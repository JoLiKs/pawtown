--!nonstrict
--[[
	Abilities — движение способностей на клиенте (физика персонажа принадлежит клиенту):
	  * кошка — двойной прыжок (DoubleJump);
	  * попугай — два взмаха в воздухе (Flap) и планирование (Glide: держи прыжок при падении);
	  * Q — Нюх (собака) / Рывок (кролик) через сервер (Ability).
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
	if SpeciesData.has(species, "Flap") then
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

function Abilities.init()
	UserInputService.JumpRequest:Connect(tryAirJump)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space then
			jumpHeld = true
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			local core = ClientState.Core
			if core and SpeciesData.has(core.Species, "Sniff") then
				Actions.call("Ability", "Sniff")
			elseif core and SpeciesData.has(core.Species, "Dash") then
				Actions.call("Ability", "Dash")
			end
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
			if v.Y < GLIDE_FALL then
				local look = root.CFrame.LookVector
				local fwd = Vector3.new(v.X, 0, v.Z)
				if fwd.Magnitude < hum.WalkSpeed then
					fwd = Vector3.new(look.X, 0, look.Z) * hum.WalkSpeed
				end
				root.AssemblyLinearVelocity = Vector3.new(fwd.X, GLIDE_FALL, fwd.Z)
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
