--!strict
--[[
	WorldData — раскладка мира (студы). Земля: верх на Y = 0. Используется WorldBuilder (сервер), сервисами
	(проверки расстояний, зоны) и клиентом (метки квестов). Мир строится кодом — ассеты не нужны.

	   z<0  ← север: дом семьи (Home), соседские дома с крышами, «тайный сад» за забором
	   z=0  ← улица Кленовая (Maple Street), дорога вдоль X
	   z>0  ← юг: приют «Тёплый нос» (Shelter, запад) и парк «Одуванчик» (Dandelion Park, восток)
]]
local V = Vector3.new

local WorldData = {}

WorldData.GROUND_SIZE = 560
WorldData.ROAD_HALF = 11

-- Зоны (прямоугольники XZ): для «где я» и событий arrive_home
WorldData.Zones = {
	Home = { Min = V(-28, 0, -70), Max = V(28, 14, -30) },
	Shelter = { Min = V(-150, 0, 30), Max = V(-110, 12, 60) },
	Park = { Min = V(20, 0, 30), Max = V(210, 40, 200) },
	Street = { Min = V(-220, 0, -30), Max = V(220, 40, 30) },
	Garden = { Min = V(-135, 0, -100), Max = V(-105, 20, -72) },
}
WorldData.ZONE_ORDER = { "Home", "Shelter", "Garden", "Park", "Street" }

function WorldData.zoneAt(pos: Vector3): string
	for _, name in ipairs(WorldData.ZONE_ORDER) do
		local z = WorldData.Zones[name]
		if pos.X >= z.Min.X and pos.X <= z.Max.X and pos.Z >= z.Min.Z and pos.Z <= z.Max.Z then
			return name
		end
	end
	return "Outside"
end

-- Точки появления
WorldData.SPAWN_SHELTER = V(-130, 3, 50)
WorldData.SPAWN_HOME = V(-8, 3, -40)
WorldData.SPAWN_DREAM = V(0, 63, -330) -- «сон»: отдельная площадка вне карты

-- Дом семьи: объекты
WorldData.Home = {
	FoodBowl = V(10, 0, -33),
	WaterBowl = V(14, 0, -33),
	Table = V(18, 0, -42),
	PetBed = V(-6, 0, -64),
	FamilyBed = V(-20, 0, -62),
	Tub = V(22, 0, -62),
	ToyBox = V(-22, 0, -35),
	Boutique = V(-25, 0, -46),
	TrickMat = V(-8, 0, -44),
	Mailbox = V(9, 0, -24),
	Door = V(0, 0, -30),
}

-- Семья: где стоят (днём) и где спит папа (задание «разбудить»)
WorldData.Family = {
	Dad = V(-12, 0, -40),
	Grandma = V(20, 0, -46),
	Kid = V(-18, 0, -38),
	DadAsleep = V(-20, 3.2, -62),
	Keeper = V(-140, 0, 52), -- смотритель приюта (Nina)
}

