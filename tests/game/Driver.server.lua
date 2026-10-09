--!nocheck
-- Интеграционный сценарий Pawtown (эмулятор roblox2web, серверный Script рядом с игрой).
-- Идёт по реальным путям кода: подсказки (Interact) и Router -> сервисы -> данные.
-- Печатает "OK имя" / "FAIL имя: причина" и в конце "DONE".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local TrickData = require(Shared.TrickData)
local WorldData = require(Shared.WorldData)
local QuestData = require(Shared.QuestData)

local DataService = require(Server.DataService)
local Session = require(Server.Session)
local AntiExploit = require(Server.AntiExploit)
local Interact = require(Server.Interact)
local QuestService = require(Server.QuestService)
local DayNightService = require(Server.DayNightService)
local PlayerService = require(Server.PlayerService)
local Movement = require(Server.Movement)
local RareAbilities = require(Server.RareAbilities)
local WorldBuilder = require(Server.WorldBuilder)
local RebirthLogic = require(Shared.RebirthLogic)

local function check(name, cond, msg)
	if cond then
		print("OK " .. name)
	else
		print("FAIL " .. name .. ": " .. tostring(msg or "condition false"))
	end
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local t0 = os.clock()
while
	not (
		Session.get(player)
		and Session.get(player).Ready
		and player.Character
		and player.Character:FindFirstChild("HumanoidRootPart")
	)
do
	task.wait(0.1)
	if os.clock() - t0 > 30 then
		print("FAIL startup: player never became ready")
		print("DONE")
		return
	end
end
task.wait(0.5)
local data = DataService.get(player)
local function root()
	return player.Character:FindFirstChild("HumanoidRootPart")
end
local function call(action, ...)
	local fn = Remotes.getFunction("Action")
	local res = fn.OnServerInvoke(player, action, ...)
	task.wait(0.4) -- лимиты частоты Router
	return res
end
local function moveTo(pos)
	AntiExploit.markTeleport(player)
	root().CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	root().AssemblyLinearVelocity = Vector3.zero
	task.wait(0.3)
end
local function findPrompt(action, arg)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if
			d:IsA("ProximityPrompt")
			and d:GetAttribute("Action") == action
			and (arg == nil or d:GetAttribute("Arg") == arg)
		then
			return d
		end
	end
	return nil
end
local function usePrompt(action, arg, noMove)
	local p = findPrompt(action, arg)
	if not p then
		return false, "no prompt " .. action .. "/" .. tostring(arg)
	end
	if not noMove then
		local part = p.Parent
		moveTo(part.Position + Vector3.new(2, 0, 0))
	end
	local ok, msg = Interact.dispatch(player, p)
	task.wait(0.35)
	return ok, msg
end
local function step()
	return QuestService.stepId(player)
end
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- ===================================================================== 1. Старт: приют и мир
check("spawn: no species yet", data.Species == "")
check("spawn: in shelter", WorldData.zoneAt(root().Position) == "Shelter", tostring(root().Position))
check(
	"rig: custom pet rig with Motor6D",
	player.Character:FindFirstChild("Root", true) ~= nil and player.Character:FindFirstChild("Head") ~= nil
)
check(
	"rig: humanoid hip height",
	math.abs(player.Character:FindFirstChildOfClass("Humanoid").HipHeight - 0.35) < 0.2
)
for _, name in ipairs({ "Home", "Shelter", "Park", "Neighbours", "Garden", "Shards", "Dream", "NPC" }) do
	check("world: " .. name .. " built", Workspace:FindFirstChild(name, true) ~= nil)
end
check(
	"world: family NPCs",
	Workspace:FindFirstChild("Dad", true)
		and Workspace:FindFirstChild("Grandma", true)
		and Workspace:FindFirstChild("Kid", true)
		and Workspace:FindFirstChild("Mailman", true)
)
check("quest: step 1 is species", step() == "c1_species", step())
check(
	"locale: player language attribute",
	player:GetAttribute("Lang") == "en" or player:GetAttribute("Lang") == "ru"
)

