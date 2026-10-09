--!nonstrict
--[[
	TricksPanel — список трюков (уровень открытия, лучшая медаль) и ритм-мини-игра.
	Мини-игра: лапки летят к кругу; нажми (пробел/F/клик/кнопка) в момент, когда лапка в круге.
	Сервер выдаёт seed (TrickStart) -> одинаковый ритм на клиенте и сервере (TrickData.pattern);
	клиент отправляет только отклонения нажатий, оценку и медаль считает сервер (TrickFinish).
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local TrickData = require(Shared:WaitForChild("TrickData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local TricksPanel = {}

local SPEED = 300 -- px/с полёта лапки
local TARGET_X = 80

function TricksPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Tricks", nil, { MinH = 460 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)
	Ui.list(scroll, 6)

	------------------------------------------------------------------ мини-игра
	local layer, _getK = Ui.root(gui, "TrickGame", 30)
	layer.Visible = false
	local box = Ui.card({
		Name = "Box",
		Size = UDim2.fromOffset(600, 230),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		BackgroundTransparency = 0.05,
		ZIndex = 30,
		Parent = layer,
	})
	local gTitle = Ui.text({
		Name = "Title",
		Font = Theme.Font,
		TextSize = 24,
		TextColor3 = Theme.Gold,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(14, 8),
		ZIndex = 31,
		Parent = box,
	})
	local hint = Ui.text({
		Name = "Hint",
		Text = L.k("trick.hint"),
		TextSize = 17,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(14, 38),
		ZIndex = 31,
		Parent = box,
	})
	local lane = New("Frame", {
		Name = "Lane",
		BackgroundColor3 = Color3.fromRGB(30, 22, 36),
		Size = UDim2.new(1, -150, 0, 90),
		Position = UDim2.fromOffset(14, 70),
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = box,
	})
	Widgets.corner(lane, 14)
	local target = New("Frame", {
		Name = "Target",
		BackgroundColor3 = Theme.Gold,
		BackgroundTransparency = 0.6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.new(0, TARGET_X, 0.5, 0),
		ZIndex = 32,
		Parent = lane,
	})
	Widgets.corner(target, 36)
	Widgets.stroke(target, Theme.Gold, 3)
	local judge = Ui.text({
		Name = "Judge",
		Font = Theme.Font,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -150, 0, 34),
		Position = UDim2.fromOffset(14, 166),
		ZIndex = 33,
		Parent = box,
	})
	local tap = Widgets.button({
		Name = "Tap",
		Text = L.k("trick.tap"),
		Color = Theme.Pink,
		MaxTextSize = 26,
		Size = UDim2.fromOffset(116, 116),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 62),
		ZIndex = 33,
		Parent = box,
	})
	local result = Ui.card({
		Name = "Result",
		Size = UDim2.fromOffset(600, 230),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 34,
		Parent = layer,
	})
	local medalHolder = New("Frame", {
		Name = "Medal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromOffset(20, 30),
		ZIndex = 35,
		Parent = result,
	})
	local rTitle = Ui.text({
		Name = "Title",
		Font = Theme.Font,
		TextSize = 28,
		Size = UDim2.new(1, -160, 0, 36),
		Position = UDim2.fromOffset(148, 30),
		ZIndex = 35,
		Parent = result,
	})
	local rScore = Ui.text({
		Name = "Score",
		TextSize = 20,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -160, 0, 28),
		Position = UDim2.fromOffset(148, 72),
		ZIndex = 35,
		Parent = result,
	})
	local again = Widgets.button({
		Name = "Again",
		Text = L.k("btn.again"),
		Color = Theme.Green,
		MaxTextSize = 20,
		Size = UDim2.fromOffset(160, 44),
		Position = UDim2.fromOffset(148, 160),
		ZIndex = 35,
		Parent = result,
	})
	local closeR = Widgets.button({
		Name = "CloseResult",
		Text = L.k("btn.close"),
		Color = Theme.BgLight,
		MaxTextSize = 20,
		Size = UDim2.fromOffset(160, 44),
		Position = UDim2.fromOffset(320, 160),
		ZIndex = 35,
		Parent = result,
	})

	local running = nil :: any
	local lastId = nil
	local hbConn: RBXScriptConnection? = nil
	local JUDGE_COLORS = { perfect = Theme.Gold, good = Theme.Green, ok = Theme.Blue, miss = Theme.Red }

	local function stopLoop()
		if hbConn then
			hbConn:Disconnect()
			hbConn = nil
		end
	end

	local function finish()
		local run = running
		if not run then
			return
		end
		running = nil
		stopLoop()
		local errors = {}
		for i = 1, #run.Times do
			errors[i] = if run.Errors[i] ~= nil then run.Errors[i] else false
		end
		local ok, data = Actions.request("TrickFinish", run.Id, errors)
		box.Visible = false
		if ok and type(data) == "table" then
			Widgets.clear(medalHolder)
			local medal = data.Medal or 0
			if medal > 0 then
				Ui.icon(Ui.MEDAL_ICON[medal], 110, { ZIndex = 36, Parent = medalHolder })
			else
				Ui.icon("Paw", 110, { ZIndex = 36, Parent = medalHolder })
			end
			rTitle.Text = L.t("trick.medal." .. medal)
			rTitle.TextColor3 = Ui.MEDAL_COLORS[medal]
			rScore.Text = L.t("trick.score", { n = math.floor((data.Score or 0) * 100 + 0.5) })
			result.Visible = true
		else
			layer.Visible = false
		end
	end

	local function press()
		local run = running
		if not run then
			return
		end
		local now = os.clock() - run.Start
		local best, bestErr = nil, 1e9
		for i, t in ipairs(run.Times) do
			if run.Errors[i] == nil and math.abs(now - t) < math.abs(bestErr) then
				best, bestErr = i, now - t
			end
		end
		-- нажатие далеко от лапки не тратит её (без штрафа), промах — только в пределах окна
		if not best or math.abs(bestErr) > TrickData.WINDOW_OK * run.Mult + 0.08 then
			return
		end
		run.Errors[best] = bestErr
		local j = TrickData.judge(bestErr, run.Mult)
		if j == "miss" then
			run.Errors[best] = false
		end
		judge.Text = L.t("trick.judge." .. j)
		judge.TextColor3 = JUDGE_COLORS[j]
		local note = run.Notes[best]
		if note then
			note:Destroy()
			run.Notes[best] = nil
		end
		Widgets.tween(target, 0.05, { BackgroundTransparency = 0.2 }).Completed:Once(function()
			Widgets.tween(target, 0.15, { BackgroundTransparency = 0.6 })
		end)
	end

	local function start(id: string)
		if running then
			return
		end
		local t = TrickData.ById[id]
		local ok, data = Actions.request("TrickStart", id)
		if not ok or type(data) ~= "table" then
			return
		end
		panel.Close()
		lastId = id
		layer.Visible = true
		box.Visible = true
		result.Visible = false
		gTitle.Text = L.n(t.Name)
		judge.Text = ""
		for _, c in ipairs(lane:GetChildren()) do
			if c.Name == "Note" then
				c:Destroy()
			end
		end
		local times = TrickData.pattern(id, data.Seed)
		local notes = {}
		for i in ipairs(times) do
			local n = New("Frame", {
				Name = "Note",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(56, 56),
				Position = UDim2.new(0, 2000, 0.5, 0),
				ZIndex = 34,
				Parent = lane,
			})
			Ui.icon("Paw", 56, { ZIndex = 35, Parent = n })
			notes[i] = n
		end
		running =
			{ Id = id, Times = times, Errors = {}, Notes = notes, Start = os.clock(), Mult = data.Mult or 1 }
		stopLoop()
		hbConn = RunService.Heartbeat:Connect(function()
			local run = running
			if not run then
				return
			end
			local now = os.clock() - run.Start
			for i, tm in ipairs(run.Times) do
				local n = run.Notes[i]
				if n then
					n.Position = UDim2.new(0, TARGET_X + (tm - now) * SPEED, 0.5, 0)
					if now - tm > TrickData.WINDOW_OK * run.Mult + 0.05 and run.Errors[i] == nil then
						run.Errors[i] = false
						n:Destroy()
						run.Notes[i] = nil
						judge.Text = L.t("trick.judge.miss")
						judge.TextColor3 = JUDGE_COLORS.miss
					end
				end
			end
			if now > run.Times[#run.Times] + 0.6 then
				task.spawn(finish)
			end
		end)
	end

	tap.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not running or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.F then
			press()
		end
	end)
	again.Activated:Connect(function()
		result.Visible = false
		if lastId then
			start(lastId)
		end
	end)
	closeR.Activated:Connect(function()
		layer.Visible = false
	end)
	_ = hint

	------------------------------------------------------------------ список
	local rows = {}
	for i, t in ipairs(TrickData.List) do
		local card = Ui.card({
			Name = t.Id,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, -4, 0, 70),
			LayoutOrder = i,
			Parent = scroll,
		})
		Ui.icon("Trick", 50, { Position = UDim2.fromOffset(10, 10), Parent = card })
		Ui.text({
			Name = "Title",
			Text = L.kn(t.Name),
			Font = Theme.Font,
			TextSize = 20,
			Size = UDim2.new(1, -250, 0, 26),
			Position = UDim2.fromOffset(70, 8),
			Parent = card,
		})
		local info = Ui.text({
			Name = "Info",
			TextSize = 15,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, -250, 0, 22),
			Position = UDim2.fromOffset(70, 38),
			Parent = card,
		})
		local medal = New("Frame", {
			Name = "Medal",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(44, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -140, 0.5, 0),
			Parent = card,
		})
		local play = Widgets.button({
			Name = "Play",
			Text = L.k("btn.play"),
			Color = Theme.Green,
			MaxTextSize = 18,
			Size = UDim2.fromOffset(120, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = card,
			OnClick = function()
				start(t.Id)
			end,
		})
		rows[t.Id] = { Info = info, Medal = medal, Play = play, Best = -1 }
	end
	ClientState.onCore(function(core)
		for _, t in ipairs(TrickData.List) do
			local r = rows[t.Id]
			local rec = (core.Tricks or {})[t.Id]
			local best = if type(rec) == "table" then rec.Best or 0 else 0
			local unlocked = (core.Level or 1) >= t.Level
			Widgets.setEnabled(r.Play, unlocked, Theme.Green)
			r.Info.Text = if unlocked
				then L.t("trick.info", { beats = t.Beats, xp = t.Xp })
				else L.t("msg.trick_level", { n = t.Level })
			local key = best * 10 + (if unlocked then 1 else 0)
			if r.Best ~= key then
				r.Best = key
				Widgets.clear(r.Medal)
				Ui.icon(
					if best > 0 then Ui.MEDAL_ICON[best] else if unlocked then "Paw" else "Lock",
					44,
					{ Parent = r.Medal }
				)
			end
		end
	end)
	TricksPanel.start = start
	return panel
end

return TricksPanel
