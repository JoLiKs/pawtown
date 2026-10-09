--!strict
--[[
	Main — точка входа сервера Pawtown. Порядок: Remotes и мир, затем сервисы (регистрируют действия Router и
	подсказки Interact), и только потом PlayerService (начинает принимать игроков).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false -- персонаж-питомец создаётся сервером (PetRig)

local Server = script.Parent:WaitForChild("Server")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.init()

require(Server.WorldBuilder).build()
require(Server.DataService).init()
require(Server.Router).init()
require(Server.State).init()
require(Server.AntiExploit).init()
require(Server.DayNightService).init()
require(Server.QuestService).init()
require(Server.NeedsService).init()
require(Server.FamilyService).init()
require(Server.ParkService).init()
require(Server.AbilityService).init()
require(Server.RareAbilities).init()
require(Server.TrickService).init()
require(Server.SocialService).init()
require(Server.StoryService).init()
require(Server.ShopService).init()
require(Server.LanguageService).init()
require(Server.RebirthService).init()
require(Server.PlayerService).init()

print("[Pawtown] Server started. JobId:", game.JobId)
