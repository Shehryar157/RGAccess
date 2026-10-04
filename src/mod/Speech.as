import flash.utils.getDefinitionByName;

// Starts the Python speech helper (rga_speech.py) and sends it lines of text.
// AIR-only classes are looked up by name because JPEXS doesn't know AIR's types.
class Speech
{
   private static var proc:* = null;

   public static function init(helperDir:String, pythonw:String) : void
   {
      try
      {
         var NP:Class = getDefinitionByName("flash.desktop.NativeProcess") as Class;
         var NPSI:Class = getDefinitionByName("flash.desktop.NativeProcessStartupInfo") as Class;
         var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
         if(!NP["isSupported"])
         {
            trace("RGA: NativeProcess not supported");
            return;
         }
         var info:* = new NPSI();
         info.executable = new FileC(pythonw);
         var args:Vector.<String> = new Vector.<String>();
         args.push(helperDir + "\\rga_speech.py");
         info.arguments = args;
         info.workingDirectory = new FileC(helperDir);
         proc = new NP();
         proc.start(info);
      }
      catch(e:Error)
      {
         trace("RGA: speech init failed: " + e.message);
      }
   }

   // Speak text. interrupt=true cuts off current speech, false queues after it.
   public static function say(text:String, interrupt:Boolean = true) : void
   {
      if(text == null || text == "")
      {
         return;
      }
      text = text.split("\r").join(" ").split("\n").join(" ");
      send((interrupt ? "S " : "Q ") + text);
   }

   private static function send(line:String) : void
   {
      if(proc == null || !proc.running)
      {
         return;
      }
      try
      {
         proc.standardInput.writeUTFBytes(line + "\n");
      }
      catch(e:Error)
      {
      }
   }
}
