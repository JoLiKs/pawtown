--!strict
--[[
	FamilyService — NPC-семья (папа, бабушка, Мия), смотритель приюта Нина и почтальон.
	  * подсказка «Поздороваться» у каждого члена семьи: ласка (Love + Bond, кулдаун), передача того, что питомец
	    несёт (газета — папе, игрушка/мяч — Мие), «разбудить» спящего папу (ежедневное задание);
	  * подарки на порогах привязанности (FamilyData.Gifts, один раз);
	  * реплики-пузыри над головой (Locale.setWorld — каждый видит на своём языке);
	  * почтальон ходит по тротуару (Humanoid:MoveTo).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local FamilyData = require(Shared.FamilyData)
local Locale = require(Shared.Locale)
local PetRig = require(Shared.PetRig)
local Remotes = require(Shared.Remotes)
local ShopData = require(Shared.ShopData)
local WorldData = require(Shared.WorldData)

local DataService = require(script.Parent.DataService)
local DayNightService = require(script.Parent.DayNightService)
local Interact = require(script.Parent.Interact)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local FamilyService = {}

local c3 = Color3.fromRGB
local LOOKS = {
	Dad = { Shirt = c3(70, 120, 200), Pants = c3(60, 60, 80), Skin = c3(240, 200, 170), Hair = c3(90, 60, 40), H = 1.05 },
	Grandma = { Shirt = c3(200, 110, 160), Pants = c3(120, 90, 140), Skin = c3(245, 210, 185), Hair = c3(225, 225, 230), H = 0.95 },
	Kid = { Shirt = c3(250, 190, 70), Pants = c3(80, 150, 220), Skin = c3(240, 205, 175), Hair = c3(140, 80, 40), H = 0.7 },
	Keeper = { Shirt = c3(90, 180, 140), Pants = c3(70, 90, 110), Skin = c3(235, 195, 160), Hair = c3(60, 40, 30), H = 1 },
	Mailman = { Shirt = c3(60, 90, 170), Pants = c3(40, 50, 90), Skin = c3(220, 180, 150), Hair = c3(40, 30, 25), H = 1.05 },
}

local npcs: { [string]: Model } = {}
FamilyService.npcs = npcs
local dadWokeAt = -1e9

local function bubble(m: Model): TextLabel?
	local head = m:FindFirstChild("Head")
	local g = head and head:FindFirstChild("Speech")
	return g and g:FindFirstChild("Text") :: TextLabel?
end

function FamilyService.say(id: string, key: string, args: { [string]: any }?)
	local m = npcs[id]
	local label = m and bubble(m)
	if not label then
		return
	end
	Locale.setWorld(label, key, args)
	local g = label.Parent :: BillboardGui
	g.Enabled = true
	local token = os.clock()
	g:SetAttribute("Token", token)
	task.delay(4, function()
		if g:GetAttribute("Token") == token then
			g.Enabled = false
		end
	end)
end

local function makeNpc(id: string, pos: Vector3, yaw: number, anchored: boolean): Model
	local look = LOOKS[id]
	local h = look.H
	local cf = CFrame.new(pos + Vector3.new(0, 3 * h, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	local m = PetRig.buildHuman(id, cf, look :: any, h)
	m:SetAttribute("NpcId", id)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored and d.Name == "HumanoidRootPart"
		end
	end
	local head = m:FindFirstChild("Head") :: BasePart
	-- имя
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 26)
	tag.StudsOffset = Vector3.new(0, 1.6 * h + 0.6, 0)
	tag.MaxDistance = 50
	tag.LightInfluence = 0
	tag:SetAttribute("LabelKind", "Npc")
	local name = Instance.new("TextLabel")
	name.Name = "Text"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 1)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	Locale.setWorld(name, "npc." .. id)
	name.Parent = tag
	tag.Parent = head
	-- пузырь реплики
	local sp = Instance.new("BillboardGui")
	sp.Name = "Speech"
	sp.Size = UDim2.fromOffset(220, 46)
	sp.StudsOffset = Vector3.new(0, 1.6 * h + 2.4, 0)
	sp.MaxDistance = 60
	sp.LightInfluence = 0
	sp.Enabled = false
	local bg = Instance.new("TextLabel")
	bg.Name = "Text"
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BackgroundTransparency = 0.05
	bg.Size = UDim2.fromScale(1, 1)
	bg.Font = Enum.Font.GothamBold
	bg.TextScaled = true
	bg.TextWrapped = true
	bg.TextColor3 = c3(40, 40, 60)
	bg.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bg
	bg.Parent = sp
	sp.Parent = head
	m.Parent = WorldBuilder.folder("NPC")
	npcs[id] = m
	return m
end

function FamilyService.dadAsleep(): boolean
	local c = DayNightService.clock()
	local window = c >= 21 or c < 10
	return window and os.clock() - dadWokeAt > Config.DAY_LENGTH / 2
end

local function placeDad()
	local m = npcs.Dad
	if not m then
		return
	end
	local asleep = FamilyService.dadAsleep()
	if m:GetAttribute("Asleep") == asleep then
		return
	end
	m:SetAttribute("Asleep", asleep)
	if asleep then
		m:PivotTo(CFrame.new(WorldData.Family.DadAsleep) * CFrame.Angles(math.rad(-90), 0, 0))
		FamilyService.say("Dad", "speech.zzz")
	else
		m:PivotTo(CFrame.new(WorldData.Family.Dad + Vector3.new(0, 3.15, 0)) * CFrame.Angles(0, math.rad(200), 0))
	end
end

-- Подарки на порогах привязанности
local function checkGifts(player: Player, member: string)
	local data = DataService.get(player)
	local def = FamilyData.ById[member]
	if not data or not def then
		return
	end
	for _, g in ipairs(def.Gifts) do
		local key = member .. ":" .. g.At
		if data.Bond[member] >= g.At and not data.Gifts[key] then
			data.Gifts[key] = true
			if g.Treats then
				Progress.treats(player, g.Treats)
			end
			if g.Item and ShopData.ById[g.Item] then
				data.Cosmetics.Owned[g.Item] = true
			end
			Remotes.getEvent("Fx"):FireClient(player, "Gift", member, g.Item or "", g.Treats or 0)
			if g.Item then
				Notify.send(player, Locale.m("toast.gift_item", { who = "npc." .. member, item = ShopData.ById[g.Item].Name }), "reward")
			else
				Notify.send(player, Locale.m("toast.gift_treats", { who = "npc." .. member, n = g.Treats or 0 }), "reward")
			end
			State.markCore(player)
		end
	end
end
FamilyService.checkGifts = checkGifts

function FamilyService.bond(player: Player, member: string, amount: number)
	Progress.bond(player, member, amount)
	checkGifts(player, member)
end

-- Хук ParkService: «отдать мяч Мие» завершает домашний апорт
FamilyService.onBallToKid = nil :: ((Player) -> boolean)?

local function interactFamily(player: Player, member: string): (boolean, any)
	local s = Session.get(player)
	local data = DataService.get(player)
	if not s or not data or not FamilyData.ById[member] then
		return false, nil
	end
	-- 1) разбудить папу
	if member == "Dad" and FamilyService.dadAsleep() then
		dadWokeAt = os.clock()
		placeDad()
		FamilyService.say("Dad", "speech.dad_wake")
		NeedsService.add(player, "Love", 6)
		FamilyService.bond(player, "Dad", 2)
		QuestService.event(player, "wake")
		return true, "msg.woke_dad"
	end
	-- 2) передать то, что во рту
	if s.Carrying == "Newspaper" and member == "Dad" then
		s.Carrying = nil
		FamilyService.say("Dad", "speech.dad_paper")
		FamilyService.bond(player, "Dad", 5)
		NeedsService.add(player, "Love", 12)
		QuestService.event(player, "newspaper")
		State.markCore(player)
		return true, nil
	end
	if s.Carrying == "Toy" and member == "Kid" then
		s.Carrying = nil
		FamilyService.say("Kid", "speech.kid_toy")
		FamilyService.bond(player, "Kid", 6)
		NeedsService.add(player, "Love", 12)
		Progress.treats(player, 5)
		QuestService.event(player, "lost_toy")
		State.markCore(player)
		return true, nil
	end
	if s.Carrying == "Ball" and member == "Kid" and FamilyService.onBallToKid then
		if FamilyService.onBallToKid(player) then
			FamilyService.say("Kid", "speech.kid_fetch")
			return true, nil
		end
	end
	-- 3) ласка
	if not Session.cooldown(player, "cuddle:" .. member, Config.CUDDLE_COOLDOWN) then
		FamilyService.say(member, "speech." .. member .. ".busy")
		return false, Locale.m("msg.cuddle_wait", { who = "npc." .. member })
	end
	NeedsService.add(player, "Love", 20)
	NeedsService.add(player, "Fun", 4)
	FamilyService.bond(player, member, 3)
	Progress.xp(player, 10)
	local def = FamilyData.ById[member]
	FamilyService.say(member, "speech." .. member .. "." .. math.random(1, def.Lines))
	Remotes.getEvent("Fx"):FireClient(player, "Need", "Love")
	QuestService.event(player, "cuddle", member)
	local ch = player.Character
	if ch then
		ch:SetAttribute("Action", "Cuddle:" .. os.clock())
	end
	return true, nil
