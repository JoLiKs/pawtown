--!strict
--[[
	WorldBuilder — процедурный мир Pawtown (без ассетов): улица Кленовая, дом семьи с комнатами, соседские дома
	с крышами (для котов), тайный сад за забором (лаз для кроликов), приют «Тёплый нос», парк «Одуванчик»
	(аджилити-трасса, апорт, ямки для собак, пруд), остров сна. Мультяшно и экономно (~1000 деталей).
	Все интерактивные объекты — ProximityPrompt через Interact.prompt; тексты мира — Locale.setWorld.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local PetRig = require(Shared.PetRig)
local WorldData = require(Shared.WorldData)

local Interact = require(script.Parent.Interact)

local WorldBuilder = {}

local c3 = Color3.fromRGB
local V = Vector3.new
local COL = {
	Grass = c3(120, 200, 95),
	GrassDark = c3(95, 175, 80),
	Road = c3(85, 88, 98),
	Line = c3(250, 235, 150),
	Walk = c3(205, 200, 190),
	Curb = c3(170, 165, 160),
	Wood = c3(170, 115, 70),
	WoodLight = c3(215, 170, 115),
	Fence = c3(245, 240, 230),
	Window = c3(170, 220, 250),
	Floor = c3(225, 190, 140),
	Tile = c3(230, 240, 245),
	White = c3(250, 250, 250),
	Red = c3(225, 80, 75),
	Dark = c3(60, 60, 70),
	Water = c3(90, 170, 235),
	Neon = c3(190, 140, 255),
}

local world: Folder

type Props = { [string]: any }
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3 | CFrame,
	color: Color3,
	extra: Props?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if typeof(pos) == "CFrame" then
		p.CFrame = pos
	else
		p.Position = pos
	end
	if extra then
		for k, v in pairs(extra) do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end
WorldBuilder.part = part

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Табличка-билборд с локализуемым текстом
local function sign(parent: Instance, pos: Vector3, key: string, color: Color3?, size: number?): BillboardGui
	local anchor = part(
		parent,
		"SignAnchor",
		V(0.2, 0.2, 0.2),
		pos,
		COL.White,
		{ Transparency = 1, CanCollide = false, CanQuery = false }
	)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = UDim2.fromOffset(size or 200, 44)
	g.AlwaysOnTop = false
	g.MaxDistance = 140
	g.LightInfluence = 0
	g:SetAttribute("LabelKind", "Place")
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or COL.White
	t.TextStrokeTransparency = 0.35
	t.TextStrokeColor3 = c3(40, 30, 50)
	Locale.setWorld(t, key)
	t.Parent = g
	g.Parent = anchor
	return g
end
WorldBuilder.sign = sign

-- Стена вдоль оси X (z фикс.) или Z (x фикс.) с проёмами { {центр, ширина, высота?} }
local function wall(
	parent: Instance,
	axis: string,
	fixed: number,
	from: number,
	to: number,
	y0: number,
	h: number,
	thick: number,
	color: Color3,
	doors: { { number } }?
)
	local cuts = {}
	for _, d in ipairs((doors or {}) :: { { number } }) do
		table.insert(cuts, { d[1] - d[2] / 2, d[1] + d[2] / 2, d[3] or 7 })
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local pos = from
	local function seg(a: number, b: number, ya: number, hh: number)
		if b - a < 0.05 or hh < 0.05 then
			return
		end
		local mid = (a + b) / 2
		if axis == "X" then
			part(parent, "Wall", V(b - a, hh, thick), V(mid, ya + hh / 2, fixed), color)
		else
			part(parent, "Wall", V(thick, hh, b - a), V(fixed, ya + hh / 2, mid), color)
		end
	end
	for _, c in ipairs(cuts) do
		seg(pos, c[1], y0, h)
		seg(c[1], c[2], y0 + c[3], h - c[3]) -- над проёмом
		pos = c[2]
	end
	seg(pos, to, y0, h)
end

local function window(parent: Instance, pos: Vector3, axis: string, w: number)
	local size = if axis == "X" then V(w, 2.6, 0.3) else V(0.3, 2.6, w)
	part(
		parent,
		"Window",
		size,
		pos,
		COL.Window,
		{ Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false }
	)
	local frame = if axis == "X" then V(w + 0.6, 0.3, 0.4) else V(0.4, 0.3, w + 0.6)
	part(parent, "WindowSill", frame, pos - V(0, 1.4, 0), COL.White, { CanCollide = false })
end

local function tree(parent: Instance, pos: Vector3, h: number, r: number, color: Color3?)
	local m = model(parent, "Tree")
	part(m, "Trunk", V(1.4, h, 1.4), pos + V(0, h / 2, 0), c3(130, 90, 60), { Material = Enum.Material.Wood })
	part(
		m,
		"Leaves",
		V(r, r, r),
		pos + V(0, h + r * 0.3, 0),
		color or c3(90, 175, 80),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass }
	)
	part(
		m,
		"Leaves2",
		V(r * 0.7, r * 0.7, r * 0.7),
		pos + V(r * 0.3, h + r * 0.7, -r * 0.1),
		color or c3(110, 190, 90),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass }
	)
	return m
