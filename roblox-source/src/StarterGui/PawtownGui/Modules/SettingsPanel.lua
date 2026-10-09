--!nonstrict
--[[
	SettingsPanel — язык (авто / English / Русский), звук (музыка вкл/выкл, звуки вкл/выкл — глушат и звуки
	персонажей, громкость музыки, состояние музыки) и сведения об игре. Общение — только стандартный чат Roblox.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioData = require(Shared:WaitForChild("AudioData"))
local Config = require(Shared:WaitForChild("Config"))
local L = require(Shared:WaitForChild("Locale"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local SettingsPanel = {}

function SettingsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Settings", nil, { MinH = 470 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)
	Ui.list(scroll, 8)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function heading(text: any)
		Ui.text({
			Text = text,
			Font = Theme.Font,
			TextSize = 19,
			Size = UDim2.new(1, -8, 0, 26),
			LayoutOrder = nextOrder(),
			Parent = scroll,
		})
	end
	local function row(name: string, h: number): Frame
		return New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			LayoutOrder = nextOrder(),
			Parent = scroll,
		})
	end

	heading(L.k("settings.lang"))
	local langRow = row("LangRow", 44)
	local buttons = {}
	for i, choice in ipairs({ "auto", "en", "ru" }) do
		buttons[choice] = Widgets.button({
			Name = "Lang_" .. choice,
			Text = L.k("lang." .. choice),
			Color = Theme.BgLight,
			MaxTextSize = 18,
			Size = UDim2.new(1 / 3, -8, 1, 0),
			Position = UDim2.new((i - 1) / 3, 4, 0, 0),
			Parent = langRow,
			OnClick = function()
				Actions.call("SetLanguage", choice)
			end,
		})
	end

	heading(L.k("settings.sound"))
	local current = AudioData.normalize(nil)
	local toggles = row("SoundRow", 44)
	local musicBtn = Widgets.button({
		Name = "MusicToggle",
		Text = "",
		Color = Theme.Green,
		MaxTextSize = 17,
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		Parent = toggles,
		OnClick = function()
			Actions.call("SetAudio", "Music", not current.Music)
		end,
	})
	local sfxBtn = Widgets.button({
		Name = "SfxToggle",
		Text = "",
		Color = Theme.Green,
		MaxTextSize = 17,
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.new(0.5, 4, 0, 0),
		Parent = toggles,
		OnClick = function()
			Actions.call("SetAudio", "Sfx", not current.Sfx)
		end,
	})
	local volRow = row("VolumeRow", 44)
	local function volBtn(name: string, text: string, delta: number, pos: UDim2)
		return Widgets.button({
			Name = name,
			Text = text,
			Color = Theme.BgLight,
			MaxTextSize = 22,
			Size = UDim2.fromOffset(52, 44),
			Position = pos,
			Parent = volRow,
			OnClick = function()
				local v = math.clamp(current.MusicVol + delta, 0, 1)
				Actions.call("SetAudio", "MusicVol", math.floor(v * 10 + 0.5) / 10)
			end,
		})
	end
	volBtn("VolDown", "-", -AudioData.VOL_STEP, UDim2.fromOffset(4, 0))
	volBtn("VolUp", "+", AudioData.VOL_STEP, UDim2.new(1, -56, 0, 0))
	local volLabel = Ui.text({
		Name = "VolumeLabel",
		Text = "",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -128, 1, 0),
		Position = UDim2.fromOffset(64, 0),
		Parent = volRow,
	})
	local statusLabel = Ui.text({
		Name = "MusicStatusLabel",
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -8, 0, 20),
		LayoutOrder = nextOrder(),
		Parent = scroll,
	})
	Ui.text({
		Text = L.k("settings.sound_note"),
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = scroll,
	})

	Ui.text({
		Text = L.k("settings.chat"),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = scroll,
	})
	Ui.text({
		Text = L.k("settings.version", { v = Config.VERSION }),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -8, 0, 20),
		LayoutOrder = nextOrder(),
		Parent = scroll,
	})

	local function refreshStatus()
		local st, code = Music.status()
		statusLabel.Text = L.t("settings.music_" .. st)
			.. (if st == "error" and code then " (" .. code .. ")" else "")
	end
	ClientState.onCore(function(core)
		for choice, b in pairs(buttons) do
			b.BackgroundColor3 = if (core.Lang or "auto") == choice then Theme.Green else Theme.BgLight
		end
		current = AudioData.normalize(core.Audio)
		musicBtn.Text = L.t(if current.Music then "settings.music_on" else "settings.music_off")
		musicBtn.BackgroundColor3 = if current.Music then Theme.Green else Theme.BgLight
		sfxBtn.Text = L.t(if current.Sfx then "settings.sfx_on" else "settings.sfx_off")
		sfxBtn.BackgroundColor3 = if current.Sfx then Theme.Green else Theme.BgLight
		volLabel.Text = L.t("settings.volume", { n = math.floor(current.MusicVol * 100 + 0.5) })
		refreshStatus()
	end)
	gui:GetAttributeChangedSignal("MusicStatus"):Connect(refreshStatus)
	return panel
end

return SettingsPanel
