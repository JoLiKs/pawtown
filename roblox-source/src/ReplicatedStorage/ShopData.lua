--!strict
--[[
	ShopData — косметика за лакомства (Treats). Без Robux, без случайных наград (шансы показывать не нужно),
	на характеристики не влияет (никакого pay-to-win). Slot: Collar | Neck | Hat.
]]
local c3 = Color3.fromRGB

export type Item = {
	Id: string,
	Slot: string,
	Name: string,
	Price: number,
	Color: Color3,
	Color2: Color3,
	Order: number,
	Rep: number?, -- не продаётся: награда за репутацию Кленовой улицы этого уровня
}

local ShopData = {}

ShopData.SLOTS = { "Collar", "Neck", "Hat" }

ShopData.List = {
	{
		Id = "collar_red",
		Slot = "Collar",
		Name = "Red Collar",
		Price = 40,
		Color = c3(220, 50, 60),
		Color2 = c3(250, 210, 80),
		Order = 1,
	},
	{
		Id = "collar_blue",
		Slot = "Collar",
		Name = "Blue Collar",
		Price = 40,
		Color = c3(60, 110, 230),
		Color2 = c3(220, 225, 235),
		Order = 2,
	},
	{
		Id = "collar_star",
		Slot = "Collar",
		Name = "Star Collar",
		Price = 120,
		Color = c3(60, 40, 120),
		Color2 = c3(255, 220, 90),
		Order = 3,
	},
	{
		Id = "bandana_green",
		Slot = "Neck",
		Name = "Green Bandana",
		Price = 60,
		Color = c3(70, 170, 90),
		Color2 = c3(240, 240, 240),
		Order = 4,
	},
	{
		Id = "bandana_plaid",
		Slot = "Neck",
		Name = "Plaid Bandana",
		Price = 90,
		Color = c3(200, 60, 60),
		Color2 = c3(40, 40, 50),
		Order = 5,
	},
	{
		Id = "hat_party",
		Slot = "Hat",
		Name = "Party Hat",
		Price = 80,
		Color = c3(240, 90, 200),
		Color2 = c3(255, 230, 90),
		Order = 6,
	},
	{
		Id = "hat_beanie",
		Slot = "Hat",
		Name = "Cozy Beanie",
		Price = 100,
		Color = c3(80, 160, 230),
		Color2 = c3(250, 250, 250),
		Order = 7,
	},
	{
		Id = "hat_crown",
		Slot = "Hat",
		Name = "Little Crown",
		Price = 300,
		Color = c3(250, 200, 50),
		Color2 = c3(230, 70, 90),
		Order = 8,
	},
	{
		Id = "hat_maple",
		Slot = "Hat",
		Name = "Maple Leaf Hat",
		Price = 1,
		Color = c3(230, 110, 40),
		Color2 = c3(250, 200, 60),
		Order = 9,
		Rep = 3,
	},
} :: { Item }

-- Цена с учётом скидки за репутацию улицы (уровень DISCOUNT_LEVEL+: -DISCOUNT_PCT%)
function ShopData.price(item: Item, streetRepLevel: number): number
	if streetRepLevel >= 2 then
		return math.max(1, math.floor(item.Price * 0.85 + 0.5))
	end
	return item.Price
end

ShopData.ById = {} :: { [string]: Item }
for _, it in ipairs(ShopData.List) do
	ShopData.ById[it.Id] = it
end

return ShopData
