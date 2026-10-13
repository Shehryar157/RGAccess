import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.TimerEvent;
import flash.utils.Timer;
import flash.utils.getDefinitionByName;

// RGAccess entry point, called once from Main.init.
class RGA
{
   // Created in start(), not here: code that runs while the classes are still being defined
   // can make the whole game fail to load.
   private static var doc:Doc = null;

   public static function start(stage:Stage) : void
   {
      doc = new Doc();
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var helperDir:String = FileC["applicationDirectory"].nativePath + "\\RGAccess";
      RGALog.write("RGA " + RGAConfig.VERSION + " starting, helper " + helperDir);
      Speech.init(helperDir,RGAConfig.PYTHONW);
      RGALog.write("speech started");
      Speech.say("RG Access " + RGAConfig.VERSION + " loaded. Press F1 for help.");

      // High priority so we see keys before the game does.
      stage.addEventListener(KeyboardEvent.KEY_DOWN,onKey,false,1000);
      // After Alt+Tab away and back, the window can come back with no keyboard focus, so
      // key events never reach us. Take the focus again whenever the window is activated.
      stage.addEventListener(Event.ACTIVATE,onActivate);
      stage.addEventListener(Event.DEACTIVATE,onDeactivate);
      doc.onAction = afterAction;
      var t:Timer = new Timer(500);
      t.addEventListener(TimerEvent.TIMER,onTick);
      t.start();
   }

   // A named function, not an inline one: JPEXS miscompiles inline functions (VerifyError).
   // Twice a second the page is read again, so values stay live and a new dialog is spoken
   // soon. It costs 5 to 10 ms each time (measured), which the game does not notice.
   private static var ticks:int = 0;

   private static function onTick(e:TimerEvent) : void
   {
      refresh();
      ticks++;
      if(RGAConfig.DEV)
      {
         // Research tools, left out of a release.
         if(ticks == 50 && RGADump.wanted())
         {
            dumpTree();
         }
         if(ticks % 2 == 0)
         {
            RGARemote.tick(doc); // it counts in seconds
         }
      }
   }

   private static var lastError:String = "";
   private static var lastPopup:String = "";
   private static var lastToast:String = "";

   private static function dumpTree() : void
   {
      try
      {
         RGADump.dump();
         RGPage.dump(doc.lines);
      }
      catch(e:Error)
      {
         RGALog.write("dump failed: " + e.getStackTrace());
      }
   }

   private static function refresh() : void
   {
      try
      {
         doc.setLines(RGPage.build());
         if(RGPage.toastText != lastToast)
         {
            lastToast = RGPage.toastText;
            if(lastToast != "")
            {
               Speech.say(lastToast,false);
               doc.visit("h:" + RGPage.TOAST);
            }
         }
         if(RGPage.popupText != lastPopup)
         {
            lastPopup = RGPage.popupText;
            if(lastPopup != "")
            {
               Speech.say("Dialog. " + lastPopup,false);
               doc.visit("h:dialog");
            }
         }
         if(lastToast == "" && lastPopup == "")
         {
            doc.backKey = null;
         }
      }
      catch(e:Error)
      {
         // The game may not be fully loaded yet; try again next tick.
         // Log each different error once, so a real bug doesn't hide here.
         if(e.message != lastError)
         {
            lastError = e.message;
            RGALog.write("page build failed: " + e.getStackTrace());
         }
      }
   }

   // The line Enter was pressed on, and the page's main headings at that moment.
   private static var pressedLine:DocLine = null;
   private static var headsBefore:Object = null;
   private static var resultTimer:Timer = null;

   private static var popupBefore:String = "";
   private static var toastBefore:String = "";

   // After a button is pressed: say what happened as soon as the game has reacted. The page is
   // looked at 100, 200 and 300 ms after the press; the first look that shows a change speaks.
   public static function afterAction(l:DocLine) : void
   {
      pressedLine = l;
      headsBefore = heads();
      popupBefore = lastPopup;
      toastBefore = lastToast;
      if(resultTimer == null)
      {
         resultTimer = new Timer(100,3);
         resultTimer.addEventListener(TimerEvent.TIMER,onResult);
      }
      resultTimer.reset();
      resultTimer.start();
   }

