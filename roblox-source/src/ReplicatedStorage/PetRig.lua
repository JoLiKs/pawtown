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

type PartSpec = {
	Name: string,
	Size: Vector3,
	Pos: Vector3, -- центр, от земли
	Color: string | Color3, -- ключ Look ("Body"/"Accent"/...) или цвет
	Rot: Vector3?, -- градусы (X, Y, Z)
	Shape: string?, -- "Ball" | "Cylinder"
	Parent: string?, -- к какой части крепится (по умолчанию Body)
	Joint: string?, -- имя Motor6D (анимируемый сустав); иначе Weld
	Pivot: Vector3?, -- точка сустава (от земли)
	Material: string?,
}

local function P(
	name: string,
	size: Vector3,
	pos: Vector3,
	color: string | Color3,
	extra: { [string]: any }?
): PartSpec
	local s: any = { Name = name, Size = size, Pos = pos, Color = color }
	if extra then
		for k, v in pairs(extra) do
			s[k] = v
		end
	end
	return s
end
local V = Vector3.new
local BLACK = Color3.fromRGB(25, 25, 30)
local WHITE = Color3.fromRGB(250, 250, 250)

local function quadLegs(
	out: { PartSpec },
	w: number,
	h: number,
	x: number,
	zf: number,
	zb: number,
	bodyBottom: number
)
	for _, leg in ipairs({ { "LegFL", -x, zf }, { "LegFR", x, zf }, { "LegBL", -x, zb }, { "LegBR", x, zb } }) do
		table.insert(
			out,
			P(leg[1], V(w, h, w), V(leg[2], h / 2, leg[3]), "Body", {
				Joint = leg[1],
				Pivot = V(leg[2], bodyBottom, leg[3]),
			})
		)
		-- лапка светлее
		table.insert(
			out,
			P(
				leg[1] .. "Paw",
				V(w + 0.04, 0.22, w + 0.06),
				V(leg[2], 0.11, leg[3] - 0.02),
				"Belly",
				{ Parent = leg[1] }
			)
		)
	end
end

local function face(out: { PartSpec }, hy: number, hz: number, eyeX: number, eyeY: number)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(
			out,
			P(
				"Eye" .. (if sx < 0 then "L" else "R"),
				V(0.26, 0.3, 0.08),
				V(sx * eyeX, hy + eyeY, hz),
				"Eye",
				{ Parent = "Head" }
			)
		)
		table.insert(
			out,
			P(
				"Pupil" .. (if sx < 0 then "L" else "R"),
				V(0.13, 0.17, 0.06),
				V(sx * eyeX, hy + eyeY + 0.02, hz - 0.05),
				BLACK,
				{ Parent = "Head" }
			)
		)
		table.insert(
			out,
			P(
				"Shine" .. (if sx < 0 then "L" else "R"),
				V(0.06, 0.06, 0.04),
				V(sx * eyeX + 0.04, hy + eyeY + 0.08, hz - 0.08),
				WHITE,
				{ Parent = "Head" }
			)
		)
	end
end

