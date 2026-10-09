--!strict
--[[
	ShopService — бутик косметики (лакомства, без Robux и без случайных наград), надевание косметики, таланты.
	Покупать можно только дома (у бутика): сервер проверяет зону. Косметика не влияет на характеристики.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local ShopData = require(Shared.ShopData)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Interact = require(script.Parent.Interact)
local Movement = require(script.Parent.Movement)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local ShopService = {}

-- PlayerService перестраивает риг при смене косметики
ShopService.onLookChanged = nil :: ((Player) -> ())?

function ShopService.init()
	Interact.register("Shop", function(player)
		Remotes.getEvent("OpenUi"):FireClient(player, "Shop")
		return true, nil
	end)

	Router.register("Buy", 2, 4, function(player, id: any)
		local data = DataService.get(player)
		local item = type(id) == "string" and ShopData.ById[id] or nil
		if not data or not item then
			return false, "err.bad_request"
		end
		if data.Cosmetics.Owned[item.Id] then
			return false, "msg.owned"
		end
		if item.Rep then
			return false, "msg.rep_only"
		end
		local pos = AntiExploit.rootPos(player)
		if not pos or WorldData.zoneAt(pos) ~= "Home" then
			return false, "msg.shop_home_only"
		end
		local price = ShopData.price(item, Progression.repLevel(data.Rep.Street or 0))
		if not Progress.spend(player, price) then
			return false, "msg.not_enough"
		end
		data.Cosmetics.Owned[item.Id] = true
		data.Cosmetics.Equipped[item.Slot] = item.Id
		State.markCore(player)
		if ShopService.onLookChanged then
			ShopService.onLookChanged(player)
		end
		return true, Locale.m("msg.bought", { item = item.Name })
	end)

	-- id = "" — снять косметику со слота
	Router.register("Equip", 3, 6, function(player, slot: any, id: any)
		local data = DataService.get(player)
		if
			not data
			or type(slot) ~= "string"
			or data.Cosmetics.Equipped[slot] == nil
			or type(id) ~= "string"
		then
			return false, "err.bad_request"
		end
		if id ~= "" then
			local item = ShopData.ById[id]
			if not item or item.Slot ~= slot or not data.Cosmetics.Owned[id] then
				return false, "err.bad_request"
			end
		end
		data.Cosmetics.Equipped[slot] = id
		State.markCore(player)
		if ShopService.onLookChanged then
			ShopService.onLookChanged(player)
		end
		return true, nil
	end)

	Router.register("Talent", 3, 6, function(player, id: any)
		local data = DataService.get(player)
		if not data or type(id) ~= "string" then
			return false, "err.bad_request"
		end
		local ok, why = Progression.canLearn(data.Level, data.Talents, id)
		if not ok then
			return false, why
		end
		data.Talents[id] = Progression.rank(data.Talents, id) + 1
		Movement.apply(player)
		State.markCore(player)
		return true, nil
	end)
end

return ShopService
