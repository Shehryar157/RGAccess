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
