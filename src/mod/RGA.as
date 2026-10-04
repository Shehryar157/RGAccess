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

   private static function onKey(e:KeyboardEvent) : void
   {
      var used:Boolean = false;
      if(e.keyCode == 112) // F1
      {
         Speech.say("RG Access help. The game is a page you read like a web page. " +
            "Arrows move by line, character or word; Shift selects; Ctrl+C copies. " +
            "H and Shift+H move by heading, B and Shift+B by building, Tab and Shift+Tab by button. " +
            "Enter presses a button. On a building, Enter buys using the game's buy mode.");
         used = true;
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
