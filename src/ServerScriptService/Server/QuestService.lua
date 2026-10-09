--!strict
--[[
	QuestService — глава 1 «Новый дом» (по шагам) и 5 ежедневных заданий (обновляются в полночь UTC).
	QuestService.event(player, kind, key?) — единая точка: сервисы сообщают о событиях (eat, trick, cuddle, shard…).
	Награды выдаются автоматически при выполнении (Progress.reward) — без лишних кликов.
	Также: газета (почтовый ящик) и «потерянная игрушка» (своя для каждого игрока).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local QuestData = require(Shared.QuestData)
local Remotes = require(Shared.Remotes)
local WorldData = require(Shared.WorldData)

local DataService = require(script.Parent.DataService)
local Interact = require(script.Parent.Interact)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local QuestService = {}

QuestService.onStepDone = nil :: ((Player, string) -> ())?

-- Текущий шаг главы (или nil, если глава пройдена)
function QuestService.currentStep(data: any): QuestData.Step?
	return QuestData.CHAPTER1[data.Story.Step]
end

function QuestService.stepId(player: Player): string?
	local data = DataService.get(player)
	local step = data and QuestService.currentStep(data)
	return step and step.Id
end

-- Ежедневные: сброс по дню, набор из QuestData.pickDaily
function QuestService.ensureDaily(player: Player, data: any)
	local day = QuestData.dayNumber(os.time())
	if data.Daily.Day ~= day then
		data.Daily = { Day = day, Items = {} }
		for _, id in ipairs(QuestData.pickDaily(day, player.UserId)) do
			data.Daily.Items[id] = { P = 0, Done = false }
		end
	end
end

function QuestService.dailyActive(player: Player, kind: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	QuestService.ensureDaily(player, data)
	for id, st in pairs(data.Daily.Items) do
		local d = QuestData.DAILY_BY_ID[id]
		if d and d.Kind == kind and not st.Done then
			return true
		end
	end
	return false
end

local function advanceStory(player: Player, data: any, kind: string, key: string?)
	local step = QuestService.currentStep(data)
	if not step or step.Kind ~= kind then
		return
	end
	if step.Distinct then
		local k = key or "?"
		if data.Story.Seen[k] then
			return
		end
		data.Story.Seen[k] = true
	end
	data.Story.P += 1
	if data.Story.P >= step.Need then
		data.Story.Step += 1
		data.Story.P = 0
		data.Story.Seen = {}
		Progress.reward(player, { Treats = step.Treats, Xp = step.Xp }, "quest." .. step.Id)
		Remotes.getEvent("Fx"):FireClient(player, "Quest", step.Id)
		local nextStep = QuestService.currentStep(data)
		if nextStep then
			Notify.send(player, Locale.m("toast.next_step", { step = "quest." .. nextStep.Id }), "info")
		else
			Notify.send(player, "toast.chapter_done", "reward")
		end
		if QuestService.onStepDone then
			task.spawn(QuestService.onStepDone, player, step.Id)
		end
		-- новый шаг мог быть уже выполнен (например, осколки собраны заранее)
		local ns = QuestService.currentStep(data)
		if ns and ns.Kind == "shard" then
			local n = 0
			for _ in pairs(data.Shards) do
				n += 1
			end
			data.Story.P = math.min(ns.Need - 1, n)
			if n >= ns.Need then
				advanceStory(player, data, "shard", nil)
			end
		end
	end
end

local function advanceDaily(player: Player, data: any, kind: string)
	QuestService.ensureDaily(player, data)
	for id, st in pairs(data.Daily.Items) do
		local d = QuestData.DAILY_BY_ID[id]
		if d and d.Kind == kind and not st.Done then
			st.P += 1
			if st.P >= d.Need then
				st.Done = true
				Progress.reward(player, { Treats = d.Treats, Xp = d.Xp }, "daily." .. d.Id)
				if d.Rep then
					Progress.rep(player, d.Rep, d.RepPts or 5)
				end
				Remotes.getEvent("Fx"):FireClient(player, "Daily", d.Id)
			end
		end
	end
end

function QuestService.event(player: Player, kind: string, key: string?)
	local data = DataService.get(player)
	if not data then
		return
	end
	advanceStory(player, data, kind, key)
	advanceDaily(player, data, kind)
	State.markCore(player)
end

-- ---------------------------------------------------------------------------------------------
-- Потерянная игрушка: одна на игрока в день, видна всем, поднять может только владелец
local toys: { [Player]: BasePart } = {}

function QuestService.spawnToy(player: Player)
	if toys[player] or not QuestService.dailyActive(player, "lost_toy") then
		return
	end
	local s = Session.get(player)
	if s and s.Carrying == "Toy" then
		return
	end
	local spots = WorldData.ToySpots
	local spot = spots[(QuestData.dayNumber(os.time()) + player.UserId) % #spots + 1]
	local dyn = WorldBuilder.folder("Dynamic")
	local toy = WorldBuilder.part(dyn, "LostToy_" .. player.UserId, Vector3.new(1.6, 1.6, 1.6), spot + Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 120, 200), {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Material = Enum.Material.SmoothPlastic,
	})
	toy:SetAttribute("Owner", player.UserId)
	toy:SetAttribute("LostToy", true)
	Interact.prompt(toy, "PickToy", "prompt.pick_toy", { Arg = tostring(player.UserId), Object = "obj.toy" })
	toys[player] = toy
end

local function removeToy(player: Player)
	local t = toys[player]
	toys[player] = nil
	if t then
		t:Destroy()
	end
end

-- Возвращает позицию игрушки игрока (для метки квеста на клиенте)
function QuestService.toyPos(player: Player): Vector3?
	local t = toys[player]
	return t and t.Position
end

function QuestService.init()
	Interact.register("Newspaper", function(player)
		local s = Session.get(player)
		if not s then
			return false, nil
		end
		if not QuestService.dailyActive(player, "newspaper") then
			return false, "msg.no_newspaper"
		end
		if s.Carrying then
			return false, "msg.mouth_full"
		end
		s.Carrying = "Newspaper"
		State.markCore(player)
		return true, "msg.got_newspaper"
	end)
	Interact.register("PickToy", function(player, _prompt, arg)
		local s = Session.get(player)
		if not s or arg ~= tostring(player.UserId) then
			return false, "msg.not_your_toy"
		end
		if s.Carrying then
			return false, "msg.mouth_full"
		end
		s.Carrying = "Toy"
		removeToy(player)
		State.markCore(player)
		return true, "msg.got_toy"
	end)
	State.providers.Story = function(_player, data)
		local step = QuestService.currentStep(data)
		return {
			Index = data.Story.Step,
			Total = #QuestData.CHAPTER1,
			Id = step and step.Id or "",
			P = data.Story.P,
			Need = step and step.Need or 0,
			Target = step and step.Target or "",
		}
	end
	State.providers.Daily = function(player, data)
		QuestService.ensureDaily(player, data)
		local out = {}
		for id, st in pairs(data.Daily.Items) do
			local d = QuestData.DAILY_BY_ID[id]
			if d then
				table.insert(out, { Id = id, Kind = d.Kind, P = st.P, Need = d.Need, Done = st.Done, Treats = d.Treats, Xp = d.Xp })
			end
		end
		table.sort(out, function(a, b)
			return a.Id < b.Id
		end)
		return out
	end
	State.providers.ToyPos = function(player)
		return QuestService.toyPos(player)
	end
	-- игрушки и сброс дня: раз в 5 секунд
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				local data = DataService.get(player)
				if s and s.Ready and data and data.Species ~= "" then
					local day = data.Daily.Day
					QuestService.ensureDaily(player, data)
					if day ~= data.Daily.Day then
						removeToy(player)
						State.markCore(player)
					end
					QuestService.spawnToy(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(removeToy)
end

return QuestService
