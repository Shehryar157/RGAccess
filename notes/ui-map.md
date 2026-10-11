# Game UI map and how the page reads it

UI is Starling + Feathers. `src/mod/RGPage.as` builds the page generically from the screen tree; nothing is per-screen except the panel names below.
Status: the generic builder is confirmed working in the game (2026-10-11): dialogs, buildings, menu, status bar all read; buying Farm and Inn by Enter works.

## Rules the page builder uses
- Every `feathers.controls.Label` is a text line (formatting tags stripped).
- Every game control extends `§1U§.§6+§` (a FeathersControl). A control with no controls inside it becomes a button line, named from its tooltip title plus its labels.
- Tooltips: `control["[i"]()` returns the tooltip title, `control["9!0"]()` the body. Base-class defaults are "Test Title" and "Test Body" (treated as none). The T key shows these.
- Pressing: `Starling.current.touchProcessor.enqueue(0, phase, x, y)` with phases "hover", "began", "ended" at the control's centre (stage coordinates from `getBounds(stage)`).
- Stage children after index 0 are dialogs on top of the game. They are listed first under "Dialog" and spoken when they appear. A dialog with no button gets a "Continue" button that clicks its centre.
- Building rows (`§"#§.§[!2§`) have four labels in order: name, cost, percent, count.

## Main screen panels (getQualifiedClassName values)
- `]!6::%!a`: the realm, the big clickable background (a ScrollContainer, not a control).
- `]!6::"T`: buildings panel, holds the building rows.
- `]!6::!M`: buy options: `4X::2!C` buy amount button (BUY 1/10/100/1000/10000/MAX), `4X::"W` scry button, `4X::=!_` Shop.
- `]!6::2i`: left menu, tab buttons `"#:: !D` (Upgrades, Trophies, Events, Kong) with a count badge label.
- `]!6::+r`: status bar, at the BOTTOM of the screen for sighted players. Child 0 is a group of four `"#::=!R` stat items (tooltip titles Coins, Production, Gems, Rubies). Child 1 is a group of five picture-only `4X::` buttons, left to right: `+Y` Hide interface (tooltip title is an empty string), `^C` Tips and Hints, `9P` Statistics (opens dialog `1Z::8!-`), `<!w` Sound on/off (two Image children; the second, UIAudioOff, is visible when muted), `2!Z` Options (opens dialog `1Z::?K`). `4X::=!_` in the buy panel is the Shop. These have no text and no tooltip title, so `RGPage.iconName` names them by class.
- `]!6::7R`: mana orb: labels Mana, amount, rate, Spells, plus control `'?::=!a`.
- `]!6::3!5`: a ScrollContainer near the top right of the realm, empty at game start. Unidentified.

## Dialogs seen
- `1Z::+!Y` containing `1Z::<!^`: advisor tutorial message, dismissed by clicking.
- `'?::"<`: Offline Production box with a feathers Button (no label) that closes it.

## Page layout choices
- The page reads the status bar as heading "Resources" (key `h:resources`, the R key jumps to it), with the mana orb moved in after the four stats, then heading "Toolbar" for the icon buttons.
- Building rows: the percent label is that building's share of total coin production. A row's `isEnabled` is simply cost <= coins.
- `RGPage.click` hit-tests (`stage.hitTest(point, true)`) several points in the control and presses the first one where the control itself is on top; it logs every click, and what covered the centre, to rga_debug.log.

## Things on top of the game
- Stage children after index 0. `1Z::!s` is the hover TOOLTIP (not a dialog; skipped). After every tap the mod hovers at -5000,-5000 so the tooltip closes.
- A dialog (Offline Production `'?::"<`) comes with a full-screen stage `Quad` that swallows every click. The tutorial advisor uses a `Quad` inside the main screen the same way. `RGPage.click` detects this by hit test and throws "Blocked..." (spoken). This was the user's "cannot buy Blacksmith" problem.
- `'?::8!L` (child of the main screen): notification banner, e.g. "You unlocked the trophy X". Spoken by RGA when its text changes (`RGPage.toastText`).