   private static function onResult(e:TimerEvent) : void
   {
      var last:Boolean = resultTimer.currentCount >= 3;
      RGPage.hoverAway();
      RGPage.listStale = true;
      refresh();
      // A dialog or notification that appeared since the press has been spoken already, and it is the result.
      if(popupBefore != lastPopup && lastPopup != "" || toastBefore != lastToast && lastToast != "")
      {
         resultTimer.stop();
         return;
      }
      try
      {
         var r:String = result(pressedLine);
         // "Cannot afford" means nothing changed, which is only certain at the last look.
         if(last || r != "" && r.indexOf("Cannot afford") != 0)
         {
            resultTimer.stop();
            Speech.say(r);
         }
      }
      catch(err:Error)
      {
         RGALog.write("result failed: " + err.getStackTrace());
      }
   }

   // The level 1 headings on the page, as key -> text.
   private static function heads() : Object
   {
      var o:Object = new Object();
      for(var i:int = 0; i < doc.lines.length; i++)
      {
         var l:DocLine = DocLine(doc.lines[i]);
         if(l.kind == "h1")
         {
            o[l.key] = l.text;
         }
      }
      return o;
   }

   // What pressing the line "old" did, found by comparing it with the page as it is now. "" if nothing to say.
   private static function result(old:DocLine) : String
   {
      var i:int;
      var l:DocLine;
      var now:DocLine = null;
      var item:ListItem = old.target as ListItem;
      for(i = 0; i < doc.lines.length && now == null; i++)
      {
         l = DocLine(doc.lines[i]);
         if(item != null ? l.target is ListItem && ListItem(l.target).item === item.item : l.key == old.key)
         {
            now = l;
         }
      }
      var name:String = String(old.text.split(",")[0]);
      if(old.kind == "building" && now != null)
      {
         // A bought building is read again as it is now: new count, new price.
         if(now.text != old.text)
         {
            return now.spoken;
         }
         return old.text.indexOf("unavailable") >= 0 ? "Cannot afford " + name : "";
      }
      if(item != null && item.index >= 0)
      {
         // A bought upgrade leaves the list or moves to the Purchased section.
         if(now == null || ListItem(now.target).group != item.group)
         {
            return name + " purchased";
         }
         if(old.text.indexOf("cannot afford") >= 0)
         {
            return "Cannot afford " + name;
         }
      }
      if(now != null && now.text != old.text)
      {
         return now.spoken;
      }
      // A part of the screen opened or closed.
      var after:Object = heads();
      var key:String;
      for(key in after)
      {
         if(!headsBefore.hasOwnProperty(key))
         {
            return String(after[key]) + " opened";
         }
      }
      for(key in headsBefore)
      {
         if(!after.hasOwnProperty(key))
         {
            return String(headsBefore[key]) + " closed";
         }
      }
      return "";
   }

   // F1 help: a second page, like FFC Access's help window. Escape or F1 closes it.
   private static var help:Doc = null;

