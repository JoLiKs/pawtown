--!strict
--[[
	Icons — иконки интерфейса из примитивов GUI (Frame + UICorner + UIGradient + UIStroke), движок взят из
	Pet Collector Simulator. Без эмодзи и без загрузок: одинаково в Roblox (любой клиент) и в веб-демо.
	Icons.make(kind, props) -> Frame: квадратный контейнер, всё внутри в долях (масштабируется с размером).
	props: Name, Size, Position, AnchorPoint, ZIndex, LayoutOrder, Parent, Px (примерный размер в px — толщина обводки).
]]
local Icons = {}

local c3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local DARK = c3(35, 30, 45)

-- Слой: { x, y, w, h } — центр и размер в долях контейнера.
--   c — цвет, g = { верх/лево, низ/право } — градиент, gr — его Rotation (по умолчанию 90), r — поворот (°),
--   k — скругление (доля), t — прозрачность, ring = толщина кольца (доля), o = false — без общего контура.
type Layer = { [string]: any }
local function L(x: number, y: number, w: number, h: number, o: any): Layer
	local t: Layer = o or {}
	t.X, t.Y, t.W, t.H = x, y, w, h
	return t
end
type Spec = { Outline: Color3?, Layers: { Layer } }

-- Голова зверя для карточек выбора вида и бейджей: body/accent/eye/nose + форма ушей
local function animal(body: Color3, accent: Color3, eye: Color3, nose: Color3, ears: string): Spec
	local layers: { Layer } = {}
	if ears == "cat" then
		table.insert(layers, L(0.28, 0.24, 0.26, 0.26, { c = body, r = 45, k = 0.1 }))
		table.insert(layers, L(0.72, 0.24, 0.26, 0.26, { c = body, r = 45, k = 0.1 }))
		table.insert(layers, L(0.28, 0.27, 0.12, 0.12, { c = nose, r = 45, k = 0.1, o = false }))
		table.insert(layers, L(0.72, 0.27, 0.12, 0.12, { c = nose, r = 45, k = 0.1, o = false }))
	elseif ears == "rabbit" then
		table.insert(layers, L(0.36, 0.2, 0.16, 0.4, { c = body, k = 0.5, r = -8 }))
		table.insert(layers, L(0.64, 0.2, 0.16, 0.4, { c = body, k = 0.5, r = 8 }))
		table.insert(layers, L(0.36, 0.22, 0.07, 0.28, { c = nose, k = 0.5, r = -8, o = false }))
		table.insert(layers, L(0.64, 0.22, 0.07, 0.28, { c = nose, k = 0.5, r = 8, o = false }))
	elseif ears == "parrot" then
		table.insert(layers, L(0.5, 0.17, 0.14, 0.26, { c = accent, k = 0.5, r = 15 }))
	end
	table.insert(layers, L(0.5, 0.58, 0.72, 0.64, { g = { body, accent }, gr = 90, k = 0.42 }))
	if ears == "dog" then
		table.insert(layers, L(0.16, 0.56, 0.2, 0.42, { c = accent, k = 0.5, r = 12 }))
		table.insert(layers, L(0.84, 0.56, 0.2, 0.42, { c = accent, k = 0.5, r = -12 }))
	end
	table.insert(layers, L(0.36, 0.52, 0.13, 0.16, { c = WHITE, k = 0.5, o = false }))
	table.insert(layers, L(0.64, 0.52, 0.13, 0.16, { c = WHITE, k = 0.5, o = false }))
	table.insert(layers, L(0.37, 0.54, 0.08, 0.1, { c = eye, k = 0.5, o = false }))
	table.insert(layers, L(0.63, 0.54, 0.08, 0.1, { c = eye, k = 0.5, o = false }))
	if ears == "parrot" then
		table.insert(layers, L(0.5, 0.72, 0.2, 0.2, { c = nose, k = 0.3, r = 45 }))
	else
		table.insert(layers, L(0.5, 0.72, 0.3, 0.16, { c = c3(255, 245, 230), k = 0.5, o = false }))
		table.insert(layers, L(0.5, 0.67, 0.12, 0.07, { c = nose, k = 0.5, o = false }))
	end
	return { Outline = DARK, Layers = layers }
end

