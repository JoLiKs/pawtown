--!nonstrict
--[[
	PetRig — процедурный риг питомца-аватара (4 формы: Cat / Dog / Rabbit / Parrot) и NPC-людей.
	Персонаж = Model { HumanoidRootPart (2x2x2, невидимый, единственный с коллизией), Humanoid (RigType R15,
	HipHeight), части тела на Motor6D }. Суставы называются одинаково для всех форм:
	  Root (HRP->Body), Neck (Body->Head), LegFL/LegFR/LegBL/LegBR, Tail, WingL/WingR (попугай).
	Клиент (PetAnimator) анимирует их через Motor6D.Transform — без ассетов анимаций; так же это работает в
	эмуляторе roblox2web. Передняя сторона — -Z (LookVector), координаты деталей — от земли (Y = 0).
	Косметика (ShopData) крепится на Weld к Body/Head: Collar, Neck (бандана), Hat.
]]
local ShopData = require(script.Parent.ShopData)
local SpeciesData = require(script.Parent.SpeciesData)

local PetRig = {}

PetRig.HIP_HEIGHT = 0.35
PetRig.ROOT_SIZE = Vector3.new(2, 2, 2)
-- Высота центра HRP над землёй
PetRig.ROOT_Y = PetRig.HIP_HEIGHT + PetRig.ROOT_SIZE.Y / 2

local PetModels = require(script.Parent.PetModels)

local V = Vector3.new
local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(25, 25, 30)

-- Части формы (масштаб 1) и опорные точки косметики — см. PetModels
function PetRig.shape(speciesId: string)
	local sp = SpeciesData.ById[speciesId] or SpeciesData.ById.Dog
	return PetModels.specs(sp.Id, sp.Look)
end

local function makePart(spec: any, s: number): BasePart
	local part = Instance.new(spec.Class or "Part") :: any
	part.Name = spec.Name
	part.Size = spec.Size * s
	part.Color = spec.Color or WHITE
	part.Material = if spec.Material
		then (Enum.Material :: any)[spec.Material]
		else Enum.Material.SmoothPlastic
	if spec.Reflectance then
		part.Reflectance = spec.Reflectance
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = spec.Size.Magnitude > 0.5
	part.Massless = true
	part.Anchored = false
	if spec.Mesh == "Sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif spec.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	if spec.Name == "Head" then
		part:SetAttribute("NoFace", true) -- эмулятор: не рисовать лицо R6 на голове питомца
	end
	return part
end

-- Мировой CFrame детали (масштаб s): CF задан от точки на земле под HRP
local function partCF(rootCF: CFrame, cf: CFrame, s: number): CFrame
	local p = cf.Position * s - Vector3.new(0, PetRig.ROOT_Y, 0)
	return rootCF * (CFrame.new(p) * cf.Rotation)
end

local function joint(
	kind: string,
	name: string,
	p0: BasePart,
	p1: BasePart,
	pivotWorld: CFrame
): JointInstance
	local j = Instance.new(kind) :: any
	j.Name = name
	j.Part0 = p0
	j.Part1 = p1
	j.C0 = p0.CFrame:Inverse() * pivotWorld
	j.C1 = p1.CFrame:Inverse() * pivotWorld
	j.Parent = p0
	return j
end

local function P(name: string, size: Vector3, pos: Vector3, color: Color3, extra: { [string]: any }?): any
	local sp: any = { Name = name, Size = size, CF = CFrame.new(pos), Color = color }
	if extra then
		for k, v in pairs(extra) do
			sp[k] = v
		end
		if extra.Rot then
			local r = extra.Rot
			sp.CF = CFrame.new(pos) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		end
	end
	return sp
end