-- Детали формы (масштаб 1)
function PetRig.shape(shape: string): { PartSpec }
	local out: { PartSpec } = {}
	if shape == "Cat" or shape == "Dog" then
		local dog = shape == "Dog"
		local legH = if dog then 1.0 else 0.95
		local bodyH = if dog then 1.15 else 1.0
		local bodyY = legH + bodyH / 2 - 0.05
		table.insert(out, P("Body", V(if dog then 1.45 else 1.3, bodyH, 2.5), V(0, bodyY, 0.1), "Body"))
		table.insert(out, P("Belly", V(1.0, 0.2, 1.8), V(0, bodyY - bodyH / 2 + 0.05, 0.1), "Belly"))
		table.insert(out, P("Back", V(0.7, 0.12, 1.6), V(0, bodyY + bodyH / 2, 0.2), "Accent"))
		local hy = bodyY + 0.75
		local hz = -1.25
		table.insert(
			out,
			P(
				"Head",
				V(1.35, 1.15, 1.15),
				V(0, hy, hz),
				"Body",
				{ Joint = "Neck", Pivot = V(0, bodyY + 0.3, -0.95) }
			)
		)
		local front = hz - 0.58
		face(out, hy, front, 0.3, 0.12)
		if dog then
			table.insert(
				out,
				P("Snout", V(0.7, 0.5, 0.55), V(0, hy - 0.22, front - 0.2), "Belly", { Parent = "Head" })
			)
			table.insert(
				out,
				P("Nose", V(0.3, 0.22, 0.12), V(0, hy - 0.08, front - 0.5), "Nose", { Parent = "Head" })
			)
			table.insert(
				out,
				P(
					"Tongue",
					V(0.22, 0.06, 0.25),
					V(0, hy - 0.48, front - 0.35),
					Color3.fromRGB(240, 110, 130),
					{ Parent = "Head" }
				)
			)
			table.insert(
				out,
				P(
					"EarL",
					V(0.25, 0.75, 0.5),
					V(-0.75, hy - 0.05, hz + 0.1),
					"Accent",
					{ Parent = "Head", Rot = V(0, 0, -12) }
				)
			)
			table.insert(
				out,
				P(
					"EarR",
					V(0.25, 0.75, 0.5),
					V(0.75, hy - 0.05, hz + 0.1),
					"Accent",
					{ Parent = "Head", Rot = V(0, 0, 12) }
				)
			)
			table.insert(
				out,
				P(
					"Tail",
					V(0.28, 0.28, 1.0),
					V(0, bodyY + 0.65, 1.65),
					"Body",
					{ Rot = V(40, 0, 0), Joint = "Tail", Pivot = V(0, bodyY + 0.35, 1.3) }
				)
			)
		else
			table.insert(
				out,
				P("Snout", V(0.55, 0.32, 0.18), V(0, hy - 0.2, front - 0.05), "Belly", { Parent = "Head" })
			)
			table.insert(
				out,
				P("Nose", V(0.2, 0.14, 0.1), V(0, hy - 0.08, front - 0.14), "Nose", { Parent = "Head" })
			)
			for _, sx in ipairs({ -1, 1 }) do
				local n = if sx < 0 then "L" else "R"
				table.insert(
					out,
					P(
						"Ear" .. n,
						V(0.42, 0.5, 0.18),
						V(sx * 0.42, hy + 0.72, hz + 0.1),
						"Body",
						{ Parent = "Head", Rot = V(0, 0, sx * -18) }
					)
				)
				table.insert(
					out,
					P(
						"EarIn" .. n,
						V(0.22, 0.3, 0.06),
						V(sx * 0.42, hy + 0.68, hz - 0.0),
						"Nose",
						{ Parent = "Head", Rot = V(0, 0, sx * -18) }
					)
				)
				table.insert(
					out,
					P(
						"Whisker" .. n,
						V(0.5, 0.04, 0.04),
						V(sx * 0.5, hy - 0.18, front - 0.08),
						WHITE,
						{ Parent = "Head", Rot = V(0, 0, sx * 8) }
					)
				)
			end
			table.insert(
				out,
				P(
					"Tail",
					V(0.24, 0.24, 1.7),
					V(0, bodyY + 0.75, 1.85),
					"Accent",
					{ Rot = V(45, 0, 0), Joint = "Tail", Pivot = V(0, bodyY + 0.3, 1.3) }
				)
			)
		end
		quadLegs(out, if dog then 0.42 else 0.36, legH, 0.42, -0.75, 0.95, bodyY - bodyH / 2 + 0.1)
	elseif shape == "Rabbit" then
		local bodyY = 1.15
		table.insert(out, P("Body", V(1.35, 1.25, 1.8), V(0, bodyY, 0.15), "Body"))
		table.insert(out, P("Belly", V(0.95, 0.9, 0.2), V(0, bodyY - 0.1, -0.78), "Belly"))
		local hy, hz = 2.05, -0.75
		table.insert(
			out,
			P("Head", V(1.15, 1.05, 1.05), V(0, hy, hz), "Body", { Joint = "Neck", Pivot = V(0, 1.6, -0.5) })
		)
		local front = hz - 0.53
		face(out, hy, front, 0.28, 0.12)
		table.insert(
			out,
			P("Snout", V(0.5, 0.3, 0.15), V(0, hy - 0.2, front - 0.05), "Belly", { Parent = "Head" })
		)
		table.insert(
			out,
			P("Nose", V(0.18, 0.12, 0.08), V(0, hy - 0.08, front - 0.12), "Nose", { Parent = "Head" })
		)
		table.insert(
			out,
			P("Teeth", V(0.16, 0.12, 0.05), V(0, hy - 0.4, front - 0.1), WHITE, { Parent = "Head" })
		)
		for _, sx in ipairs({ -1, 1 }) do
			local n = if sx < 0 then "L" else "R"
			table.insert(
				out,
				P(
					"Ear" .. n,
					V(0.32, 1.35, 0.16),
					V(sx * 0.28, hy + 1.1, hz + 0.15),
					"Body",
					{ Parent = "Head", Rot = V(-8, 0, sx * -8) }
				)
			)
			table.insert(
				out,
				P(
					"EarIn" .. n,
					V(0.16, 1.0, 0.06),
					V(sx * 0.28, hy + 1.05, hz + 0.05),
					"Nose",
					{ Parent = "Head", Rot = V(-8, 0, sx * -8) }
				)
			)
		end
		table.insert(
			out,
			P(
				"Tail",
				V(0.6, 0.6, 0.6),
				V(0, bodyY + 0.1, 1.1),
				"Belly",
				{ Shape = "Ball", Joint = "Tail", Pivot = V(0, bodyY, 0.95) }
			)
		)
		-- задние лапы крупнее
		for _, leg in ipairs({
			{ "LegFL", -0.35, -0.55, 0.3, 0.55 },
			{ "LegFR", 0.35, -0.55, 0.3, 0.55 },
			{ "LegBL", -0.48, 0.55, 0.45, 0.6 },
			{ "LegBR", 0.48, 0.55, 0.45, 0.6 },
		}) do
			local w, h = leg[4], leg[5]
			table.insert(
				out,
				P(
					leg[1],
					V(w, h, w + 0.15),
					V(leg[2], h / 2, leg[3]),
					"Body",
					{ Joint = leg[1], Pivot = V(leg[2], h, leg[3]) }
				)
			)
		end
	else -- Parrot
		local bodyY = 1.45
		table.insert(out, P("Body", V(1.05, 1.5, 1.05), V(0, bodyY, 0), "Body"))
		table.insert(out, P("Belly", V(0.8, 1.0, 0.15), V(0, bodyY - 0.1, -0.55), "Belly"))
		local hy, hz = 2.55, -0.15
		table.insert(
			out,
			P("Head", V(1.0, 0.95, 0.95), V(0, hy, hz), "Accent", { Joint = "Neck", Pivot = V(0, 2.15, 0) })
		)
		local front = hz - 0.48
		face(out, hy, front, 0.25, 0.08)
		table.insert(
			out,
			P(
				"Beak",
				V(0.34, 0.42, 0.42),
				V(0, hy - 0.2, front - 0.17),
				"Nose",
				{ Parent = "Head", Rot = V(20, 0, 0) }
			)
		)
		table.insert(
			out,
			P(
				"Crest",
				V(0.18, 0.45, 0.4),
				V(0, hy + 0.6, hz + 0.15),
				"Belly",
				{ Parent = "Head", Rot = V(-25, 0, 0) }
			)
		)
		for _, sx in ipairs({ -1, 1 }) do
			local n = if sx < 0 then "L" else "R"
			table.insert(
				out,
				P(
					"Wing" .. n,
					V(0.2, 1.2, 0.85),
					V(sx * 0.62, bodyY + 0.05, 0.1),
					"Body",
					{ Joint = "Wing" .. n, Pivot = V(sx * 0.52, bodyY + 0.6, 0.1) }
				)
			)
			table.insert(
				out,
				P(
					"WingTip" .. n,
					V(0.16, 0.5, 0.6),
					V(sx * 0.64, bodyY - 0.55, 0.2),
					"Accent",
					{ Parent = "Wing" .. n }
				)
			)
		end
		table.insert(
			out,
			P(
				"Tail",
				V(0.5, 0.12, 1.1),
				V(0, bodyY - 0.6, 0.85),
				"Accent",
				{ Rot = V(-35, 0, 0), Joint = "Tail", Pivot = V(0, bodyY - 0.45, 0.45) }
			)
		)
		for _, leg in ipairs({
			{ "LegFL", -0.25, -0.05 },
			{ "LegFR", 0.25, -0.05 },
			{ "LegBL", -0.25, 0.05 },
			{ "LegBR", 0.25, 0.05 },
		}) do
			local front2 = string.sub(leg[1], 4, 4) == "F"
			if front2 then
				table.insert(
					out,
					P(
						leg[1],
						V(0.16, 0.75, 0.16),
						V(leg[2], 0.38, leg[3]),
						Color3.fromRGB(110, 110, 120),
						{ Joint = leg[1], Pivot = V(leg[2], 0.75, leg[3]) }
					)
				)
				table.insert(
					out,
					P(
						leg[1] .. "Foot",
						V(0.3, 0.1, 0.4),
						V(leg[2], 0.05, leg[3] - 0.08),
						Color3.fromRGB(110, 110, 120),
						{ Parent = leg[1] }
					)
				)
			end
		end
	end
	return out
