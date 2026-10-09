--!strict
--[[
	SpeciesData — виды питомцев. Игрок всегда ровно ОДИН вид (data.Species).
	Standard — выбор в приюте «Тёплый нос»; Rare/Legendary — перерождение «Звёздная ночь» (v0.2+, в MVP —
	только модель данных и проверка требований: RebirthLogic.check).
	Look: цвета для процедурного рига (PetRig), Shape — форма тела.
	Abilities — id способностей (AbilityData ниже), которые реально работают в MVP.
]]
local c3 = Color3.fromRGB

export type Look = {
	Shape: string, -- "Cat" | "Dog" | "Rabbit" | "Parrot" (форма рига; редкие виды пока используют базовую)
	Body: Color3,
	Accent: Color3,
	Belly: Color3,
	Eye: Color3,
	Nose: Color3,
}
export type Species = {
	Id: string,
	Tier: string, -- "Standard" | "Rare" | "Legendary"
	Name: string,
	Desc: string,
	Speed: number, -- множитель скорости
	Jump: number, -- множитель прыжка
	BondMult: number, -- множитель роста привязанности к хозяевам
	Abilities: { string },
	Look: Look,
	Voice: string, -- эмоция «голос»: bark / meow / squeak / chirp
	Req: { [string]: number }?, -- требования перерождения (Rare/Legendary)
}

local SpeciesData = {}

SpeciesData.Abilities = {
	DoubleJump = { Id = "DoubleJump", Name = "Double jump", Desc = "Jump again in mid-air.", Key = "Space" },
	RoofRun = { Id = "RoofRun", Name = "Roof runner", Desc = "Run faster on rooftops.", Key = "" },
	Sniff = { Id = "Sniff", Name = "Sniff", Desc = "Reveal memory shards and dig spots nearby.", Key = "Q" },
	Dig = { Id = "Dig", Name = "Dig", Desc = "Dig up treasures at dig spots.", Key = "E" },
	Burrow = { Id = "Burrow", Name = "Burrow", Desc = "Crawl under fences through gaps.", Key = "E" },
	Dash = { Id = "Dash", Name = "Dash", Desc = "A short burst of speed.", Key = "Q" },
	Glide = { Id = "Glide", Name = "Glide", Desc = "Hold jump while falling to glide.", Key = "Space" },
	Flap = { Id = "Flap", Name = "Short flight", Desc = "Flap your wings twice in the air.", Key = "Space" },
	Mimic = { Id = "Mimic", Name = "Mimic", Desc = "Copy sounds: a special emote.", Key = "" },
	BestBond = {
		Id = "BestBond",
		Name = "Best friend",
		Desc = "Bond with owners grows 25% faster.",
		Key = "",
	},
}

