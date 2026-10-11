# Runtime architecture

## Repository layout

`src/` is the mod: exactly the files the game loads and every release ships.
Everything else is development-only: `docs/`, `images/` and metadata.

## UI module

`src/ui.xml` registers one Lua file in the `menus` environment, loaded after
`ego_detailmonitorhelper`, `ego_detailmonitor` and (if present) kuertee UI
Extensions, so `MapMenu` already exists when it runs.

`src/ui/size_appropriate_turrets.lua` owns the whole feature, the
"Attack size-appropriate target" preset in the "All turrets" mode dropdown of two
menus:

- preset logic, shared by both menus (they build `menu.turrets` and
  `menu.turretgroups` the same way): L/XL turrets and groups -> `prefercapital`,
  M -> `preferfighters`, only where `IsWeaponModeCompatible` allows it;
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

## Translations

`src/t/0001.xml` is the English source for text page 992101 (id 1 mod name, id 2 dropdown
label); the 15
`0001-lNNN.xml` files carry the same page/text ids for every other game locale.

## Release tooling

Release, publication, translation checks, `just link` and `just log` come from
x4-modkit; see its README and ARCHITECTURE.md.
