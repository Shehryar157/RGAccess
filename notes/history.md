# Approaches tried and dropped

- Real web page inside the game window (StageWebView, useNative): failed. AIR 23 on Windows renders its built-in WebKit into the game surface; there is no child window, so NVDA gets no browse mode.
- Edge app window re-parented into the game window (`src/attach_test.py`): failed, NVDA read nothing.
- Remaining one-window idea not tried: swapping in a newer Harman AIR runtime (WebView2); needs a licence and download.
- Chosen design: in-game keys that behave like NVDA browse mode, with speech through a hidden Python helper (Tolk) that the game starts via NativeProcess and writes to on stdin (lines starting S speak, Q queue, X exit).
- First page builder was hand-written for buildings and read game data fields directly. It gave "%0" names, faction-variant names and duplicate rows. Replaced by the generic screen-tree builder (see ui-map.md).
- Startup failure hunt, 2026-10-11: import placement and inline functions were suspected and were NOT the cause; see the `new` in field defaults bug in build-and-jpexs.md.
- The game's crash reporter (posted to divinegames.it) was removed from Main; errors go to rga_debug.log.
