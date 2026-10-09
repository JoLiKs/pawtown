--!nonstrict
--[[
	SpeciesCard — карточка вида (выбор в приюте и «Звёздная ночь»): значок, имя, описание, способности,
	скорость/прыжок и кнопка. Вёрстка «потоком» (UIListLayout + AutomaticSize): текст переносится и
	никогда не обрезается ни на ПК, ни на телефоне. SpeciesCard.grid раскладывает карточки в 1 или 2 колонки.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local SpeciesCard = {}

local function row(parent: Instance, order: number, h: number): Frame
	return New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h),
		LayoutOrder = order,
		Parent = parent,
	})
end

-- opts: { Button = {Text=key, Color, OnClick}, Extra = function(card, nextOrder) }
function SpeciesCard.build(sp: any, order: number, opts: any): Frame
	local o = opts or {}
	local card = Ui.card({
		Name = sp.Id,
		BackgroundColor3 = o.Color or Theme.BgCard,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Widgets.padding(card, 8)
	Ui.list(card, 4)
	local head = row(card, 1, 60)
	head.Name = "Head"
	local iconBack = New("Frame", {
		BackgroundColor3 = sp.Look.Body,
		BackgroundTransparency = 0.6,
		Size = UDim2.fromOffset(60, 60),
		Parent = head,
	})
	Widgets.corner(iconBack, 30)
	Ui.icon(
		sp.Id,
		52,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = iconBack }
	)
	Ui.text({
		Name = "Title",
		Text = L.kn(sp.Name),
		Font = Theme.Font,
		TextSize = 22,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(70, 0),
		Parent = head,
	})
	Ui.text({
		Name = "Desc",
		Text = L.kn(sp.Desc),
		TextSize = 16,
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = card,
	})
	local n = 10
	for _, abId in ipairs(sp.Abilities) do
		local ab = SpeciesData.Abilities[abId]
		if ab then
			n += 1
			local r = row(card, n, 24)
			r.Name = "Ab_" .. abId
			Ui.icon(Ui.ABILITY_ICON[abId] or "Paw", 22, { Position = UDim2.fromOffset(2, 1), Parent = r })
			Ui.text({
				Text = L.kn(ab.Name),
				TextSize = 16,
				TextWrapped = false,
				Size = UDim2.new(1, -32, 1, 0),
				Position = UDim2.fromOffset(30, 0),
				Parent = r,
			})
		end
	end
	local function stat(key: string, v: number, color: Color3)
		n += 1
		local r = row(card, n, 20)
		r.Name = "Stat_" .. key
		Ui.text({
			Text = L.k(key),
			TextSize = 15,
			TextWrapped = false,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(0, 104, 1, 0),
			Parent = r,
		})
		local _, set = Ui.bar(r, UDim2.new(0, 108, 0.5, -5), UDim2.new(1, -110, 0, 10), color)
		set(math.clamp(v, 0.05, 1))
	end
	stat("species.speed", (sp.Speed - 0.7) / 0.6, Theme.Green)
	stat("species.jump", (sp.Jump - 0.7) / 0.6, Theme.Blue)
	if o.Extra then
		n = o.Extra(card, n + 1) or n + 1
	end
	if o.Button then
		local r = row(card, 90, 38)
		r.Name = "Buttons"
		o.Button.Name = o.Button.Name or "Choose"
		local b = Widgets.button({
			Name = o.Button.Name,
			Text = L.k(o.Button.Text),
			Color = o.Button.Color or Theme.Green,
			MaxTextSize = 18,
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 2),
			Parent = r,
			OnClick = o.Button.OnClick,
		})
		card:SetAttribute("HasButton", true)
		o.Button.Instance = b
	end
	return card
end

-- Раскладка карточек: 2 колонки (ПК, телефон горизонтально) или 1 (телефон вертикально).
-- Карточки кладутся в строки-фреймы; при смене режима строки пересобираются.
function SpeciesCard.grid(scroll: ScrollingFrame, cards: { Frame })
	Ui.list(scroll, 8)
	local rows = {}
	local function arrange(lay)
		local cols = if lay.Mode == "portrait" then 1 else 2
		for _, c in ipairs(cards) do
			c.Parent = nil
		end
		for _, r in ipairs(rows) do
			r:Destroy()
		end
		table.clear(rows)
		for i, c in ipairs(cards) do
			local ri = math.ceil(i / cols)
			local r = rows[ri]
			if not r then
				r = New("Frame", {
					Name = "Row" .. ri,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = ri,
					Parent = scroll,
				})
				Ui.list(r, 8, true)
				rows[ri] = r
			end
			c.Size = UDim2.new(1 / cols, if cols == 1 then 0 else -4, 0, 0)
			c.LayoutOrder = i
			c.Parent = r
		end
	end
	Layout.onChanged(arrange)
end

return SpeciesCard
