import flash.geom.Rectangle;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import starling.core.Starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;

// Research tool: writes every visible object on the game's screen to rga_tree.txt
// (in the Local Store folder, next to rga_debug.log), one line each, indented by depth.
// Control+Shift+F12 dumps; it also dumps once by itself if a file named rga_autodump exists there.
class RGADump
{
   public static function wanted() : Boolean
   {
      try
      {
         var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
         return FileC["applicationStorageDirectory"].resolvePath("rga_autodump").exists;
      }
      catch(e:Error)
      {
      }
      return false;
   }

   public static function dump() : void
   {
      var out:Array = [];
      walk(Starling.current.stage,0,out);
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
      var f:* = FileC["applicationStorageDirectory"].resolvePath("rga_tree.txt");
      var s:* = new FS();
      s.open(f,"write");
      s.writeUTFBytes(out.join("\r\n"));
      s.close();
      RGALog.write("tree dumped, " + out.length + " objects");
   }

   private static function walk(obj:DisplayObject, depth:int, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      var line:String = depth + " " + getQualifiedClassName(obj);
      var o:Object = obj;
      try
      {
         var r:Rectangle = obj.getBounds(Starling.current.stage);
         line += " @" + int(r.x) + "," + int(r.y) + " " + int(r.width) + "x" + int(r.height);
      }
      catch(e:Error)
      {
      }
      if(obj.name != null && obj.name != "")
      {
         line += " name=" + obj.name;
      }
      if(o.hasOwnProperty("text"))
      {
         line += " text=[" + o["text"] + "]";
      }
      if(o.hasOwnProperty("label"))
      {
         line += " label=[" + o["label"] + "]";
      }
      if(o.hasOwnProperty("isEnabled") && !o["isEnabled"])
      {
         line += " disabled";
      }
      if(obj.alpha < 1)
      {
         line += " alpha=" + obj.alpha;
      }
      out.push(line);
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      if(c == null)
      {
         return;
      }
      for(var i:int = 0; i < c.numChildren; i++)
      {
         walk(c.getChildAt(i),depth + 1,out);
      }
   }
}
