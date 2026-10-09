--!strict
--[[
	RebirthLogic — перерождение «Звёздная ночь» (редкие и легендарные виды). В MVP — только проверка требований
	и окно-заглушка «скоро»; сама смена вида — v0.2 (см. docs/DESIGN.md).
	Требования: Level, Nose/Agility/Charm (очки талантов в ветке), Shards (осколков памяти), Bond (сумма привязанности
	семьи), Gold (золотых медалей трюков).
]]
local Progression = require(script.Parent.Progression)
local SpeciesData = require(script.Parent.SpeciesData)

local RebirthLogic = {}

RebirthLogic.REQ_ORDER = { "Level", "Nose", "Agility", "Charm", "Shards", "Bond", "Gold" }
RebirthLogic.AVAILABLE = false -- v0.1: «скоро»

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _ in pairs(t) do
			n += 1
		end
	end
	return n
end

-- Текущее значение показателя для требований
function RebirthLogic.stat(data: any, key: string): number
	if key == "Level" then
		return data.Level or 1
	elseif key == "Nose" or key == "Agility" or key == "Charm" then
		return Progression.branchPoints(data.Talents, key)
	elseif key == "Shards" then
		return count(data.Shards)
	elseif key == "Bond" then
		local s = 0
		for _, v in pairs(data.Bond or {}) do
			s += v
		end
		return s
	elseif key == "Gold" then
		local n = 0
		for _, t in pairs(data.Tricks or {}) do
			if type(t) == "table" and (t.Best or 0) >= 3 then
				n += 1
			end
		end
		return n
	end
	return 0
end

-- { { Key, Need, Have, Ok } ... }, allOk
function RebirthLogic.check(data: any, speciesId: string): ({ { [string]: any } }, boolean)
	local s = SpeciesData.ById[speciesId]
	local out = {}
	local all = true
	if not s or not s.Req then
		return out, false
	end
	local req = s.Req :: { [string]: number }
	for _, key in ipairs(RebirthLogic.REQ_ORDER) do
		local need = req[key]
		if need then
			local have = RebirthLogic.stat(data, key)
			local ok = have >= need
			all = all and ok
			table.insert(out, { Key = key, Need = need, Have = have, Ok = ok })
		end
	end
	return out, all
end

return RebirthLogic
