--!nonstrict
--[[
	WorldFx — клиентские эффекты мира:
	  * крыша дома/приюта прозрачна, когда питомец внутри;
	  * собранные осколки памяти скрыты (у каждого игрока свои);
	  * подсказки (ProximityPrompt) с атрибутом Species показываются только виду с этой способностью;
	    пьедестал выбора вида — только пока вид не выбран;
	  * маячок цели текущего шага главы (светящийся шар над целью);
	  * подсветка находок «Нюха» (собака) и «Хрустального зрения» (сквозь стены: Highlight AlwaysOnTop);
	  * искры испытания «Ночи Искр» видны только своему игроку; тайники-кристаллы — только после зрения;
	  * ночное зрение совы: несобранные осколки рядом подсвечены.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local ClientState = require(script.Parent.ClientState)

local WorldFx = {}
local player = Players.LocalPlayer

local function rootPos(): Vector3?
	local ch = player.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r and r.Position
end

local function makeGlow(name: string, color: Color3, size: number): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 0.15
	return p
end

-- Куда ведёт маячок для шага главы
function WorldFx.targetFor(stepId: string, core: any): Vector3?
	local H = WorldData.Home
	if stepId == "c1_species" then
		return WorldData.SPAWN_SHELTER + Vector3.new(0, 0, -6)
	elseif stepId == "c1_home" then
		return Vector3.new(0, 0, -28)
	elseif stepId == "c1_eat" then
		return H.FoodBowl
	elseif stepId == "c1_trick" then
		return H.TrickMat
	elseif stepId == "c1_family" then
		local fam = Workspace:FindFirstChild("NPC")
		local pos = rootPos()
		local best, bestD = nil, math.huge
		for _, id in ipairs({ "Dad", "Grandma", "Kid" }) do
			local m = fam and fam:FindFirstChild(id)
			local r = m and m:FindFirstChild("HumanoidRootPart")
			if r and pos then
				local d = (r.Position - pos).Magnitude
				if d < bestD then
					best, bestD = r.Position, d
				end
			end
		end
		return best
	elseif stepId == "c1_shards" then
		local have = {}
		for _, id in ipairs(core.Shards or {}) do
			have[id] = true
		end
		local pos = rootPos() or Vector3.zero
		local best, bestD = nil, math.huge
		for _, sh in ipairs(WorldData.Shards) do
			if not have[sh.Id] and (sh.Access == "Any" or sh.Access == core.Species) then
				local d = (sh.Pos - pos).Magnitude
				if d < bestD then
					best, bestD = sh.Pos, d
				end
			end
		end
		return best
	elseif stepId == "c1_dream" then
		return H.PetBed
	end
	return nil
end

function WorldFx.init()
	local roofs = {}
	local prompts = {}
	local shards = {}
	local sparks = {}
	local caches = {}
	local function scan(d: Instance)
		if d:IsA("BasePart") and d:GetAttribute("TrialSpark") then
			table.insert(sparks, d)
		elseif d:IsA("BasePart") and d:GetAttribute("Secret") then
			table.insert(caches, d)
		elseif d:IsA("BasePart") and d:GetAttribute("HomeRoof") then
			table.insert(roofs, d)
		elseif d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		elseif d:IsA("BasePart") and d:GetAttribute("ShardId") then
			table.insert(shards, d)
		end
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		scan(d)
	end
	Workspace.DescendantAdded:Connect(scan)

	local beacon = makeGlow("QuestBeacon", Color3.fromRGB(255, 220, 90), 1.6)
	local ring = makeGlow("QuestBeaconRing", Color3.fromRGB(255, 220, 90), 0.6)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 5, 5)
	ring.Transparency = 0.55
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = Workspace

	local function apply()
		local core = ClientState.Core
		if not core then
			return
		end
		local pos = rootPos()
		-- крыши
		local zone = if pos then WorldData.zoneAt(pos) else nil
		local inside = (zone == "Home" or zone == "Shelter") and pos ~= nil and pos.Y < 11
		for _, r in ipairs(roofs) do
			if r.Parent then
				local near = inside
					and pos
					and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
						< 45
				local t = if near then 0.88 else 0
				if r.Transparency ~= t then
					r.Transparency = t
				end
			end
		end
		-- осколки
		local have = {}
		for _, id in ipairs(core.Shards or {}) do
			have[id] = true
		end
		for _, s in ipairs(shards) do
			if s.Parent then
				local got = have[s:GetAttribute("ShardId")] == true
				s.Transparency = if got then 1 else 0.1
				for _, c in ipairs(s:GetDescendants()) do
					if c:IsA("ProximityPrompt") then
						c.Enabled = not got
					end
				end
			end
		end
		-- подсказки по виду
		for _, p in ipairs(prompts) do
			if p.Parent then
				local need = p:GetAttribute("Species")
				local action = p:GetAttribute("Action")
				local on = true
				if type(need) == "string" and need ~= "" then
					on = SpeciesData.has(core.Species, need)
				end
				if action == "Species" then
					on = core.Species == ""
				elseif core.Species == "" and action ~= "Species" then
					on = false
				end
				if action == "Shard" and p.Parent and have[p.Parent:GetAttribute("ShardId")] then
					on = false
				end
				if p.Enabled ~= on then
					p.Enabled = on
				end
			end
		end
		-- искры испытаний: только свои
		for i = #sparks, 1, -1 do
			local sp = sparks[i]
			if not sp.Parent then
				table.remove(sparks, i)
			else
				local mine = sp:GetAttribute("Owner") == player.UserId
				sp.LocalTransparencyModifier = if mine then 0 else 1
			end
		end
		-- тайники: видны только хрустальному кролику во время зрения
		local seeing = os.clock() < WorldFx.sightUntil
		for _, c in ipairs(caches) do
			if c.Parent then
				c.LocalTransparencyModifier = if seeing then 0 else 1
			end
		end
		-- ночное зрение: подсветка несобранных осколков рядом
		local ch = player.Character
		local nv = ch ~= nil and ch:GetAttribute("NightVision") == true
		for _, sh in ipairs(shards) do
			if sh.Parent then
				local hl = sh:FindFirstChild("NightGlow")
				local want = nv
					and not have[sh:GetAttribute("ShardId")]
					and pos ~= nil
					and (sh.Position - pos).Magnitude < 90
				if want and not hl then
					local h = Instance.new("Highlight")
					h.Name = "NightGlow"
					h.FillColor = Color3.fromRGB(190, 255, 200)
					h.OutlineColor = Color3.fromRGB(255, 255, 255)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = sh
				elseif not want and hl then
					hl:Destroy()
				end
			end
		end
		-- маячок: испытание важнее шага главы
		local story = core.Story or {}
		local trial = core.Rebirth and core.Rebirth.Trial
		local target = if trial and typeof(trial.Pos) == "Vector3"
			then trial.Pos
			elseif story.Id and story.Id ~= "" then WorldFx.targetFor(story.Id, core)
			else nil
		if target and pos and (target - pos).Magnitude > 7 then
			local y = target.Y + 6 + math.sin(os.clock() * 3) * 0.5
			beacon.CFrame = CFrame.new(target.X, y, target.Z)
			ring.CFrame = CFrame.new(target.X, target.Y + 0.6, target.Z) * CFrame.Angles(0, 0, math.rad(90))
			beacon.Parent = fxFolder
			ring.Parent = fxFolder
		else
			beacon.Parent = nil
			ring.Parent = nil
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			apply()
		end
	end)
