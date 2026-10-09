--!strict
--[[
	Migrations — миграции сохранений между версиями шаблона. Чистая функция над таблицей (покрыта тестами).
	v1 (сборка разработки 0.0.x): Coins вместо Treats, потребности без Health, Bond массивом.
	v2 (MVP 0.1): Treats, Needs.Health, Bond = { Dad, Grandma, Kid }, Story, Daily, Cosmetics.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NeedsLogic = require(ReplicatedStorage.Shared.NeedsLogic)
local SpeciesData = require(ReplicatedStorage.Shared.SpeciesData)

local Migrations = {}

Migrations.CURRENT = 2

local function bad(v: any): boolean
	return type(v) ~= "number" or v ~= v or v < 0 or v == math.huge
end

function Migrations.run(data: { [string]: any }): boolean
	local changed = false
	local version = data.Version or 1
	if version < 2 then
		if data.Treats == nil and type(data.Coins) == "number" then
			data.Treats = data.Coins
		end
		data.Coins = nil
		if type(data.Bond) == "table" and data.Bond[1] ~= nil then
			local arr = data.Bond
			data.Bond = { Dad = arr[1] or 0, Grandma = arr[2] or 0, Kid = arr[3] or 0 }
		end
		data.Version = 2
		changed = true
	end
	-- потребности: всегда нормализуем (битые значения, отсутствующее здоровье)
	local before = data.Needs
	data.Needs = NeedsLogic.normalize(before)
	if type(before) ~= "table" or before.Health == nil then
		changed = true
	end
	-- вид: только известный; редкий без перерождения в v0.1 невозможен — сбрасываем на выбор
	if data.Species ~= nil and data.Species ~= "" and not SpeciesData.ById[data.Species] then
		data.Species = ""
		changed = true
	end
	if type(data.Settings) ~= "table" then
		data.Settings = { Lang = "auto" }
		changed = true
	end
	local lang = data.Settings.Lang
	if lang ~= "auto" and lang ~= "en" and lang ~= "ru" then
		data.Settings.Lang = "auto"
		changed = true
	end
	for _, key in ipairs({ "Treats", "Xp", "TotalTreats" }) do
		if data[key] ~= nil and bad(data[key]) then
			data[key] = 0
			changed = true
		end
	end
	if data.Level ~= nil and (bad(data.Level) or data.Level < 1 or data.Level > 100) then
		data.Level = 1
		changed = true
	end
	if type(data.Bond) == "table" then
		for k, v in pairs(data.Bond) do
			if bad(v) then
				data.Bond[k] = 0
				changed = true
			elseif v > 100 then
				data.Bond[k] = 100
				changed = true
			end
		end
	end
	return changed
end

return Migrations
