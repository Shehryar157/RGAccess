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

## Open problem (2026-10-11)
User could not buy the first Blacksmith with over 600 coins, though Farm and Inn bought fine. Cause unknown; read the `click` lines in rga_debug.log after the user retries.

## Not yet explored
Upgrades, Trophies, Events and Spells screens; faction choice; abdication; options; stats; scroll containers whose contents are off screen; whether simulated clicks honour Control and Shift.
