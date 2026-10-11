import starling.core.Starling;
import starling.display.DisplayObject;
import starling.display.DisplayObjectContainer;
import §"#§.§[!2§;

// Reads the game and builds the virtual page's lines.
// Game names (see notes/names.md):
//   §8G§.§@e§   coins          §8G§.§%<§   all buildings, in order
//   §[!2§        a building row on screen; .§%<§ is its building, .§?"L§() clicks it (.§8!Q§ is protected)
//   §8G§.§>!a§.§ u§(building, ctrl, shift, false, -1)  the game's buy function
//   building .§!a§ owned, .§`!X§(n) price of n, .§3y§ / .§1i§ name
//   §&c§.§8!Z§(n)  the game's own number formatting
class RGPage
{
   public static function build() : Array
   {
      var out:Array = [];
      out.push(new DocLine("Resources","h1","h:res"));
      out.push(new DocLine("Coins: " + fmt(§8G§.§@e§),"text","coins"));

      out.push(new DocLine("Buildings","h1","h:bld"));
      var rows:Array = [];
      if(Starling.current != null && Starling.current.stage != null)
      {
         findRows(Starling.current.stage,rows);
      }
      if(rows.length == 0)
      {
         out.push(new DocLine("No buildings on screen","text","bld:none"));
      }
      for each(var row:§[!2§ in rows)
      {
         out.push(buildingLine(row));
      }
      return out;
   }

   private static function buildingLine(row:§[!2§) : DocLine
   {
      var b:* = row.§%<§;
      var name:String = §&c§.§>!&§(b.id); // the game's own "name shown on the row" function
      var text:String = name + ", " + fmt(b.§!a§) + " owned, costs " + fmt(b.§`!X§(1));
      return new DocLine(text,"building","b:" + b.ids,function(ctrl:Boolean, shift:Boolean):void
      {
         if(!ctrl && !shift)
         {
            row.§?"L§(); // public wrapper around the row's own click
            return;
         }
         // The click itself is protected, so repeat its steps with the modifier keys.
         if(!row.isEnabled)
         {
            return;
         }
         §8G§.§>!a§.§ u§(b,ctrl,shift,false,-1);
         row.§!!G§();
      });
   }

   // Walk the screen's object tree (like os.walk) collecting visible building rows.
   private static function findRows(obj:DisplayObject, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      if(obj is §[!2§)
      {
         out.push(obj);
         return;
      }
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      if(c == null)
      {
         return;
      }
      for(var i:int = 0; i < c.numChildren; i++)
      {
         findRows(c.getChildAt(i),out);
      }
   }

   public static function fmt(n:Number) : String
   {
      try
      {
         return §&c§.§8!Z§(n);
      }
      catch(e:Error)
      {
      }
      return String(Math.floor(n));
   }
}
