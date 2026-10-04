package
{
   import §[!6§.*;
   import com.divinegames.service.*;
   import flash.display.*;
   import flash.events.Event;
   import flash.events.HTTPStatusEvent;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.system.Capabilities;
   import flash.utils.*;
   import flash.geom.Rectangle;
   import starling.core.Starling;
   
   public class Main extends Sprite
   {
      
      private var starling:Starling;
      
      protected var sentOne:Boolean = false;
      
      public function Main()
      {
         while(true)
         {
            if(!_loc1_)
            {
               super();
               if(_loc1_)
               {
                  break;
               }
            }
            addEventListener("addedToStage",init);
            break;
         }
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
         RGA.start(stage);
      }

      
      protected function uncaughtErrorHandler(param1:UncaughtErrorEvent) : void
      {
         var _loc6_:* = null;
         var _loc3_:ByteArray = null;
         var _loc7_:* = null;
         var _loc4_:ByteArray = null;
         var _loc2_:URLRequest = null;
         var _loc5_:URLLoader = null;
         if(!_loc11_)
         {
            if(!sentOne)
            {
               try
               {
                  sentOne = true;
                  while(true)
                  {
                     §§push("[");
                     if(!_loc11_)
                     {
                        §§push(§§pop() + param1.error.name);
                        if(_loc11_)
                        {
                           break;
                        }
                        §§push(§§pop() + "] ");
                        if(_loc11_)
                        {
                           break;
                        }
                     }
                     §§push(§§pop() + param1.error.message);
                     break;
                  }
                  _loc6_ = §§pop();
                  §§push(_loc6_);
                  if(!_loc10_)
                  {
                     §§push("\n\n");
                     if(!_loc10_)
                     {
                        §§push(§§pop() + param1.error.getStackTrace());
                     }
                     §§push(§§pop() + §§pop());
                  }
                  _loc6_ = §§pop();
                  if(!_loc10_)
                  {
                     trace(_loc6_);
                  }
                  _loc3_ = new ByteArray();
                  while(true)
                  {
                     if(!_loc10_)
                     {
                        _loc3_.writeUTFBytes(_loc6_);
                        if(_loc10_)
                        {
                           break;
                        }
                     }
                     _loc3_.position = 0;
                     break;
                  }
                  §§push(Kongregate.getPlatform());
                  if(!_loc10_)
                  {
                     while(true)
                     {
                        §§push(§§pop() + " ");
                        if(!_loc11_)
                        {
                           §§push(§§pop() + Capabilities.os);
                           if(!_loc11_)
                           {
                              §§push(§§pop() + " ");
                              if(_loc10_)
                              {
                                 break;
                              }
                           }
                        }
                        §§push(§§pop() + Capabilities.version);
                        break;
                     }
                  }
                  _loc7_ = §§pop();
                  _loc4_ = new ByteArray();
                  _loc4_.writeUTFBytes(_loc7_);
                  if(!_loc10_)
                  {
                     _loc4_.position = 0;
                  }
                  _loc2_ = new URLRequest("http://www.divinegames.it/rg.php?v=" + §&M§.§'!6§(true).toString() + "&e=" + §'!V§.§56§(_loc3_) + "&p=" + §'!V§.§56§(_loc4_));
                  while(true)
                  {
                     if(!_loc10_)
                     {
                        _loc2_.data = §2!c§.§3!W§;
                        if(_loc10_)
                        {
                           break;
                        }
                     }
                     _loc2_.method = "POST";
                     break;
                  }
                  _loc5_ = new URLLoader();
                  _loc5_.addEventListener("complete",loaderCompleteHandler,false,0,true);
                  while(true)
                  {
                     if(!_loc11_)
                     {
                        _loc5_.addEventListener("httpStatus",httpStatusHandler,false,0,true);
                        if(!_loc11_)
                        {
                           _loc5_.addEventListener("securityError",securityErrorHandler,false,0,true);
                           if(_loc11_)
                           {
                              break;
                           }
                        }
                        _loc5_.addEventListener("ioError",ioErrorHandler,false,0,true);
                        if(_loc11_)
                        {
                           break;
                        }
                     }
                     _loc5_.load(_loc2_);
                     break;
                  }
               }
               catch(e:Error)
               {
               }
               return;
            }
         }
      }
      
      protected function loaderCompleteHandler(param1:Event) : void
      {
      }
      
      protected function httpStatusHandler(param1:HTTPStatusEvent) : void
      {
      }
      
      protected function securityErrorHandler(param1:SecurityErrorEvent) : void
      {
      }
      
      protected function ioErrorHandler(param1:IOErrorEvent) : void
      {
      }
   }
}

