--!nonstrict
--[[
	Cutscene — короткие сюжетные сцены поверх игры: кинорамка (чёрные полосы), слайды текста со значком.
	  * Adoption — после выбора вида: смотрительница, новая семья, смутное воспоминание;
	  * Dream — сон главы 1: звездопад, Полуночный Кот, «найди свои воспоминания».
	Камера и персонаж — как есть (сервер переносит питомца на остров сна). Кнопка «Пропустить».
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local Cutscene = {}

Cutscene.SCENES = {
	Adoption = { { "Home", "cut.adopt.1" }, { "Love", "cut.adopt.2" }, { "Spark", "cut.adopt.3" } },
	Dream = {
		{ "Spark", "cut.dream.1" },
		{ "MidnightCat", "cut.dream.2" },
		{ "MidnightCat", "cut.dream.3" },
		{ "Shard", "cut.dream.4" },
	},
}
Cutscene.SLIDE = 2.6

function Cutscene.init(gui: ScreenGui, closeAll: (() -> ())?)
	local layer = New("Frame", {
		Name = "Cutscene",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 80,
		Parent = gui,
	})
	local top = New("Frame", {
		Name = "BarTop",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.13),
		ZIndex = 80,
		Parent = layer,
	})
	local bottom = New("Frame", {
		Name = "BarBottom",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.2),
		ZIndex = 80,
		Parent = layer,
	})
	_ = top
	local inner, _k = Ui.root(layer, "Inner", 81)
	local iconHolder = New("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(90, 90),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 30, 1, -18),
		ZIndex = 82,
		Parent = inner,
	})
	local text = Ui.text({
		Name = "Text",
		Font = Theme.Font,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(255, 240, 220),
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -300, 0, 110),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 136, 1, -8),
		ZIndex = 82,
		Parent = inner,
	})
	local skip = Widgets.button({
		Name = "Skip",
		Text = L.k("btn.skip"),
		Color = Theme.BgLight,
		MaxTextSize = 18,
		Size = UDim2.fromOffset(120, 44),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -40),
		ZIndex = 83,
		Parent = inner,
	})
	_ = bottom
	local token = 0
	local savedClock = nil
	local function stop()
		token += 1
		layer.Visible = false
		if savedClock then
			savedClock = nil
		end
	end
	skip.Activated:Connect(stop)

	function Cutscene.play(name: string)
		local scene = Cutscene.SCENES[name]
		if not scene then
			return
		end
		token += 1
		local my = token
		if closeAll then
			closeAll()
		end
		layer.Visible = true
		for _, slide in ipairs(scene) do
			if token ~= my then
				return
			end
			Widgets.clear(iconHolder)
			Ui.icon(slide[1], 90, { ZIndex = 83, Parent = iconHolder })
			text.Text = L.t(slide[2])
			text.TextTransparency = 1
			Widgets.tween(text, 0.4, { TextTransparency = 0 })
			if name == "Dream" then
				Lighting.ClockTime = 0 -- клиентский вид: звёздная ночь во сне
			end
			task.wait(Cutscene.SLIDE)
		end
		if token == my then
			stop()
		end
	end
	Remotes.getEvent("Cutscene").OnClientEvent:Connect(function(name)
		if type(name) == "string" then
			task.spawn(Cutscene.play, name)
		end
	end)
	return Cutscene
end

return Cutscene
