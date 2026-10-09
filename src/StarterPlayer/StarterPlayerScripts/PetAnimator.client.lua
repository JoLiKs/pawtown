--!nonstrict
--[[
	PetAnimator — процедурная анимация всех питомцев и NPC через Motor6D.Transform (без ассетов анимаций):
	  * ходьба (диагональные пары лап у питомцев, руки/ноги у людей), дыхание, виляние хвостом;
	  * попугай машет крыльями в воздухе и расправляет их в планировании;
	  * сон (Sleeping), эмоции (Emote), трюки (Trick), действия (Action: еда, нюх, отряхивание), двойной прыжок;
	  * предмет в зубах (Carrying): газета / игрушка / мяч — у всех клиентов одинаково.
	Атрибуты ставит сервер на модели персонажа, поэтому другие игроки видят эмоции и трюки.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local rigs: { [Model]: any } = {}

local function scan(m: Instance)
	if not m:IsA("Model") or rigs[m] then
		return
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	local joints = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	if not joints.Root then
		return
	end
	rigs[m] = {
		Root = root,
		Hum = hum,
		J = joints,
		Phase = math.random() * 10,
		Human = m:GetAttribute("Human") == true,
		Carry = nil,
		CarryKind = "",
	}
end

local function watch(folder: Instance)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("Humanoid") and d.Parent then
			task.defer(scan, d.Parent)
		end
	end
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("Humanoid") then
			task.delay(0.1, function()
				if d.Parent then
					scan(d.Parent)
				end
			end)
		end
	end)
end
watch(Workspace)

local A = CFrame.Angles
local function parseStamp(v: any): (string?, number, string?)
	-- "Id:clock" или "Id:medal:clock"
	if type(v) ~= "string" then
		return nil, 0, nil
	end
	local parts = string.split(v, ":")
	if #parts == 2 then
		return parts[1], tonumber(parts[2]) or 0, nil
	elseif #parts >= 3 then
		return parts[1], tonumber(parts[3]) or 0, parts[2]
	end
	return nil, 0, nil
end

local CARRY = {
	Newspaper = {
		Size = Vector3.new(0.35, 0.35, 1.3),
		Color = Color3.fromRGB(235, 235, 225),
		Shape = Enum.PartType.Cylinder,
	},
	Toy = {
		Size = Vector3.new(0.7, 0.7, 0.7),
		Color = Color3.fromRGB(240, 110, 170),
		Shape = Enum.PartType.Ball,
	},
	Ball = {
		Size = Vector3.new(0.65, 0.65, 0.65),
		Color = Color3.fromRGB(230, 230, 60),
		Shape = Enum.PartType.Ball,
	},
	Parcel = {
		Size = Vector3.new(0.9, 0.6, 0.7),
		Color = Color3.fromRGB(190, 140, 90),
		Shape = Enum.PartType.Block,
	},
	Glasses = {
		Size = Vector3.new(0.8, 0.25, 0.2),
		Color = Color3.fromRGB(60, 60, 80),
		Shape = Enum.PartType.Block,
	},
}

local function updateCarry(m: Model, r: any)
	local kind = m:GetAttribute("Carrying")
	kind = if type(kind) == "string" then kind else ""
	if kind == r.CarryKind then
		return
	end
	r.CarryKind = kind
	if r.Carry then
		r.Carry:Destroy()
		r.Carry = nil
	end
	local def = CARRY[kind]
	local head = m:FindFirstChild("Head")
	if not def or not head then
		return
	end
	local p = Instance.new("Part")
	p.Name = "CarryItem"
	p.Shape = def.Shape
	p.Size = def.Size
	p.Color = def.Color
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	local off = CFrame.new(0, -0.35, -0.75)
	if def.Shape == Enum.PartType.Cylinder then
		off *= A(0, math.rad(90), 0)
	end
	p.CFrame = head.CFrame * off
	local w = Instance.new("Weld")
	w.Part0 = head
	w.Part1 = p
	w.C0 = off
	w.Parent = p
	p.Parent = m
	r.Carry = p
end

local function setT(j: Motor6D?, cf: CFrame)
	if j then
		j.Transform = cf
	end
end

local function animatePet(m: Model, r: any, t: number)
	local J = r.J
	local v = r.Root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / 12, 0, 1)
	local air = math.abs(v.Y) > 3
	local ph = t * (6 + speed * 0.5) + r.Phase
	local swing = math.sin(ph) * 0.7 * moving
	local rootCF = CFrame.new(0, math.abs(math.sin(ph)) * 0.12 * moving + math.sin(t * 2) * 0.02, 0)
	local neck = A(math.sin(t * 1.7 + r.Phase) * 0.05, math.sin(t * 0.9 + r.Phase) * 0.12, 0)
	-- хвост: спокойное покачивание в покое, быстрее на бегу
	local tail =
		A(math.sin(t * 1.3 + r.Phase) * 0.08, math.sin(t * (2.2 + moving * 5)) * (0.22 + moving * 0.15), 0)
	-- уши: редкое «подёргивание» (раз в ~3 с), у бегущего — прижаты назад
	local tw = (t + r.Phase) % 3.1
	local twitch = if tw < 0.22 then math.sin(tw / 0.22 * math.pi) * 0.45 else 0
	local earL, earR = A(-0.15 * moving, 0, twitch), A(-0.15 * moving, 0, -twitch * 0.4)
	local legs =
		{ LegFL = A(swing, 0, 0), LegBR = A(swing, 0, 0), LegFR = A(-swing, 0, 0), LegBL = A(-swing, 0, 0) }
	local wing = 0
	if air then
		legs = { LegFL = A(0.5, 0, 0), LegFR = A(0.5, 0, 0), LegBL = A(-0.5, 0, 0), LegBR = A(-0.5, 0, 0) }
		wing = math.sin(t * 22) * 0.9
	end
	if m:GetAttribute("Gliding") then
		wing = 1.2
	end
	-- двойной прыжок / взмах: кувырок или взмах крыльев
	local aj = m:GetAttribute("AirJump")
	if type(aj) == "number" and os.clock() - aj < 0.45 then
		local k = (os.clock() - aj) / 0.45
		if J.WingL then
			wing = math.sin(k * math.pi * 4) * 1.2
		else
			rootCF *= A(-k * math.pi * 2, 0, 0)
		end
	end
	-- сон
	if m:GetAttribute("Sleeping") then
		rootCF = CFrame.new(0, -0.45, 0) * A(0, 0, math.rad(80)) * CFrame.new(0, math.sin(t * 1.5) * 0.04, 0)
		legs = { LegFL = A(0.3, 0, 0), LegFR = A(0.3, 0, 0), LegBL = A(-0.3, 0, 0), LegBR = A(-0.3, 0, 0) }
		neck = A(0.25, 0, 0)
		tail = A(0, 0.3, 0)
		wing = 0
		earL, earR = A(0.3, 0, 0), A(0.3, 0, 0)
	end
	-- действие (еда, нюх, отряхивание)
	local act, at = parseStamp(m:GetAttribute("Action"))
	local da = os.clock() - at
	if act and da < 1.6 then
		if act == "Eat" then
			neck = A(0.6 + math.sin(da * 14) * 0.15, 0, 0)
		elseif act == "Sniff" then
			neck = A(0.5, math.sin(da * 10) * 0.3, 0)
		elseif act == "Shake" then
			rootCF *= A(0, 0, math.sin(da * 30) * 0.35 * (1 - da / 1.6))
		elseif act == "Roll" and da < 0.7 then
			-- перекат корги-рыцаря со щитом: кувырок вперёд
			rootCF *= CFrame.new(0, 0.4 * math.sin(da / 0.7 * math.pi), 0) * A(
				-(da / 0.7) * math.pi * 2,
				0,
				0
			)
		end
	end
	-- эмоции
	local emo, et = parseStamp(m:GetAttribute("Emote"))
	local de = os.clock() - et
	if emo and de < 1.6 then
		local k = de / 1.6
		if emo == "Wag" then
			tail = A(0, math.sin(t * 22) * 0.7, 0)
			rootCF *= A(0, math.sin(t * 11) * 0.12, 0)
		elseif emo == "PlayBow" then
			rootCF *= CFrame.new(0, -0.2, 0) * A(-0.35, 0, 0)
			tail = A(0, math.sin(t * 18) * 0.6, 0)
		elseif emo == "Voice" or emo == "Mimic" then
			neck = A(-0.35 + math.sin(de * 18) * 0.12, 0, if emo == "Mimic" then 0.35 else 0)
		elseif emo == "Sniff" then
			neck = A(0.55, math.sin(de * 12) * 0.35, 0)
		elseif emo == "Roll" then
			rootCF *= A(0, 0, k * math.pi * 2)
		end
	end
	-- трюки
	local trick, tt = parseStamp(m:GetAttribute("Trick"))
	local dt = os.clock() - tt
	if trick and dt < 1.8 then
		local k = math.clamp(dt / 1.2, 0, 1)
		if trick == "Sit" then
			rootCF *= CFrame.new(0, -0.25, 0.2) * A(0.45, 0, 0)
			legs.LegBL, legs.LegBR = A(-1.1, 0, 0), A(-1.1, 0, 0)
		elseif trick == "Paw" then
			rootCF *= CFrame.new(0, -0.25, 0.2) * A(0.45, 0, 0)
			legs.LegFR = A(1.4 + math.sin(dt * 12) * 0.2, 0, 0)
		elseif trick == "Roll" then
			rootCF *= A(0, 0, k * math.pi * 2)
		elseif trick == "PlayDead" then
			rootCF = CFrame.new(0, -0.4, 0) * A(0, 0, math.rad(170) * math.min(1, k * 2))
			legs =
				{ LegFL = A(0.2, 0, 0), LegFR = A(0.2, 0, 0), LegBL = A(-0.2, 0, 0), LegBR = A(-0.2, 0, 0) }
		elseif trick == "Spin" then
			rootCF *= A(0, k * math.pi * 4, 0)
		end
	end
	-- лиса в кусте: полупрозрачна (себе — 0.5, другим — почти не видно)
	local hidden = m:GetAttribute("Hidden") == true
	if hidden ~= (r.Hidden == true) then
		r.Hidden = hidden
		local own = m == game:GetService("Players").LocalPlayer.Character
		local ltm = if hidden then (if own then 0.5 else 0.85) else 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = ltm
			end
		end
	end
	setT(J.Root, rootCF)
	setT(J.Neck, neck)
	setT(J.Tail, tail)
	for name, cf in pairs(legs) do
		setT(J[name], cf)
	end
	setT(J.EarL, earL)
	setT(J.EarR, earR)
	setT(J.WingL, A(0, 0, -wing))
	setT(J.WingR, A(0, 0, wing))
end

local function animateHuman(_m: Model, r: any, t: number)
	local J = r.J
	local v = r.Root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / 8, 0, 1)
	local ph = t * 7 + r.Phase
	local s = math.sin(ph) * 0.6 * moving
	local idle = math.sin(t * 1.5 + r.Phase) * 0.04
	setT(J.ArmL, A(s + idle, 0, 0))
	setT(J.ArmR, A(-s - idle, 0, 0))
	setT(J.LegL, A(-s, 0, 0))
	setT(J.LegR, A(s, 0, 0))
	setT(J.Neck, A(0, math.sin(t * 0.6 + r.Phase) * 0.2, 0))
	setT(J.Root, CFrame.new(0, idle * 0.5, 0))
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for m, r in pairs(rigs) do
		if not m.Parent or not r.Root.Parent then
			rigs[m] = nil
		else
			if r.Human then
				animateHuman(m, r, t)
			else
				animatePet(m, r, t)
				updateCarry(m, r)
			end
		end
	end
end)
