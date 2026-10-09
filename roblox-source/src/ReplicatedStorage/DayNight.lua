--!strict
-- DayNight — чистые функции игрового времени суток (ClockTime 0..24) по серверным секундам.
local Config = require(script.Parent.Config)

local DayNight = {}

function DayNight.length(): number
	return if Config.WEB_DEMO then Config.DAY_LENGTH_DEMO else Config.DAY_LENGTH
end

-- t — секунды «мира» (сервер копит их сам, сон может перематывать). Старт — 8:00.
function DayNight.clock(t: number, len: number?): number
	local L = len or DayNight.length()
	local c = (8 + (t % L) / L * 24) % 24
	return c
end

function DayNight.isNight(clock: number): boolean
	return clock >= Config.NIGHT_FROM or clock < Config.NIGHT_TO
end

-- Сколько секунд мира перемотать до утра (7:00)
function DayNight.secondsToMorning(clock: number, len: number?): number
	local L = len or DayNight.length()
	local hours = (7 - clock) % 24
	return hours / 24 * L
end

return DayNight
