import flash.utils.getDefinitionByName;

// Appends lines to rga_debug.log in the game's AIR "Local Store" folder
// (%APPDATA%\com.kongregate.mobile.realmgrinder.air\Local Store), the only place AIR lets the game write.
class RGALog
{
   public static function write(text:String) : void
   {
      try
      {
         var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
         var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
         var f:* = FileC["applicationStorageDirectory"].resolvePath("rga_debug.log");
         var s:* = new FS();
         s.open(f,"append");
         s.writeUTFBytes(new Date().toTimeString() + " " + text + "\r\n");
         s.close();
      }
      catch(e:Error)
      {
         trace(text);
      }
   }
}
