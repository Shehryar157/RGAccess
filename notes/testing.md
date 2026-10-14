# Testing and debugging

## Rules
- AIR is single-instance. If the user's game is open, a second launch quits after 1 second. Ask the user to close it, or to restart it themselves.
- Game exit code 0 with no log means the SWF failed to load (see build-and-jpexs.md), not a crash. The Windows event log shows nothing.

## Tools
- `python tools/smoke.py [variant...]`: installs a build, runs the game about 20 s by itself, prints SURVIVED or QUIT plus `rga_debug.log`, then puts the previous SWF back. Variants: `full` (default), `main_only`, `no_call`, `with:Doc,Speech` (Main + logger + those files). For a longer run, from `tools/`: `python -c "import smoke, build; smoke.run(build.compile_swf(smoke.variant('full')), 45)"`.
- Compile only, no install, from `tools/`: `python -c "import build; build.compile_swf(build.bundle())"`.

## Remote control (use this to explore; no keyboard needed)
- The mod polls `rga_cmd.txt` in the Local Store every second (src/mod/RGARemote.as) and answers in `rga_cmd_done.txt`.
- `python tools/remote.py stop` closes the game politely (it saves), `start` launches it and waits for the mod. The user has allowed closing and reopening the game.
- `python tools/remote.py "press Upgrades" "wait 2" "dump upgrades"` then read `rga_page_upgrades.txt` (lines as spoken, each with its key in brackets and its tooltip indented) and `rga_tree_upgrades.txt`. Other commands: `presskey <key>`, `tip <text>`, `click x y`, `static <class> <field>` (prints a static field of a game class).
- Cycle after a code change: stop, `python tools/build.py`, start. About 40 s.
- At start the Offline Production dialog is usually open: `press Close` first. The tutorial advisor needs `press Continue`. Both block every other press until closed.
- This runs in the user's real save. Save backups are in `save_backups/`. Only open screens; do not buy or confirm anything costly without the user asking (bought so far for testing: 1 Farm, 1 Blacksmith which the user wanted, the free Crop Rotation).
- Grep the dumps (`grep -v 'tip:'`, `cut -c1-150`) instead of printing them whole; tooltips are long.

## Files the mod writes
In `%APPDATA%\com.kongregate.mobile.realmgrinder.air\Local Store`:
- `rga_debug.log`: mod log and errors (RGALog). Page-build errors are logged once each.
- `rga_tree.txt`: every visible screen object with class, position and text (RGADump).
- `rga_page.txt`: the virtual page exactly as spoken.
- The two dump files are written on Control+Shift+F12, and once automatically 25 s after start if a file named `rga_autodump` exists in that folder (it currently does). Read these instead of asking the user to paste output.

In `<game>\RGAccess`: `rga_speech.log`, the speech helper's log (which screen reader it found, each line it was sent).

## Added 2026-10-11
- `dump` also answers how long the last list took to read ("list read in 32 ms").
- The remote `press` speaks its result like Enter does. `rga_speech.log` (lines start with "S", the file starts again at every game start) shows everything spoken, so results and announcements can be checked there.
- The user often plays while you test. Every restart interrupts them, so batch changes into one restart, and say so. Do not press things that change their setup (Buy amount, purchases); the log shows their own presses mixed with yours.
- Remote `time` builds the page 10 times each way and answers with the average milliseconds.
- Remote `key <code>` types a key on the page through `Doc.handleKey` (80 = P) and `where` types nothing; both answer with the line the cursor is on (added 2026-10-12). Keys handled in `RGA.onKey` itself (F1, T, Escape) still cannot be typed.
- When the user is playing, their own key presses move the cursor between your commands: trust `rga_speech.log` over `where`.
- Remote keys: `key N` only reaches `Doc.handleKey` (page moves, H, B, R...). Keys handled in `RGA.onKey` (T, D, F1, F2, Escape) need `stagekey <charCode> <keyCode>`, SPACE-separated, e.g. `stagekey 68 68` for D. A comma ("100,68") parses as one number and sends key 0 (seen in the log as "key 0"). It cannot hold Shift, so Shift+B and the like cannot be tested; move with `key 38`/`key 40` instead.
