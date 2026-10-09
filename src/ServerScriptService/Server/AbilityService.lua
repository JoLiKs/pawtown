--!strict
--[[
	AbilityService — способности видов (сервер проверяет вид, кулдауны и расстояния):
	  Dog: Sniff (подсветка осколков/ямок рядом), Dig (ямки — лакомства, иногда осколок);
	  Rabbit: Dash (рывок: скорость задаёт сервер), Burrow (лаз под забором — перенос на другую сторону);
	  Cat: DoubleJump (клиент), RoofRun (скорость на крышах — Movement);
	  Parrot: Flap/Glide (клиент), Mimic (эмоция — SocialService).
	Осколки памяти: подсказка у осколка (кроме s_dig — он выкапывается).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local SpeciesData = require(Shared.SpeciesData)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Interact = require(script.Parent.Interact)
local Movement = require(script.Parent.Movement)
local NeedsService = require(script.Parent.NeedsService)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local AbilityService = {}

local shardById = {}
for _, s in ipairs(WorldData.Shards) do
	shardById[s.Id] = s
end
local digById = {}
for _, d in ipairs(WorldData.DigSpots) do
	digById[d.Id] = d
end
local gapById = {}
for _, g in ipairs(WorldData.BurrowGaps) do
	gapById[g.Id] = g
end

local rng = Random.new()

function AbilityService.giveShard(player: Player, id: string): (boolean, any)
	local data = DataService.get(player)
	if not data or not shardById[id] then
		return false, "err.bad_request"
	end
	if data.Shards[id] then
		return false, "msg.shard_have"
	end
	data.Shards[id] = true
	Progress.xp(player, 30)
	Progress.treats(player, 15)
	Remotes.getEvent("Fx"):FireClient(player, "Shard", id)
	QuestService.event(player, "shard", id)
	State.markCore(player)
	local n = 0
	for _ in pairs(data.Shards) do
		n += 1
	end
	return true, Locale.m("msg.shard_found", { n = n, total = #WorldData.Shards })
end

local function sniffRadius(data: any): number
	return 70 * (1 + Progression.bonus(data.Talents, "KeenNose"))
end

function AbilityService.init()
	Interact.register("Shard", function(player, _prompt, arg)
		local s = arg and shardById[arg]
		if not s or s.Id == "s_dig" then
			return false, nil
		end
		if not AntiExploit.near(player, s.Pos, WorldData.SHARD_RADIUS + 4) then
			return false, nil
		end
		return AbilityService.giveShard(player, s.Id)
	end)

	Interact.register("Dig", function(player, _prompt, arg)
		local data = DataService.get(player)
		local spot = arg and digById[arg]
		if not data or not spot then
			return false, nil
		end
		if not SpeciesData.has(data.Species, "Dig") then
			return false, "msg.only_dog"
		end
		if not Session.cooldown(player, "dig:" .. spot.Id, Config.DIG_COOLDOWN) then
			return false, "msg.dig_empty"
		end
		local ch = player.Character
		if ch then
			ch:SetAttribute("Action", "Dig:" .. os.clock())
		end
		NeedsService.add(player, "Fun", 6)
		NeedsService.add(player, "Hygiene", -4)
		Remotes.getEvent("Fx"):FireClient(player, "Dig", spot.Pos)
		if spot.Shard ~= "" and not data.Shards[spot.Shard] then
			return AbilityService.giveShard(player, spot.Shard)
		end
		local t = math.floor(rng:NextInteger(5, 15) * (1 + Progression.bonus(data.Talents, "TreasureHunter")))
		Progress.treats(player, t)
		Progress.xp(player, 8)
		QuestService.event(player, "dig")
		return true, Locale.m("msg.dig_found", { n = t })
	end)

	Interact.register("Burrow", function(player, _prompt, arg)
		local data = DataService.get(player)
		if not data or type(arg) ~= "string" then
			return false, nil
		end
		if not SpeciesData.has(data.Species, "Burrow") then
			return false, "msg.only_rabbit"
		end
		local id, side = string.match(arg, "^([%w_]+):([AB])$")
		local gap = id and gapById[id]
		if not gap then
			return false, nil
		end
		local from = if side == "A" then gap.A else gap.B
		local to = if side == "A" then gap.B else gap.A
		if not AntiExploit.near(player, from, 8) then
			return false, nil
		end
		local ch = player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false, nil
		end
		AntiExploit.markTeleport(player)
		local look = (to - from).Unit
		root.CFrame =
			CFrame.lookAt(to + Vector3.new(0, 2, 0) + look * 1.5, to + Vector3.new(0, 2, 0) + look * 3)
		NeedsService.add(player, "Hygiene", -3)
		NeedsService.add(player, "Fun", 4)
		Remotes.getEvent("Fx"):FireClient(player, "Burrow", to)
		QuestService.event(player, "burrow")
		return true, nil
	end)

	-- Активные способности с кнопки/клавиши
	Router.register("Ability", 4, 6, function(player, name: any)
		local data = DataService.get(player)
		local s = Session.get(player)
		if not data or not s or type(name) ~= "string" then
			return false, "err.bad_request"
		end
		if not SpeciesData.has(data.Species, name) then
			return false, "msg.no_ability"
		end
		if s.SleepUntil > os.clock() then
			return false, nil
		end
		if name == "Sniff" then
			if not Session.cooldown(player, "sniff", Config.SNIFF_COOLDOWN) then
				return false, nil
			end
			local pos = AntiExploit.rootPos(player)
			if not pos then
				return false, nil
			end
			local r = sniffRadius(data)
			local found = {}
			for _, sh in ipairs(WorldData.Shards) do
				if not data.Shards[sh.Id] and (sh.Pos - pos).Magnitude <= r then
					table.insert(found, { Kind = "Shard", Pos = sh.Pos })
				end
			end
			for _, d in ipairs(WorldData.DigSpots) do
				if (d.Pos - pos).Magnitude <= r then
					table.insert(found, { Kind = "Dig", Pos = d.Pos })
				end
			end
			Remotes.getEvent("Fx"):FireClient(player, "Sniff", found)
			local ch = player.Character
			if ch then
				ch:SetAttribute("Action", "Sniff:" .. os.clock())
			end
			QuestService.event(player, "sniff")
			return true, if #found > 0 then Locale.m("msg.sniff_found", { n = #found }) else "msg.sniff_none"
		elseif name == "Dash" then
			if not Session.cooldown(player, "dash", Config.DASH_COOLDOWN) then
				return false, nil
			end
			s.DashUntil = os.clock() + Config.DASH_TIME
			Movement.apply(player)
			task.delay(Config.DASH_TIME + 0.05, function()
				if player.Parent then
					Movement.apply(player)
				end
			end)
			return true, nil
		end
		return false, "msg.no_ability"
	end)
end

AbilityService._sniffRadius = sniffRadius

return AbilityService
