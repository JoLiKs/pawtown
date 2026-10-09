--!nonstrict
--[[
	FriendsPanel — «Друзья»: заявки, игроки на этом сервере (добавить / в гости), мой список друзей
	(в сети ли, «в гости», убрать) и подсказка о комбо-эмоциях. Данные — снимок сервера (core.FriendsList).
	Имена — DisplayName из Roblox; переписка — только стандартный чат Roblox (своего чата в игре нет).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FriendsLogic = require(Shared:WaitForChild("FriendsLogic"))
local L = require(Shared:WaitForChild("Locale"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local FriendsPanel = {}

function FriendsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Friends", nil, { MinH = 520 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)
	Ui.list(scroll, 6)

	local function header(name: string, order: number): TextLabel
		return Ui.text({
			Name = name,
			Text = "",
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Theme.Gold,
			Size = UDim2.new(1, -4, 0, 26),
			LayoutOrder = order,
			Parent = scroll,
		})
	end
	local function holder(name: string, order: number): Frame
		local f = New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = scroll,
		})
		Ui.list(f, 6)
		return f
	end
	local function note(parent: Instance, text: string, order: number)
		Ui.text({
			Name = "Note",
			Text = text,
			TextSize = 15,
			TextColor3 = Theme.TextDim,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = parent,
		})
	end
	-- строка: имя/подпись слева, кнопки справа (переносятся под имя на узком экране не нужно: 2 кнопки по 96 px)
	local function entry(
		parent: Instance,
		name: string,
		title: string,
		sub: string,
		order: number,
		btns: { any }
	)
		local card = Ui.card({
			Name = name,
			BackgroundColor3 = Theme.BgCard,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = order,
			Parent = parent,
		})
		local bw = #btns * 100
		Ui.text({
			Name = "Name",
			Text = title,
			Font = Theme.Font,
			TextSize = 18,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -(bw + 20), 0, 26),
			Position = UDim2.fromOffset(10, 4),
			Parent = card,
		})
		Ui.text({
			Name = "Sub",
			Text = sub,
			TextSize = 14,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, -(bw + 20), 0, 20),
			Position = UDim2.fromOffset(10, 30),
			Parent = card,
		})
		for i, b in ipairs(btns) do
			local btn = Widgets.button({
				Name = b.Name,
				Text = L.t(b.Text),
				Color = b.Color,
				MaxTextSize = 16,
				Size = UDim2.fromOffset(94, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8 - (#btns - i) * 100, 0.5, 0),
				Parent = card,
			})
			if b.Enabled == false then
				Widgets.setEnabled(btn, false)
			end
			btn.Activated:Connect(function()
				if btn.Active and b.OnClick then
					b.OnClick()
				end
			end)
		end
		return card
	end

	local hReq = header("H_Requests", 1)
	local reqs = holder("Requests", 2)
	local hHere = header("H_Here", 3)
	local here = holder("Here", 4)
	local hList = header("H_List", 5)
	local list = holder("List", 6)
	local hCombo = header("H_Combos", 7)
	local combos = holder("Combos", 8)

	ClientState.onCore(function(core)
		local fl = core.FriendsList or { Friends = {}, Requests = {}, Here = {}, Max = 50 }
		hReq.Text = L.t("friends.requests")
		hReq.Visible = #fl.Requests > 0
		Widgets.clear(reqs)
		for i, r in ipairs(fl.Requests) do
			entry(reqs, "Req_" .. r.Id, r.Name, L.t("friends.wants"), i, {
				{
					Name = "Accept",
					Text = "friends.accept",
					Color = Theme.Green,
					OnClick = function()
						Actions.call("FriendAccept", r.Id, true)
					end,
				},
				{
					Name = "Decline",
					Text = "friends.decline",
					Color = Theme.BgLight,
					OnClick = function()
						Actions.call("FriendAccept", r.Id, false)
					end,
				},
			})
		end
		hHere.Text = L.t("friends.here", { n = #fl.Here })
		Widgets.clear(here)
		if #fl.Here == 0 then
			note(here, L.t("friends.here_none"), 1)
		end
		for i, p in ipairs(fl.Here) do
			local btns = {}
			if p.Friend then
				table.insert(btns, {
					Name = "Visit",
					Text = "friends.visit",
					Color = Theme.Blue,
					OnClick = function()
						if Actions.call("Visit", p.Id) then
							panel.Close()
						end
					end,
				})
			else
				table.insert(btns, {
					Name = "Add",
					Text = if p.Sent then "friends.sent" else "friends.add",
					Color = Theme.Green,
					Enabled = not p.Sent,
					OnClick = function()
						Actions.call("FriendRequest", p.Id)
					end,
				})
			end
			entry(
				here,
				"Here_" .. p.Id,
				p.Name,
				L.t(if p.Friend then "friends.is_friend" else "friends.player"),
				i,
				btns
			)
		end
		hList.Text = L.t("friends.list", { n = #fl.Friends, max = fl.Max })
		Widgets.clear(list)
		if #fl.Friends == 0 then
			note(list, L.t("friends.none"), 1)
		end
		for i, f in ipairs(fl.Friends) do
			entry(
				list,
				"Friend_" .. f.Id,
				f.Name,
				L.t(if f.Online then "friends.online" else "friends.offline", { n = f.Points }),
				i,
				{
					{
						Name = "Visit",
						Text = "friends.visit",
						Color = Theme.Blue,
						Enabled = f.Online,
						OnClick = function()
							if Actions.call("Visit", f.Id) then
								panel.Close()
							end
						end,
					},
					{
						Name = "Remove",
						Text = "friends.remove",
						Color = Theme.Red,
						OnClick = function()
							Actions.call("FriendRemove", f.Id)
						end,
					},
				}
			)
		end
		hCombo.Text = L.t("friends.combos")
		Widgets.clear(combos)
		note(combos, L.t("friends.combos_hint"), 0)
		for i, c in ipairs(FriendsLogic.COMBOS) do
			Ui.text({
				Name = "Combo_" .. c.Id,
				Text = L.t("combo." .. c.Id) .. ": " .. L.t("emote." .. c.A) .. " + " .. L.t("emote." .. c.B),
				TextSize = 15,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = combos,
			})
		end
	end)
	return panel
end

return FriendsPanel
