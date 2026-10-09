--!strict
--[[
	TrickData + логика ритм-мини-игры трюков (чистые функции, покрыты тестами).
	Сервер выдаёт seed, клиент показывает ноты по TrickData.pattern(id, seed) и отправляет отклонения нажатий
	от каждой ноты (секунды). Сервер сам считает оценку (TrickData.grade) и медаль: бронза/серебро/золото.
]]
local TrickData = {}

export type Trick = {
	Id: string,
	Name: string,
	Level: number,
	Beats: number,
	Interval: number,
	Xp: number,
	Treats: number,
	Order: number,
}

TrickData.List = {
	{ Id = "Sit", Name = "Sit", Level = 1, Beats = 4, Interval = 0.85, Xp = 20, Treats = 6, Order = 1 },
	{ Id = "Paw", Name = "Paw", Level = 2, Beats = 5, Interval = 0.8, Xp = 26, Treats = 8, Order = 2 },
	{
		Id = "Roll",
		Name = "Roll Over",
		Level = 4,
		Beats = 6,
		Interval = 0.75,
		Xp = 34,
		Treats = 10,
		Order = 3,
	},
	{
		Id = "PlayDead",
		Name = "Play Dead",
		Level = 6,
		Beats = 6,
		Interval = 0.7,
		Xp = 40,
		Treats = 12,
		Order = 4,
	},
	{ Id = "Spin", Name = "Spin", Level = 8, Beats = 7, Interval = 0.65, Xp = 48, Treats = 14, Order = 5 },
} :: { Trick }

TrickData.ById = {} :: { [string]: Trick }
for _, t in ipairs(TrickData.List) do
	TrickData.ById[t.Id] = t
end

TrickData.LEAD = 1.2 -- секунды до первой ноты
TrickData.WINDOW_PERFECT = 0.09
TrickData.WINDOW_GOOD = 0.18
TrickData.WINDOW_OK = 0.3
TrickData.MEDALS = { "Bronze", "Silver", "Gold" }
TrickData.MEDAL_SCORE = { 0.45, 0.72, 0.9 }

-- Детерминированный ГПСЧ (одинаково на клиенте и сервере)
local function lcg(seed: number): () -> number
	local s = (math.floor(seed) % 2147483646) + 1
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

-- Время каждой ноты от старта (секунды). Иногда «двойная» нота (половина интервала) — ритм не монотонный.
function TrickData.pattern(id: string, seed: number): { number }
	local t = TrickData.ById[id]
	if not t then
		return {}
	end
	local rnd = lcg(seed)
	local out = {}
	local time = TrickData.LEAD
	for i = 1, t.Beats do
		table.insert(out, math.floor(time * 1000 + 0.5) / 1000)
		local step = t.Interval
		if i > 1 and i < t.Beats and rnd() < 0.3 then
			step = t.Interval * 0.5
		elseif rnd() < 0.2 then
			step = t.Interval * 1.5
		end
		time += step
	end
	return out
end

-- Длительность (последняя нота)
function TrickData.duration(id: string, seed: number): number
	local p = TrickData.pattern(id, seed)
	return p[#p] or 0
end

-- Оценка: errors[i] — отклонение нажатия от i-й ноты (сек, знак не важен), nil/false = промах.
-- windowMult > 1 расширяет окна (настроение «Счастлив», талант Showstopper).
function TrickData.grade(errors: { any }, beats: number, windowMult: number?): (number, number)
	local k = windowMult or 1
	local sum = 0
	for i = 1, beats do
		local e = errors[i]
		if type(e) == "number" and e == e then
			local a = math.abs(e)
			if a <= TrickData.WINDOW_PERFECT * k then
				sum += 1
			elseif a <= TrickData.WINDOW_GOOD * k then
				sum += 0.6
			elseif a <= TrickData.WINDOW_OK * k then
				sum += 0.25
			end
		end
	end
	local score = if beats > 0 then sum / beats else 0
	local medal = 0
	for i, need in ipairs(TrickData.MEDAL_SCORE) do
		if score >= need - 1e-9 then
			medal = i
		end
	end
	return score, medal
end

-- Оценка одного нажатия (для подсветки на клиенте): "perfect" | "good" | "ok" | "miss"
function TrickData.judge(err: number, windowMult: number?): string
	local k = windowMult or 1
	local a = math.abs(err)
	if a <= TrickData.WINDOW_PERFECT * k then
		return "perfect"
	elseif a <= TrickData.WINDOW_GOOD * k then
		return "good"
	elseif a <= TrickData.WINDOW_OK * k then
		return "ok"
	end
	return "miss"
end

return TrickData