end

WorldFx.sightUntil = 0

-- «Хрустальное зрение»: секреты сквозь стены (Highlight AlwaysOnTop) + столбы света на SIGHT_TIME секунд
function WorldFx.crystalSight(list: any)
	local folder = Workspace:FindFirstChild("ClientFx")
	if type(list) ~= "table" or not folder then
		return
	end
	local dur = 10
	WorldFx.sightUntil = os.clock() + dur
	local world = Workspace:FindFirstChild("World")
	for _, f in ipairs(list) do
		if typeof(f.Pos) == "Vector3" then
			local color = if f.Kind == "Shard"
				then Color3.fromRGB(170, 140, 255)
				elseif f.Kind == "Cache" then Color3.fromRGB(140, 230, 255)
				else Color3.fromRGB(230, 170, 90)
			local p = makeGlow("SightMark", color, 1)
			p.Shape = Enum.PartType.Block
			p.Size = Vector3.new(0.6, 18, 0.6)
			p.Transparency = 0.4
			p.CFrame = CFrame.new(f.Pos + Vector3.new(0, 9, 0))
			p.Parent = folder
			local target: Instance? = nil
			if world and f.Kind == "Shard" then
				local sf = world:FindFirstChild("Shards")
				target = sf and sf:FindFirstChild(f.Id)
			elseif world and f.Kind == "Cache" then
				local cf = world:FindFirstChild("SecretCaches")
				target = cf and cf:FindFirstChild(f.Id)
			end
			local hl = Instance.new("Highlight")
			hl.Name = "CrystalSight"
			hl.FillColor = color
			hl.FillTransparency = 0.3
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = target or p
			hl.Parent = folder
			task.delay(dur, function()
				p:Destroy()
				hl:Destroy()
			end)
		end
	end
end

-- Подсветка находок «Нюха»: столб света над каждой находкой на 8 секунд
function WorldFx.sniff(list: any)
	local folder = Workspace:FindFirstChild("ClientFx")
	if type(list) ~= "table" or not folder then
		return
	end
	for _, f in ipairs(list) do
		if typeof(f.Pos) == "Vector3" then
			local p = makeGlow(
				"SniffMark",
				if f.Kind == "Shard" then Color3.fromRGB(150, 200, 255) else Color3.fromRGB(230, 170, 90),
				1
			)
			p.Shape = Enum.PartType.Block
			p.Size = Vector3.new(0.8, 14, 0.8)
			p.Transparency = 0.45
			p.CFrame = CFrame.new(f.Pos + Vector3.new(0, 7, 0))
			p.Parent = folder
			task.delay(8, function()
				p:Destroy()
			end)
		end
	end
end

return WorldFx