   private static function buildHelp() : Doc
   {
      var d:Doc = new Doc();
      var l:Array = [];
      l.push(new DocLine("RG Access " + RGAConfig.VERSION + " help. Escape closes.","text","title"));
      l.push(new DocLine("Anywhere","h2","g:any"));
      l.push(new DocLine("F1: this help. Press it again, or Escape, to close.","text","k:f1"));
      l.push(new DocLine("Reading the page","h2","g:read"));
      l.push(new DocLine("Up and Down arrows: previous or next line.","text","k:ud"));
      l.push(new DocLine("Control with Up or Down: previous or next paragraph. Here every line is a paragraph, so it is the same as Up or Down.","text","k:cud"));
      l.push(new DocLine("Left and Right arrows: previous or next character. With Control: by word.","text","k:lr"));
      l.push(new DocLine("Home and End: start or end of the line. With Control: top or bottom of the page.","text","k:he"));
      l.push(new DocLine("Shift with any movement key: select text. Control C copies, Control A selects all.","text","k:sel"));
      l.push(new DocLine("H and Shift H: next or previous heading.","text","k:h"));
      l.push(new DocLine("R: jump to the Toolbar. Resources (coins, production, gems, rubies, mana) is the heading just before it: Shift H.","text","k:r"));
      l.push(new DocLine("S: jump to Spells. U: jump to Upgrades, opening the panel if it is closed.","text","k:su"));
      l.push(new DocLine("O: open Options. If it is already open, jump to its top.","text","k:o"));
      l.push(new DocLine("Tab and Shift Tab: next or previous button.","text","k:tab"));
      l.push(new DocLine("Enter or Space: press the button you are on.","text","k:enter"));
      l.push(new DocLine("T: read the whole tooltip of the button you are on. Shift T: open the tooltip as a page to read line by line; Escape closes it.","text","k:tip"));
      l.push(new DocLine("Dialogs, such as the advisor, and notifications are spoken when they appear, and the cursor moves to them. When they close, it goes back to where it was.","text","k:dlg"));
      l.push(new DocLine("Buildings","h2","g:bld"));
      l.push(new DocLine("B and Shift B: next or previous building.","text","k:b"));
      l.push(new DocLine("Enter on a building: buy it, using the game's buy mode.","text","k:buy"));
      l.push(new DocLine("Control Enter: buy 10. Shift Enter: buy 100. Control Shift Enter: buy as many as you can afford.","text","k:buymod"));
      l.push(new DocLine("T on a building reads what each of those would cost.","text","k:buytip"));
      l.push(new DocLine("After Enter, the mod reads the button again if it changed, for example a building with its new count and price. It says nothing if nothing changed.","text","k:result"));
      d.lines = l;
      return d;
   }

   private static function toggleHelp() : void
   {
      if(help != null)
      {
         help = null;
         Speech.say("Closed");
         Speech.say(doc.lines.length > doc.line ? DocLine(doc.lines[doc.line]).spoken : "",false);
         return;
      }
      help = buildHelp();
      help.readCurrent();
   }

   // T speaks the current control's whole tooltip. Shift+T (open) also opens it as a small
   // page of its own, to read line by line; Escape closes it.
   private static function showTooltip(open:Boolean) : void
   {
      var l:DocLine = doc.lines.length > doc.line ? DocLine(doc.lines[doc.line]) : null;
      var tip:Array = l == null || l.target == null ? [] : RGPage.tooltip(l.target);
      if(tip.length == 0)
      {
         Speech.say("No tooltip");
         return;
      }
      if(!open)
      {
         Speech.say(tip.join(". "));
         return;
      }
      var a:Array = [];
      for(var i:int = 0; i < tip.length; i++)
      {
         a.push(new DocLine(tip[i],i == 0 ? "h2" : "text","tip" + i));
      }
      a.push(new DocLine("End of tooltip. Escape closes.","text","tipend"));
      help = new Doc();
      help.setLines(a);
      Speech.say(tip.join(". "));
   }

   private static function onActivate(e:Event) : void
   {
      var stage:Stage = e.target as Stage;
      RGALog.write("window activated, focus was " + (stage != null && stage.focus != null ? String(stage.focus) : "none"));
      if(stage != null)
      {
         stage.focus = stage;
      }
   }

   private static function onDeactivate(e:Event) : void
   {
      RGALog.write("window deactivated");
   }

   private static function onKey(e:KeyboardEvent) : void
   {
      var used:Boolean = false;
      if(e.keyCode == 123 && e.ctrlKey && e.shiftKey) // Control+Shift+F12: research dump
      {
         dumpTree();
         Speech.say("Screen tree saved");
         return;
      }
      if(e.keyCode == 112 || (help != null && e.keyCode == 27)) // F1, or Escape in help
      {
         toggleHelp();
         used = true;
      }
      else if(help != null)
      {
         used = help.handleKey(e);
      }
      else if(e.keyCode == 84 && !e.ctrlKey && !e.altKey) // T: speak the tooltip of the current line; Shift+T: open it as a page
      {
         showTooltip(e.shiftKey);
         used = true;
      }
      else
      {
         // Keys that press something need the page as it is this instant. Keys that only move
         // or read use the page the timer keeps up to date, so they answer at once.
         if(e.keyCode == 13 || e.keyCode == 32 || e.keyCode == 85 || e.keyCode == 79)
         {
            refresh();
         }
         used = doc.handleKey(e);
      }
      if(used)
      {
         e.stopImmediatePropagation();
         e.preventDefault();
      }
   }
}
