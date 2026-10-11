# Build and JPEXS pitfalls

## How the build works
- Game: `D:\Steam\steamapps\common\Realm Grinder`, Adobe AIR 23 captive runtime, code in `RealmGrinderDesktop.swf`. Original backed up in `original/`.
- `python tools/build.py` bundles `src/scripts/Main.as` + a generated `RGAConfig` + every `src/mod/*.as` into `build/Main.as`, runs `ffdec-cli -replace` on the original SWF, and copies the SWF, `src/helper/rga_speech.py` and the Tolk DLLs into the game (`<game>\RGAccess`). `--restore` puts the original SWF back.
- Mod classes are file-internal classes appended after Main's package block (JPEXS cannot add packaged classes). Their imports are hoisted to just after the package block; that works.
- AIR-only classes (File, FileStream, NativeProcess, Clipboard) must be fetched with `getDefinitionByName`, because JPEXS has no AIR type library.
- No hot reload: the mod is compiled into the SWF, so every change needs a game restart. A loader plus external SWF (needs the AIR SDK compiler) would allow reloading; suggested for later.

## JPEXS compiler bugs (it compiles without error, the game then fails)
- NEVER use `new X()` in a field default value. JPEXS drops the class lookup. In a static field it breaks the whole SWF at load (game quits cleanly after about 15 s, nothing logged). In an instance field the constructor fails with VerifyError #1024. Assign inside a constructor or function instead.
- NEVER recompile decompiled game code that still has `_locN_` junk branches; those variables are undeclared. Rewrite the class by hand (Main.as is fully clean).
- Inline anonymous functions are unproven; prefer named static functions. DocLine actions are static functions called as `action(target, ctrl, shift)`.
- Confirmed fine: private members, static vars with plain defaults, default arguments, `Vector.<String>`, try/catch with return or empty catch, cross-class calls.

## Seeing what JPEXS really produced
`java -jar tools/ffdec/ffdec-cli.jar -format script:pcode -selectclass Main -export script <outdir> build/RealmGrinderDesktop.swf` then read `<outdir>/scripts/Main.pcode`. Look for a `construct N` with no `findpropstrict` before its arguments.

## Shell note
Bash heredocs choke on the scrambled names (the section-sign and quote characters). Write files containing them with the Write tool, not `cat <<EOF`.

## Regular expressions
- In ActionScript a pattern needs doubled backslashes: `new RegExp(", (\\S+) owned")`. Twice a scripted edit (Python in a Bash heredoc) wrote a single backslash, which compiles but never matches. After any scripted edit, grep the line and check it; fix with the Edit tool.

## Release and installer (added 2026-10-11)
- `python tools/build_release.py` builds `dist/RGAccess-Setup.exe` (13 MB). Version comes from the `VERSION` file (also compiled in as `RGAConfig.VERSION`).
- The installer does not carry the game's SWF: it carries a 31 KB patch (`installer/patch.py`, differences between the unpacked bodies) and rebuilds the modded SWF from the player's file. It checks the SHA-256 of the game's file and refuses an unknown one, so a game update needs a new release.
- The installer keeps the untouched SWF as `RealmGrinderDesktop.swf.before-rgaccess` and writes `version.txt` and `swf.sha256` into `<game>\RGAccess`.
- Installed mod runs `rga_speech.exe` (PyInstaller); a source build still uses pythonw + `rga_speech.py`. `Speech.as` picks the exe when it exists.
- On this computer the game holds a source build, which the installer refuses. To try the installer on the real game: close the game, `python tools/build.py --restore`, then run the setup.
- Testing without the game: `python installer/setup.py --silent --no-update --game <scratch folder with the original SWF and an empty RealmGrinderDesktop.exe>`. `--silent` skips the "game is running" check.
- Tested 2026-10-11: scratch install, reinstall, refusal of a changed file, packed helper finds NVDA. NOT tested: the windows (progress, update dialog), the uninstaller, the update download (needs a published release), the release build inside the real game.
- Updater expects repo `Shehryar157/RGAccess` (public), release tag `v<version>`, asset `RGAccess-Setup.exe`; release description = "what's new".
