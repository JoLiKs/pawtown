--!nonstrict
--[[
	TalentsPanel — таланты по ветках Нюх / Ловкость / Обаяние (по 2 таланта, до 3 рангов; второй талант ветки
	открывается после первого). Очко таланта — за каждый уровень. Кнопка «Ночь Искр» открывает RebirthPanel.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Progression = require(Shared:WaitForChild("Progression"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local TalentsPanel = {}

local BRANCHES = {
	{ "Nose", "Sniff", Color3.fromRGB(170, 120, 80) },
	{ "Agility", "Dash", Color3.fromRGB(80, 170, 120) },
	{ "Charm", "Love", Color3.fromRGB(220, 100, 150) },
}

function TalentsPanel.init(gui: ScreenGui, openRebirth: () -> ())
	local panel = Widgets.panel(gui, "Talents", nil, { MinH = 500 })
	local top = New("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 4),
		Parent = panel.Body,
	})
	Ui.icon("Talent", 32, { Position = UDim2.fromOffset(0, 6), Parent = top })
	local points = Ui.text({
		Name = "Points",
		Font = Theme.Font,
		TextSize = 20,
		Size = UDim2.new(1, -230, 1, 0),
		Position = UDim2.fromOffset(40, 0),
		Parent = top,
	})
	Widgets.button({
		Name = "SparkNight",
		Text = L.k("btn.spark_night"),
		Color = Theme.Purple,
		MaxTextSize = 17,
		Size = UDim2.fromOffset(180, 40),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Parent = top,
		OnClick = openRebirth,
	})
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -56), Position = UDim2.fromOffset(4, 52) })
	Widgets.padding(scroll, 6)
	Ui.list(scroll, 6)
	local rows = {}
	local order = 0
	for _, br in ipairs(BRANCHES) do
		order += 1
		local h = New("Frame", {
			Name = "Branch" .. br[1],
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 30),
			LayoutOrder = order,
			Parent = scroll,
		})
		Ui.icon(br[2], 26, { Position = UDim2.fromOffset(2, 2), Parent = h })
		Ui.text({
			Text = L.k("branch." .. br[1]),
			Font = Theme.Font,
			TextSize = 19,
			TextColor3 = br[3],
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(36, 0),
			Parent = h,
		})
		local list = {}
		for _, t in pairs(Progression.Talents) do
			if t.Branch == br[1] then
				table.insert(list, t)
			end
		end
		table.sort(list, function(a, b)
			return a.Order < b.Order
		end)
		for _, t in ipairs(list) do
			order += 1
			local card = Ui.card({
				Name = t.Id,
				BackgroundColor3 = Theme.BgCard,
				BackgroundTransparency = 0,
				Size = UDim2.new(1, -4, 0, 64),
				LayoutOrder = order,
				Parent = scroll,
			})
			Ui.text({
				Text = L.kn(t.Name),
				Font = Theme.Font,
				TextSize = 18,
				Size = UDim2.new(1, -230, 0, 24),
				Position = UDim2.fromOffset(10, 6),
				Parent = card,
			})
			Ui.text({
				Text = L.kn(t.Desc),
				TextSize = 15,
				TextColor3 = Theme.TextDim,
				Size = UDim2.new(1, -230, 0, 30),
				Position = UDim2.fromOffset(10, 30),
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
			local pips = {}
			for i = 1, t.Max do
				local p = New("Frame", {
					BackgroundColor3 = Theme.Disabled,
					Size = UDim2.fromOffset(16, 16),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -110 - (t.Max - i) * 20, 0.5, 0),
					Parent = card,
				})
				Widgets.corner(p, 8)
				pips[i] = p
			end
			local learn = Widgets.button({
				Name = "Learn",
				Text = L.k("btn.learn"),
				Color = Theme.Green,
				MaxTextSize = 17,
				Size = UDim2.fromOffset(92, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Parent = card,
				OnClick = function()
					Actions.call("Talent", t.Id)
				end,
			})
			rows[t.Id] = { Pips = pips, Learn = learn, T = t, Color = br[3] }
		end
	end
	ClientState.onCore(function(core)
		points.Text = L.t("talents.points", { n = core.TalentFree or 0 })
		for id, r in pairs(rows) do
			local rank = Progression.rank(core.Talents or {}, id)
			for i, p in ipairs(r.Pips) do
				p.BackgroundColor3 = if i <= rank then r.Color else Theme.Disabled
			end
			local ok = Progression.canLearn(core.Level or 1, core.Talents or {}, id)
			Widgets.setEnabled(r.Learn, ok == true, Theme.Green)
		end
	end)
	return panel
end

return TalentsPanel
