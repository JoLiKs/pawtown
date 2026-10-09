--!strict
--[[
	DayNightService — общий для сервера цикл дня и ночи (Lighting.ClockTime). Ночью горят фонари.
	Ночной сон перематывает время до утра, только если спят ВСЕ питомцы на сервере (как в мультиплеерных играх).
]]
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local DayNightService = {}

local worldTime = 0
local lights: { BasePart } = {}
local lastNight: boolean? = nil

function DayNightService.clock(): number
	return DayNight.clock(worldTime)
end

function DayNightService.isNight(): boolean
	return DayNight.isNight(DayNightService.clock())
end

function DayNightService.skipToMorning()
	worldTime += DayNight.secondsToMorning(DayNightService.clock())
	DayNightService.apply()
end

-- для тестов / отладки
function DayNightService.setClock(hours: number)
	local L = DayNight.length()
	local cur = DayNightService.clock()
	worldTime += ((hours - cur) % 24) / 24 * L
	DayNightService.apply()
end

local function paintLights(night: boolean)
	for _, b in ipairs(lights) do
		if b.Parent then
			b.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			b.Color = if night then Color3.fromRGB(255, 235, 170) else Color3.fromRGB(230, 230, 220)
		end
	end
end

function DayNightService.apply()
	local c = DayNightService.clock()
	Lighting.ClockTime = c
	local night = DayNight.isNight(c)
	Lighting.Brightness = if night then 1 else 2.2
	Lighting.OutdoorAmbient = if night then Color3.fromRGB(95, 100, 140) else Color3.fromRGB(150, 145, 160)
	Workspace:SetAttribute("Clock", c)
	Workspace:SetAttribute("Night", night)
	if night ~= lastNight then
		lastNight = night
		paintLights(night)
	end
end

function DayNightService.init()
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("NightLight") then
			table.insert(lights, d)
		end
	end
	-- отладка/демо: Workspace.Clock0 = начальный час
	local start = Workspace:GetAttribute("Clock0")
	if type(start) == "number" then
		DayNightService.setClock(start)
	end
	DayNightService.apply()
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			if Workspace:GetAttribute("ClockPaused") ~= true then
				worldTime += dt
			end
			DayNightService.apply()
		end
	end)
end

return DayNightService
