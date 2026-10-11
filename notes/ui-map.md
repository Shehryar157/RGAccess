# Game UI map and how the page reads it

UI is Starling + Feathers. `src/mod/RGPage.as` builds the page generically from the screen tree; nothing is per-screen except the panel names below.
Status: the generic builder was built and installed on 2026-10-11 but has not yet been run in the game.

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
- `]!6::+r`: status bar: four `"#::=!R` stat items (coins, per second, two more) and five `4X::` icon buttons (`+Y` hides the interface; `^C` holds tips text; the others are unidentified).
- `]!6::7R`: mana orb: labels Mana, amount, rate, Spells, plus control `'?::=!a`.
- `]!6::3!5`: a ScrollContainer near the top right of the realm, empty at game start. Unidentified.

## Dialogs seen
- `1Z::+!Y` containing `1Z::<!^`: advisor tutorial message, dismissed by clicking.
- `'?::"<`: Offline Production box with a feathers Button (no label) that closes it.

## Not yet explored
Upgrades, Trophies, Events and Spells screens; faction choice; abdication; options; stats; scroll containers whose contents are off screen; whether simulated clicks honour Control and Shift.
