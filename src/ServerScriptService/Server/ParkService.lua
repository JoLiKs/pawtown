--!strict
--[[
	ParkService — мини-игры:
	  * Апорт (дома — с Мией, в парке — метатель мячей): мяч падает в случайной точке радиуса, игрок подбирает
	    его (подсказка, только владелец) и приносит обратно за FETCH_TIME_LIMIT секунд;
	  * Аджилити-трасса на время: старт у ворот, 6 колец по порядку (сервер сам проверяет позицию игрока),
	    медали по времени (WorldData.Agility.Medals), лучший результат сохраняется. Соревнования честные:
	    косметика за лакомства на скорость не влияет, покупок за Robux нет.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Remotes = require(Shared.Remotes)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local FamilyService = require(script.Parent.FamilyService)
local Interact = require(script.Parent.Interact)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ParkService = {}

local rng = Random.new()

local function clearBall(player: Player)
	local s = Session.get(player)
	if s and s.Fetch then
		if s.Fetch.Ball then
			s.Fetch.Ball:Destroy()
		end
		s.Fetch = nil
	end
	if s and s.Carrying == "Ball" then
		s.Carrying = nil
	end
end

local function finishFetch(player: Player): boolean
	local s = Session.get(player)
	if not s or not s.Fetch or s.Carrying ~= "Ball" then
		return false
	end
	local where = s.Fetch.Where
	clearBall(player)
	NeedsService.add(player, "Fun", 20)
	NeedsService.add(player, "Love", 4)
	Progress.xp(player, 15)
	Progress.treats(player, 5)
	if where == "Home" then
		FamilyService.bond(player, "Kid", 2)
	else
		Progress.rep(player, "Park", 3)
	end
	QuestService.event(player, "fetch")
	Remotes.getEvent("Fx"):FireClient(player, "FetchDone")
	State.markCore(player)
	Notify.send(player, "msg.fetch_done", "reward")
	return true
end

local function startFetch(player: Player, where: string): (boolean, any)
	local s = Session.get(player)
	if not s then
		return false, nil
	end
	if s.Fetch then
		if s.Carrying == "Ball" and s.Fetch.Where == where then
			finishFetch(player)
			return true, nil
		end
		return false, "msg.fetch_busy"
	end
	if s.Carrying then
		return false, "msg.mouth_full"
	end
	local center = if where == "Park" then WorldData.Fetch.Park else WorldData.Fetch.HomeYard
	local radius = if where == "Park" then WorldData.Fetch.Radius else 10
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(radius * 0.5, radius)
	local pos = center + Vector3.new(math.cos(a) * r, 0.7, math.sin(a) * r)
	local ball = WorldBuilder.part(
		WorldBuilder.folder("Dynamic"),
		"Ball_" .. player.UserId,
		Vector3.new(1.4, 1.4, 1.4),
		pos,
		Color3.fromRGB(250, 230, 70),
		{
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		}
	)
	ball:SetAttribute("Owner", player.UserId)
	ball:SetAttribute("FetchBall", true)
	Interact.prompt(
		ball,
		"GrabBall",
		"prompt.grab_ball",
		{ Arg = tostring(player.UserId), Object = "obj.ball", Distance = 8 }
	)
	s.Fetch = { Start = os.clock(), Where = where, Ball = ball } :: any
	local token = s.Fetch
	if where == "Home" then
		FamilyService.say("Kid", "speech.kid_throw")
	end
	task.delay(Config.FETCH_TIME_LIMIT, function()
		local s2 = Session.get(player)
		if s2 and s2.Fetch == token then
			clearBall(player)
			State.markCore(player)
			Notify.send(player, "msg.fetch_timeout", "info")
		end
	end)
	Remotes.getEvent("Fx"):FireClient(player, "FetchStart", pos)
	return true, "msg.fetch_go"
end

-- Аджилити
local function agilityTick(player: Player)
	local s = Session.get(player)
	local ag = s and s.Agility
	if not s or not ag then
		return
	end
	local pos = AntiExploit.rootPos(player)
	if not pos then
		return
	end
	local A = WorldData.Agility
	local elapsed = os.clock() - ag.Start
	if elapsed > Config.AGILITY_TIME_LIMIT then
		s.Agility = nil
		Remotes.getEvent("Fx"):FireClient(player, "AgilityEnd", 0, 0)
		Notify.send(player, "msg.agility_timeout", "info")
		return
	end
	local cp = A.Checkpoints[ag.Next]
	if Vector3.new(pos.X - cp.X, 0, pos.Z - cp.Z).Magnitude <= A.Radius then
		ag.Next += 1
		if ag.Next > #A.Checkpoints then
			s.Agility = nil
			local t = math.floor(elapsed * 10 + 0.5) / 10
			local medal = if t <= A.Medals.Gold
				then 3
				elseif t <= A.Medals.Silver then 2
				elseif t <= A.Medals.Bronze then 1
				else 0
			local data = DataService.get(player)
			local best = data and data.Best.Agility or 0
			if data and (best == 0 or t < best) then
				data.Best.Agility = t
			end
			Progress.xp(player, 20 + medal * 15)
			Progress.treats(player, 5 + medal * 8)
			Progress.rep(player, "Park", 4 + medal * 2)
			NeedsService.add(player, "Fun", 20)
			QuestService.event(player, "agility")
			Remotes.getEvent("Fx"):FireClient(player, "AgilityEnd", t, medal)
			Notify.send(player, Locale.m("msg.agility_done", { t = t, medal = "medal." .. medal }), "reward")
			State.markCore(player)
		else
			Remotes.getEvent("Fx"):FireClient(player, "AgilityCp", ag.Next)
		end
	end
end

function ParkService.init()
	Interact.register("Fetch", function(player, _prompt, arg)
		return startFetch(player, if arg == "Park" then "Park" else "Home")
	end)
	Interact.register("GrabBall", function(player, _prompt, arg)
		local s = Session.get(player)
		if not s or not s.Fetch or arg ~= tostring(player.UserId) then
			return false, "msg.not_your_ball"
		end
		if s.Carrying then
			return false, "msg.mouth_full"
		end
		s.Carrying = "Ball"
		if s.Fetch.Ball then
			s.Fetch.Ball:Destroy()
			s.Fetch.Ball = nil
		end
		State.markCore(player)
		return true, if s.Fetch.Where == "Home" then "msg.ball_home" else "msg.ball_park"
	end)
	FamilyService.onBallToKid = function(player)
		local s = Session.get(player)
		if s and s.Fetch and s.Fetch.Where == "Home" then
			return finishFetch(player)
		end
		return false
	end
	Interact.register("Agility", function(player)
		local s = Session.get(player)
		if not s then
			return false, nil
		end
		if s.Agility then
			return false, "msg.agility_running"
		end
		s.Agility = { Start = os.clock(), Next = 1 }
		Remotes.getEvent("Fx"):FireClient(player, "AgilityStart", Config.AGILITY_TIME_LIMIT)
		return true, "msg.agility_go"
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				if s and s.Agility then
					pcall(agilityTick, player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(clearBall)
end

ParkService._finishFetch = finishFetch

return ParkService
