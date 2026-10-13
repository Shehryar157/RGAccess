import flash.utils.getTimer;
import flash.utils.getDefinitionByName;

// Research remote control, so the game can be explored without anyone at the keyboard.
// Once a second it looks for rga_cmd.txt in the Local Store folder (next to rga_debug.log),
// runs its lines one per second, and writes what happened to rga_cmd_done.txt.
// tools/remote.py is the sending side. Commands:
//   press <text>     activate the first button whose line starts with <text>
//   presskey <key>   activate the line with exactly this key (keys are shown in page dumps)
//   tip <text>       report the tooltip of the first line that starts with <text>
//   dump <name>      write rga_tree_<name>.txt and rga_page_<name>.txt
//   wait <seconds>   do nothing for a while
//   click <x> <y>    a raw click at stage coordinates
//   static <class> <field>   show a static field of a game class
class RGARemote
{
   private static var queue:Array = null;
   private static var results:Array = null;
   private static var waitTicks:int = 0;

   public static function tick(doc:Doc) : void
   {
      try
      {
         if(queue == null || queue.length == 0)
         {
            load();
            return;
         }
         if(waitTicks > 0)
         {
            waitTicks--;
            return;
         }
         var cmd:String = String(queue.shift());
         results.push(cmd + " -> " + run(cmd,doc));
         if(queue.length == 0)
         {
            write("rga_cmd_done.txt",results.join("\r\n"));
         }
      }
      catch(e:Error)
      {
         RGALog.write("remote failed: " + e.getStackTrace());
         queue = null;
      }
   }

   private static function load() : void
   {
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var f:* = FileC["applicationStorageDirectory"].resolvePath("rga_cmd.txt");
      if(!f.exists)
      {
         return;
      }
      var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
      var s:* = new FS();
      s.open(f,"read");
      var text:String = s.readUTFBytes(s.bytesAvailable);
      s.close();
      f.deleteFile();
      queue = [];
      results = [];
      var parts:Array = text.split("\n");
      for(var i:int = 0; i < parts.length; i++)
      {
         var p:String = RGPage.clean(parts[i]);
         if(p != "")
         {
            queue.push(p);
         }
      }
      RGALog.write("remote: " + queue.length + " commands");
   }

   // The last (topmost) text box under obj, or null.
   private static function findInput(obj:Object) : Object
   {
      if(getQualifiedClassName(obj) == "feathers.controls::TextInput")
      {
         return obj;
      }
      if(!obj.hasOwnProperty("numChildren"))
      {
         return null;
      }
      for(var i:int = int(obj["numChildren"]) - 1; i >= 0; i--)
      {
         var found:Object = findInput(obj["getChildAt"](i));
         if(found != null)
         {
            return found;
         }
      }
      return null;
   }

   private static function run(cmd:String, doc:Doc) : String
   {
      var sp:int = cmd.indexOf(" ");
      var verb:String = sp < 0 ? cmd : cmd.substr(0,sp);
      var arg:String = sp < 0 ? "" : cmd.substr(sp + 1);
      var l:DocLine;
      if(verb == "static")
      {
         // static <class> <field>: the value of a static field of a game class, for research.
         var cf:Array = arg.split(" ");
         return String(getDefinitionByName(cf[0])[cf[1]]);
      }
      if(verb == "wait")
      {
         waitTicks = int(arg);
         return "ok";
      }
      if(verb == "dump")
      {
         RGADump.dump(arg);
         RGPage.dump(doc.lines,arg);
         return doc.lines.length + " lines, list read in " + RGPage.listMs + " ms";
      }
      if(verb == "key" || verb == "where")
      {
         // key <code>: type a key on the page (80 = P), as the keyboard would; where: no key.
         // Both answer with the line the cursor is on, so cursor moves can be tested.
         if(verb == "key")
         {
            doc.handleKey(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,int(arg)));
         }
         return "cursor: " + DocLine(doc.lines[doc.line]).text;
      }
      if(verb == "time")
      {
         // How long building the page takes: reading every list again, and with lists kept.
         var t0:int = getTimer();
         var n:int;
         for(n = 0; n < 10; n++)
         {
            RGPage.listStale = true;
            RGPage.build();
         }
         var full:int = getTimer() - t0;
         t0 = getTimer();
         for(n = 0; n < 10; n++)
         {
            RGPage.build();
         }
         return "full build " + full / 10 + " ms, kept lists " + (getTimer() - t0) / 10 + " ms, " + doc.lines.length + " lines";
      }
      if(verb == "settext")
      {
         // settext <text>: put text into the topmost text box on screen (Hard Reset wants "RESET").
         var box:Object = findInput(Starling.current.stage);
         if(box == null)
         {
            return "no text box";
         }
         box["text"] = arg;
         box.dispatchEventWith("change");
         return "text set";
      }
      if(verb == "click")
      {
         var xy:Array = arg.split(" ");
         RGPage.tap(Number(xy[0]),Number(xy[1]));
         return "ok";
      }
      // cpress and spress press with Control or Shift held.
      if(verb == "press" || verb == "presskey" || verb == "cpress" || verb == "spress")
      {
         l = find(doc,arg,verb == "presskey",true);
         if(l == null)
         {
            return "NOT FOUND";
         }
         try
         {
            if(l.target != null)
            {
               l.action(l.target,verb == "cpress",verb == "spress");
            }
            else
            {
               l.action(false,false);
            }
         }
         catch(err:Error)
         {
            return "FAILED on " + l.text + ": " + err.message;
         }
         RGA.afterAction(l);
         return "pressed " + l.text + " [" + l.key + "]";
      }
      if(verb == "tip")
      {
         l = find(doc,arg,false,false);
         if(l == null)
         {
            return "NOT FOUND";
         }
         return l.text + ": " + RGPage.tooltip(l.target).join(" | ");
      }
      return "unknown command";
   }

   private static function find(doc:Doc, what:String, byKey:Boolean, needAction:Boolean) : DocLine
   {
      what = what.toLowerCase();
      for(var i:int = 0; i < doc.lines.length; i++)
      {
         var l:DocLine = DocLine(doc.lines[i]);
         if(needAction && l.action == null)
         {
            continue;
         }
         if(byKey ? l.key.toLowerCase() == what : l.text.toLowerCase().indexOf(what) == 0)
         {
            return l;
         }
      }
      return null;
   }

   private static function write(name:String, text:String) : void
   {
      var FileC:Class = getDefinitionByName("flash.filesystem.File") as Class;
      var FS:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
      var s:* = new FS();
      s.open(FileC["applicationStorageDirectory"].resolvePath(name),"write");
      s.writeUTFBytes(text);
      s.close();
   }
}