end

local function deg(v: Vector3): CFrame
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

-- Мировой CFrame детали (масштаб s), считая что HRP стоит в rootCF
local function partCF(rootCF: CFrame, spec: PartSpec, s: number): CFrame
	local p = spec.Pos * s - Vector3.new(0, PetRig.ROOT_Y, 0)
	local cf = rootCF * CFrame.new(p)
	if spec.Rot then
		cf = cf * deg(spec.Rot)
	end
	return cf
end

local function makePart(spec: PartSpec, look: { [string]: any }, s: number): BasePart
	local part = Instance.new("Part")
	part.Name = spec.Name
	part.Size = spec.Size * s
	local col = spec.Color
	part.Color = if type(col) == "string" then (look[col] or WHITE) else col
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	if spec.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif spec.Shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
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

-- Косметика: детали в системе Head/Body (от земли, масштаб 1, форма учитывается через якоря)
local function cosmeticParts(item: any, shape: string): { PartSpec }
	local out: { PartSpec } = {}
	local c1, c2 = item.Color, item.Color2
	-- опорные точки шеи и макушки для каждой формы
	local neck = ({
		Cat = V(0, 1.75, -0.85),
		Dog = V(0, 1.85, -0.9),
		Rabbit = V(0, 1.6, -0.45),
		Parrot = V(0, 2.1, -0.1),
	})[shape] or V(0, 1.8, -0.9)
	local top = ({
		Cat = V(0, 2.9, -1.25),
		Dog = V(0, 3.0, -1.25),
		Rabbit = V(0, 2.6, -0.65),
		Parrot = V(0, 3.05, -0.1),
	})[shape] or V(0, 2.9, -1.2)
	if item.Slot == "Collar" then
		table.insert(out, P("Collar", V(1.25, 0.2, 0.75), neck, c1, { Parent = "Body" }))
		table.insert(
			out,
			P(
				"CollarTag",
				V(0.26, 0.26, 0.26),
				neck + V(0, -0.2, -0.4),
				c2,
				{ Parent = "Body", Shape = "Ball" }
			)
		)
	elseif item.Slot == "Neck" then
		table.insert(out, P("Bandana", V(1.2, 0.2, 0.7), neck + V(0, 0.02, 0), c1, { Parent = "Body" }))
		table.insert(
			out,
			P(
				"BandanaFront",
				V(0.7, 0.45, 0.1),
				neck + V(0, -0.25, -0.38),
				c1,
				{ Parent = "Body", Rot = V(-15, 0, 45) }
			)
		)
		table.insert(
			out,
			P("BandanaDot", V(0.14, 0.14, 0.06), neck + V(0, -0.2, -0.45), c2, { Parent = "Body" })
		)
	elseif item.Slot == "Hat" then
		if item.Id == "hat_party" then
			table.insert(out, P("HatBase", V(0.65, 0.2, 0.65), top + V(0, 0.05, 0), c1, { Parent = "Head" }))
			table.insert(out, P("HatMid", V(0.45, 0.3, 0.45), top + V(0, 0.3, 0), c2, { Parent = "Head" }))
			table.insert(out, P("HatTop", V(0.25, 0.3, 0.25), top + V(0, 0.58, 0), c1, { Parent = "Head" }))
			table.insert(
				out,
				P("HatPom", V(0.28, 0.28, 0.28), top + V(0, 0.85, 0), c2, { Parent = "Head", Shape = "Ball" })
			)
		elseif item.Id == "hat_beanie" then
			table.insert(
				out,
				P("HatBase", V(1.05, 0.25, 0.95), top + V(0, -0.05, 0), c2, { Parent = "Head" })
			)
			table.insert(out, P("HatDome", V(0.95, 0.35, 0.85), top + V(0, 0.22, 0), c1, { Parent = "Head" }))
			table.insert(
				out,
				P("HatPom", V(0.32, 0.32, 0.32), top + V(0, 0.5, 0), c2, { Parent = "Head", Shape = "Ball" })
			)
		else
			table.insert(
				out,
				P(
					"HatBase",
					V(0.85, 0.28, 0.75),
					top + V(0, 0.05, 0),
					c1,
					{ Parent = "Head", Material = "Neon" }
				)
			)
			for i, x in ipairs({ -0.3, 0, 0.3 }) do
				table.insert(
					out,
					P(
						"HatSpike" .. i,
						V(0.16, 0.28, 0.16),
						top + V(x, 0.3, 0),
						c1,
						{ Parent = "Head", Rot = V(0, 45, 0) }
					)
				)
			end
			table.insert(
				out,
				P("HatGem", V(0.16, 0.16, 0.08), top + V(0, 0.08, -0.4), c2, { Parent = "Head" })
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

	local specs = PetRig.shape(sp.Look.Shape)
	local cos = o.Cosmetics or {}
	for _, slot in ipairs(ShopData.SLOTS) do
		local id = cos[slot]
		local item = id and ShopData.ById[id]
		if item then
			for _, c in ipairs(cosmeticParts(item, sp.Look.Shape)) do
				table.insert(specs, c)
			end
		end
	end
	local parts: { [string]: BasePart } = {}
	for _, spec in ipairs(specs) do
		local part = makePart(spec, look, s)
		if spec.Material == "Neon" then
			part.Material = Enum.Material.Neon
		end
		part.CFrame = partCF(rootCF, spec, s)
		part.Parent = model
		parts[spec.Name] = part
	end
	-- суставы: Body к HRP, остальные — к родителю
	for _, spec in ipairs(specs) do
		local part = parts[spec.Name]
		if spec.Name == "Body" then
			joint("Motor6D", "Root", root, part, part.CFrame)
		else
			local parent = parts[spec.Parent or "Body"] or parts.Body
			if spec.Joint then
				local pivot = rootCF
					* CFrame.new((spec.Pivot or spec.Pos) * s - Vector3.new(0, PetRig.ROOT_Y, 0))
				joint("Motor6D", spec.Joint, parent, part, pivot)
			else
				joint("Weld", spec.Name .. "Weld", parent, part, part.CFrame)
			end
		end
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
