--!strict
-- Рассылка состояния клиенту (снимок Core). Клиент только отображает то, что прислал сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local NeedsLogic = require(Shared.NeedsLogic)
local Progression = require(Shared.Progression)
local QuestData = require(Shared.QuestData)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Session = require(script.Parent.Session)

local State = {}

local dirty: { [Player]: boolean } = {}

function State.markCore(player: Player)
	dirty[player] = true
end

-- Внешние поставщики полей снимка (QuestService, DayNightService и т.п. регистрируют себя, чтобы не было циклов require)
State.providers = {} :: { [string]: (Player, any) -> any }

function State.build(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local s = Session.get(player)
	local needs = data.Needs
	local mood = NeedsLogic.mood(needs)
	local shards = {}
	for id in pairs(data.Shards) do
		table.insert(shards, id)
	end
	table.sort(shards)
	local core: { [string]: any } = {
		ServerTime = os.time(),
		Species = data.Species,
		Needs = needs,
		Mood = mood,
		Glowing = NeedsLogic.glowing(needs),
		Level = data.Level,
		Xp = data.Xp,
		XpNeed = Progression.xpFor(data.Level),
		Age = Progression.age(data.Level),
		Treats = data.Treats,
		Talents = data.Talents,
		TalentFree = Progression.talentPointsTotal(data.Level) - Progression.spent(data.Talents),
		Tricks = data.Tricks,
		Bond = data.Bond,
		Rep = data.Rep,
		Shards = shards,
		Cosmetics = data.Cosmetics,
		Best = data.Best,
		Carrying = s and s.Carrying or "",
		Sleeping = s ~= nil and s.SleepUntil > os.clock(),
		Lang = data.Settings.Lang,
		FriendsCount = (function()
			local n = 0
			for _ in pairs(data.Friends or {}) do
				n += 1
			end
			return n
		end)(),
		DailyIds = QuestData.pickDaily(QuestData.dayNumber(os.time()), player.UserId),
	}
	for key, fn in pairs(State.providers) do
		core[key] = fn(player, data)
	end
	return core
end

function State.push(player: Player)
	dirty[player] = nil
	local core = State.build(player)
	if core then
		Remotes.getEvent("State"):FireClient(player, { Core = core })
	end
end

function State.init()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				if player.Parent then
					local ok, err = pcall(function()
						State.push(player)
					end)
					if not ok then
						warn("[State] push failed:", err)
					end
				else
					dirty[player] = nil
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
end

return State