end

local function bush(parent: Instance, pos: Vector3, s: number)
	part(
		parent,
		"Bush",
		V(s, s, s),
		pos + V(0, s * 0.35, 0),
		c3(85, 165, 75),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass }
	)
end

local function flower(parent: Instance, pos: Vector3, color: Color3)
	part(
		parent,
		"Stem",
		V(0.15, 0.9, 0.15),
		pos + V(0, 0.45, 0),
		c3(70, 150, 60),
		{ CanCollide = false, CanQuery = false }
	)
	part(
		parent,
		"Bloom",
		V(0.6, 0.6, 0.6),
		pos + V(0, 1.0, 0),
		color,
		{ Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false }
	)
end

-- Забор вдоль линии: столбики + 2 перекладины; gaps — { центр } проёмы-лазы снизу (только для кроликов)
local function fence(
	parent: Instance,
	axis: string,
	fixed: number,
	from: number,
	to: number,
	h: number,
	gaps: { number }?
)
	local m = model(parent, "Fence")
	local len = to - from
	local mid = (from + to) / 2
	-- сплошная стенка-доски (коллизия), с лазами: под лазом — дыра 0..2 (закрыта невидимым барьером для всех)
	local boards = if axis == "X" then V(len, h, 0.4) else V(0.4, h, len)
	local c = if axis == "X" then V(mid, h / 2, fixed) else V(fixed, h / 2, mid)
	part(m, "Boards", boards, c, COL.Fence)
	for x = from, to, 4 do
		local p = if axis == "X" then V(x, h / 2 + 0.3, fixed) else V(fixed, h / 2 + 0.3, x)
		part(m, "Post", V(0.8, h + 0.6, 0.8), p, c3(225, 220, 210))
	end
	for _, g in ipairs(gaps or {}) do
		local p = if axis == "X" then V(g, 0.9, fixed) else V(fixed, 0.9, g)
		local hole = part(
			m,
			"BurrowHole",
			if axis == "X" then V(2.4, 1.8, 0.5) else V(0.5, 1.8, 2.4),
			p,
			c3(70, 50, 40),
			{ CanCollide = false }
		)
		hole:SetAttribute("BurrowHole", true)
	end
	return m
end

