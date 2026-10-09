--!nonstrict
--[[
	ChoicePanel — сюжетный выбор главы 2: что сделать с найденной посылкой почтальона.
	Варианты и последствия (репутация Кленовой улицы, лакомства) — из QuestData.CHOICES; решает сервер (StoryChoice).
	Поток (UIListLayout + AutomaticSize): текст переносится, ничего не обрезается на телефоне.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local QuestData = require(Shared:WaitForChild("QuestData"))

local Actions = require(script.Parent.Actions)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local ChoicePanel = {}

function ChoicePanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Choice", nil, { MinH = 380 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 10)
	Ui.list(scroll, 10)
	local head = New("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 1,
		Parent = scroll,
	})
	Ui.icon("Shop", 60, { Parent = head })
	Ui.text({
		Name = "Title",
		Text = L.k("choice.parcel.title"),
		Font = Theme.Font,
		TextSize = 22,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -72, 1, 0),
		Position = UDim2.fromOffset(72, 0),
		Parent = head,
	})
	Ui.text({
		Name = "Story",
		Text = L.k("choice.parcel.text"),
		TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = scroll,
	})
	for i, opt in ipairs(QuestData.CHOICES.c2_parcel) do
		local card = Ui.card({
			Name = "Opt_" .. opt.Id,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2 + i,
			Parent = scroll,
		})
		Widgets.padding(card, 8)
		Ui.list(card, 6)
		Ui.text({
			Name = "Effect",
			Text = L.k("choice.parcel." .. opt.Id .. ".effect", { rep = opt.RepPts, n = opt.Treats }),
			TextSize = 15,
			TextColor3 = if opt.RepPts > 0 then Theme.Green else Theme.Orange,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
		})
		local row = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 1,
			Parent = card,
		})
		Widgets.button({
			Name = "Choose",
			Text = L.k("choice.parcel." .. opt.Id),
			Color = if opt.RepPts > 0 then Theme.Green else Theme.Orange,
			MaxTextSize = 18,
			Size = UDim2.new(1, 0, 0, 38),
			Parent = row,
			OnClick = function()
				if Actions.call("StoryChoice", "c2_parcel", opt.Id) then
					panel.Close()
				end
			end,
		})
	end
	return panel
end

return ChoicePanel
