--!nonstrict
--[[
	PetModels — «мягкие» стилизованные модели питомцев из примитивов (v0.2): эллипсоиды (SpecialMesh Sphere —
	в Roblox рисуется эллипсоидом любой пропорции), клинья (WedgePart) для острых ушей и кристаллов.
	Без ассетов — работает и в эмуляторе roblox2web.

	PetModels.specs(speciesId, look) -> (specs, anchors)
	  specs: { Name, Size, CF (CFrame от точки на земле под центром, перед — -Z), Color, Mesh?, Class?,
	           Parent? (по умолчанию Body), Joint? (имя Motor6D), Pivot? (точка сустава), Material?, Reflectance? }
	  anchors: Neck / Top (точки для косметики), S (масштаб головы для косметики)
	Суставы (для PetAnimator): Root, Neck, LegFL/FR/BL/BR, Tail, EarL/EarR, WingL/WingR (птицы).
]]
local PetModels = {}

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles
local rad = math.rad
local BLACK = Color3.fromRGB(22, 20, 28)
local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(245, 150, 170)
local METAL = Color3.fromRGB(200, 205, 215)

local function maker(look)
	local specs = {}
	local function col(c)
		if type(c) == "string" then
			return look[c] or WHITE
		end
		return c
	end
	local function add(name, size, at, color, ex)
		local cf = if typeof(at) == "Vector3" then CF(at) else at
		local s = { Name = name, Size = size, CF = cf, Color = col(color) }
		if ex then
			for k, v in pairs(ex) do
				s[k] = v
			end
		end
		table.insert(specs, s)
		return s
	end
	local m = {}
	m.specs = specs
	-- эллипсоид
	function m.E(name, size, at, color, ex)
		local s = add(name, size, at, color, ex)
		s.Mesh = "Sphere"
		return s
	end
	-- клин
	function m.W(name, size, at, color, ex)
		local s = add(name, size, at, color, ex)
		s.Class = "WedgePart"
		return s
	end
	function m.B(name, size, at, color, ex)
		return add(name, size, at, color, ex)
	end
	-- острый треугольник из двух клиньев (в плоскости XY, вершина вверх): base — CFrame основания
	function m.tri(name, base, w, h, thick, color, ex)
		local e = ex or {}
		m.W(name .. "A", V(thick, h, w / 2), base * CF(-w / 4, h / 2, 0) * A(0, rad(90), 0), color, e)
		m.W(name .. "B", V(thick, h, w / 2), base * CF(w / 4, h / 2, 0) * A(0, rad(-90), 0), color, e)
	end
	-- глаза: большая радужка, зрачок, два блика (милый стиль)
	function m.eyes(H, r, o)
		local spread, up, size = o.spread or 0.42, o.up or 0.1, o.size or 0.22
		local iris = o.iris or "Eye"
		for _, sx in ipairs({ -1, 1 }) do
			local n = if sx < 0 then "L" else "R"
			local dir = V(sx * spread, up, -1).Unit
			local pos = H + dir * r * (o.depth or 0.86)
			local base = CFrame.lookAt(pos, pos + dir)
			if o.ring then
				m.E("EyeRing" .. n, V(size * 1.35, size * 1.5, size * 0.4), base, o.ring, { Parent = "Head" })
			end
			m.E("Eye" .. n, V(size, size * 1.18, size * 0.5), base * CF(0, 0, -0.03), iris, {
				Parent = "Head",
				Material = o.glow and "Neon" or nil,
			})
			m.E(
				"Pupil" .. n,
				V(size * 0.62, size * 0.82, size * 0.45),
				base * CF(0, -size * 0.04, -0.06),
				BLACK,
				{
					Parent = "Head",
				}
			)
			m.E(
				"Shine" .. n,
				V(size * 0.34, size * 0.34, size * 0.2),
				base * CF(sx * size * 0.16, size * 0.24, -0.12),
				WHITE,
				{
					Parent = "Head",
				}
			)
			m.E(
				"Shine2" .. n,
				V(size * 0.16, size * 0.16, size * 0.12),
				base * CF(-sx * size * 0.14, -size * 0.2, -0.11),
				WHITE,
				{
					Parent = "Head",
				}
			)
		end
	end
	return m
