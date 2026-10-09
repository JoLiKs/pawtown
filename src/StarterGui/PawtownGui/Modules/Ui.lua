--!nonstrict
--[[
	Ui — мелкие строительные блоки интерфейса Pawtown поверх Widgets: карточка, подпись, полоса, кнопка-значок,
	корневой слой HUD с общим масштабом (Theme.uiScale) и размерами в «дизайнерских» px.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local Ui = {}

-- Слой на весь экран: дочерние элементы задаются в дизайнерских px, видимый размер = px × k
function Ui.root(gui: ScreenGui, name: string, z: number?): (Frame, () -> number)
	-- якорь по центру: UIScale масштабирует относительно AnchorPoint, слой остаётся на весь экран
	local f = New("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z or 2,
		Parent = gui,
	})
	local sc = New("UIScale", { Parent = f })
	local k = 1
	Layout.onChanged(function(lay)
		k = Theme.uiScale(lay)
		sc.Scale = k
		f.Size = UDim2.fromScale(1 / k, 1 / k)
	end)
	return f, function()
		return k
	end
end

function Ui.card(props: { [string]: any }): Frame
	local p = {
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}
	for key, v in pairs(props) do
		p[key] = v
	end
	local f = New("Frame", p)
	Widgets.corner(f, props.Radius or 12)
	local st = Widgets.stroke(f, Color3.new(0, 0, 0), 2)
	st.Transparency = 0.55
	return f
end

-- Подпись фиксированного размера текста (TextSize в дизайнерских px)
function Ui.text(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1,
		Font = Theme.FontBody,
		TextColor3 = Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}
	for key, v in pairs(props) do
		p[key] = v
	end
	return New("TextLabel", p)
end

function Ui.icon(kind: string, size: number, props: { [string]: any }?): Frame
	local p = { Name = "Icon", Px = size, Size = UDim2.fromOffset(size, size) }
	if props then
		for key, v in pairs(props) do
			p[key] = v
		end
	end
	return Icons.make(kind, p)
end

-- Полоса прогресса: возвращает рамку и функцию set(0..1)
function Ui.bar(
	parent: Instance,
	pos: UDim2,
	size: UDim2,
	color: Color3,
	name: string?
): (Frame, (number) -> ())
	local back = New("Frame", {
		Name = name or "Bar",
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(30, 24, 34),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Widgets.corner(back, 6)
	local fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	})
	Widgets.corner(fill, 6)
	return back, function(v: number)
		fill.Size = UDim2.fromScale(math.clamp(v, 0, 1), 1)
	end
end

-- Квадратная кнопка-значок (без текста): Name, IconKind, Size, Color, OnClick, Position, AnchorPoint, Parent
function Ui.iconButton(props: { [string]: any }): TextButton
	local size = props.Size or 58
	local btn = New("TextButton", {
		Name = props.Name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or Theme.BgLight,
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 4,
		Parent = props.Parent,
	})
	Widgets.corner(btn, math.floor(size * 0.28))
	New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.35, Parent = btn })
	Icons.make(props.IconKind, {
		Name = "Icon",
		Px = math.floor(size * 0.66),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.66),
		ZIndex = (props.ZIndex or 4) + 1,
		Parent = btn,
	})
	local sc = New("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		Widgets.tween(sc, 0.1, { Scale = 1.07 })
	end)
	btn.MouseLeave:Connect(function()
		Widgets.tween(sc, 0.1, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		Widgets.tween(sc, 0.06, { Scale = 0.92 })
	end)
	btn.MouseButton1Up:Connect(function()
		Widgets.tween(sc, 0.1, { Scale = 1 })
	end)
	if props.OnClick then
		btn.Activated:Connect(props.OnClick)
	end
	return btn
end

function Ui.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

Ui.NEED_COLORS = {
	Hunger = Color3.fromRGB(245, 160, 70),
	Energy = Color3.fromRGB(110, 170, 255),
	Hygiene = Color3.fromRGB(110, 220, 230),
	Fun = Color3.fromRGB(250, 210, 80),
	Love = Color3.fromRGB(250, 110, 150),
}
Ui.MEDAL_COLORS = {
	[0] = Theme.Disabled,
	[1] = Color3.fromRGB(205, 127, 50),
	[2] = Color3.fromRGB(200, 205, 215),
	[3] = Color3.fromRGB(255, 205, 60),
}
Ui.ABILITY_ICON = {
	DoubleJump = "Jump",
	RoofRun = "Home",
	Sniff = "Sniff",
	Dig = "Dig",
	Burrow = "Burrow",
	Dash = "Dash",
	Glide = "Glide",
	Flap = "Glide",
	Mimic = "Emote",
	BestBond = "Love",
	Stealth = "Leaf",
	Snatch = "Shop",
	HugeLeap = "Jump",
	RoofSprint = "Home",
	ShieldRoll = "Shield",
	CommandDogs = "Friends",
	CrystalSight = "Eye",
	Unlock = "Lock",
	Stash = "Shop",
	LongFlight = "Glide",
	NightVision = "Energy",
}
Ui.MEDAL_ICON = { [1] = "Bronze", [2] = "Silver", [3] = "Gold" }

return Ui