local list: { Species } = {
	{
		Id = "Cat",
		Tier = "Standard",
		Name = "Cat",
		Desc = "Agile and curious. Reaches places nobody else can.",
		Speed = 1.0,
		Jump = 1.05,
		BondMult = 1,
		Abilities = { "DoubleJump", "RoofRun" },
		Look = {
			Shape = "Cat",
			Body = c3(240, 150, 70),
			Accent = c3(200, 105, 40),
			Belly = c3(255, 230, 200),
			Eye = c3(90, 190, 90),
			Nose = c3(240, 120, 140),
		},
		Voice = "meow",
	},
	{
		Id = "Dog",
		Tier = "Standard",
		Name = "Dog",
		Desc = "Loyal friend with a great nose. Bonds with owners best.",
		Speed = 1.0,
		Jump = 1.0,
		BondMult = 1.25,
		Abilities = { "Sniff", "Dig", "BestBond" },
		Look = {
			Shape = "Dog",
			Body = c3(190, 135, 80),
			Accent = c3(120, 80, 45),
			Belly = c3(245, 225, 190),
			Eye = c3(60, 40, 30),
			Nose = c3(40, 30, 30),
		},
		Voice = "bark",
	},
	{
		Id = "Rabbit",
		Tier = "Standard",
		Name = "Rabbit",
		Desc = "Fastest runner. Burrows under fences.",
		Speed = 1.12,
		Jump = 1.1,
		BondMult = 1,
		Abilities = { "Dash", "Burrow" },
		Look = {
			Shape = "Rabbit",
			Body = c3(235, 235, 240),
			Accent = c3(170, 170, 185),
			Belly = c3(255, 255, 255),
			Eye = c3(200, 60, 90),
			Nose = c3(250, 150, 170),
		},
		Voice = "squeak",
	},
	{
		Id = "Parrot",
		Tier = "Standard",
		Name = "Parrot",
		Desc = "Short flights and gliding. Mimics any sound.",
		Speed = 0.95,
		Jump = 1.0,
		BondMult = 1,
		Abilities = { "Flap", "Glide", "Mimic" },
		Look = {
			Shape = "Parrot",
			Body = c3(70, 190, 90),
			Accent = c3(235, 70, 60),
			Belly = c3(250, 220, 70),
			Eye = c3(30, 30, 30),
			Nose = c3(250, 170, 60),
		},
		Voice = "chirp",
	},
	-- Редкие (перерождение «Звёздная ночь», v0.2+). Req: Level, Nose/Agility/Charm (очки в ветке), Shards, Bond (сумма), Gold (золотых трюков)
	{
		Id = "Fox",
		Tier = "Rare",
		Name = "Fox",
		Desc = "Cunning sniffer of secrets.",
		Speed = 1.08,
		Jump = 1.05,
		BondMult = 1.1,
		Abilities = { "Sniff", "Dig", "Dash" },
		Look = {
			Shape = "Dog",
			Body = c3(230, 110, 40),
			Accent = c3(60, 40, 30),
			Belly = c3(255, 245, 235),
			Eye = c3(230, 170, 40),
			Nose = c3(30, 25, 25),
		},
		Voice = "squeak",
		Req = { Level = 25, Nose = 4, Shards = 8 },
	},
	{
		Id = "SnowLeopard",
		Tier = "Rare",
		Name = "Snow Leopard",
		Desc = "Silent climber of the highest roofs.",
		Speed = 1.08,
		Jump = 1.15,
		BondMult = 1,
		Abilities = { "DoubleJump", "RoofRun", "Dash" },
		Look = {
			Shape = "Cat",
			Body = c3(225, 228, 235),
			Accent = c3(110, 115, 130),
			Belly = c3(250, 250, 255),
			Eye = c3(120, 190, 230),
			Nose = c3(200, 140, 150),
		},
		Voice = "meow",
		Req = { Level = 25, Agility = 4, Shards = 8 },
	},
	{
		Id = "CorgiKnight",
		Tier = "Rare",
		Name = "Corgi Knight",
		Desc = "Brave guardian of the family.",
		Speed = 1.0,
		Jump = 1.0,
		BondMult = 1.4,
		Abilities = { "Sniff", "Dig", "BestBond" },
		Look = {
			Shape = "Dog",
			Body = c3(235, 160, 70),
			Accent = c3(250, 245, 235),
			Belly = c3(255, 250, 240),
			Eye = c3(50, 35, 25),
			Nose = c3(30, 25, 25),
		},
		Voice = "bark",
		Req = { Level = 25, Charm = 4, Bond = 200 },
	},
	{
		Id = "CrystalRabbit",
		Tier = "Rare",
		Name = "Crystal Rabbit",
		Desc = "Shimmers with starlight.",
		Speed = 1.18,
		Jump = 1.15,
		BondMult = 1,
		Abilities = { "Dash", "Burrow" },
		Look = {
			Shape = "Rabbit",
			Body = c3(170, 220, 255),
			Accent = c3(120, 160, 240),
			Belly = c3(235, 250, 255),
			Eye = c3(80, 90, 220),
			Nose = c3(250, 170, 210),
		},
		Voice = "squeak",
		Req = { Level = 30, Agility = 3, Gold = 3 },
	},
	{
		Id = "Raccoon",
		Tier = "Rare",
		Name = "Raccoon",
		Desc = "Master of mischief and bins.",
		Speed = 1.02,
		Jump = 1.05,
		BondMult = 1,
		Abilities = { "Dig", "Burrow", "DoubleJump" },
		Look = {
			Shape = "Cat",
			Body = c3(130, 130, 140),
			Accent = c3(45, 45, 55),
			Belly = c3(200, 200, 205),
			Eye = c3(30, 30, 30),
			Nose = c3(30, 30, 30),
		},
		Voice = "squeak",
		Req = { Level = 25, Nose = 2, Agility = 2, Shards = 6 },
	},
	{
		Id = "Owl",
		Tier = "Rare",
		Name = "Owl",
		Desc = "Wise night flyer.",
		Speed = 0.98,
		Jump = 1.05,
		BondMult = 1,
		Abilities = { "Flap", "Glide", "Sniff" },
		Look = {
			Shape = "Parrot",
			Body = c3(150, 110, 75),
			Accent = c3(95, 65, 40),
			Belly = c3(235, 215, 180),
			Eye = c3(250, 190, 40),
			Nose = c3(230, 170, 70),
		},
		Voice = "chirp",
		Req = { Level = 30, Nose = 3, Charm = 2 },
	},
	-- Легендарные
	{
		Id = "StarfallDog",
		Tier = "Legendary",
		Name = "Starfall Dog",
		Desc = "Born from a falling star. Loved by everyone.",
		Speed = 1.1,
		Jump = 1.1,
		BondMult = 1.5,
		Abilities = { "Sniff", "Dig", "BestBond", "Dash" },
		Look = {
			Shape = "Dog",
			Body = c3(255, 235, 150),
			Accent = c3(255, 200, 80),
			Belly = c3(255, 250, 225),
			Eye = c3(80, 120, 230),
			Nose = c3(60, 50, 40),
		},
		Voice = "bark",
		Req = { Level = 60, Charm = 6, Bond = 270, Shards = 20 },
	},
	{
		Id = "MidnightCat",
		Tier = "Legendary",
		Name = "Midnight Cat",
		Desc = "Keeper of the soul sparks.",
		Speed = 1.12,
		Jump = 1.2,
		BondMult = 1,
		Abilities = { "DoubleJump", "RoofRun", "Glide" },
		Look = {
			Shape = "Cat",
			Body = c3(35, 35, 60),
			Accent = c3(90, 70, 170),
			Belly = c3(60, 60, 95),
			Eye = c3(250, 220, 90),
			Nose = c3(120, 100, 200),
		},
		Voice = "meow",
		Req = { Level = 60, Agility = 6, Nose = 3, Shards = 20, Gold = 5 },
	},
}

SpeciesData.List = list
SpeciesData.ById = {} :: { [string]: Species }
SpeciesData.Standard = {} :: { Species }
for _, s in ipairs(list) do
	SpeciesData.ById[s.Id] = s
	if s.Tier == "Standard" then
		table.insert(SpeciesData.Standard, s)
	end
end

function SpeciesData.isStandard(id: any): boolean
	local s = type(id) == "string" and SpeciesData.ById[id] or nil
	return s ~= nil and s.Tier == "Standard"
end

function SpeciesData.has(speciesId: string?, ability: string): boolean
	local s = speciesId and SpeciesData.ById[speciesId]
	if not s then
		return false
	end
	return table.find(s.Abilities, ability) ~= nil
end

return SpeciesData
