--!strict
-- Общие настройки Pawtown (клиент + сервер). Все балансные числа — здесь и в data-модулях.
local Config = {}

Config.VERSION = "0.2.0"
Config.GAME_NAME = "Pawtown" -- l10n-ok (имя собственное; RU-название — строка game.title_ru)

-- Веб-демо (roblox2web) включает быстрый день/ночь и подсказки; в Roblox всегда false
Config.WEB_DEMO = false

-- Сохранение (DataService)
Config.DATASTORE_NAME = "PawtownData_v1"
Config.AUTOSAVE_INTERVAL = 60
Config.SESSION_LOCK_TIMEOUT = 180
Config.LOAD_ATTEMPTS = 8
Config.LOAD_LOCK_RETRY_DELAY = 4
Config.SAVE_ATTEMPTS = 5
Config.STUDIO_FALLBACK_TO_EPHEMERAL = true

-- Движение
Config.BASE_WALKSPEED = 16
Config.BASE_JUMPPOWER = 42

-- Античит (см. AntiExploit)
Config.ANTICHEAT = {
	STRIKE_WINDOW = 60,
	STRIKE_KICK_THRESHOLD = 40,
	TELEPORT_GRACE = 2,
	SPEED_TOLERANCE = 1.6,
	SPEED_SLACK = 8,
	MAX_HORIZONTAL_SPEED = 90,
}

-- Потребности: минут от 100 до 0 при обычной активности (мягко: ~30–40 мин)
Config.NEED_EMPTY_MINUTES = {
	Hunger = 35,
	Energy = 40,
	Hygiene = 40,
	Fun = 30,
	Love = 36,
}
Config.NEED_TICK = 2 -- секунд между пересчётами на сервере
Config.OFFLINE_NEED_FLOOR = 40 -- офлайн потребности не опускаются ниже (без жёстких наказаний)
Config.HEALTH_DECAY_PER_MIN = 2 -- здоровье падает, только если 2+ потребности < 15
Config.HEALTH_REGEN_PER_MIN = 4

-- День/ночь: полный цикл (секунды реального времени); ночь — с 20:00 до 6:00 игровых
Config.DAY_LENGTH = 720
Config.DAY_LENGTH_DEMO = 300
Config.NIGHT_FROM = 20
Config.NIGHT_TO = 6

-- Прогресс
Config.MAX_LEVEL = 100
Config.TEEN_LEVEL = 10
Config.ADULT_LEVEL = 30

-- Взаимодействия
Config.INTERACT_DISTANCE = 12 -- макс. расстояние до объекта для действия через Router
Config.CUDDLE_COOLDOWN = 45
Config.BEG_COOLDOWN = 60
Config.DIG_COOLDOWN = 30 -- на каждую ямку
Config.SNIFF_COOLDOWN = 10
Config.DASH_COOLDOWN = 4
Config.DASH_TIME = 0.8
Config.DASH_MULT = 1.9
Config.ROOF_SPEED_MULT = 1.3
Config.EMOTE_COOLDOWN = 1.5
Config.FRIEND_RADIUS = 14
Config.FRIEND_PAIR_COOLDOWN = 20
Config.FRIEND_MAX_ENTRIES = 100
Config.FETCH_TIME_LIMIT = 30
Config.AGILITY_TIME_LIMIT = 90
Config.BATH_MIN_SECONDS = 5
Config.SLEEP_SECONDS = 6

-- «Ночь Искр» (перерождение). DEV_FAST_REBIRTH — кнопка «выполнить условия» для проверки в Studio:
-- работает ТОЛЬКО при RunService:IsStudio() (на живых серверах действие даже не регистрируется).
Config.DEV_FAST_REBIRTH = true

-- Способности редких видов
Config.ROOF_SPRINT_MULT = 1.6 -- снежный барс на крышах
Config.LEAP_COOLDOWN = 3
Config.LEAP_TIME = 1.6 -- окно повышенной легальной скорости
Config.LEAP_FORWARD = 46 -- студ/с вперёд
Config.LEAP_UP_MULT = 1.75 -- от силы прыжка
Config.ROLL_COOLDOWN = 3
Config.ROLL_TIME = 0.7
Config.STEALTH_RADIUS = 3.6 -- от центра куста
Config.STEALTH_LINGER = 4 -- секунд «невидимости» после выхода из куста
Config.SNATCH_COOLDOWN = 60 -- на NPC
Config.SIGHT_COOLDOWN = 12
Config.SIGHT_TIME = 10
Config.SIGHT_RADIUS = 170
Config.BIN_COOLDOWN = 120
Config.SHED_COOLDOWN = 600
Config.STASH_MAX = 20
Config.STASH_TREATS = 6
Config.DOGS_FOLLOW_TIME = 60
Config.DOGS_COMMAND_RADIUS = 40
Config.OWL_FLAPS = 5
Config.OWL_GLIDE_FALL = -4

-- Друзья
Config.FRIEND_LIST_MAX = 50
Config.VISIT_COOLDOWN = 10
Config.COMBO_WINDOW = 3 -- секунд: оба друга делают одну эмоцию рядом -> комбо

return Config
