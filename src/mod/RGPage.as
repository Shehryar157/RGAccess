import feathers.controls.Button;
import feathers.controls.Callout;
import feathers.controls.GroupedList;
import feathers.controls.Label;
import feathers.controls.ProgressBar;
import feathers.controls.renderers.IGroupedListHeaderRenderer;
import feathers.controls.renderers.IGroupedListItemRenderer;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.getDefinitionByName;
import flash.utils.getQualifiedClassName;
import flash.utils.getTimer;
import flash.utils.Dictionary;
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
      var names:Array = [];
      var i:int;
      var j:int;
      var cont:DocLine = null;
      var stays:Boolean = false;
      var topName:String = "";
      counts = new Object();
      manaDone = false;
      lastCls = "";
      toastText = "";
      dialogName = "";
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
         dialogName = "";
         walk(top,part);
         part = table(part);
         if(part.length > 0)
         {
            var hasButton:Boolean = false;
            // Only the dialog on top is announced; one opened from another (Options, then Language) hides the first.
            var first:Boolean = pop.length == 0;
            for(j = 0; j < part.length; j++)
            {
               if(DocLine(part[j]).isButton)
               {
                  hasButton = true;
                  if(first)
                  {
                     names.push(DocLine(part[j]).text);
                  }
               }
               else if(first)
               {
                  said.push(DocLine(part[j]).text);
               }
            }
            if(first)
            {
               topName = dialogName;
            }
            // Every open dialog gets its own heading, the one on top first.
            pop.push(new DocLine(dialogName == "" ? "Dialog" : dialogName + " dialog","h1",first ? "h:dialog" : nextKey("h:dialog")));
            if(!hasButton)
            {
               // A message you dismiss by clicking it, like the advisor.
               var go:DocLine = new DocLine("Continue","button",nextKey("continue"),click);
               go.target = stage.getChildAt(i);
               part.push(go);
               cont = go;
               // The advisor is a Callout. For a step that waits for one action ("click the
               // Realm") the game switches off closing it by a click, so Continue would do nothing.
               var co:Callout = stage.getChildAt(i) as Callout;
               stays = co != null && !co.closeOnTouchBeganOutside && !co.closeOnTouchEndedOutside;
            }
            pop = pop.concat(part);
         }
      }
      // A dialog without any text, like the buy amount chooser, is announced by its buttons.
      popupText = said.length > 0 ? said.join(" ") : names.join(", ");
      if(topName != "")
      {
         // Statistics and Options are long and their numbers keep changing: announce the name only.
         popupText = topName;
      }
      out = out.concat(pop);
      var mainAt:int = out.length;
      if(stage.numChildren > 0)
      {
         walk(stage.getChildAt(0),out);
      }
      if(cont != null)
      {
         spotlight(cont,out,mainAt);
         if(stays && cont.target is Callout)
         {
            // No lit button was found either: say so instead of offering a dead button.
            cont.text = "No Continue button: this message closes by itself when you do what it asks.";
            cont.kind = "text";
            cont.action = null;
            cont.target = null;
         }
      }
      if(out.length == 0)
      {
         out.push(new DocLine("Nothing on screen yet","text","empty"));
      }
      listStale = false;
      lastLines = out;
      return out;
   }

   // The page as last built, so a blocked press can say what can be pressed instead.
   private static var lastLines:Array = null;

   // The point inside a control where a press reaches it, or null when something covers it
   // everywhere. Asks the engine what is on top at a few points, the centre first.
   private static function reach(d:DisplayObject) : Point
   {
      var r:Rectangle = d.getBounds(Starling.current.stage);
      var fx:Array = [0.5,0.25,0.75,0.5,0.5,0.1,0.9,0.1,0.9];
      var fy:Array = [0.5,0.5,0.5,0.25,0.75,0.15,0.15,0.85,0.85];
      for(var i:int = 0; i < fx.length; i++)
      {
         var p:Point = new Point(r.x + r.width * fx[i],r.y + r.height * fy[i]);
         var hit:DisplayObject = Starling.current.stage.hitTest(p,true);
         if(hit != null && inside(hit,d))
         {
            return p;
         }
      }
      return null;
   }

   // True if a press on this line would get through. A list item counts when its row is on
   // screen now and uncovered (the tutorial lights up one upgrade).
   private static function canReach(l:DocLine) : Boolean
   {
      if(l.target is DisplayObject)
      {
         return reach(DisplayObject(l.target)) != null;
      }
      var it:ListItem = l.target as ListItem;
      if(it == null || it.index < 0)
      {
         return false;
      }
      var row:Object = findRow(it.list,it.item);
      return row != null && reach(DisplayObject(row)) != null;
   }

   // Names of the page's buttons that can be pressed right now, at most five (the tutorial
   // darkens the screen and leaves one or two). Empty when there are none or more than five.
   private static function pressable() : Array
   {
      var a:Array = [];
      if(lastLines == null)
      {
         return a;
      }
      for(var i:int = 0; i < lastLines.length; i++)
      {
         var l:DocLine = DocLine(lastLines[i]);
         if(l.action == null || !canReach(l))
         {
            continue;
         }
         a.push(l.text);
         if(a.length > 5)
         {
            return [];
         }
      }
      return a;
   }

   // A tutorial message can darken the whole screen except one button ("Click this button...")
   // and wait until that button is pressed; clicking the message itself does nothing then.
   // So if only a few of the page's buttons can be reached, Continue presses the first of them.
   private static function spotlight(go:DocLine, lines:Array, from:int) : void
   {
      var total:int = 0;
      var reachable:int = 0;
      var first:DocLine = null;
      for(var i:int = from; i < lines.length; i++)
      {
         var l:DocLine = DocLine(lines[i]);
         if(l.action == null || l == go)
         {
            continue;
         }
         total++;
         if(canReach(l))
         {
            reachable++;
            if(first == null)
            {
               first = l;
            }
         }
      }
      if(first != null && reachable <= 3 && reachable < total)
      {
         go.text = "Continue, presses " + first.text;
         go.target = first.target;
         go.action = first.action;
      }
   }

   private static function walk(obj:DisplayObject, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      if(obj is Label)
      {
         var t:String = keys(clean(String(Object(obj)["text"])));
         if(t != "")
         {
            var tl:DocLine = new DocLine(t,"text",nextKey("t"));
            tl.place = obj;
            out.push(tl);
         }
         return;
      }
      if(obj is ProgressBar)
      {
         // A bar on its own, not inside a control (those are read with their control).
         out.push(new DocLine("Progress " + Math.round(percent(ProgressBar(obj))) + "%","text",nextKey("bar")));
         return;
      }
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      var cls:String = getQualifiedClassName(obj);
      if(cls == MANA && manaDone)
      {
         return;
      }
      if(cls == "1Z::8!-")
      {
         dialogName = "Statistics";
      }
      if(cls == "1Z::?K")
      {
         dialogName = "Options";
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
      if(obj is GroupedList && walkList(GroupedList(obj),out))
      {
         return;
      }
      if(cls == "feathers.controls::TextInput")
      {
         // A text box (Hard Reset wants "RESET" typed). Enter on the line starts typing: RGA.startEdit.
         var typed:String = clean(String(Object(obj)["text"]));
         var ed:DocLine = new DocLine(typed == "" ? "empty" : typed,"button",nextKey("edit"),RGA.startEdit);
         ed.role = "edit box";
         ed.target = obj;
         out.push(ed);
         return;
      }
      if(cls.indexOf("::Slider") > 0)
      {
         // A slider is dragged with the mouse; give it a lower and a higher button instead.
         // It is named after the text before it ("Volume: 50%"), which also shows the new value.
         var sn:String = "Slider";
         if(out.length > 0 && !DocLine(out[out.length - 1]).isButton)
         {
            sn = DocLine(out[out.length - 1]).text.split(":")[0];
         }
         var lower:DocLine = new DocLine(sn + " lower","button",nextKey("slider-"),slideDown);
         lower.target = obj;
         out.push(lower);
         var higher:DocLine = new DocLine(sn + " higher","button",nextKey("slider+"),slideUp);
         higher.target = obj;
         out.push(higher);
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
         var realm:DocLine = new DocLine("Click to earn coins","button","realm",clickRealm);
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
   // How long the last list took to read, in milliseconds (shown by the remote "dump" command).
   public static var listMs:int = 0;

   // A list (upgrades, trophies) only creates the rows that fit on screen and reuses them while
   // scrolling. So the rows are not read. Instead every item is taken from the list's data, which
   // is an Array of groups {header:{text, collapsed}, children:[items]}, and each item is shown in
   // one borrowed row just long enough to read it. Returns false if the list cannot be read this way.
   private static function walkList(list:GroupedList, out:Array) : Boolean
   {
      var row:Object = findRow(list,null);
      var groups:Array = list.dataProvider == null ? null : list.dataProvider.data as Array;
      if(row == null || groups == null)
      {
         return false;
      }
      var t0:int = getTimer();
      // Reading every item is the slowest thing the mod does, so a list of items is kept for
      // LIST_FRESH ms and read again only when it gained or lost items, or after a press.
      var sig:String = listSig(groups);
      if(listCache == null)
      {
         listCache = new Dictionary(true);
      }
      var kept:Object = listCache[list];
      var n:int;
      var k:String;
      if(kept != null && !listStale && kept.sig == sig && t0 - kept.time < LIST_FRESH)
      {
         for(n = 0; n < kept.lines.length; n++)
         {
            out.push(kept.lines[n]);
         }
         for(k in kept.counts)
         {
            counts[k] = kept.counts[k];
         }
         return true;
      }
      var startAt:int = out.length;
      var allItems:Boolean = true;
      var cls:String = getQualifiedClassName(row);
      var own:Object = row.data;
      var failed:Error = null;
      try
      {
         for(var g:int = 0; g < groups.length; g++)
         {
            var head:Object = groups[g].hasOwnProperty("header") ? groups[g]["header"] : null;
            if(head != null)
            {
               // Enter on the heading does what clicking it does in the game: close or open the section.
               var title:String = clean(String(head["text"]));
               var hl:DocLine = new DocLine(title + (head["collapsed"] ? ", collapsed" : ""),"h2",nextKey("h2:" + title),clickItem);
               hl.target = new ListItem(list,g,-1,head);
               out.push(hl);
            }
            var items:Array = groups[g]["children"] as Array;
            for(var i:int = 0; items != null && i < items.length; i++)
            {
               row.data = items[i];
               row.validate();
               if(!isItem(row))
               {
                  // A row that is only text, like a block of statistics: every label is a line.
                  // Its numbers change all the time, so such a list is never kept.
                  allItems = false;
                  var texts:Array = [];
                  collectLabels(DisplayObject(row),texts);
                  for(var j:int = 0; j < texts.length; j++)
                  {
                     out.push(new DocLine(texts[j],"text",nextKey("t")));
                  }
                  continue;
               }
               var line:DocLine = controlLine(DisplayObject(row),cls);
               // Several identical items in a row (trophies still shown as ???) are read once.
               if(out.length > 0 && DocLine(out[out.length - 1]).text == line.text)
               {
                  continue;
               }
               line.target = new ListItem(list,g,i,items[i]);
               line.action = clickItem;
               out.push(line);
            }
         }
      }
      catch(e:Error)
      {
         failed = e;
      }
      row.data = own;
      row.validate();
      listMs = getTimer() - t0;
      if(failed != null)
      {
         throw failed;
      }
      if(allItems)
      {
         kept = new Object();
         kept.sig = sig;
         kept.time = getTimer();
         kept.lines = out.slice(startAt);
         kept.counts = new Object();
         for(k in counts)
         {
            kept.counts[k] = counts[k];
         }
         listCache[list] = kept;
      }
      else
      {
         delete listCache[list];
      }
      return true;
   }

   // Lists that were read a moment ago: list -> {sig, time, lines, counts}.
   private static var listCache:Dictionary = null;
   private static var LIST_FRESH:int = 2000;
   // Set to make the next build read every list again (after a press, which may have bought something).
   public static var listStale:Boolean = false;

   // The shape of a list: how many items each section has and whether it is collapsed.
   private static function listSig(groups:Array) : String
   {
      var s:String = "";
      for(var g:int = 0; g < groups.length; g++)
      {
         var head:Object = groups[g].hasOwnProperty("header") ? groups[g]["header"] : null;
         var items:Array = groups[g]["children"] as Array;
         s += (items == null ? 0 : items.length) + (head != null && head["collapsed"] ? "c," : "o,");
      }
      return s;
   }

   // The row inside box that shows this item (or, with item null, the first row that shows anything).
   private static function findRow(box:DisplayObjectContainer, item:Object) : Object
   {
      for(var i:int = 0; i < box.numChildren; i++)
      {
         var k:Object = box.getChildAt(i);
         if(k is IGroupedListHeaderRenderer || k is IGroupedListItemRenderer || isItem(k))
         {
            // A section title also has a title and a description, but it is not a row to borrow.
            if(item == null ? !(k is IGroupedListHeaderRenderer) && k.visible && k.data != null : k.data === item)
            {
               return k;
            }
         }
         else if(k is DisplayObjectContainer)
         {
            var found:Object = findRow(DisplayObjectContainer(k),item);
            if(found != null)
            {
               return found;
            }
         }
      }
      return null;
   }

   // Enter on a list item or list heading: scroll the list to it, so the game creates its row, and click that.
   public static function clickItem(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      var it:ListItem = ListItem(target);
      it.list.scrollToDisplayIndex(it.group,it.index,0);
      // The first pass does the scrolling, the next creates the rows for the new position.
      it.list.validate();
      it.list.validate();
      it.list.validate();
      var row:Object = findRow(it.list,it.item);
      if(row == null)
      {
         throw new Error("Could not bring this item on screen.");
      }
      click(row,ctrl,shift);
   }

   // The tooltip of a list item, read through a borrowed row like walkList does.
   private static function itemTip(it:ListItem) : Array
   {
      var row:Object = findRow(it.list,null);
      if(row == null || it.index < 0)
      {
         return [];
      }
      var own:Object = row.data;
      row.data = it.item;
      row.validate();
      var tip:Array = tooltip(row);
      row.data = own;
      row.validate();
      return tip;
   }

   // A dialog laid out as a table (the Royal Market: "Faction", "Bonus", "Cost in FC", then a
   // row per faction with a BUY button) would read cell by cell, and the numbers lose their
   // column. A table is found by position: a row of two or more texts, with at least two rows
   // under it whose texts each sit under one of them. Every such row becomes one line,
   // "Faction: Fairy (0), Bonus: 10%, Cost in FC: 1x 20, BUY", which is the row's button
   // when it has exactly one. The heading row itself is dropped.
   private static function table(part:Array) : Array
   {
      var stage:DisplayObject = Starling.current.stage;
      var cells:Array = [];
      var i:int;
      var j:int;
      for(i = 0; i < part.length; i++)
      {
         var l:DocLine = part[i];
         var d:DisplayObject = (l.place != null ? l.place : l.target) as DisplayObject;
         if(d == null || l.isHeading || d.stage == null)
         {
            continue;
         }
         var r:Rectangle = d.getBounds(stage);
         cells.push({line:l, x:r.x + r.width / 2, y:r.y + r.height / 2});
      }
      cells.sort(byCellY);
      var rows:Array = [];
      var row:Array = null;
      for(i = 0; i < cells.length; i++)
      {
         if(row == null || Math.abs(cells[i].y - row[0].y) > 8)
         {
            row = [];
            rows.push(row);
         }
         row.push(cells[i]);
      }
      for(i = 0; i < rows.length; i++)
      {
         rows[i].sort(byCellX);
      }
      for(var h:int = 0; h < rows.length; h++)
      {
         var head:Array = rows[h];
         if(head.length < 2 || !allText(head))
         {
            continue;
         }
         var body:Array = [];
         for(j = h + 1; j < rows.length && columnsOf(rows[j],head); j++)
         {
            body.push(rows[j]);
         }
         if(body.length >= 2)
         {
            return tableLines(part,head,body);
         }
      }
      return part;
   }

   private static function byCellY(a:Object, b:Object) : int
   {
      return a.y < b.y ? -1 : (a.y > b.y ? 1 : 0);
   }

   private static function byCellX(a:Object, b:Object) : int
   {
      return a.x < b.x ? -1 : (a.x > b.x ? 1 : 0);
   }

   private static function allText(row:Array) : Boolean
   {
      for(var i:int = 0; i < row.length; i++)
      {
         if(DocLine(row[i].line).action != null)
         {
            return false;
         }
      }
      return true;
   }

   // Gives every text of the row its column (cell.col, the heading's index) and answers
   // whether the row belongs to the table: at least two texts, each close under a heading.
   // Buttons may sit anywhere (the BUY column has no heading).
   private static function columnsOf(row:Array, head:Array) : Boolean
   {
      var gap:Number = 100000;
      var i:int;
      for(i = 1; i < head.length; i++)
      {
         gap = Math.min(gap,head[i].x - head[i - 1].x);
      }
      var texts:int = 0;
      for(i = 0; i < row.length; i++)
      {
         if(DocLine(row[i].line).action != null)
         {
            continue;
         }
         var best:int = -1;
         var dist:Number = gap / 2;
         for(var k:int = 0; k < head.length; k++)
         {
            if(Math.abs(row[i].x - head[k].x) < dist)
            {
               dist = Math.abs(row[i].x - head[k].x);
               best = k;
            }
         }
         if(best < 0)
         {
            return false;
         }
         row[i].col = best;
         texts++;
      }
      return texts >= 2;
   }

   private static function tableLines(part:Array, head:Array, body:Array) : Array
   {
      var used:Dictionary = new Dictionary();
      var made:Array = [];
      var i:int;
      var j:int;
      for(i = 0; i < head.length; i++)
      {
         used[head[i].line] = true;
      }
      for(i = 0; i < body.length; i++)
      {
         var says:Array = [];
         var buttons:Array = [];
         var first:DocLine = null;
         for(j = 0; j < body[i].length; j++)
         {
            var l:DocLine = body[i][j].line;
            used[l] = true;
            if(l.action != null)
            {
               buttons.push(l);
               continue;
            }
            if(first == null)
            {
               first = l;
            }
            says.push(DocLine(head[body[i][j].col].line).text + ": " + l.text);
         }
         if(buttons.length == 1)
         {
            DocLine(buttons[0]).text = says.join(", ") + ", " + DocLine(buttons[0]).text;
            made.push(buttons[0]);
         }
         else
         {
            first.text = says.join(", ");
            made.push(first);
            made = made.concat(buttons);
         }
      }
      var out:Array = [];
      for(i = 0; i < part.length; i++)
      {
         if(used[part[i]] != true)
         {
            out.push(part[i]);
         }
         else if(made != null)
         {
            out = out.concat(made); // the whole table goes where its first line was
            made = null;
         }
      }
      return out;
   }

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
   public static var TOAST:String = "'?::8!L";
   // Text of the notification banner on screen, or "".
   public static var toastText:String = "";
   // Name of the dialog on screen when it has no title of its own ("Statistics"), or "".
   private static var dialogName:String = "";

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
      if(cls == "]!6::@h")
      {
         return "Events panel";
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
         // With a buy amount above 1 the game writes the price as "4x 116": 4 of them for 116 coins.
         var many:Array = String(labels[1]).match(new RegExp("^(\\S+)x (.+)$"));
         var cost:String = many == null ? "costs " + labels[1] : "costs " + many[2] + " for " + many[1];
         text = labels[0] + ", " + labels[3] + " owned, " + cost + ", " + labels[2] + " of production";
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
      if(text == "???")
      {
         // The game hides the name of something not unlocked yet, and a screen reader skips
         // question marks. The one below Abdication is Reincarnation.
         text = cls == "4X::59" ? "Reincarnation, locked" : "Locked";
      }
      if(o.hasOwnProperty("isEnabled") && !o["isEnabled"])
      {
         text += ", unavailable";
      }
      text += barText(obj,cls);
      var l:DocLine = new DocLine(text,kind,nextKey(cls),click);
      l.target = obj;
      // A tick box or one of a group of choices says which state it is in.
      if(cls.indexOf("::Check") > 0)
      {
         l.role = o["isSelected"] ? "check box, checked" : "check box, not checked";
      }
      if(cls.indexOf("::Radio") > 0)
      {
         l.role = o["isSelected"] ? "radio button, checked" : "radio button, not checked";
      }
      // One of a row of choices that stays pressed, like the current language.
      if(cls.indexOf("::ToggleButton") > 0 && o["isSelected"])
      {
         l.role = "button, selected";
      }
      if(cls == MANA)
      {
         // The mana orb only shows amounts; "Spells" under it is the caption of the spell bar.
         l.text = text.replace(", Spells","");
         l.kind = "text";
         l.action = null;
      }
      if(cls == "\"#::=!R")
      {
         // An amount in the status bar (coins, gems...). Clicking it does nothing, so it is plain
         // text; it keeps its target, so T still reads its tooltip.
         l.kind = "text";
         l.action = null;
      }
      return l;
   }

   // A progress bar drawn inside a control, as a counter (", bar 45%"). Not for the two the
   // game already says in words: the mana orb's fill is its "608/1000" and a spell button's
   // bar is the time left it writes ("16s"). The user asked for counters only where sighted
   // players get the same (2026-10-14).
   private static function barText(obj:DisplayObject, cls:String) : String
   {
      var bar:ProgressBar = cls == MANA || cls == "\"#::5W" ? null : findBar(obj);
      return bar == null ? "" : ", bar " + Math.round(percent(bar)) + "%";
   }

   private static function findBar(obj:DisplayObject) : ProgressBar
   {
      if(!obj.visible)
      {
         return null;
      }
      if(obj is ProgressBar)
      {
         return ProgressBar(obj);
      }
      var c:DisplayObjectContainer = obj as DisplayObjectContainer;
      if(c != null)
      {
         for(var i:int = 0; i < c.numChildren; i++)
         {
            var b:ProgressBar = findBar(c.getChildAt(i));
            if(b != null)
            {
               return b;
            }
         }
      }
      return null;
   }

   private static function percent(bar:ProgressBar) : Number
   {
      var range:Number = bar.maximum - bar.minimum;
      return range <= 0 ? 0 : Math.max(0,Math.min(100,(bar.value - bar.minimum) * 100 / range));
   }

   private static function collectLabels(obj:DisplayObject, out:Array) : void
   {
      if(!obj.visible)
      {
         return;
      }
      if(obj is Label)
      {
         var t:String = keys(clean(String(Object(obj)["text"])));
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
      if(target is ListItem)
      {
         return itemTip(ListItem(target));
      }
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
            var p:String = keys(clean(parts[i]));
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

   // The game's texts (labels, dialogs, tooltips) talk about the mouse ("CTRL+Click", "Click here to...");
   // say the key that does it here.
   // Only the whole word: "Clicking Reward" is the game's name for something and stays.
   private static function keys(s:String) : String
   {
      s = s.replace(new RegExp("CTRL\\+SHIFT\\+Click","gi"),"Control Shift Enter");
      s = s.replace(new RegExp("CTRL\\+Click","gi"),"Control Enter");
      s = s.replace(new RegExp("SHIFT\\+Click","gi"),"Shift Enter");
      return s;
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
      // A hover tooltip the game left open can lie over a button (it did over the spells).
      // It is only a picture, so make it let presses through.
      var st:DisplayObjectContainer = Starling.current.stage;
      for(var t:int = 1; t < st.numChildren; t++)
      {
         if(getQualifiedClassName(st.getChildAt(t)) == TOOLTIP)
         {
            st.getChildAt(t).touchable = false;
         }
      }
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
            if(RGAConfig.DEV) RGALog.write("click " + getQualifiedClassName(d) + " at " + int(x) + "," + int(y) + state(d) + (i > 0 ? ", centre covered by " + cover : ""));
            tap(x,y,ctrl,shift);
            return;
         }
         if(i == 0)
         {
            cover = hit == null ? "nothing touchable" : path(hit);
         }
      }
      var can:Array = pressable();
      RGALog.write("click " + getQualifiedClassName(d) + " COVERED everywhere by " + cover + state(d) + ", bounds " + r + ", pressable: " + (can.length > 0 ? can.join(" | ") : "none or many"));
      if(can.length > 0)
      {
         throw new Error("Blocked. Right now you can only press: " + can.join(", ") + ".");
      }
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
   public static function slideDown(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      slide(target,-1);
   }

   public static function slideUp(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      slide(target,1);
   }

   // Move a slider one tenth of its range; setting the value tells the game, as dragging would.
   private static function slide(target:Object, dir:int) : void
   {
      var lo:Number = Number(target["minimum"]);
      var hi:Number = Number(target["maximum"]);
      var v:Number = Number(target["value"]) + dir * (hi - lo) / 10;
      target["value"] = Math.max(lo,Math.min(hi,v));
   }

   public static function clickRealm(target:Object, ctrl:Boolean, shift:Boolean) : void
   {
      var r:Rectangle = DisplayObject(target).getBounds(Starling.current.stage);
      tap(r.x + r.width * 0.3,r.y + r.height * 0.2);
   }

   // Move the pretend mouse off the screen, so the game closes its hover tooltip.
   public static function hoverAway() : void
   {
      Starling.current.touchProcessor.enqueue(0,"hover",-5000,-5000);
   }

   // The game asks Starling whether Control or Shift is held during a click (buy 10, buy 100).
   // Starling learns that from key events on its stage, so it is sent one for each key.
   private static function modifier(code:int, down:Boolean) : void
   {
      var K:Class = getDefinitionByName("starling.events.KeyboardEvent") as Class;
      Starling.current.stage.dispatchEvent(new K(down ? "keyDown" : "keyUp",0,code));
   }

   // Feed Starling (the game's graphics engine) a mouse move, press and release at x, y.
   public static function tap(x:Number, y:Number, ctrl:Boolean = false, shift:Boolean = false) : void
   {
      modifier(17,ctrl);
      modifier(16,shift);
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

// One item (or, with index -1, one heading) of a list, wherever it is in the list.
// It is the target of that item's page line, because the item may have no row on screen.
class ListItem
{
   public var list:GroupedList;
   public var group:int;
   public var index:int;
   // The item's data, as the list holds it.
   public var item:Object;

   public function ListItem(list:GroupedList, group:int, index:int, item:Object)
   {
      this.list = list;
      this.group = group;
      this.index = index;
      this.item = item;
   }
}