local function medal(c: Color3, dark: Color3): Spec
	return {
		Outline = DARK,
		Layers = {
			L(0.38, 0.22, 0.16, 0.36, { c = c3(70, 110, 220), r = -20, k = 0.1 }),
			L(0.62, 0.22, 0.16, 0.36, { c = c3(220, 70, 80), r = 20, k = 0.1 }),
			L(0.5, 0.62, 0.62, 0.62, { g = { c, dark }, k = 0.5 }),
			L(0.5, 0.62, 0.38, 0.38, { ring = 0.04, c = WHITE, k = 0.5, o = false }),
			L(0.4, 0.52, 0.14, 0.08, { c = WHITE, t = 0.3, k = 0.5, r = -40, o = false }),
		},
	}
end

local function paw(c: Color3): Spec
	return {
		Outline = DARK,
		Layers = {
			L(0.5, 0.64, 0.46, 0.38, { c = c, k = 0.45 }),
			L(0.24, 0.42, 0.16, 0.2, { c = c, k = 0.5, r = -20 }),
			L(0.41, 0.28, 0.16, 0.2, { c = c, k = 0.5, r = -5 }),
			L(0.59, 0.28, 0.16, 0.2, { c = c, k = 0.5, r = 5 }),
			L(0.76, 0.42, 0.16, 0.2, { c = c, k = 0.5, r = 20 }),
		},
	}
end

