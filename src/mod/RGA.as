import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.TimerEvent;
import flash.utils.Timer;
import flash.utils.getDefinitionByName;
import flash.utils.getTimer;

// RGAccess entry point, called once from Main.init.
class RGA
{
   // Created in start(), not here: code that runs while the classes are still being defined
   // can make the whole game fail to load.
   private static var doc:Doc = null;

   public static function start(stage:Stage) : void
   {
      doc = new Doc();
      theStage = stage;
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
      pageTimer = new Timer(500);
      pageTimer.addEventListener(TimerEvent.TIMER,onTick);
      pageTimer.start();
   }

   // A named function, not an inline one: JPEXS miscompiles inline functions (VerifyError).
   // Twice a second the page is read again, so values stay live and a new dialog is spoken
   // soon. It usually costs 5 to 10 ms (measured), which the game does not notice. A big
   // screen (Trophies, Statistics) or a slow computer can cost more, so the wait before the
   // next read grows with what the last one cost: the mod never takes more than about 4% of
   // the game's time. In the background the page is read only every 2 seconds.
   private static var ticks:int = 0;
   private static var pageTimer:Timer = null;
   private static var active:Boolean = true;

   private static function onTick(e:TimerEvent) : void
   {
      if(editing != null && editing["stage"] == null)
      {
         endEdit(false); // the dialog with the box closed
      }
      ticks++;
      if(active || ticks % 4 == 0)
      {
         var t0:int = getTimer();
         refresh();
         pageTimer.delay = Math.max(500,Math.min(2000,(getTimer() - t0) * 25));
      }
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
   // The last dialog or notification that was spoken, kept after it closes: F2 repeats it.
   private static var lastMessage:String = "";

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
               lastMessage = lastToast;
               doc.visit("h:" + RGPage.TOAST);
            }
         }
         if(RGPage.popupText != lastPopup)
         {
            lastPopup = RGPage.popupText;
            if(lastPopup != "")
            {
               Speech.say("Dialog. " + lastPopup,false);
               lastMessage = lastPopup;
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
      if(editing != null)
      {
         return; // Enter on a text box started typing; there is no result to announce
      }
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
      l.push(new DocLine("F2: repeat the last dialog or notification, even after it has closed.","text","k:f2"));
      l.push(new DocLine("Text boxes: press Enter on an edit box to type in it. Letters are spoken as you type. Escape or Enter finishes.","text","k:edit"));
      l.push(new DocLine("Reading the page","h2","g:read"));
      l.push(new DocLine("Up and Down arrows: previous or next line.","text","k:ud"));
      l.push(new DocLine("Control with Up or Down: previous or next paragraph. Here every line is a paragraph, so it is the same as Up or Down.","text","k:cud"));
      l.push(new DocLine("Left and Right arrows: previous or next character. With Control: by word.","text","k:lr"));
      l.push(new DocLine("Home and End: start or end of the line. With Control: top or bottom of the page.","text","k:he"));
      l.push(new DocLine("Shift with any movement key: select text. Control C copies, Control A selects all.","text","k:sel"));
      l.push(new DocLine("H and Shift H: next or previous heading.","text","k:h"));
      l.push(new DocLine("R: jump to Resources (coins, production, gems, rubies, mana). L: jump to the Toolbar.","text","k:r"));
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
      l.push(new DocLine("D: read the tooltip without its title and without the costs for buying several, for example what a building produces. Works on anything that has a tooltip.","text","k:desc"));
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

   // D: the tooltip minus its title (the line already says it) and the "Cost for 10: ..." lines
   // of a building, so what is left is what the thing does: for a building, what one produces
   // (so also the next one) and what all of them produce. The user asked for this (2026-10-14).
   private static function sayDescription() : void
   {
      var l:DocLine = doc.lines.length > doc.line ? DocLine(doc.lines[doc.line]) : null;
      var tip:Array = l == null || l.target == null ? [] : RGPage.tooltip(l.target);
      var a:Array = [];
      for(var i:int = 1; i < tip.length; i++)
      {
         var s:String = tip[i];
         if(s.indexOf("Cost for ") != 0)
         {
            a.push(new RegExp("[.!?)]$").test(s) ? s : s + ".");
         }
      }
      Speech.say(a.length == 0 ? "No description" : a.join(" "));
   }

   private static function onActivate(e:Event) : void
   {
      var stage:Stage = e.target as Stage;
      RGALog.write("window activated, focus was " + (stage != null && stage.focus != null ? String(stage.focus) : "none"));
      if(stage != null && editing == null)
      {
         stage.focus = stage;
      }
      keysToLog = 5;
      active = true;
      refresh(); // the page may be up to 2 seconds old
   }

   private static function onDeactivate(e:Event) : void
   {
      active = false;
      RGALog.write("window deactivated");
   }

   // The first few keys after the window comes to the front are logged, so a player's log
   // shows whether keys reach the mod at all after switching windows.
   private static var keysToLog:int = 5;

   private static var theStage:Stage = null;
   // The text box being typed into, or null. While it is set the mod takes no keys except
   // Escape and Enter, so every letter reaches the box instead of moving the cursor.
   private static var editing:Object = null;
   private static var typedBefore:String = "";

   // Enter on a text box line: give the box the keyboard.
   public static function startEdit(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      editing = target;
      typedBefore = String(target["text"]);
      target.addEventListener("change",onEditChange);
      target.addEventListener("enter",onEditEnter);
      target.addEventListener("focusOut",onEditOut);
      target["setFocus"]();
      Speech.say("Typing" + (typedBefore == "" ? "" : ", " + typedBefore) + ". Press Escape or Enter when you are done.");
   }

   // The box's text changed: speak the letter typed or deleted, like a screen reader's key echo.
   private static function onEditChange(e:Object) : void
   {
      if(editing == null)
      {
         return;
      }
      var now:String = String(editing["text"]);
      var was:String = typedBefore;
      typedBefore = now;
      if(now.length == was.length + 1 && now.indexOf(was) == 0)
      {
         Speech.say(now.charAt(now.length - 1) == " " ? "space" : now.charAt(now.length - 1));
      }
      else if(now.length == was.length - 1 && was.indexOf(now) == 0)
      {
         Speech.say((was.charAt(was.length - 1) == " " ? "space" : was.charAt(was.length - 1)) + " deleted");
      }
      else
      {
         Speech.say(now == "" ? "empty" : now);
      }
   }

   private static function onEditEnter(e:Object) : void
   {
      endEdit(true);
   }

   // The game's box does not always keep the keyboard (seen: it loses it at once). That does
   // not end typing: onKey then types into the box itself.
   private static function onEditOut(e:Object) : void
   {
      RGALog.write("edit box lost the keyboard, typing through the mod");
   }

   // A key while typing, when it arrived at the stage and not at the box: do the box's work.
   private static function typeKey(e:KeyboardEvent) : void
   {
      var text:String = String(editing["text"]);
      if(e.keyCode == 8)
      {
         if(text == "")
         {
            Speech.say("empty");
            return;
         }
         text = text.substr(0,text.length - 1);
      }
      else if(e.charCode >= 32 && !e.ctrlKey && !e.altKey)
      {
         text += String.fromCharCode(e.charCode);
      }
      else
      {
         return;
      }
      // Setting the text makes the box announce the change itself: the game hears it (Hard
      // Reset enables its button) and onEditChange speaks the letter.
      editing["text"] = text;
   }

   private static function endEdit(byKey:Boolean) : void
   {
      if(editing == null)
      {
         return;
      }
      var box:Object = editing;
      editing = null;
      box.removeEventListener("change",onEditChange);
      box.removeEventListener("enter",onEditEnter);
      box.removeEventListener("focusOut",onEditOut);
      var text:String = String(box["text"]);
      if(byKey)
      {
         try
         {
            box["clearFocus"]();
         }
         catch(err:Error)
         {
         }
         if(theStage != null)
         {
            theStage.focus = theStage;
         }
      }
      Speech.say("Typing finished, " + (text == "" ? "empty" : text));
   }

   private static function onKey(e:KeyboardEvent) : void
   {
      var used:Boolean = false;
      if(editing != null)
      {
         if(e.keyCode == 27 || e.keyCode == 13)
         {
            endEdit(true);
            e.stopImmediatePropagation();
            e.preventDefault();
         }
         else if(e.target is Stage)
         {
            typeKey(e);
            e.stopImmediatePropagation();
            e.preventDefault();
         }
         return;
      }
      if(keysToLog > 0)
      {
         keysToLog--;
         RGALog.write("key " + e.keyCode + (e.target is Stage ? "" : ", sent to " + e.target));
      }
      if(e.keyCode == 123 && e.ctrlKey && e.shiftKey) // Control+Shift+F12: research dump
      {
         dumpTree();
         Speech.say("Screen tree saved");
         return;
      }
      if(e.keyCode == 113) // F2: repeat the last dialog or notification, even after it closed
      {
         Speech.say(lastMessage != "" ? lastMessage : "No dialog or notification yet");
         e.stopImmediatePropagation();
         e.preventDefault();
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
      else if(e.keyCode == 68 && !e.ctrlKey && !e.altKey && !e.shiftKey) // D: the tooltip without its title and buy costs
      {
         sayDescription();
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
