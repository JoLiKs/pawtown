--!strict
--[[
	SocialService — эмоции питомцев (видны всем: атрибут персонажа Emote -> анимация у клиентов) и дружба.
	Дружба: два игрока рядом (FRIEND_RADIUS) делают эмоции в пределах 10 с — оба получают +1 к дружбе пары
	(не чаще раза в FRIEND_PAIR_COOLDOWN). Общение — только стандартный фильтрованный чат Roblox:
	своих текстовых каналов в игре нет, имена — DisplayName из Roblox.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local SpeciesData = require(Shared.SpeciesData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local FamilyService = require(script.Parent.FamilyService)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local SocialService = {}

-- Эмоции: Voice — голос вида (bark/meow/squeak/chirp), Mimic — только с способностью Mimic
SocialService.EMOTES = { "Wag", "Sniff", "Voice", "PlayBow", "Roll", "Mimic" }

local pairCd: { [string]: number } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function addFriend(player: Player, other: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = tostring(other.UserId)
	if data.Friends[key] == nil then
		local n = 0
		for _ in pairs(data.Friends) do
			n += 1
		end
		if n >= Config.FRIEND_MAX_ENTRIES then
			return
		end
	end
	data.Friends[key] = (data.Friends[key] or 0) + 1
	Notify.send(player, Locale.m("msg.friendship", { player = other.DisplayName, n = data.Friends[key] }), "reward")
	Progress.xp(player, 5)
	NeedsService.add(player, "Fun", 5)
	State.markCore(player)
end

function SocialService.init()
	Router.register("Emote", 2, 4, function(player, id: any)
		local data = DataService.get(player)
		local s = Session.get(player)
		if not data or not s or type(id) ~= "string" or not table.find(SocialService.EMOTES, id) then
			return false, "err.bad_request"
		end
		if id == "Mimic" and not SpeciesData.has(data.Species, "Mimic") then
			return false, "msg.no_ability"
		end
		if not Session.cooldown(player, "emote", Config.EMOTE_COOLDOWN) then
			return false, nil
		end
		local ch = player.Character
		if not ch or data.Species == "" then
			return false, nil
		end
		local now = os.clock()
		ch:SetAttribute("Emote", id .. ":" .. now)
		s.LastEmote = { Id = id, Time = now }
		local pos = AntiExploit.rootPos(player)
		if not pos then
			return true, nil
		end
		-- дружба с соседями
		for _, other in ipairs(Players:GetPlayers()) do
			local os2 = Session.get(other)
			local opos = AntiExploit.rootPos(other)
			if other ~= player and os2 and os2.LastEmote and opos then
				if (opos - pos).Magnitude <= Config.FRIEND_RADIUS and now - os2.LastEmote.Time <= 10 then
					local k = pairKey(player.UserId, other.UserId)
					if not pairCd[k] or now - pairCd[k] >= Config.FRIEND_PAIR_COOLDOWN then
						pairCd[k] = now
						addFriend(player, other)
						addFriend(other, player)
						QuestService.event(player, "friend")
						QuestService.event(other, "friend")
					end
				end
			end
		end
		-- почтальон и семья радуются
		local mp = FamilyService.mailmanPos()
		if mp and (mp - pos).Magnitude <= 16 then
			FamilyService.say("Mailman", "speech.mail_hi")
			QuestService.event(player, "greet_mailman")
		end
		local member = FamilyService.nearestMember(pos, 14)
		if member and Session.cooldown(player, "emotelove", 20) then
			NeedsService.add(player, "Love", 4)
			FamilyService.bond(player, member, 1)
		end
		NeedsService.add(player, "Fun", 2)
		return true, nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		local id = tostring(player.UserId)
		for k in pairs(pairCd) do
			local a, b = string.match(k, "^(%d+):(%d+)$")
			if a == id or b == id then
				pairCd[k] = nil
			end
		end
	end)
end

return SocialService
