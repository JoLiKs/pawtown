--!strict
-- Единая точка создания/получения RemoteEvent и RemoteFunction.
-- Сервер создаёт их при старте (Remotes.init), клиент ждёт через WaitForChild.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

Remotes.Events = {
	"State", -- S->C: снимок состояния игрока (Core)
	"Notify", -- S->C: всплывающее сообщение (text, kind)
	"Fx", -- S->C: эффекты (kind, ...): LevelUp, Shard, Medal, Gift, Speech, Dig, Sniff
	"Cutscene", -- S->C: катсцена ("Adoption" | "Dream")
	"OpenUi", -- S->C: открыть окно (ProximityPrompt в мире): Species, Shop, Tricks, Bath, Rebirth
}
Remotes.Functions = {
	"Action", -- C->S: все действия игрока (Router на сервере: валидация, лимиты частоты)
}

local folder: Folder? = nil

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init must be called on the server")
	local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
	end
	local fld = f :: Folder
	for _, name in ipairs(Remotes.Events) do
		if not fld:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = fld
		end
	end
	for _, name in ipairs(Remotes.Functions) do
		if not fld:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = fld
		end
	end
	folder = fld
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	folder = f
	return f
end

function Remotes.getEvent(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
