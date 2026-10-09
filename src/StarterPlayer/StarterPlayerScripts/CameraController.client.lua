--!nonstrict
--[[
	CameraController — камера в помещениях (дом, приют):
	  * ограничение отдаления (CameraMaxZoomDistance) — камера не улетает за стены и над крышей;
	  * стены между камерой и питомцем становятся полупрозрачными (LocalTransparencyModifier — только у этого клиента);
	  * снаружи — обычная камера Roblox (с её собственной окклюзией «Zoom»).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldData"))

local player = Players.LocalPlayer
local INSIDE_MAX, OUTSIDE_MAX = 16, 48
local FADE = 0.75

local faded: { [BasePart]: boolean } = {}
local lastInside = nil

local function isWall(p: Instance): boolean
	return p:IsA("BasePart") and (p.Name == "Wall" or p:GetAttribute("HomeRoof") == true)
end

local function step()
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		return
	end
	local pos = root.Position
	local zone = WorldData.zoneAt(pos)
	local inside = (zone == "Home" or zone == "Shelter") and pos.Y < 11
	if inside ~= lastInside then
		lastInside = inside
		player.CameraMaxZoomDistance = if inside then INSIDE_MAX else OUTSIDE_MAX
		player.CameraMinZoomDistance = 4
	end
	local now: { [BasePart]: boolean } = {}
	if inside then
		-- до 4 стен между головой питомца и камерой
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { ch }
		local from = pos + Vector3.new(0, 1.5, 0)
		local to = cam.CFrame.Position
		for _ = 1, 4 do
			params.FilterDescendantsInstances = ignore
			local dir = to - from
			if dir.Magnitude < 0.1 then
				break
			end
			local hit = Workspace:Raycast(from, dir, params)
			if not hit then
				break
			end
			if isWall(hit.Instance) then
				now[hit.Instance :: BasePart] = true
			end
			table.insert(ignore, hit.Instance)
		end
	end
	for p in pairs(now) do
		if not faded[p] then
			p.LocalTransparencyModifier = FADE
		end
	end
	for p in pairs(faded) do
		if not now[p] and p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	faded = now
end

RunService.RenderStepped:Connect(step)
