--!nonstrict
-- SettingsPanel — язык (авто / English / Русский) и сведения об игре. Общение — только стандартный чат Roblox.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local L = require(Shared:WaitForChild("Locale"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local SettingsPanel = {}

function SettingsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Settings")
	local body = panel.Body
	Ui.text({ Text = L.k("settings.lang"), Font = Theme.Font, TextSize = 19, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(12, 8), Parent = body })
	local buttons = {}
	for i, choice in ipairs({ "auto", "en", "ru" }) do
		buttons[choice] = Widgets.button({
			Name = "Lang_" .. choice,
			Text = L.k("lang." .. choice),
			Color = Theme.BgLight,
			MaxTextSize = 18,
			Size = UDim2.new(1 / 3, -12, 0, 44),
			Position = UDim2.new((i - 1) / 3, 8, 0, 40),
			Parent = body,
			OnClick = function()
				Actions.call("SetLanguage", choice)
			end,
		})
	end
	Ui.text({
		Text = L.k("settings.chat"),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.fromOffset(12, 100),
		Parent = body,
	})
	Ui.text({
		Text = L.k("settings.version", { v = Config.VERSION }),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.new(0, 12, 1, -28),
		Parent = body,
	})
	ClientState.onCore(function(core)
		for choice, b in pairs(buttons) do
			b.BackgroundColor3 = if (core.Lang or "auto") == choice then Theme.Green else Theme.BgLight
		end
	end)
	return panel
end

return SettingsPanel
