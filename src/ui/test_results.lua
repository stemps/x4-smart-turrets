-- Smart Turrets: data for the "Test results" page of the mod's options
-- (md/smart_turrets.xml). On request the role of every turret in the game's
-- turret library is sent to MD, which keeps it until the page is opened. MD pages are
-- built in MD, so the list has to travel there; UI events carry one Lua table each.

local ffi = require("ffi")
local C = ffi.C
pcall(ffi.cdef, "typedef uint64_t UniverseID;")
ffi.cdef[[
	bool IsWeaponModeCompatible(UniverseID weaponid, const char* macroname, const char* weaponmodeid);
]]

local ST = SmartTurrets
local SCREEN = "SmartTurrets"

-- Formatted like the encyclopedia's turret stats.
local function statsText(stats)
	local rotation = (stats.rotation >= 1) and ConvertIntegerString(stats.rotation, true, 0, true) or tostring(Helper.round(stats.rotation, 2))
	local lines = { ReadText(1001, 2419) .. ReadText(1001, 120) .. " " .. rotation .. " " .. ReadText(1001, 117) }
	if stats.beam then
		table.insert(lines, ReadText(1001, 4163))
	else
		table.insert(lines, ReadText(1001, 9086) .. ReadText(1001, 120) .. " " .. ConvertIntegerString(stats.bulletspeed, true, 0, true) .. " " .. ReadText(1001, 113))
	end
	if stats.area then
		table.insert(lines, ReadText(ST.TEXT_PAGE, 13))
	end
	return table.concat(lines, "\n")
end

-- Turrets without stats keep their size-based role, and turrets that support neither
-- mode (mining turrets, for example) are left alone, so neither is listed.
local function publishTurretRoles()
	AddUITriggeredEvent(SCREEN, "turretRolesBegin")
	local sent = 0
	for _, entry in ipairs(GetLibrary("weapons_turrets")) do
		local mode = ST.macroMode(entry.id)
		if mode and C.IsWeaponModeCompatible(0, entry.id, mode) then
			AddUITriggeredEvent(SCREEN, "turretRole", {
				fighters = (mode == "preferfighters") and 1 or 0,
				name = entry.name,
				info = statsText(ST.turretStats(entry.id)),
			})
			sent = sent + 1
		end
	end
	AddUITriggeredEvent(SCREEN, "turretRolesEnd")
	ST.log("sent the roles of " .. sent .. " turrets to the test results page")
end

-- The "Test results" button on the mod's options page. Opens the results page the way
-- SirNukes' submenu links do (OptionsMenu.openSubmenu, which keeps the Back history),
-- but only while the mod's own options page is shown.
local SETTINGS_MENU_ID = "smart_turrets"
RegisterEvent("SmartTurrets.openTestResults", function (_, resultsMenuId)
	local optionsMenu = Helper.getMenu("OptionsMenu")
	if (optionsMenu == nil) or (optionsMenu.openSubmenu == nil) then
		ST.log("OptionsMenu.openSubmenu not found; cannot open the test results")
	elseif optionsMenu.currentOption == SETTINGS_MENU_ID then
		optionsMenu.openSubmenu(resultsMenuId, resultsMenuId)
	end
end)

RegisterEvent("SmartTurrets.publishTurretRoles", function ()
	local ok, err = pcall(publishTurretRoles)
	if not ok then
		ST.log("sending the turret roles failed: " .. tostring(err))
	end
end)