-- Осколки памяти: Access — кто легко достанет (подсказка); все проверки на сервере — по расстоянию
WorldData.Shards = {
	{ Id = "s_home", Pos = V(-26.5, 1.5, -66), Access = "Any" }, -- под кроватью семьи
	{ Id = "s_street", Pos = V(-60, 1.5, -18), Access = "Any" }, -- у почтового ящика соседей
	{ Id = "s_park", Pos = V(120, 1.5, 150), Access = "Any" }, -- у пруда
	{ Id = "s_roof", Pos = V(80, 15.5, -45), Access = "Cat" }, -- крыша соседа (двойной прыжок / полёт)
	{ Id = "s_garden", Pos = V(-120, 1.5, -88), Access = "Rabbit" }, -- тайный сад за забором (подкоп)
	{ Id = "s_dig", Pos = V(170, 1.5, 70), Access = "Dog" }, -- выкапывается из ямки (Dig)
	{ Id = "s_tree", Pos = V(60, 13.5, 160), Access = "Parrot" }, -- на дереве в парке
	{ Id = "s_shelter", Pos = V(-146, 1.5, 34), Access = "Any" }, -- в приюте
	-- v0.2: ещё 21 осколок (всего 29; любой вид может собрать 20+; для «Ночи Искр» нужно 20)
	{ Id = "s_porch", Pos = V(-16, 1.5, -25), Access = "Any" }, -- у крыльца
	{ Id = "s_road_w", Pos = V(-150, 1.5, 8), Access = "Any" }, -- запад улицы
	{ Id = "s_road_e", Pos = V(150, 1.5, -8), Access = "Any" }, -- восток улицы
	{ Id = "s_bench", Pos = V(60, 1.5, 40), Access = "Any" }, -- вход в парк
	{ Id = "s_pond2", Pos = V(140, 1.5, 182), Access = "Any" }, -- дальний берег пруда
	{ Id = "s_course", Pos = V(95, 1.5, 95), Access = "Any" }, -- полоса препятствий
	{ Id = "s_shelter2", Pos = V(-118, 1.5, 56), Access = "Any" }, -- в приюте, у окна
	{ Id = "s_maple_w", Pos = V(-112, 1.5, -20), Access = "Any" }, -- у дома Вязовых
	{ Id = "s_maple_e", Pos = V(112, 1.5, -20), Access = "Any" }, -- у дома Лютиковых
	{ Id = "s_crossing", Pos = V(0, 1.5, 25), Access = "Any" }, -- напротив дома
	{ Id = "s_south", Pos = V(-60, 1.5, 22), Access = "Any" }, -- южный тротуар
	{ Id = "s_far_w", Pos = V(-195, 1.5, -15), Access = "Any" }, -- конец улицы
	{ Id = "s_meadow", Pos = V(30, 1.5, 180), Access = "Any" }, -- луг в парке
	{ Id = "s_corner", Pos = V(200, 1.5, 190), Access = "Any" }, -- угол парка
	{ Id = "s_roof2", Pos = V(-80, 15.5, -44), Access = "Cat" }, -- крыша
	{ Id = "s_roof3", Pos = V(-170, 15.5, -50), Access = "Cat" }, -- крыша
	{ Id = "s_roof4", Pos = V(160, 15.5, -50), Access = "Cat" }, -- крыша
	{ Id = "s_shed", Pos = V(-59.5, 10.6, -42), Access = "Cat" }, -- крыша сарая
	{ Id = "s_garden2", Pos = V(-128, 1.5, -82), Access = "Rabbit" }, -- в тайном саду
	{ Id = "s_yard", Pos = V(30, 1.5, -122), Access = "Rabbit" }, -- за забором двора
	{ Id = "s_dig2", Pos = V(190, 1.5, 130), Access = "Dog" }, -- выкапывается
}
WorldData.SHARD_RADIUS = 6

-- Осколок, который не лежит на виду, а выкапывается из ямки (DigSpots[].Shard)
function WorldData.isDugShard(id: string): boolean
	for _, d in ipairs(WorldData.DigSpots) do
		if d.Shard == id then
			return true
		end
	end
	return false
end

-- Ямки для копания (собаки): Shard — осколок, который выкапывается только тут
-- (Shard = "" — без осколка)
WorldData.DigSpots = {
	{ Id = "dig_park1", Pos = V(170, 0, 70), Shard = "s_dig" },
	{ Id = "dig_park2", Pos = V(95, 0, 185), Shard = "" },
	{ Id = "dig_park3", Pos = V(190, 0, 130), Shard = "s_dig2" },
	{ Id = "dig_yard", Pos = V(10, 0, -88), Shard = "" },
}

-- Лазы под забором (кролики): A <-> B
WorldData.BurrowGaps = {
	{ Id = "gap_garden", A = V(-120, 0, -66), B = V(-120, 0, -78) },
	{ Id = "gap_yard", A = V(26, 0, -104), B = V(26, 0, -116) },
}

-- Аджилити-трасса в парке: старт и чекпоинты по порядку (радиус 7)
WorldData.Agility = {
	Start = V(45, 0, 50),
	Checkpoints = { V(60, 0, 70), V(80, 0, 90), V(60, 0, 110), V(85, 0, 125), V(110, 0, 105), V(100, 0, 70) },
	Radius = 7,
	Medals = { Gold = 30, Silver = 45, Bronze = 70 }, -- секунды
}

-- Апорт: метатель мяча в парке и мячик Мии дома
WorldData.Fetch = {
	Park = V(150, 0, 110),
	HomeYard = V(-14, 0, -86),
	Radius = 28,
}

-- Почтальон: маршрут по тротуару
WorldData.MailmanRoute =
	{ V(-180, 0, 15), V(-60, 0, 15), V(9, 0, 15), V(9, 0, -18), V(9, 0, 15), V(180, 0, 15) }