Icons.SPECS = {
	Treat = { -- печенька-косточка
		Outline = c3(110, 60, 20),
		Layers = {
			L(0.5, 0.5, 0.56, 0.24, { g = { c3(250, 210, 140), c3(215, 150, 75) }, k = 0.3, r = -30 }),
			L(0.24, 0.6, 0.2, 0.2, { c = c3(240, 190, 115), k = 0.5 }),
			L(0.33, 0.76, 0.2, 0.2, { c = c3(240, 190, 115), k = 0.5 }),
			L(0.67, 0.24, 0.2, 0.2, { c = c3(240, 190, 115), k = 0.5 }),
			L(0.76, 0.4, 0.2, 0.2, { c = c3(240, 190, 115), k = 0.5 }),
			L(0.46, 0.46, 0.2, 0.05, { c = WHITE, t = 0.4, k = 0.5, r = -30, o = false }),
		},
	},
	Hunger = { -- миска с кормом
		Outline = DARK,
		Layers = {
			L(0.5, 0.48, 0.66, 0.24, { c = c3(160, 100, 50), k = 0.5 }),
			L(0.36, 0.42, 0.16, 0.14, { c = c3(200, 130, 60), k = 0.5, o = false }),
			L(0.56, 0.4, 0.16, 0.14, { c = c3(190, 120, 55), k = 0.5, o = false }),
			L(0.5, 0.66, 0.84, 0.3, { g = { c3(250, 110, 90), c3(200, 60, 60) }, k = 0.35 }),
			L(0.5, 0.6, 0.6, 0.06, { c = WHITE, t = 0.5, k = 0.5, o = false }),
		},
	},
	Energy = { -- луна
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.72, 0.72, { g = { c3(255, 240, 150), c3(240, 190, 60) }, k = 0.5 }),
			L(0.66, 0.38, 0.56, 0.56, { c = c3(40, 50, 90), k = 0.5, o = false }),
			L(0.8, 0.78, 0.1, 0.1, { c = WHITE, r = 45, k = 0.2, o = false }),
		},
	},
	Hygiene = { -- капля и пузырь
		Outline = DARK,
		Layers = {
			L(0.45, 0.42, 0.42, 0.42, { g = { c3(160, 230, 255), c3(60, 150, 240) }, r = 45, k = 0.12 }),
			L(0.45, 0.58, 0.5, 0.5, { g = { c3(150, 225, 255), c3(50, 140, 235) }, k = 0.5 }),
			L(0.36, 0.56, 0.1, 0.18, { c = WHITE, t = 0.3, k = 0.5, o = false }),
			L(0.78, 0.3, 0.2, 0.2, { ring = 0.04, c = c3(200, 240, 255), k = 0.5 }),
		},
	},
	Fun = { -- мячик
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.76, 0.76, { g = { c3(255, 120, 120), c3(220, 50, 80) }, k = 0.5 }),
			L(0.5, 0.5, 0.76, 0.12, { c = c3(255, 230, 90), r = -30, o = false }),
			L(0.36, 0.34, 0.16, 0.1, { c = WHITE, t = 0.3, k = 0.5, r = -35, o = false }),
		},
	},
	Love = { -- сердце
		Outline = DARK,
		Layers = {
			L(0.37, 0.4, 0.38, 0.38, { c = c3(240, 80, 120), k = 0.5 }),
			L(0.63, 0.4, 0.38, 0.38, { c = c3(240, 80, 120), k = 0.5 }),
			L(0.5, 0.56, 0.42, 0.42, { g = { c3(245, 90, 130), c3(205, 45, 90) }, r = 45, k = 0.08 }),
			L(0.33, 0.36, 0.1, 0.1, { c = WHITE, t = 0.3, k = 0.5, o = false }),
		},
	},
	Health = { -- крест
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.78, 0.78, { c = WHITE, k = 0.25 }),
			L(0.5, 0.5, 0.2, 0.56, { c = c3(80, 200, 110), k = 0.15, o = false }),
			L(0.5, 0.5, 0.56, 0.2, { c = c3(80, 200, 110), k = 0.15, o = false }),
		},
	},
	Xp = { -- звезда (два повёрнутых квадрата)
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.56, 0.56, { g = { c3(255, 240, 120), c3(250, 180, 40) }, k = 0.12 }),
			L(0.5, 0.5, 0.56, 0.56, { g = { c3(255, 240, 120), c3(250, 180, 40) }, k = 0.12, r = 45 }),
			L(0.5, 0.5, 0.2, 0.2, { c = WHITE, t = 0.4, k = 0.5, o = false }),
		},
	},
	Shard = { -- осколок памяти (кристалл)
		Outline = c3(40, 30, 90),
		Layers = {
			L(0.5, 0.5, 0.42, 0.66, { g = { c3(200, 230, 255), c3(140, 110, 250) }, r = 20, k = 0.15 }),
			L(0.46, 0.44, 0.12, 0.36, { c = WHITE, t = 0.4, r = 20, k = 0.5, o = false }),
			L(0.8, 0.2, 0.1, 0.1, { c = c3(255, 240, 160), r = 45, k = 0.2, o = false }),
			L(0.18, 0.8, 0.08, 0.08, { c = c3(255, 240, 160), r = 45, k = 0.2, o = false }),
		},
	},
	Quest = { -- флажок
		Outline = DARK,
		Layers = {
			L(0.3, 0.52, 0.08, 0.8, { c = c3(120, 80, 50), k = 0.4 }),
			L(0.58, 0.32, 0.5, 0.36, { g = { c3(255, 200, 80), c3(240, 140, 40) }, k = 0.12 }),
			L(0.3, 0.88, 0.3, 0.08, { c = c3(90, 170, 90), k = 0.5 }),
		},
	},
	Shop = { -- сумка
		Outline = DARK,
		Layers = {
			L(0.5, 0.3, 0.36, 0.3, { ring = 0.05, c = c3(150, 80, 40), k = 0.5, o = false }),
			L(0.5, 0.6, 0.72, 0.56, { g = { c3(255, 170, 90), c3(230, 110, 60) }, k = 0.18 }),
			L(0.5, 0.58, 0.18, 0.18, { c = c3(255, 230, 120), k = 0.5, o = false }),
		},
	},
	Trick = paw(c3(250, 200, 120)),
	Paw = paw(c3(240, 240, 250)),
	Emote = { -- улыбка
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.78, 0.78, { g = { c3(255, 230, 110), c3(250, 180, 50) }, k = 0.5 }),
			L(0.37, 0.42, 0.1, 0.14, { c = DARK, k = 0.5, o = false }),
			L(0.63, 0.42, 0.1, 0.14, { c = DARK, k = 0.5, o = false }),
			L(0.5, 0.64, 0.36, 0.14, { c = c3(200, 70, 80), k = 0.5, o = false }),
		},
	},
	Talent = { -- листок-росток
		Outline = DARK,
		Layers = {
			L(0.5, 0.66, 0.08, 0.5, { c = c3(80, 150, 70), k = 0.4 }),
			L(0.34, 0.4, 0.36, 0.2, { g = { c3(150, 230, 110), c3(70, 170, 70) }, k = 0.5, r = 30 }),
			L(0.66, 0.34, 0.36, 0.2, { g = { c3(150, 230, 110), c3(70, 170, 70) }, k = 0.5, r = -30 }),
		},
	},
	Settings = { -- шестерёнка
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.2, 0.86, { c = c3(190, 200, 220), k = 0.2 }),
			L(0.5, 0.5, 0.2, 0.86, { c = c3(190, 200, 220), k = 0.2, r = 60 }),
			L(0.5, 0.5, 0.2, 0.86, { c = c3(190, 200, 220), k = 0.2, r = 120 }),
			L(0.5, 0.5, 0.6, 0.6, { c = c3(170, 180, 205), k = 0.5 }),
			L(0.5, 0.5, 0.24, 0.24, { c = c3(70, 75, 100), k = 0.5, o = false }),
		},
	},
	Spark = { -- искра (перерождение)
		Outline = c3(60, 40, 110),
		Layers = {
			L(0.5, 0.5, 0.26, 0.86, { g = { c3(255, 250, 200), c3(255, 190, 80) }, k = 0.5 }),
			L(0.5, 0.5, 0.86, 0.26, { g = { c3(255, 250, 200), c3(255, 190, 80) }, k = 0.5 }),
			L(0.5, 0.5, 0.36, 0.36, { c = WHITE, k = 0.5, r = 45, o = false }),
		},
	},
	Lock = {
		Outline = DARK,
		Layers = {
			L(0.5, 0.34, 0.4, 0.4, { ring = 0.07, c = c3(170, 180, 200), k = 0.5, o = false }),
			L(0.5, 0.64, 0.62, 0.46, { g = { c3(250, 210, 90), c3(220, 160, 40) }, k = 0.15 }),
			L(0.5, 0.62, 0.1, 0.18, { c = DARK, k = 0.5, o = false }),
		},
	},
	Check = {
		Outline = c3(20, 80, 40),
		Layers = {
			L(0.36, 0.6, 0.14, 0.36, { c = c3(90, 220, 120), r = -45, k = 0.4 }),
			L(0.6, 0.48, 0.14, 0.62, { c = c3(90, 220, 120), r = 40, k = 0.4 }),
		},
	},
	Close = {
		Outline = DARK,
		Layers = {
			L(0.5, 0.5, 0.16, 0.72, { c = WHITE, r = 45, k = 0.4 }),
			L(0.5, 0.5, 0.16, 0.72, { c = WHITE, r = -45, k = 0.4 }),
		},
	},
	Friends = {
		Outline = DARK,
		Layers = {
			L(0.32, 0.36, 0.22, 0.22, { c = c3(250, 120, 160), k = 0.5 }),
			L(0.5, 0.36, 0.22, 0.22, { c = c3(250, 120, 160), k = 0.5 }),
			L(0.41, 0.48, 0.24, 0.24, { c = c3(240, 90, 140), r = 45, k = 0.1 }),
			L(0.6, 0.56, 0.22, 0.22, { c = c3(120, 190, 255), k = 0.5 }),
			L(0.78, 0.56, 0.22, 0.22, { c = c3(120, 190, 255), k = 0.5 }),
			L(0.69, 0.68, 0.24, 0.24, { c = c3(90, 160, 240), r = 45, k = 0.1 }),
		},
	},
	Sniff = { -- нос и волны
		Outline = DARK,
		Layers = {
			L(0.36, 0.56, 0.46, 0.36, { c = c3(60, 50, 50), k = 0.45 }),
			L(0.28, 0.6, 0.08, 0.1, { c = c3(20, 15, 15), k = 0.5, o = false }),
			L(0.44, 0.6, 0.08, 0.1, { c = c3(20, 15, 15), k = 0.5, o = false }),
			L(0.7, 0.4, 0.2, 0.2, { ring = 0.04, c = c3(150, 220, 255), k = 0.5, o = false }),
			L(0.82, 0.28, 0.14, 0.14, { ring = 0.035, c = c3(150, 220, 255), k = 0.5, o = false }),
		},
	},
	Dash = { -- ветер-стрелки
		Outline = DARK,
		Layers = {
			L(0.42, 0.34, 0.6, 0.12, { c = c3(150, 220, 255), k = 0.5 }),
			L(0.5, 0.52, 0.7, 0.12, { c = c3(120, 200, 255), k = 0.5 }),
			L(0.4, 0.7, 0.5, 0.12, { c = c3(150, 220, 255), k = 0.5 }),
		},
	},
	Jump = { -- двойная стрелка вверх
		Outline = DARK,
		Layers = {
			L(0.5, 0.36, 0.36, 0.36, { c = c3(255, 200, 90), r = 45, k = 0.1 }),
			L(0.5, 0.62, 0.36, 0.36, { c = c3(255, 170, 70), r = 45, k = 0.1 }),
			L(0.5, 0.86, 0.5, 0.16, { c = c3(255, 170, 70), k = 0.3, o = false }),
		},
	},
	Dig = { -- лопатка
		Outline = DARK,
		Layers = {
			L(0.5, 0.3, 0.1, 0.5, { c = c3(150, 100, 60), k = 0.4 }),
			L(0.5, 0.7, 0.36, 0.36, { g = { c3(210, 215, 230), c3(140, 145, 165) }, k = 0.3 }),
			L(0.5, 0.08, 0.24, 0.1, { c = c3(150, 100, 60), k = 0.4 }),
		},
	},
	Burrow = { -- нора
		Outline = DARK,
		Layers = {
			L(0.5, 0.7, 0.86, 0.36, { c = c3(120, 80, 50), k = 0.4 }),
			L(0.5, 0.62, 0.5, 0.36, { c = c3(40, 25, 20), k = 0.5, o = false }),
			L(0.5, 0.26, 0.12, 0.34, { c = c3(200, 160, 110), k = 0.2 }),
			L(0.2, 0.26, 0.12, 0.34, { c = c3(200, 160, 110), k = 0.2 }),
			L(0.8, 0.26, 0.12, 0.34, { c = c3(200, 160, 110), k = 0.2 }),
		},
	},
	Glide = { -- крыло
		Outline = DARK,
		Layers = {
			L(0.5, 0.42, 0.7, 0.2, { c = c3(120, 210, 130), k = 0.5, r = -15 }),
			L(0.56, 0.56, 0.56, 0.16, { c = c3(90, 190, 110), k = 0.5, r = -15 }),
			L(0.62, 0.7, 0.42, 0.13, { c = c3(70, 170, 95), k = 0.5, r = -15 }),
		},
	},
	Home = {
		Outline = DARK,
		Layers = {
			L(0.5, 0.36, 0.5, 0.5, { c = c3(230, 90, 80), r = 45, k = 0.08 }),
			L(0.5, 0.66, 0.6, 0.46, { c = c3(250, 235, 210), k = 0.08 }),
			L(0.5, 0.74, 0.16, 0.3, { c = c3(150, 100, 60), k = 0.2, o = false }),
		},
	},
	Bronze = medal(c3(230, 150, 90), c3(170, 95, 45)),
	Silver = medal(c3(235, 240, 250), c3(160, 170, 190)),
	Gold = medal(c3(255, 225, 90), c3(225, 160, 30)),
	Cat = animal(c3(240, 150, 70), c3(210, 115, 50), c3(70, 160, 70), c3(240, 120, 140), "cat"),
	Dog = animal(c3(190, 135, 80), c3(150, 100, 55), c3(50, 35, 25), c3(40, 30, 30), "dog"),
	Rabbit = animal(c3(240, 240, 245), c3(200, 200, 210), c3(200, 60, 90), c3(250, 150, 170), "rabbit"),
	Parrot = animal(c3(235, 70, 60), c3(70, 190, 90), c3(30, 30, 30), c3(250, 170, 60), "parrot"),
	Fox = animal(c3(235, 120, 50), c3(250, 240, 230), c3(230, 170, 40), c3(30, 25, 25), "cat"),
	SnowLeopard = animal(c3(230, 232, 238), c3(150, 155, 170), c3(120, 190, 230), c3(200, 140, 150), "cat"),
	CorgiKnight = animal(c3(235, 160, 70), c3(250, 245, 235), c3(50, 35, 25), c3(30, 25, 25), "dog"),
	CrystalRabbit = animal(
		c3(170, 220, 255),
		c3(120, 160, 240),
		c3(80, 90, 220),
		c3(250, 170, 210),
		"rabbit"
	),
	Raccoon = animal(c3(140, 140, 150), c3(60, 60, 70), c3(30, 30, 30), c3(30, 30, 30), "cat"),
	Owl = animal(c3(160, 120, 80), c3(235, 215, 180), c3(250, 190, 40), c3(230, 170, 70), "parrot"),
	StarfallDog = animal(c3(255, 235, 150), c3(255, 200, 80), c3(80, 120, 230), c3(60, 50, 40), "dog"),
	MidnightCat = animal(c3(50, 50, 85), c3(90, 70, 170), c3(250, 220, 90), c3(120, 100, 200), "cat"),
} :: { [string]: Spec }

