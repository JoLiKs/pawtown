--!strict
--[[
	FamilyData — NPC-семья (хозяева). У каждого члена семьи своя шкала привязанности (Bond, 0..100).
	Подарки на порогах привязанности (один раз). Реплики — ключи локализации family.<Id>.<n>.
]]
local FamilyData = {}

export type Gift = { At: number, Treats: number?, Item: string? }
export type Member = { Id: string, Name: string, Role: string, Gifts: { Gift }, Lines: number, Likes: string }

FamilyData.List = {
	{
		Id = "Dad",
		Name = "Dad",
		Role = "Brings the newspaper home… with your help.",
		Likes = "newspaper",
		Lines = 3,
		Gifts = { { At = 20, Treats = 40 }, { At = 50, Item = "collar_blue" }, { At = 80, Treats = 150 } },
	},
	{
		Id = "Grandma",
		Name = "Grandma",
		Role = "Cooks, spoils you with snacks.",
		Likes = "beg",
		Lines = 3,
		Gifts = { { At = 20, Treats = 40 }, { At = 50, Item = "bandana_green" }, { At = 80, Treats = 150 } },
	},
	{
		Id = "Kid",
		Name = "Mia",
		Role = "Loves to play fetch and tricks.",
		Likes = "fetch",
		Lines = 3,
		Gifts = { { At = 20, Treats = 40 }, { At = 50, Item = "hat_party" }, { At = 80, Treats = 150 } },
	},
} :: { Member }

FamilyData.ById = {} :: { [string]: Member }
for _, m in ipairs(FamilyData.List) do
	FamilyData.ById[m.Id] = m
end

-- Уровень привязанности (для подписи): 0 Stranger, 1 Friend (20+), 2 Family (50+), 3 Best friends (80+)
function FamilyData.bondTier(v: number): number
	if v >= 80 then
		return 3
	elseif v >= 50 then
		return 2
	elseif v >= 20 then
		return 1
	end
	return 0
end

return FamilyData
