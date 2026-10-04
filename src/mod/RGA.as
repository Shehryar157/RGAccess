import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.events.TimerEvent;
import flash.utils.Timer;
import flash.utils.getDefinitionByName;

// RGAccess entry point, called once from Main.init.
class RGA
{
   public static const VERSION:String = "0.1";
   private static var doc:Doc = new Doc();

   public static function start(stage:Stage) : void
   {
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var helperDir:String = FileC["applicationDirectory"].nativePath + "\\RGAccess";
      Speech.init(helperDir,RGAConfig.PYTHONW);
      Speech.say("RG Access " + VERSION + " loaded. Press F1 for help.");

      // High priority so we see keys before the game does.
      stage.addEventListener(KeyboardEvent.KEY_DOWN,onKey,false,1000);
      doc.onAction = refresh;
      var t:Timer = new Timer(1000);
      t.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void
      {
         refresh();
      });
      t.start();
   }

   private static function refresh() : void
   {
      try
      {
         doc.setLines(RGPage.build());
      }
      catch(e:Error)
      {
         // The game may not be fully loaded yet; try again next tick.
      }
   }

   // F1 help: a second page, like FFC Access's help window. Escape or F1 closes it.
   private static var help:Doc = null;

   private static function buildHelp() : Doc
   {
      var d:Doc = new Doc();
      var l:Array = [];
      l.push(new DocLine("RG Access " + VERSION + " help. Escape closes.","text","title"));
      l.push(new DocLine("Anywhere","h2","g:any"));
      l.push(new DocLine("F1: this help. Press it again, or Escape, to close.","text","k:f1"));
      l.push(new DocLine("Reading the page","h2","g:read"));
      l.push(new DocLine("Up and Down arrows: previous or next line.","text","k:ud"));
      l.push(new DocLine("Control with Up or Down: previous or next section.","text","k:cud"));
      l.push(new DocLine("Left and Right arrows: previous or next character. With Control: by word.","text","k:lr"));
      l.push(new DocLine("Home and End: start or end of the line. With Control: top or bottom of the page.","text","k:he"));
      l.push(new DocLine("Shift with any movement key: select text. Control C copies, Control A selects all.","text","k:sel"));
      l.push(new DocLine("H and Shift H: next or previous heading.","text","k:h"));
      l.push(new DocLine("Tab and Shift Tab: next or previous button.","text","k:tab"));
      l.push(new DocLine("Enter or Space: press the button you are on.","text","k:enter"));
      l.push(new DocLine("Buildings","h2","g:bld"));
      l.push(new DocLine("B and Shift B: next or previous building.","text","k:b"));
      l.push(new DocLine("Enter on a building: buy it, using the game's buy mode.","text","k:buy"));
      l.push(new DocLine("Control Enter or Shift Enter: the same as Control click or Shift click in the game.","text","k:buymod"));
      d.lines = l;
      return d;
   }

   private static function toggleHelp() : void
   {
      if(help != null)
      {
         help = null;
         Speech.say("Help closed");
         Speech.say(doc.lines.length > doc.line ? DocLine(doc.lines[doc.line]).spoken : "",false);
         return;
      }
      help = buildHelp();
      help.readCurrent();
   }

   private static function onKey(e:KeyboardEvent) : void
   {
      var used:Boolean = false;
      if(e.keyCode == 112 || (help != null && e.keyCode == 27)) // F1, or Escape in help
      {
         toggleHelp();
         used = true;
      }
      else if(help != null)
      {
         used = help.handleKey(e);
      }
      else
      {
         refresh();
         used = doc.handleKey(e);
      }
      if(used)
      {
         e.stopImmediatePropagation();
         e.preventDefault();
      }
   }
}