-- Косметика: детали относительно опорных точек вида (Neck — шея, Top — макушка, S — масштаб головы)
local function cosmeticParts(item: any, anchors: any): { any }
	local out = {}
	local c1, c2 = item.Color, item.Color2
	local neck, top, k = anchors.Neck, anchors.Top, anchors.S or 1
	local nw = (anchors.NeckW or 1.3) * 0.82
	if item.Slot == "Collar" then
		table.insert(out, P("Collar", V(nw, 0.2, nw * 0.62), neck, c1, { Parent = "Body", Mesh = "Sphere" }))
		table.insert(
			out,
			P(
				"CollarTag",
				V(0.24, 0.24, 0.24),
				neck + V(0, -0.15, -nw * 0.33),
				c2,
				{ Parent = "Body", Shape = "Ball" }
			)
		)
	elseif item.Slot == "Neck" then
		table.insert(
			out,
			P(
				"Bandana",
				V(nw, 0.22, nw * 0.62),
				neck + V(0, 0.02, 0),
				c1,
				{ Parent = "Body", Mesh = "Sphere" }
			)
		)
		table.insert(
			out,
			P(
				"BandanaFront",
				V(0.62, 0.42, 0.1),
				neck + V(0, -0.22, -nw * 0.3),
				c1,
				{ Parent = "Body", Rot = V(-15, 0, 45) }
			)
		)
		table.insert(
			out,
			P("BandanaDot", V(0.14, 0.14, 0.06), neck + V(0, -0.18, -nw * 0.37), c2, { Parent = "Body" })
		)
	elseif item.Slot == "Hat" then
		if item.Id == "hat_party" then
			table.insert(
				out,
				P(
					"HatBase",
					V(0.62, 0.22, 0.62) * k,
					top + V(0, 0.08, 0),
					c1,
					{ Parent = "Head", Mesh = "Sphere" }
				)
			)
			table.insert(
				out,
				P(
					"HatMid",
					V(0.44, 0.34, 0.44) * k,
					top + V(0, 0.3 * k, 0),
					c2,
					{ Parent = "Head", Mesh = "Sphere" }
				)
			)
			table.insert(
				out,
				P(
					"HatTop",
					V(0.24, 0.34, 0.24) * k,
					top + V(0, 0.55 * k, 0),
					c1,
					{ Parent = "Head", Mesh = "Sphere" }
				)
			)
			table.insert(
				out,
				P(
					"HatPom",
					V(0.26, 0.26, 0.26) * k,
					top + V(0, 0.78 * k, 0),
					c2,
					{ Parent = "Head", Shape = "Ball" }
				)
			)
		elseif item.Id == "hat_beanie" then
			table.insert(
				out,
				P(
					"HatBase",
					V(1.0, 0.24, 0.92) * k,
					top + V(0, -0.02, 0),
					c2,
					{ Parent = "Head", Mesh = "Sphere" }
				)
			)
			table.insert(
				out,
				P(
					"HatDome",
					V(0.95, 0.55, 0.85) * k,
					top + V(0, 0.12 * k, 0),
					c1,
					{ Parent = "Head", Mesh = "Sphere" }
				)
			)
			table.insert(
				out,
				P(
					"HatPom",
					V(0.3, 0.3, 0.3) * k,
					top + V(0, 0.45 * k, 0),
					c2,
					{ Parent = "Head", Shape = "Ball" }
				)
			)
		else
			table.insert(
				out,
				P(
					"HatBase",
					V(0.8, 0.26, 0.7) * k,
					top + V(0, 0.06, 0),
					c1,
					{ Parent = "Head", Material = "Neon" }
				)
			)
			for i, x in ipairs({ -0.28, 0, 0.28 }) do
				table.insert(
					out,
					P(
						"HatSpike" .. i,
						V(0.16, 0.28, 0.16) * k,
						top + V(x * k, 0.28 * k, 0),
						c1,
						{ Parent = "Head", Rot = V(0, 45, 0) }
					)
				)
			end
			table.insert(
				out,
				P("HatGem", V(0.16, 0.16, 0.08) * k, top + V(0, 0.08, -0.36 * k), c2, { Parent = "Head" })
			)
		end
	end
	return out
end
PetRig._cosmeticParts = cosmeticParts

export type BuildOpts = { Scale: number?, Cosmetics: { [string]: string }?, Name: string? }

