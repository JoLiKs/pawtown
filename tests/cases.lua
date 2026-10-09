-- ============================================================================
-- Тест-кейсы логики Pawtown (запускаются в `luau` поверх эмуляции из prelude.lua)
-- ============================================================================
local passed, failed = 0, 0
local failures = {}
local function check(cond, msg)
	if cond then
		passed += 1
	else
		failed += 1
		table.insert(failures, msg)
		print("  FAIL: " .. msg)
	end
end
local function test(name, fn)
	print("• " .. name)
	RESET_SCHEDULER()
	local co = coroutine.create(function()
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			failed += 1
			table.insert(failures, name .. " (exception)")
			print("  EXCEPTION: " .. tostring(err))
		end
	end)
	coroutine.resume(co)
	DRIVE_UNTIL_IDLE(400)
end

local function boot(label, opts)
	opts = opts or {}
	local U = MAKE_UNIVERSE(label)
	U.IsStudio = opts.studio == true
	for path, fn in pairs(SOURCES) do
		U.register(path, fn)
	end
	local function req(p)
		return U.require(p)
	end
	local prev = game
	game = U.Game
	local S = { U = U, req = req }
	for _, name in ipairs({
		"Config",
		"Util",
		"Locale",
		"LocaleEn",
		"LocaleRu",
		"NeedsLogic",
		"Progression",
		"TrickData",
		"QuestData",
		"ShopData",
		"FamilyData",
		"WorldData",
		"SpeciesData",
		"RebirthLogic",
		"DayNight",
		"UiGeometry",
	}) do
		S[name] = req("ReplicatedStorage/Shared/" .. name)
	end
	S.Migrations = req("ServerScriptService/Server/Migrations")
	S.Data = req("ServerScriptService/Server/DataService")
	S.Session = req("ServerScriptService/Server/Session")
	S.Layout = req("ReplicatedStorage/Client/Layout")
	game = prev
	return S
end

local S0 = boot("Static")

-- ============================================================================
test("NeedsLogic: шаблон, распад ~30–40 мин, сон, пол, здоровье", function()
	local N, C = S0.NeedsLogic, S0.Config
	local n = N.default()
	for _, k in ipairs(N.KEYS) do
		check(n[k] >= 50 and n[k] <= 100, "default " .. k .. " in 50..100")
	end
	local function full()
		local f = N.default()
		for _, k in ipairs(N.KEYS) do
			f[k] = 100
		end
		return f
	end
	for key, minutes in pairs(C.NEED_EMPTY_MINUTES) do
		check(minutes >= 30 and minutes <= 40, key .. " empties in 30-40 min")
		local m = full()
		N.step(m, minutes * 60 * 0.5)
		check(math.abs(m[key] - 50) < 1.5, key .. " half after half time: " .. tostring(m[key]))
	end
	local m = N.default()
	m.Energy = 20
	N.step(m, 5, { Sleeping = true })
	check(m.Energy > 60, "sleep refills energy quickly")
	local f = N.default()
	N.step(f, 3600, { Floor = 25 })
	check(f.Hunger == 25, "floor holds needs (soft punishment)")
	local h = N.default()
	h.Hunger, h.Fun = 0, 0
	N.step(h, 3600 * 10)
	check(h.Health >= 10, "health never below 10")
	check(N.add(full(), "Hunger", 50) == 0, "add clamps at 100")
end)

test("NeedsLogic: настроение, сияние, офлайн-пересчёт", function()
	local N = S0.NeedsLogic
	local n = N.default()
	for _, k in ipairs(N.KEYS) do
		n[k] = 100
	end
	check(N.mood(n) == "Happy", "all full -> Happy")
	check(N.glowing(n), "all >= 80 -> glowing bonus")
	n.Hunger = 5
	check(N.mood(n) == "Sad", "one need < 15 -> Sad")
	local m = N.default()
	m.Energy = 90
	m.Fun = 20
	check(N.mood(m) == "Mischievous", "low fun, high energy -> Mischievous")
	check(N.xpMult("Happy") > N.xpMult("Normal") and N.xpMult("Sad") < 1, "mood xp multipliers")
	local o = N.default()
	N.offline(o, 30 * 24 * 3600)
	check(o.Hunger == S0.Config.OFFLINE_NEED_FLOOR, "offline: floored, not zero")
	local low = N.default()
	low.Fun = 10
	N.offline(low, 3600)
	check(low.Fun == 10, "offline never lowers a need already below floor")
	local nn = N.normalize({ Hunger = "x", Energy = -5, Fun = 1 / 0 })
	check(nn.Hunger == 50 and nn.Energy == 0 and nn.Fun == 100 and nn.Health == 100, "normalize bad values")
end)

