# Runtime architecture

## Repository layout

`src/` is the mod: exactly the files the game loads and every release ships.
Everything else is development-only: `docs/`, `images/` and metadata.

## Settings and test results (MD)

`src/md/smart_turrets.xml` registers two options menus with SirNukes Mod
Support APIs (`md.Simple_Menu_API.Register_Options_Menu`): the mod's page in "Extension
Options" (an intro, then one bold heading per turret group naming its role: fast
turrets with the turn rate and projectile speed sliders, area damage turrets with
their turn rate slider and the "Shoot missiles first" checkbox, and all other turrets
without settings; then a "Reset to defaults" button and a "View results" button that
shows the current fighter/missile/capital counts and is updated with `Update_Widget`
when new roles arrive) and the private "View results" page, one column per mode.
Each entry in `Load_Sliders` is a slider or (`$checkbox`) a checkbox; `$heading` starts
a group. Reset stores the defaults and rebuilds the
page with `Refresh_Menu`. The "View results" button raises the Lua event
`SmartTurrets.openTestResults`, and `ui/test_results.lua` opens the page with
`OptionsMenu.openSubmenu` (as SirNukes' links do), because link rows need a double
click. It stores the thresholds per user profile with `md.Userdata`
(owner `smart_turrets`, key `settings`; the `$key` names are storage keys and
its `$default` values must match `ST.DEFAULTS`).

Data flow, on every `md.Simple_Menu_API.Reloaded` (game load, `/reloadui`) and every
slider confirm: MD raises the Lua event `SmartTurrets.<key>` per threshold (the checkbox as 1/0),
then `SmartTurrets.publishTurretRoles`; `ui/test_results.lua` answers with UI
events on screen `SmartTurrets` (`turretRolesBegin`, one `turretRole` table per
turret with its preset `mode`, `turretRolesEnd`), which MD keeps in `Globals` until the results page is opened.
Options pages must be built in the frame they open, so the data has to be there before.

## UI module

`src/ui.xml` registers three Lua files in the `menus` environment, loaded after
`ego_detailmonitorhelper`, `ego_detailmonitor` and (if present) kuertee UI Extensions, so
`MapMenu` and `DockedMenu` already exist when they run. Load order matters: the first
file creates the shared global namespace `SmartTurrets`.

- `src/ui/settings.lua`: the namespace, `log`, the threshold defaults and
  `ST.setting(key)`, which returns the last value received from the MD settings or the
  default.
- `src/ui/turret_roles.lua`: `ST.turretMode(component, slotsize)` (and
  `ST.macroMode(macro)`, `ST.turretStats(macro)` for a macro without a component) decides
  `preferfighters`, `prefercapital` or (area damage turrets that qualify for fighters,
  while `areaMissilesFirst` is on) `prefermissiles` from the turret macro's library entry
  (`GetLibraryEntry("weapons_turrets", macro)`: `rotation`, `bulletspeed`,
  `isbeamweapon`, area damage fields) and the thresholds; turrets without such an entry
  (missile turrets, modded turrets without one) fall back to the slot size. Stats are
  cached per macro and logged once each. `ST.compatibleMode` checks the mode with
  `IsWeaponModeCompatible` and falls back from `prefermissiles` to `preferfighters`;
  both menus and the results page use it.
- `src/ui/smart_turrets.lua`: the "Attack best-suited target" preset in
  the "All turrets" mode dropdown of two menus:
  - preset logic, shared by both menus (they build `menu.turrets` and
    `menu.turretgroups` the same way): each turret and group gets `ST.turretMode`,
    only where `IsWeaponModeCompatible` allows it;
  - `addPresetOption` adds the option to a dropdown cell and wraps its confirm handler;
    `wrapGetDropDownTurretModeOption` makes the "All" row show the preset when the
    current modes match the mapping. The preset is derived from engine state, never
    stored, so the mod adds nothing to saves;
  - map ship info menu (`MapMenu`): wraps `setupLoadoutInfoSubmenuRows` and patches
    row `info_turretconfig` (mode `ship`) after vanilla builds it;
  - cockpit ship interactions menu (`DockedMenu`): its `display()` builds rows inline,
    so the mod wraps `Helper.createFrameHandle` and, for DockedMenu frames only,
    patches the "All" row (uiTriggerID `docked_turretconfig_modes`) just before the
    frame's `display`.

- `src/ui/test_results.lua`: on `SmartTurrets.publishTurretRoles`, sends the
  role and formatted stats of every turret in `GetLibrary("weapons_turrets")` that has
  stats and supports its mode (`IsWeaponModeCompatible(0, macro, mode)`) to MD; it also
  opens the results page for the "View results" button.

## Translations

`src/t/0001.xml` is the English source for text page 992101 (id 1 mod name, id 2 dropdown
label, ids 3-8 slider labels and mouseovers, ids 10-14 results page, id 15 reset button,
ids 16-22 settings page text (17, 19 and 20 group headings) with 22 also the results page
title, ids 23-24 missiles-first checkbox label (also the results column title) and
mouseover, id 25 the missile turret note; ids 7, 9 and 18 are unused); the 15
`0001-lNNN.xml` files carry the same page/text ids for every other game locale.

## Release tooling

Release, publication, translation checks, `just link` and `just log` come from
x4-modkit; see its README and ARCHITECTURE.md.
