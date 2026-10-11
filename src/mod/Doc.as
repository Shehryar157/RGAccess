import flash.events.KeyboardEvent;
import flash.utils.getDefinitionByName;

// One line of the virtual page.
// kind: "h1", "h2", "text", "button" or "building" (a building is also a button).
// key: a stable id, so the cursor stays on the same item when the page is rebuilt.
// action: function(ctrl:Boolean, shift:Boolean) run by Enter, or null.
class DocLine
{
   public var text:String;
   public var kind:String;
   // What a button line is called when spoken: "button", "check box, checked"...
   public var role:String = "button";
   public var key:String;
   public var action:Function;
   // The game object this line stands for. When set, action is called as action(target, ctrl, shift).
   public var target:Object = null;

   public function DocLine(text:String, kind:String, key:String, action:Function = null)
   {
      this.text = text;
      this.kind = kind;
      this.key = key;
      this.action = action;
   }

   public function get isButton() : Boolean
   {
      return action != null;
   }

   public function get isHeading() : Boolean
   {
      return kind == "h1" || kind == "h2";
   }

   // What the screen reader says when you land on this line, like NVDA in browse mode.
   public function get spoken() : String
   {
      if(kind == "h1")
      {
         return text + ", heading level 1";
      }
      if(kind == "h2")
      {
         return text + ", heading level 2";
      }
      if(isButton)
      {
         return text + ", " + role;
      }
      return text == "" ? "blank" : text;
   }
}

// A virtual web page: lines of text with a cursor and selection, read like NVDA browse mode.
class Doc
{
   // Filled in the constructor: JPEXS miscompiles "new" in a field's default value (VerifyError).
   public var lines:Array;
   public var line:int = 0;
   public var col:int = 0;
   // Selection anchor: where Shift-selection started. -1 means no selection.
   private var aLine:int = -1;
   private var aCol:int = 0;
   // Called as onAction(line) after Enter runs a line's action, so the result can be announced.
   public var onAction:Function = null;
   // Where the cursor was before visit() moved it, or null.
   public var backKey:String = null;
   // A heading goTo() is waiting for, and how many more page rebuilds it waits.
   private var wantKey:String = null;
   private var wantTries:int = 0;

   public function Doc()
   {
      super();
      lines = [new DocLine("Loading","text","loading")];
   }

   private function cur() : DocLine
   {
      return lines[line] as DocLine;
   }

   // Replace the page contents, keeping the cursor on the same item (matched by key).
   public function setLines(newLines:Array) : void
   {
      if(newLines == null || newLines.length == 0)
      {
         return;
      }
      var key:String = line < lines.length ? cur().key : null;
      var oldLine:int = line;
      lines = newLines;
      line = -1;
      for(var i:int = 0; i < lines.length; i++)
      {
         if(DocLine(lines[i]).key == key)
         {
            line = i;
            break;
         }
      }
      if(wantKey != null)
      {
         // A section goTo() asked the game to open: move to it once it is there.
         for(i = 0; i < lines.length; i++)
         {
            if(DocLine(lines[i]).key == wantKey)
            {
               line = i;
               col = 0;
               aLine = -1;
               wantTries = 0;
               break;
            }
         }
         if(--wantTries <= 0)
         {
            wantKey = null;
         }
      }
      if(line < 0 && backKey != null)
      {
         // The dialog or notification the cursor was taken to is gone: go back to where it was before.
         for(i = 0; i < lines.length; i++)
         {
            if(DocLine(lines[i]).key == backKey)
            {
               line = i;
               col = 0;
               break;
            }
         }
         backKey = null;
      }
      if(line < 0)
      {
         line = Math.min(oldLine,lines.length - 1);
      }
      col = Math.min(col,cur().text.length);
      if(aLine >= lines.length)
      {
         aLine = -1;
      }
      if(aLine >= 0)
      {
         aCol = Math.min(aCol,DocLine(lines[aLine]).text.length);
      }
   }

   // Something appeared on the page (a dialog, a notification): put the cursor on its first line.
   // Nothing is spoken here; the caller announces what appeared.
   public function visit(key:String) : void
   {
      for(var i:int = 0; i < lines.length; i++)
      {
         if(DocLine(lines[i]).key == key)
         {
            if(backKey == null && line < lines.length)
            {
               backKey = cur().key;
            }
            line = i;
            col = 0;
            aLine = -1;
            return;
         }
      }
   }

   public function readCurrent() : void
   {
      Speech.say(cur().spoken);
   }

