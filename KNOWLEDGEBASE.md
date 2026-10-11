# Mod-local Knowledgebase

Durable, non-obvious findings for developing this mod. New entries are headed
`## YYYY-MM-DD - slug`.

## 2026-10-11 - turret-modes-closed-enum

Turret modes are a closed engine enum (`libraries/common.xsd` `weaponmodelookup`,
`scriptproperties.xml` `type="enum"`); a mod cannot add a real mode. The two
behaviours the preset uses already exist: `prefercapital` (text {1001,8637}) and
`preferfighters` ({1001,8638}). Modes can differ per turret group
(`SetTurretGroupMode2`), and `GetUpgradeGroupInfo2(...).slotsize` exposes the size.

## 2026-10-11 - map-turret-dropdown-hook

The "All turrets" mode dropdown is built in `MapMenu.setupLoadoutInfoSubmenuRows`
(row id `info_turretconfig`; the same id is reused for the station non-missile row,
so filter on `mode == "ship"`). It is called by field lookup, and dropdown handlers
and `startOption` closures are read at display time, so wrapping the menu functions
and editing `row[5].properties.options` / `row[5].handlers` after the original call
works without replacing vanilla files. Ungrouped turrets are in `menu.turrets` as
components only; their size needs the slot index (`GetSlotSize(ship, 0, "", false,
"turret", slot)`).

kuertee UI Extensions 900 replaces `menu_map.lua` (packed in `subst_01.cat`) but keeps
these functions and row ids unchanged (read 2026-10-11). It adds a
`sto_addTurretBehavioursMapMenu` callback that may replace the "All" dropdown, so
check `row[5].type == "dropdown"` before touching it.

## 2026-10-11 - prefer-modes-is-only

From the vanilla AI (`aiscripts/fight.attack.object.capital.xml`): player ships keep a
separate target list per turret mode in-sector, so mixed modes split targets as
intended. Out-of-sector all `prefer*` modes are handled alike and
`set_turret_targets` is ignored in low attention, so the size split is in-sector
only. "Prefer" modes engage all enemies, unlike "Defend" (attackers only). Newly
equipped or rebuilt turrets get the default mode until the preset is reapplied.
(Read from scripts, not yet observed in game.)

## 2026-10-11 - docked-menu-turret-dropdown-hook

The cockpit's ship interactions screen is `DockedMenu` (`menu_docked.lua`), a separate
copy of the turret config UI with its own `menu.turrets`, `menu.turretgroups` and
`getDropDownTurretModeOption`; hooking the map does not affect it. Its `display()`
builds every row inline and ends with `menu.frame:display()`, so there is no row
builder to wrap. `Helper.createFrameHandle(menu, ...)` is looked up by field, and a
`display` field set on the returned frame shadows the prototype method, which gives a
hook between building and showing. The "All" row is rowdata `"turret_config"` (shared
with the per-turret rows), identified by `row[2].properties.uiTriggerID ==
"docked_turretconfig_modes"`. UI Extensions 900 also replaces `menu_docked.lua` (loose
`.xpl`) with the same rows plus a `sto_addTurretBehavioursDockMenu` callback that may
replace that dropdown (read 2026-10-11).
