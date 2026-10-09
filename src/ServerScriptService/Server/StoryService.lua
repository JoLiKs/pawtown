--!strict
--[[
	StoryService — глава 2 «Соседи» и награды за репутацию Кленовой улицы.
	  * соседи (миссис Вязова, мистер Лютиков): поздороваться, вернуть очки, развеселить эмоцией;
	  * почтальон потерял посылку: найти её (своя для каждого игрока) и решить — вернуть (+репутация улицы)
	    или оставить пищалку себе (лакомства, -репутация). Выбор сохраняется (data.Choices);
	  * праздник улицы — финал главы;
	  * награды репутации (QuestData.REP_REWARDS): тропинка соседей (короткий путь в парк), скидка в бутике
	    (ShopData.price), кленовая шляпа (не продаётся).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Progression = require(Shared.Progression)
local QuestData = require(Shared.QuestData)
local Remotes = require(Shared.Remotes)
local ShopData = require(Shared.ShopData)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local FamilyService = require(script.Parent.FamilyService)
local Interact = require(script.Parent.Interact)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local SocialService = require(script.Parent.SocialService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local StoryService = {}

local S2 = WorldData.Story2

-- -------------------------------------------------------------- предметы сюжета (свои у каждого игрока)
type ItemDef = { Step: string, Pos: Vector3, Size: Vector3, Color: Color3 }
local ITEMS: { [string]: ItemDef } = {
	Parcel = {
		Step = "c2_parcel",
		Pos = S2.Parcel,
		Size = Vector3.new(2, 1.4, 1.6),
		Color = Color3.fromRGB(190, 140, 90),
	},
	Glasses = {
		Step = "c2_glasses",
		Pos = S2.Glasses,
		Size = Vector3.new(1.2, 0.4, 0.5),
		Color = Color3.fromRGB(60, 60, 80),
	},
}
local spawned: { [Player]: { [string]: BasePart } } = {}

local function removeItem(player: Player, kind: string)
	local t = spawned[player]
	local p = t and t[kind]
	if p then
		p:Destroy()
		t[kind] = nil
	end
end

local function spawnItems(player: Player)
	local s = Session.get(player)
	local step = QuestService.stepId(player)
	spawned[player] = spawned[player] or {}
	for kind, def in pairs(ITEMS) do
		local want = step == def.Step and s ~= nil and s.Carrying ~= kind
		local have = spawned[player][kind]
		if want and not have then
			local p = WorldBuilder.part(
				WorldBuilder.folder("Dynamic"),
				"Story_" .. kind .. "_" .. player.UserId,
				def.Size,
				def.Pos + Vector3.new(0, def.Size.Y / 2 + 0.1, 0),
				def.Color,
				{ CanCollide = false }
			)
			p:SetAttribute("Owner", player.UserId)
			p:SetAttribute("StoryItem", kind)
			Interact.prompt(
				p,
				"PickStory",
				"prompt.pick_" .. string.lower(kind),
				{ Arg = kind .. ":" .. player.UserId, Object = "obj." .. string.lower(kind), Distance = 8 }
			)
			spawned[player][kind] = p
		elseif not want and have then
			removeItem(player, kind)
		end
	end
end

function StoryService.itemPos(player: Player, kind: string): Vector3?
	local t = spawned[player]
	local p = t and t[kind]
	return p and p.Position
end

-- ------------------------------------------------------------------------- выбор с посылкой
function StoryService.choose(player: Player, choiceId: any, option: any): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s or choiceId ~= "c2_parcel" or type(option) ~= "string" then
		return false, "err.bad_request"
	end
	if QuestService.stepId(player) ~= "c2_choice" or s.Carrying ~= "Parcel" then
		return false, "msg.no_choice"
	end
	local opt
	for _, o in ipairs(QuestData.CHOICES.c2_parcel) do
		if o.Id == option then
			opt = o
		end
	end
	if not opt then
		return false, "err.bad_request"
	end
	s.Carrying = nil
	data.Choices.c2_parcel = opt.Id
	if opt.RepPts > 0 then
		Progress.rep(player, "Street", opt.RepPts)
	else
		data.Rep.Street = math.max(0, data.Rep.Street + opt.RepPts)
	end
	Progress.treats(player, opt.Treats)
	FamilyService.say("Mailman", if opt.Id == "return" then "speech.mail_thanks" else "speech.mail_sad")
	QuestService.event(player, "choice", opt.Id)
	State.markCore(player)
	return true, Locale.m("msg.choice_" .. opt.Id, { n = opt.RepPts })
end

-- --------------------------------------------------------------------------- награды репутации
function StoryService.repLevel(data: any): number
	return Progression.repLevel(data.Rep.Street or 0)
end

function StoryService.grantRepRewards(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local lvl = StoryService.repLevel(data)
	for _, r in ipairs(QuestData.REP_REWARDS) do
		if r.Kind == "Cosmetic" and lvl >= r.Level and r.Item and not data.Cosmetics.Owned[r.Item] then
			data.Cosmetics.Owned[r.Item] = true
			local item = ShopData.ById[r.Item]
			Notify.send(
				player,
				Locale.m("msg.rep_cosmetic", { item = item and item.Name or r.Item }),
				"reward"
			)
			State.markCore(player)
		end
	end
end

function StoryService.shortcut(player: Player, side: string): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	if StoryService.repLevel(data) < QuestData.SHORTCUT_LEVEL then
		return false, Locale.m("msg.shortcut_locked", { n = QuestData.SHORTCUT_LEVEL })
	end
	local from = if side == "A" then S2.Shortcut.A else S2.Shortcut.B
	local to = if side == "A" then S2.Shortcut.B else S2.Shortcut.A
	if not AntiExploit.near(player, from, 10) then
		return false, nil
	end
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, nil
	end
	AntiExploit.markTeleport(player)
	root.CFrame = CFrame.new(to + Vector3.new(0, 3, 4))
	Remotes.getEvent("Fx"):FireClient(player, "Burrow", to)
	return true, "msg.shortcut_used"
end

-- ------------------------------------------------------------------------------------- init
function StoryService.init()
	Interact.register("Neighbour", function(player, _prompt, arg)
		local s = Session.get(player)
		if not s or (arg ~= "Elm" and arg ~= "Buttercup") then
			return false, nil
		end
		local id = arg :: string
		if id == "Elm" and s.Carrying == "Glasses" then
			s.Carrying = nil
			FamilyService.say("Elm", "speech.elm_glasses")
			QuestService.event(player, "glasses")
			Progress.rep(player, "Street", 8)
			State.markCore(player)
			return true, nil
		end
		if not Session.cooldown(player, "neighbour:" .. id, 4) then
			return false, nil
		end
		local step = QuestService.stepId(player)
		local line = "speech." .. id .. ".hi"
		if step == "c2_glasses" and id == "Elm" then
			line = "speech.elm_lost"
		elseif step == "c2_cheer" and id == "Buttercup" then
			line = "speech.buttercup_grumpy"
		end
		FamilyService.say(id, line)
		NeedsService.add(player, "Fun", 2)
		QuestService.event(player, "greet_neighbour", id)
		return true, nil
	end)
	FamilyService.onMailman = function(player, fromPrompt)
		local s = Session.get(player)
		local step = QuestService.stepId(player)
		if step == "c2_mail" then
			FamilyService.say("Mailman", "speech.mail_lost")
			QuestService.event(player, "greet_mailman")
			return true
		elseif step == "c2_choice" and s and s.Carrying == "Parcel" and fromPrompt then
			Remotes.getEvent("OpenUi"):FireClient(player, "Choice")
			return true
		end
		return false
	end
	Interact.register("PickStory", function(player, _prompt, arg)
		local s = Session.get(player)
		local kind, uid = string.match(arg or "", "^(%a+):(%d+)$")
		if not s or not kind or not ITEMS[kind] or uid ~= tostring(player.UserId) then
			return false, "msg.not_your_toy"
		end
		if QuestService.stepId(player) ~= ITEMS[kind].Step then
			return false, nil
		end
		if s.Carrying then
			return false, "msg.mouth_full"
		end
		s.Carrying = kind
		removeItem(player, kind)
		State.markCore(player)
		if kind == "Parcel" then
			QuestService.event(player, "parcel")
			Remotes.getEvent("OpenUi"):FireClient(player, "Choice")
			return true, "msg.got_parcel"
		end
		return true, "msg.got_glasses"
	end)
	Router.register("StoryChoice", 1, 3, StoryService.choose)
	Interact.register("Shortcut", function(player, _prompt, arg)
		return StoryService.shortcut(player, arg or "")
	end)
	table.insert(SocialService.emoteHooks, function(player, _id, pos)
		local m = FamilyService.npcs.Buttercup
		local r = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - pos).Magnitude <= 12 and QuestService.stepId(player) == "c2_cheer" then
			FamilyService.say("Buttercup", "speech.buttercup_smile")
			QuestService.event(player, "cheer")
		end
	end)
	local prevRep = Progress.onRep
	Progress.onRep = function(player, district)
		if prevRep then
			prevRep(player, district)
		end
		if district == "Street" then
			StoryService.grantRepRewards(player)
		end
	end
	State.providers.StoryItems = function(player)
		return {
			Parcel = StoryService.itemPos(player, "Parcel"),
			Glasses = StoryService.itemPos(player, "Glasses"),
		}
	end
	State.providers.Choices = function(_player, data)
		return data.Choices
	end
	State.providers.Discount = function(_player, data)
		return if StoryService.repLevel(data) >= QuestData.DISCOUNT_LEVEL then QuestData.DISCOUNT_PCT else 0
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				local data = DataService.get(player)
				if s and s.Ready and data and data.Species ~= "" then
					pcall(spawnItems, player)
					if
						QuestService.stepId(player) == "c2_party" and AntiExploit.near(player, S2.Party, 12)
					then
						QuestService.event(player, "party")
					end
					StoryService.grantRepRewards(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for kind in pairs(ITEMS) do
			removeItem(player, kind)
		end
		spawned[player] = nil
	end)
end

return StoryService