test("Progression: опыт, уровни, возраст, таланты, репутация", function()
	local P = S0.Progression
	local prev = 0
	for l = 1, 99 do
		local x = P.xpFor(l)
		check(x > prev, "xpFor increasing at " .. l)
		prev = x
		if x <= prev - 1 then
			break
		end
	end
	local lvl, xp, ups = P.addXp(1, 0, P.xpFor(1) + P.xpFor(2) + 5)
	check(lvl == 3 and xp == 5 and ups == 2, "addXp multi-level " .. lvl .. "/" .. xp)
	local l2 = P.addXp(100, 0, 10 ^ 7)
	check(l2 == 100, "level capped at 100")
	check(P.age(1) == "Baby" and P.age(10) == "Teen" and P.age(30) == "Adult", "age stages")
	check(P.talentPointsTotal(1) == 0 and P.talentPointsTotal(5) == 4, "talent points per level")
	local t = {}
	local ok, why = P.canLearn(1, t, "KeenNose")
	check(not ok and why == "talent.no_points", "no points at level 1")
	ok, why = P.canLearn(5, t, "TreasureHunter")
	check(not ok and why == "talent.locked", "second talent locked until first")
	check(P.canLearn(5, t, "KeenNose") == true, "first talent learnable")
	t.KeenNose = 3
	ok, why = P.canLearn(10, t, "KeenNose")
	check(not ok and why == "talent.maxed", "max rank")
	check(P.canLearn(10, t, "TreasureHunter") == true, "second unlocked after first")
	check(P.branchPoints(t, "Nose") == 3 and P.spent(t) == 3, "branch/spent points")
	check(P.repLevel(0) == 0 and P.repLevel(95) == 2 and P.repLevel(10000) == 4, "reputation levels")
	-- каждая ветка ровно из 2 талантов
	local per = {}
	for _, tal in pairs(P.Talents) do
		per[tal.Branch] = (per[tal.Branch] or 0) + 1
	end
	check(per.Nose == 2 and per.Agility == 2 and per.Charm == 2, "2 talents per branch")
end)