end

------------------------------------------------------------------ четвероногие
local QUAD_DEFAULT = {
	legH = 0.85,
	legW = 0.42,
	bodyL = 2.2,
	bodyH = 1.25,
	bodyW = 1.35,
	headD = 1.55,
	muzzle = "cat",
	snoutLen = 0.6,
	ears = "pointy",
	earH = 0.62,
	earW = 0.56,
	earColor = "Body",
	earInner = "Nose",
	tail = "cat",
	tailColor = "Body",
	tailAlt = nil,
	tailTip = nil,
	pawColor = "Belly",
	eyeSize = 0.36,
	eyeSpread = 0.42,
}

local function quad(m, p)
	local o = table.clone(QUAD_DEFAULT)
	for k, v in pairs(p) do
		o[k] = v
	end
	local E = m.E
	local bodyY = o.legH + o.bodyH * 0.38
	E("Body", V(o.bodyW, o.bodyH, o.bodyL), V(0, bodyY, 0), "Body")
	E(
		"Chest",
		V(o.bodyW * 0.72, o.bodyH * 0.78, o.bodyL * 0.42),
		V(0, bodyY - o.bodyH * 0.06, -o.bodyL * 0.3),
		"Belly"
	)
	E(
		"BellyPatch",
		V(o.bodyW * 0.7, o.bodyH * 0.4, o.bodyL * 0.7),
		V(0, bodyY - o.bodyH * 0.3, 0.02),
		"Belly"
	)
	-- голова
	local hd = o.headD
	local headY = bodyY + o.bodyH * 0.5 + hd * 0.28
	local headZ = -o.bodyL * 0.5 - hd * 0.1
	local H = V(0, headY, headZ)
	local r = hd * 0.475
	E("Head", V(hd * 1.06, hd * 0.94, hd * 0.95), H, "Body", {
		Joint = "Neck",
		Pivot = V(0, bodyY + o.bodyH * 0.3, -o.bodyL * 0.36),
	})
	local F = H + V(0, -r * 0.3, -r * 0.88)
	if o.muzzle == "cat" then
		for _, sx in ipairs({ -1, 1 }) do
			E(
				"Cheek" .. (if sx < 0 then "L" else "R"),
				V(hd * 0.28, hd * 0.22, hd * 0.2),
				F + V(sx * hd * 0.11, 0, 0),
				"Belly",
				{ Parent = "Head" }
			)
			for i = 1, 2 do
				m.B(
					"Whisker" .. (if sx < 0 then "L" else "R") .. i,
					V(hd * 0.36, 0.03, 0.03),
					CF(F + V(sx * hd * 0.32, 0.02 - (i - 1) * 0.07, -0.02))
						* A(0, 0, sx * rad(i == 1 and 8 or -6)),
					WHITE,
					{ Parent = "Head" }
				)
			end
		end
		E(
			"Nose",
			V(hd * 0.13, hd * 0.09, hd * 0.08),
			F + V(0, hd * 0.09, -hd * 0.08),
			"Nose",
			{ Parent = "Head" }
		)
	else
		local fox = o.muzzle == "fox"
		local sl = o.snoutLen
		local sw = if fox then hd * 0.34 else hd * 0.42
		E(
			"Snout",
			V(sw, hd * (if fox then 0.26 else 0.32), sl),
			F + V(0, 0, -sl * 0.28),
			"Belly",
			{ Parent = "Head" }
		)
		E(
			"Nose",
			V(hd * 0.18, hd * 0.13, hd * 0.12),
			F + V(0, hd * 0.1, -sl * 0.72),
			"Nose",
			{ Parent = "Head" }
		)
		if not fox then
			E(
				"Tongue",
				V(hd * 0.12, hd * 0.05, hd * 0.14),
				F + V(0, -hd * 0.15, -sl * 0.42),
				PINK,
				{ Parent = "Head" }
			)
		end
	end
	if o.mask then
		E(
			"Mask",
			V(hd * 1.0, hd * 0.25, hd * 0.6),
			H + V(0, r * 0.12, -r * 0.25),
			o.mask,
			{ Parent = "Head" }
		)
	end
	m.eyes(H, r, {
		size = hd * o.eyeSize * 0.62,
		spread = o.eyeSpread,
		up = 0.14,
		glow = o.eyeGlow,
		depth = if o.mask then 0.98 else nil,
	})
	-- уши
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		if o.ears == "floppy" then
			local piv = H + V(sx * r * 0.82, r * 0.55, r * 0.05)
			E(
				"Ear" .. n,
				V(hd * 0.2, o.earH, o.earW),
				CF(H + V(sx * r * 1.0, r * 0.05, r * 0.05)) * A(0, 0, sx * rad(14)),
				o.earColor,
				{
					Parent = "Head",
					Joint = "Ear" .. n,
					Pivot = piv,
				}
			)
		else
			local baseP = H + V(sx * r * 0.52, r * 0.7, r * 0.05)
			local base = CF(baseP) * A(0, 0, -sx * rad(o.earTilt or 16)) * A(rad(-6), 0, 0)
			E(
				"Ear" .. n,
				V(o.earW * 0.85, 0.22, 0.26),
				base,
				o.earColor,
				{ Parent = "Head", Joint = "Ear" .. n, Pivot = baseP }
			)
			m.tri("Ear" .. n .. "Out", base, o.earW, o.earH, 0.16, o.earColor, { Parent = "Ear" .. n })
			m.tri(
				"Ear" .. n .. "In",
				base * CF(0, 0.04, -0.06),
				o.earW * 0.6,
				o.earH * 0.68,
				0.08,
				o.earInner,
				{ Parent = "Ear" .. n }
			)
		end
	end
	-- хвост
	local TB = V(0, bodyY + o.bodyH * 0.18, o.bodyL * 0.44)
	local function chain(angles, len, dia, colors, tip)
		local pnt = TB
		for i, ang in ipairs(angles) do
			local dir = V(0, math.sin(rad(ang)), math.cos(rad(ang)))
			local c = pnt + dir * len * 0.5
			local cf = CFrame.lookAt(c, c + dir)
			local nm = if i == 1 then "Tail" else "Tail" .. i
			E(nm, V(dia, dia, len), cf, colors[(i - 1) % #colors + 1], {
				Parent = if i == 1 then nil else "Tail",
				Joint = if i == 1 then "Tail" else nil,
				Pivot = if i == 1 then TB else nil,
			})
			pnt += dir * len * 0.62
		end
		if tip then
			E("TailTip", V(dia * 1.05, dia * 1.05, dia * 1.3), pnt, tip, { Parent = "Tail" })
		end
	end
	local tc = { o.tailColor, o.tailAlt or o.tailColor }
	if o.tail == "cat" then
		chain({ 25, 50, 75, 95 }, 0.5, 0.3, tc, o.tailTip)
	elseif o.tail == "leopard" then
		chain({ 10, 25, 45, 70, 95 }, 0.55, 0.42, tc, o.tailTip)
	elseif o.tail == "ringed" then
		chain({ 20, 35, 50, 65 }, 0.5, 0.5, tc, o.tailTip)
	elseif o.tail == "dog" then
		chain({ 45, 70 }, 0.55, 0.34, tc, o.tailTip)
	elseif o.tail == "fox" then
		local dir = V(0, math.sin(rad(20)), math.cos(rad(20)))
		local c = TB + dir * 0.8
		E("Tail", V(0.75, 0.72, 1.6), CFrame.lookAt(c, c + dir), o.tailColor, { Joint = "Tail", Pivot = TB })
		E("TailTip", V(0.5, 0.5, 0.6), TB + dir * 1.55, o.tailTip or "Belly", { Parent = "Tail" })
	else -- stub
		E("Tail", V(0.45, 0.42, 0.4), TB + V(0, 0.05, 0.08), o.tailColor, { Joint = "Tail", Pivot = TB })
	end
	-- лапы
	local legTop = bodyY - o.bodyH * 0.12
	local lx, lzf, lzb = o.bodyW * 0.3, -o.bodyL * 0.3, o.bodyL * 0.3
	for _, leg in ipairs({
		{ "LegFL", -lx, lzf },
		{ "LegFR", lx, lzf },
		{ "LegBL", -lx, lzb },
		{ "LegBR", lx, lzb },
	}) do
		local h = legTop - 0.1
		E(leg[1], V(o.legW, h + 0.2, o.legW * 1.05), V(leg[2], h / 2 + 0.12, leg[3]), "Body", {
			Joint = leg[1],
			Pivot = V(leg[2], legTop, leg[3]),
		})
		E(
			leg[1] .. "Paw",
			V(o.legW * 1.18, 0.28, o.legW * 1.4),
			V(leg[2], 0.14, leg[3] - 0.06),
			o.pawColor,
			{ Parent = leg[1] }
		)
	end
	local top = H + V(0, r * 0.92, r * 0.05)
	return {
		H = H,
		r = r,
		bodyY = bodyY,
		o = o,
		anchors = {
			Neck = V(0, bodyY + o.bodyH * 0.36, -o.bodyL * 0.36),
			Top = top,
			S = hd / 1.4,
			NeckW = o.bodyW,
		},
	}
