--!strict
--[[
	QuestData — глава 1 «Новый дом» и ежедневные задания.
	Шаг главы: Kind — событие (QuestService.event(player, kind, key)), Need — сколько раз (или разных key при Distinct).
	Награды: Treats + Xp. Тексты — ключи локализации quest.<Id> / quest.<Id>.hint.
]]
local QuestData = {}

export type Step = {
	Id: string,
	Kind: string,
	Need: number,
	Distinct: boolean?,
	Treats: number,
	Xp: number,
	Target: string?,
}

QuestData.CHAPTER1 = {
	{ Id = "c1_species", Kind = "species", Need = 1, Treats = 0, Xp = 0, Target = "Shelter" },
	{ Id = "c1_home", Kind = "arrive_home", Need = 1, Treats = 20, Xp = 30, Target = "Home" },
	{ Id = "c1_eat", Kind = "eat", Need = 1, Treats = 10, Xp = 25, Target = "Bowl" },
	{ Id = "c1_trick", Kind = "trick", Need = 1, Treats = 20, Xp = 40, Target = "Home" },
	{ Id = "c1_family", Kind = "cuddle", Need = 3, Distinct = true, Treats = 30, Xp = 60, Target = "Family" },
	{ Id = "c1_shards", Kind = "shard", Need = 3, Treats = 50, Xp = 90, Target = "Shard" },
	{ Id = "c1_dream", Kind = "dream", Need = 1, Treats = 80, Xp = 120, Target = "Bed" },
} :: { Step }

QuestData.ById = {} :: { [string]: Step }
for _, s in ipairs(QuestData.CHAPTER1) do
	QuestData.ById[s.Id] = s
end

-- Ежедневные задания: каждый день 5 из пула (детерминированно по дню и игроку)
export type Daily = {
	Id: string,
	Kind: string,
	Need: number,
	Treats: number,
	Xp: number,
	Rep: string?,
	RepPts: number?,
}
QuestData.DAILY_POOL = {
	{ Id = "d_newspaper", Kind = "newspaper", Need = 1, Treats = 25, Xp = 40, Rep = "Street", RepPts = 10 },
	{ Id = "d_lost_toy", Kind = "lost_toy", Need = 1, Treats = 30, Xp = 45, Rep = "Street", RepPts = 10 },
	{ Id = "d_wake", Kind = "wake", Need = 1, Treats = 15, Xp = 30 },
	{ Id = "d_fetch", Kind = "fetch", Need = 3, Treats = 30, Xp = 50, Rep = "Park", RepPts = 10 },
	{ Id = "d_tricks", Kind = "trick_silver", Need = 2, Treats = 30, Xp = 50 },
	{ Id = "d_bath", Kind = "bath", Need = 1, Treats = 20, Xp = 35 },
	{ Id = "d_mailman", Kind = "greet_mailman", Need = 1, Treats = 15, Xp = 30, Rep = "Street", RepPts = 8 },
	{ Id = "d_agility", Kind = "agility", Need = 1, Treats = 35, Xp = 55, Rep = "Park", RepPts = 12 },
} :: { Daily }
QuestData.DAILY_COUNT = 5
QuestData.DAILY_BY_ID = {} :: { [string]: Daily }
for _, d in ipairs(QuestData.DAILY_POOL) do
	QuestData.DAILY_BY_ID[d.Id] = d
end

-- Номер дня (UTC)
function QuestData.dayNumber(unix: number): number
	return math.floor(unix / 86400)
end

-- 5 разных заданий на день: детерминированно (seed = день * 7919 + userId)
function QuestData.pickDaily(day: number, userId: number): { string }
	local ids = {}
	for _, d in ipairs(QuestData.DAILY_POOL) do
		table.insert(ids, d.Id)
	end
	local s = (day * 7919 + math.abs(userId)) % 2147483646 + 1
	local function rnd(n: number): number
		s = (s * 48271) % 2147483647
		return (s % n) + 1
	end
	for i = #ids, 2, -1 do
		local j = rnd(i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local out = {}
	for i = 1, QuestData.DAILY_COUNT do
		table.insert(out, ids[i])
	end
	return out
end

return QuestData
