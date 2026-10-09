--!strict
--[[
	FriendsService — список друзей (сохраняется: data.FriendList), заявки, «в гости» и комбо-эмоции друзей.
	  * FriendRequest(userId) — заявка игроку на этом сервере; FriendAccept(userId, accept) — ответ (заявка живёт 2 мин);
	  * FriendRemove(userId) — убрать из своего списка;
	  * Visit(userId) — серверный телепорт к другу (только на этом сервере; переход между серверами появится вместе
	    с universe игры: TeleportService);
	  * комбо: друзья рядом делают подходящие эмоции (FriendsLogic.COMBOS) за COMBO_WINDOW секунд.
	Имена — DisplayName из Roblox; общение — только стандартный фильтрованный чат.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local FriendsLogic = require(Shared.FriendsLogic)
local Locale = require(Shared.Locale)
local Remotes = require(Shared.Remotes)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Movement = require(script.Parent.Movement)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local SocialService = require(script.Parent.SocialService)
local State = require(script.Parent.State)

local FriendsService = {}

local REQUEST_TTL = 120
-- pending[toPlayer][fromUserId] = время заявки
local pending: { [Player]: { [number]: number } } = {}
local comboCd: { [string]: number } = {}

local function byId(userId: any): Player?
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function markAll()
	for _, p in ipairs(Players:GetPlayers()) do
		State.markCore(p)
	end
end

function FriendsService.request(player: Player, userId: any): (boolean, any)
	local data = DataService.get(player)
	local target = byId(userId)
	local tdata = target and DataService.get(target)
	if not data or not target or not tdata then
		return false, "msg.friend_not_here"
	end
	local ok, why = FriendsLogic.canAdd(data, target.UserId, player.UserId, Config.FRIEND_LIST_MAX)
	if not ok then
		return false, why
	end
	-- встречная заявка — сразу дружба
	local mine = pending[player]
	if mine and mine[target.UserId] then
		return FriendsService.accept(player, target.UserId, true)
	end
	pending[target] = pending[target] or {}
	pending[target][player.UserId] = os.clock()
	Notify.send(target, Locale.m("msg.friend_request", { player = player.DisplayName }), "info")
	State.markCore(target)
	State.markCore(player)
	return true, Locale.m("msg.friend_sent", { player = target.DisplayName })
end

function FriendsService.accept(player: Player, fromId: any, accept: any): (boolean, any)
	local list = pending[player]
	local t: number? = if type(fromId) == "number" and list then list[fromId] else nil
	if t == nil or os.clock() - t > REQUEST_TTL then
		return false, "msg.friend_no_request"
	end
	list[fromId] = nil
	local from = byId(fromId)
	local data, fdata = DataService.get(player), from and DataService.get(from)
	State.markCore(player)
	if accept ~= true then
		return true, nil
	end
	if not data or not from or not fdata then
		return false, "msg.friend_not_here"
	end
	local ok, why = FriendsLogic.canAdd(data, from.UserId, player.UserId, Config.FRIEND_LIST_MAX)
	if not ok then
		return false, why
	end
	local now = os.time()
	FriendsLogic.add(data, from.UserId, from.DisplayName, now)
	FriendsLogic.add(fdata, player.UserId, player.DisplayName, now)
	Notify.send(from, Locale.m("msg.friend_added", { player = player.DisplayName }), "reward")
	QuestService.event(player, "friend")
	QuestService.event(from, "friend")
	State.markCore(from)
	return true, Locale.m("msg.friend_added", { player = from.DisplayName })
end

function FriendsService.remove(player: Player, userId: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(userId) ~= "number" then
		return false, "err.bad_request"
	end
	if not FriendsLogic.remove(data, userId) then
		return false, "err.bad_request"
	end
	State.markCore(player)
	return true, "msg.friend_removed"
end

function FriendsService.visit(player: Player, userId: any): (boolean, any)
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s or type(userId) ~= "number" then
		return false, "err.bad_request"
	end
	if not FriendsLogic.isFriend(data, userId) then
		return false, "msg.friend_only"
	end
	local friend = byId(userId)
	local fpos = friend and AntiExploit.rootPos(friend)
	if not friend or not fpos then
		return false, "msg.friend_not_here"
	end
	if Movement.busy(s) or s.Trial then
		return false, "msg.visit_busy"
	end
	local left = Session.cooldownLeft(player, "visit", Config.VISIT_COOLDOWN)
	if left > 0 then
		return false, Locale.m("msg.visit_wait", { n = math.ceil(left) })
	end
	Session.cooldown(player, "visit", Config.VISIT_COOLDOWN)
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, nil
	end
	s.Carrying = nil
	AntiExploit.markTeleport(player)
	local fch = friend.Character
	local froot = fch and fch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local back = if froot then -froot.CFrame.LookVector * 4 else Vector3.new(0, 0, 4)
	local at = fpos + Vector3.new(back.X, 1, back.Z)
	root.CFrame = CFrame.lookAt(at, Vector3.new(fpos.X, at.Y, fpos.Z))
	root.AssemblyLinearVelocity = Vector3.zero
	Notify.send(friend, Locale.m("msg.visit_arrived", { player = player.DisplayName }), "info")
	Remotes.getEvent("Fx"):FireClient(player, "Burrow", at)
	return true, Locale.m("msg.visit_to", { player = friend.DisplayName })
end

-- Комбо-эмоции друзей
function FriendsService.tryCombo(player: Player, emote: string, pos: Vector3)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local os2 = Session.get(other)
		local odata = DataService.get(other)
		local opos = AntiExploit.rootPos(other)
		if
			other ~= player
			and os2
			and odata
			and opos
			and os2.LastEmote
			and FriendsLogic.isFriend(data, other.UserId)
			and FriendsLogic.isFriend(odata, player.UserId)
			and (opos - pos).Magnitude <= Config.FRIEND_RADIUS
			and now - os2.LastEmote.Time <= Config.COMBO_WINDOW
		then
			local combo = FriendsLogic.comboFor(emote, os2.LastEmote.Id)
			local key = if player.UserId < other.UserId
				then player.UserId .. ":" .. other.UserId
				else other.UserId .. ":" .. player.UserId
			if combo and (not comboCd[key] or now - comboCd[key] > 8) then
				comboCd[key] = now
				for _, p in ipairs({ player, other }) do
					local ch = p.Character
					if ch then
						ch:SetAttribute("Combo", combo .. ":" .. now)
					end
					Progress.xp(p, FriendsLogic.REWARD.Xp)
					Progress.treats(p, FriendsLogic.REWARD.Treats)
					NeedsService.add(p, "Fun", FriendsLogic.REWARD.Fun)
					Remotes.getEvent("Fx"):FireClient(p, "Combo", combo)
					QuestService.event(p, "combo", combo)
				end
				return
			end
		end
	end
end

function FriendsService.init()
	Router.register("FriendRequest", 1, 3, FriendsService.request)
	Router.register("FriendAccept", 2, 4, FriendsService.accept)
	Router.register("FriendRemove", 1, 3, FriendsService.remove)
	Router.register("Visit", 1, 2, FriendsService.visit)
	table.insert(SocialService.emoteHooks, FriendsService.tryCombo)
	State.providers.FriendsList = function(player, data)
		local friends = {}
		for key, f in pairs(data.FriendList or {}) do
			local id = tonumber(key) or 0
			local online = Players:GetPlayerByUserId(id)
			table.insert(friends, {
				Id = id,
				Name = if online then online.DisplayName else f.Name,
				Online = online ~= nil,
				Points = (data.Friends or {})[key] or 0,
			})
		end
		table.sort(friends, function(a, b)
			if a.Online ~= b.Online then
				return a.Online
			end
			return a.Name < b.Name
		end)
		local requests = {}
		for id, t in pairs(pending[player] or {}) do
			local from = Players:GetPlayerByUserId(id)
			if from and os.clock() - t <= REQUEST_TTL then
				table.insert(requests, { Id = id, Name = from.DisplayName })
			end
		end
		local here = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local their = pending[p]
				table.insert(here, {
					Id = p.UserId,
					Name = p.DisplayName,
					Friend = FriendsLogic.isFriend(data, p.UserId),
					Sent = their ~= nil and their[player.UserId] ~= nil,
				})
			end
		end
		return { Friends = friends, Requests = requests, Here = here, Max = Config.FRIEND_LIST_MAX }
	end
	Players.PlayerAdded:Connect(markAll)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		for _, list in pairs(pending) do
			list[player.UserId] = nil
		end
		task.defer(markAll)
	end)
end

return FriendsService
