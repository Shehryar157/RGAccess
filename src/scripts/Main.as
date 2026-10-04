package
{
   import §[!6§.*;
   import com.divinegames.service.*;
   import flash.display.*;
   import flash.events.Event;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.*;
   import starling.core.Starling;

   // The game's startup class, rewritten without the obfuscation junk (see notes/names.md).
   // It does what the original does, plus starting RGAccess.
   // The original sent crash reports to the developer; we write them to our log instead.
   public class Main extends Sprite
   {
      private var starling:Starling;

      public function Main()
      {
         super();
         addEventListener("addedToStage",init);
      }

      private function init(param1:Event) : void
      {
         removeEventListener("addedToStage",init);
         loaderInfo.uncaughtErrorEvents.addEventListener("uncaughtError",uncaughtErrorHandler);
         stage.align = "TL";
         stage.scaleMode = "noScale";
         §<!d§.§>!a§.§1?§ = _("Initializing ...");
         Starling.handleLostContext = true;
         starling = new Starling(§8G§,stage,null,null,"auto","auto");
         starling.antiAliasing = 8;
         starling.start();
         Starling.current.nativeStage.addChild(§<!d§.§>!a§);
         try
         {
            RGA.start(stage);
         }
         catch(e:Error)
         {
            RGALog.write("RGA.start failed: " + e.getStackTrace());
         }
      }

      protected function uncaughtErrorHandler(param1:UncaughtErrorEvent) : void
      {
         var err:* = param1.error;
         var text:String = err is Error ? Error(err).getStackTrace() : String(err);
         RGALog.write("Uncaught error: " + text);
      }
   }
}