end

------------------------------------------------------------------ кролики
local function rabbit(m, crystal)
	local E = m.E
	local bodyY = 0.95
	E("Body", V(1.35, 1.3, 1.6), CF(0, bodyY, 0.15) * A(rad(-12), 0, 0), "Body")
	E("BellyPatch", V(0.95, 0.95, 0.5), V(0, bodyY - 0.05, -0.42), "Belly")
	local H = V(0, 1.95, -0.55)
	local r = 0.58
	E("Head", V(1.3, 1.15, 1.12), H, "Body", { Joint = "Neck", Pivot = V(0, 1.55, -0.35) })
	local F = H + V(0, -r * 0.32, -r * 0.88)
	for _, sx in ipairs({ -1, 1 }) do
		E(
			"Cheek" .. (if sx < 0 then "L" else "R"),
			V(0.34, 0.28, 0.26),
			F + V(sx * 0.15, 0, 0),
			"Belly",
			{ Parent = "Head" }
		)
	end
	E("Nose", V(0.16, 0.11, 0.1), F + V(0, 0.12, -0.1), "Nose", { Parent = "Head" })
	m.B("Teeth", V(0.16, 0.13, 0.04), F + V(0, -0.15, -0.1), WHITE, { Parent = "Head" })
	m.eyes(H, r, { size = 0.3, spread = 0.48, up = 0.12 })
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		local baseP = H + V(sx * 0.24, r * 0.85, 0.08)
		local base = CF(baseP) * A(rad(-10), 0, -sx * rad(10))
		E(
			"Ear" .. n,
			V(0.4, 0.22, 0.24),
			base,
			"Body",
			{ Parent = "Head", Joint = "Ear" .. n, Pivot = baseP }
		)
		E("Ear" .. n .. "Long", V(0.4, 1.4, 0.22), base * CF(0, 0.65, 0), "Body", { Parent = "Ear" .. n })
		E("Ear" .. n .. "In", V(0.22, 1.05, 0.1), base * CF(0, 0.62, -0.08), "Nose", { Parent = "Ear" .. n })
		if crystal then
			E(
				"Ear" .. n .. "Glow",
				V(0.2, 0.3, 0.2),
				base * CF(0, 1.32, 0),
				"Accent",
				{ Parent = "Ear" .. n, Material = "Neon" }
			)
		end
	end
	E(
		"Tail",
		V(0.6, 0.6, 0.6),
		V(0, 1.05, 0.98),
		"Belly",
		{ Joint = "Tail", Pivot = V(0, 1.0, 0.85), Material = crystal and "Neon" or nil }
	)
	-- лапы: передние тонкие, задние — бедро + длинная стопа
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		E(
			"LegF" .. n,
			V(0.3, 0.75, 0.32),
			V(sx * 0.3, 0.38, -0.45),
			"Body",
			{ Joint = "LegF" .. n, Pivot = V(sx * 0.3, 0.75, -0.45) }
		)
		E(
			"LegF" .. n .. "Paw",
			V(0.34, 0.22, 0.42),
			V(sx * 0.3, 0.11, -0.52),
			"Belly",
			{ Parent = "LegF" .. n }
		)
		E(
			"LegB" .. n,
			V(0.55, 0.8, 0.85),
			V(sx * 0.52, 0.55, 0.45),
			"Body",
			{ Joint = "LegB" .. n, Pivot = V(sx * 0.52, 0.85, 0.45) }
		)
		E(
			"LegB" .. n .. "Foot",
			V(0.4, 0.22, 0.85),
			V(sx * 0.52, 0.11, 0.18),
			"Belly",
			{ Parent = "LegB" .. n }
		)
	end
	if crystal then
		for i, z in ipairs({ -0.2, 0.2, 0.55 }) do
			local base = CF(0, bodyY + 0.6 - i * 0.05, z) * A(rad(-15), 0, 0)
			m.tri("Crystal" .. i, base, 0.34, 0.5 - i * 0.06, 0.3, "Accent", { Material = "Neon" })
		end
		E(
			"Gem",
			V(0.18, 0.18, 0.1),
			H + V(0, r * 0.55, -r * 0.8),
			"Accent",
			{ Parent = "Head", Material = "Neon" }
		)
	end
	return {
		H = H,
		r = r,
		anchors = { Neck = V(0, 1.45, -0.4), Top = H + V(0, r * 0.95, 0.05), S = 0.85, NeckW = 1.2 },
	}
