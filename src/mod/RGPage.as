import feathers.controls.Button;
import feathers.controls.Label;
import flash.geom.Rectangle;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import starling.core.Starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import §"#§.§[!2§;
import §1U§.§6+§;

// Builds the virtual page from whatever is on the game's screen right now.
// It walks the screen's object tree (like os.walk): every Label becomes a text line and
// every control becomes a button line. Nothing here is specific to one screen.
// Scrambled names used (see notes/names.md):
//   §6+§            base class of all the game's own controls; it knows its tooltip:
//                   ["[i"]() is the tooltip title and ["9!0"]() the tooltip body
//   §[!2§           a building row; its labels are name, cost, percent, count
class RGPage
{
   // Text of the dialogs that are open, so RGA can speak a new one when it appears.
   public static var popupText:String = "";
   private static var counts:Object = null;

   public static function build() : Array
   {
      var out:Array = [];
      var pop:Array = [];
      var said:Array = [];
      var i:int;
      var j:int;
      counts = new Object();
      var stage:DisplayObjectContainer = Starling.current.stage;
      // Everything on the stage after the first child is a dialog on top of the game.
      for(i = stage.numChildren - 1; i >= 1; i--)
      {
         var part:Array = [];
         walk(stage.getChildAt(i),part);
         if(part.length > 0)
         {
            var hasButton:Boolean = false;
            for(j = 0; j < part.length; j++)
            {
               if(DocLine(part[j]).isButton)
               {
                  hasButton = true;
               }
               else
               {
                  said.push(DocLine(part[j]).text);
               }
            }
            if(!hasButton)
            {
               // A message you dismiss by clicking it, like the advisor.
               var go:DocLine = new DocLine("Continue","button",nextKey("continue"),click);
               go.target = stage.getChildAt(i);
               part.push(go);
            }
            pop = pop.concat(part);
         }
      }
      popupText = said.join(" ");
      if(pop.length > 0)
      {
         out.push(new DocLine("Dialog","h1","h:dialog"));
         out = out.concat(pop);
      }
      if(stage.numChildren > 0)
      {
         walk(stage.getChildAt(0),out);
      }
      if(out.length == 0)
      {
         out.push(new DocLine("Nothing on screen yet","text","empty"));
      }
      return out;
   }

   private static function walk(obj:DisplayObject, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      if(obj is Label)
      {
         var t:String = clean(String(Object(obj)["text"]));
         if(t != "")
         {
            out.push(new DocLine(t,"text",nextKey("t")));
         }
         return;
      }
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      var cls:String = getQualifiedClassName(obj);
      if((obj is §6+§ || obj is Button) && (c == null || !hasControl(c)))
      {
         out.push(controlLine(obj,cls));
         return;
      }
      var head:String = sectionName(cls);
      if(head != "")
      {
         out.push(new DocLine(head,"h1","h:" + cls));
      }
      if(cls == "]!6::%!a")
      {
         var realm:DocLine = new DocLine("The realm, click to earn coins","button","realm",clickRealm);
         realm.target = obj;
         out.push(realm);
      }
      if(c == null)
      {
         return;
      }
      for(var i:int = 0; i < c.numChildren; i++)
      {
         walk(c.getChildAt(i),out);
      }
   }

   // Our names for the main screen's panels, which have no visible title of their own.
   private static function sectionName(cls:String) : String
   {
      if(cls == "]!6::%!a")
      {
         return "Realm";
      }
      if(cls == "]!6::\"T")
      {
         return "Buildings";
      }
      if(cls == "]!6::!M")
      {
         return "Buy options";
      }
      if(cls == "]!6::2i")
      {
         return "Menu";
      }
      if(cls == "]!6::+r")
      {
         return "Status bar";
      }
      if(cls == "]!6::7R")
      {
         return "Mana and spells";
      }
      return "";
   }

