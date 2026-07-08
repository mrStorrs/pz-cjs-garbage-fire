# CJS Garbage Fire

Adds a `Burn Trash` right-click option to trash cans, wheelie bins, dumpsters, and other vanilla objects marked with `IsTrashCan`.

The action requires:

- A fire starter such as matches, lighter, or any item tagged `StartFire`
- A rag, ripped cloth, denim/leather strip, or unequipped clothing item with fabric. Rags and strips are selected before other valid burnable items.

The mod creates a tagged campfire object on the garbage can square, burns the can contents as fuel, keeps the campfire light/noise small, prevents campfire spread for tagged garbage fires, and removes the campfire object when it burns out.

While the trash fire is burning, the server checks tagged garbage fires every 8 seconds by default. The `CJS Garbage Fire > Incinerator Scan Seconds` sandbox option can set the interval from 1 to 300 seconds. Any new contents added to the same trash can are destroyed and counted as additional capped fuel for that fire.
