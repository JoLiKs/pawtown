--!strict
--[[
	NeedsLogic — чистые функции потребностей (клиент + сервер, покрыты тестами).
	Потребности 0..100: Hunger (сытость), Energy, Hygiene, Fun, Love (внимание хозяев), Health.
	Убывание мягкое (Config.NEED_EMPTY_MINUTES ~30–40 мин от полного до нуля), без жёстких наказаний:
	Health падает только когда 2+ потребности ниже 15, и восстанавливается, когда всё в порядке.
	Настроение (Mood) выводится из потребностей и влияет на XP и качество трюков.
]]
local Config = require(script.Parent.Config)

export type Needs = { [string]: number }

local NeedsLogic = {}

NeedsLogic.KEYS = { "Hunger", "Energy", "Hygiene", "Fun", "Love", "Health" }
NeedsLogic.DECAYING = { "Hunger", "Energy", "Hygiene", "Fun", "Love" }
NeedsLogic.LOW = 15

function NeedsLogic.default(): Needs
	return { Hunger = 80, Energy = 85, Hygiene = 80, Fun = 70, Love = 60, Health = 100 }
end

function NeedsLogic.clamp(v: any): number
	if type(v) ~= "number" or v ~= v then
		return 50
	end
	return math.clamp(v, 0, 100)
end

-- Нормализация (битые/отсутствующие значения)
function NeedsLogic.normalize(n: any): Needs
	local out = NeedsLogic.default()
	if type(n) == "table" then
		for _, k in ipairs(NeedsLogic.KEYS) do
			if n[k] ~= nil then
				out[k] = NeedsLogic.clamp(n[k])
			end
		end
	end
	return out
end

-- Скорость убывания (единиц в секунду) для потребности
function NeedsLogic.rate(key: string): number
	local minutes = Config.NEED_EMPTY_MINUTES[key]
	if not minutes then
		return 0
	end
	return 100 / (minutes * 60)
end

-- Сколько потребностей ниже порога
function NeedsLogic.lowCount(n: Needs): number
	local c = 0
	for _, k in ipairs(NeedsLogic.DECAYING) do
		if (n[k] or 0) < NeedsLogic.LOW then
			c += 1
		end
	end
	return c
end

-- Пересчёт за dt секунд. mods: { Sleeping = bool, Activity = 1 (множитель убывания) , Floor = минимум (офлайн) }
function NeedsLogic.step(n: Needs, dt: number, mods: { [string]: any }?): Needs
	local m = mods or {}
	local activity: number = m.Activity or 1
	local floor: number = m.Floor or 0
	for _, k in ipairs(NeedsLogic.DECAYING) do
		local r = NeedsLogic.rate(k) * activity
		if m.Sleeping and k == "Energy" then
			n[k] = math.min(100, n[k] + 10 * dt) -- во сне энергия быстро растёт
		elseif m.Sleeping and k == "Hunger" then
			n[k] = math.max(math.min(n[k], floor), n[k] - r * 0.5 * dt)
		else
			local before = n[k]
			n[k] = math.max(0, n[k] - r * dt)
			if before >= floor and n[k] < floor then
				n[k] = floor
			end
		end
	end
	local lows = NeedsLogic.lowCount(n)
	if lows >= 2 then
		n.Health = math.max(10, n.Health - Config.HEALTH_DECAY_PER_MIN / 60 * dt) -- здоровье не падает ниже 10
	elseif lows == 0 then
		n.Health = math.min(100, n.Health + Config.HEALTH_REGEN_PER_MIN / 60 * dt)
	end
	return n
end

-- Добавить к потребности (действие). Возвращает фактический прирост
function NeedsLogic.add(n: Needs, key: string, amount: number): number
	local before = n[key] or 0
	n[key] = math.clamp(before + amount, 0, 100)
	return n[key] - before
end

function NeedsLogic.average(n: Needs): number
	local s = 0
	for _, k in ipairs(NeedsLogic.KEYS) do
		s += n[k] or 0
	end
	return s / #NeedsLogic.KEYS
end

--[[ Настроение:
	Sad          — любая потребность < 15 или среднее < 35;
	Mischievous  — заскучал (Fun < 35), но полон сил (Energy > 60);
	Happy        — среднее >= 70 и всё >= 40;
	Normal       — иначе. ]]
function NeedsLogic.mood(n: Needs): string
	local avg = NeedsLogic.average(n)
	local minV = 100
	for _, k in ipairs(NeedsLogic.KEYS) do
		minV = math.min(minV, n[k] or 0)
	end
	if minV < NeedsLogic.LOW or avg < 35 then
		return "Sad"
	end
	if (n.Fun or 0) < 35 and (n.Energy or 0) > 60 then
		return "Mischievous"
	end
	if avg >= 70 and minV >= 40 then
		return "Happy"
	end
	return "Normal"
end

NeedsLogic.MOODS = {
	Happy = { Xp = 1.25, Trick = 1.15 },
	Normal = { Xp = 1.0, Trick = 1.0 },
	Mischievous = { Xp = 1.0, Trick = 0.9 },
	Sad = { Xp = 0.75, Trick = 0.85 },
}

function NeedsLogic.xpMult(mood: string): number
	local m = NeedsLogic.MOODS[mood]
	return if m then m.Xp else 1
end

function NeedsLogic.trickMult(mood: string): number
	local m = NeedsLogic.MOODS[mood]
	return if m then m.Trick else 1
end

-- Бонус «Сияние»: все потребности >= 80 -> +10% лакомств
function NeedsLogic.glowing(n: Needs): boolean
	for _, k in ipairs(NeedsLogic.KEYS) do
		if (n[k] or 0) < 80 then
			return false
		end
	end
	return true
end

-- Офлайн-пересчёт: максимум 8 часов, потребности не ниже Config.OFFLINE_NEED_FLOOR
function NeedsLogic.offline(n: Needs, seconds: number): Needs
	local dt = math.clamp(seconds, 0, 8 * 3600)
	if dt <= 0 then
		return n
	end
	for _, k in ipairs(NeedsLogic.DECAYING) do
		if n[k] > Config.OFFLINE_NEED_FLOOR then
			n[k] = math.max(Config.OFFLINE_NEED_FLOOR, n[k] - NeedsLogic.rate(k) * dt)
		end
	end
	return n
end

return NeedsLogic