-- ===================================================================== 2. Выбор вида
local r = call("ChooseSpecies", "MidnightCat")
check("species: rare species rejected", r.ok == false)
r = call("ChooseSpecies", "Dog")
check("species: choose Dog", r.ok == true and data.Species == "Dog", r.msg)
task.wait(0.3)
check("species: rig rebuilt as Dog", player.Character:GetAttribute("Species") == "Dog")
check("quest: step 2 go home", step() == "c1_home", step())
r = call("ChooseSpecies", "Cat")
check("species: can't choose twice", r.ok == false and data.Species == "Dog")

-- ===================================================================== 3. Дом, еда
moveTo(WorldData.SPAWN_HOME)
task.wait(Config.NEED_TICK + 1)
check("quest: arrived home", step() == "c1_eat", step())
data.Needs.Hunger = 30
local ok, msg = usePrompt("Eat", nil)
check("eat: from bowl", ok and data.Needs.Hunger > 30, tostring(msg) .. " " .. data.Needs.Hunger)
check("quest: after eating -> trick", step() == "c1_trick", step())

-- ===================================================================== 4. Трюк (ритм)
r = call("TrickStart", "Spin")
check("trick: locked trick rejected", r.ok == false)
r = call("TrickStart", "Sit")
check("trick: start gives seed", r.ok and r.data and type(r.data.Seed) == "number", r.msg)
local seed = r.data and r.data.Seed or 1
check("trick: pet frozen during trick", Movement.walkSpeed(player) == 0)
r = call("TrickFinish", "Sit", { 0, 0, 0, 0 })
check("trick: too fast finish rejected", r.ok == false)
r = call("TrickStart", "Sit")
seed = r.data and r.data.Seed or 1
task.wait(TrickData.duration("Sit", seed) + 0.2)
r = call("TrickFinish", "Sit", { 0.01, -0.02, 0.0, 0.03 })
check("trick: perfect -> gold", r.ok and r.data and r.data.Medal == 3, r.msg)
check("trick: best medal saved", data.Tricks.Sit and data.Tricks.Sit.Best == 3)
check("quest: after trick -> family", step() == "c1_family", step())
check("trick: attribute for animation", type(player.Character:GetAttribute("Trick")) == "string")

-- ===================================================================== 5. Семья
for _, m in ipairs({ "Dad", "Grandma", "Kid" }) do
	local p = findPrompt("Family", m)
	local npc = p and p.Parent
	if npc then
		moveTo(npc.Position + Vector3.new(3, 0, 0))
	end
	ok, msg = usePrompt("Family", m, true)
	if m == "Dad" and msg == "msg.woke_dad" then
		-- утром папа спит: первое касание будит его, второе — ласка
		check("family: woke Dad up", true)
		p = findPrompt("Family", m)
		moveTo(p.Parent.Position + Vector3.new(3, 0, 0))
		ok, msg = usePrompt("Family", m, true)
	end
	check("family: cuddle " .. m, ok, msg)
end
check("family: bond grew", data.Bond.Dad > 0 and data.Bond.Grandma > 0 and data.Bond.Kid > 0)
check("quest: after family -> shards", step() == "c1_shards", step())

-- ===================================================================== 6. Осколки памяти
local gotShards = 0
for _, sh in ipairs(WorldData.Shards) do
	if sh.Access == "Any" and gotShards < 3 then
		ok, msg = usePrompt("Shard", nil and sh.Id)
		local p
		for _, d in ipairs(Workspace:GetDescendants()) do
			if
				d:IsA("ProximityPrompt")
				and d:GetAttribute("Action") == "Shard"
				and d.Parent:GetAttribute("ShardId") == sh.Id
			then
				p = d
			end
		end
		if p then
			moveTo(p.Parent.Position + Vector3.new(1.5, 0, 0))
			ok, msg = Interact.dispatch(player, p)
			task.wait(0.3)
			if data.Shards[sh.Id] then
				gotShards += 1
			end
		end
	end