end

------------------------------------------------------------------ птицы
local function parrot(m)
	local E = m.E
	E("Body", V(1.1, 1.55, 1.15), CF(0, 1.35, 0.05) * A(rad(-14), 0, 0), "Body")
	E("BellyPatch", V(0.82, 1.1, 0.5), CF(0, 1.25, -0.32) * A(rad(-14), 0, 0), "Belly")
	local H = V(0, 2.4, -0.18)
	local r = 0.5
	E("Head", V(1.05, 1.0, 1.0), H, "Body", { Joint = "Neck", Pivot = V(0, 2.05, -0.05) })
	m.eyes(H, r, { size = 0.24, spread = 0.75, up = 0.15, ring = WHITE, depth = 0.9 })
	E("Beak", V(0.36, 0.44, 0.46), CF(H + V(0, -0.08, -0.52)) * A(rad(28), 0, 0), "Nose", { Parent = "Head" })
	E("BeakLow", V(0.26, 0.2, 0.26), H + V(0, -0.3, -0.42), Color3.fromRGB(60, 55, 60), { Parent = "Head" })
	for i, a in ipairs({ -25, 0, 25 }) do
		E(
			"Crest" .. i,
			V(0.14, 0.5, 0.22),
			CF(H + V(math.sin(rad(a)) * 0.12, 0.55, 0.05)) * A(rad(-25), 0, rad(a)),
			"Accent",
			{ Parent = "Head" }
		)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		E("Wing" .. n, V(0.26, 1.2, 0.88), CF(sx * 0.58, 1.4, 0.12) * A(rad(-14), 0, 0), "Body", {
			Joint = "Wing" .. n,
			Pivot = V(sx * 0.48, 1.85, 0.0),
		})
		E(
			"Wing" .. n .. "Tip",
			V(0.2, 0.7, 0.55),
			CF(sx * 0.6, 0.85, 0.32) * A(rad(-20), 0, 0),
			"Accent",
			{ Parent = "Wing" .. n }
		)
		E(
			"Wing" .. n .. "Band",
			V(0.22, 0.25, 0.7),
			V(sx * 0.6, 1.2, 0.15),
			Color3.fromRGB(60, 120, 230),
			{ Parent = "Wing" .. n }
		)
	end
	E(
		"Tail",
		V(0.34, 0.12, 1.4),
		CF(0, 0.75, 0.85) * A(rad(-40), 0, 0),
		"Accent",
		{ Joint = "Tail", Pivot = V(0, 1.0, 0.45) }
	)
	E(
		"Tail2",
		V(0.3, 0.1, 1.15),
		CF(0.12, 0.8, 0.78) * A(rad(-38), rad(8), 0),
		Color3.fromRGB(60, 120, 230),
		{ Parent = "Tail" }
	)
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		E("LegF" .. n, V(0.16, 0.6, 0.16), V(sx * 0.24, 0.32, -0.02), Color3.fromRGB(120, 120, 130), {
			Joint = "LegF" .. n,
			Pivot = V(sx * 0.24, 0.62, -0.02),
		})
		E(
			"LegF" .. n .. "Foot",
			V(0.32, 0.12, 0.44),
			V(sx * 0.24, 0.06, -0.1),
			Color3.fromRGB(120, 120, 130),
			{ Parent = "LegF" .. n }
		)
	end
	return {
		H = H,
		r = r,
		anchors = { Neck = V(0, 2.0, -0.12), Top = H + V(0, r * 0.95, 0.05), S = 0.75, NeckW = 0.95 },
	}