   // Returns true if we used the key (so the game shouldn't see it).
   public function handleKey(e:KeyboardEvent) : Boolean
   {
      var k:uint = e.keyCode;
      var ctrl:Boolean = e.ctrlKey;
      var shift:Boolean = e.shiftKey;
      if(e.altKey)
      {
         return false;
      }
      // Arrow keys, Home and End: moving and Shift-selecting.
      if(k == 38 || k == 40 || k == 37 || k == 39 || k == 36 || k == 35)
      {
         moveCursor(k,ctrl,shift);
         return true;
      }
      if(ctrl)
      {
         if(k == 65) // Ctrl+A
         {
            aLine = 0;
            aCol = 0;
            line = lines.length - 1;
            col = cur().text.length;
            Speech.say("Select all");
            return true;
         }
         if(k == 67) // Ctrl+C
         {
            copySelection();
            return true;
         }
      }
      if(k == 72 && !ctrl) // H / Shift+H
      {
         jump(shift ? -1 : 1,"isHeading","heading");
         return true;
      }
      if(k == 66 && !ctrl) // B / Shift+B
      {
         jump(shift ? -1 : 1,"building","building");
         return true;
      }
      if(k == 82 && !ctrl) // R: the Resources section
      {
         jumpToKey("h:resources","No resources on this screen");
         return true;
      }
      if(k == 80 && !ctrl) // P: the Spells section
      {
         jumpToKey("h:]!6::3!5","No spells on this screen");
         return true;
      }
      if(k == 85 && !ctrl) // U: the Upgrades panel, opened first if it is closed
      {
         goTo("h:]!6::>F","","\"#:: !D#0","Upgrades");
         return true;
      }
      if(k == 83 && !ctrl) // S: the Statistics dialog, opened first if it is closed
      {
         goTo("","Statistics dialog","4X::9P#0","Statistics");
         return true;
      }
      if(k == 79 && !ctrl) // O: the Options dialog, opened first if it is closed
      {
         goTo("","Options dialog","4X::2!Z#0","Options");
         return true;
      }
      if(k == 9) // Tab / Shift+Tab
      {
         jump(shift ? -1 : 1,"isButton","button");
         return true;
      }
      if(k == 13 || k == 32) // Enter / Space
      {
         activate(ctrl,shift);
         return true;
      }
      return false;
   }

   private function matches(l:DocLine, what:String) : Boolean
   {
      if(what == "isHeading")
      {
         return l.isHeading;
      }
      if(what == "isButton")
      {
         return l.isButton;
      }
      return l.kind == what;
   }

   private function jump(dir:int, what:String, name:String) : void
   {
      for(var i:int = line + dir; i >= 0 && i < lines.length; i += dir)
      {
         if(matches(lines[i],what))
         {
            line = i;
            col = 0;
            aLine = -1;
            readCurrent();
            return;
         }
      }
      Speech.say(dir > 0 ? "No next " + name : "No previous " + name);
   }

   // Move to the one line with this key, wherever it is on the page.
   private function jumpToKey(key:String, missing:String) : void
   {
      for(var i:int = 0; i < lines.length; i++)
      {
         if(DocLine(lines[i]).key == key)
         {
            line = i;
            col = 0;
            aLine = -1;
            readCurrent();
            return;
         }
      }
      Speech.say(missing);
   }

   // Move to a section's heading (found by its key, or by its text when it has no key of its
   // own, like a dialog). When the section is closed, press the button that opens it instead:
   // a dialog takes the cursor by itself, a panel through wantKey.
   private function goTo(headKey:String, headText:String, buttonKey:String, name:String) : void
   {
      var i:int;
      var l:DocLine;
      for(i = 0; i < lines.length; i++)
      {
         l = lines[i];
         if(l.key == headKey || l.isHeading && l.text == headText)
         {
            line = i;
            col = 0;
            aLine = -1;
            readCurrent();
            return;
         }
      }
      for(i = 0; i < lines.length; i++)
      {
         l = lines[i];
         if(l.key == buttonKey && l.action != null)
         {
            if(headKey != "")
            {
               wantKey = headKey;
               wantTries = 5;
            }
            press(l,false,false);
            return;
         }
      }
      Speech.say(name + " is not on this screen");
   }

   private function activate(ctrl:Boolean, shift:Boolean) : void
   {
      press(cur(),ctrl,shift);
   }

   private function press(l:DocLine, ctrl:Boolean, shift:Boolean) : void
   {
      if(l.action == null)
      {
         return;
      }
      try
      {
         if(l.target != null)
         {
            l.action(l.target,ctrl,shift);
         }
         else
         {
            l.action(ctrl,shift);
         }
      }
      catch(err:Error)
      {
         Speech.say(err.message);
         return;
      }
      if(onAction != null)
      {
         onAction(l);
      }
   }

