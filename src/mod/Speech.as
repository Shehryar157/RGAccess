import flash.utils.getDefinitionByName;

// Starts the speech helper (rga_speech.exe, or rga_speech.py from source) and sends it lines of text.
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
            RGALog.write("NativeProcess not supported");
            return;
         }
         var info:* = new NPSI();
         // An installed mod carries the helper as a program (no Python needed);
         // a build from source runs the script with pythonw.
         var exe:* = new FileC(helperDir + "\\rga_speech.exe");
         var args:Vector.<String> = new Vector.<String>();
         if(exe.exists)
         {
            info.executable = exe;
         }
         else
         {
            info.executable = new FileC(pythonw);
            args.push(helperDir + "\\rga_speech.py");
         }
         info.arguments = args;
         info.workingDirectory = new FileC(helperDir);
         proc = new NP();
         proc.start(info);
      }
      catch(e:Error)
      {
         RGALog.write("speech init failed: " + e.getStackTrace());
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
