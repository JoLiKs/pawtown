--!strict
--[[
	RebirthLogic — перерождение «Ночь Искр» в редкий вид (чистые функции, покрыты тестами).

	Общие условия (COMMON): взрослый питомец, уровень 50, 20 осколков памяти, высокая привязанность семьи
	(сумма по трём членам), пройденное испытание вида (Trial). Плюс у каждого редкого вида — путь (From: из каких
	видов, когда-либо сыгранных — data.Lineage) и ветка талантов (Req: Nose/Agility/Charm, Gold — золотые медали).

	Что сохраняется: дружба, косметика, дом (подарки семьи и привязанность), репутация, осколки, звёзды
	перерождений (постоянный бонус к опыту и лакомствам), один унаследованный талант (бесплатно, со своими рангами).
	Что сбрасывается: уровень (возраст снова «малыш»), опыт, остальные таланты, потребности.
	Легендарные виды — пока «скоро».
]]
local NeedsLogic = require(script.Parent.NeedsLogic)
local Progression = require(script.Parent.Progression)
local SpeciesData = require(script.Parent.SpeciesData)
local TrickData = require(script.Parent.TrickData)
local WorldData = require(script.Parent.WorldData)

local RebirthLogic = {}

RebirthLogic.REQ_ORDER =
	{ "Path", "Age", "Level", "Nose", "Agility", "Charm", "Shards", "Bond", "Gold", "Trial" }
RebirthLogic.COMMON = { Age = 1, Level = 50, Shards = 20, Bond = 180, Trial = 1 }
RebirthLogic.AVAILABLE = true -- редкие виды (легендарные — нет)
RebirthLogic.STAR_BONUS = 0.1 -- +10% опыта и лакомств за звезду
RebirthLogic.MAX_STARS = 5

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _ in pairs(t) do
			n += 1
		end
	end
	return n
end

-- Доступно ли перерождение в этот вид сейчас (только редкие)
function RebirthLogic.available(speciesId: string): boolean
	return RebirthLogic.AVAILABLE and SpeciesData.isRare(speciesId)
end

-- Полный список требований вида: общие + собственные
function RebirthLogic.requirements(speciesId: string): { [string]: number }
	local s = SpeciesData.ById[speciesId]
	local out: { [string]: number } = {}
	if not s then
		return out
	end
	if s.Tier == "Rare" then
		for k, v in pairs(RebirthLogic.COMMON) do
			out[k] = v
		end
		out.Path = 1
	end
	for k, v in pairs(s.Req or {}) do
		out[k] = v
	end
	return out
end

-- Путь открыт: текущий или один из прошлых видов игрока входит в From
function RebirthLogic.pathOk(data: any, speciesId: string): boolean
	local s = SpeciesData.ById[speciesId]
	if not s or not s.From then
		return false
	end
	for _, from in ipairs(s.From) do
		if data.Species == from or (type(data.Lineage) == "table" and data.Lineage[from]) then
			return true
		end
	end
	return false
end

-- Текущее значение показателя для требований
function RebirthLogic.stat(data: any, key: string, speciesId: string?): number
	if key == "Level" then
		return data.Level or 1
	elseif key == "Age" then
		return if Progression.age(data.Level or 1) == "Adult" then 1 else 0
	elseif key == "Nose" or key == "Agility" or key == "Charm" then
		return Progression.branchPoints(data.Talents, key)
	elseif key == "Shards" then
		return count(data.Shards)
	elseif key == "Bond" then
		local s = 0
		for _, v in pairs(data.Bond or {}) do
			s += v
		end
		return math.floor(s)
	elseif key == "Gold" then
		local n = 0
		for _, t in pairs(data.Tricks or {}) do
			if type(t) == "table" and (t.Best or 0) >= 3 then
				n += 1
			end
		end
		return n
	elseif key == "Path" then
		return if speciesId and RebirthLogic.pathOk(data, speciesId) then 1 else 0
	elseif key == "Trial" then
		return if speciesId and type(data.Trials) == "table" and data.Trials[speciesId] then 1 else 0
	end
	return 0
end

-- { { Key, Need, Have, Ok } ... }, allOk
function RebirthLogic.check(data: any, speciesId: string): ({ { [string]: any } }, boolean)
	local out = {}
	local req = RebirthLogic.requirements(speciesId)
	if next(req) == nil then
		return out, false
	end
	local all = true
	for _, key in ipairs(RebirthLogic.REQ_ORDER) do
		local need = req[key]
		if need then
			local have = RebirthLogic.stat(data, key, speciesId)
			local ok = have >= need
			all = all and ok
			table.insert(out, { Key = key, Need = need, Have = have, Ok = ok })
		end
	end
	return out, all and RebirthLogic.available(speciesId)
