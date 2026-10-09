--!strict
--[[
	RareAbilities — способности редких видов (сервер авторитетен: вид, кулдауны, расстояния, награды).
	  Лиса: Stealth — в кусте (и STEALTH_LINGER сек после) «невидима» (атрибут Hidden: клиенты делают её
	        полупрозрачной); Snatch — выскочить из куста и стащить угощение у человека (иначе заметят).
	  Снежный барс: HugeLeap — сервер открывает окно LEAP_TIME (легальная скорость выше), прыжок делает клиент;
	        RoofSprint — быстрее по крышам (Movement).
	  Корги-рыцарь: ShieldRoll — перекат со щитом (рывок + атрибут Rolling); CommandDogs — собаки парка идут
	        следом, у приюта получают дом (лакомства, репутация парка).
	  Хрустальный кролик: CrystalSight — список секретов в радиусе (осколки, ямки, тайники, искры испытания):
	        клиент подсвечивает их сквозь стены (Highlight AlwaysOnTop); тайники открываются только «увиденные».
	  Енот: Unlock — мусорные баки и замки сараев (безделушки в тайник + лакомства); Stash — логово:
	        безделушки -> лакомства.
	  Сова: LongFlight (клиент: 5 взмахов, медленное планирование); NightVision — клиентский фильтр.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local PetRig = require(Shared.PetRig)
local Remotes = require(Shared.Remotes)
local SpeciesData = require(Shared.SpeciesData)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local FamilyService = require(script.Parent.FamilyService)
local Interact = require(script.Parent.Interact)
local Movement = require(script.Parent.Movement)
local NeedsService = require(script.Parent.NeedsService)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RareAbilities = {}

local rng = Random.new()

-- ------------------------------------------------------------------------------------------- лиса
function RareAbilities.inBush(pos: Vector3): boolean
	for _, b in ipairs(WorldBuilder.bushes) do
		if
			Vector3.new(pos.X - b.X, 0, pos.Z - b.Z).Magnitude <= Config.STEALTH_RADIUS
			and pos.Y < b.Y + 6
		then
			return true
		end
	end
	return false
end

local function stealthTick(player: Player)
	local data = DataService.get(player)
	local s = Session.get(player)
	local ch = player.Character
	if not data or not s or not ch then
		return
	end
	local hidden = false
	if SpeciesData.has(data.Species, "Stealth") then
		local pos = AntiExploit.rootPos(player)
		if pos and RareAbilities.inBush(pos) then
			s.HiddenUntil = os.clock() + Config.STEALTH_LINGER
		end
		hidden = s.HiddenUntil > os.clock()
	end
	if ch:GetAttribute("Hidden") ~= hidden then
		ch:SetAttribute("Hidden", hidden)
	end
end

local SNATCH_LOOT = { "Sandwich", "Sock", "Letter", "Cookie" }

function RareAbilities.snatch(player: Player, npcId: string): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s then
		return false, nil
	end
	if not SpeciesData.has(data.Species, "Snatch") then
		return false, "msg.no_ability"
	end
	if s.Carrying then
		return false, "msg.mouth_full"
	end
	if s.HiddenUntil <= os.clock() then
		FamilyService.say(npcId, "speech.noticed")
		return false, "msg.snatch_seen"
	end
	if not Session.cooldown(player, "snatch:" .. npcId, Config.SNATCH_COOLDOWN) then
		return false, "msg.snatch_wait"
	end
	s.HiddenUntil = 0
	local loot = SNATCH_LOOT[rng:NextInteger(1, #SNATCH_LOOT)]
	local t = rng:NextInteger(10, 20)
	Progress.treats(player, t)
	Progress.xp(player, 15)
	Progress.stat(player, "snatch")
	NeedsService.add(player, "Fun", 8)
	FamilyService.say(npcId, "speech.snatched")
	QuestService.event(player, "snatch", npcId)
	local ch = player.Character
	if ch then
		ch:SetAttribute("Action", "Sniff:" .. os.clock())
	end
	return true, Locale.m("msg.snatched", { item = "loot." .. loot, n = t })
end

-- ------------------------------------------------------------------------------------ енот
local function addTrinket(data: any, n: number): number
	local before = data.Stash.Trinkets
	data.Stash.Trinkets = math.min(Config.STASH_MAX, before + n)
	return data.Stash.Trinkets - before
end

function RareAbilities.unlock(player: Player, arg: string): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	if not SpeciesData.has(data.Species, "Unlock") then
		return false, "msg.only_raccoon"
	end
	local kind, idx = string.match(arg, "^(%a+)(%d+)$")
	local i = tonumber(idx)
	if not kind or not i then
		return false, nil
	end
	local pos = if kind == "bin"
		then WorldData.TrashBins[i]
		elseif kind == "shed" then WorldData.shedPos(i)
		else nil
	if not pos or not AntiExploit.near(player, pos, 12) then
		return false, nil
	end
	local cd = if kind == "bin" then Config.BIN_COOLDOWN else Config.SHED_COOLDOWN
	if not Session.cooldown(player, "unlock:" .. arg, cd) then
		return false, "msg.unlock_empty"
	end
	local got = addTrinket(data, if kind == "bin" then 1 else 2)
	local t = if kind == "bin" then rng:NextInteger(3, 8) else rng:NextInteger(15, 25)
	Progress.treats(player, t)
	Progress.xp(player, if kind == "bin" then 8 else 20)
	NeedsService.add(player, "Fun", 6)
	NeedsService.add(player, "Hygiene", if kind == "bin" then -6 else -2)
	QuestService.event(player, "unlock", arg)
	State.markCore(player)
	local ch = player.Character
	if ch then
		ch:SetAttribute("Action", "Dig:" .. os.clock())
	end
	if got == 0 then
		return true, Locale.m("msg.stash_full", { n = t })
	end
	return true, Locale.m("msg.unlocked", { n = t, k = got })
end

function RareAbilities.stash(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	if not SpeciesData.has(data.Species, "Stash") then
		return false, "msg.only_raccoon"
	end
	local n = data.Stash.Trinkets
	if n <= 0 then
		return false, "msg.stash_empty"
	end
	data.Stash.Trinkets = 0
	data.Stash.Total = (data.Stash.Total or 0) + n
	local t = Progress.treats(player, n * Config.STASH_TREATS)
	Progress.xp(player, n * 4)
	QuestService.event(player, "stash")
	State.markCore(player)
	return true, Locale.m("msg.stash_traded", { k = n, n = t })
end

-- ------------------------------------------------------------------- хрустальный кролик
function RareAbilities.secrets(player: Player, data: any, pos: Vector3): { any }
	local r = Config.SIGHT_RADIUS
	local out = {}
	for _, sh in ipairs(WorldData.Shards) do
		if not data.Shards[sh.Id] and (sh.Pos - pos).Magnitude <= r then
			table.insert(out, { Kind = "Shard", Pos = sh.Pos, Id = sh.Id })
		end
	end
	for _, c in ipairs(WorldData.SecretCaches) do
		if (c.Pos - pos).Magnitude <= r and Session.cooldownLeft(player, "cache:" .. c.Id, 1800) <= 0 then
			table.insert(out, { Kind = "Cache", Pos = c.Pos, Id = c.Id })
		end
	end
	for _, d in ipairs(WorldData.DigSpots) do
		if (d.Pos - pos).Magnitude <= r then
			table.insert(out, { Kind = "Dig", Pos = d.Pos, Id = d.Id })
		end
	end
	return out
end

function RareAbilities.cache(player: Player, id: string): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s then
		return false, nil
	end
	if not SpeciesData.has(data.Species, "CrystalSight") then
		return false, "msg.no_ability"
	end
	local c
	for _, x in ipairs(WorldData.SecretCaches) do
		if x.Id == id then
			c = x
		end
	end
	if not c or not AntiExploit.near(player, c.Pos, 10) then
		return false, nil
	end
	if s.SightUntil <= os.clock() then
		return false, "msg.cache_hidden"
	end
	if not Session.cooldown(player, "cache:" .. id, 1800) then
		return false, "msg.cache_empty"
	end
	local t = rng:NextInteger(20, 35)
	Progress.treats(player, t)
	Progress.xp(player, 25)
	QuestService.event(player, "cache", id)
	return true, Locale.m("msg.cache_found", { n = t })
end

-- --------------------------------------------------------------------- корги: собаки парка
type Dog = { Model: Model, Home: Vector3, Leader: Player?, Until: number, Index: number }
local dogs: { Dog } = {}
RareAbilities.dogs = dogs

local function spawnDogs()
	local folder = WorldBuilder.folder("NPC")
	local colors = { "Dog", "Dog", "Dog" }
	for i, pos in ipairs(WorldData.ParkDogs) do
		local m = PetRig.build(
			colors[i] or "Dog",
			CFrame.new(pos + Vector3.new(0, PetRig.ROOT_Y, 0)),
			{ Scale = 0.85, Name = "ParkDog" .. i }
		)
		m:SetAttribute("ParkDog", i)
		m:SetAttribute("NpcId", "ParkDog")
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				-- свои окрасы, чтобы отличались от игроков-собак
				if d.Name == "Body" or d.Name == "Head" then
					d.Color = ({
						Color3.fromRGB(150, 150, 160),
						Color3.fromRGB(110, 80, 60),
						Color3.fromRGB(230, 220, 200),
					})[i] or d.Color
				end
			end
		end
		m.Parent = folder
		table.insert(dogs, { Model = m, Home = pos, Leader = nil, Until = 0, Index = i })
	end
end

function RareAbilities.command(player: Player): (boolean, any)
	local pos = AntiExploit.rootPos(player)
	if not pos then
		return false, nil
	end
	local n = 0
	for _, d in ipairs(dogs) do
		local root = d.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - pos).Magnitude <= Config.DOGS_COMMAND_RADIUS then
			d.Leader = player
			d.Until = os.clock() + Config.DOGS_FOLLOW_TIME
			n += 1
		end
	end
	if n == 0 then
		return false, "msg.no_dogs"
	end
	local ch = player.Character
	if ch then
		ch:SetAttribute("Emote", "Voice:" .. os.clock())
	end
	QuestService.event(player, "command_dogs")
	return true, Locale.m("msg.dogs_follow", { n = n })
end

local function dogsTick()
	local now = os.clock()
	local keeper = WorldData.Family.Keeper
	for _, d in ipairs(dogs) do
		local hum = d.Model:FindFirstChildOfClass("Humanoid")
		local root = d.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root then
			local leader = d.Leader
			local lpos = leader and leader.Parent and AntiExploit.rootPos(leader)
			if leader and lpos and now < d.Until then
				local off = Vector3.new(math.cos(d.Index * 2.1) * 4, 0, math.sin(d.Index * 2.1) * 4)
				hum.WalkSpeed = 20
				hum:MoveTo(lpos + off)
				-- привёл к смотрительнице приюта: собака нашла дом
				if (root.Position - keeper).Magnitude < 14 then
					if Session.cooldown(leader, "doghome:" .. d.Index, 900) then
						Progress.reward(leader, { Treats = 15, Xp = 25 }, "msg.dog_home")
						Progress.rep(leader, "Park", 4)
						QuestService.event(leader, "dog_home")
						FamilyService.say("Keeper", "speech.keeper_dog")
					end
					d.Leader = nil
					d.Until = now + 8 -- отдых у приюта, потом обратно в парк
				end
			else
				d.Leader = nil
				hum.WalkSpeed = 8
				if now > d.Until then
					d.Until = now + rng:NextNumber(4, 9)
					local a = rng:NextNumber(0, math.pi * 2)
					hum:MoveTo(d.Home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 14))
				end
			end
		end
	end
end

-- ------------------------------------------------------------------------- активные (Router "Ability")
function RareAbilities.ability(player: Player, name: string, data: any, s: any): (boolean, any)
	if name == "HugeLeap" then
		if not Session.cooldown(player, "leap", Config.LEAP_COOLDOWN) then
			return false, nil
		end
		s.LeapUntil = os.clock() + Config.LEAP_TIME
		local ch = player.Character
		if ch then
			ch:SetAttribute("AirJump", os.clock())
		end
		return true, nil
	elseif name == "ShieldRoll" then
		if not Session.cooldown(player, "roll", Config.ROLL_COOLDOWN) then
			return false, nil
		end
		s.DashUntil = os.clock() + Config.ROLL_TIME
		local ch = player.Character
		if ch then
			ch:SetAttribute("Action", "Roll:" .. os.clock())
		end
		Movement.apply(player)
		task.delay(Config.ROLL_TIME + 0.05, function()
			if player.Parent then
				Movement.apply(player)
			end
		end)
		return true, nil
	elseif name == "CommandDogs" then
		if not Session.cooldown(player, "command", 2) then
			return false, nil
		end
		return RareAbilities.command(player)
	elseif name == "CrystalSight" then
		if not Session.cooldown(player, "sight", Config.SIGHT_COOLDOWN) then
			return false, nil
		end
		local pos = AntiExploit.rootPos(player)
		if not pos then
			return false, nil
		end
		s.SightUntil = os.clock() + Config.SIGHT_TIME + 20
		local found = RareAbilities.secrets(player, data, pos)
		Remotes.getEvent("Fx"):FireClient(player, "CrystalSight", found)
		QuestService.event(player, "sight")
		return true, Locale.m("msg.sight_found", { n = #found })
	elseif name == "NightVision" then
		return true, nil -- фильтр включает клиент; сервер только подтверждает вид
	end
	return false, "msg.no_ability"
end

function RareAbilities.init()
	Interact.register("Unlock", function(player, _prompt, arg)
		return RareAbilities.unlock(player, arg or "")
	end)
	Interact.register("Stash", function(player)
		return RareAbilities.stash(player)
	end)
	Interact.register("Cache", function(player, _prompt, arg)
		return RareAbilities.cache(player, arg or "")
	end)
	Interact.register("Snatch", function(player, _prompt, arg)
		return RareAbilities.snatch(player, arg or "")
	end)
	-- «стащить» можно у всех людей, кроме смотрительницы приюта
	for id, m in pairs(FamilyService.npcs) do
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and id ~= "Keeper" then
			Interact.prompt(
				root,
				"Snatch",
				"prompt.snatch",
				{ Arg = id, Species = "Snatch", Key = Enum.KeyCode.R, Object = "npc." .. id, Distance = 9 }
			)
		end
	end
	State.providers.Stash = function(_player, data)
		return data.Stash.Trinkets
	end
	spawnDogs()
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(stealthTick, player)
			end
			local ok: boolean, err: any = pcall(dogsTick)
			if not ok then
				warn("[RareAbilities] dogs:", err)
			end
		end
	end)
end

return RareAbilities
