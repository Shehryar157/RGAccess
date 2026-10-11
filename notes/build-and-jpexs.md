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