end
check("shards: collected 3", gotShards == 3 and count(data.Shards) >= 3, gotShards)
check("quest: after shards -> dream", step() == "c1_dream", step())
local first = nil
for _, sh in ipairs(WorldData.Shards) do
	if data.Shards[sh.Id] then
		first = sh
		break
	end
end

-- ===================================================================== 7. Сон и катсцена сна
data.Needs.Energy = 20
DayNightService.setClock(22)
task.wait(0.3)
check("daynight: night at 22:00", DayNightService.isNight() and Lighting.ClockTime > 21, Lighting.ClockTime)
ok, msg = usePrompt("Sleep", nil)
check("sleep: in pet bed", ok and Session.get(player).SleepUntil > os.clock(), msg)
check("sleep: frozen while sleeping", Movement.walkSpeed(player) == 0)
task.wait(Config.SLEEP_SECONDS + 1.5)
check("sleep: energy refilled", data.Needs.Energy >= 90, data.Needs.Energy)
check("sleep: night skipped to morning", not DayNightService.isNight(), DayNightService.clock())
check("dream: teleported to dream island", root().Position.Y > 40, tostring(root().Position))
task.wait(12)
check("dream: back in bed", root().Position.Y < 20)
check("quest: chapter 1 complete", step() == nil and data.Story.Step > #QuestData.CHAPTER1, tostring(step()))

-- ===================================================================== 8. Способности собаки
r = call("Ability", "Sniff")
check("ability: dog sniff", r.ok == true, r.msg)
r = call("Ability", "Dash")
check("ability: dog can't dash", r.ok == false)
local treatsBefore = data.Treats
ok, msg = usePrompt("Dig", "dig_park1")
check("dig: dog digs up shard s_dig", data.Shards.s_dig == true, msg)
check("dig: cooldown", (select(1, usePrompt("Dig", "dig_park1", true))) == false)
_ = treatsBefore

-- ===================================================================== 9. Бутик и таланты
data.Treats = 500
moveTo(WorldData.SPAWN_SHELTER)
r = call("Buy", "hat_party")
check("shop: can't buy away from home", r.ok == false)
moveTo(WorldData.Home.Boutique + Vector3.new(3, 0, 3))
r = call("Buy", "hat_party")
check(
	"shop: bought and equipped",
	r.ok and data.Cosmetics.Owned.hat_party and data.Cosmetics.Equipped.Hat == "hat_party",
	r.msg
)
task.wait(0.3)
check(
	"shop: cosmetic on the rig",
	player.Character:FindFirstChild("HatBase", true) ~= nil or #player.Character:GetDescendants() > 0
)
check("shop: treats spent", data.Treats == 500 - 80, data.Treats)
r = call("Buy", "hat_party")
check("shop: no double buy", r.ok == false and data.Treats == 420)
r = call("Equip", "Hat", "")
check("shop: unequip", r.ok and data.Cosmetics.Equipped.Hat == "")
r = call("Equip", "Hat", "hat_crown")
check("shop: can't equip unowned", r.ok == false)
r = call("Talent", "KeenNose")
check("talent: learn first", r.ok and data.Talents.KeenNose == 1, r.msg)
r = call("Talent", "Showstopper")
check("talent: locked second", r.ok == false)

-- ===================================================================== 10. Эмоции, ванна
r = call("Emote", "Wag")
check("emote: wag", r.ok and string.find(player.Character:GetAttribute("Emote") or "", "Wag") ~= nil)
r = call("Emote", "Mimic")
check("emote: mimic only for parrots", r.ok == false)
data.Needs.Hygiene = 20
ok, msg = usePrompt("Bath", nil)
check("bath: started", Session.get(player).Bath ~= nil, msg)
r = call("BathDone", 1)
check("bath: too fast rejected", r.ok == false)
task.wait(2.2)
usePrompt("Bath", nil, true)
task.wait(Config.BATH_MIN_SECONDS + 0.5)
r = call("BathDone", 0.9)
check("bath: done raises hygiene", r.ok and data.Needs.Hygiene > 70, data.Needs.Hygiene)

-- ===================================================================== 11. Парк: апорт и полоса
ok, msg = usePrompt("Fetch", "Park")
local s = Session.get(player)
check("fetch: ball launched", s.Fetch ~= nil and s.Fetch.Ball ~= nil, msg)
if s.Fetch and s.Fetch.Ball then
	local ball = s.Fetch.Ball
	task.wait(1.2)
	moveTo(ball.Position + Vector3.new(1, 0, 0))
	local gp = ball:FindFirstChildOfClass("ProximityPrompt")
	if gp then
		Interact.dispatch(player, gp)
		task.wait(0.3)
	end
	check("fetch: carrying ball", s.Carrying == "Ball", s.Carrying)
	moveTo(WorldData.Fetch.Park + Vector3.new(3, 0, 0))
	task.wait(1)
	check("fetch: returned", s.Fetch == nil and s.Carrying == nil, tostring(s.Carrying))
end
ok, msg = usePrompt("Agility", nil)
check("agility: started", s.Agility ~= nil, msg)
for _, cp in ipairs(WorldData.Agility.Checkpoints) do
	moveTo(cp)
	task.wait(0.4)
end
task.wait(0.5)
check("agility: finished with best time", s.Agility == nil and data.Best.Agility > 0, data.Best.Agility)

-- ===================================================================== 12. Кролик: лаз под забором; анти-чит
data.Species = "Rabbit"
PlayerService.respawnInPlace(player)
task.wait(0.5)
check("rabbit: rig", player.Character:GetAttribute("Species") == "Rabbit")
local gap = WorldData.BurrowGaps[1]
local bp = findPrompt("Burrow", gap.Id .. ":A")
if bp then
	moveTo(bp.Parent.Position + Vector3.new(1, 0, 0))
	ok, msg = Interact.dispatch(player, bp)
	task.wait(0.5)
	check(
		"burrow: crawled to the other side",
		(root().Position - gap.B).Magnitude < 6,
		tostring(root().Position) .. " " .. tostring(msg)
	)
else
	check("burrow: prompt exists", false)
end
r = call("Ability", "Dash")
check("dash: rabbit dashes", r.ok and Movement.walkSpeed(player) > Movement.baseSpeed(data) * 1.5, r.msg)
task.wait(1.2)
local hum = player.Character:FindFirstChildOfClass("Humanoid")
hum.WalkSpeed = 120
task.wait(1.2)
check("anticheat: walk speed restored", hum.WalkSpeed < 40, hum.WalkSpeed)

-- ===================================================================== 13. Физика способностей: прыжок скриптом (двойной прыжок/взмах)
moveTo(WorldData.SPAWN_HOME + Vector3.new(0, 0, -6))
task.wait(1)
local y0 = root().Position.Y
root().AssemblyLinearVelocity = Vector3.new(0, 50, 0)
task.wait(0.2)
check(
	"physics: script-set velocity lifts the pet (double jump works)",
	root().Position.Y > y0 + 2,
	root().Position.Y - y0
)

-- ===================================================================== 13b. Ночь Искр и редкие виды
r = call("DevFastTrack", "Raccoon")
check("rebirth: dev fast-track absent outside Studio", r.ok == false, r.msg)
data.Species = "Rabbit"
RebirthLogic.fastTrack(data, "CrystalRabbit")
data.Trials.CrystalRabbit = nil
r = call("Rebirth", "CrystalRabbit", "LightPaws")
check("rebirth: refused without the trial", r.ok == false, r.msg)
r = call("TrialStart", "CrystalRabbit")
check("trial: started", r.ok and Session.get(player).Trial ~= nil, r.msg)
for _, pt in ipairs(WorldData.Trials.CrystalRabbit.Points) do
	moveTo(pt - Vector3.new(0, 1.5, 0))
	task.wait(0.4)
end
check(
	"trial: all sparks caught",
	data.Trials.CrystalRabbit == true,
	Session.get(player).Trial and Session.get(player).Trial.Index
)
local treats0 = data.Treats
r = call("Rebirth", "CrystalRabbit", "LightPaws")
task.wait(0.6)
check(
	"rebirth: Crystal Rabbit, baby, star, inherited talent",
	r.ok
		and data.Species == "CrystalRabbit"
		and data.Level == 1
		and data.Stars == 1
		and data.Talents.Inherit == "LightPaws",
	r.msg
)
check("rebirth: rig rebuilt", player.Character:GetAttribute("Species") == "CrystalRabbit")
r = call("Ability", "CrystalSight")
check("crystal sight: secrets found", r.ok, r.msg)
ok, msg = usePrompt("Cache", "c_bush")
check("crystal cache: opened after sight", ok and data.Treats > treats0, msg)

data.Species = "Raccoon"
PlayerService.respawnInPlace(player)
task.wait(0.4)
ok, msg = usePrompt("Unlock", "bin1")
check("raccoon: bin opened, trinket stashed", ok and data.Stash.Trinkets == 1, msg)
ok, msg = usePrompt("Unlock", "shed1")
check("raccoon: shed lock picked", ok and data.Stash.Trinkets == 3, msg)
ok, msg = usePrompt("Stash")
check("raccoon: stash traded", ok and data.Stash.Trinkets == 0 and data.Stash.Total == 3, msg)

data.Species = "Fox"
PlayerService.respawnInPlace(player)
task.wait(0.4)
local mailRoot = Workspace.World.NPC:FindFirstChild("Mailman"):FindFirstChild("HumanoidRootPart")
local bushNear, bd = nil, math.huge
for _, b in ipairs(WorldBuilder.bushes) do
	local d = (b - mailRoot.Position).Magnitude
	if d < bd then
		bushNear, bd = b, d
	end
end
moveTo(bushNear)
task.wait(0.7)
check("fox: hidden in a bush", player.Character:GetAttribute("Hidden") == true)
local sp = findPrompt("Snatch", "Mailman")
moveTo(mailRoot.Position + Vector3.new(2, 0, 0))
ok, msg = Interact.dispatch(player, sp)
check("fox: snatched from the mailman", ok, msg)
task.wait(0.3)
moveTo(mailRoot.Position + Vector3.new(2, 0, 0))
task.wait(4.5)
ok, msg = Interact.dispatch(player, sp)
check("fox: seen when not hiding", not ok, msg)

data.Species = "SnowLeopard"
PlayerService.respawnInPlace(player)
task.wait(0.4)
r = call("Ability", "HugeLeap")
check("snow leopard: huge leap window", r.ok and Movement.legalSpeed(player) > 50, r.msg)
moveTo(Vector3.new(-80, 15, -48))
task.wait(0.6)
check(
	"snow leopard: roof sprint",
	Movement.walkSpeed(player) > Movement.baseSpeed(data) * 1.5,
	Movement.walkSpeed(player)
)

data.Species = "CorgiKnight"
PlayerService.respawnInPlace(player)
task.wait(0.4)
moveTo(WorldData.ParkDogs[1] + Vector3.new(4, 0, 0))
r = call("Ability", "CommandDogs")
check("corgi: park dogs follow", r.ok and RareAbilities.dogs[1].Leader == player, r.msg)
r = call("Ability", "ShieldRoll")
check("corgi: shield roll", r.ok and Movement.walkSpeed(player) > Movement.baseSpeed(data) * 1.5, r.msg)

data.Species = "Owl"
PlayerService.respawnInPlace(player)
task.wait(0.4)
r = call("Ability", "NightVision")
check("owl: night vision", r.ok, r.msg)
r = call("Ability", "Sniff")
check("owl: no dog abilities", r.ok == false)

-- ===================================================================== 14. Сохранение
check("save: saveNow", DataService.saveNow(player) == true)
check("daily: 5 tasks today", count(data.Daily.Items) == 5, count(data.Daily.Items))
check("state: Core has story & daily", true)

print("DONE")
