--!nonstrict
--[[
	ShopPanel — бутик косметики (ошейники, банданы, шапки) за лакомства. Только внешний вид: никаких бонусов,
	никаких Robux и случайных покупок. Купить — у бутика дома (проверяет сервер), надеть/снять — где угодно.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Progression = require(Shared:WaitForChild("Progression"))
local ShopData = require(Shared:WaitForChild("ShopData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local ShopPanel = {}

function ShopPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Shop", nil, { MinH = 480 })
	local tabs = New("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 4),
		Parent = panel.Body,
	})
	Ui.list(tabs, 6, true)
	local note = Ui.text({
		Name = "Note",
		Text = L.k("shop.note"),
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.new(0, 8, 1, -42),
		Parent = panel.Body,
	})
	_ = note
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -94), Position = UDim2.fromOffset(4, 48) })
	Widgets.padding(scroll, 6)
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 132),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})

	local current = "Collar"
	local tabButtons = {}
	local cards = {}
	for i, item in ipairs(ShopData.List) do
		local card = Ui.card({
			Name = item.Id,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			LayoutOrder = i,
			Parent = scroll,
		})
		local sw = New("Frame", {
			Name = "Swatch",
			BackgroundColor3 = item.Color,
			Size = UDim2.fromOffset(54, 54),
			Position = UDim2.fromOffset(10, 10),
			Parent = card,
		})
		Widgets.corner(sw, if item.Slot == "Hat" then 8 else 27)
		Widgets.stroke(sw, Color3.new(0, 0, 0), 2).Transparency = 0.4
		local stripe = New("Frame", {
			BackgroundColor3 = item.Color2,
			Size = UDim2.new(1, -16, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = sw,
		})
		Widgets.corner(stripe, 5)
		Ui.text({
			Name = "Title",
			Text = L.kn(item.Name),
			Font = Theme.Font,
			TextSize = 18,
			Size = UDim2.new(1, -80, 0, 44),
			Position = UDim2.fromOffset(72, 8),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		Ui.icon("Treat", 22, { Position = UDim2.fromOffset(72, 52), Parent = card })
		local priceLabel = Ui.text({
			Name = "Price",
			Text = tostring(item.Price),
			Font = Theme.Font,
			TextSize = 18,
			Size = UDim2.new(1, -106, 0, 22),
			Position = UDim2.fromOffset(98, 52),
			Parent = card,
		})
		local btn = Widgets.button({
			Name = "Action",
			Text = "",
			MaxTextSize = 18,
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.new(0, 8, 1, -48),
			Parent = card,
		})
		cards[item.Id] = { Card = card, Button = btn, Item = item, Price = priceLabel }
		btn.Activated:Connect(function()
			local core = ClientState.Core or {}
			local cos = core.Cosmetics or { Owned = {}, Equipped = {} }
			if not cos.Owned[item.Id] then
				Actions.call("Buy", item.Id)
			elseif cos.Equipped[item.Slot] == item.Id then
				Actions.call("Equip", item.Slot, "")
			else
				Actions.call("Equip", item.Slot, item.Id)
			end
		end)
	end

	local function refresh()
		local core = ClientState.Core or {}
		local cos = core.Cosmetics or { Owned = {}, Equipped = {} }
		for _, c in pairs(cards) do
			c.Card.Visible = c.Item.Slot == current
			local price = ShopData.price(c.Item, Progression.repLevel((core.Rep or {}).Street or 0))
			c.Price.Text = if c.Item.Rep
				then L.t("shop.rep_reward", { n = c.Item.Rep })
				elseif price < c.Item.Price then L.t("shop.discount", { n = price, old = c.Item.Price })
				else tostring(price)
			if not cos.Owned[c.Item.Id] and c.Item.Rep then
				c.Button.Text = L.t("shop.rep_locked")
				Widgets.setEnabled(c.Button, false)
			elseif not cos.Owned[c.Item.Id] then
				c.Button.Text = L.t("btn.buy")
				Widgets.setEnabled(c.Button, (core.Treats or 0) >= price, Theme.Green)
			elseif cos.Equipped[c.Item.Slot] == c.Item.Id then
				c.Button.Text = L.t("btn.unequip")
				Widgets.setEnabled(c.Button, true, Theme.Orange)
			else
				c.Button.Text = L.t("btn.equip")
				Widgets.setEnabled(c.Button, true, Theme.Blue)
			end
		end
		for slot, b in pairs(tabButtons) do
			b.BackgroundColor3 = if slot == current then Theme.Pink else Theme.BgLight
		end
	end
	for i, slot in ipairs(ShopData.SLOTS) do
		tabButtons[slot] = Widgets.button({
			Name = "Tab" .. slot,
			Text = L.k("shop.slot." .. slot),
			Color = Theme.BgLight,
			MaxTextSize = 18,
			Size = UDim2.new(1 / #ShopData.SLOTS, -6, 1, 0),
			LayoutOrder = i,
			Parent = tabs,
			OnClick = function()
				current = slot
				refresh()
			end,
		})
	end
	ClientState.onCore(refresh)
	refresh()
	return panel
end

return ShopPanel