function Icons.has(kind: string): boolean
	return Icons.SPECS[kind] ~= nil
end

local function frame(parent: Instance, name: string, l: Layer, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(l.X, l.Y)
	f.Size = UDim2.fromScale(l.W, l.H)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = l.c or WHITE
	f.BackgroundTransparency = l.t or 0
	f.Rotation = l.r or 0
	f.ZIndex = z
	if l.k then
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(l.k, 0)
		cr.Parent = f
	end
	if l.g then
		f.BackgroundColor3 = WHITE
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(l.g[1], l.g[2])
		g.Rotation = l.gr or 90
		g.Parent = f
	end
	f.Parent = parent
	return f
end

local function stroke(f: Instance, color: Color3, px: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = math.max(1, px)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
end

-- Нижняя половина кольца (дуга магнита): кольцо-обводка, обрезанное контейнером с ClipsDescendants.
-- l = { cx, верх дуги, внешний диаметр }: отверстие и толщина дуги — по трети диаметра.
local function arc(root: Frame, l: Layer, z: number, px: number, outline: Color3?)
	local d = l.W
	local cw, ch = d + 0.16, d / 2 + 0.1
	local clip = Instance.new("Frame")
	clip.Name = "ArcClip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0.5, 0)
	clip.Position = UDim2.fromScale(l.X, l.Y)
	clip.Size = UDim2.fromScale(cw, ch)
	clip.ZIndex = z
	clip.Parent = root
	local function ring(name: string, hole: number, thick: number, color: Color3, zz: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0)
		f.Size = UDim2.fromScale(hole / cw, hole / ch)
		f.ZIndex = zz
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = f
		stroke(f, color, thick)
		f.Parent = clip
	end
	local ow = 0.06
	if outline then
		ring("ArcOutline", d / 3 - 2 * ow * 0.5, px * (d / 3 + 2 * ow * 0.5), outline, z)
	end
	ring("Arc", d / 3, px * d / 3, l.c or WHITE, z + 1)
end

function Icons.make(kind: string, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local px: number = p.Px or 40
	local root = Instance.new("Frame")
	root.Name = p.Name or "Icon"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = p.Size or UDim2.fromOffset(px, px)
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	if p.LayoutOrder then
		root.LayoutOrder = p.LayoutOrder
	end
	local z0: number = p.ZIndex or 1
	root.ZIndex = z0
	root:SetAttribute("IconKind", kind)
	do
		local spec = Icons.SPECS[kind]
		if not spec then
			-- неизвестный вид — нейтральный кружок (не падаем)
			spec = {
				Outline = c3(40, 40, 60),
				Layers = { L(0.5, 0.5, 0.7, 0.7, { c = c3(170, 180, 205), k = 0.5 }) },
			}
		end
		local outline = spec.Outline
		local ow = px * 0.06
		-- проход 1: общий контур (обводка всех «твёрдых» слоёв), проход 2: сами слои поверх — силуэт без внутренних швов
		if outline then
			for i, l in ipairs(spec.Layers) do
				if l.o ~= false and not l.ring and not l.arc then
					local f = frame(root, "Outline" .. i, l, z0 + 1)
					f.BackgroundColor3 = outline
					for _, ch in ipairs(f:GetChildren()) do
						if ch:IsA("UIGradient") then
							ch:Destroy()
						end
					end
					stroke(f, outline, ow)
				end
			end
		end
		for i, l in ipairs(spec.Layers) do
			local z = z0 + 1 + i -- порядок слоёв = порядок отрисовки
			if l.arc then
				arc(root, l, z, px, outline)
			elseif l.ring then
				local f = frame(root, "Ring" .. i, l, z)
				f.BackgroundTransparency = 1
				stroke(f, l.c or WHITE, px * l.ring)
			else
				frame(root, "L" .. i, l, z)
			end
		end
	end
	if p.Parent then
		root.Parent = p.Parent
	end
	return root
end

return Icons
