-- Smart Turrets: adds "Attack best-suited target" to the "All turrets"
-- mode dropdown of the map's ship info menu and of the cockpit's ship interactions menu
-- (DockedMenu). Selecting it sets each turret to "preferfighters" or "prefercapital"
-- by its role (turret_roles.lua). Turret modes are a closed engine enum, so this is a
-- preset over vanilla modes, not a new mode; the dropdown shows it whenever the turrets
-- currently match the mapping, so nothing is stored in saves.

local ffi = require("ffi")
local C = ffi.C

-- Vanilla menus may already have declared these types.
for _, declaration in ipairs({
	"typedef uint64_t UniverseID;",
	"typedef struct { const char* path; const char* group; } UpgradeGroup;",
}) do pcall(ffi.cdef, declaration) end
ffi.cdef[[
	size_t GetNumUpgradeSlots(UniverseID destructibleid, const char* macroname, const char* upgradetypename);
	const char* GetSlotSize(UniverseID defensibleid, UniverseID moduleid, const char* macroname, bool ismodule, const char* upgradetypename, size_t slot);
	const char* GetTurretGroupMode2(UniverseID defensibleid, UniverseID contextid, const char* path, const char* group);
	UniverseID GetUpgradeSlotCurrentComponent(UniverseID destructibleid, const char* upgradetypename, size_t slot);
	const char* GetWeaponMode(UniverseID weaponid);
	bool IsWeaponModeCompatible(UniverseID weaponid, const char* macroname, const char* weaponmodeid);
	void SetTurretGroupMode2(UniverseID defensibleid, UniverseID contextid, const char* path, const char* group, const char* mode);
	void SetWeaponMode(UniverseID weaponid, const char* mode);
]]

local ST = SmartTurrets
local OPTION_ID = "smartturrets"
-- uiTriggerID of the cockpit menu's "All turrets" mode dropdown (vanilla and UI Extensions).
local DOCKED_ALL_DROPDOWN = "docked_turretconfig_modes"

local log = ST.log

-- ---------------------------------------------------------------------------
-- Preset logic. Both menus keep the displayed ship's ungrouped turrets in
-- menu.turrets (components) and its turret groups in menu.turretgroups, built the
-- same way, so the preset works on either menu.
-- ---------------------------------------------------------------------------

-- menu.turrets holds only the components of ungrouped turrets; their slot size (the
-- role fallback) needs the slot index, so walk the slots the same way the menus do.
local function singularTurretSizes(ship)
	local sizes = {}
	local numslots = tonumber(C.GetNumUpgradeSlots(ship, "", "turret"))
	for slot = 1, numslots do
		local current = C.GetUpgradeSlotCurrentComponent(ship, "turret", slot)
		if current ~= 0 then
			sizes[tostring(current)] = ffi.string(C.GetSlotSize(ship, 0, "", false, "turret", slot))
		end
	end
	return sizes
end

-- The turrets and groups of the displayed ship that the preset changes, each with its
-- target mode. Turrets without a role and weapons that do not support their mode stay
-- untouched.
local function presetTargets(menu, ship)
	local targets = {}
	if #menu.turrets > 0 then
		local sizes = singularTurretSizes(ship)
		for _, turret in ipairs(menu.turrets) do
			local mode = ST.turretMode(turret, sizes[tostring(turret)])
			if mode and C.IsWeaponModeCompatible(turret, "", mode) then
				table.insert(targets, { turret = turret, mode = mode })
			end
		end
	end
	for _, group in ipairs(menu.turretgroups) do
		local mode = (group.currentcomponent ~= 0) and ST.turretMode(group.currentcomponent, group.slotsize)
		if mode and C.IsWeaponModeCompatible(group.currentcomponent, "", mode) then
			table.insert(targets, { group = group, mode = mode })
		end
	end
	return targets
end

