--!strict
--[[
	Progression — уровни 1..100, опыт, возрастные стадии, таланты (Nose/Agility/Charm), репутация районов.
	Чистые функции (покрыты тестами).
]]
local Config = require(script.Parent.Config)

local Progression = {}

-- Опыт до следующего уровня
function Progression.xpFor(level: number): number
	return math.floor(40 + 18 * level ^ 1.35)
end

-- Добавить опыт: возвращает новые level, xp и число полученных уровней
function Progression.addXp(level: number, xp: number, amount: number): (number, number, number)
	local gained = 0
	xp += math.max(0, math.floor(amount))
	while level < Config.MAX_LEVEL and xp >= Progression.xpFor(level) do
		xp -= Progression.xpFor(level)
		level += 1
		gained += 1
	end
	if level >= Config.MAX_LEVEL then
		level = Config.MAX_LEVEL
		xp = 0
	end
	return level, xp, gained
end

-- Возрастные стадии по уровню
function Progression.age(level: number): string
	if level >= Config.ADULT_LEVEL then
		return "Adult"
	elseif level >= Config.TEEN_LEVEL then
		return "Teen"
	end
	return "Baby"
end

Progression.AGE_SCALE = { Baby = 0.8, Teen = 0.9, Adult = 1.0 }

-- Очки талантов: 1 за каждый уровень после первого
function Progression.talentPointsTotal(level: number): number
	return math.max(0, level - 1)
end

-- Таланты: 3 ветки по 2 таланта (MVP), до 3 рангов каждый. Per — бонус за ранг.
Progression.Branches = { "Nose", "Agility", "Charm" }
Progression.Talents = {
	KeenNose = {
		Id = "KeenNose",
		Branch = "Nose",
		Name = "Keen Nose",
		Desc = "Sniff reaches farther.",
		Max = 3,
		Per = 0.25,
		Order = 1,
	},
	TreasureHunter = {
		Id = "TreasureHunter",
		Branch = "Nose",
		Name = "Treasure Hunter",
		Desc = "More treats from finds and digs.",
		Max = 3,
		Per = 0.15,
		Order = 2,
	},
	LightPaws = {
		Id = "LightPaws",
		Branch = "Agility",
		Name = "Light Paws",
		Desc = "Run faster.",
		Max = 3,
		Per = 0.04,
		Order = 1,
	},
	SpringLegs = {
		Id = "SpringLegs",
		Branch = "Agility",
		Name = "Spring Legs",
		Desc = "Jump higher.",
		Max = 3,
		Per = 0.06,
		Order = 2,
	},
	PuppyEyes = {
		Id = "PuppyEyes",
		Branch = "Charm",
		Name = "Puppy Eyes",
		Desc = "Owners bond with you faster.",
		Max = 3,
		Per = 0.15,
		Order = 1,
	},
	Showstopper = {
		Id = "Showstopper",
		Branch = "Charm",
		Name = "Showstopper",
		Desc = "Wider timing window in tricks.",
		Max = 3,
		Per = 0.05,
		Order = 2,
	},
}

function Progression.rank(talents: any, id: string): number
	if type(talents) ~= "table" then
		return 0
	end
	local r = talents[id]
	return if type(r) == "number" then math.clamp(math.floor(r), 0, 3) else 0
end

function Progression.bonus(talents: any, id: string): number
	local t = Progression.Talents[id]
	return if t then t.Per * Progression.rank(talents, id) else 0
end

function Progression.spent(talents: any): number
	local n = 0
	for id in pairs(Progression.Talents) do
		n += Progression.rank(talents, id)
	end
	return n
end

function Progression.branchPoints(talents: any, branch: string): number
	local n = 0
	for id, t in pairs(Progression.Talents) do
		if t.Branch == branch then
			n += Progression.rank(talents, id)
		end
	end
	return n
end

-- Можно ли вложить очко: (ok, причина-ключ)
function Progression.canLearn(level: number, talents: any, id: string): (boolean, string?)
	local t = Progression.Talents[id]
	if not t then
		return false, "err.bad_request"
	end
	if Progression.rank(talents, id) >= t.Max then
		return false, "talent.maxed"
	end
	-- второй талант ветки открывается после 1 очка в первом
	if t.Order == 2 then
		local first = nil
		for oid, o in pairs(Progression.Talents) do
			if o.Branch == t.Branch and o.Order == 1 then
				first = oid
			end
		end
		if first and Progression.rank(talents, first) < 1 then
			return false, "talent.locked"
		end
	end
	if Progression.spent(talents) >= Progression.talentPointsTotal(level) then
		return false, "talent.no_points"
	end
	return true, nil
end

-- Репутация района: уровни по очкам
Progression.REP_STEPS = { 0, 30, 90, 200, 400 }
function Progression.repLevel(points: number): number
	local lvl = 0
	for i, need in ipairs(Progression.REP_STEPS) do
		if points >= need then
			lvl = i - 1
		end
	end
	return lvl
end

return Progression