-- Строит модель-персонаж. rootCF — где стоит HRP.
function PetRig.build(speciesId: string, rootCF: CFrame, opts: BuildOpts?): Model
	local o: BuildOpts = opts or {}
	local sp = SpeciesData.ById[speciesId] or SpeciesData.ById.Dog
	local look: { [string]: any } = table.clone(sp.Look :: any)
	local s = o.Scale or 1
	local model = Instance.new("Model")
	model.Name = o.Name or sp.Id
	model:SetAttribute("Species", sp.Id)
	model:SetAttribute("Shape", sp.Look.Shape)
	model:SetAttribute("Scale", s)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = PetRig.ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.CFrame = rootCF
	root.Parent = model

	local specs, anchors = PetModels.specs(sp.Id, look)
	local cos = o.Cosmetics or {}
	for _, slot in ipairs(ShopData.SLOTS) do
		local id = cos[slot]
		local item = id and ShopData.ById[id]
		if item then
			for _, c in ipairs(cosmeticParts(item, anchors)) do
				table.insert(specs, c)
			end
		end
	end
	local parts: { [string]: BasePart } = {}
	for _, spec in ipairs(specs) do
		local part = makePart(spec, s)
		part.CFrame = partCF(rootCF, spec.CF, s)
		parts[spec.Name] = part
	end
	-- суставы: Body к HRP, остальные — к родителю (сначала суставы, потом в модель — без лишних перерасчётов)
	for _, spec in ipairs(specs) do
		local part = parts[spec.Name]
		if spec.Name == "Body" then
			joint("Motor6D", "Root", root, part, part.CFrame)
		else
			local parent = parts[spec.Parent or "Body"] or parts.Body
			if spec.Joint then
				local pv = spec.Pivot or spec.CF.Position
				local pivot = rootCF * CFrame.new(pv * s - Vector3.new(0, PetRig.ROOT_Y, 0))
				joint("Motor6D", spec.Joint, parent, part, pivot)
			else
				joint("Weld", spec.Name .. "Weld", parent, part, part.CFrame)
			end
		end
	end
	for _, spec in ipairs(specs) do
		parts[spec.Name].Parent = model
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = PetRig.HIP_HEIGHT
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

-- Простой NPC-человек (семья, почтальон, смотритель): тот же принцип, суставы Root/Neck/ArmL/ArmR/LegL/LegR
function PetRig.buildHuman(name: string, rootCF: CFrame, colors: { [string]: Color3 }, height: number?): Model
	local h = height or 1
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = rootCF
	root.Parent = model
	-- HRP центр на высоте 3*h над землёй (HipHeight = 3h - 1)
	local base = 3 * h
	local function part(n: string, size: Vector3, pos: Vector3, color: Color3, shape: string?): BasePart
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size * h
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		end
		p.CFrame = rootCF * CFrame.new(pos * h - Vector3.new(0, base, 0))
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(1.8, 2, 1), Vector3.new(0, 3, 0), colors.Shirt)
	local head = part("Head", Vector3.new(1.3, 1.3, 1.2), Vector3.new(0, 4.7, 0), colors.Skin)
	local hair = part("Hair", Vector3.new(1.4, 0.45, 1.3), Vector3.new(0, 5.4, 0.05), colors.Hair)
	local eyeL = part("EyeL", Vector3.new(0.18, 0.22, 0.05), Vector3.new(-0.28, 4.8, -0.61), BLACK)
	local eyeR = part("EyeR", Vector3.new(0.18, 0.22, 0.05), Vector3.new(0.28, 4.8, -0.61), BLACK)
	local smile =
		part("Smile", Vector3.new(0.45, 0.08, 0.05), Vector3.new(0, 4.4, -0.61), Color3.fromRGB(150, 60, 60))
	local armL = part("ArmL", Vector3.new(0.6, 1.9, 0.6), Vector3.new(-1.25, 3.05, 0), colors.Shirt)
	local armR = part("ArmR", Vector3.new(0.6, 1.9, 0.6), Vector3.new(1.25, 3.05, 0), colors.Shirt)
	local legL = part("LegL", Vector3.new(0.8, 2, 0.8), Vector3.new(-0.45, 1, 0), colors.Pants)
	local legR = part("LegR", Vector3.new(0.8, 2, 0.8), Vector3.new(0.45, 1, 0), colors.Pants)
	local function piv(v: Vector3): CFrame
		return rootCF * CFrame.new(v * h - Vector3.new(0, base, 0))
	end
	joint("Motor6D", "Root", root, body, body.CFrame)
	joint("Motor6D", "Neck", body, head, piv(Vector3.new(0, 4, 0)))
	joint("Motor6D", "ArmL", body, armL, piv(Vector3.new(-1.25, 3.9, 0)))
	joint("Motor6D", "ArmR", body, armR, piv(Vector3.new(1.25, 3.9, 0)))
	joint("Motor6D", "LegL", body, legL, piv(Vector3.new(-0.45, 2, 0)))
	joint("Motor6D", "LegR", body, legR, piv(Vector3.new(0.45, 2, 0)))
	for _, p in ipairs({ hair, eyeL, eyeR, smile }) do
		joint("Weld", p.Name .. "Weld", head, p, p.CFrame)
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = base - 1
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.WalkSpeed = 9
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Human", true)
	return model
end

return PetRig