local function applyPreset(menu, ship)
	local targets = presetTargets(menu, ship)
	for _, target in ipairs(targets) do
		if target.turret then
			C.SetWeaponMode(target.turret, target.mode)
		else
			local group = target.group
			C.SetTurretGroupMode2(ship, group.context, group.path, group.group, target.mode)
		end
	end
	log("applied preset to " .. #targets .. " turrets and turret groups (" .. menu.name .. ")")
end

-- Mirrors vanilla's "all" check, which ignores groups without operational turrets.
local function isPresetApplied(menu, ship)
	local checked = 0
	for _, target in ipairs(presetTargets(menu, ship)) do
		local mode
		if target.turret then
			mode = ffi.string(C.GetWeaponMode(target.turret))
		elseif target.group.operational > 0 then
			local group = target.group
			mode = ffi.string(C.GetTurretGroupMode2(ship, group.context, group.path, group.group))
		end
		if mode then
			if mode ~= target.mode then
				return false
			end
			checked = checked + 1
		end
	end
	return checked > 0
end

-- ---------------------------------------------------------------------------
-- Dropdown integration shared by both menus.
-- ---------------------------------------------------------------------------

-- Adds the preset to an "All turrets" mode dropdown cell and routes its selection to
-- applyPreset; every other option still goes to the menu's own handler.
local function addPresetOption(cell, menu, ship, onApplied)
	-- Another mod (UI Extensions' Subsystem Targeting Orders callback) may have put
	-- something else into this cell.
	if (cell == nil) or (cell.type ~= "dropdown") or (cell.properties.options == nil) then
		log("'All' turret row has no mode dropdown in " .. menu.name .. "; preset not offered")
		return
	end
	table.insert(cell.properties.options, { id = OPTION_ID, text = ReadText(ST.TEXT_PAGE, 2), icon = "", displayremoveoption = false })
	local originalConfirmed = cell.handlers.onDropDownConfirmed
	cell.handlers.onDropDownConfirmed = function (dropdown, newturretmode, ...)
		if newturretmode == OPTION_ID then
			if onApplied then
				onApplied()
			end
			applyPreset(menu, ship)
		elseif originalConfirmed then
			return originalConfirmed(dropdown, newturretmode, ...)
		end
	end
end

-- Vanilla returns "" for the "All" row when the modes differ; report the preset
-- instead when the differences are exactly the preset's mapping.
local function wrapGetDropDownTurretModeOption(menu)
	local original = menu.getDropDownTurretModeOption
	menu.getDropDownTurretModeOption = function (defensibleorturret, context, path, group)
		local result = original(defensibleorturret, context, path, group)
		if (context == "all") and (path == nil) and (result == "") then
			local ok, applied = pcall(isPresetApplied, menu, defensibleorturret)
			if not ok then
				log("checking the preset failed in " .. menu.name .. ": " .. tostring(applied))
			elseif applied then
				return OPTION_ID
			end
		end
		return result
	end
end

-- ---------------------------------------------------------------------------
-- Map: ship info menu. The rows come from a separate function, so wrap it.
-- ---------------------------------------------------------------------------

local function hookMapMenu(mapMenu)
	if (mapMenu.setupLoadoutInfoSubmenuRows == nil) or (mapMenu.getDropDownTurretModeOption == nil) then
		log("MapMenu turret config functions not found; map preset inactive")
		return false
	end

	local function addToMapRows(inputtable, ship)
		for _, row in ipairs(inputtable.rows) do
			if row.rowdata == "info_turretconfig" then
				addPresetOption(row[5], mapMenu, ship, function () mapMenu.noupdate = false end)
				return
			end
		end
	end

	local original = mapMenu.setupLoadoutInfoSubmenuRows
	local loggedEntry = false
	local function afterSetup(mode, inputtable, inputobject, ...)
		if mode == "ship" then
			if not loggedEntry then
				loggedEntry = true
				log("ship turret config rows hooked (MapMenu)")
			end
			local ok, err = pcall(addToMapRows, inputtable, inputobject)
			if not ok then
				log("adding the preset option failed in MapMenu: " .. tostring(err))
			end
		end
		return ...
	end
	mapMenu.setupLoadoutInfoSubmenuRows = function (mode, inputtable, inputobject, instance, ...)
		return afterSetup(mode, inputtable, inputobject, original(mode, inputtable, inputobject, instance, ...))
	end

	wrapGetDropDownTurretModeOption(mapMenu)
	return true
end

-- ---------------------------------------------------------------------------
-- Cockpit: ship interactions menu (DockedMenu). Its display() builds all rows inline
-- and shows the frame at the end, so the only point between building and showing is
-- the frame's display call. Helper.createFrameHandle is looked up by field, so wrap it
-- and, for DockedMenu frames only, patch the finished rows before they are shown.
-- ---------------------------------------------------------------------------

local function hookDockedMenu(dockedMenu)
	if (dockedMenu.getDropDownTurretModeOption == nil) or (Helper.createFrameHandle == nil) then
		log("DockedMenu turret config functions not found; cockpit preset inactive")
		return false
	end

	local loggedEntry = false
	local function addToDockedFrame(frame)
		for _, widget in ipairs(frame.content) do
			if (widget.type == "table") and widget.rows then
				for _, row in ipairs(widget.rows) do
					if (row.rowdata == "turret_config") and row[2] and (row[2].properties.uiTriggerID == DOCKED_ALL_DROPDOWN) then
						if not loggedEntry then
							loggedEntry = true
							log("ship turret config rows hooked (DockedMenu)")
						end
						addPresetOption(row[2], dockedMenu, dockedMenu.currentplayership)
						return
					end
				end
			end
		end
	end

	local originalCreateFrameHandle = Helper.createFrameHandle
	Helper.createFrameHandle = function (menu, ...)
		local frame = originalCreateFrameHandle(menu, ...)
		if menu == dockedMenu then
			local originalDisplay = frame.display
			frame.display = function (self, ...)
				local ok, err = pcall(addToDockedFrame, self)
				if not ok then
					log("adding the preset option failed in DockedMenu: " .. tostring(err))
				end
				return originalDisplay(self, ...)
			end
		end
		return frame
	end

	wrapGetDropDownTurretModeOption(dockedMenu)
	return true
end

local function init()
	local hooked = 0
	for name, hook in pairs({ MapMenu = hookMapMenu, DockedMenu = hookDockedMenu }) do
		local menu = Helper.getMenu(name)
		if menu == nil then
			log(name .. " not found; its preset is inactive")
		elseif hook(menu) then
			hooked = hooked + 1
		end
	end
	log("loaded (" .. hooked .. " menus)")
end

init()