end

local function owl(m)
	local E = m.E
	E("Body", V(1.45, 1.6, 1.35), V(0, 1.2, 0.05), "Body")
	E("BellyPatch", V(1.05, 1.15, 0.5), V(0, 1.1, -0.42), "Belly")
	for i, p in ipairs({
		V(-0.2, 1.35, -0.62),
		V(0.2, 1.35, -0.62),
		V(0, 1.05, -0.66),
		V(-0.25, 0.85, -0.6),
		V(0.25, 0.85, -0.6),
	}) do
		E("Spot" .. i, V(0.16, 0.08, 0.06), p, "Accent")
	end
	local H = V(0, 2.25, -0.1)
	local r = 0.62
	E("Head", V(1.4, 1.15, 1.2), H, "Body", { Joint = "Neck", Pivot = V(0, 1.9, -0.05) })
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		E("Disc" .. n, V(0.66, 0.7, 0.2), H + V(sx * 0.3, 0.02, -0.5), "Belly", { Parent = "Head" })
		local baseP = H + V(sx * 0.48, 0.45, 0.0)
		local base = CF(baseP) * A(0, 0, -sx * rad(25))
		E(
			"Ear" .. n,
			V(0.25, 0.15, 0.2),
			base,
			"Accent",
			{ Parent = "Head", Joint = "Ear" .. n, Pivot = baseP }
		)
		m.tri("Ear" .. n .. "Tuft", base, 0.3, 0.42, 0.14, "Accent", { Parent = "Ear" .. n })
	end
	m.eyes(H + V(0, 0.02, 0), r, { size = 0.4, spread = 0.5, up = 0.05, depth = 0.95 })
	E("Beak", V(0.18, 0.32, 0.22), CF(H + V(0, -0.22, -0.62)) * A(rad(15), 0, 0), "Nose", { Parent = "Head" })
	for _, sx in ipairs({ -1, 1 }) do
		local n = if sx < 0 then "L" else "R"
		E(
			"Wing" .. n,
			V(0.3, 1.25, 1.0),
			V(sx * 0.72, 1.25, 0.12),
			"Accent",
			{ Joint = "Wing" .. n, Pivot = V(sx * 0.62, 1.75, 0.0) }
		)
		for k = 1, 2 do
			E(
				"Wing" .. n .. "Stripe" .. k,
				V(0.31, 0.08, 0.7),
				V(sx * 0.73, 1.05 + k * 0.25, 0.15),
				"Belly",
				{ Parent = "Wing" .. n }
			)
		end
		E(
			"LegF" .. n,
			V(0.22, 0.4, 0.22),
			V(sx * 0.3, 0.22, -0.1),
			"Nose",
			{ Joint = "LegF" .. n, Pivot = V(sx * 0.3, 0.45, -0.1) }
		)
		E(
			"LegF" .. n .. "Foot",
			V(0.36, 0.14, 0.4),
			V(sx * 0.3, 0.07, -0.2),
			"Nose",
			{ Parent = "LegF" .. n }
		)
	end
	E(
		"Tail",
		V(0.6, 0.14, 0.6),
		CF(0, 0.55, 0.7) * A(rad(-35), 0, 0),
		"Accent",
		{ Joint = "Tail", Pivot = V(0, 0.7, 0.5) }
	)
	return {
		H = H,
		r = r,
		anchors = { Neck = V(0, 1.85, -0.15), Top = H + V(0, 0.55, 0.05), S = 0.95, NeckW = 1.2 },
	}
