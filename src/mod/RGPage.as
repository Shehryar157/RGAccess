import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.renderers.IGroupedListHeaderRenderer;
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
      lastCls = "";
      toastText = "";
      var stage:DisplayObjectContainer = Starling.current.stage;
      // Everything on the stage after the first child is a dialog on top of the game.
      for(i = stage.numChildren - 1; i >= 1; i--)
      {
         var part:Array = [];
         var top:DisplayObject = stage.getChildAt(i);
         // A hover tooltip also sits on top of the game, but it is not a dialog. The T key reads tooltips.
         if(!top.touchable || getQualifiedClassName(top) == TOOLTIP)
         {
            continue;
         }
         walk(top,part);
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
      if(obj is IGroupedListHeaderRenderer)
      {
         // The title of one section of a list, like "Unpurchased Upgrades".
         var heads:Array = [];
         collectLabels(obj,heads);
         if(heads.length > 0)
         {
            out.push(new DocLine(heads.join(", "),"h2",nextKey("h2:" + heads[0])));
         }
         return;
      }
      if((obj is §6+§ || obj is Button || isItem(obj)) && (c == null || !hasControl(c)))
      {
         var line:DocLine = controlLine(obj,cls);
         // Several identical buttons in a row (the assistants on the realm) are read once.
         if(out.length > 0 && DocLine(out[out.length - 1]).text == line.text && lastCls == cls && line.kind != "building")
         {
            return;
         }
         lastCls = cls;
         // A picture that cannot be touched is decoration, like the houses drawn on the realm.
         if((!obj.touchable || obj is Button) && line.text.indexOf("Unlabelled") == 0)
         {
            return;
         }
         // The parts of a scroll bar are thin, nameless buttons; arrows scroll here instead.
         if(obj is Button && line.text.indexOf("Close") == 0 && (obj.width < 12 || obj.height < 12))
         {
            return;
         }
         out.push(line);
         return;
      }
      var head:String = sectionName(cls);
      var headAt:int = -1;
      if(head != "" && cls != STATUS)
      {
         headAt = out.length;
         out.push(new DocLine(head,"h1","h:" + cls));
      }
      if(cls == TOAST)
      {
         // A banner the game slides in, like "You unlocked the trophy...". RGA speaks it.
         var banner:Array = [];
         collectLabels(obj,banner);
         toastText = banner.join(" ");
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
      var kids:Array = [];
      for(i = 0; i < c.numChildren; i++)
      {
         kids.push(c.getChildAt(i));
      }
      if(cls.indexOf("DataViewPort") >= 0)
      {
         // A list keeps its rows in any order; read them as they look, top to bottom, left to right.
         kids.sort(byPosition);
      }
      for(i = 0; i < kids.length; i++)
      {
         walk(kids[i],out);
      }
      if(headAt >= 0 && out.length == headAt + 1)
      {
         // Nothing under the heading, so leave the heading out too.
         out.pop();
      }
   }

   private static var lastCls:String = "";

   private static function byPosition(a:DisplayObject, b:DisplayObject) : int
   {
      if(Math.abs(a.y - b.y) > 5)
      {
         return a.y < b.y ? -1 : 1;
      }
      return a.x < b.x ? -1 : (a.x > b.x ? 1 : 0);
   }

   // A row of one of the game's lists (an upgrade, a trophy...). Every such row has two
   // functions: ["[B"]() gives its title and ["@\""]() its description.
   private static function isItem(obj:Object) : Boolean
   {
      return obj.hasOwnProperty("[B") && obj.hasOwnProperty("@\"");
   }

   private static var STATUS:String = "]!6::+r";
   private static var MANA:String = "]!6::7R";
   private static var TOOLTIP:String = "1Z::!s";
   private static var TOAST:String = "'?::8!L";
   // Text of the notification banner on screen, or "".
   public static var toastText:String = "";

   // Names for buttons that are only a picture: no text and no tooltip title.
   // Found from the picture each class loads (UIShop, BGView, UIAudio, UICog) and the dialog it opens.
   private static function iconName(obj:DisplayObject, cls:String) : String
   {
      if(cls == "\"#::>W")
      {
         // A faction coin counter; the game keeps the coin names in a list.
         try
         {
            var names:Object = getDefinitionByName("-D")["45"];
            return String(names[Object(obj)["@e"]]) + " coins";
         }
         catch(e:Error)
         {
         }
         return "";
      }
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
      if(cls == "]!6::>F")
      {
         return "Upgrades panel";
      }
      if(cls == "]!6::8T")
      {
         return "Trophies panel";
      }
      if(cls == "]!6::3!5")
      {
         return "Spells";
      }
      if(cls == TOAST)
      {
         return "Notification";
      }
      if(cls == STATUS)
      {
         return "Resources";
      }
      if(cls == "]!6::7R")
      {
         return "Mana and spells";
      }
      if(cls.indexOf("]!6::") == 0)
      {
         // A panel of the main screen that has no name here yet.
         return "Panel";
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
      else if(cls == "\"#::>W" && iconName(obj,cls) != "")
      {
         text = iconName(obj,cls) + ", " + text;
      }
      if(isItem(obj))
      {
         // The first tooltip line after the title is the price, when there is one.
         var tip:Array = tooltip(obj);
         if(tip.length > 1 && String(tip[1]).indexOf(":") > 0 && String(tip[1]).length < 60)
         {
            text += ", " + tip[1];
         }
         // The game draws a row it will not let you buy half transparent.
         var box:DisplayObjectContainer = obj as DisplayObjectContainer;
         if(box != null && box.numChildren > 0 && box.getChildAt(0).alpha < 0.99)
         {
            text += tip.length > 1 && String(tip[1]).indexOf("Cost") == 0 ? ", cannot afford" : ", locked";
         }
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
      if(text == "Close" && o.hasOwnProperty("isEnabled") && !o["isEnabled"])
      {
         text = "Unlabelled";
      }
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
      if(isItem(obj))
      {
         try
         {
            return clean(String(obj["[B"]()));
         }
         catch(e0:Error)
         {
         }
         return "";
      }
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
      if(target == null || !(target is §6+§ || isItem(target)))
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
         var body:String = String(isItem(target) ? target["@\""]() : target["9!0"]());
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
      throw new Error("Blocked, something is on top of this button. If a dialog is open, close it first. It is at the top of the page.");
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
   public static function tap(x:Number, y:Number) : void
   {
      var tp:* = Starling.current.touchProcessor;
      tp.enqueue(0,"hover",x,y);
      tp.enqueue(0,"began",x,y);
      tp.enqueue(0,"ended",x,y);
      // Move the pretend mouse off the screen again, or the game keeps a hover tooltip open.
      tp.enqueue(0,"hover",-5000,-5000);
   }

   // Research: write the current page to rga_page.txt next to the log.
   // Each line as spoken, then its key in brackets, then its tooltip lines indented.
   public static function dump(lines:Array, name:String = "") : void
   {
      var a:Array = [];
      for(var i:int = 0; i < lines.length; i++)
      {
         var l:DocLine = DocLine(lines[i]);
         a.push(l.spoken + "   [" + l.key + "]");
         if(l.target != null)
         {
            var tip:Array = tooltip(l.target);
            for(var j:int = 0; j < tip.length; j++)
            {
               a.push("      tip: " + tip[j]);
            }
         }
      }
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
      var s:* = new FS();
      s.open(FileC["applicationStorageDirectory"].resolvePath("rga_page" + (name == "" ? "" : "_" + name) + ".txt"),"write");
      s.writeUTFBytes(a.join("\r\n"));
      s.close();
   }
}
