--!strict
--[[
	RebirthService — «Ночь Искр»: испытания видов и перерождение в редкий вид (логика — RebirthLogic).
	  * Испытание (TrialStart): искры появляются по одной (WorldData.Trials[id].Points), успеть за Time секунд.
	    Сервер сам проверяет расстояние до искры (клиенту не доверяем). Пройдено -> data.Trials[id] = true.
	  * Перерождение (Rebirth): все условия RebirthLogic.check; смена вида, сброс уровня, +1 звезда, наследуемый талант.
	  * Алтарь Искр в парке открывает окно «Ночь Искр».
	  * DevFastTrack — ТОЛЬКО в Studio (RunService:IsStudio() и Config.DEV_FAST_REBIRTH): действие регистрируется лишь
	    там, на живых серверах его просто нет.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local RebirthLogic = require(Shared.RebirthLogic)
local Remotes = require(Shared.Remotes)
local SpeciesData = require(Shared.SpeciesData)
local WorldData = require(Shared.WorldData)

local DataService = require(script.Parent.DataService)
local Interact = require(script.Parent.Interact)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RebirthService = {}

function RebirthService.devAllowed(): boolean
	return Config.DEV_FAST_REBIRTH == true and RunService:IsStudio()
end

local function clearSpark(s: any)
	local t = s.Trial
	if t and t.Spark then
		t.Spark:Destroy()
		t.Spark = nil
	end
end

local function placeSpark(player: Player, s: any)
	clearSpark(s)
	local t = s.Trial
	local def = WorldData.Trials[t.Id]
	local pos = def.Points[t.Index]
	local p = WorldBuilder.part(
		WorldBuilder.folder("Dynamic"),
		"TrialSpark_" .. player.UserId,
		Vector3.new(2.2, 2.2, 2.2),
		pos + Vector3.new(0, 0.6, 0),
		Color3.fromRGB(255, 225, 120),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.1 }
	)
	p:SetAttribute("Owner", player.UserId)
	p:SetAttribute("TrialSpark", true)
	t.Spark = p
end

function RebirthService.stopTrial(player: Player, msg: string?)
	local s = Session.get(player)
	if not s or not s.Trial then
		return
	end
	clearSpark(s)
	s.Trial = nil
	if msg then
		Notify.send(player, msg, "error")
	end
	State.markCore(player)
end

function RebirthService.startTrial(player: Player, id: any): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s or type(id) ~= "string" then
		return false, "err.bad_request"
	end
	local ok, why = RebirthLogic.canTrial(data, id)
	if not ok then
		return false, why
	end
	RebirthService.stopTrial(player)
	local def = WorldData.Trials[id]
	local now = os.clock()
	s.Trial = { Id = id, Index = 1, Start = now, Ends = now + def.Time, Spark = nil }
	placeSpark(player, s)
	State.markCore(player)
	return true, Locale.m("rebirth.trial_started", { n = #def.Points, sec = def.Time })
end

local function trialTick(player: Player)
	local s = Session.get(player)
	local data = DataService.get(player)
	if not s or not s.Trial or not data then
		return
	end
	local t = s.Trial
	if os.clock() > t.Ends then
		RebirthService.stopTrial(player, "rebirth.trial_failed")
		return
	end
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local def = WorldData.Trials[t.Id]
	if not root or not def then
		return
	end
	if (root.Position - def.Points[t.Index]).Magnitude <= WorldData.TRIAL_RADIUS then
		Remotes.getEvent("Fx"):FireClient(player, "TrialSpark", def.Points[t.Index])
		t.Index += 1
		if t.Index > #def.Points then
			clearSpark(s)
			s.Trial = nil
			data.Trials[t.Id] = true
			Progress.reward(player, { Treats = 60, Xp = 120 }, "rebirth.trial_done_title")
			Remotes.getEvent("Fx"):FireClient(player, "Quest", "trial")
			QuestService.event(player, "trial", t.Id)
			Notify.send(
				player,
				Locale.m("rebirth.trial_passed", { species = SpeciesData.ById[t.Id].Name }),
				"reward"
			)
		else
			placeSpark(player, s)
		end
		State.markCore(player)
	end
end

function RebirthService.rebirth(player: Player, id: any, inherit: any): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s or type(id) ~= "string" then
		return false, "err.bad_request"
	end
	if inherit ~= nil and type(inherit) ~= "string" then
		return false, "err.bad_request"
	end
	if inherit == "" then
		inherit = nil
	end
	if s.Trial then
		return false, "rebirth.trial_running"
	end
	local ok, why = RebirthLogic.apply(data, id, inherit)
	if not ok then
		return false, why
	end
	s.Carrying = nil
	State.markCore(player)
	PlayerService.respawnInPlace(player)
	Remotes.getEvent("Cutscene"):FireClient(player, "Rebirth", id)
	QuestService.event(player, "rebirth", id)
	return true,
		Locale.m("rebirth.done", { species = SpeciesData.ById[id].Name, n = RebirthLogic.stars(data) })
end

function RebirthService.fastTrack(player: Player, id: any): (boolean, any)
	if not RebirthService.devAllowed() then
		return false, "err.bad_request"
	end
	local data = DataService.get(player)
	if not data or type(id) ~= "string" or not SpeciesData.isRare(id) then
		return false, "err.bad_request"
	end
	RebirthLogic.fastTrack(data, id)
	State.markCore(player)
	PlayerService.respawnInPlace(player)
	return true, "rebirth.dev_done"
end

function RebirthService.init()
	Router.register("TrialStart", 1, 3, RebirthService.startTrial)
	Router.register("TrialCancel", 1, 3, function(player)
		RebirthService.stopTrial(player)
		return true, nil
	end)
	Router.register("Rebirth", 0.5, 2, RebirthService.rebirth)
	if RebirthService.devAllowed() then
		Router.register("DevFastTrack", 1, 3, RebirthService.fastTrack)
	end
	Interact.register("SparkShrine", function(player)
		Remotes.getEvent("OpenUi"):FireClient(player, "SparkNight")
		return true, nil
	end)
	State.providers.Rebirth = function(player, data)
		local s = Session.get(player)
		local lineage, trials = {}, {}
		for id in pairs(data.Lineage or {}) do
			table.insert(lineage, id)
		end
		for id in pairs(data.Trials or {}) do
			table.insert(trials, id)
		end
		table.sort(lineage)
		table.sort(trials)
		local t = s and s.Trial
		return {
			Stars = RebirthLogic.stars(data),
			Count = data.Rebirths or 0,
			Mult = RebirthLogic.mult(data),
			Lineage = lineage,
			Trials = trials,
			Inherit = data.Talents.Inherit or "",
			Trial = if t
				then {
					Id = t.Id,
					Index = t.Index,
					Total = #WorldData.Trials[t.Id].Points,
					Left = math.max(0, math.floor(t.Ends - os.clock())),
					Pos = WorldData.Trials[t.Id].Points[t.Index],
				}
				else nil,
			Dev = RebirthService.devAllowed(),
		}
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok: boolean, err: any = pcall(trialTick, player)
				if not ok then
					warn("[RebirthService] trial tick:", err)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		RebirthService.stopTrial(player)
	end)
end

return RebirthService
