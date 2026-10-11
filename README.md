# RG Access

A screen reader mod for [Realm Grinder](https://store.steampowered.com/app/610080/Realm_Grinder/), the free idle game on Steam. It turns the game's screen into something you read like a web page: arrow through the lines, jump between headings, buttons and buildings, and press Enter to click. Speech goes to NVDA, JAWS or, without a screen reader, Windows' own voice.

The mod is for the Steam version on Windows. It is unofficial and not made or endorsed by the game's developers.

## What works

- The main screen as a page: resources (coins, production, gems, rubies, mana), the toolbar, buildings, spells, and whatever is open on the left.
- Pressing any button with Enter, including icon buttons, which are given names.
- Buying buildings, one at a time or 10 at once.
- Casting spells.
- The Upgrades and Trophies lists, read in full, including what is scrolled off the screen.
- Tooltips: the cost and effect of every upgrade, building and spell.
- Statistics, with all its numbers.
- Options, with the state of every check box and radio button, and its Language and Audio dialogs. The volume slider becomes two buttons, lower and higher.
- The Shop, Scrying, the Events panel and the Abdication dialog.
- Dialogs and notifications are spoken when they appear, and the cursor moves to them and back.
- Numbers that change while you read stay live, and the cursor stays on the same item.
- Selecting and copying text.

## What does not work

- The Events panel during a live event, and the Reincarnation dialog, have not been met yet, so they are unchecked. The mod reads screens it has never seen in a general way, so they may simply work.
- Buying 100 at once (Shift Enter) is built but unconfirmed.
- The Kong tab does nothing. That is the game: the tab belongs to the Kongregate web version.
- If "Disable Buy Hotkey" is checked in the game's Options, Control Enter and Shift Enter buy only one. Uncheck it.
- When Steam updates or repairs the game, the mod is removed. Run the setup again.

## Known bugs

None confirmed at the moment. Two things that can look like bugs:

- While the Offline Production dialog or the tutorial advisor is open, nothing else can be pressed. Close it first.
- Every press of a volume button reads the whole Audio dialog again.

Please report anything else on the [issues page](https://github.com/Shehryar157/RGAccess/issues).

## How to install

1. Install Realm Grinder from Steam and close it if it is running.
2. Download `RGAccess-Setup.exe` from the [latest release](https://github.com/Shehryar157/RGAccess/releases/latest) and run it.
3. Start the game from Steam. You hear "RG Access loaded" with the version number.

To update, run the setup again: it tells you when a newer version exists, shows what is new, and lets you update or skip. If you skip, it asks again the next time you run it.

To remove the mod, run "Uninstall RG Access" in the RGAccess folder inside the game's folder. It puts the game's original file back.

Windows may warn about the setup because it is not signed. Choose "More info", then "Run anyway".

## Keys

### Anywhere

- F1: help, listing these keys. Press it again, or Escape, to close.

### Reading the page

- Up and Down arrows: previous or next line.
- Left and Right arrows: previous or next character. With Control: by word.
- Home and End: start or end of the line. With Control: top or bottom of the page.
- Shift with any movement key: select text. Control C copies, Control A selects all.
- H and Shift H: next or previous heading.
- R: jump to the Toolbar. Resources is the heading just before it: press Shift H.
- S: jump to Spells.
- U: jump to Upgrades. If the panel is closed, it is opened first.
- O: open Options. If it is already open, jump to its top.
- Tab and Shift Tab: next or previous button.
- Enter or Space: press the button you are on.
- T: read the whole tooltip of the button you are on.
- Shift T: open the tooltip as a page to read line by line. Escape closes it.

### Buildings

- B and Shift B: next or previous building.
- Enter: buy the building, using the game's buy mode.
- Control Enter: buy 10.
- Shift Enter: buy 100.
- Control Shift Enter: buy as many as you can afford.
- T on a building reads what each of those would cost.

After Enter, the mod reads the button again if it changed, for example a building with its new count and price.

## How it works: for the technically minded

Realm Grinder is an Adobe AIR program; its code is one Flash file, `RealmGrinderDesktop.swf`. The mod is ActionScript compiled into that file with [JPEXS Free Flash Decompiler](https://github.com/jindrapetrik/jpexs-decompiler): the game's `Main` class gets one extra call that starts the mod, and the mod's classes (`src/mod`) ride along in the same script.

- **Reading.** Once a second, and after every press, the mod walks the game's display tree (Starling and Feathers controls) and builds a page of lines from the labels, buttons and tooltips it finds. Nothing is tied to one screen, which is why new screens mostly read without extra work.
- **Pressing.** Enter sends the control the same touch events a mouse click would.
- **Speech.** AIR cannot talk to a screen reader, so the mod starts a small helper program (`src/helper/rga_speech.py`, packed as `rga_speech.exe`) and writes lines of text to it. The helper speaks them through [Tolk](https://github.com/dkager/tolk).
- **The installer.** A release does not contain the game's file. It contains the differences between the original and the modded file, about 30 KB, and rebuilds the modded file from your own copy (`installer/patch.py`). It refuses a game file it does not recognise, so it cannot break a newer game version. Updates come from this repository's releases.

Building from source needs Python 3.11, PyInstaller, a Java runtime and JPEXS in `tools/`, and the original game file in `original/`:

- `python tools/build.py` compiles the mod and puts it into the game.
- `python tools/build_release.py` builds `dist/RGAccess-Setup.exe`.

`notes/FINDINGS.md` is the index to what was learned about the game along the way.

## Help: learning the game

The game explains little by itself. These explain how it is played and what to do next:

- [Not a Wiki](http://musicfamily.org/realm/): the community's main guide, with beginner advice, factions, builds for every stage, and challenges.
- [Realm Grinder Wiki](https://realm-grinder.fandom.com/): every building, upgrade, spell, trophy and faction, one page each.
- [Steam guides for Realm Grinder](https://steamcommunity.com/app/610080/guides/) and the [Steam discussions](https://steamcommunity.com/app/610080/discussions/), for questions.

The short version of the loop: buy buildings to earn coins, buy upgrades to earn faster, pick a faction and cast its spells, and when progress slows, abdicate: you start again, but with gems that make everything faster.
