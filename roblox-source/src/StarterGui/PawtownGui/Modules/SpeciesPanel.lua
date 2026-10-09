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
	local grid = New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 262),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	_ = grid
	local chooseButtons = {}
	for i, sp in ipairs(SpeciesData.Standard) do
		local id = sp.Id
		local card = Ui.card({
			Name = id,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			LayoutOrder = i,
			Parent = scroll,
		})
		local iconBack = New("Frame", {
			BackgroundColor3 = sp.Look.Body,
			BackgroundTransparency = 0.6,
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.fromOffset(8, 8),
			Parent = card,
		})
		Widgets.corner(iconBack, 32)
		Ui.icon(
			id,
			56,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = iconBack }
		)
		Ui.text({
			Name = "Title",
			Text = L.kn(sp.Name),
			Font = Theme.Font,
			TextSize = 22,
			Size = UDim2.new(1, -84, 0, 26),
			Position = UDim2.fromOffset(80, 8),
			Parent = card,
		})
		Ui.text({
			Name = "Desc",
			Text = L.kn(sp.Desc),
			TextSize = 15,
			TextColor3 = Theme.TextDim,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -84, 0, 66),
			Position = UDim2.fromOffset(80, 34),
			Parent = card,
		})
		local y = 104
		for _, abId in ipairs(sp.Abilities) do
			local ab = SpeciesData.Abilities[abId]
			if ab then
				Ui.icon(
					Ui.ABILITY_ICON[abId] or "Paw",
					22,
					{ Position = UDim2.fromOffset(10, y), Parent = card }
				)
				Ui.text({
					Text = L.kn(ab.Name),
					TextSize = 15,
					Size = UDim2.new(1, -44, 0, 22),
					Position = UDim2.fromOffset(38, y),
					Parent = card,
				})
				y += 24
			end
		end
		-- скорость и прыжок
		local function stat(label: string, v: number, yy: number, color: Color3)
			Ui.text({
				Text = L.k(label),
				TextSize = 15,
				TextColor3 = Theme.TextDim,
				Size = UDim2.fromOffset(70, 18),
				Position = UDim2.fromOffset(10, yy),
				Parent = card,
			})
			local _, set = Ui.bar(card, UDim2.fromOffset(84, yy + 4), UDim2.new(1, -96, 0, 10), color)
			set(v)
		end
		stat("species.speed", (sp.Speed - 0.7) / 0.6, 182, Theme.Green)
		stat("species.jump", (sp.Jump - 0.7) / 0.6, 202, Theme.Blue)
		chooseButtons[id] = Widgets.button({
			Name = "Choose",
			Text = L.k("btn.choose"),
			Color = Theme.Green,
			MaxTextSize = 18,
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.new(0, 8, 1, -36),
			Parent = card,
			OnClick = function()
				if Actions.call("ChooseSpecies", id) then
					panel.Close()
				end
			end,
		})
	end
	local rare = Ui.card({
		Name = "Rare",
		BackgroundColor3 = Color3.fromRGB(60, 40, 90),
		BackgroundTransparency = 0,
		LayoutOrder = 10,
		Parent = scroll,
	})
	Ui.icon("Spark", 48, { Position = UDim2.fromOffset(10, 12), Parent = rare })
	Ui.text({
		Text = L.k("species.rare_title"),
		Font = Theme.Font,
		TextSize = 20,
		Size = UDim2.new(1, -70, 0, 26),
		Position = UDim2.fromOffset(66, 10),
		Parent = rare,
	})
	Ui.text({
		Text = L.k("species.rare_desc"),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -20, 0, 100),
		Position = UDim2.fromOffset(10, 70),
		Parent = rare,
	})
	Widgets.button({
		Name = "SparkNight",
		Text = L.k("btn.look"),
		Color = Theme.Purple,
		MaxTextSize = 18,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 1, -36),
		Parent = rare,
		OnClick = openRebirth,
	})
	ClientState.onCore(function(core)
		for _, b in pairs(chooseButtons) do
			b.Visible = core.Species == ""
		end
	end)
	return panel
end

return SpeciesPanel
