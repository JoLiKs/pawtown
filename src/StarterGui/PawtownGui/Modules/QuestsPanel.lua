--!nonstrict
--[[
	QuestsPanel — «Дневник»: шаги текущей главы (1 «Новый дом», 2 «Соседи»), ежедневные задания, привязанность семьи
	(со следующим подарком), репутация районов, осколки памяти и друзья.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FamilyData = require(Shared:WaitForChild("FamilyData"))
local L = require(Shared:WaitForChild("Locale"))
local Progression = require(Shared:WaitForChild("Progression"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local QuestsPanel = {}

function QuestsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Quests", nil, { MinH = 500 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)
	Ui.list(scroll, 6)

	local function header(key: string, order: number)
		Ui.text({
			Name = "H_" .. key,
			Text = L.k(key),
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Theme.Gold,
			Size = UDim2.new(1, -4, 0, 26),
			LayoutOrder = order,
			Parent = scroll,
		})
	end
	local function row(name: string, order: number, h: number?): Frame
		return Ui.card({
			Name = name,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, -4, 0, h or 44),
			LayoutOrder = order,
			Parent = scroll,
		})
	end

	-- главы: показываем текущую (пройденная глава 1 сворачивается в заголовок)
	local steps = {}
	local chapterHeaders = {}
	for c, list in ipairs(QuestData.CHAPTERS) do
		local base = (c - 1) * 9
		header("quests.chapter" .. c, base + 1)
		chapterHeaders[c] = scroll:FindFirstChild("H_quests.chapter" .. c)
		for i, st in ipairs(list) do
			local r = row(st.Id, base + 1 + i)
			local ic = New("Frame", {
				Name = "IconHolder",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(30, 30),
				Position = UDim2.fromOffset(8, 7),
				Parent = r,
			})
			local t = Ui.text({
				Name = "Text",
				Text = L.k("quest." .. st.Id),
				TextSize = 16,
				Size = UDim2.new(1, -110, 1, -4),
				Position = UDim2.fromOffset(46, 2),
				Parent = r,
			})
			local p = Ui.text({
				Name = "P",
				Font = Theme.Font,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromOffset(60, 40),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 2),
				Parent = r,
			})
			table.insert(steps, { Row = r, Icon = ic, Text = t, P = p, State = "", C = c, I = i, St = st })
		end
	end
	-- ежедневные
	header("quests.daily", 20)
	local dailyHolder = New("Frame", {
		Name = "Daily",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 5 * 50),
		LayoutOrder = 21,
		Parent = scroll,
	})
	Ui.list(dailyHolder, 6)
	-- семья
	header("quests.family", 30)
	local bonds = {}
	for i, m in ipairs(FamilyData.List) do
		local r = row("Bond" .. m.Id, 30 + i, 58)
		Ui.icon("Love", 28, { Position = UDim2.fromOffset(8, 8), Parent = r })
		Ui.text({
			Text = L.k("npc." .. m.Id),
			Font = Theme.Font,
			TextSize = 17,
			Size = UDim2.fromOffset(150, 22),
			Position = UDim2.fromOffset(44, 4),
			Parent = r,
		})
		local _, set = Ui.bar(r, UDim2.fromOffset(44, 30), UDim2.new(1, -160, 0, 12), Ui.NEED_COLORS.Love)
		local v = Ui.text({
			TextSize = 15,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(104, 40),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Parent = r,
		})
		bonds[m.Id] = { Set = set, V = v, M = m }
	end
	-- мир
	header("quests.world", 40)
	local world = row("World", 41, 92)
	-- награды репутации Кленовой улицы
	local rewards = row("RepRewards", 42, 8 + 24 * #QuestData.REP_REWARDS)
	local rewardRows = {}
	for i, r in ipairs(QuestData.REP_REWARDS) do
		Ui.icon(
			if r.Kind == "Shortcut" then "Home" elseif r.Kind == "Discount" then "Treat" else "Shop",
			20,
			{
				Position = UDim2.fromOffset(10, 6 + (i - 1) * 24),
				Parent = rewards,
			}
		)
		rewardRows[i] = Ui.text({
			Name = "Reward" .. r.Kind,
			TextSize = 15,
			Size = UDim2.new(1, -50, 0, 22),
			Position = UDim2.fromOffset(42, 4 + (i - 1) * 24),
			Parent = rewards,
		})
	end
	Ui.icon("Shard", 26, { Position = UDim2.fromOffset(8, 6), Parent = world })
	local shardsT = Ui.text({
		TextSize = 16,
		Size = UDim2.new(1, -50, 0, 24),
		Position = UDim2.fromOffset(42, 6),
		Parent = world,
	})
	Ui.icon("Home", 26, { Position = UDim2.fromOffset(8, 34), Parent = world })
	local repT = Ui.text({
		TextSize = 16,
		Size = UDim2.new(1, -50, 0, 24),
		Position = UDim2.fromOffset(42, 34),
		Parent = world,
	})
	Ui.icon("Friends", 26, { Position = UDim2.fromOffset(8, 62), Parent = world })
	local friendsT = Ui.text({
		TextSize = 16,
		Size = UDim2.new(1, -50, 0, 24),
		Position = UDim2.fromOffset(42, 62),
		Parent = world,
	})

	ClientState.onCore(function(core)
		local story = core.Story or {}
		local idx = story.Index or 1
		local cur = story.Chapter or 1
		for c, h in pairs(chapterHeaders) do
			h.Visible = c <= cur
		end
		for _, s in ipairs(steps) do
			local st, i = s.St, s.I
			s.Row.Visible = s.C == cur
			local state = if s.C < cur or (s.C == cur and i < idx)
				then "done"
				elseif s.C == cur and i == idx then "cur"
				else "todo"
			if s.State ~= state then
				s.State = state
				Widgets.clear(s.Icon)
				Ui.icon(
					if state == "done" then "Check" elseif state == "cur" then "Quest" else "Lock",
					30,
					{ Parent = s.Icon }
				)
				s.Text.TextColor3 = if state == "todo" then Theme.TextDim else Theme.Text
				s.Row.BackgroundColor3 = if state == "cur" then Color3.fromRGB(110, 80, 60) else Theme.BgCard
			end
			s.P.Text = if state == "cur" and st.Need > 1
				then string.format("%d/%d", story.P or 0, st.Need)
				else ""
		end
		Widgets.clear(dailyHolder)
		local list = core.Daily or {}
		for i, d in ipairs(list) do
			local r = Ui.card({
				Name = d.Id,
				BackgroundColor3 = if d.Done then Color3.fromRGB(60, 110, 70) else Theme.BgCard,
				BackgroundTransparency = 0,
				Size = UDim2.new(1, 0, 0, 44),
				LayoutOrder = i,
				Parent = dailyHolder,
			})
			Ui.icon(
				if d.Done then "Check" else "Quest",
				28,
				{ Position = UDim2.fromOffset(8, 8), Parent = r }
			)
			Ui.text({
				Text = L.t("daily." .. d.Id),
				TextSize = 16,
				Size = UDim2.new(1, -150, 1, -4),
				Position = UDim2.fromOffset(44, 2),
				Parent = r,
			})
			Ui.text({
				Text = if d.Done
					then L.t("quests.done")
					else string.format("%d/%d  +%d", d.P or 0, d.Need or 1, d.Treats or 0),
				Font = Theme.Font,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromOffset(100, 40),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 2),
				Parent = r,
			})
		end
		dailyHolder.Size = UDim2.new(1, -4, 0, math.max(1, #list) * 50)
		for id, b in pairs(bonds) do
			local v = (core.Bond or {})[id] or 0
			b.Set(v / 100)
			local nextGift = nil
			for _, g in ipairs(b.M.Gifts) do
				if v < g.At then
					nextGift = g.At
					break
				end
			end
			b.V.Text = if nextGift
				then L.t("quests.bond_next", { n = math.floor(v), at = nextGift })
				else tostring(math.floor(v))
		end
		shardsT.Text = L.t("quests.shards", { n = #(core.Shards or {}), total = #WorldData.Shards })
		local rep = core.Rep or {}
		local street = Progression.repLevel(rep.Street or 0)
		repT.Text = L.t("quests.rep", {
			street = street,
			park = Progression.repLevel(rep.Park or 0),
		})
		for i, r in ipairs(QuestData.REP_REWARDS) do
			local t = rewardRows[i]
			if t then
				t.Text = L.t("quests.rep_reward." .. r.Kind, { n = r.Level, pct = r.Pct or 0 })
				t.TextColor3 = if street >= r.Level then Theme.Green else Theme.TextDim
			end
		end
		friendsT.Text = L.t("quests.friends", { n = core.FriendsCount or 0 })
	end)
	return panel
end

return QuestsPanel
