--!strict
--[[
	Progress — единая выдача наград: опыт (с множителем настроения), лакомства (Treats), привязанность, репутация.
	Повышение уровня: очки талантов, возрастная стадия (масштаб рига), эффект LevelUp.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local NeedsLogic = require(Shared.NeedsLogic)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local SpeciesData = require(Shared.SpeciesData)

local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)

local Progress = {}

-- Вызывается при смене возрастной стадии (PlayerService перестраивает риг)
Progress.onAgeChanged = nil :: ((Player) -> ())?
Progress.onLevel = nil :: ((Player, number) -> ())?

function Progress.xp(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local mood = NeedsLogic.mood(data.Needs)
	local gain = math.floor(amount * NeedsLogic.xpMult(mood) + 0.5)
	local oldAge = Progression.age(data.Level)
	local level, xp, gained = Progression.addXp(data.Level, data.Xp, gain)
	data.Level = level
	data.Xp = xp
	if gained > 0 then
		Remotes.getEvent("Fx"):FireClient(player, "LevelUp", level)
		Notify.send(player, Locale.m("toast.level_up", { n = level }), "reward")
		if Progress.onLevel then
			Progress.onLevel(player, level)
		end
		if Progression.age(level) ~= oldAge and Progress.onAgeChanged then
			Notify.send(player, Locale.m("toast.age_up", { age = "age." .. Progression.age(level) }), "reward")
			task.spawn(Progress.onAgeChanged, player)
		end
	end
	State.markCore(player)
	return gain
end

function Progress.treats(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local mult = if NeedsLogic.glowing(data.Needs) then 1.1 else 1
	local gain = math.floor(amount * mult + 0.5)
	data.Treats += gain
	data.TotalTreats += gain
	State.markCore(player)
	return gain
end

function Progress.spend(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount < 0 or data.Treats < amount then
		return false
	end
	data.Treats -= amount
	State.markCore(player)
	return true
end

-- Привязанность к члену семьи (вид Dog/BestBond и талант Puppy Eyes ускоряют)
function Progress.bond(player: Player, member: string, amount: number): number
	local data = DataService.get(player)
	if not data or data.Bond[member] == nil then
		return 0
	end
	local sp = SpeciesData.ById[data.Species]
	local mult = (if sp then sp.BondMult else 1) * (1 + Progression.bonus(data.Talents, "PuppyEyes"))
	local before = data.Bond[member]
	data.Bond[member] = math.min(100, before + amount * mult)
	State.markCore(player)
	return data.Bond[member] - before
end

function Progress.rep(player: Player, district: string, amount: number)
	local data = DataService.get(player)
	if not data or data.Rep[district] == nil then
		return
	end
	local before = Progression.repLevel(data.Rep[district])
	data.Rep[district] += amount
	local after = Progression.repLevel(data.Rep[district])
	if after > before then
		Notify.send(player, Locale.m("toast.rep_up", { place = "place." .. district, n = after }), "reward")
	end
	State.markCore(player)
end

function Progress.stat(player: Player, key: string, n: number?)
	local data = DataService.get(player)
	if data then
		data.Stats[key] = (data.Stats[key] or 0) + (n or 1)
	end
end

-- Награда одним сообщением: { Treats, Xp }
function Progress.reward(player: Player, r: { [string]: any }, reasonKey: string?)
	local t = if r.Treats then Progress.treats(player, r.Treats) else 0
	local x = if r.Xp then Progress.xp(player, r.Xp) else 0
	if reasonKey then
		Notify.send(player, Locale.m("toast.reward", { what = reasonKey, t = t, x = x }), "reward")
	end
end

return Progress
