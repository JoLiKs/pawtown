--!nonstrict
--[[
	BathGame — мини-игра «пена»: на питомце пятна грязи, каждое нужно потереть (3 касания) — появляется пена.
	Когда всё чисто — кнопка «Отряхнуться!». Оценка = доля чистых пятен × бонус за скорость; сервер сам
	проверяет время (не быстрее BATH_MIN_SECONDS) и ограничивает оценку (BathDone).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local L = require(Shared:WaitForChild("Locale"))
local SpeciesData = require(Shared:WaitForChild("SpeciesData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local BathGame = {}

local SPOTS = 7
local TIME = 25

function BathGame.init(gui: ScreenGui)
	local layer = Ui.root(gui, "BathGame", 30)
	layer.Visible = false
	local box = Ui.card({
		Name = "Box",
		Size = UDim2.fromOffset(460, 430),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(60, 110, 150),
		BackgroundTransparency = 0.05,
		ZIndex = 30,
		Parent = layer,
	})
	local title = Ui.text({ Name = "Title", Text = L.k("bath.title"), Font = Theme.Font, TextSize = 24, Size = UDim2.new(1, -120, 0, 30), Position = UDim2.fromOffset(14, 10), ZIndex = 31, Parent = box })
	local hint = Ui.text({ Name = "Hint", Text = L.k("bath.hint"), TextSize = 17, Size = UDim2.new(1, -28, 0, 22), Position = UDim2.fromOffset(14, 42), ZIndex = 31, Parent = box })
	local timer = Ui.text({ Name = "Timer", Font = Theme.Font, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(100, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), ZIndex = 31, Parent = box })
	local stage = New("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.fromRGB(200, 235, 250),
		Size = UDim2.fromOffset(300, 270),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		ZIndex = 31,
		Parent = box,
	})
	Widgets.corner(stage, 20)
	local petHolder = New("Frame", { Name = "Pet", BackgroundTransparency = 1, Size = UDim2.fromOffset(240, 240), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 32, Parent = stage })
	local shake = Widgets.button({ Name = "Shake", Text = L.k("bath.shake"), Color = Theme.Orange, MaxTextSize = 22, Size = UDim2.fromOffset(200, 50), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), ZIndex = 33, Visible = false, Parent = box })
	local cancel = Widgets.button({ Name = "Cancel", Text = L.k("btn.cancel"), Color = Theme.BgLight, MaxTextSize = 18, Size = UDim2.fromOffset(120, 40), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -18), ZIndex = 33, Parent = box })
	local petScale = New("UIScale", { Parent = petHolder })

	local run = nil :: any
	local function clean(): number
		local n = 0
		for _, sp in ipairs(run.Spots) do
			if sp.Hits >= 3 then
				n += 1
			end
		end
		return n
	end

	local function finish()
		local r = run
		if not r or r.Sent then
			return
		end
		r.Sent = true
		local frac = clean() / SPOTS
		local elapsed = os.clock() - r.Start
		local speed = math.clamp(1 - (elapsed - 8) / 30, 0.6, 1)
		local score = frac * speed
		-- сервер не принимает слишком быструю ванну: подождать минимум
		local waitFor = Config.BATH_MIN_SECONDS + 0.3 - elapsed
		if waitFor > 0 then
			task.wait(waitFor)
		end
		-- «отряхивание»
		for i = 1, 6 do
			petHolder.Rotation = if i % 2 == 0 then 12 else -12
			task.wait(0.07)
		end
		petHolder.Rotation = 0
		Actions.call("BathDone", score)
		run = nil
		layer.Visible = false
	end

	shake.Activated:Connect(function()
		task.spawn(finish)
	end)
	cancel.Activated:Connect(function()
		run = nil
		layer.Visible = false
		Actions.call("BathCancel")
	end)

	function BathGame.open()
		local core = ClientState.Core or {}
		Widgets.clear(petHolder)
		local species = if SpeciesData.ById[core.Species] then core.Species else "Dog"
		Ui.icon(species, 240, { ZIndex = 32, Parent = petHolder })
		local rng = Random.new()
		local spots = {}
		for i = 1, SPOTS do
			local a = (i / SPOTS) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local rr = rng:NextNumber(0.18, 0.36)
			local b = New("TextButton", {
				Name = "Spot" .. i,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(120, 85, 50),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(52, 52),
				Position = UDim2.fromScale(0.5 + math.cos(a) * rr, 0.5 + math.sin(a) * rr),
				ZIndex = 34,
				Parent = petHolder,
			})
			Widgets.corner(b, 26)
			local sp = { Button = b, Hits = 0 }
			b.Activated:Connect(function()
				if not run or sp.Hits >= 3 then
					return
				end
				sp.Hits += 1
				-- грязь -> пена
				local t = sp.Hits / 3
				b.BackgroundColor3 = Color3.fromRGB(120, 85, 50):Lerp(Color3.fromRGB(250, 252, 255), t)
				b.Size = UDim2.fromOffset(52 + 10 * sp.Hits, 52 + 10 * sp.Hits)
				if clean() == SPOTS then
					shake.Visible = true
					hint.Text = L.t("bath.done_hint")
				end
			end)
			spots[i] = sp
		end
		shake.Visible = false
		hint.Text = L.t("bath.hint")
		petScale.Scale = 1
		layer.Visible = true
		run = { Start = os.clock(), Spots = spots }
		task.spawn(function()
			local my = run
			while run == my and run do
				local left = math.max(0, TIME - (os.clock() - my.Start))
				timer.Text = string.format("%d", math.ceil(left))
				if left <= 0 then
					shake.Visible = true
					task.spawn(finish)
					break
				end
				task.wait(0.2)
			end
		end)
	end
	_ = title
	return BathGame
end

return BathGame
