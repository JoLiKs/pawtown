--!nonstrict
--[[
	RebirthPanel — «Ночь Искр» (перерождение в редкий/легендарный вид). В v0.1 — только модель данных и
	проверка требований: список видов с условиями (галочки) и неактивная кнопка «Скоро».
	Редкие виды не продаются: их открывают только игрой (уровень, таланты, осколки, привязанность, медали).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local RebirthLogic = require(Shared:WaitForChild("RebirthLogic"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local RebirthPanel = {}

local TIER_COLOR = { Rare = Color3.fromRGB(90, 150, 255), Legendary = Color3.fromRGB(255, 190, 60) }

function RebirthPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "SparkNight", nil, { MinH = 520 })
	local intro = Ui.text({ Name = "Intro", Text = L.k("rebirth.intro"), TextSize = 15, TextColor3 = Theme.TextDim, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 4), TextYAlignment = Enum.TextYAlignment.Top, Parent = panel.Body })
	_ = intro
	local scroll = Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -56), Position = UDim2.fromOffset(4, 52) })
	Widgets.padding(scroll, 6)
	Ui.list(scroll, 6)
	local cards = {}
	local order = 0
	for _, sp in ipairs(SpeciesData.List) do
		if sp.Tier ~= "Standard" then
			order += 1
			local card = Ui.card({ Name = sp.Id, BackgroundColor3 = Theme.BgCard, BackgroundTransparency = 0, Size = UDim2.new(1, -4, 0, 120), LayoutOrder = order, Parent = scroll })
			Widgets.stroke(card, TIER_COLOR[sp.Tier] or Theme.Gold, 2)
			Ui.icon(sp.Id, 64, { Position = UDim2.fromOffset(8, 8), Parent = card })
			Ui.text({ Text = L.kn(sp.Name), Font = Theme.Font, TextSize = 19, Size = UDim2.new(1, -220, 0, 24), Position = UDim2.fromOffset(80, 6), Parent = card })
			Ui.text({ Text = L.k("tier." .. sp.Tier), Font = Theme.Font, TextSize = 15, TextColor3 = TIER_COLOR[sp.Tier] or Theme.Gold, Size = UDim2.fromOffset(130, 20), Position = UDim2.fromOffset(80, 30), Parent = card })
			Ui.text({ Text = L.kn(sp.Desc), TextSize = 15, TextColor3 = Theme.TextDim, Size = UDim2.new(1, -220, 0, 20), Position = UDim2.fromOffset(80, 50), Parent = card })
			local reqHolder = New("Frame", { Name = "Req", BackgroundTransparency = 1, Size = UDim2.new(1, -90, 0, 40), Position = UDim2.fromOffset(80, 74), Parent = card })
			local grid = New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 20), CellPadding = UDim2.fromOffset(4, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = reqHolder })
			_ = grid
			local soon = Widgets.button({
				Name = "Soon",
				Text = L.k("rebirth.soon"),
				Color = Theme.Disabled,
				MaxTextSize = 16,
				Size = UDim2.fromOffset(120, 40),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Parent = card,
			})
			soon.Active = false
			cards[sp.Id] = { Req = reqHolder }
		end
	end
	ClientState.onCore(function(core)
		for id, c in pairs(cards) do
			Widgets.clear(c.Req)
			local list = RebirthLogic.check(core, id)
			for i, r in ipairs(list) do
				Ui.text({
					Name = r.Key,
					Text = L.t("req." .. r.Key, { have = math.floor(r.Have), need = r.Need }),
					TextSize = 15,
					TextColor3 = if r.Ok then Theme.Green else Theme.TextDim,
					LayoutOrder = i,
					Parent = c.Req,
				})
			end
		end
	end)
	return panel
end

return RebirthPanel