end

-- Ближайший член семьи в радиусе (для бонуса привязанности за трюки рядом)
function FamilyService.nearestMember(pos: Vector3, radius: number): string?
	local best, bestD = nil, radius
	for _, def in ipairs(FamilyData.List) do
		local m = npcs[def.Id]
		local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestD then
				best, bestD = def.Id, d
			end
		end
	end
	return best
end

function FamilyService.mailmanPos(): Vector3?
	local m = npcs.Mailman
	local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function patrol()
	local m = npcs.Mailman
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	if not m or not hum then
		return
	end
	local route = WorldData.MailmanRoute
	local i = 1
	while m.Parent do
		local target = route[i]
		hum:MoveTo(target)
		local t0 = os.clock()
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
		while m.Parent and os.clock() - t0 < 30 do
			task.wait(0.5)
			local p = root.Position
			if Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude < 2.5 then
				break
			end
			hum:MoveTo(target)
		end
		if target == WorldData.Home.Mailbox + Vector3.new(0, 0, 6) or i == 4 then
			FamilyService.say("Mailman", "speech.mail")
			task.wait(2)
		end
		i = i % #route + 1
	end
end

function FamilyService.init()
	local F = WorldData.Family
	makeNpc("Dad", F.Dad, 200, true)
	makeNpc("Grandma", F.Grandma, 160, true)
	makeNpc("Kid", F.Kid, 150, true)
	makeNpc("Keeper", F.Keeper, 160, true)
	local mail = makeNpc("Mailman", WorldData.MailmanRoute[1], 90, false)
	-- сумка почтальона
	local body = mail:FindFirstChild("Body") :: BasePart
	local bag = WorldBuilder.part(mail, "Bag", Vector3.new(1.2, 1.4, 0.6), body.CFrame * CFrame.new(1.1, -0.4, 0.4), c3(150, 100, 60), { Anchored = false, CanCollide = false, Massless = true })
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = bag
	w.C0 = body.CFrame:Inverse() * bag.CFrame
	w.Parent = body
	for _, def in ipairs(FamilyData.List) do
		local m = npcs[def.Id]
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
		Interact.prompt(root, "Family", "prompt.family", { Arg = def.Id, Object = "npc." .. def.Id, Distance = 10 })
	end
	local keeperRoot = npcs.Keeper:FindFirstChild("HumanoidRootPart") :: BasePart
	Interact.prompt(keeperRoot, "Species", "prompt.keeper", { Object = "npc.Keeper", Distance = 12 })
	local mailRoot = mail:FindFirstChild("HumanoidRootPart") :: BasePart
	Interact.prompt(mailRoot, "Mailman", "prompt.mailman", { Object = "npc.Mailman", Distance = 12 })

	Interact.register("Family", function(player, _prompt, arg)
		return interactFamily(player, arg or "")
	end)
	Interact.register("Mailman", function(player)
		if not Session.cooldown(player, "mailman", 10) then
			return false, nil
		end
		FamilyService.say("Mailman", "speech.mail_hi")
		QuestService.event(player, "greet_mailman")
		NeedsService.add(player, "Fun", 3)
		return true, nil
	end)
	-- бабушка комментирует сон, Мия — трюки
	table.insert(NeedsService.sleepEndHooks, function(_player)
		FamilyService.say("Grandma", "speech.grandma_sleep")
	end)

	task.spawn(patrol)
	task.spawn(function()
		while true do
			placeDad()
			task.wait(2)
		end
	end)
end

return FamilyService
