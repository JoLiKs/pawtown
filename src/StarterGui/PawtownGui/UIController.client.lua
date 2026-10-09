--!nonstrict
--[[
	UIController — собирает весь интерфейс Pawtown кодом (без внешних ассетов, значки — из примитивов Icons).
	Лежит внутри ScreenGui "PawtownGui" (ResetOnSpawn = false).
]]
local gui = script.Parent :: ScreenGui
gui.DisplayOrder = 50
gui.IgnoreGuiInset = false
local Modules = script.Parent:WaitForChild("Modules")

local ClientState = require(Modules:WaitForChild("ClientState"))
local Toasts = require(Modules:WaitForChild("Toasts"))
local Hud = require(Modules:WaitForChild("Hud"))

ClientState.init()
Toasts.init(gui)

local panels = {}
local openPanel
local function openRebirth()
	openPanel("SparkNight", true)
end
panels.Species = require(Modules:WaitForChild("SpeciesPanel")).init(gui, openRebirth)
panels.Tricks = require(Modules:WaitForChild("TricksPanel")).init(gui)
panels.Shop = require(Modules:WaitForChild("ShopPanel")).init(gui)
panels.Quests = require(Modules:WaitForChild("QuestsPanel")).init(gui)
panels.Talents = require(Modules:WaitForChild("TalentsPanel")).init(gui, openRebirth)
panels.SparkNight = require(Modules:WaitForChild("RebirthPanel")).init(gui)
panels.Settings = require(Modules:WaitForChild("SettingsPanel")).init(gui)
panels.Emotes = require(Modules:WaitForChild("EmotesPanel")).init(gui)
panels.Choice = require(Modules:WaitForChild("ChoicePanel")).init(gui)
panels.Friends = require(Modules:WaitForChild("FriendsPanel")).init(gui)
local Bath = require(Modules:WaitForChild("BathGame")).init(gui)

openPanel = function(name: string, force: boolean?)
	if name == "Bath" then
		for _, p in pairs(panels) do
			if p.IsOpen() then
				p.Close()
			end
		end
		Bath.open()
		return
	end
	local target = panels[name]
	if not target then
		return
	end
	local wasOpen = target.IsOpen()
	for _, p in pairs(panels) do
		if p.IsOpen() then
			p.Close()
		end
	end
	if not wasOpen or force then
		target.Open()
	end
end

Hud.init(gui, openPanel)
require(Modules:WaitForChild("Fx")).init(gui, function(name: string)
	openPanel(name, true)
end)
require(Modules:WaitForChild("Cutscene")).init(gui, function()
	for _, p in pairs(panels) do
		if p.IsOpen() then
			p.Close()
		end
	end
end)
require(Modules:WaitForChild("WorldFx")).init()
require(Modules:WaitForChild("Abilities")).init()

-- Смена языка: привязанные тексты (L.k) перерисовывает Locale, остальное — повторный снимок состояния
local L = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Locale"))
L.onChanged(ClientState.refresh)
ClientState.requestResync()

-- для тестов интерфейса (UiDriver): открыть окно по имени
gui:SetAttribute("Ready", true)
gui:GetAttributeChangedSignal("OpenPanel"):Connect(function()
	local name = gui:GetAttribute("OpenPanel")
	if type(name) == "string" and name ~= "" then
		openPanel(name, true)
	end
end)
