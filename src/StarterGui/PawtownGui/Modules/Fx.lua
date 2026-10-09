--!nonstrict
-- Fx — реакции интерфейса на события сервера (уровень, шаг главы, подарок, осколок, полоса препятствий, нюх)
-- и открытие окон по команде сервера (OpenUi: подсказки мира — коврик трюков, бутик, приют, ванна).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)
local WorldFx = require(script.Parent.WorldFx)

local Fx = {}

function Fx.init(gui: ScreenGui, openUi: (string) -> ())
	-- таймер полосы препятствий
	local layer = Ui.root(gui, "FxLayer", 3)
	local agility = Ui.card({ Name = "AgilityTimer", Size = UDim2.fromOffset(240, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Visible = false, Parent = layer })
	local agTime = Ui.text({ Name = "Time", Font = Theme.Font, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 2), Parent = agility })
	local agCp = Ui.text({ Name = "Gate", TextSize = 16, TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 36), Parent = agility })
	local agStart, agNext = 0, 1
	RunService.Heartbeat:Connect(function()
		if agility.Visible then
			agTime.Text = string.format("%.1f", os.clock() - agStart)
			agCp.Text = L.t("fx.gate", { n = agNext, total = #WorldData.Agility.Checkpoints })
		end
	end)

	Remotes.getEvent("Fx").OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "LevelUp" then
			Toasts.banner(L.m("fx.level", { n = a }), nil, Theme.Gold, 3)
		elseif kind == "Quest" then
			Toasts.banner("fx.step_done", "quest." .. tostring(a), Theme.Green, 3.5)
		elseif kind == "Daily" then
			Toasts.banner("fx.daily_done", "daily." .. tostring(a), Theme.Blue, 3)
		elseif kind == "Gift" then
			local item = ShopData.ById[b]
			Toasts.banner(L.m("fx.gift", { who = "npc." .. tostring(a) }), if item then item.Name else L.m("fx.treats", { n = c or 0 }), Theme.Pink, 4)
		elseif kind == "Shard" then
			Toasts.banner("fx.shard", "fx.shard_sub", Color3.fromRGB(150, 200, 255), 3.5)
		elseif kind == "Sniff" then
			WorldFx.sniff(a)
		elseif kind == "AgilityStart" then
			agStart, agNext = os.clock(), 1
			agility.Visible = true
		elseif kind == "AgilityCp" then
			agNext = a
		elseif kind == "AgilityEnd" then
			agility.Visible = false
		elseif kind == "Medal" then
			_ = c
		end
	end)
	Remotes.getEvent("OpenUi").OnClientEvent:Connect(function(name)
		if type(name) == "string" then
			openUi(name)
		end
	end)
	_ = Widgets
end

return Fx