end

-- Можно ли начать испытание вида: путь открыт, испытание ещё не пройдено, питомец взрослый
function RebirthLogic.canTrial(data: any, speciesId: string): (boolean, string?)
	if not RebirthLogic.available(speciesId) or not WorldData.Trials[speciesId] then
		return false, "err.bad_request"
	end
	if not RebirthLogic.pathOk(data, speciesId) then
		return false, "rebirth.need_path"
	end
	if data.Trials and data.Trials[speciesId] then
		return false, "rebirth.trial_done"
	end
	if Progression.age(data.Level or 1) ~= "Adult" then
		return false, "rebirth.need_adult"
	end
	return true, nil
end

function RebirthLogic.stars(data: any): number
	local n = if type(data.Stars) == "number" then data.Stars else 0
	return math.clamp(math.floor(n), 0, RebirthLogic.MAX_STARS)
end

-- Множитель опыта и лакомств от звёзд перерождений
function RebirthLogic.mult(data: any): number
	return 1 + RebirthLogic.STAR_BONUS * RebirthLogic.stars(data)
end

-- Таланты, которые можно унаследовать (ранг >= 1)
function RebirthLogic.inheritable(data: any): { string }
	local out = {}
	for id in pairs(Progression.Talents) do
		if Progression.rank(data.Talents, id) >= 1 then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Само перерождение (сервер вызывает после check). Меняет data на месте. -> ok, ошибка-ключ
function RebirthLogic.apply(data: any, speciesId: string, inherit: string?): (boolean, string?)
	local _, ok = RebirthLogic.check(data, speciesId)
	if not ok then
		return false, "rebirth.not_ready"
	end
	local rank = if inherit then Progression.rank(data.Talents, inherit) else 0
	if inherit and (not Progression.Talents[inherit] or rank < 1) then
		return false, "err.bad_request"
	end
	data.Lineage = if type(data.Lineage) == "table" then data.Lineage else {}
	if data.Species ~= "" then
		data.Lineage[data.Species] = true
	end
	data.Lineage[speciesId] = true
	data.Species = speciesId
	data.Level = 1
	data.Xp = 0
	data.Talents = {}
	if inherit then
		data.Talents[inherit] = rank
		data.Talents.Inherit = inherit
		data.Talents.InheritRank = rank
	end
	data.Needs = NeedsLogic.default()
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Stars = math.min(RebirthLogic.MAX_STARS, (data.Stars or 0) + 1)
	data.Trials = if type(data.Trials) == "table" then data.Trials else {}
	data.Trials[speciesId] = nil -- испытание «потрачено»: для следующего перерождения в этот вид — снова
	return true, nil
end

-- Только для разработки (Studio, Config.DEV_FAST_REBIRTH): выполнить все условия для вида
function RebirthLogic.fastTrack(data: any, speciesId: string)
	local req = RebirthLogic.requirements(speciesId)
	data.Level = math.max(data.Level or 1, req.Level or 50)
	data.Xp = 0
	for _, s in ipairs(WorldData.Shards) do
		if count(data.Shards) >= (req.Shards or 0) then
			break
		end
		data.Shards[s.Id] = true
	end
	for k in pairs(data.Bond) do
		data.Bond[k] = math.max(data.Bond[k], 70)
	end
	for _, branch in ipairs(Progression.Branches) do
		local need = req[branch] or 0
		local have = Progression.branchPoints(data.Talents, branch)
		for id, t in pairs(Progression.Talents) do
			if t.Branch == branch and have < need then
				local add = math.min(3 - Progression.rank(data.Talents, id), need - have)
				data.Talents[id] = Progression.rank(data.Talents, id) + add
				have += add
			end
		end
	end
	local gold = req.Gold or 0
	for _, t in ipairs(TrickData.List) do
		if RebirthLogic.stat(data, "Gold") >= gold then
			break
		end
		data.Tricks[t.Id] = { Best = 3, Plays = 1 }
	end
	local s = SpeciesData.ById[speciesId]
	if s and s.From and not RebirthLogic.pathOk(data, speciesId) then
		data.Lineage = if type(data.Lineage) == "table" then data.Lineage else {}
		data.Lineage[s.From[1]] = true
	end
	data.Trials = if type(data.Trials) == "table" then data.Trials else {}
	data.Trials[speciesId] = true
end

return RebirthLogic
