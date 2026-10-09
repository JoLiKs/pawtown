--!strict
--[[
	FriendsLogic — список друзей и комбо-эмоции друзей (чистые функции, покрыты тестами).
	Список друзей хранится у каждого игрока: data.FriendList[tostring(userId)] = { Name, Since }.
	Дружба взаимная: заявка -> принятие (FriendsService). «В гости» — серверный телепорт к другу на этом сервере.
	Комбо: два друга рядом делают подходящие эмоции в пределах Config.COMBO_WINDOW секунд -> общая анимация и бонус.
	Общение — только стандартный фильтрованный чат Roblox (своих текстов игроков в игре нет).
]]
local FriendsLogic = {}

FriendsLogic.COMBOS = {
	{ Id = "HappyDance", A = "Wag", B = "Wag" },
	{ Id = "PlayFight", A = "PlayBow", B = "PlayBow" },
	{ Id = "Duet", A = "Voice", B = "Voice" },
	{ Id = "DoubleRoll", A = "Roll", B = "Roll" },
	{ Id = "NoseBoop", A = "Sniff", B = "Sniff" },
	{ Id = "Zoomies", A = "Wag", B = "PlayBow" },
	{ Id = "Echo", A = "Voice", B = "Mimic" },
}
FriendsLogic.REWARD = { Xp = 12, Treats = 6, Fun = 10 }

-- Комбо для пары эмоций (порядок не важен) или nil
function FriendsLogic.comboFor(a: string, b: string): string?
	for _, c in ipairs(FriendsLogic.COMBOS) do
		if (c.A == a and c.B == b) or (c.A == b and c.B == a) then
			return c.Id
		end
	end
	return nil
end

function FriendsLogic.count(list: any): number
	local n = 0
	if type(list) == "table" then
		for _ in pairs(list) do
			n += 1
		end
	end
	return n
end

function FriendsLogic.isFriend(data: any, userId: number): boolean
	return type(data.FriendList) == "table" and data.FriendList[tostring(userId)] ~= nil
end

-- Можно ли добавить: (ok, ключ-причина)
function FriendsLogic.canAdd(data: any, userId: number, selfId: number, max: number): (boolean, string?)
	if userId == selfId then
		return false, "err.bad_request"
	end
	if FriendsLogic.isFriend(data, userId) then
		return false, "msg.friend_already"
	end
	if FriendsLogic.count(data.FriendList) >= max then
		return false, "msg.friend_full"
	end
	return true, nil
end

function FriendsLogic.add(data: any, userId: number, name: string, now: number)
	data.FriendList = if type(data.FriendList) == "table" then data.FriendList else {}
	data.FriendList[tostring(userId)] = { Name = string.sub(name, 1, 40), Since = now }
end

function FriendsLogic.remove(data: any, userId: number): boolean
	if not FriendsLogic.isFriend(data, userId) then
		return false
	end
	data.FriendList[tostring(userId)] = nil
	return true
end

return FriendsLogic