- Tutorial spotlight: after choosing Good, the advisor says "Click this button to simplify building purchases". Four `Quad`s (alpha 0.6) in `1U:: g` darken everything except a hole over the Buy amount button `4X::2!C`; clicking the advisor does nothing, only that button continues. `RGPage.spotlight` hit-tests the page's buttons and, if at most 3 are reachable, turns Continue into "Continue, presses <that button>". Written 2026-10-11, NOT yet seen working (the message was gone after the restart).
- When a dialog or notification appears, `RGA.refresh` calls `Doc.visit(key)`: the cursor moves to its heading (`h:dialog`, `h:` + toast class) and `Doc.backKey` remembers the old line, used by `setLines` when the heading disappears.
- Seen once: the first `press Close` on Offline Production after a restart did nothing, the second worked. Cause unknown (possibly the real mouse sharing touch id 0).

- After Enter, `RGA.afterAction` waits 300 ms, rebuilds the page and speaks `RGA.result`: a building whose line changed is read again whole (the user asked for this instead of "Farm purchased"), "Cannot afford X" for an unchanged unavailable building, list item gone or moved group ("X purchased"), same line with new text, or a level 1 heading that appeared or went ("Upgrades panel opened"). The remote `press` goes through it too, so results show in rga_speech.log. Confirmed for panels and dialogs; building and upgrade purchases not yet seen.
- Buy amount `4X::2!C` opens a text-less dialog of choices (BUY 1, 10, 100, 1000, 10000, SMART, MAX). Above BUY 1 a building's cost label is "4x 116"; the page says "costs 116 for 4". Tooltip: Control click buys 10, Shift click 100, both MAX (modifier keys with simulated clicks still untested).
- Status bar amounts `"#::=!R` are text lines, not buttons (they keep their target for T).

## Lists (Upgrades, Trophies)
- Panels: `]!6::>F` Upgrades (top buttons `4X::%!S` Abdication and `4X::59` Reincarnation, shown as ??? early), `]!6::8T` Trophies. Any other `]!6::` class gets the heading "Panel".
- Inside is a Feathers GroupedList. Its `...DataViewPort` holds the rows in no fixed order; the page sorts them by y then x.
- Section titles implement `IGroupedListHeaderRenderer` (class `1U::5X`): read as level 2 headings.
- Rows extend `1U::?!\`` (upgrade `"#::7!B`, trophy `"#::>m`). Public `["[B"]()` is the title, `["@\""]()` the description (for upgrades its first line is "Cost: ..."), `data` is the item. `RGPage.isItem` detects rows by those two functions. A simulated click on an upgrade row buys it (confirmed with the free Crop Rotation).
- A row the game draws half transparent (first child alpha below 1) is unaffordable (upgrade) or not yet earned (trophy): read as "cannot afford" or "locked".
- Lists are virtual: only rows on screen exist (Trophies shows about 20 of 903). SOLVED 2026-10-11 by `RGPage.walkList`: `list.dataProvider.data` is an Array of groups `{header:{text, collapsed, id}, children:[items]}` (a collapsed group has empty `children`, the items wait in `cchildren`). Each item is put into one borrowed on-screen row (`row.data = item; row.validate()`), read, and the row is given its own data back. All 903 trophies take about 30 ms. Confirmed in game.
- Such a line's target is a `ListItem` (list, group, index, item), not a row. `RGPage.clickItem` calls `list.scrollToDisplayIndex(group, index, 0)`, validates the list, finds the row whose `data` is the item and clicks it; index -1 is the group heading, and clicking that collapses or opens the section. Confirmed for an off-screen trophy and a heading.
- `"#::>W` at the bottom of the Upgrades panel: faction coin counters. Public field `@e` is the faction number; names come from the static array `-D`.`45` (Fairy, Elven, Angel, Goblin, Undead, Demon, Titan, Druid, Faceless, Dwarven, Drow, Mercenary, Dragon, Archon...). `-D`.`]!4` holds event item names (Snowballs, Hearts...).
- `'?::[[`: the list's scroll bar, made of thin unlabeled Buttons (skipped).

