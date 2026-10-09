--!nonstrict
-- EmotesPanel — эмоции питомца, видимые всем игрокам рядом (виляние, поклон «давай играть», голос...).
-- Эмоции рядом с другим игроком повышают дружбу; эмоция рядом с почтальоном — ежедневное задание.
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
local EmotesPanel = {}

local EMOTES = {
	{ "Wag", "Paw" },
	{ "PlayBow", "Trick" },
	{ "Voice", "Emote" },
	{ "Sniff", "Sniff" },
	{ "Roll", "Fun" },
	{ "Mimic", "Spark" },
}

function EmotesPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Emotes")
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = panel.Body })
	New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 96), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local mimic
	for i, e in ipairs(EMOTES) do
		local b = New("TextButton", { Name = e[1], Text = "", AutoButtonColor = true, BackgroundColor3 = Theme.BgCard, LayoutOrder = i, Parent = holder })
		Widgets.corner(b, 12)
		Ui.icon(e[2], 46, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = b })
		Ui.text({ Text = L.k("emote." .. e[1]), Font = Theme.Font, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.new(0, 3, 1, -36), Parent = b })
		b.Activated:Connect(function()
			if Actions.call("Emote", e[1]) then
				panel.Close()
			end
		end)
		if e[1] == "Mimic" then
			mimic = b
		end
	end
	ClientState.onCore(function(core)
		mimic.Visible = SpeciesData.has(core.Species, "Mimic")
	end)
	return panel
end

return EmotesPanel
