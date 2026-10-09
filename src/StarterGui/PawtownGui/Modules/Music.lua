--!nonstrict
--[[
	Music — фоновая музыка и короткие звуки на клиенте (подход roblox-game Music.lua v3.3, перенесён в Pawtown).
	  * днём — «Кленовая улица» (Config.SOUNDS.MUSIC_DAY), ночью — «Колыбельная фонарей» (MUSIC_NIGHT); между ними
	    плавный кроссфейд Config.MUSIC.FADE секунд; ночь — по Lighting.ClockTime (DayNight.isNight);
	  * настройки игрока Core.Audio (AudioData): музыка вкл/выкл, громкость, звуки вкл/выкл;
	  * группы SoundService «Music» и «SFX»: переключатели настроек = громкость групп; ВСЕ прочие звуки мира и
	    персонажей (шаги, прыжок, приземление) тоже попадают в «SFX», поэтому «Звуки: выкл» глушит и их;
	  * ID = 0 — звука нет: ничего не создаётся и не играет (никаких ошибок и пустых Sound);
	  * загрузка с повторами: TimedOut — ждём и пробуем снова (паузы растут), Failure — сломан только после
	    AudioData.MAX_FAILURES попыток подряд; сломанный звук — одна запись в лог, дальше пропускается, игра
	    работает (вторая тема играет вместо сломанной; Play не повторяется каждый кадр);
	  * звуки: голос питомца (эмоции Voice / Mimic любого игрока, в точке персонажа, Config.VOICES), подбор
	    предмета / осколка (PICKUP), шаг главы или ежедневное задание (QUEST_DONE).
	Атрибуты gui для тестов: MusicStatus, MusicTarget, MusicTracks, AudioFailed, SfxVolume, LastSfx.
]]
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioData = require(Shared:WaitForChild("AudioData"))
local Config = require(Shared:WaitForChild("Config"))
local DayNight = require(Shared:WaitForChild("DayNight"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent.ClientState)

local Music = {}

type Track = { Sound: Sound, Mix: number, Base: number, Key: string, Loaded: boolean }
local tracks: { [string]: Track } = {}
local settings = AudioData.normalize(nil)
local health = AudioData.newHealth()
local guiRef: ScreenGui? = nil
local musicGroup: SoundGroup? = nil
local sfxGroup: SoundGroup? = nil
local lastStatus = ""
local SFX_KEYS = { "BARK", "MEOW", "SQUEAK", "CHIRP", "HOOT", "PICKUP", "QUEST_DONE" }

local function publish()
	local g = guiRef
	if g then
		g:SetAttribute(
			"MusicTracks",
			(if tracks.Day then "Day" else "") .. (if tracks.Night then "Night" else "")
		)
		g:SetAttribute("AudioFailed", AudioData.failedList(health))
	end
end

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local ng = Instance.new("SoundGroup")
	ng.Name = name
	ng.Volume = 1
	ng.Parent = SoundService
	return ng
end

local function applyGroups()
	if musicGroup then
		musicGroup.Volume = if settings.Music then 1 else 0
	end
	if sfxGroup then
		sfxGroup.Volume = if settings.Sfx then 1 else 0
	end
end

-- любой звук без группы (звуки персонажей RbxCharacterSounds, звуки в мире) — в группу «Звуки»
function Music.route(o: Instance)
	local g = sfxGroup
	if g and o:IsA("Sound") and o.SoundGroup == nil then
		o.SoundGroup = g
	end
end

function Music.fail(key: string, why: string?)
	if not AudioData.reportFailure(health, key, why) then
		return
	end
	warn(
		("[Music] sound %s (%s) unavailable after %d attempts: %s; skipped"):format(
			key,
			tostring(Config.SOUNDS[key]),
			AudioData.MAX_FAILURES,
			why or "?"
		)
	)
	publish()
end

local function statusName(st: any): string
	if st == Enum.AssetFetchStatus.Success then
		return "Success"
	elseif st == Enum.AssetFetchStatus.Failure then
		return "Failure"
	elseif st == Enum.AssetFetchStatus.TimedOut then
		return "TimedOut"
	end
	return tostring(st)
end

local function load(key: string, target: any, onLoaded: (() -> ())?)
	task.spawn(function()
		while true do
			local status = "Success"
			local ok: boolean, err: any = pcall(function()
				ContentProvider:PreloadAsync({ target }, function(_contentId, st)
					status = statusName(st)
				end)
			end)
			if not ok then
				status = "Failure"
			end
			if typeof(target) == "Instance" and target:IsA("Sound") and target.IsLoaded then
				status = "Success"
			end
			local res, delay = AudioData.loadResult(health, key, status)
			if res == "ok" then
				if onLoaded then
					onLoaded()
				end
				return
			elseif res == "broken" then
				Music.fail(key, if ok then status else tostring(err))
				return
			end
			print(("[Music] %s: %s, retry in %ds"):format(key, status, delay or 0))
			task.wait(delay or 5)
			if typeof(target) == "Instance" and target:IsA("Sound") and not target.IsLoaded then
				local id = target.SoundId
				target.SoundId = ""
				target.SoundId = id
			end
		end
	end)
end

function Music.settings()
	return settings
end

local function usable(name: string): boolean
	local t = tracks[name]
	return t ~= nil and not AudioData.isFailed(health, t.Key)
end

local function isNight(): boolean
	return DayNight.isNight(Lighting.ClockTime)
end

function Music.target(): string?
	if not settings.Music then
		return nil
	end
	return AudioData.musicTarget(isNight(), usable("Day"), usable("Night"))
end

-- состояние для окна настроек: "off" | "playing" | "loading" | "error", код ошибки
function Music.status(): (string, string?)
	local target = Music.target()
	local t = if target then tracks[target] else nil
	local err = health.Failed.MUSIC_DAY or health.Failed.MUSIC_NIGHT
	return AudioData.musicStatus(
		settings.Music,
		t ~= nil,
		t ~= nil and (t.Loaded or t.Sound.IsLoaded),
		t ~= nil and t.Sound.IsPlaying,
		err
	)
end

local function startTrack(t: Track)
	local s = t.Sound
	if s.IsPaused then
		s:Resume() -- тема продолжает с того же места
	else
		s:Play()
	end
end

local function step(dt: number)
	local target = Music.target()
	for name, t in pairs(tracks) do
		t.Mix = AudioData.fadeStep(t.Mix, if name == target then 1 else 0, dt, Config.MUSIC.FADE)
		local s = t.Sound
		s.Volume = AudioData.gain(t.Mix, t.Base, settings.MusicVol)
		if t.Mix > 0 and not s.IsPlaying then
			if AudioData.tryPlay(health, t.Key, os.clock()) then
				startTrack(t)
			end
		elseif t.Mix <= 0 and s.IsPlaying then
			s:Pause()
		end
	end
	local st, code = Music.status()
	local line = st .. (if code then " " .. code else "")
	if line ~= lastStatus then
		lastStatus = line
		local t = if target then tracks[target] else nil
		print(
			("[Music] status=%s track=%s loaded=%s playing=%s group=%.2f musicOn=%s vol=%.1f"):format(
				line,
				target or "-",
				tostring(t ~= nil and t.Sound.IsLoaded),
				tostring(t ~= nil and t.Sound.IsPlaying),
				if musicGroup then musicGroup.Volume else -1,
				tostring(settings.Music),
				settings.MusicVol
			)
		)
		local g = guiRef
		if g then
			g:SetAttribute("MusicStatus", line)
		end
	end
end

-- короткий звук из Config.SOUNDS (если звуки включены и ассет не сломан); с at — в точке мира / на детали
function Music.sfx(key: string, at: (Vector3 | BasePart)?, volume: number?, speed: number?)
	local g = guiRef
	if g then
		g:SetAttribute("LastSfx", key)
	end
	local id = AudioData.soundId(Config.SOUNDS[key])
	if not id or not settings.Sfx or AudioData.isFailed(health, key) then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. key
	s.SoundId = id
	s.Volume = volume or Config.MUSIC.SFX_VOLUME
	s.PlaybackSpeed = speed or 1
	s.SoundGroup = sfxGroup
	if typeof(at) == "Vector3" then
		local att = Instance.new("Attachment")
		att.Name = "SfxAt"
		att.Position = at -- Terrain в начале координат: Position == мировая точка
		att.Parent = Workspace.Terrain
		s.RollOffMinDistance = 10
		s.RollOffMaxDistance = 90
		s.Parent = att
		Debris:AddItem(att, 4)
	elseif typeof(at) == "Instance" then
		s.RollOffMinDistance = 10
		s.RollOffMaxDistance = 90
		s.Parent = at
		Debris:AddItem(s, 4)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 4)
	end
	s:Play()
