--!strict
--[[
	Interact — объекты мира с ProximityPrompt. WorldBuilder создаёт подсказку (Interact.prompt), сервисы
	регистрируют обработчики (Interact.register). Расстояние проверяет сам Roblox (MaxActivationDistance) и ещё раз
	сервер (AntiExploit.near) — подсказка тоже приходит от клиента.
	Атрибуты подсказки: Action, Arg, Species (для подсказок способностей: клиент прячет чужие).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage.Shared.Locale)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local Session = require(script.Parent.Session)

local Interact = {}

type Handler = (Player, ProximityPrompt, string?) -> (boolean, any)
local handlers: { [string]: Handler } = {}

function Interact.register(action: string, fn: Handler)
	assert(handlers[action] == nil, "duplicate interact " .. action)
	handlers[action] = fn
end

function Interact.dispatch(player: Player, prompt: ProximityPrompt): (boolean, any)
	local action = prompt:GetAttribute("Action")
	local arg = prompt:GetAttribute("Arg")
	local fn = type(action) == "string" and handlers[action] or nil
	local s = Session.get(player)
	if not fn or not s or not s.Ready or not DataService.get(player) then
		return false, nil
	end
	if not Session.cooldown(player, "prompt", 0.25) then
		return false, nil
	end
	local part = prompt.Parent
	if part and part:IsA("BasePart") then
		if not AntiExploit.near(player, part.Position, prompt.MaxActivationDistance + 6) then
			AntiExploit.strike(player, "prompt distance", 2)
			return false, nil
		end
	end
	local ok, res, msg = pcall(fn, player, prompt, if type(arg) == "string" then arg else nil)
	if not ok then
		warn("[Interact] handler error", action, res)
		return false, nil
	end
	if msg ~= nil then
		Notify.send(player, msg, if res then "info" else "error")
	end
	return res == true, msg
end

-- Создаёт подсказку на детали
function Interact.prompt(
	part: BasePart,
	action: string,
	textKey: string,
	opts: { [string]: any }?
): ProximityPrompt
	local o: any = opts or {}
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt_" .. action
	p.MaxActivationDistance = o.Distance or 9
	p.HoldDuration = o.Hold or 0
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = o.Key or Enum.KeyCode.E
	p.Style = Enum.ProximityPromptStyle.Default
	p:SetAttribute("Action", action)
	if o.Arg then
		p:SetAttribute("Arg", o.Arg)
	end
	if o.Species then
		p:SetAttribute("Species", o.Species)
	end
	Locale.setWorld(p, textKey, nil, "ActionText")
	if o.Object then
		Locale.setWorld(p, o.Object, nil, "ObjectText")
	end
	p.Parent = part
	p.Triggered:Connect(function(player: Player)
		Interact.dispatch(player, p)
	end)
	return p
end

return Interact