   private static function controlLine(obj:DisplayObject, cls:String) : DocLine
   {
      var labels:Array = [];
      collectLabels(obj,labels);
      var title:String = tipTitle(obj);
      var text:String;
      var kind:String = "button";
      if(obj is §[!2§ && labels.length >= 4)
      {
         kind = "building";
         text = labels[0] + ", " + labels[3] + " owned, costs " + labels[1] + ", " + labels[2];
      }
      else
      {
         if(title != "" && labels.indexOf(title) < 0)
         {
            labels.unshift(title);
         }
         text = labels.join(", ");
      }
      if(text == "" && obj is Button)
      {
         text = clean(String(Object(obj)["label"]));
         if(text == "")
         {
            text = "Close";
         }
      }
      if(text == "")
      {
         text = "Unlabelled";
      }
      var o:Object = obj;
      if(o.hasOwnProperty("isEnabled") && !o["isEnabled"])
      {
         text += ", unavailable";
      }
      var l:DocLine = new DocLine(text,kind,nextKey(cls),click);
      l.target = obj;
      return l;
   }

   private static function collectLabels(obj:DisplayObject, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      if(obj is Label)
      {
         var t:String = clean(String(Object(obj)["text"]));
         if(t != "")
         {
            out.push(t);
         }
         return;
      }
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      if(c == null)
      {
         return;
      }
      for(var i:int = 0; i < c.numChildren; i++)
      {
         collectLabels(c.getChildAt(i),out);
      }
   }

   // True if a control sits somewhere inside c (then c is a container, not a button itself).
   private static function hasControl(c:DisplayObjectContainer) : Boolean
   {
      for(var i:int = 0; i < c.numChildren; i++)
      {
         var k:DisplayObject = c.getChildAt(i);
         if(k.visible)
         {
            if(k is §6+§ || k is Button)
            {
               return true;
            }
            var kc:DisplayObjectContainer = k as DisplayObjectContainer;
            if(kc != null && hasControl(kc))
            {
               return true;
            }
         }
      }
      return false;
   }

   // A stable id per line ("3rd control of this type"), so the cursor stays put across rebuilds.
   private static function nextKey(what:String) : String
   {
      var n:int = counts[what] == undefined ? 0 : int(counts[what]);
      counts[what] = n + 1;
      return what + "#" + n;
   }

   private static function tipTitle(obj:Object) : String
   {
      if(!(obj is §6+§))
      {
         return "";
      }
      try
      {
         var t:String = clean(String(obj["[i"]()));
         if(t != "Test Title")
         {
            return t;
         }
      }
      catch(e:Error)
      {
      }
      return "";
   }

   // The control's tooltip as lines of text: title first, then the body.
   public static function tooltip(target:Object) : Array
   {
      var out:Array = [];
      if(!(target is §6+§))
      {
         return out;
      }
      var title:String = tipTitle(target);
      if(title != "")
      {
         out.push(title);
      }
      try
      {
         var body:String = String(target["9!0"]());
         body = body.replace(new RegExp("<br ?/?>","gi"),"\n").split("\r").join("\n");
         var parts:Array = body.split("\n");
         for(var i:int = 0; i < parts.length; i++)
         {
            var p:String = clean(parts[i]);
            if(p != "" && p != "Test Body")
            {
               out.push(p);
            }
         }
      }
      catch(e:Error)
      {
      }
      return out;
   }

   // Strip the game's formatting tags (<font>, <b> ...) and tidy spaces.
   public static function clean(s:String) : String
   {
      if(s == null || s == "null" || s == "undefined")
      {
         return "";
      }
      s = s.replace(new RegExp("<[^>]+>","g"),"");
      s = s.replace(new RegExp("\\s+","g")," ");
      s = s.replace(new RegExp("^ | $","g"),"");
      return s;
   }

   // Enter on a button: a pretend mouse click in the middle of the control.
   public static function click(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      var r:Rectangle = DisplayObject(target).getBounds(Starling.current.stage);
      tap(r.x + r.width / 2,r.y + r.height / 2);
   }

   // The realm is the big background; click near its top left, away from any dialog.
   public static function clickRealm(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      var r:Rectangle = DisplayObject(target).getBounds(Starling.current.stage);
      tap(r.x + r.width * 0.3,r.y + r.height * 0.2);
   }

   // Feed Starling (the game's graphics engine) a mouse move, press and release at x, y.
   private static function tap(x:Number, y:Number) : void
   {
      var tp:* = Starling.current.touchProcessor;
      tp.enqueue(0,"hover",x,y);
      tp.enqueue(0,"began",x,y);
      tp.enqueue(0,"ended",x,y);
   }

   // Research: write the current page to rga_page.txt next to the log.
   public static function dump(lines:Array) : void
   {
      var a:Array = [];
      for(var i:int = 0; i < lines.length; i++)
      {
         a.push(DocLine(lines[i]).spoken);
      }
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
      var s:* = new FS();
      s.open(FileC["applicationStorageDirectory"].resolvePath("rga_page.txt"),"write");
      s.writeUTFBytes(a.join("\r\n"));
      s.close();
   }
}