-- Места для «потерянной игрушки» (выбирается одно на день)
WorldData.ToySpots = { V(-70, 0, -20), V(40, 0, 20), V(130, 0, 60), V(70, 0, 180), V(-95, 0, 22) }

-- Крыши (для кота: бег по крышам) — помечаются атрибутом Roof при постройке
WorldData.Neighbours = {
	{ Center = V(-80, 0, -48), Size = V(30, 14, 26), Color = Color3.fromRGB(150, 200, 230) },
	{ Center = V(80, 0, -48), Size = V(30, 14, 26), Color = Color3.fromRGB(240, 200, 150) },
	{ Center = V(-170, 0, -48), Size = V(28, 14, 24), Color = Color3.fromRGB(200, 170, 230) },
	{ Center = V(160, 0, -48), Size = V(28, 14, 24), Color = Color3.fromRGB(180, 230, 180) },
}

-- Сараи у соседских домов (по WorldData.Neighbours): енот открывает замок
function WorldData.shedPos(i: number): Vector3
	local nb = WorldData.Neighbours[i]
	local c, s = nb.Center, nb.Size
	local side = if c.X < 0 then 1 else -1
	return V(c.X + side * (s.X / 2 + 5.5), 0, c.Z + s.Z / 2 - 7)
end

-- «Ночь Искр»: алтарь в парке и испытания видов (искры по одной, за отведённое время).
-- Каждое испытание рассчитано на способности вида, из которого ведёт путь.
WorldData.SparkShrine = V(185, 0, 45)
WorldData.TRIAL_RADIUS = 5
WorldData.Trials = {
	-- лиса: тихо по кустам Кленовой улицы и приюта
	Fox = {
		Time = 150,
		Points = {
			V(-70, 1.5, -24),
			V(-86, 1.5, -24),
			V(-160, 1.5, -24),
			V(-176, 1.5, -24),
			V(-141, 1.5, 27),
			V(-123, 1.5, 27),
		},
	},
	-- снежный барс: по крышам и сараям
	SnowLeopard = {
		Time = 150,
		Points = {
			V(-59.5, 10.6, -42),
			V(-80, 15.5, -40),
			V(-88, 15.5, -56),
			V(-170, 15.5, -44),
			V(-165, 15.5, -54),
		},
	},
	-- корги-рыцарь: обход парка дозором
	CorgiKnight = {
		Time = 120,
		Points = {
			V(45, 1.5, 50),
			V(80, 1.5, 90),
			V(120, 1.5, 150),
			V(170, 1.5, 110),
			V(185, 1.5, 60),
			V(150, 1.5, 40),
		},
	},
	-- хрустальный кролик: тайный сад и двор (через лазы)
	CrystalRabbit = {
		Time = 150,
		Points = {
			V(-118, 1.5, -82),
			V(-130, 1.5, -94),
			V(-110, 1.5, -95),
			V(30, 1.5, -122),
			V(20, 1.5, -126),
		},
	},
	-- енот: мусорные баки улицы
	Raccoon = {
		Time = 120,
		Points = { V(-100, 1.5, -21), V(-40, 1.5, -21), V(40, 1.5, -21), V(100, 1.5, -21), V(-130, 1.5, 21) },
	},
	-- сова: высоко — сараи, крыши, дерево
	Owl = {
		Time = 150,
		Points = {
			V(-59.5, 10.6, -42),
			V(-80, 15.5, -48),
			V(59.5, 10.6, -42),
			V(80, 15.5, -48),
			V(60, 13.5, 160),
		},
	},
}

-- Мусорные баки (енот), логово енота (тайник) и тайники-кристаллы (видит только хрустальный кролик)
WorldData.TrashBins = { V(-100, 0, -21), V(-40, 0, -21), V(40, 0, -21), V(100, 0, -21), V(-130, 0, 21) }
WorldData.RaccoonDen = V(-30, 0, -24)
WorldData.SecretCaches = {
	{ Id = "c_bush", Pos = V(-70, 0.6, -24) },
	{ Id = "c_bush2", Pos = V(90, 0.6, -24) },
	{ Id = "c_shelter", Pos = V(-141, 0.6, 27) },
	{ Id = "c_yard", Pos = V(22, 0.6, -120) },
	{ Id = "c_pond", Pos = V(120, 0.6, 192) },
}
-- Бродячие собаки парка (корги-рыцарь ведёт их в приют)
WorldData.ParkDogs = { V(130, 0, 90), V(160, 0, 150), V(100, 0, 170) }

return WorldData