test("TrickData: детерминированный ритм, оценка и медали", function()
	local T = S0.TrickData
	check(#T.List == 5, "5 tricks")
	for _, t in ipairs(T.List) do
		local a, b = T.pattern(t.Id, 12345), T.pattern(t.Id, 12345)
		check(#a == t.Beats, t.Id .. " beats count")
		local same, inc = true, true
		for i = 1, #a do
			same = same and a[i] == b[i]
			if i > 1 then
				inc = inc and a[i] > a[i - 1]
			end
		end
		check(same and inc, t.Id .. " deterministic & increasing")
		check(T.duration(t.Id, 12345) == a[#a], t.Id .. " duration")
	end
	local perfect, miss, half = {}, {}, {}
	for i = 1, 6 do
		perfect[i] = 0.01
		miss[i] = false
		half[i] = if i % 2 == 0 then 0.0 else false
	end
	local s1, m1 = T.grade(perfect, 6)
	check(s1 == 1 and m1 == 3, "perfect -> gold")
	local s2, m2 = T.grade(miss, 6)
	check(s2 == 0 and m2 == 0, "all miss -> no medal")
	local s3, m3 = T.grade(half, 6)
	check(s3 == 0.5 and m3 == 1, "half -> bronze")
	local _, mw = T.grade({ 0.2, 0.2, 0.2, 0.2 }, 4, 1.0)
	local _, mw2 = T.grade({ 0.2, 0.2, 0.2, 0.2 }, 4, 2.5)
	check(mw2 > mw, "window multiplier (mood/talent) helps")
	check(T.judge(0.05) == "perfect" and T.judge(0.5) == "miss", "judge")
end)

test("QuestData: глава 1 и 5 ежедневных заданий", function()
	local Q = S0.QuestData
	local ids = {}
	for _, s in ipairs(Q.CHAPTER1) do
		ids[s.Id] = true
	end
	for _, id in ipairs({ "c1_species", "c1_home", "c1_trick", "c1_family", "c1_shards", "c1_dream" }) do
		check(ids[id], "chapter has " .. id)
	end
	local a = Q.pickDaily(100, 7)
	local b = Q.pickDaily(100, 7)
	check(#a == Q.DAILY_COUNT and Q.DAILY_COUNT == 5, "5 daily tasks")
	local uniq, same = {}, true
	for i, id in ipairs(a) do
		check(Q.DAILY_BY_ID[id] ~= nil, "daily id exists " .. tostring(id))
		check(not uniq[id], "daily unique " .. tostring(id))
		uniq[id] = true
		same = same and b[i] == id
	end
	check(same, "pickDaily deterministic")
	local differs = false
	for d = 101, 110 do
		local c = Q.pickDaily(d, 7)
		for i = 1, #c do
			if c[i] ~= a[i] then
				differs = true
			end
		end
	end
	check(differs, "daily set changes between days")
	check(Q.dayNumber(86400 * 3 + 5) == 3, "day number")
end)

test(
	"SpeciesData и RebirthLogic: 4 стандартных вида, редкие — только по условиям (скоро)",
	function()
		local Sp, R = S0.SpeciesData, S0.RebirthLogic
		check(#Sp.Standard == 4, "4 standard species")
		for _, id in ipairs({ "Cat", "Dog", "Rabbit", "Parrot" }) do
			check(Sp.isStandard(id), id .. " standard")
		end
		check(
			Sp.has("Cat", "DoubleJump")
				and Sp.has("Dog", "Dig")
				and Sp.has("Rabbit", "Burrow")
				and Sp.has("Parrot", "Glide"),
			"core abilities"
		)
		check(not Sp.isStandard("MidnightCat") and not Sp.isStandard("Nope"), "rare not choosable")
		local order = {}
		for _, k in ipairs(R.REQ_ORDER) do
			order[k] = true
		end
		for _, sp in ipairs(Sp.List) do
			for _, ab in ipairs(sp.Abilities) do
				check(Sp.Abilities[ab] ~= nil, sp.Id .. " ability " .. ab .. " defined")
			end
			if sp.Tier ~= "Standard" then
				check(sp.Req ~= nil, sp.Id .. " has requirements")
				for k in pairs(sp.Req or {}) do
					check(order[k], sp.Id .. " req key " .. k)
				end
			end
		end
		check(R.AVAILABLE == true and R.available("Fox") and not R.available("MidnightCat"), "rare only")
		local data = {
			Species = "Dog",
			Level = 30,
			Talents = { KeenNose = 3, TreasureHunter = 1 },
			Shards = { a = true, b = true },
			Bond = { Dad = 50 },
			Tricks = { Sit = { Best = 3 } },
			Lineage = {},
			Trials = {},
		}
		local list, all = R.check(data, "Fox")
		check(#list == 7 and not all, "Fox: path + 5 common + Nose, not all met")
		check(list[1].Key == "Path" and list[1].Ok, "Dog -> Fox path open")
		check(list[2].Key == "Age" and list[2].Ok, "adult at 30")
		check(list[3].Key == "Level" and not list[3].Ok and list[3].Need == 50, "level 50 needed")
		check(R.stat(data, "Gold") == 1 and R.stat(data, "Bond") == 50, "stats")
		check(not R.pathOk(data, "SnowLeopard") and not R.pathOk(data, "Owl"), "Dog has no cat/parrot path")
		data.Lineage.Cat = true
		check(R.pathOk(data, "SnowLeopard"), "lineage opens path")
		for _, sp in ipairs(Sp.List) do
			if sp.Tier == "Rare" then
				check(sp.From ~= nil and #sp.From > 0, sp.Id .. " has path")
				check(S0.WorldData.Trials[sp.Id] ~= nil, sp.Id .. " has trial")
				check(#Sp.Abilities[sp.Abilities[1]].Name > 0, sp.Id .. " ability")
			end
		end
	end
)

test(
	"RebirthLogic: ускоренные условия, перерождение, что сохраняется, звёзды и наследуемый талант",
	function()
		local R, P = S0.RebirthLogic, S0.Progression
		local data = {
			Species = "Cat",
			Level = 12,
			Xp = 5,
			Talents = { LightPaws = 2 },
			Shards = { s_home = true },
			Bond = { Dad = 10, Grandma = 10, Kid = 10 },
			Tricks = {},
			Rep = { Street = 33, Park = 7 },
			Cosmetics = { Owned = { BlueCollar = true }, Equipped = { Collar = "BlueCollar" } },
			Friends = { ["42"] = 5 },
			FriendList = { ["42"] = { Name = "Ann", Since = 1 } },
			Lineage = {},
			Trials = {},
			Needs = {},
			Rebirths = 0,
			Stars = 0,
		}
		local ok0 = R.canTrial(data, "SnowLeopard")
		check(not ok0, "trial needs adult")
		check(select(2, R.check(data, "SnowLeopard")) == false, "not ready")
		R.fastTrack(data, "SnowLeopard")
		local list, all = R.check(data, "SnowLeopard")
		check(all, "fast-track meets all requirements")
		for _, r in ipairs(list) do
			check(r.Ok, "req ok " .. r.Key)
		end
		check(R.stat(data, "Shards") >= 20 and data.Level >= 50, "20 shards, level 50")
		check(not R.apply(data, "Owl", nil), "wrong path refused")
		check(not R.apply(data, "SnowLeopard", "KeenNose"), "cannot inherit unlearned talent")
		local ok = R.apply(data, "SnowLeopard", "LightPaws")
		check(ok, "rebirth applied")
		check(data.Species == "SnowLeopard" and data.Level == 1 and data.Xp == 0, "level reset")
		check(P.age(data.Level) == "Baby", "baby again")
		check(data.Lineage.Cat and data.Lineage.SnowLeopard, "lineage kept")
		check(data.Rebirths == 1 and R.stars(data) == 1, "star +1")
		check(math.abs(R.mult(data) - 1.1) < 1e-9, "+10% bonus")
		check(data.Rep.Street == 33 and data.Cosmetics.Owned.BlueCollar, "rep and cosmetics kept")
		check(data.FriendList["42"] ~= nil and data.Friends["42"] == 5, "friends kept")
		check(R.stat(data, "Shards") >= 20, "shards kept")
		check(data.Bond.Dad >= 70, "family bond kept")
		local inhRank = P.rank(data.Talents, "LightPaws")
		check(inhRank >= 2, "inherited talent rank kept")
		check(P.spent(data.Talents) == 0, "inherited talent is free")
		check(P.rank(data.Talents, "SpringLegs") == 0, "other talents reset")
		check(not data.Trials.SnowLeopard, "trial consumed")
		for _ = 1, 10 do
			data.Stars += 1
		end
		check(R.stars(data) == R.MAX_STARS, "stars capped")
	end
)

test(
	"Экономика: только косметика за лакомства, подарки семьи существуют",
	function()
		local Sh, F = S0.ShopData, S0.FamilyData
		for _, it in ipairs(Sh.List) do
			check(it.Price > 0 and table.find(Sh.SLOTS, it.Slot) ~= nil, it.Id .. " price/slot")
			check(it.Robux == nil and it.Odds == nil, it.Id .. " no robux / no random")
		end
		for _, m in ipairs(F.List) do
			for _, g in ipairs(m.Gifts) do
				check(g.Item == nil or Sh.ById[g.Item] ~= nil, m.Id .. " gift item exists")
			end
		end
		check(F.bondTier(0) == 0 and F.bondTier(55) == 2, "bond tiers")
	end
)

test("WorldData: зоны, осколки, ямки, лазы", function()
	local W = S0.WorldData
	check(W.zoneAt(W.SPAWN_SHELTER) == "Shelter", "shelter spawn in Shelter")
	check(W.zoneAt(W.SPAWN_HOME) == "Home", "home spawn in Home")
	local ids = {}
	for _, s in ipairs(W.Shards) do
		check(not ids[s.Id], "unique shard " .. s.Id)
		ids[s.Id] = true
	end
	check(#W.Shards >= 3, "enough shards for chapter 1")
	for _, d in ipairs(W.DigSpots) do
		check(d.Shard == "" or ids[d.Shard], "dig spot shard exists")
	end
	check(#W.Agility.Checkpoints == 6, "6 agility gates")
end)

test("DayNight: длина суток, ночь, утро", function()
	local D = S0.DayNight
	check(D.length(false) > D.length(true) or D.length(true) > 0, "day length")
	local L = D.length(false)
	check(math.abs(D.clock(0, L) - 8) < 1e-6, "starts at 8:00")
	check(D.isNight(22) and D.isNight(3) and not D.isNight(12), "night hours")
	check(
		math.abs(D.secondsToMorning(22, L) - 9 / 24 * L) < 1e-6 and D.secondsToMorning(7, L) == 0,
		"seconds to morning"
	)
end)

test("Migrations: v1 -> v2 и починка битых данных", function()
	local M = S0.Migrations
	local d = {
		Coins = 77,
		Bond = { 10, 20, 30 },
		Needs = { Hunger = 50 },
		Species = "Dragon",
		Settings = { Lang = "de" },
		Level = -3,
		Xp = 0 / 0,
	}
	local changed = M.run(d)
	check(changed, "changed")
	check(d.Version == 3 and d.Treats == 77 and d.Coins == nil, "coins -> treats")
	check(type(d.Lineage) == "table" and type(d.Trials) == "table" and d.Stars == 0, "v3 rebirth fields")
	check(d.Bond.Dad == 10 and d.Bond.Kid == 30, "bond array -> map")
	check(d.Needs.Hunger == 50 and d.Needs.Health == 100, "needs normalized")
	check(d.Species == "", "unknown species reset to choice")
	check(d.Settings.Lang == "auto", "bad lang reset")
	check(d.Level == 1 and d.Xp == 0, "bad numbers fixed")
	local d2 = {
		Version = 2,
		Bond = { Dad = 500 },
		Needs = S0.NeedsLogic.default(),
		Settings = { Lang = "ru" },
		Species = "Cat",
	}
	M.run(d2)
	check(d2.Bond.Dad == 100 and d2.Species == "Cat" and d2.Settings.Lang == "ru", "bond capped, valid kept")
end)

-- ============================================================================
test(
	"DataService: новый игрок получает шаблон, блокировка записывается",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local data, err = S.Data.load(MAKE_PLAYER(S.U, 1, "Alice"))
		check(data ~= nil and err == nil, "loaded new profile")
		check(
			data.Species == ""
				and data.Level == 1
				and data.Treats == 0
				and data.Version == S.Migrations.CURRENT,
			"template defaults"
		)
		check(data.Needs.Health == 100 and data.Bond.Dad == 0 and data.Story.Step == 1, "needs/bond/story")
		local rec = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_1"]
		check(
			rec ~= nil and rec.Lock ~= nil and rec.Lock.SessionId == S.Data.SESSION_ID,
			"lock written to store"
		)
	end
)

test(
	"DataService: сохранение, повторная загрузка, reconcile и миграция",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local p = MAKE_PLAYER(S.U, 2, "Bob")
		local data = S.Data.load(p)
		data.Treats = 4242
		data.Species = "Dog"
		S.Data.release(p)
		local rec = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_2"]
		check(rec.Lock == nil, "lock released")
		check(rec.Data.Treats == 4242, "treats persisted")
		rec.Data.Cosmetics = nil
		rec.Data.Version = 1
		rec.Data.Coins = 5
		local d2 = S.Data.load(MAKE_PLAYER(S.U, 2, "Bob"))
		check(d2.Treats == 4242 and d2.Species == "Dog", "data restored")
		check(d2.Cosmetics ~= nil and d2.Cosmetics.Equipped.Hat == "", "missing fields reconciled")
		check(d2.Version == S.Migrations.CURRENT and d2.Coins == nil, "migrated")
	end
)

test(
	"DataService: session lock между серверами и «мёртвая» блокировка",
	function()
		BACKEND.Stores = {}
		local A = boot("A")
		local B = boot("B")
		B.Config.LOAD_ATTEMPTS = 3
		B.Config.LOAD_LOCK_RETRY_DELAY = 1
		local pa = MAKE_PLAYER(A.U, 3, "Carol")
		local da = A.Data.load(pa)
		da.Treats = 777
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(60)
				if alive then
					A.Data.saveNow(pa)
				end
			end
		end)
		local db, err = B.Data.load(MAKE_PLAYER(B.U, 3, "Carol"))
		alive = false
		check(db == nil, "server B cannot load while A holds lock")
		check(err ~= nil and string.find(err, "locked") ~= nil, "reason mentions lock: " .. tostring(err))
		A.Data.release(pa)
		local db2 = B.Data.load(MAKE_PLAYER(B.U, 3, "Carol"))
		check(db2 ~= nil and db2.Treats == 777, "B loads A's latest data after release")
		-- упавший сервер
		BACKEND.Stores = {}
		local C = boot("C")
		local D = boot("D")
		local pc = MAKE_PLAYER(C.U, 4, "Dan")
		local dc = C.Data.load(pc)
		dc.Treats = 55
		C.Data.saveNow(pc)
		ADVANCE(D.Config.SESSION_LOCK_TIMEOUT + 5)
		local dd = D.Data.load(MAKE_PLAYER(D.U, 4, "Dan"))
		check(dd ~= nil and dd.Treats == 55, "stale lock taken over")
		-- проснувшийся старый сервер не затирает данные
		dd.Treats = 999
		dc.Treats = 123456
		check(C.Data.saveNow(pc) == false and pc.Kicked ~= nil, "stale server save rejected and kicked")
	end
)

-- ============================================================================
test(
	"Локализация: EN/RU одинаковые ключи и подстановки, данные переведены",
	function()
		local en, ru = S0.LocaleEn.Strings, S0.LocaleRu.Strings
		local function holders(s)
			local out = {}
			for name in string.gmatch(s, "{([%w_]+)") do
				out[name] = true
			end
			return out
		end
		for k, v in pairs(en) do
			check(ru[k] ~= nil, "ru has " .. k)
			if ru[k] then
				for h in pairs(holders(v)) do
					check(holders(ru[k])[h], k .. " ru keeps {" .. h .. "}")
				end
			end
		end
		for k in pairs(ru) do
			check(en[k] ~= nil, "en has " .. k)
		end
		local names = S0.LocaleRu.Names
		local function needName(text, where)
			check(names[text] ~= nil, "RU name for '" .. text .. "' (" .. where .. ")")
		end
		for _, sp in ipairs(S0.SpeciesData.List) do
			needName(sp.Name, sp.Id)
			needName(sp.Desc, sp.Id)
			check(en["tier." .. sp.Tier] ~= nil or sp.Tier == "Standard", "tier key " .. sp.Tier)
		end
		for _, ab in pairs(S0.SpeciesData.Abilities) do
			needName(ab.Name, ab.Id)
			needName(ab.Desc, ab.Id)
		end
		for _, t in pairs(S0.Progression.Talents) do
			needName(t.Name, t.Id)
			needName(t.Desc, t.Id)
		end
		for _, t in ipairs(S0.TrickData.List) do
			needName(t.Name, t.Id)
		end
		for _, it in ipairs(S0.ShopData.List) do
			needName(it.Name, it.Id)
			check(en["shop.slot." .. it.Slot] ~= nil, "slot key " .. it.Slot)
		end
		for _, s in ipairs(S0.QuestData.CHAPTER1) do
			check(en["quest." .. s.Id] ~= nil, "quest key " .. s.Id)
		end
		for _, d in ipairs(S0.QuestData.DAILY_POOL) do
			check(en["daily." .. d.Id] ~= nil, "daily key " .. d.Id)
		end
		for _, m in ipairs(S0.FamilyData.List) do
			check(en["npc." .. m.Id] ~= nil, "npc key " .. m.Id)
			check(en["speech." .. m.Id .. ".busy"] ~= nil, "busy line " .. m.Id)
			for i = 1, m.Lines do
				check(en["speech." .. m.Id .. "." .. i] ~= nil, "line " .. m.Id .. i)
			end
		end
		for _, k in ipairs(S0.RebirthLogic.REQ_ORDER) do
			check(en["req." .. k] ~= nil, "req key " .. k)
		end
		for _, k in ipairs({ "Happy", "Normal", "Sad", "Mischievous" }) do
			check(en["mood." .. k] ~= nil, "mood key " .. k)
		end
		-- плюрализация/формат
		check(S0.Locale.get("ru", "toast.level_up", { n = 5 }) == "Уровень 5!", "ru format")
		check(S0.Locale.get("en", "msg.shard_found", { n = 1, total = 8 }) ~= nil, "en format")
		check(S0.Locale.nameIn("ru", "Cat") == "Кошка", "names translation")
		-- без эмодзи в строках интерфейса
		local emoji = false
		for _, tbl in ipairs({ en, ru }) do
			for _, v in pairs(tbl) do
				for _, cp in utf8.codes(v) do
					if cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF) then
						emoji = true
					end
				end
			end
		end
		check(not emoji, "no emoji in UI strings")
	end
)

test("Layout и UiGeometry: режимы экрана, минимальный текст", function()
	check(S0.Layout.modeFor(1280, 720) == "wide", "pc wide")
	check(S0.Layout.modeFor(390, 844) == "portrait", "phone portrait")
	check(S0.Layout.modeFor(844, 390) == "landscape", "phone landscape")
	check(S0.UiGeometry.minText(0.8) * 0.8 >= 12, "panel body text >= 12 px")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	for _, f in ipairs(failures) do
		print(" - " .. f)
	end
	error("TESTS FAILED")
end
