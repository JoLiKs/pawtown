--!nonstrict
--[[
	SpeciesPanel — выбор вида в приюте: карточки 4 стандартных видов (значок, описание, способности,
	скорость/прыжок, кнопка «Выбрать»). Ниже — ссылка на «Ночь Искр» (редкие виды, в MVP — «скоро»).
	Выбор подтверждает сервер (ChooseSpecies): только стандартный вид и только пока вида нет.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local Actions = require(script.Parent.Actions)
local SpeciesCard = require(script.Parent.SpeciesCard)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local SpeciesPanel = {}

function SpeciesPanel.init(gui: ScreenGui, openRebirth: () -> ())
	local panel = Widgets.panel(gui, "Species", nil, { MinH = 540 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)
	local chooseButtons = {}
	local cards = {}
	for i, sp in ipairs(SpeciesData.Standard) do
		local id = sp.Id
		local btn: any = {
			Text = "btn.choose",
			OnClick = function()
				if Actions.call("ChooseSpecies", id) then
					panel.Close()
				end
			end,
		}
		table.insert(cards, SpeciesCard.build(sp, i, { Button = btn }))
		chooseButtons[id] = btn.Instance
	end
	-- редкие виды: «Звёздная ночь»
	local rare = Ui.card({
		Name = "Rare",
		BackgroundColor3 = Color3.fromRGB(60, 40, 90),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Widgets.padding(rare, 8)
	Ui.list(rare, 6)
	local rh = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, Parent = rare }
	)
	Ui.icon("Spark", 46, { Parent = rh })
	Ui.text({
		Text = L.k("species.rare_title"),
		Font = Theme.Font,
		TextSize = 20,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -56, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		Parent = rh,
	})
	Ui.text({
		Text = L.k("species.rare_desc"),
		TextSize = 16,
		TextColor3 = Theme.TextDim,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = rare,
	})
	local rb = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3, Parent = rare }
	)
	Widgets.button({
		Name = "SparkNight",
		Text = L.k("btn.look"),
		Color = Theme.Purple,
		MaxTextSize = 18,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 2),
		Parent = rb,
		OnClick = openRebirth,
	})
	table.insert(cards, rare)
	SpeciesCard.grid(scroll, cards)
	ClientState.onCore(function(core)
		for _, b in pairs(chooseButtons) do
			b.Visible = core.Species == ""
		end
	end)
	return panel
end

return SpeciesPanel