-- ---------------------------------------------------------------------------------------------
local function buildGround()
	local g = folder(world, "Ground")
	local S = WorldData.GROUND_SIZE
	part(g, "Grass", V(S, 2, S), V(0, -1, 0), COL.Grass, { Material = Enum.Material.Grass })
	-- дорога и тротуары
	part(g, "Road", V(440, 0.2, 22), V(0, 0.1, 0), COL.Road, { Material = Enum.Material.Asphalt })
	for x = -210, 210, 12 do
		part(g, "Line", V(6, 0.05, 0.6), V(x, 0.22, 0), COL.Line, { CanCollide = false })
	end
	for _, z in ipairs({ -14, 14 }) do
		part(g, "Sidewalk", V(440, 0.5, 6), V(0, 0.25, z), COL.Walk, { Material = Enum.Material.Concrete })
	end
	-- дорожки к дому, приюту и парку
	part(g, "PathHome", V(6, 0.3, 13), V(0, 0.15, -23.5), COL.Walk, { Material = Enum.Material.Concrete })
	part(g, "PathShelter", V(6, 0.3, 14), V(-130, 0.15, 24), COL.Walk, { Material = Enum.Material.Concrete })
	part(g, "PathPark", V(10, 0.3, 30), V(45, 0.15, 30), COL.Walk, { Material = Enum.Material.Concrete })
	-- фонари вдоль улицы
	for x = -200, 200, 40 do
		local m = model(g, "Lamp")
		part(m, "Pole", V(0.5, 10, 0.5), V(x, 5, 17.5), COL.Dark)
		local bulb = part(
			m,
			"Bulb",
			V(1.4, 1.4, 1.4),
			V(x, 10.3, 17.5),
			c3(255, 240, 190),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		bulb:SetAttribute("NightLight", true)
	end
	-- деревья по краям карты
	for i = 0, 14 do
		local x = -210 + i * 30
		tree(g, V(x, 0, -125 - (i % 3) * 6), 7 + (i % 3), 9)
		tree(g, V(x + 10, 0, 215 + (i % 2) * 6), 7 + (i % 2), 8)
	end
	sign(g, V(-30, 9, 0), "place.Street", c3(255, 240, 160), 240)
end

local function buildHome()
	local h = folder(world, "Home")
	local W = WorldData.Home
	-- пол и стены: дом x -28..28, z -70..-30, высота 12
	part(h, "Floor", V(56, 0.4, 40), V(0, 0.2, -50), COL.Floor, { Material = Enum.Material.WoodPlanks })
	part(
		h,
		"BathFloor",
		V(14, 0.42, 20),
		V(21, 0.21, -60),
		COL.Tile,
		{ Material = Enum.Material.SmoothPlastic }
	)
	local wc = c3(250, 225, 190)
	wall(h, "X", -30, -28, 28, 0, 12, 1, wc, { { 0, 6, 8 } }) -- фасад, дверь
	wall(h, "X", -70, -28, 28, 0, 12, 1, wc, { { -10, 5, 7 } }) -- задняя, выход во двор
	wall(h, "Z", -28, -70, -30, 0, 12, 1, wc)
	wall(h, "Z", 28, -70, -30, 0, 12, 1, wc)
	-- внутренние стены (ниже, с проёмами): спальня/ванная сзади, кухня справа
	local iw = c3(240, 235, 225)
	wall(h, "X", -50, -28, 28, 0, 9, 0.6, iw, { { -16, 7, 7 }, { 6, 7, 7 }, { 21, 6, 7 } })
	wall(h, "Z", 14, -70, -50, 0, 9, 0.6, iw)
	wall(h, "Z", 4, -50, -40, 0, 9, 0.6, iw)
	for _, x in ipairs({ -18, 18 }) do
		window(h, V(x, 6, -29.7), "X", 7)
		window(h, V(x, 6, -70.3), "X", 6)
	end
	window(h, V(-28.3, 6, -50), "Z", 8)
	window(h, V(28.3, 6, -42), "Z", 6)
	-- крыша (клиент делает её прозрачной, когда питомец внутри)
	local roof = model(h, "Roof")
	for _, side in ipairs({ -1, 1 }) do
		local r = part(
			roof,
			"RoofSlab",
			V(60, 1, 24),
			CFrame.new(0, 15.5, -50 + side * 10.5) * CFrame.Angles(math.rad(side * 24), 0, 0),
			c3(200, 85, 70),
			{ CanCollide = false }
		)
		r:SetAttribute("HomeRoof", true)
	end
	local ridge = part(roof, "Ridge", V(60, 1, 1.4), V(0, 20.4, -50), c3(170, 65, 55), { CanCollide = false })
	ridge:SetAttribute("HomeRoof", true)
	for _, z in ipairs({ -70, -30 }) do
		for i = 1, 4 do
			local w = 56 - i * 11
			local gab = part(roof, "Gable", V(w, 2.2, 0.8), V(0, 11 + i * 2.1, z), wc, { CanCollide = false })
			gab:SetAttribute("HomeRoof", true)
		end
	end
	sign(h, V(0, 10, -29), "place.Home", c3(255, 220, 160), 220)
	part(h, "Doormat", V(5, 0.1, 2.5), V(0, 0.45, -28.5), c3(180, 90, 70), { CanCollide = false })

	-- гостиная: диван, ТВ, ковёр, коробка игрушек, бутик, коврик для трюков
	local lr = model(h, "LivingRoom")
	part(lr, "Rug", V(16, 0.1, 10), V(-12, 0.45, -42), c3(120, 160, 220), { CanCollide = false })
	part(lr, "SofaSeat", V(10, 1.6, 3.5), V(-12, 0.8, -48), c3(110, 140, 200))
	part(lr, "SofaBack", V(10, 3, 1), V(-12, 2, -49.4), c3(95, 120, 180))
	part(lr, "TV", V(7, 4, 0.5), V(-12, 4, -30.8), COL.Dark)
	part(lr, "TVStand", V(8, 2, 2), V(-12, 1, -31.6), COL.Wood)
	local toy = part(lr, "ToyBox", V(4, 2.5, 3), W.ToyBox + V(0, 1.25, 0), c3(240, 180, 60))
	part(
		lr,
		"ToyBall",
		V(1.2, 1.2, 1.2),
		W.ToyBox + V(-0.8, 2.9, 0),
		c3(230, 70, 80),
		{ Shape = Enum.PartType.Ball, CanCollide = false }
	)
	Interact.prompt(toy, "Fetch", "prompt.fetch", { Arg = "Home", Object = "obj.toybox" })
	local bout = part(lr, "Boutique", V(2, 6, 6), W.Boutique + V(0, 3, 0), c3(200, 150, 220))
	part(
		lr,
		"BoutiqueMirror",
		V(0.2, 3.5, 3),
		W.Boutique + V(1.1, 3.6, 0),
		COL.Window,
		{ Material = Enum.Material.Glass, CanCollide = false }
	)
	Interact.prompt(bout, "Shop", "prompt.shop", { Object = "obj.boutique" })
	local mat = part(
		lr,
		"TrickMat",
		V(5, 0.15, 5),
		W.TrickMat + V(0, 0.48, 0),
		c3(250, 210, 90),
		{ CanCollide = false }
	)
	part(
		lr,
		"TrickMatStar",
		V(1.6, 0.16, 1.6),
		W.TrickMat + V(0, 0.5, 0),
		c3(255, 150, 60),
		{ CanCollide = false, Orientation = V(0, 45, 0) }
	)
	Interact.prompt(mat, "Tricks", "prompt.tricks", { Object = "obj.trickmat" })

	-- кухня: миски, стол (выпрашивать), холодильник, плита
	local k = model(h, "Kitchen")
	local bowl = part(
		k,
		"FoodBowl",
		V(2, 0.7, 2),
		W.FoodBowl + V(0, 0.75, 0),
		c3(230, 80, 80),
		{ Shape = Enum.PartType.Cylinder, Orientation = V(0, 0, 90) }
	)
	part(k, "Kibble", V(1.5, 0.3, 1.5), W.FoodBowl + V(0, 1.1, 0), c3(170, 110, 60), { CanCollide = false })
	Interact.prompt(bowl, "Eat", "prompt.eat", { Object = "obj.bowl" })
	local water = part(
		k,
		"WaterBowl",
		V(2, 0.7, 2),
		W.WaterBowl + V(0, 0.75, 0),
		c3(80, 140, 230),
		{ Shape = Enum.PartType.Cylinder, Orientation = V(0, 0, 90) }
	)
	part(
		k,
		"Water",
		V(1.5, 0.3, 1.5),
		W.WaterBowl + V(0, 1.05, 0),
		COL.Water,
		{ CanCollide = false, Transparency = 0.2 }
	)
	Interact.prompt(water, "Eat", "prompt.drink", { Arg = "Water", Object = "obj.water" })
	local tbl = part(k, "Table", V(7, 0.6, 4.5), W.Table + V(0, 3.4, 0), COL.WoodLight)
	for _, o in ipairs({ V(-3, 0, -1.8), V(3, 0, -1.8), V(-3, 0, 1.8), V(3, 0, 1.8) }) do
		part(k, "TableLeg", V(0.5, 3.1, 0.5), W.Table + o + V(0, 1.55, 0), COL.Wood)
	end
	part(k, "Plate", V(1.6, 0.15, 1.6), W.Table + V(-1.5, 3.8, 0), COL.White, { CanCollide = false })
	part(k, "Sandwich", V(1, 0.4, 0.8), W.Table + V(-1.5, 4.05, 0), c3(240, 200, 120), { CanCollide = false })
	Interact.prompt(tbl, "Beg", "prompt.beg", { Object = "obj.table", Distance = 10 })
	part(k, "Fridge", V(4, 8, 3), V(25.5, 4, -36), c3(235, 240, 245))
	part(k, "Counter", V(3, 3.5, 9), V(26, 1.75, -45), c3(200, 205, 215))
	part(k, "Stove", V(3, 0.3, 3), V(26, 3.65, -45), COL.Dark)

	-- спальня: кровать семьи, лежанка питомца
	local br = model(h, "Bedroom")
	part(br, "FamilyBed", V(9, 2, 12), W.FamilyBed + V(0, 1, 0), c3(150, 110, 200))
	part(br, "Pillow", V(7, 0.8, 2.5), W.FamilyBed + V(0, 2.4, -4.5), COL.White)
	part(br, "Blanket", V(9.2, 0.4, 7), W.FamilyBed + V(0, 2.1, 2), c3(120, 170, 230))
	local pb = part(
		br,
		"PetBed",
		V(5, 0.8, 5),
		W.PetBed + V(0, 0.8, 0),
		c3(240, 130, 150),
		{ Shape = Enum.PartType.Cylinder, Orientation = V(0, 0, 90) }
	)
	part(br, "PetCushion", V(4, 0.4, 4), W.PetBed + V(0, 1.15, 0), c3(255, 220, 230), { CanCollide = false })
	Interact.prompt(pb, "Sleep", "prompt.sleep", { Object = "obj.petbed" })
	part(br, "Nightstand", V(2.5, 2.5, 2.5), V(-26, 1.25, -54), COL.Wood)
	part(
		br,
		"Lamp",
		V(1, 1, 1),
		V(-26, 3, -54),
		c3(255, 230, 160),
		{ Material = Enum.Material.Neon, Shape = Enum.PartType.Ball }
	)

	-- ванная
	local bath = model(h, "Bathroom")
	local tub = part(bath, "Tub", V(7, 2.5, 4.5), W.Tub + V(0, 1.25, 0), COL.White)
	part(
		bath,
		"TubWater",
		V(6, 0.2, 3.5),
		W.Tub + V(0, 2.3, 0),
		c3(170, 220, 250),
		{ CanCollide = false, Transparency = 0.3 }
	)
	for i = 1, 4 do
		part(
			bath,
			"Foam",
			V(1.2, 1.2, 1.2),
			W.Tub + V(-2 + i, 2.6, (i % 2) - 0.5),
			COL.White,
			{ Shape = Enum.PartType.Ball, CanCollide = false }
		)
	end
	Interact.prompt(tub, "Bath", "prompt.bath", { Object = "obj.tub" })
	part(bath, "Sink", V(3, 3, 2), V(26, 1.5, -54), COL.White)

	-- двор: забор, ямка, почтовый ящик, будка
	local yard = model(h, "Yard")
	part(
		yard,
		"Lawn",
		V(56, 0.15, 40),
		V(0, 0.08, -90),
		COL.GrassDark,
		{ Material = Enum.Material.Grass, CanCollide = false }
	)
	fence(yard, "X", -110, -28, 30, 5, { 26 })
	fence(yard, "Z", -28, -110, -70, 5)
	fence(yard, "Z", 30, -110, -70, 5)
	part(yard, "Doghouse", V(5, 4, 5), V(18, 2, -95), c3(200, 110, 80))
	part(yard, "DoghouseRoof", V(6, 1, 6), V(18, 4.5, -95), c3(150, 70, 60))
	local mb = part(h, "Mailbox", V(1.5, 1.4, 2.2), W.Mailbox + V(0, 3.4, 0), c3(70, 120, 220))
	part(h, "MailboxPost", V(0.4, 2.8, 0.4), W.Mailbox + V(0, 1.4, 0), COL.Wood)
	Interact.prompt(mb, "Newspaper", "prompt.newspaper", { Object = "obj.mailbox" })
	for x = -24, 24, 6 do
		if math.abs(x) > 4 then
			bush(h, V(x, 0, -27), 2.4)
		end
	end
	for i = 1, 6 do
		flower(h, V(-20 + i * 2.5, 0, -25), if i % 2 == 0 then c3(250, 120, 160) else c3(255, 220, 80))
	end
end

local function buildNeighbours()
	local n = folder(world, "Neighbours")
	for i, nb in ipairs(WorldData.Neighbours) do
		local m = model(n, "House" .. i)
		local c, s = nb.Center, nb.Size
		local hw, hd = s.X / 2, s.Z / 2
		wall(m, "X", c.Z + hd, c.X - hw, c.X + hw, 0, s.Y, 1, nb.Color, { { c.X, 5, 7 } })
		wall(m, "X", c.Z - hd, c.X - hw, c.X + hw, 0, s.Y, 1, nb.Color)
		wall(m, "Z", c.X - hw, c.Z - hd, c.Z + hd, 0, s.Y, 1, nb.Color)
		wall(m, "Z", c.X + hw, c.Z - hd, c.Z + hd, 0, s.Y, 1, nb.Color)
		window(m, V(c.X - hw / 2, 6, c.Z + hd + 0.3), "X", 5)
		window(m, V(c.X + hw / 2, 6, c.Z + hd + 0.3), "X", 5)
		-- плоская крыша с бортиком: по ней бегают коты
		local roof = part(m, "Roof", V(s.X + 1, 1, s.Z + 1), V(c.X, s.Y - 0.5, c.Z), c3(150, 110, 90))
		roof:SetAttribute("Roof", true)
		for _, side in ipairs({ -1, 1 }) do
			part(
				m,
				"Parapet",
				V(s.X + 1, 0.8, 0.5),
				V(c.X, s.Y + 0.4, c.Z + side * (hd + 0.25)),
				c3(130, 95, 80)
			)
		end
		part(m, "Chimney", V(2, 3, 2), V(c.X + hw - 3, s.Y + 1.5, c.Z - hd + 3), c3(170, 90, 70))
		-- «лестница» для котов: ящик -> сарайчик -> крыша (с одним прыжком не забраться)
		local side = if c.X < 0 then 1 else -1
		part(
			m,
			"Crate",
			V(3, 2.5, 3),
			V(c.X + side * (hw + 2), 1.25, c.Z + hd - 2),
			COL.WoodLight,
			{ Material = Enum.Material.WoodPlanks }
		)
		part(m, "Shed", V(5, 9, 6), V(c.X + side * (hw + 5.5), 4.5, c.Z + hd - 7), c3(160, 120, 90))
		part(m, "ShedRoof", V(6, 0.6, 7), V(c.X + side * (hw + 5.5), 9.3, c.Z + hd - 7), c3(120, 85, 65))
		part(m, "Mailbox", V(1.2, 1.2, 1.8), V(c.X + 6, 3.2, -18), c3(200, 70, 70))
		part(m, "MailboxPost", V(0.4, 2.6, 0.4), V(c.X + 6, 1.3, -18), COL.Wood)
		bush(m, V(c.X - 6, 0, -24), 2.6)
		bush(m, V(c.X + 10, 0, -24), 2.2)
	end
	-- тайный сад за высоким забором: внутрь — только через лаз (кролики) или по воздуху
	local gd = folder(world, "Garden")
	local z = WorldData.Zones.Garden
	fence(gd, "X", -72, -135, -105, 11, { -120 })
	fence(gd, "X", -100, -135, -105, 11)
	fence(gd, "Z", -135, -100, -72, 11)
	fence(gd, "Z", -105, -100, -72, 11)
	part(
		gd,
		"GardenLawn",
		V(30, 0.15, 28),
		V((z.Min.X + z.Max.X) / 2, 0.08, -86),
		c3(140, 215, 110),
		{ CanCollide = false }
	)
	for i = 0, 5 do
		flower(gd, V(-130 + i * 4, 0, -95), if i % 2 == 0 then c3(250, 120, 200) else c3(160, 120, 250))
	end
	part(gd, "Gnome", V(1.2, 2, 1.2), V(-112, 1, -92), c3(80, 140, 230))
	part(gd, "GnomeHat", V(1, 1.2, 1), V(-112, 2.6, -92), COL.Red)
	sign(gd, V(-120, 13, -72), "place.Garden", c3(220, 200, 255), 200)
end

local function buildShelter()
	local s = folder(world, "Shelter")
	local zmin, zmax, xmin, xmax = 30, 60, -150, -110
	part(s, "Floor", V(40, 0.4, 30), V(-130, 0.2, 45), c3(235, 220, 200))
	local wc = c3(255, 200, 150)
	wall(s, "X", zmin, xmin, xmax, 0, 11, 1, wc, { { -130, 6, 8 } })
	wall(s, "X", zmax, xmin, xmax, 0, 11, 1, wc)
	wall(s, "Z", xmin, zmin, zmax, 0, 11, 1, wc)
	wall(s, "Z", xmax, zmin, zmax, 0, 11, 1, wc)
	local roof = part(s, "Roof", V(42, 1, 32), V(-130, 11.5, 45), c3(240, 140, 90), { CanCollide = false })
	roof:SetAttribute("HomeRoof", true)
	window(s, V(-142, 6, 29.7), "X", 6)
	window(s, V(-118, 6, 29.7), "X", 6)
	sign(s, V(-130, 14, 29), "place.Shelter", c3(255, 230, 170), 260)
	-- коробки с питомцами (декор), миски, лежанки
	for i = 0, 3 do
		local x = -146 + i * 6
		part(s, "Box", V(4.5, 2.5, 4), V(x, 1.25, 56), c3(210, 170, 120), { Material = Enum.Material.Fabric })
		part(
			s,
			"BoxBlanket",
			V(3.6, 0.3, 3),
			V(x, 2.6, 56),
			if i % 2 == 0 then c3(150, 200, 250) else c3(250, 170, 190),
			{ CanCollide = false }
		)
	end
	part(s, "Counter", V(8, 3.5, 2.5), V(-140, 1.75, 47), c3(160, 120, 90))
	-- пьедестал выбора вида
	local ped = part(
		s,
		"Pedestal",
		V(6, 1, 6),
		V(-125, 0.9, 48),
		c3(250, 220, 120),
		{ Shape = Enum.PartType.Cylinder, Orientation = V(0, 0, 90) }
	)
	part(
		s,
		"PedestalStar",
		V(2, 2, 2),
		V(-125, 3.4, 48),
		c3(255, 230, 120),
		{ Material = Enum.Material.Neon, Orientation = V(0, 45, 45), CanCollide = false }
	)
	Interact.prompt(ped, "Species", "prompt.species", { Object = "obj.pedestal", Distance = 12 })
	for i = 1, 3 do
		bush(s, V(-150 + i * 9, 0, 27), 2.4)
	end
end

local function buildPark()
	local p = folder(world, "Park")
	part(
		p,
		"ParkLawn",
		V(190, 0.15, 170),
		V(115, 0.08, 115),
		c3(135, 210, 100),
		{ Material = Enum.Material.Grass, CanCollide = false }
	)
	sign(p, V(45, 10, 33), "place.Park", c3(255, 245, 140), 260)
	part(p, "Arch", V(14, 1.2, 1.2), V(45, 8.5, 32), c3(250, 220, 90))
	part(p, "ArchL", V(1.2, 8, 1.2), V(38.5, 4, 32), c3(250, 220, 90))
	part(p, "ArchR", V(1.2, 8, 1.2), V(51.5, 4, 32), c3(250, 220, 90))
	-- одуванчики
	local rnd = Random.new(17)
	for _ = 1, 70 do
		local pos = V(rnd:NextNumber(30, 205), 0, rnd:NextNumber(40, 195))
		flower(p, pos, if rnd:NextNumber() < 0.6 then c3(255, 225, 60) else c3(250, 250, 250))
	end
	-- деревья, кусты, скамейки
	for i, pos in ipairs({
		V(35, 0, 120),
		V(140, 0, 45),
		V(195, 0, 175),
		V(30, 0, 190),
		V(200, 0, 50),
		V(150, 0, 190),
	}) do
		tree(p, pos, 7 + i % 3, 9 + i % 2 * 2)
	end
	-- дерево с площадкой (осколок для попугаев; камень рядом помогает котам)
	local big = tree(p, V(60, 0, 160), 11, 12, c3(80, 160, 75))
	part(big, "Branch", V(8, 0.8, 5), V(60, 12, 160), c3(130, 90, 60), { Material = Enum.Material.Wood })
	part(p, "Rock", V(5, 2.5, 4), V(66, 1.25, 156), c3(150, 150, 160), { Material = Enum.Material.Slate })
	for _, b in ipairs({ V(95, 0, 60), V(130, 0, 150), V(175, 0, 100) }) do
		part(p, "BenchSeat", V(6, 0.5, 2), b + V(0, 1.6, 0), COL.Wood)
		part(p, "BenchBack", V(6, 1.6, 0.4), b + V(0, 2.6, 0.9), COL.Wood)
		part(p, "BenchLegs", V(5, 1.4, 1.6), b + V(0, 0.7, 0), COL.Dark)
	end
	-- пруд
	part(
		p,
		"Pond",
		V(26, 0.3, 18),
		V(130, 0.2, 165),
		COL.Water,
		{ Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false }
	)
	part(p, "PondEdge", V(28, 0.25, 20), V(130, 0.12, 165), c3(170, 160, 150), { CanCollide = false })
	for i = 1, 3 do
		part(
			p,
			"LilyPad",
			V(2, 0.1, 2),
			V(122 + i * 5, 0.4, 162 + (i % 2) * 4),
			c3(80, 170, 80),
			{ CanCollide = false }
		)
	end

	-- аджилити-трасса: старт, 6 колец-чекпоинтов, барьеры и тоннель между ними
	local ag = model(p, "Agility")
	local A = WorldData.Agility
	local start = part(ag, "StartGate", V(8, 0.4, 4), A.Start + V(0, 0.3, 0), c3(90, 200, 120))
	part(ag, "StartFlag", V(0.4, 6, 0.4), A.Start + V(-4, 3, 0), COL.White)
	part(
		ag,
		"StartBanner",
		V(3, 1.6, 0.2),
		A.Start + V(-2.4, 5.2, 0),
		c3(90, 200, 120),
		{ CanCollide = false }
	)
	Interact.prompt(start, "Agility", "prompt.agility", { Object = "obj.agility", Distance = 10 })
	sign(ag, A.Start + V(0, 8, 0), "place.Agility", c3(180, 255, 190), 220)
	for i, cp in ipairs(A.Checkpoints) do
		local ring = model(ag, "Checkpoint" .. i)
		local col = if i == #A.Checkpoints then c3(255, 210, 80) else c3(255, 140, 90)
		part(ring, "PostL", V(0.8, 6, 0.8), cp + V(-3.5, 3, 0), col)
		part(ring, "PostR", V(0.8, 6, 0.8), cp + V(3.5, 3, 0), col)
		part(ring, "Top", V(8, 0.8, 0.8), cp + V(0, 6.2, 0), col)
		local num = sign(ring, cp + V(0, 8, 0), "agility.cp", col, 60)
		Locale.setWorld(num:FindFirstChild("Text") :: TextLabel, "agility.cp", { n = i })
		ring:SetAttribute("Checkpoint", i)
	end
	-- препятствия между чекпоинтами
	part(ag, "Hurdle", V(6, 0.4, 0.4), V(70, 1.6, 80), COL.White)
	part(ag, "HurdleL", V(0.4, 1.8, 0.4), V(67, 0.9, 80), c3(230, 80, 80))
	part(ag, "HurdleR", V(0.4, 1.8, 0.4), V(73, 0.9, 80), c3(230, 80, 80))
	part(
		ag,
		"Ramp",
		V(6, 1, 12),
		CFrame.new(70, 1.4, 100) * CFrame.Angles(math.rad(14), 0, 0),
		c3(250, 200, 90)
	)
	part(ag, "Platform", V(6, 2.6, 6), V(70, 1.3, 109), c3(250, 200, 90))
	for i = 0, 4 do
		part(
			ag,
			"WeavePole",
			V(0.5, 4, 0.5),
			V(92 + i * 3.5, 2, 118 + (i % 2) * 2),
			if i % 2 == 0 then c3(240, 80, 80) else COL.White
		)
	end
	part(ag, "TunnelTop", V(5, 0.6, 8), V(105, 3.2, 88), c3(90, 140, 230), { CanCollide = false })
	part(ag, "TunnelL", V(0.5, 3, 8), V(102.7, 1.5, 88), c3(90, 140, 230))
	part(ag, "TunnelR", V(0.5, 3, 8), V(107.3, 1.5, 88), c3(90, 140, 230))

	-- апорт: метатель мячей
	local F = WorldData.Fetch
	local launcher = part(p, "BallLauncher", V(3, 3, 3), F.Park + V(0, 1.5, 0), c3(240, 120, 60))
	part(
		p,
		"LauncherBall",
		V(1.4, 1.4, 1.4),
		F.Park + V(0, 3.6, 0),
		c3(250, 230, 80),
		{ Shape = Enum.PartType.Ball, CanCollide = false }
	)
	Interact.prompt(launcher, "Fetch", "prompt.fetch", { Arg = "Park", Object = "obj.launcher" })
	sign(p, F.Park + V(0, 7, 0), "place.Fetch", c3(255, 230, 140), 180)
end

local function buildDigSpots()
	local f = folder(world, "DigSpots")
	for _, d in ipairs(WorldData.DigSpots) do
		local mound = part(
			f,
			d.Id,
			V(3.4, 0.8, 3.4),
			d.Pos + V(0, 0.3, 0),
			c3(150, 105, 70),
			{ Material = Enum.Material.Ground, CanCollide = false }
		)
		part(f, "Pebble", V(0.5, 0.4, 0.5), d.Pos + V(0.9, 0.7, 0.4), c3(120, 85, 60), { CanCollide = false })
		mound:SetAttribute("DigSpot", d.Id)
		Interact.prompt(
			mound,
			"Dig",
			"prompt.dig",
			{ Arg = d.Id, Species = "Dig", Hold = 0.6, Object = "obj.digspot" }
		)
	end
end

local function buildBurrows()
	local f = folder(world, "Burrows")
	for _, g in ipairs(WorldData.BurrowGaps) do
		for _, side in ipairs({ "A", "B" }) do
			local pos = if side == "A" then g.A else g.B
			local pad = part(
				f,
				g.Id .. side,
				V(2.6, 0.2, 2.6),
				pos + V(0, 0.2, 0),
				c3(110, 80, 60),
				{ CanCollide = false }
			)
			Interact.prompt(
				pad,
				"Burrow",
				"prompt.burrow",
				{ Arg = g.Id .. ":" .. side, Species = "Burrow", Hold = 0.4, Object = "obj.gap" }
			)
		end
	end
end

local function buildShards()
	local f = folder(world, "Shards")
	for _, s in ipairs(WorldData.Shards) do
		if s.Id ~= "s_dig" then
			local p = part(
				f,
				s.Id,
				V(1.1, 1.8, 1.1),
				CFrame.new(s.Pos) * CFrame.Angles(0, 0, math.rad(15)),
				COL.Neon,
				{
					Material = Enum.Material.Neon,
					CanCollide = false,
					Transparency = 0.1,
				}
			)
			p:SetAttribute("ShardId", s.Id)
			Interact.prompt(p, "Shard", "prompt.shard", { Arg = s.Id, Object = "obj.shard", Distance = 8 })
		end
	end
end

-- Остров сна: тёмная площадка в небе, звёзды и Полуночный кот (катсцена «Сон»)
local function buildDream()
	local d = folder(world, "Dream")
	local c = WorldData.SPAWN_DREAM
	part(
		d,
		"Cloud",
		V(40, 1, 40),
		c + V(0, -3, 0),
		c3(70, 60, 120),
		{ Material = Enum.Material.SmoothPlastic }
	)
	part(
		d,
		"Glow",
		V(30, 0.2, 30),
		c + V(0, -2.4, 0),
		c3(120, 100, 200),
		{ Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.5 }
	)
	local rnd = Random.new(5)
	for _ = 1, 24 do
		part(
			d,
			"Star",
			V(0.8, 0.8, 0.8),
			c + V(rnd:NextNumber(-40, 40), rnd:NextNumber(4, 30), rnd:NextNumber(-60, -20)),
			c3(255, 245, 200),
			{ Material = Enum.Material.Neon, CanCollide = false, Shape = Enum.PartType.Ball }
		)
	end
	part(
		d,
		"Starfall",
		V(2.4, 2.4, 2.4),
		c + V(6, 14, -18),
		c3(255, 230, 150),
		{ Material = Enum.Material.Neon, CanCollide = false, Shape = Enum.PartType.Ball }
	)
	local cat = PetRig.build(
		"MidnightCat",
		CFrame.new(c + V(0, PetRig.ROOT_Y - 2.5, -12)) * CFrame.Angles(0, math.rad(180), 0),
		{ Scale = 1.6, Name = "MidnightCat" }
	)
	for _, x in ipairs(cat:GetDescendants()) do
		if x:IsA("BasePart") then
			x.Anchored = true
		end
	end
	local hum = cat:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy() -- статуя, не персонаж
	end
	cat.Parent = d
end

local function setupLighting()
	Lighting.Ambient = c3(120, 115, 130)
	Lighting.OutdoorAmbient = c3(150, 145, 160)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 9
	Lighting.FogColor = c3(200, 225, 250)
	Lighting.FogStart = 200
	Lighting.FogEnd = 900
	Lighting.GlobalShadows = true
end

function WorldBuilder.build()
	local old = Workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace
	setupLighting()
	buildGround()
	buildHome()
	buildNeighbours()
	buildShelter()
	buildPark()
	buildDigSpots()
	buildBurrows()
	buildShards()
	buildDream()
	-- папки для динамики: NPC, мячи, игрушки
	folder(world, "NPC")
	folder(world, "Dynamic")
	return world
end

function WorldBuilder.folder(name: string): Folder
	return world:FindFirstChild(name) :: Folder
end

return WorldBuilder