   private function moveCursor(k:uint, ctrl:Boolean, shift:Boolean) : void
   {
      var oldLine:int = line;
      var oldCol:int = col;
      if(shift && aLine < 0)
      {
         aLine = line;
         aCol = col;
      }
      if(!shift)
      {
         aLine = -1;
      }
      var text:String = cur().text;
      var byLine:Boolean = false;
      if(k == 38 || k == 40) // Up / Down. With Ctrl it's "by paragraph", and here every line is a paragraph.
      {
         var dir:int = k == 40 ? 1 : -1;
         line = Math.max(0,Math.min(lines.length - 1,line + dir));
         col = 0;
         byLine = true;
      }
      else if(k == 36) // Home (Ctrl: top of page)
      {
         if(ctrl)
         {
            line = 0;
            byLine = true;
         }
         col = 0;
      }
      else if(k == 35) // End (Ctrl: bottom of page)
      {
         if(ctrl)
         {
            line = lines.length - 1;
            byLine = true;
         }
         col = cur().text.length;
      }
      else if(k == 39) // Right
      {
         if(ctrl)
         {
            col = nextWord(text,col);
         }
         else
         {
            col++;
         }
         if(col > text.length)
         {
            if(line < lines.length - 1)
            {
               line++;
               col = 0;
            }
            else
            {
               col = text.length;
            }
         }
      }
      else if(k == 37) // Left
      {
         if(ctrl)
         {
            col = prevWord(text,col);
         }
         else
         {
            col--;
         }
         if(col < 0)
         {
            if(line > 0)
            {
               line--;
               col = cur().text.length;
            }
            else
            {
               col = 0;
            }
         }
      }
      if(shift)
      {
         var moved:String = textBetween(oldLine,oldCol,line,col);
         var growing:Boolean = dist(line,col) > dist(oldLine,oldCol);
         Speech.say((moved == "" ? "blank" : moved) + (growing ? " selected" : " unselected"));
      }
      else if(byLine)
      {
         readCurrent();
      }
      else if(ctrl && (k == 37 || k == 39))
      {
         Speech.say(wordAt(cur().text,col));
      }
      else
      {
         Speech.say(charName(cur().text,col));
      }
   }

   // Distance of a position from the selection anchor, used to tell selecting from unselecting.
   private function dist(l:int, c:int) : Number
   {
      return Math.abs((l - aLine) * 100000 + (c - aCol));
   }

   private function nextWord(t:String, c:int) : int
   {
      while(c < t.length && t.charAt(c) != " ")
      {
         c++;
      }
      while(c < t.length && t.charAt(c) == " ")
      {
         c++;
      }
      return c >= t.length ? t.length + 1 : c;
   }

   private function prevWord(t:String, c:int) : int
   {
      if(c == 0)
      {
         return -1;
      }
      c--;
      while(c > 0 && t.charAt(c) == " ")
      {
         c--;
      }
      while(c > 0 && t.charAt(c - 1) != " ")
      {
         c--;
      }
      return c;
   }

   private function wordAt(t:String, c:int) : String
   {
      var e:int = c;
      while(e < t.length && t.charAt(e) != " ")
      {
         e++;
      }
      var w:String = t.substring(c,e);
      return w == "" ? "blank" : w;
   }

   private function charName(t:String, c:int) : String
   {
      if(t.length == 0)
      {
         return "blank";
      }
      if(c >= t.length)
      {
         return "end of line";
      }
      var ch:String = t.charAt(c);
      if(ch == " ")
      {
         return "space";
      }
      if(ch == ",")
      {
         return "comma";
      }
      if(ch == ".")
      {
         return "dot";
      }
      if(ch == ":")
      {
         return "colon";
      }
      return ch;
   }

   // Text between two positions, in either order, with line breaks between lines.
   private function textBetween(l1:int, c1:int, l2:int, c2:int) : String
   {
      if(l1 > l2 || (l1 == l2 && c1 > c2))
      {
         var tl:int = l1;
         var tc:int = c1;
         l1 = l2;
         c1 = c2;
         l2 = tl;
         c2 = tc;
      }
      if(l1 == l2)
      {
         return DocLine(lines[l1]).text.substring(c1,c2);
      }
      var parts:Array = [DocLine(lines[l1]).text.substring(c1)];
      for(var i:int = l1 + 1; i < l2; i++)
      {
         parts.push(DocLine(lines[i]).text);
      }
      parts.push(DocLine(lines[l2]).text.substring(0,c2));
      return parts.join("\r\n");
   }

   private function copySelection() : void
   {
      if(aLine < 0)
      {
         Speech.say("No selection");
         return;
      }
      var t:String = textBetween(aLine,aCol,line,col);
      try
      {
         var CB:Class = getDefinitionByName("flash.desktop.Clipboard") as Class;
         CB["generalClipboard"].setData("air:text",t);
         Speech.say("Copied to clipboard");
      }
      catch(err:Error)
      {
         Speech.say("Copy failed");
      }
   }
}