end

------------------------------------------------------------------ виды
local BUILD = {}
function BUILD.Cat(m)
	local q = quad(m, { tailAlt = "Accent", tailTip = "Accent" })
	-- полоски табби на лбу и спине
	for i = -1, 1 do
		m.E(
			"Stripe" .. (i + 2),
			V(0.1, 0.07, 0.3),
			CF(q.H + V(i * 0.18, q.r * 0.8, -q.r * 0.35)) * A(rad(-35), 0, 0),
			"Accent",
			{ Parent = "Head" }
		)
	end
	for i = 1, 3 do
		m.E("BackStripe" .. i, V(1.0, 0.12, 0.2), CF(0, q.bodyY + 0.58, -0.4 + i * 0.35), "Accent")
	end
	return q
end
function BUILD.Dog(m)
	local q = quad(m, {
		legH = 0.9,
		bodyL = 2.35,
		bodyH = 1.35,
		bodyW = 1.45,
		headD = 1.6,
		muzzle = "dog",
		snoutLen = 0.7,
		ears = "floppy",
		earH = 0.9,
		earW = 0.55,
		earColor = "Accent",
		tail = "dog",
		tailTip = "Belly",
		eyeSize = 0.34,
	})
	-- пятно у глаза
	m.E("Patch", V(0.42, 0.42, 0.2), q.H + V(0.32, q.r * 0.22, -q.r * 0.78), "Accent", { Parent = "Head" })
	return q
