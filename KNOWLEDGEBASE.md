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

## 2026-10-11 - turret-stats-from-lua

`GetLibraryEntry(GetMacroData(macro, "infolibrary"), macro)` on a turret macro
(library `weapons_turrets`) returns `rotation` (deg/s), `bulletspeed` (m/s, beams report
the speed of light), `isbeamweapon`, `range`, `dps` and the area damage fields
`hullshieldareadpshot`, `shieldonlyareadpshot`, `hullonlyareadpshot`,
`hullnoshieldareadpshot` (read from the encyclopedia and `Helper` equipment info code;
confirmed in game, see `turret-stats-api-confirmed`). Missile
turrets are library `weapons_missileturrets` without projectile stats. The bullet's
`<weapon system="turret_shortrange|midrange|longrange">` role tag is read by no script
or Lua, so it is not available to the UI.

## 2026-10-11 - vanilla-turret-stat-clusters

Measured over the 97 non-mining turret macros in the unpacked base game and DLC
`reference/` (loose files, 9.0): M turrets turn at 40-60 deg/s (plasma, long-range
beams, Boron railguns) or 80-180 deg/s (lasers, gatlings, flak, shotguns, short-range
beams), with nothing between 60 and 80. L turrets turn at 10-40 deg/s except Boron L
flak (50) and the pirate battleship L laser (60). Plasma flies at 600-1000 m/s, every
other projectile at 1400 m/s or more (one story turret at 342). Area damage: 7 turrets,
mostly flak at 120-142 deg/s, plus Boron L flak (50) and Xenon L plasma (25, 850 m/s).
The default thresholds (75 deg/s, 1200 m/s, 45 deg/s with area damage) sit in these
gaps; against the old size rule they move 19 M turrets plus the slow Terran story laser
to anti-capital and Boron L flak to anti-fighter (checked by running `turret_roles.lua`
against these stats).

## 2026-10-11 - mod-settings-in-extension-options

A UI mod can persist settings per user profile with
`<savedvariable name="..." storage="userdata" />` in its `ui.xml` (name must not start
with `__CORE`; UI Extensions uses the same). The global is available when the menu files
run (vanilla `gameoptions.lua` reads its own at init); `C.SaveUIUserData()` writes it.
The Options > Extensions > (mod) page is `config.optionDefinitions["extensionsettings"]`
(local), but `displayOptions` renders every option through the field
`menu.displayOption(ftable, option, numCols)`, and the page's last option is always
`workshop` (hidden by its own `display()` for non-Workshop mods, still passed in). So
wrapping `displayOption` and rendering extra option tables after `workshop` reuses
vanilla's slider/button rows. Selecting a slider row calls its callback with no value.
UI Extensions 900 replaces `gameoptions.lua` (loose `.xpl`) with the same page and
function (read 2026-10-11). Implemented and loaded in game, but the user looked for mod
settings under "Extension Options" (SirNukes) and not on this page, so the mod moved its
settings there (see `sirnukes-simple-menu-options`); this approach is no longer used.

## 2026-10-11 - sirnukes-simple-menu-options

"Extension Options" is the SirNukes Mod Support APIs menu (content id `ws_2042901274`,
same id in the Nexus/Vortex install and as a Workshop dependency of Options Helper), not
vanilla. `md.Simple_Menu_Options.Register_Option` (read from its packed
`md/simple_menu_options.xml`, version 195) takes `$id`, `$name`, `$mouseover`,
`$category` (own header), `$type` (`button` on/off or `slidercell`), `$default`, `$args`
(merged into the widget: `$min`, `$max`, `$step`, `$suffix`), `$echo` and `$callback`.
Values persist per user profile via `md.Userdata` (uidata.xml), keyed by `$id`. The
callback gets `table[$id, $value, $echo]` once right after registration and on each
slider confirm. Registration must happen on `md.Simple_Menu_Options.Reloaded`, which
fires after the API's Lua sends `reloaded` (game load, `/reloadui`). There is no reset
button type, and that section cannot hold links or buttons; the mod therefore uses its
own options page instead (see `sirnukes-options-pages`). MD passes values to UI Lua with `raise_lua_event` (one `param`: string,
number or component) and `RegisterEvent(name, function (_, param) ... end)`.

## 2026-10-11 - turret-stats-api-confirmed

Observed in game (debug.txt, 2026-10-11): `turret_pir_l_battleship_01_laser_01_mk1_macro:
turn rate 60.0 deg/s, projectile speed 1800 m/s`, matching its macro XML, so
`GetLibraryEntry` returns macro rotation and bullet speed as read.

## 2026-10-11 - sirnukes-options-pages

Read from SirNukes Mod Support APIs 195 (`md/simple_menu_api.xml`,
`ui/simple_menu/options_menu.lua`): the "Extension Options" page lists every
non-private menu registered with `md.Simple_Menu_API.Register_Options_Menu` as a link
(sorted by title), then appends the `Simple_Menu_Options` sections. There are no popups
in options menus: a "button" can only be `Add_Submenu_Link` to another registered (usually
`$private = 1`) menu, which opens as a full page with a Back button. A menu's `$onOpen`
cue must build all rows (`Add_Row`, `Make_Text`, `Make_Slider` with
`$onSliderCellConfirm`, ...) in the same frame, so data from Lua must already be in MD.
Lua can send a string-keyed table to MD with `AddUITriggeredEvent(screen, control,
table)`; MD reads it as `event.param3` with `$`-prefixed keys (how SirNukes returns widget
events). `GetLibrary("weapons_turrets")` lists turret library entries (`id` = macro,
`name`), as the encyclopedia uses it. `C.IsWeaponModeCompatible(0, macro, mode)` checks
a macro without a component (vanilla `menu_map.lua` does this).

## 2026-10-11 - options-page-buttons

`Add_Submenu_Link` rows open only on double click in game (user report, 2026-10-11): the
first click selects the row. A `Make_Button` (`$text = table[$text = ..., $halign =
'center']`, `$onClick` cue) reacts to one click, but SirNukes has no MD command to open an
options page. Its links call vanilla `OptionsMenu.openSubmenu(id, id)` (keeps the Back
history), and SirNukes patches `submenuHandler` to handle its pages and sets
`OptionsMenu.currentOption` to the page id, so the button's cue raises a Lua event and
the mod's Lua calls `openSubmenu` (read from SirNukes 195 `ui/simple_menu/options_menu.lua`
and vanilla `gameoptions.lua`). `md.Simple_Menu_API.Refresh_Menu` rebuilds the current
page through its `$onOpen` cue, which updates sliders after a reset.
`md.Simple_Menu_API.Update_Widget` (`$id` given at creation, updatable fields such as a
button's `$text`) is skipped when no widget with that id is on the current page. A
static MD cue's actions do not rerun in a save that already has the script, so a
`Globals` variable added later is null there (standard MD behaviour, not tested in this mod): read it with `@` and a fallback.

## 2026-10-11 - renamed-to-smart-turrets

Before the first release the mod was renamed from "Size-appropriate Turrets"
(`size_appropriate_turrets`) to "Smart Turrets" (`smart_turrets`), because roles no
longer depend on slot size. Renamed with it: the mdscript (`SmartTurrets`), the Lua
namespace, event and UI screen names (`SmartTurrets.*`), the SirNukes options menu ids
(`smart_turrets`, `smart_turrets_results`), the `md.Userdata` owner and the dropdown
option id (`smartturrets`). Settings stored under the old owner are not migrated. The
repository folder was renamed to `dev/smart_turrets` as well (remote
`stemps/x4-smart-turrets`).
