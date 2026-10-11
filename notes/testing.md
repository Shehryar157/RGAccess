# Testing and debugging

## Rules
- AIR is single-instance. If the user's game is open, a second launch quits after 1 second. Ask the user to close it, or to restart it themselves.
- Game exit code 0 with no log means the SWF failed to load (see build-and-jpexs.md), not a crash. The Windows event log shows nothing.

## Tools
- `python tools/smoke.py [variant...]`: installs a build, runs the game about 20 s by itself, prints SURVIVED or QUIT plus `rga_debug.log`, then puts the previous SWF back. Variants: `full` (default), `main_only`, `no_call`, `with:Doc,Speech` (Main + logger + those files). For a longer run, from `tools/`: `python -c "import smoke, build; smoke.run(build.compile_swf(smoke.variant('full')), 45)"`.
- Compile only, no install, from `tools/`: `python -c "import build; build.compile_swf(build.bundle())"`.

## Files the mod writes
In `%APPDATA%\com.kongregate.mobile.realmgrinder.air\Local Store`:
- `rga_debug.log`: mod log and errors (RGALog). Page-build errors are logged once each.
- `rga_tree.txt`: every visible screen object with class, position and text (RGADump).
- `rga_page.txt`: the virtual page exactly as spoken.
- The two dump files are written on Control+Shift+F12, and once automatically 25 s after start if a file named `rga_autodump` exists in that folder (it currently does). Read these instead of asking the user to paste output.

In `<game>\RGAccess`: `rga_speech.log`, the speech helper's log (which screen reader it found, each line it was sent).
