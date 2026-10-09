--!strict
--[[
	NeedsService — потребности питомца: мягкое убывание (NeedsLogic), еда/питьё, выпрашивание у стола, сон в
	лежанке (ночью — перемотка до утра, если спят все), купание (мини-игра с пеной: старт по подсказке, итог —
	действие BathDone; сервер проверяет время и ограничивает оценку).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local NeedsLogic = require(Shared.NeedsLogic)
local Remotes = require(Shared.Remotes)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local DayNightService = require(script.Parent.DayNightService)
local Interact = require(script.Parent.Interact)
local Movement = require(script.Parent.Movement)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local NeedsService = {}

-- Хуки конца сна (FamilyService: реплика бабушки; PlayerService: катсцена сна главы 1)
NeedsService.sleepEndHooks = {} :: { (Player) -> () }

function NeedsService.add(player: Player, key: string, amount: number): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local d = NeedsLogic.add(data.Needs, key, amount)
	State.markCore(player)
	return d
end

local function setSleeping(player: Player, on: boolean)
	local ch = player.Character
	if ch then
		ch:SetAttribute("Sleeping", on)
	end
end

local function allAsleep(): boolean
	local any = false
	for _, p in ipairs(Players:GetPlayers()) do
		local s = Session.get(p)
		local data = DataService.get(p)
		if s and s.Ready and data and data.Species ~= "" then
			any = true
			if s.SleepUntil <= os.clock() then
				return false
			end
		end
	end
	return any
end

function NeedsService.sleep(player: Player): (boolean, any)
	local s = Session.get(player)
	local data = DataService.get(player)
	if not s or not data then
		return false, nil
	end
	if s.SleepUntil > os.clock() then
		return false, nil
	end
	if data.Needs.Energy >= 95 and QuestService.stepId(player) ~= "c1_dream" then
		return false, "msg.not_sleepy"
	end
	s.SleepUntil = os.clock() + Config.SLEEP_SECONDS
	s.Carrying = nil
	setSleeping(player, true)
	Movement.apply(player)
	State.markCore(player)
	local night = DayNightService.isNight()
	task.delay(Config.SLEEP_SECONDS, function()
		if player.Parent == nil then
			return
		end
		-- ночью: если спят все — утро
		if night and allAsleep() then
			DayNightService.skipToMorning()
			Notify.send(player, "msg.morning", "info")
		end
		s.SleepUntil = 0
		setSleeping(player, false)
		Movement.apply(player)
		NeedsLogic.add(data.Needs, "Energy", 100)
		Progress.xp(player, 10)
		State.markCore(player)
		QuestService.event(player, "sleep")
		for _, fn in ipairs(NeedsService.sleepEndHooks) do
			task.spawn(fn, player)
		end
	end)
	return true, if night then "msg.sleep_night" else "msg.sleep_nap"
end

function NeedsService.init()
	Interact.register("Eat", function(player, _prompt, arg)
		local data = DataService.get(player)
		if not data then
			return false, nil
		end
		if arg == "Water" then
			if not Session.cooldown(player, "drink", 15) then
				return false, "msg.not_thirsty"
			end
			NeedsService.add(player, "Hunger", 8)
			NeedsService.add(player, "Health", 4)
			Remotes.getEvent("Fx"):FireClient(player, "Need", "Hunger")
			return true, "msg.drink"
		end
		if data.Needs.Hunger >= 95 then
			return false, "msg.not_hungry"
		end
		if not Session.cooldown(player, "eat", 10) then
			return false, "msg.chewing"
		end
		NeedsService.add(player, "Hunger", 45)
		Progress.xp(player, 6)
		Remotes.getEvent("Fx"):FireClient(player, "Need", "Hunger")
		QuestService.event(player, "eat")
		local ch = player.Character
		if ch then
			ch:SetAttribute("Action", "Eat:" .. os.clock())
		end
		return true, "msg.yum"
	end)
	Interact.register("Beg", function(player)
		if not Session.cooldown(player, "beg", Config.BEG_COOLDOWN) then
			return false, Locale.m("msg.beg_wait", { n = math.ceil(Session.cooldownLeft(player, "beg", Config.BEG_COOLDOWN)) })
		end
		NeedsService.add(player, "Hunger", 15)
		NeedsService.add(player, "Love", 8)
		Progress.bond(player, "Grandma", 2)
		Progress.treats(player, 3)
		Progress.xp(player, 8)
		QuestService.event(player, "beg")
		local ch = player.Character
		if ch then
			ch:SetAttribute("Action", "Beg:" .. os.clock())
		end
		return true, "msg.beg_ok"
	end)
	Interact.register("Sleep", function(player)
		return NeedsService.sleep(player)
	end)
	Interact.register("Bath", function(player)
		local s = Session.get(player)
		if not s then
			return false, nil
		end
		if not Session.cooldown(player, "bath", 8) then
			return false, nil
		end
		s.Bath = { Start = os.clock() }
		s.Carrying = nil
		Remotes.getEvent("OpenUi"):FireClient(player, "Bath")
		return true, nil
	end)
	-- Итог мини-игры купания: score 0..1 (доля смытых пятен). Сервер проверяет: купание начато у ванны,
	-- прошло не меньше BATH_MIN_SECONDS и не больше 60 с.
	Router.register("BathDone", 1, 2, function(player, score: any)
		local s = Session.get(player)
		if not s or not s.Bath then
			return false, "err.bad_request"
		end
		local elapsed = os.clock() - s.Bath.Start
		s.Bath = nil
		if type(score) ~= "number" or elapsed > 60 then
			return false, "err.bad_request"
		end
		if elapsed < Config.BATH_MIN_SECONDS then
			AntiExploit.strike(player, "bath too fast", 3)
			return false, "err.bad_request"
		end
		local sc = math.clamp(score, 0, 1)
		NeedsService.add(player, "Hygiene", 35 + 65 * sc)
		NeedsService.add(player, "Fun", 6)
		Progress.xp(player, math.floor(12 + 18 * sc))
		QuestService.event(player, "bath")
		return true, Locale.m("msg.bath_done", { n = math.floor(sc * 100) })
	end)
	Router.register("BathCancel", 2, 4, function(player)
		local s = Session.get(player)
		if s then
			s.Bath = nil
		end
		return true, nil
	end)
	Router.register("Wake", 2, 4, function(player)
		local s = Session.get(player)
		if s and s.SleepUntil > os.clock() then
			s.SleepUntil = os.clock() + 0.1 -- проснётся в конце таймера (награды как обычно)
		end
		return true, nil
	end)

	-- Убывание потребностей
	task.spawn(function()
		while true do
			local dt = task.wait(Config.NEED_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				local data = DataService.get(player)
				if s and s.Ready and data and data.Species ~= "" then
					local sleeping = s.SleepUntil > os.clock()
					local zone = s.Zone
					NeedsLogic.step(data.Needs, dt, { Sleeping = sleeping, Activity = if zone == "Dream" then 0 else 1 })
					data.NeedsAt = os.time()
					local pos = AntiExploit.rootPos(player)
					if pos then
						local z = if pos.Y > 40 then "Dream" else WorldData.zoneAt(pos)
						if z ~= s.Zone then
							s.Zone = z
							if z == "Home" then
								QuestService.event(player, "arrive_home")
							end
						end
					end
					State.markCore(player)
				end
			end
		end
	end)
end

return NeedsService
