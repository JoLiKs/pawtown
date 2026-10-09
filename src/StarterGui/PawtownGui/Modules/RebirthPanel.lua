--!nonstrict
--[[
	RebirthPanel — «Ночь Искр»: перерождение в редкий вид.
	Сверху — звёзды перерождений (бонус опыта и лакомств) и выбор наследуемого таланта. Ниже — карточки видов
	(SpeciesCard, поток без обрезки): путь, условия с галочками, кнопки «Испытание» и «Переродиться».
	Легендарные виды — «Скоро». В Studio (и только там) — кнопка разработчика «выполнить условия».
	Редкие виды не продаются: их открывают только игрой.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Progression = require(Shared:WaitForChild("Progression"))
local RebirthLogic = require(Shared:WaitForChild("RebirthLogic"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local SpeciesCard = require(script.Parent.SpeciesCard)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local RebirthPanel = {}

local TIER_COLOR = { Rare = Color3.fromRGB(90, 150, 255), Legendary = Color3.fromRGB(255, 190, 60) }

local function flowText(
	parent: Instance,
	name: string,
	order: number,
	size: number,
	color: Color3?
): TextLabel
	return Ui.text({
		Name = name,
		Text = "",
		TextSize = size,
		TextColor3 = color or Theme.Text,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- Состояние, которое нужно для «дома»/проверок на клиенте (то же, что у сервера: RebirthLogic)
local function dataFromCore(core: any): any
	local shards, lineage, trials = {}, {}, {}
	for _, id in ipairs(core.Shards or {}) do
		shards[id] = true
	end
	local rb = core.Rebirth or {}
	for _, id in ipairs(rb.Lineage or {}) do
		lineage[id] = true
	end
	for _, id in ipairs(rb.Trials or {}) do
		trials[id] = true
	end
	return {
		Species = core.Species,
		Level = core.Level,
		Talents = core.Talents or {},
		Shards = shards,
		Bond = core.Bond or {},
		Tricks = core.Tricks or {},
		Lineage = lineage,
		Trials = trials,
	}
end
RebirthPanel.dataFromCore = dataFromCore

function RebirthPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "SparkNight", nil, { MinH = 540 })
	local scroll =
		Widgets.scroller(panel.Body, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 0) })
	Widgets.padding(scroll, 8)

	-- шапка: пояснение, звёзды, наследуемый талант
	local top = Ui.card({
		Name = "Top",
		LayoutOrder = 0,
		BackgroundColor3 = Color3.fromRGB(60, 40, 90),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Widgets.padding(top, 8)
	Ui.list(top, 6)
	local intro = flowText(top, "Intro", 1, 16, Theme.Text)
	L.bind(intro, "Text", L.k("rebirth.intro"))
	local stars = flowText(top, "Stars", 2, 16, Theme.Gold)
	local keep = flowText(top, "Keep", 3, 15, Theme.TextDim)
	L.bind(keep, "Text", L.k("rebirth.keep"))
	local inhRow = New("Frame", {
		Name = "InheritRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 4,
		Parent = top,
	})
	local inhLabel = Ui.text({
		Name = "Inherit",
		Text = "",
		TextSize = 16,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -150, 1, 0),
		Parent = inhRow,
	})
	local inherit = ""
	local options = { "" }
	local inhButton = Widgets.button({
		Name = "InheritNext",
		Text = L.k("rebirth.change"),
		Color = Theme.Purple,
		MaxTextSize = 16,
		Size = UDim2.fromOffset(140, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Parent = inhRow,
	})
	local trialInfo = flowText(top, "TrialInfo", 5, 16, Theme.Green)

	local function inheritText()
		local t = Progression.Talents[inherit]
		inhLabel.Text = L.t("rebirth.inherit", { talent = if t then t.Name else L.t("rebirth.none") })
	end
	inhButton.Activated:Connect(function()
		local i = table.find(options, inherit) or 1
		inherit = options[i % #options + 1]
		inheritText()
	end)

	local cards = {}
	local ui = {}
	local order = 0
	for _, sp in ipairs(SpeciesData.List) do
		if sp.Tier ~= "Standard" then
			order += 1
			local entry = {}
			local card = SpeciesCard.build(sp, order, {
				Extra = function(c, n)
					local tier = flowText(c, "Tier", n, 15, TIER_COLOR[sp.Tier])
					entry.Tier = tier
					local req = New("Frame", {
						Name = "Req",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = n + 1,
						Parent = c,
					})
					Ui.list(req, 2)
					entry.Req = req
					local row = New("Frame", {
						Name = "Buttons",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = n + 2,
						Parent = c,
					})
					Ui.list(row, 6)
					local function btn(name, key, color, i, fn)
						local b = Widgets.button({
							Name = name,
							Text = L.k(key),
							Color = color,
							MaxTextSize = 17,
							Size = UDim2.new(1, 0, 0, 36),
							LayoutOrder = i,
							Parent = row,
						})
						if fn then
							b.Activated:Connect(function()
								if b.Active then
									fn()
								end
							end)
						end
						return b
					end
					if RebirthLogic.available(sp.Id) then
						entry.Trial = btn("Trial", "rebirth.trial", Theme.Blue, 1, function()
							Actions.call("TrialStart", sp.Id)
						end)
						entry.Reborn = btn("Reborn", "rebirth.reborn", Theme.Purple, 2, function()
							if Actions.call("Rebirth", sp.Id, inherit) then
								panel.Close()
							end
						end)
						entry.Dev = btn("Dev", "rebirth.dev", Color3.fromRGB(120, 120, 130), 3, function()
							Actions.call("DevFastTrack", sp.Id)
						end)
						entry.Dev.Visible = false
					else
						local soon = btn("Soon", "rebirth.soon", Theme.Disabled, 1, nil)
						soon.Active = false
					end
					return n + 3
				end,
			})
			Widgets.stroke(card, TIER_COLOR[sp.Tier] or Theme.Gold, 2)
			table.insert(cards, card)
			ui[sp.Id] = entry
		end
	end
	SpeciesCard.grid(scroll, cards)
	top.Parent = scroll -- шапка — во всю ширину, над сеткой карточек

	ClientState.onCore(function(core)
		local rb = core.Rebirth or {}
		local data = dataFromCore(core)
		stars.Text = L.t("rebirth.stars", {
			n = rb.Stars or 0,
			max = RebirthLogic.MAX_STARS,
			pct = math.floor(((rb.Mult or 1) - 1) * 100 + 0.5),
		})
		options = { "" }
		for _, id in ipairs(RebirthLogic.inheritable(data)) do
			table.insert(options, id)
		end
		if not table.find(options, inherit) then
			inherit = options[#options] or ""
		end
		inheritText()
		local t = rb.Trial
		trialInfo.Visible = t ~= nil
		if t then
			trialInfo.Text = L.t("rebirth.trial_progress", {
				species = SpeciesData.ById[t.Id] and SpeciesData.ById[t.Id].Name or t.Id,
				n = t.Index - 1,
				total = t.Total,
				sec = t.Left,
			})
		end
		for id, e in pairs(ui) do
			local sp = SpeciesData.ById[id]
			if e.Tier and sp then
				local names = {}
				for _, f in ipairs(sp.From or {}) do
					table.insert(names, L.n(f))
				end
				e.Tier.Text = if sp.From
					then L.t("rebirth.path", { tier = "tier." .. sp.Tier, from = table.concat(names, ", ") })
					else L.t("tier." .. sp.Tier)
			end
			if e.Req then
				Widgets.clear(e.Req)
				local list, ok = RebirthLogic.check(data, id)
				for i, r in ipairs(list) do
					local line = New("Frame", {
						Name = r.Key,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 22),
						LayoutOrder = i,
						Parent = e.Req,
					})
					Ui.icon(
						if r.Ok then "Check" else "Lock",
						18,
						{ Position = UDim2.fromOffset(0, 2), Parent = line }
					)
					local key = "req." .. r.Key
					Ui.text({
						Name = "Text",
						Text = if r.Key == "Path"
								or r.Key == "Trial"
								or r.Key == "Age"
							then L.t(key .. (if r.Ok then ".ok" else ".no"))
							else L.t(key, { have = math.floor(r.Have), need = r.Need }),
						TextSize = 15,
						TextWrapped = false,
						TextColor3 = if r.Ok then Theme.Green else Theme.TextDim,
						Size = UDim2.new(1, -26, 1, 0),
						Position = UDim2.fromOffset(26, 0),
						Parent = line,
					})
				end
				if e.Trial then
					local canTrial = RebirthLogic.canTrial(data, id)
					local done = data.Trials[id] == true
					local running = t ~= nil and t.Id == id
					e.Trial.Text = L.t(
						if done
							then "rebirth.trial_ok"
							elseif running then "rebirth.trial_running_btn"
							else "rebirth.trial"
					)
					Widgets.setEnabled(e.Trial, canTrial and not running, Theme.Blue)
					Widgets.setEnabled(e.Reborn, ok, Theme.Purple)
					e.Dev.Visible = rb.Dev == true
				end
			end
		end
	end)
	return panel
end

return RebirthPanel
