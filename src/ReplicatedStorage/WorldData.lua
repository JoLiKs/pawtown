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
}
WorldData.SHARD_RADIUS = 6

-- Ямки для копания (собаки): Shard — осколок, который выкапывается только тут
WorldData.DigSpots = {
	{ Id = "dig_park1", Pos = V(170, 0, 70), Shard = "s_dig" },
	{ Id = "dig_park2", Pos = V(95, 0, 185) },
	{ Id = "dig_park3", Pos = V(190, 0, 130) },
	{ Id = "dig_yard", Pos = V(10, 0, -88) },
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
WorldData.MailmanRoute = { V(-180, 0, 15), V(-60, 0, 15), V(9, 0, 15), V(9, 0, -18), V(9, 0, 15), V(180, 0, 15) }

-- Места для «потерянной игрушки» (выбирается одно на день)
WorldData.ToySpots = { V(-70, 0, -20), V(40, 0, 20), V(130, 0, 60), V(70, 0, 180), V(-95, 0, 22) }

-- Крыши (для кота: бег по крышам) — помечаются атрибутом Roof при постройке
WorldData.Neighbours = {
	{ Center = V(-80, 0, -48), Size = V(30, 14, 26), Color = Color3.fromRGB(150, 200, 230) },
	{ Center = V(80, 0, -48), Size = V(30, 14, 26), Color = Color3.fromRGB(240, 200, 150) },
	{ Center = V(-170, 0, -48), Size = V(28, 14, 24), Color = Color3.fromRGB(200, 170, 230) },
	{ Center = V(160, 0, -48), Size = V(28, 14, 24), Color = Color3.fromRGB(180, 230, 180) },
}

return WorldData