end
function BUILD.Fox(m)
	return quad(m, {
		legH = 0.9,
		bodyL = 2.25,
		bodyH = 1.15,
		bodyW = 1.25,
		headD = 1.5,
		muzzle = "fox",
		snoutLen = 0.75,
		ears = "pointy",
		earH = 0.85,
		earW = 0.62,
		earColor = "Body",
		earInner = "Belly",
		earTilt = 10,
		tail = "fox",
		tailTip = "Belly",
		pawColor = "Accent",
		eyeSize = 0.32,
	})
end
function BUILD.SnowLeopard(m)
	local q = quad(m, {
		legH = 0.9,
		bodyL = 2.6,
		bodyH = 1.3,
		bodyW = 1.4,
		headD = 1.5,
		ears = "pointy",
		earH = 0.45,
		earW = 0.5,
		earTilt = 24,
		tail = "leopard",
		tailAlt = "Body",
		tailTip = "Accent",
		eyeSize = 0.34,
	})
	local spots = {
		V(0.55, 0.3, -0.6),
		V(0.62, 0.0, 0.0),
		V(0.55, 0.25, 0.6),
		V(-0.55, 0.3, -0.6),
		V(-0.62, 0.0, 0.0),
		V(-0.55, 0.25, 0.6),
		V(0.3, 0.58, -0.2),
		V(-0.3, 0.58, 0.3),
		V(0.0, 0.64, 0.75),
	}
	for i, p in ipairs(spots) do
		m.E("Spot" .. i, V(0.24, 0.22, 0.3), V(p.X, q.bodyY + p.Y, p.Z), "Accent")
	end
	for i, p in ipairs({ V(-0.25, 0.75, -0.4), V(0.25, 0.78, -0.35), V(0, 0.9, -0.1) }) do
		m.E(
			"HeadSpot" .. i,
			V(0.13, 0.12, 0.08),
			q.H + V(p.X, p.Y * q.r, p.Z * q.r),
			"Accent",
			{ Parent = "Head" }
		)
	end
	return q
