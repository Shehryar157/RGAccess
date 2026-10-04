# Scrambled name map

Our readable nicknames for the game's obfuscated classes and fields.
"Guess" means we inferred it and it still needs checking.

## Building (base class `§`!;§`, file decomp/scripts/§`!;§.as)
Each building is a subclass, e.g. Farm = `§-!N§/§8!d§` (its names: Farm / Enchanted Field / Dragon Pasture, depending on faction).

- `id`, `ids`: building id / string id
- `§1i§`, `§-v§`, `§ r§`: name strings (default "Unnamed"), guess: singular / plural / faction name
- `§,'§` = 1.15: cost growth per building bought (guess, matches the game's known 15%)
- `get/set §!a§` (uint): number owned (guess)
- `§`!X§(count = 1)`: cost of buying `count` (guess)
- `§9!U§` getter (Number): production or cost (unknown)

## Game object (`§8G§`, the Starling root class, decomp/scripts/§8G§.as)
- `§8G§.§>!a§`: the running game instance
- `§8G§.§@e§` (static Number): coins
- `§8G§.§%<§` (static Array): all buildings in order (also §0!=§ by id, §4!W§ by name)
- `§8G§.§[!M§`: buy mode
- instance `§ u§(building, ctrl, shift, false, -1)`: buy a building
- instance `§3! §(achievement)`: unlock an achievement (hook later for announcements)
- save keys: "resource" -> §@e§, "mana" -> §0! §, "gems" -> §"!0§, "spells" -> §'!X§, "buyMode" -> §[!M§

## UI
- `§"#§.§[!2§`: building row (extends `§1U§.§6+§`, a FeathersControl). `.§%<§` = its building (public); `.§?"L§()` = public click; `.§8!Q§(ctrl, shift)` = protected click; `.isEnabled` false when you can't afford it; `.§!!G§()` refreshes it
- `§&c§.§8!Z§(n)`: number formatting, the game's own
- `§9!A§`: database that registers all buildings, upgrades and so on at startup
- `§!7§.§=!"§`: an achievement ("Build N buildings in a single era"), not a command
