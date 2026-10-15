# RGAccess findings: index

Read this index first, then open ONLY the file for the job at hand. Do not read them all.
When you learn something new, add it to the matching file (or a new file plus a line here). Keep each file short.

- `build-and-jpexs.md`: how the mod is compiled into the game, and JPEXS compiler bugs to avoid. Read before writing or changing any ActionScript. Also the installer (and its OverflowError lesson), the release build, how a release is published on GitHub, and the release list.
- `testing.md`: smoke test tool, log files, screen dump files, the single-instance rule. Read before testing or debugging a failure.
- `ui-map.md`: what is on the game's screens, how controls expose text and tooltips, how clicking works. Read before adding or fixing anything the page reads or presses. Also the jump keys and the speed measurements.
- `names.md`: scrambled class and field names for game DATA (buildings, coins, save keys). Read only when reading game data directly instead of from the screen.
- `game.md`: how the game itself is played (loop, factions, spells, assistants, buy keys). Read when the user asks about the game or a feature needs game knowledge (clicks, factions, Royal Market, what the game does NOT show).
- `history.md`: approaches that were tried and dropped, and why. Read only before proposing a different architecture.