end
function BUILD.CorgiKnight(m)
	local q = quad(m, {
		legH = 0.5,
		legW = 0.44,
		bodyL = 2.5,
		bodyH = 1.25,
		bodyW = 1.45,
		headD = 1.55,
		muzzle = "dog",
		snoutLen = 0.55,
		ears = "pointy",
		earH = 0.78,
		earW = 0.66,
		earTilt = 14,
		earInner = "Accent",
		tail = "stub",
		pawColor = "Accent",
		eyeSize = 0.34,
	})
	-- доспех: нагрудник, плащ, шлем с пером
	m.E(
		"Breastplate",
		V(q.o.bodyW * 0.82, q.o.bodyH * 0.72, 0.6),
		V(0, q.bodyY + 0.05, -q.o.bodyL * 0.36),
		METAL,
		{
			Material = "Metal",
			Reflectance = 0.15,
		}
	)
	m.E(
		"Crest",
		V(0.3, 0.3, 0.12),
		V(0, q.bodyY + 0.12, -q.o.bodyL * 0.36 - 0.3),
		Color3.fromRGB(230, 70, 70)
	)
	m.E(
		"Cape",
		V(q.o.bodyW * 1.04, q.o.bodyH * 0.55, q.o.bodyL * 0.78),
		V(0, q.bodyY + q.o.bodyH * 0.24, 0.22),
		Color3.fromRGB(200, 45, 60)
	)
	m.E(
		"Helmet",
		V(q.r * 1.3, q.r * 0.6, q.r * 1.2),
		q.H + V(0, q.r * 0.82, 0.08),
		METAL,
		{ Parent = "Head", Material = "Metal" }
	)
	m.E(
		"Plume",
		V(0.16, 0.45, 0.5),
		CF(q.H + V(0, q.r * 1.25, 0.15)) * A(rad(-20), 0, 0),
		Color3.fromRGB(230, 60, 70),
		{ Parent = "Head" }
	)
	return q
end
function BUILD.Raccoon(m)
	return quad(m, {
		legH = 0.75,
		bodyL = 2.2,
		bodyH = 1.35,
		bodyW = 1.5,
		headD = 1.55,
		ears = "pointy",
		earH = 0.42,
		earW = 0.5,
		earInner = "Belly",
		earTilt = 22,
		mask = "Accent",
		tail = "ringed",
		tailAlt = "Accent",
		tailTip = "Accent",
		pawColor = "Accent",
		eyeSize = 0.32,
	})
end
function BUILD.StarfallDog(m)
	local q = BUILD.Dog(m)
	for i, p in ipairs({ V(0, 0.68, -0.3), V(0, 0.7, 0.3), V(0.45, 0.4, 0.1), V(-0.45, 0.4, 0.1) }) do
		m.E("Star" .. i, V(0.2, 0.2, 0.2), V(p.X, q.bodyY + p.Y, p.Z), "Accent", { Material = "Neon" })
	end
	return q
end
function BUILD.MidnightCat(m)
	local q = quad(m, { tailAlt = "Accent", tailTip = "Accent", eyeGlow = true, earInner = "Accent" })
	m.E(
		"Moon",
		V(0.22, 0.22, 0.08),
		q.H + V(0, q.r * 0.55, -q.r * 0.82),
		"Eye",
		{ Parent = "Head", Material = "Neon" }
	)
	return q
end
function BUILD.Rabbit(m)
	return rabbit(m, false)
end
function BUILD.CrystalRabbit(m)
	return rabbit(m, true)
end
BUILD.Parrot = parrot
BUILD.Owl = owl

-- Форма по умолчанию для незнакомого вида
local BY_SHAPE = { Cat = "Cat", Dog = "Dog", Rabbit = "Rabbit", Parrot = "Parrot" }

function PetModels.has(speciesId: string): boolean
	return BUILD[speciesId] ~= nil
end

function PetModels.specs(speciesId: string, look: any)
	local m = maker(look)
	local fn = BUILD[speciesId] or BUILD[BY_SHAPE[look.Shape] or "Dog"]
	local info = fn(m)
	return m.specs, info.anchors
end

return PetModels
