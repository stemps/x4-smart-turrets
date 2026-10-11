-- Smart Turrets: decides whether a turret should prefer fighters or capital
-- ships from its engine stats (turn rate, projectile speed, beam, area damage) and the
-- user's thresholds. Turrets without these stats (missile turrets, modded turrets
-- without a library entry) fall back to their slot size.

local ST = SmartTurrets

local MODE_BY_SIZE = {
	extralarge = "prefercapital",
	large = "prefercapital",
	medium = "preferfighters",
}
local AREA_DAMAGE_FIELDS = { "hullshieldareadpshot", "shieldonlyareadpshot", "hullonlyareadpshot", "hullnoshieldareadpshot" }

-- Library entries do not change while the game runs; false marks macros without stats.
local statsByMacro = {}

local function readStats(macro)
	local library = GetMacroData(macro, "infolibrary")
	if library ~= "weapons_turrets" then
		return false
	end
	local data = GetLibraryEntry(library, macro)
	if (type(data) ~= "table") or (type(data.rotation) ~= "number") or (type(data.bulletspeed) ~= "number") then
		ST.log(macro .. ": no turn rate or projectile speed in library " .. library .. "; using slot size")
		return false
	end
	local area = 0
	for _, field in ipairs(AREA_DAMAGE_FIELDS) do
		area = area + (tonumber(data[field]) or 0)
	end
	local stats = {
		rotation = data.rotation,
		bulletspeed = data.bulletspeed,
		beam = (data.isbeamweapon == true) or ((tonumber(data.isbeamweapon) or 0) ~= 0),
		area = area > 0,
	}
	ST.log(string.format("%s: turn rate %.1f deg/s, projectile speed %.0f m/s, beam %s, area damage %s",
		macro, stats.rotation, stats.bulletspeed, tostring(stats.beam), tostring(stats.area)))
	return stats
end

-- The stats of a turret macro ({ rotation, bulletspeed, beam, area }), or nil if it has
-- none (missile turrets, modded turrets without a library entry).
function ST.turretStats(macro)
	local stats = statsByMacro[macro]
	if stats == nil then
		stats = readStats(macro)
		statsByMacro[macro] = stats
	end
	return stats or nil
end

local function modeFromStats(stats)
	if stats.area and (stats.rotation >= ST.setting("areaFighterMinRotation")) then
		return "preferfighters"
	end
	if (stats.rotation >= ST.setting("fighterMinRotation")) and (stats.beam or (stats.bulletspeed >= ST.setting("fighterMinBulletSpeed"))) then
		return "preferfighters"
	end
	return "prefercapital"
end

-- The preset mode for a turret macro from its stats, or nil if it has none.
function ST.macroMode(macro)
	local stats = ST.turretStats(macro)
	return stats and modeFromStats(stats) or nil
end

-- The preset mode for an installed turret component, or nil if the preset leaves it
-- alone. slotsize is the turret's slot size ("medium", "large", ...).
function ST.turretMode(component, slotsize)
	local macro = GetComponentData(ConvertStringTo64Bit(tostring(component)), "macro")
	local mode = (type(macro) == "string") and (macro ~= "") and ST.macroMode(macro)
	return mode or MODE_BY_SIZE[slotsize]
end
