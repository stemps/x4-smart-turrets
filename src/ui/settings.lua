-- Smart Turrets: shared namespace and the user's turret role thresholds.
-- The thresholds are edited on the mod's page in the "Extension Options" menu of SirNukes
-- Mod Support APIs and stored per user profile by md/smart_turrets.xml, which
-- sends each value here as a Lua event after every game load or /reloadui and on every
-- change; until then the defaults apply.

SmartTurrets = SmartTurrets or {}
local ST = SmartTurrets

ST.TEXT_PAGE = 992101

function ST.log(message)
	DebugError("smart_turrets: " .. message)
end

-- Defaults sit in the gaps of the vanilla and DLC turret stats (9.0): M turrets turn at
-- 40-60 deg/s (plasma, long-range beams, railguns) or 80-180 deg/s (lasers, gatlings,
-- flak, shotguns); plasma flies at 600-1000 m/s, every other projectile at 1400 m/s or
-- more. areaMissilesFirst is an on/off option (1/0). Must match the $default values in
-- md/smart_turrets.xml.
ST.DEFAULTS = {
	fighterMinRotation = 75,
	fighterMinBulletSpeed = 1200,
	areaFighterMinRotation = 45,
	areaMissilesFirst = 1,
}

local values = {}

function ST.setting(key)
	local value = values[key]
	if type(value) == "number" then
		return value
	end
	return ST.DEFAULTS[key]
end

local function init()
	for key in pairs(ST.DEFAULTS) do
		RegisterEvent("SmartTurrets." .. key, function (_, value)
			value = tonumber(value)
			if value then
				values[key] = value
				ST.log("setting " .. key .. " = " .. value)
			end
		end)
	end
end

init()
