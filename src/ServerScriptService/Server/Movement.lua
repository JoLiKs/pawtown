--!strict
--[[
	Movement — скорость и прыжок персонажа задаёт только сервер (вид, таланты, возраст, рывок, бег по крышам, сон).
	Клиент реплицирует движение своего персонажа сам (так устроен Roblox), а AntiExploit сверяет перемещение
	с легальной скоростью (Movement.legalSpeed) и откатывает телепорты/спидхак.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local SpeciesData = require(Shared.SpeciesData)
local WorldData = require(Shared.WorldData)

local DataService = require(script.Parent.DataService)
local Session = require(script.Parent.Session)

local Movement = {}

local AGE_SPEED = { Baby = 0.92, Teen = 0.97, Adult = 1 }

-- Скорость без временных эффектов
function Movement.baseSpeed(data: any): number
	local sp = SpeciesData.ById[data.Species]
	local mult = (if sp then sp.Speed else 1) * (1 + Progression.bonus(data.Talents, "LightPaws"))
	mult *= AGE_SPEED[Progression.age(data.Level)] or 1
	if (data.Needs and data.Needs.Health or 100) < 30 then
		mult *= 0.9 -- мягко: немного медленнее, пока питомец нездоров
	end
	return Config.BASE_WALKSPEED * mult
end

-- Питомец «занят» (сон, мини-игра трюка или ванны) — стоит на месте
function Movement.busy(s: any): boolean
	local now = os.clock()
	if s.SleepUntil > now then
		return true
	end
	if s.Trick and now - s.Trick.Start < 30 then
		return true
	end
	if s.Bath and now - s.Bath.Start < 60 then
		return true
	end
	return false
end

function Movement.walkSpeed(player: Player): number
	local data = DataService.get(player)
	local s = Session.get(player)
	if not data or not s then
		return Config.BASE_WALKSPEED
	end
	if Movement.busy(s) then
		return 0
	end
	local v = Movement.baseSpeed(data)
	if s.DashUntil > os.clock() then
		v *= Config.DASH_MULT
	elseif s.OnRoof and SpeciesData.has(data.Species, "RoofSprint") then
		v *= Config.ROOF_SPRINT_MULT
	elseif s.OnRoof and SpeciesData.has(data.Species, "RoofRun") then
		v *= Config.ROOF_SPEED_MULT
	end
	return v
end

-- Максимальная легальная скорость (для античита): с учётом рывка и крыш
function Movement.legalSpeed(player: Player): number
	local data = DataService.get(player)
	if not data then
		return Config.BASE_WALKSPEED
	end
	local s = Session.get(player)
	if s and s.LeapUntil > os.clock() then
		-- прыжок барса: горизонтальная скорость задаётся клиентом, сервер разрешил её на LEAP_TIME
		return math.max(Config.LEAP_FORWARD * 1.15, Movement.baseSpeed(data) * Config.DASH_MULT)
	end
	return Movement.baseSpeed(data)
		* math.max(Config.DASH_MULT, Config.ROOF_SPEED_MULT, Movement.roofMult(data))
end

function Movement.roofMult(data: any): number
	if SpeciesData.has(data.Species, "RoofSprint") then
		return Config.ROOF_SPRINT_MULT
	end
	return Config.ROOF_SPEED_MULT
end

function Movement.jumpPower(player: Player): number
	local data = DataService.get(player)
	if not data then
		return Config.BASE_JUMPPOWER
	end
	local s = Session.get(player)
	if s and Movement.busy(s) then
		return 0
	end
	local sp = SpeciesData.ById[data.Species]
	return Config.BASE_JUMPPOWER
		* (if sp then sp.Jump else 1)
		* (1 + Progression.bonus(data.Talents, "SpringLegs"))
end

-- На крыше соседского дома? (по координатам: проще и надёжнее рейкаста)
function Movement.onRoof(pos: Vector3): boolean
	for _, n in ipairs(WorldData.Neighbours) do
		local half = n.Size / 2
		if
			math.abs(pos.X - n.Center.X) <= half.X + 1
			and math.abs(pos.Z - n.Center.Z) <= half.Z + 1
			and pos.Y >= n.Size.Y - 0.5
		then
			return true
		end
	end
	return false
end

function Movement.apply(player: Player)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local s = Session.get(player)
	if not hum or not s then
		return
	end
	if root then
		s.OnRoof = Movement.onRoof(root.Position)
	end
	local ws = Movement.walkSpeed(player)
	if math.abs(hum.WalkSpeed - ws) > 0.01 then
		hum.WalkSpeed = ws
	end
	local jp = Movement.jumpPower(player)
	hum.UseJumpPower = true
	if math.abs(hum.JumpPower - jp) > 0.01 then
		hum.JumpPower = jp
	end
end

return Movement
