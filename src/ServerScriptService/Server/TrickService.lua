--!strict
--[[
	TrickService — трюки через ритм-мини-игру (TrickData). Сервер:
	  * TrickStart(id): трюк изучен (уровень), питомец не спит -> seed ноты;
	  * TrickFinish(id, errors): тот же трюк, прошло не меньше длительности мелодии и не больше +20 с,
	    errors — не больше нот; оценку и медаль считает сервер (настроение и талант Showstopper расширяют окна).
	Награды: опыт (по оценке), лакомства (по медали), бонус за новую лучшую медаль; рядом с членом семьи —
	привязанность и любовь. Все игроки видят трюк (атрибут персонажа Trick -> анимация у клиентов).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local NeedsLogic = require(Shared.NeedsLogic)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local TrickData = require(Shared.TrickData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local FamilyService = require(script.Parent.FamilyService)
local Interact = require(script.Parent.Interact)
local NeedsService = require(script.Parent.NeedsService)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local TrickService = {}

local rng = Random.new()

function TrickService.windowMult(data: any): number
	return NeedsLogic.trickMult(NeedsLogic.mood(data.Needs))
		* (1 + Progression.bonus(data.Talents, "Showstopper"))
end

function TrickService.init()
	Interact.register("Tricks", function(player)
		Remotes.getEvent("OpenUi"):FireClient(player, "Tricks")
		return true, nil
	end)

	Router.register("TrickStart", 1, 3, function(player, id: any)
		local data = DataService.get(player)
		local s = Session.get(player)
		local t = type(id) == "string" and TrickData.ById[id] or nil
		if not data or not s or not t then
			return false, "err.bad_request"
		end
		if data.Species == "" then
			return false, "err.bad_request"
		end
		if data.Level < t.Level then
			return false, Locale.m("msg.trick_level", { n = t.Level })
		end
		if s.SleepUntil > os.clock() then
			return false, "msg.sleeping"
		end
		local seed = rng:NextInteger(1, 2000000000)
		s.Trick = { Id = t.Id, Seed = seed, Start = os.clock() }
		return true, { Seed = seed, Mult = TrickService.windowMult(data) }
	end)

	Router.register("TrickFinish", 1, 3, function(player, id: any, errors: any)
		local data = DataService.get(player)
		local s = Session.get(player)
		local cur = s and s.Trick
		if not data or not s or not cur or cur.Id ~= id or type(errors) ~= "table" then
			return false, "err.bad_request"
		end
		s.Trick = nil
		local t = TrickData.ById[cur.Id]
		local duration = TrickData.duration(t.Id, cur.Seed)
		local elapsed = os.clock() - cur.Start
		if elapsed < duration - 0.35 then
			AntiExploit.strike(player, "trick too fast", 5)
			return false, "err.bad_request"
		end
		if elapsed > duration + 20 or #errors > t.Beats then
			return false, "err.bad_request"
		end
		local clean = {}
		for i = 1, t.Beats do
			local e = errors[i]
			clean[i] = if type(e) == "number" and e == e and math.abs(e) < 5 then e else false
		end
		local score, medal = TrickData.grade(clean, t.Beats, TrickService.windowMult(data))
		local rec = data.Tricks[t.Id]
		if type(rec) ~= "table" then
			rec = { Best = 0, Plays = 0 }
			data.Tricks[t.Id] = rec
		end
		rec.Plays += 1
		local improved = medal > (rec.Best or 0)
		if improved then
			rec.Best = medal
		end
		Progress.xp(player, math.floor(t.Xp * (0.4 + score)))
		if medal > 0 then
			Progress.treats(player, t.Treats * medal + (if improved then 10 * medal else 0))
		end
		NeedsService.add(player, "Fun", 8)
		NeedsService.add(player, "Energy", -3)
		local pos = AntiExploit.rootPos(player)
		local member = pos and FamilyService.nearestMember(pos, 18)
		if member and medal > 0 then
			FamilyService.bond(player, member, 1 + medal)
			NeedsService.add(player, "Love", 6)
			FamilyService.say(member, "speech.trick." .. medal)
		end
		local ch = player.Character
		if ch then
			ch:SetAttribute("Trick", t.Id .. ":" .. medal .. ":" .. os.clock())
		end
		if medal >= 1 then
			QuestService.event(player, "trick", t.Id)
		end
		if medal >= 2 then
			QuestService.event(player, "trick_silver", t.Id)
		end
		Remotes.getEvent("Fx"):FireClient(player, "Medal", t.Id, medal, score)
		State.markCore(player)
		return true, { Score = score, Medal = medal, Improved = improved }
	end)
end

return TrickService
