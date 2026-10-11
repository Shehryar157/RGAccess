import feathers.controls.Button;
import feathers.controls.Label;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import starling.core.Starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import starling.display.Image;
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
   // True once the mana orb has been listed under Resources, so it is not listed twice.
   private static var manaDone:Boolean = false;

   public static function build() : Array
   {
      var out:Array = [];
      var pop:Array = [];
      var said:Array = [];
      var i:int;
      var j:int;
      counts = new Object();
      manaDone = false;
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
      if(cls == MANA && manaDone)
      {
         return;
      }
      if((obj is §6+§ || obj is Button) && (c == null || !hasControl(c)))
      {
         out.push(controlLine(obj,cls));
         return;
      }
      var head:String = sectionName(cls);
      if(head != "" && cls != STATUS)
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
      var i:int;
      if(cls == STATUS && c.numChildren > 0)
      {
         // The status bar is two groups: the amounts, then the icon buttons.
         // The mana orb lives elsewhere on screen but is a resource too, so it is read here.
         out.push(new DocLine("Resources","h1","h:resources"));
         walk(c.getChildAt(0),out);
         var sib:DisplayObjectContainer = obj.parent;
         for(i = 0; sib != null && i < sib.numChildren; i++)
         {
            if(getQualifiedClassName(sib.getChildAt(i)) == MANA)
            {
               walk(sib.getChildAt(i),out);
               manaDone = true;
            }
         }
         out.push(new DocLine("Toolbar","h1","h:toolbar"));
         for(i = 1; i < c.numChildren; i++)
         {
            walk(c.getChildAt(i),out);
         }
         return;
      }
      for(i = 0; i < c.numChildren; i++)
      {
         walk(c.getChildAt(i),out);
      }
   }

   private static var STATUS:String = "]!6::+r";
   private static var MANA:String = "]!6::7R";

   // Names for buttons that are only a picture: no text and no tooltip title.
   // Found from the picture each class loads (UIShop, BGView, UIAudio, UICog) and the dialog it opens.
   private static function iconName(obj:DisplayObject, cls:String) : String
   {
      if(cls == "4X::=!_")
      {
         return "Shop";
      }
      if(cls == "4X::+Y")
      {
         return "Hide interface";
      }
      if(cls == "4X::9P")
      {
         return "Statistics";
      }
      if(cls == "4X::2!Z")
      {
         return "Options";
      }
      if(cls == "4X::<!w")
      {
         // Two pictures, speaker and crossed-out speaker; the game shows one of them.
         var c:DisplayObjectContainer = obj as DisplayObjectContainer;
         var seen:int = 0;
         for(var i:int = 0; c != null && i < c.numChildren; i++)
         {
            if(c.getChildAt(i) is Image)
            {
               seen++;
               if(seen == 2)
               {
                  return c.getChildAt(i).visible ? "Sound, off" : "Sound, on";
               }
            }
         }
         return "Sound on or off";
      }
      return "";
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
      if(cls == STATUS)
      {
         return "Resources";
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
         text = labels[0] + ", " + labels[3] + " owned, costs " + labels[1] + ", " + labels[2] + " of production";
      }
      else
      {
         if(title != "" && labels.indexOf(title) < 0)
         {
            labels.unshift(title);
         }
         text = labels.join(", ");
         if(cls == "4X::2!C")
         {
            // Not a purchase: it changes how many buildings one press buys.
            text = "Buy amount, " + text;
         }
      }
      if(text == "")
      {
         text = iconName(obj,cls);
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
      var d:DisplayObject = DisplayObject(target);
      var r:Rectangle = d.getBounds(Starling.current.stage);
      // Ask the engine what is on top at a few points inside the control, and press the
      // first point where that is the control itself. Something else may cover its centre.
      var fx:Array = [0.5,0.25,0.75,0.5,0.5,0.1,0.9,0.1,0.9];
      var fy:Array = [0.5,0.5,0.5,0.25,0.75,0.15,0.15,0.85,0.85];
      var cover:String = "";
      for(var i:int = 0; i < fx.length; i++)
      {
         var x:Number = r.x + r.width * fx[i];
         var y:Number = r.y + r.height * fy[i];
         var hit:DisplayObject = Starling.current.stage.hitTest(new Point(x,y),true);
         if(hit != null && inside(hit,d))
         {
            RGALog.write("click " + getQualifiedClassName(d) + " at " + int(x) + "," + int(y) + state(d) + (i > 0 ? ", centre covered by " + cover : ""));
            tap(x,y);
            return;
         }
         if(i == 0)
         {
            cover = hit == null ? "nothing touchable" : path(hit);
         }
      }
      RGALog.write("click " + getQualifiedClassName(d) + " COVERED everywhere by " + cover + state(d) + ", bounds " + r);
      tap(r.x + r.width / 2,r.y + r.height / 2);
   }

   private static function state(d:Object) : String
   {
      return d.hasOwnProperty("isEnabled") ? (d["isEnabled"] ? ", enabled" : ", DISABLED") : "";
   }

   // True if obj is box or sits somewhere inside it.
   private static function inside(obj:DisplayObject, box:DisplayObject) : Boolean
   {
      while(obj != null)
      {
         if(obj == box)
         {
            return true;
         }
         obj = obj.parent;
      }
      return false;
   }

   // Class names from obj up to the screen, for the log.
   private static function path(obj:DisplayObject) : String
   {
      var a:Array = [];
      while(obj != null && a.length < 5)
      {
         a.push(getQualifiedClassName(obj));
         obj = obj.parent;
      }
      return a.join(" < ");
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
