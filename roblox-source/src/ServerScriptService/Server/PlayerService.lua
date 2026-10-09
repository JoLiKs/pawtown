--!strict
--[[
	PlayerService — жизненный цикл игрока: загрузка данных (session lock), мягкий офлайн-пересчёт потребностей,
	язык, персонаж-питомец (PetRig: player.Character = риг), тег над головой, выбор вида в приюте, катсцены
	«Усыновление» и «Сон», респаун при падении.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local NeedsLogic = require(Shared.NeedsLogic)
local PetRig = require(Shared.PetRig)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local SpeciesData = require(Shared.SpeciesData)
local WorldData = require(Shared.WorldData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Interact = require(script.Parent.Interact)
local LanguageService = require(script.Parent.LanguageService)
local Movement = require(script.Parent.Movement)
local NeedsService = require(script.Parent.NeedsService)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local QuestService = require(script.Parent.QuestService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local ShopService = require(script.Parent.ShopService)
local State = require(script.Parent.State)

local PlayerService = {}

local SHELTER_EXIT = Vector3.new(-130, 3, 22)
local dreaming: { [Player]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Где появиться (новичок — в приюте; по дороге домой — у приюта; иначе — дома)
function PlayerService.spawnPoint(data: any): CFrame
	if data.Species == "" then
		return CFrame.new(WorldData.SPAWN_SHELTER) * CFrame.Angles(0, math.rad(180), 0)
	end
	local step = QuestService.currentStep(data)
	if step and step.Id == "c1_home" then
		return CFrame.new(SHELTER_EXIT)
	end
	return CFrame.new(WorldData.SPAWN_HOME) * CFrame.Angles(0, math.rad(180), 0)
end

local function makeTag(head: BasePart): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = "OverheadTag"
	g.Size = UDim2.fromOffset(160, 38)
	g.StudsOffset = Vector3.new(0, 2.2, 0)
	g.MaxDistance = 60
	g.LightInfluence = 0
	g:SetAttribute("LabelKind", "Player")
	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.56)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.45
	name.Parent = g
	local sub = Instance.new("TextLabel")
	sub.Name = "SubLabel"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.56)
	sub.Size = UDim2.fromScale(1, 0.44)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 220, 120)
	sub.TextStrokeTransparency = 0.5
	sub.Parent = g
	g.Parent = head
	return g
end

function PlayerService.refreshTag(player: Player)
	local data = DataService.get(player)
	local ch = player.Character
	local head = ch and ch:FindFirstChild("Head") :: BasePart?
	if not data or not head then
		return
	end
	local g = head:FindFirstChild("OverheadTag") :: BillboardGui? or makeTag(head)
	local nameLabel = (g :: BillboardGui):FindFirstChild("NameLabel") :: TextLabel
	local sub = (g :: BillboardGui):FindFirstChild("SubLabel") :: TextLabel
	nameLabel.Text = player.DisplayName
	local sp = SpeciesData.ById[data.Species]
	if sp then
		Locale.setWorld(sub, "tag.pet", { n = data.Level, species = sp.Name })
	else
		Locale.setWorld(sub, "tag.new")
	end
end

function PlayerService.spawn(player: Player, at: CFrame?)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return
	end
	local cf = at or PlayerService.spawnPoint(data)
	local scale = Progression.AGE_SCALE[Progression.age(data.Level)] or 1
	local speciesId = if data.Species ~= "" then data.Species else "Dog"
	local rig = PetRig.build(
		speciesId,
		cf,
		{ Scale = scale, Cosmetics = data.Cosmetics.Equipped, Name = player.Name }
	)
	if data.Species == "" then
		-- до выбора вида — «питомец в коробке»: серый безликий силуэт
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = Color3.fromRGB(175, 175, 185)
			end
		end
	end
	rig:SetAttribute("Player", player.UserId)
	local old = player.Character
	AntiExploit.markTeleport(player)
	player.Character = rig
	rig.Parent = Workspace
	if old and old ~= rig then
		old:Destroy()
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	Movement.apply(player)
	PlayerService.refreshTag(player)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.delay(2, function()
				if player.Parent and player.Character == rig then
					PlayerService.spawn(player)
				end
			end)
		end)
	end
end

-- Перестроить риг на месте (смена косметики/возраста/вида)
function PlayerService.respawnInPlace(player: Player)
	local root = rootOf(player)
	local at = if root then root.CFrame + Vector3.new(0, 0.5, 0) else nil
	PlayerService.spawn(player, at)
end

local function playDream(player: Player)
	if dreaming[player] then
		return
	end
	dreaming[player] = true
	local root = rootOf(player)
	if root then
		AntiExploit.markTeleport(player)
		root.CFrame = CFrame.lookAt(
			WorldData.SPAWN_DREAM + Vector3.new(0, 2, 6),
			WorldData.SPAWN_DREAM + Vector3.new(0, 2, -12)
		)
	end
	Remotes.getEvent("Cutscene"):FireClient(player, "Dream")
	task.wait(11)
	dreaming[player] = nil
	if not player.Parent then
		return
	end
	local r2 = rootOf(player)
	if r2 then
		AntiExploit.markTeleport(player)
		r2.CFrame = CFrame.new(WorldData.Home.PetBed + Vector3.new(0, 3, 3))
	end
	QuestService.event(player, "dream")
end

function PlayerService.chooseSpecies(player: Player, id: any): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.bad_request"
	end
	if data.Species ~= "" then
		return false, "msg.species_chosen"
	end
	if not SpeciesData.isStandard(id) then
		return false, "err.bad_request"
	end
	data.Species = id
	data.Needs = NeedsLogic.default()
	State.markCore(player)
	PlayerService.respawnInPlace(player)
	Remotes.getEvent("Cutscene"):FireClient(player, "Adoption", id)
	QuestService.event(player, "species", id)
	return true, nil
end

local function onPlayerAdded(player: Player)
	local session = Session.create(player)
	local data, err = DataService.load(player)
	if not data then
		Session.destroy(player)
		if player.Parent then
			local lang = Locale.detect(nil, LanguageService.localeId(player), nil)
			player:Kick(Locale.get(lang, "kick.load_failed", { err = tostring(err) }))
		end
		return
	end
	if not player.Parent then
		return
	end
	-- мягкий офлайн-пересчёт
	NeedsLogic.offline(data.Needs, os.time() - (data.NeedsAt or os.time()))
	data.NeedsAt = os.time()
	data.LastSeen = os.time()
	LanguageService.apply(player)
	QuestService.ensureDaily(player, data)
	session.Ready = true
	State.push(player)
	PlayerService.spawn(player)
	if DataService.isNewPlayer(player) then
		Notify.send(player, "welcome.new", "info")
	else
		Notify.send(player, "welcome.back", "info")
	end
end

local function onPlayerRemoving(player: Player)
	local data = DataService.get(player)
	if data then
		data.LastSeen = os.time()
		data.NeedsAt = os.time()
	end
	DataService.release(player)
	Session.destroy(player)
	dreaming[player] = nil
	local ch = player.Character
	if ch then
		ch:Destroy()
	end
end

function PlayerService.init()
	Router.register("ChooseSpecies", 1, 3, PlayerService.chooseSpecies)
	Router.register("Resync", 1, 3, function(player)
		State.push(player)
		return true, nil
	end)
	Interact.register("Species", function(player)
		Remotes.getEvent("OpenUi"):FireClient(player, "Species")
		return true, nil
	end)
	ShopService.onLookChanged = PlayerService.respawnInPlace
	Progress.onAgeChanged = PlayerService.respawnInPlace
	Progress.onLevel = function(player)
		PlayerService.refreshTag(player)
	end
	table.insert(NeedsService.sleepEndHooks, function(player)
		if QuestService.stepId(player) == "c1_dream" then
			playDream(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	-- атрибуты для анимаций у всех клиентов + страховка от падения
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				local ch = player.Character
				local root = rootOf(player)
				if s and s.Ready and ch then
					local carry = s.Carrying or ""
					if ch:GetAttribute("Carrying") ~= carry then
						ch:SetAttribute("Carrying", carry)
					end
					if root and root.Position.Y < -40 then
						PlayerService.spawn(player)
					end
				end
			end
		end
	end)
end

return PlayerService
