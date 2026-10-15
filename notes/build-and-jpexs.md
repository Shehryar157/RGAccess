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
- Tested: scratch install, reinstall, refusal of a changed file, packed helper finds NVDA (2026-10-11); the update check against the real release (2026-10-12: an older version is offered 0.1, the same version nothing). NOT tested: the windows (progress, update dialog, done message), the uninstaller, the download-and-hand-over step, the release build inside the real game.
- Updater expects repo `Shehryar157/RGAccess` (public), release tag `v<version>`, asset `RGAccess-Setup.exe`; release description = "what's new".

## Publishing a release (done for v0.1 on 2026-10-12)
- Repo: https://github.com/Shehryar157/RGAccess (public, branch master). `gh` is not installed; the GitHub API is called with curl and the token from `git credential fill` (never print it).
- Steps: raise `VERSION`; close the game; `python tools/build_release.py`; commit and push; POST `/repos/Shehryar157/RGAccess/releases` with `tag_name` v<version>, `target_commitish` master and the "what's new" text as `body`; upload `dist/RGAccess-Setup.exe` to `uploads.github.com/repos/Shehryar157/RGAccess/releases/<id>/assets?name=RGAccess-Setup.exe`.
- Check afterwards, from `installer/`: `setup.newer_installer('0.0.1')` should answer with the new version and its download address.
- Creating the repo and the first push were blocked by the permission system until the user asked for them outright. Ask before publishing anything.
- `tools/build_release.py` leaves the RELEASE variant in `build/`; run `python tools/build.py` afterwards to get the development build (remote control on) back into the game.
- Build with the game closed: with it open, Java ran out of memory ("paging file is too small"). `-Xmx1g` is set in `tools/build.py`.
- Scripted edits of files with scrambled names: write a small Python file with the Write tool and run it. A bash heredoc with the script inside failed on the quotes.

## Installer OverflowError (2026-10-15)
- A player saw "Setup failed: ArgumentError('argument 1: OverflowError: int too long to convert')" (setup version unknown; 0.1.1 had already declared GetDpiForWindow and DeleteObject). Cause: a ctypes call WITHOUT argtypes converts a Python int to a 32-bit C int, so a 64-bit handle overflows. Calls WITH argtypes never raise this (tested: c_void_p, UINT, WPARAM, LPARAM all wrap silently). On this computer handles are small, so it never shows here.
- 0.1.8 declares every remaining call (CreateFontW, InternetOpenW, SHBrowseForFolderW, CoInitialize). Rule: every new ctypes call gets argtypes (and restype for handles).
- The error dialog now says "Setup <version> failed", the exception and "At: file:line function < ..." from the traceback, and asks the player to copy it with Control+C.

## Releases so far
0.1 (2026-10-12), 0.1.1-0.1.4 (2026-10-13), 0.1.5 (R/L keys, Unpurchased landing, adaptive timer), 0.1.6 (tables, shortcut hints removed), 0.1.7 (D key, hints back), 0.1.8 (installer fix), all from 2026-10-14/15. Asset link pattern: https://github.com/Shehryar157/RGAccess/releases/download/v<version>/RGAccess-Setup.exe
- On this computer: running the setup needs `python tools/build.py --restore` first (the game holds the dev build); after a release build, `python tools/build.py` puts the dev build back.
