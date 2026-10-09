--!nocheck
-- Серверный помощник браузерного UI-теста Pawtown: ждёт команд из атрибута Workspace.UiCmd (ставит Playwright)
-- и выполняет их ЧЕРЕЗ ТЕ ЖЕ сервисы игры (выбор вида, телепорт, время суток). Клики по интерфейсу делает тест.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Server = ServerScriptService:WaitForChild("Server")
local AntiExploit = require(Server.AntiExploit)
local DataService = require(Server.DataService)
local DayNightService = require(Server.DayNightService)
local PlayerService = require(Server.PlayerService)
local Progress = require(Server.Progress)
local QuestService = require(Server.QuestService)
local Session = require(Server.Session)
local State = require(Server.State)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
while
	not (
		Session.get(player)
		and Session.get(player).Ready
		and player.Character
		and player.Character:FindFirstChild("HumanoidRootPart")
	)
do
	task.wait(0.2)
end

-- tp:x,z[,yaw]  — питомец в точку (камера за ним), yaw в градусах
local handlers = {}
function handlers.tp(arg)
	local x, z, yaw = string.match(arg, "^(-?[%d.]+),(-?[%d.]+),?(-?[%d.]*)$")
	AntiExploit.markTeleport(player)
	local cf = CFrame.new(tonumber(x), 4, tonumber(z)) * CFrame.Angles(0, math.rad(tonumber(yaw) or 0), 0)
	player.Character:PivotTo(cf)
end
function handlers.species(arg)
	PlayerService.chooseSpecies(player, arg)
end
function handlers.level(arg)
	local data = DataService.get(player)
	data.Level = tonumber(arg)
	State.markCore(player)
	PlayerService.refreshTag(player)
end
function handlers.treats(arg)
	DataService.get(player).Treats = tonumber(arg)
	State.markCore(player)
end
function handlers.clock(arg)
	DayNightService.setClock(tonumber(arg))
end
function handlers.ui(arg)
	Remotes.getEvent("OpenUi"):FireClient(player, arg)
end
function handlers.cut(arg)
	Remotes.getEvent("Cutscene"):FireClient(player, arg)
end
function handlers.needs(arg)
	local data = DataService.get(player)
	for k, v in string.gmatch(arg, "(%a+)=(%d+)") do
		data.Needs[k] = tonumber(v)
	end
	State.markCore(player)
end
function handlers.quest(arg)
	-- продвинуть главу до шага с id arg
	local data = DataService.get(player)
	for i = 1, 10 do
		if QuestService.stepId(player) == arg or QuestService.stepId(player) == nil then
			break
		end
		data.Story.Step += 1
		data.Story.P = 0
		_ = i
	end
	State.markCore(player)
end
function handlers.xp(arg)
	Progress.xp(player, tonumber(arg))
end
function handlers.hud(arg)
	local g = player.PlayerGui:FindFirstChild("PawtownGui")
	if g then
		g.Enabled = arg ~= "off"
	end
end

local last
while true do
	local cmd = Workspace:GetAttribute("UiCmd")
	if cmd and cmd ~= last and cmd ~= "" then
		last = cmd
		local name, arg = string.match(cmd, "^([%w_]+):?(.*)$")
		local ok, err = pcall(handlers[name] or function() end, arg)
		print(ok and ("UIDRIVER ok " .. cmd) or ("UIDRIVER FAIL " .. cmd .. " " .. tostring(err)))
		Workspace:SetAttribute("UiCmd", "")
		last = ""
	end
	task.wait(0.1)
end
