--!nonstrict
--[[
	Abilities — движение способностей на клиенте (физика персонажа принадлежит клиенту):
	  * кошка — двойной прыжок (DoubleJump);
	  * попугай — два взмаха в воздухе (Flap) и планирование (Glide: держи прыжок при падении);
	  * сова — 5 взмахов (LongFlight) и медленное планирование; ночное зрение (NightVision) — фильтр Lighting;
	  * снежный барс — большой прыжок (HugeLeap): сервер разрешает окно, импульс задаёт клиент;
	  * Q — основная способность вида (SpeciesData.Primary), F — вторая (Secondary), через сервер (Ability).
	Скорость и высоту прыжка задаёт сервер (Movement); анти-чит проверяет перемещения.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)

local Abilities = {}
local player = Players.LocalPlayer

local Config = require(Shared:WaitForChild("Config"))
local Lighting = game:GetService("Lighting")

local GLIDE_FALL = -7
local GRAVITY_JUMP = 196.2

local airJumps = 0
local lastJump = 0
local jumpHeld = false

local function parts()
	local ch = player.Character
	if not ch then
		return nil, nil
	end
	return ch:FindFirstChild("HumanoidRootPart") :: BasePart?, ch:FindFirstChildOfClass("Humanoid")
end

-- На земле: луч вниз чуть длиннее ног
function Abilities.grounded(root: BasePart, hum: Humanoid): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local len = hum.HipHeight + root.Size.Y / 2 + 0.45
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -len, 0), params)
	return hit ~= nil
end

local function maxAirJumps(species: string): number
	if SpeciesData.has(species, "LongFlight") then
		return Config.OWL_FLAPS
	elseif SpeciesData.has(species, "Flap") then
		return 2
	elseif SpeciesData.has(species, "DoubleJump") then
		return 1
	end
	return 0
end

local lastRequest = 0

local function tryAirJump()
	-- удержание кнопки шлёт JumpRequest повторно: нужен новый «тап»
	local now = os.clock()
	local repeated = now - lastRequest < 0.12
	lastRequest = now
	if repeated then
		return
	end
	local core = ClientState.Core
	local root, hum = parts()
	if not core or not root or not hum or hum.WalkSpeed <= 0 then
		return
	end
	if os.clock() - lastJump < 0.22 then
		return
	end
	if Abilities.grounded(root, hum) then
		lastJump = os.clock()
		return
	end
	if airJumps >= maxAirJumps(core.Species) then
		return
	end
	airJumps += 1
	lastJump = os.clock()
	local jp = hum.JumpPower * (if SpeciesData.has(core.Species, "Flap") then 0.8 else 0.95)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, jp, v.Z)
	local ch = player.Character
	if ch then
		ch:SetAttribute("AirJump", os.clock())
	end
end

-- Ночное зрение совы: локальный фильтр (другие игроки не затронуты)
local nightVision = false
function Abilities.setNightVision(on: boolean)
	nightVision = on
	local cc = Lighting:FindFirstChild("NightVision")
	if on and not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "NightVision"
		cc.Brightness = 0.25
		cc.Contrast = 0.15
		cc.Saturation = -0.3
		cc.TintColor = Color3.fromRGB(190, 255, 200)
		cc.Parent = Lighting
	elseif not on and cc then
		cc:Destroy()
	end
	local ch = player.Character
	if ch then
		ch:SetAttribute("NightVision", on)
	end
end
function Abilities.nightVision(): boolean
	return nightVision
end

-- Большой прыжок снежного барса: после разрешения сервера
local function hugeLeap()
	local root, hum = parts()
	if not root or not hum or hum.WalkSpeed <= 0 then
		return
	end
	local look = root.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.new(0, 0, -1)
	lastJump = os.clock()
	airJumps = 1
	root.AssemblyLinearVelocity = fwd * Config.LEAP_FORWARD
		+ Vector3.new(0, hum.JumpPower * Config.LEAP_UP_MULT, 0)
end

-- Активировать способность (клавиша или кнопка HUD)
function Abilities.use(id: string)
	local core = ClientState.Core
	if not core or not SpeciesData.has(core.Species, id) then
		return
	end
	if id == "NightVision" then
		Abilities.setNightVision(not nightVision)
		return
	end
	local res = Actions.call("Ability", id)
	if res and id == "HugeLeap" then
		hugeLeap()
	end
end

function Abilities.init()
	ClientState.onCore(function(core)
		if nightVision and not SpeciesData.has(core.Species, "NightVision") then
			Abilities.setNightVision(false)
		end
	end)
	UserInputService.JumpRequest:Connect(tryAirJump)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space then
			jumpHeld = true
		end
		if processed then
			return
		end
		local core = ClientState.Core
		local sp = core and SpeciesData.ById[core.Species]
		if not sp then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q and sp.Primary then
			Abilities.use(sp.Primary)
		elseif input.KeyCode == Enum.KeyCode.F and sp.Secondary then
			Abilities.use(sp.Secondary)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			jumpHeld = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		local core = ClientState.Core
		local root, hum = parts()
		if not core or not root or not hum then
			return
		end
		local grounded = Abilities.grounded(root, hum)
		if grounded and os.clock() - lastJump > 0.2 then
			airJumps = 0
		end
		-- планирование: держим прыжок (или кнопку прыжка на телефоне) во время падения
		local held = jumpHeld or hum.Jump
		local gliding = false
		if SpeciesData.has(core.Species, "Glide") and not grounded and held then
			local v = root.AssemblyLinearVelocity
			local fall = if SpeciesData.has(core.Species, "LongFlight")
				then Config.OWL_GLIDE_FALL
				else GLIDE_FALL
			if v.Y < fall then
				local look = root.CFrame.LookVector
				local fwd = Vector3.new(v.X, 0, v.Z)
				if fwd.Magnitude < hum.WalkSpeed then
					fwd = Vector3.new(look.X, 0, look.Z) * hum.WalkSpeed
				end
				root.AssemblyLinearVelocity = Vector3.new(fwd.X, fall, fwd.Z)
				gliding = true
			end
		end
		local ch = player.Character
		if ch and ch:GetAttribute("Gliding") ~= gliding then
			ch:SetAttribute("Gliding", gliding)
		end
	end)
	_ = GRAVITY_JUMP
end

return Abilities
