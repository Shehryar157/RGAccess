import flash.utils.getDefinitionByName;

// Appends lines to <game>\RGAccess\rga_debug.log, for finding problems.
class RGALog
{
   public static function write(text:String) : void
   {
      try
      {
         var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
         var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
         var f:* = new FileC(FileC["applicationDirectory"].nativePath + "\\RGAccess\\rga_debug.log");
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
