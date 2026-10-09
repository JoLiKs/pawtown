--!strict
-- Временное (не сохраняемое) состояние игрока на этом сервере.
local Session = {}

export type PlayerSession = {
	Ready: boolean,
	ActionBuckets: { [string]: { Tokens: number, Last: number } },
	Strikes: { number },
	LastTeleport: number,
	LastPosition: Vector3?,
	LastPositionTime: number,
	LastExpectedSpeed: number,
	Carrying: string?, -- "Newspaper" | "Toy" | "Ball" — что несёт в зубах
	SleepUntil: number, -- os.clock(): спит до
	Bath: { Start: number }?,
	Trick: { Id: string, Seed: number, Start: number }?,
	Fetch: { Start: number, Where: string, Ball: BasePart? }?,
	Agility: { Start: number, Next: number }?,
	Cooldowns: { [string]: number },
	LastEmote: { Id: string, Time: number }?,
	DashUntil: number,
	OnRoof: boolean,
	Zone: string,
	AirJumps: number,
}

local sessions: { [Player]: PlayerSession } = {}

function Session.create(player: Player): PlayerSession
	local s: PlayerSession = {
		Ready = false,
		ActionBuckets = {},
		Strikes = {},
		LastTeleport = 0,
		LastPosition = nil,
		LastPositionTime = 0,
		LastExpectedSpeed = 0,
		Carrying = nil,
		SleepUntil = 0,
		Bath = nil,
		Trick = nil,
		Fetch = nil,
		Agility = nil,
		Cooldowns = {},
		LastEmote = nil,
		DashUntil = 0,
		OnRoof = false,
		Zone = "",
		AirJumps = 0,
	}
	sessions[player] = s
	return s
end

function Session.get(player: Player): PlayerSession?
	return sessions[player]
end

function Session.destroy(player: Player)
	sessions[player] = nil
end

-- Кулдаун по ключу: true, если можно (и запускает новый отсчёт)
function Session.cooldown(player: Player, key: string, seconds: number): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	local now = os.clock()
	local t = s.Cooldowns[key]
	if t and now - t < seconds then
		return false
	end
	s.Cooldowns[key] = now
	return true
end

-- Сколько секунд осталось (0 — готово)
function Session.cooldownLeft(player: Player, key: string, seconds: number): number
	local s = sessions[player]
	local t = s and s.Cooldowns[key]
	if not t then
		return 0
	end
	return math.max(0, seconds - (os.clock() - t))
end

return Session
