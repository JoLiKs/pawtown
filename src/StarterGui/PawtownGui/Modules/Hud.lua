--!nonstrict
--[[
	Hud — компактный HUD: карточка питомца (вид, уровень, опыт, лакомства, осколки), полосы потребностей
	со значками и настроением, трекер задания, кнопки разделов и кнопки способностей вида.
	Раскладки: ПК 1280×720 (wide), телефон вертикально 390×844 (portrait) и горизонтально 844×390 (landscape).
	Размеры — в дизайнерских px (Ui.root), видимый размер = px × Theme.uiScale (кнопки >= 36 px, текст >= 12 px).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Icons = require(Shared:WaitForChild("Icons"))
local NeedsLogic = require(Shared:WaitForChild("NeedsLogic"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local Hud = {}

local NEEDS = { "Hunger", "Energy", "Hygiene", "Fun", "Love" }
local MOOD_COLOR = {
	Happy = Color3.fromRGB(120, 230, 130),
	Normal = Color3.fromRGB(230, 230, 240),
	Sad = Color3.fromRGB(150, 170, 255),
	Mischievous = Color3.fromRGB(255, 170, 90),
}

function Hud.init(gui: ScreenGui, openPanel: (string) -> ())
	local root, getK = Ui.root(gui, "Hud", 2)

	------------------------------------------------------------------ карточка питомца
	local status = Ui.card({ Name = "Status", Size = UDim2.fromOffset(290, 82), Position = UDim2.fromOffset(10, 10), Parent = root })
	local headHolder = New("Frame", {
		Name = "Head",
		BackgroundColor3 = Theme.BgLight,
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.fromOffset(10, 10),
		Parent = status,
	})
	Widgets.corner(headHolder, 31)
	local lvl = Ui.text({
		Name = "Level",
		Font = Theme.Font,
		TextSize = 20,
		Size = UDim2.fromOffset(200, 22),
		Position = UDim2.fromOffset(82, 8),
		Parent = status,
	})
	local _, setXp = Ui.bar(status, UDim2.fromOffset(82, 33), UDim2.fromOffset(196, 10), Color3.fromRGB(150, 120, 255), "XpBar")
	Ui.icon("Treat", 24, { Position = UDim2.fromOffset(82, 50), Parent = status })
	local treats = Ui.text({ Name = "Treats", Font = Theme.Font, TextSize = 20, Size = UDim2.fromOffset(90, 24), Position = UDim2.fromOffset(110, 50), Parent = status })
	Ui.icon("Shard", 24, { Position = UDim2.fromOffset(200, 50), Parent = status })
	local shards = Ui.text({ Name = "Shards", Font = Theme.Font, TextSize = 20, Size = UDim2.fromOffset(60, 24), Position = UDim2.fromOffset(228, 50), Parent = status })

	------------------------------------------------------------------ потребности
	local needs = Ui.card({ Name = "Needs", Size = UDim2.fromOffset(230, 186), Position = UDim2.fromOffset(10, 100), Parent = root })
	local needRows = {}
	for i, key in ipairs(NEEDS) do
		local row = New("Frame", { Name = key, BackgroundTransparency = 1, Size = UDim2.fromOffset(210, 28), Parent = needs })
		Ui.icon(key, 26, { Position = UDim2.fromOffset(0, 1), Parent = row })
		local back, set = Ui.bar(row, UDim2.fromOffset(34, 8), UDim2.fromOffset(170, 13), Ui.NEED_COLORS[key])
		needRows[key] = { Row = row, Set = set, Back = back, Order = i }
	end
	local mood = Ui.text({ Name = "Mood", Font = Theme.Font, TextSize = 18, Size = UDim2.fromOffset(210, 22), Parent = needs })

	------------------------------------------------------------------ трекер задания
	local tracker = New("TextButton", {
		Name = "Tracker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromOffset(300, 92),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Parent = root,
	})
	Widgets.corner(tracker, 12)
	Widgets.stroke(tracker, Color3.new(0, 0, 0), 2).Transparency = 0.55
	Ui.icon("Quest", 26, { Position = UDim2.fromOffset(10, 8), Parent = tracker })
	local tTitle = Ui.text({ Name = "Title", Font = Theme.Font, TextSize = 18, TextColor3 = Theme.Gold, Size = UDim2.new(1, -50, 0, 24), Position = UDim2.fromOffset(42, 8), Parent = tracker })
	local tStep = Ui.text({ Name = "Step", TextSize = 18, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 34), TextYAlignment = Enum.TextYAlignment.Top, Parent = tracker })
	local tDaily = Ui.text({ Name = "Daily", TextSize = 16, TextColor3 = Theme.TextDim, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 1, -22), Parent = tracker })
	tracker.Activated:Connect(function()
		openPanel("Quests")
	end)

	------------------------------------------------------------------ кнопки разделов
	local menu = New("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(58, 58 * 5 + 32), Parent = root })
	local menuList = Ui.list(menu, 8)
	local buttons = {}
	for i, def in ipairs({
		{ "Quests", "Quest", Theme.Blue },
		{ "Talents", "Talent", Theme.Purple },
		{ "Shop", "Shop", Theme.Pink },
		{ "Emotes", "Emote", Theme.Orange },
		{ "Settings", "Settings", Theme.BgLight },
	}) do
		buttons[def[1]] = Ui.iconButton({
			Name = def[1] .. "Button",
			IconKind = def[2],
			Color = def[3],
			LayoutOrder = i,
			Parent = menu,
			OnClick = function()
				openPanel(def[1])
			end,
		})
	end
	local talentDot = Widgets.dot(buttons.Talents)

	------------------------------------------------------------------ способности
	local abilities = New("Frame", { Name = "Abilities", BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 70), Parent = root })
	Ui.list(abilities, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local abilityButtons = {}
	local function abilityButton(id: string, icon: string, color: Color3)
		local b = Ui.iconButton({
			Name = id .. "Button",
			IconKind = icon,
			Color = color,
			Size = 66,
			Parent = abilities,
			OnClick = function()
				Actions.call("Ability", id)
			end,
		})
		local key = Ui.text({
			Name = "Key",
			Text = "Q", -- l10n-ok (клавиша)
			Font = Theme.Font,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Theme.Bg,
			Size = UDim2.fromOffset(22, 20),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 2, 1, 2),
			ZIndex = 7,
			Parent = b,
		})
		Widgets.corner(key, 6)
		b.Visible = false
		abilityButtons[id] = { Button = b, Key = key }
	end
	abilityButton("Sniff", "Sniff", Color3.fromRGB(150, 110, 70))
	abilityButton("Dash", "Dash", Color3.fromRGB(90, 190, 140))

	------------------------------------------------------------------ сон
	local sleepVeil = New("Frame", {
		Name = "SleepVeil",
		BackgroundColor3 = Color3.fromRGB(10, 10, 30),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	New("TextLabel", {
		Name = "Zzz",
		BackgroundTransparency = 1,
		Text = "Z z z", -- l10n-ok (звукоподражание)
		Font = Theme.Font,
		TextColor3 = Color3.fromRGB(200, 210, 255),
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(200, 60),
		Parent = sleepVeil,
	})

	------------------------------------------------------------------ раскладка
	local function layoutNeeds(row: boolean)
		if row then
			-- в ряд: значок над короткой полосой (телефон вертикально)
			needs.Size = UDim2.fromOffset(467, 58)
			for _, r in pairs(needRows) do
				r.Row.Size = UDim2.fromOffset(80, 50)
				r.Row.Position = UDim2.fromOffset(8 + (r.Order - 1) * 78, 4)
				local ic = r.Row:FindFirstChild("Icon")
				ic.Position = UDim2.fromOffset(24, 0)
				r.Back.Position = UDim2.fromOffset(4, 32)
				r.Back.Size = UDim2.fromOffset(66, 11)
			end
			mood.Size = UDim2.fromOffset(70, 50)
			mood.Position = UDim2.fromOffset(400, 4)
			mood.TextXAlignment = Enum.TextXAlignment.Center
		else
			needs.Size = UDim2.fromOffset(230, 186)
			for _, r in pairs(needRows) do
				r.Row.Size = UDim2.fromOffset(210, 28)
				r.Row.Position = UDim2.fromOffset(10, 8 + (r.Order - 1) * 30)
				local ic = r.Row:FindFirstChild("Icon")
				ic.Position = UDim2.fromOffset(0, 1)
				r.Back.Position = UDim2.fromOffset(34, 8)
				r.Back.Size = UDim2.fromOffset(170, 13)
			end
			mood.Size = UDim2.fromOffset(210, 22)
			mood.Position = UDim2.fromOffset(10, 158)
			mood.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	local function relayout(lay)
		local k = getK()
		local W, H = lay.W / k, lay.H / k
		local touch = lay.Mode ~= "wide"
		for _, a in pairs(abilityButtons) do
			a.Key.Visible = not lay.Touch
		end
		if lay.Mode == "portrait" then
			layoutNeeds(true)
			tracker.AnchorPoint = Vector2.new(0, 0)
			tracker.Position = UDim2.fromOffset(10, 100)
			tracker.Size = UDim2.fromOffset(W - 20, 92)
			needs.Position = UDim2.fromOffset(10, 200)
			needs.Size = UDim2.fromOffset(W - 20, 58)
			menu.AnchorPoint = Vector2.new(1, 0.5)
			menu.Position = UDim2.new(1, -8, 0.56, 0)
			menuList.FillDirection = Enum.FillDirection.Vertical
			menu.Size = UDim2.fromOffset(58, 58 * 5 + 32)
			abilities.AnchorPoint = Vector2.new(1, 1)
			abilities.Position = UDim2.new(1, -8, 1, -190)
			abilities.Size = UDim2.fromOffset(70, 70)
		elseif lay.Mode == "landscape" then
			layoutNeeds(false)
			tracker.AnchorPoint = Vector2.new(1, 0)
			tracker.Position = UDim2.new(1, -10, 0, 10)
			tracker.Size = UDim2.fromOffset(300, 92)
			needs.Position = UDim2.fromOffset(10, 100)
			menu.AnchorPoint = Vector2.new(0.5, 1)
			menu.Position = UDim2.new(0.5, 0, 1, -8)
			menuList.FillDirection = Enum.FillDirection.Horizontal
			menu.Size = UDim2.fromOffset(58 * 5 + 32, 58)
			abilities.AnchorPoint = Vector2.new(1, 1)
			abilities.Position = UDim2.new(1, -16, 1, -170)
			abilities.Size = UDim2.fromOffset(70, 70)
		else
			layoutNeeds(false)
			tracker.AnchorPoint = Vector2.new(1, 0)
			tracker.Position = UDim2.new(1, -10, 0, 10)
			tracker.Size = UDim2.fromOffset(300, 92)
			needs.Position = UDim2.fromOffset(10, 100)
			menu.AnchorPoint = Vector2.new(1, 0.5)
			menu.Position = UDim2.new(1, -10, 0.55, 0)
			menuList.FillDirection = Enum.FillDirection.Vertical
			menu.Size = UDim2.fromOffset(58, 58 * 5 + 32)
			abilities.AnchorPoint = Vector2.new(0.5, 1)
			abilities.Position = UDim2.new(0.5, 0, 1, -14)
			abilities.Size = UDim2.fromOffset(150, 70)
		end
		-- безопасная область окон на телефоне (видимые px)
		if touch then
			local area
			if lay.Mode == "portrait" then
				local top = (if needs.Visible then 262 else 200) * k
				area = { X = 8, Y = top, W = lay.W - 16 - 66 * k, H = lay.H - top - 150 }
			else
				local left = 248 * k
				area = { X = left, Y = 8, W = lay.W - left - 8, H = lay.H - 8 - 74 * k }
			end
			Layout.setPanelArea(area)
		else
			Layout.setPanelArea(nil)
		end
		_ = H
	end
	Layout.onChanged(relayout)

	------------------------------------------------------------------ данные
	local lastSpecies = nil
	ClientState.onCore(function(core)
		local sp = SpeciesData.ById[core.Species]
		local chosen = sp ~= nil
		if core.Species ~= lastSpecies then
			lastSpecies = core.Species
			Widgets.clear(headHolder)
			Icons.make(if chosen then core.Species else "Paw", {
				Name = "Icon",
				Px = 54,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.86, 0.86),
				Parent = headHolder,
			})
		end
		lvl.Text = L.t("hud.level", { n = core.Level, age = "age." .. tostring(core.Age) })
		setXp(if core.XpNeed and core.XpNeed > 0 then core.Xp / core.XpNeed else 0)
		treats.Text = tostring(core.Treats)
		shards.Text = string.format("%d/%d", #(core.Shards or {}), #WorldData.Shards)
		for key, r in pairs(needRows) do
			r.Set(((core.Needs or {})[key] or 0) / 100)
		end
		mood.Text = L.t("mood." .. tostring(core.Mood))
		mood.TextColor3 = MOOD_COLOR[core.Mood] or Theme.Text
		needs.Visible = chosen
		-- трекер
		local story = core.Story or {}
		if story.Id and story.Id ~= "" then
			tTitle.Text = L.t("hud.chapter", { i = story.Index, total = story.Total })
			local stepText = L.t("quest." .. story.Id)
			if (story.Need or 0) > 1 then
				stepText ..= string.format(" (%d/%d)", story.P or 0, story.Need)
			end
			tStep.Text = stepText
		else
			tTitle.Text = L.t("hud.chapter_done")
			tStep.Text = L.t("hud.free_play")
		end
		local done, total = 0, 0
		for _, d in ipairs(core.Daily or {}) do
			total += 1
			if d.Done then
				done += 1
			end
		end
		tDaily.Text = L.t("hud.daily", { n = done, total = total })
		tDaily.Visible = chosen
		menu.Visible = chosen
		talentDot.Visible = (core.TalentFree or 0) > 0
		abilityButtons.Sniff.Button.Visible = SpeciesData.has(core.Species, "Sniff")
		abilityButtons.Dash.Button.Visible = SpeciesData.has(core.Species, "Dash")
		sleepVeil.Visible = core.Sleeping == true
		relayout(Layout.get())
	end)
	_ = NeedsLogic
	Hud.root = root
end

return Hud