end

-- голос вида (эмоции Voice / Mimic): слышно рядом с питомцем, у каждого вида свой звук или высота
function Music.voice(species: string?, at: (Vector3 | BasePart)?)
	local v = Config.VOICES[species or ""] or Config.VOICES.Dog
	Music.sfx(v.Key, at, Config.MUSIC.VOICE_VOLUME, v.Speed)
end

local function watchCharacter(ch: Model)
	local last = ch:GetAttribute("Emote")
	ch:GetAttributeChangedSignal("Emote"):Connect(function()
		local v = ch:GetAttribute("Emote")
		if v == last or type(v) ~= "string" then
			return
		end
		last = v
		local id = string.split(v, ":")[1]
		if id == "Voice" or id == "Mimic" then
			local sp = ch:GetAttribute("Species")
			Music.voice(
				if type(sp) == "string" then sp else nil,
				ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			)
		end
	end)
end

local function watchPlayer(p: Player)
	if p.Character then
		watchCharacter(p.Character)
	end
	p.CharacterAdded:Connect(watchCharacter)
end

function Music.init(gui: ScreenGui)
	guiRef = gui
	musicGroup = group("Music")
	sfxGroup = group("SFX")
	applyGroups()
	local folder = Instance.new("Folder")
	folder.Name = "PawtownMusic"
	folder.Parent = SoundService
	for _, name in ipairs({ "Day", "Night" }) do
		local key = if name == "Day" then "MUSIC_DAY" else "MUSIC_NIGHT"
		local id = AudioData.soundId(Config.SOUNDS[key])
		if id then
			local s = Instance.new("Sound")
			s.Name = "Music" .. name
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.SoundGroup = musicGroup
			s.Parent = folder
			local t: Track = {
				Sound = s,
				Mix = 0,
				Base = if name == "Night" then Config.MUSIC.NIGHT_VOLUME else Config.MUSIC.DAY_VOLUME,
				Key = key,
				Loaded = false,
			}
			tracks[name] = t
			local function onLoaded()
				if t.Loaded then
					return
				end
				t.Loaded = true
				print(("[Music] %s loaded (%s, %.0fs)"):format(name, id, s.TimeLength))
				if t.Mix > 0 and not s.IsPlaying then
					startTrack(t)
				end
			end
			s.Loaded:Connect(onLoaded)
			load(key, s, onLoaded)
		end
	end
	for _, key in ipairs(SFX_KEYS) do
		local id = AudioData.soundId(Config.SOUNDS[key])
		if id then
			load(key, id, nil)
		end
	end
	publish()
	for _, d in ipairs(Workspace:GetDescendants()) do
		Music.route(d)
	end
	Workspace.DescendantAdded:Connect(Music.route)
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	local carrying = ""
	ClientState.onCore(function(core)
		settings = AudioData.normalize(core and core.Audio)
		applyGroups()
		local c = core and core.Carrying or ""
		if c ~= carrying and c ~= "" then
			Music.sfx("PICKUP")
		end
		carrying = c
	end)
	Remotes.getEvent("Fx").OnClientEvent:Connect(function(kind)
		if kind == "Quest" or kind == "Daily" then
			Music.sfx("QUEST_DONE")
		elseif kind == "Shard" or kind == "Gift" then
			Music.sfx("PICKUP")
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
		gui:SetAttribute("MusicTarget", Music.target() or "")
		gui:SetAttribute("SfxVolume", if sfxGroup then sfxGroup.Volume else -1)
	end)
end

return Music