- Row internals (from decomp `§1U§/§?!`§`, trophy `§"#§/§>m§`, header `§1U§/§5X§`): the `data` setter only stores and invalidates; `validate()` runs `§4!^§()`, which copies data into the row and refreshes it. Trophy rows keep the trophy in `§2g§`, and `§2g§.§4!K§` is true when earned (not earned is drawn at alpha 0.4). Clicking a trophy only shows a callout. Header data is `{text, collapsed, id}`.

## Other main screen pieces found
- `]!6::3!5`: spell bar. Spell buttons `"#::5W` with labels name and "N mana" (Tax Collection 200, Call to Arms 400). Heading "Spells".
- `"#::9!`: building pictures on the realm, `touchable = false` (skipped as decoration). `"#::%[`: Assistants figures on the realm, six identical controls (read once).

## Screens explored 2026-10-11 (second session), all through the remote
- Statistics `1Z::8!-`: three Radios (This Era, This Reincarnation, All Time) and a GroupedList `'?::=!4` with groups Production, Time, Spells, Factions. Each group has ONE row (`"#::+!G`, an IGroupedListItemRenderer that is not `isItem`) holding many Labels. `walkList` reads such rows as one text line per label. Section titles `1U::5X` also pass `isItem`, so `findRow` must never borrow one (that was the "no numbers" bug).
- Options `1Z::?K`: Radios and about 30 Checks (read as "radio button/check box, checked/not checked" from `isSelected`, via `DocLine.role`), buttons Language, Audio, Overwrite, Restore, Save, Export, Import, templates, Hard Reset (never press), Community. No sliders or text inputs. Language and Audio sub-dialogs not opened.
- Shop: title, description and price buttons per product; reads well as is. Real money, never press.
- Scrying: a dialog that only says it is unavailable on this platform.
- Events panel `]!6::@h`: "No event is currently running". Untested with a live event.
- Kong tab: pressing it changes nothing in the tree on Steam, no tooltip. Left as is.
- Mana orb `]!6::7R`: not a button. A tap only shows its tooltip (max mana, per second, spells cast); "Spells" under it is the caption of the spell bar. Now a text line; T reads the tooltip.
- Abdication (button at the top of the Upgrades panel): dialog with title, explanation (gems to gain), buttons Abdicate, Gem Conversion, Close. Reads well. Not confirmed, of course.
- Faction choice is done by buying upgrades (Proof of Good Deed, Trade Treaties, then the faction), so it goes through the Upgrades list.
- Named dialogs (`RGPage.dialogName`: Statistics, Options) are announced by name only; their text is long and changes every second. Confirmed: the speech log says "Dialog. Statistics".

## Control and Shift presses (confirmed)
- The game's base control passes `TouchEvent.ctrlKey/shiftKey` to its click function; a building row hands them to the buy function. Starling's TouchProcessor fills them from private flags it sets when a "keyDown"/"keyUp" event with keyCode 17 or 16 reaches the Starling stage. `RGPage.modifier` dispatches such a `starling.events.KeyboardEvent` before every tap (`tap(x, y, ctrl, shift)`).
- Remote: `cpress <name>` and `spress <name>`. Control press on Farm bought 10 (11 to 21). Shift press bought nothing because 100 farms were unaffordable; same code path, so not proven.
- The user's Options have "Disable Buy Hotkey" CHECKED, which turns these shortcuts off in the game. Unknown whether that is deliberate; with it checked, Control Enter buys the normal amount.

## Leftover tooltips (was the spell casting bug)
- After a tap the hover tooltip `1Z::!s` sometimes stays open and is touchable, so it covered the spell buttons and `click` said "Blocked". `click` now sets every open tooltip `touchable = false` first, and `RGA.onResult` calls `RGPage.hoverAway()` 300 ms after a press. Casting Tax Collection through an open tooltip confirmed (mana 1000 to 808).

## Still open
- Events with a live event; Language and Audio sub-dialogs; Reincarnation dialog (still ??? in this save); other scroll containers with off-screen content (none met so far); Shift press proof.
- `remote.py start` does not run commands given after it; send them in a second call.
- Tooltip and Label lines pass through `RGPage.keys`: only CTRL+Click, SHIFT+Click and CTRL+SHIFT+Click become Control Enter, Shift Enter, Control Shift Enter. Plain "click" is left as the game wrote it (user asked to undo the "Press Enter" rewrite, 2026-10-11).
- Tips and Hints `4X::^C`: pressing it does nothing; the current hint is its tooltip (T). On 2026-10-11 it said: gather 20 faction coins of one faction and sign a Trade Treaty with them.

## Tooltip keys (changed 2026-10-11, late)
- T speaks the whole tooltip of the current line and opens nothing. Shift+T speaks it and opens it as a page (the old T behaviour); Escape closes. `RGA.showTooltip(open)`. The user asked for this split.
- NOT tested: the remote cannot type keys, only press lines. Ask the user how T and Shift+T behave.
