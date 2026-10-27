-- LocalScript (ВСЁ В ОДНОМ) — ФИНАЛ + ТАБЛИЧКИ + СВОБОДНЫЙ РЕЖИМ + ЭКРАН ЗАГРУЗКИ + УКРАШЕНИЯ
-- Положи в: StarterPlayer > StarterPlayerScripts > RailBuilder
-- Рельсы, таблички, украшения и вагонетка существуют только на твоём клиенте — другие игроки их не видят.
-- Сохранение между заходами работает, если в игре есть серверный скрипт RailSaveServer.
--
-- УКРАШЕНИЯ — кнопка «Декор» (или клавиша 9) закрывает нижнюю панель и открывает панель с украшениями:
-- в каждой карточке вместо картинки крутится объёмная модель. Выбери украшение и ставь его
-- на землю, на рельсы или на нужную высоту (E / Q). R — повернуть (шаг 15°), кнопка «Назад» — вернуть обычную панель.
-- Модели по ID (таблица MODELS) из LocalScript загрузить нельзя (InsertService работает только на сервере),
-- поэтому каждое украшение собрано из деталей прямо в этом скрипте.
-- Украшения: Дом (дверь, стена), Котость, Вода, Halloween (тыква, сено, надгробие, котёл), Новый год (ёлка, подарок, снеговик),
-- природа (куст, гриб, камень, цветы, костёр) и разное (забор, бочка, ящик, фонарь). Список листается стрелками по бокам.
-- Украшения сохраняются вместе с рельсами: в записи (6-е значение) лежит название украшения.
--
-- ДВЕРИ И ЖИТЕЛИ — в панели «Декор» есть «Дверь» и «Стена» (поворот по 90°). Подойди к двери: она подсветится, над ней
-- появится картинка; зажми E на 0.1 с — откроется. Пока на базе есть хоть одна дверь, там живут NPC (таблица Home):
-- гуляют внутри, иногда выходят на улицу и возвращаются, машут тебе (шанс 40%), прыгают от радости у двери
-- и пугаются, только если ты появился совсем резко (потом смотрят на тебя, смеются и уходят гулять или к двери).
-- Жители — R6, кожа бежевая, футболки из Home.SHIRTS, штаны из Home.PANTS (к штанам Sleep — футболка Sleep).
-- НПС → ОБУЧЕНИЕ: когда построена дверь, в нижней панели рядом со «Строить» и «Слоты» появляется кнопка «НПС».
-- В ней раздел «Обучение» со слотами маршрутов: «Запомнить» (пройди маршрут и нажми «Сохранить»), «Отправить» жителей
-- по этому маршруту, «Очистить». Жители идут точно по твоей линии (подсвечены Highlight), на месте удивляются (лицо amazed)
-- и бегом возвращаются домой; иногда сами ходят по сохранённым маршрутам (Home.VISIT_*).
-- Маршруты хранятся вместе со слотом постройки (записи с кодом 6; серверный скрипт должен хранить записи целиком).
-- Волосы — из Home.HAIRS. Мимика: лицо меняется по ситуации (готовится испугаться → испугался → перепугался / машет / рад / смеётся),
-- обычное лицо возвращается само; ID лиц лежат в Home.FACES.
-- ЧУЖИЕ РЯДОМ: если близко чужой NPC (модель с Humanoid, не игрок и не житель) — жители пугаются, вскрикивают и убегают от него.
-- Если близко объект с AnimationController — паника: все бегут вдвое быстрее к двери (снаружи заходят внутрь, внутри жмутся у двери).
-- Среди жителей бывают малыши: ростом поменьше, голос повыше, прыгают от радости чаще (настройки SMALL_* в таблице Home).
-- Здороваясь, житель машет рукой, говорит «Hi!» (облачко над головой) и проигрывает звук Home.SOUNDS.wave.
--
-- КАРТОЧКА ИГРОКА — после загрузки сверху падает карточка: аватарка твоего скина, ник и регион (флаг-смайлик).
-- Потом выезжают панели (карточка остаётся поверх них), а через пару секунд карточка уменьшается и уезжает в угол (настройки в таблице Profile).
--
-- «РЫБИЙ ГЛАЗ» — когда едешь в вагонетке очень быстро, угол обзора камеры раскрывается шире (настройки в таблице FX).
--
-- ЭКРАН ЗАГРУЗКИ — при входе 5 секунд (настройки в таблице LOAD): картинка прилетает в центр,
-- внизу появляется название, картинка пульсирует под музыку.
--
-- СВОБОДНЫЙ РЕЖИМ — переключатель как на iPhone (слева сверху в режиме строительства, или клавиша F).
-- Когда он включён, правил нет: рельсы ставятся где угодно и под любым углом, без сетки,
-- без «одна рельса на клетку», высота — с шагом в 1 стад.
--   R — повернуть · T — наклон · Y — крен (Shift — в обратную сторону) · N — шаг угла (90° / 45° / 15°)
--   M — магнит (рельса прилипает к свободному концу другой рельсы и стыкуется с ней)
--   V — зеркально (поставить рельсу другой стороной) · E / Q — выше / ниже · 8 — инструмент «Петля»
-- Вагонетка ездит по любым состыкованным путям, в том числе вверх ногами в верхней точке петли.
-- Для сохранения серверный скрипт должен хранить записи рельс целиком
-- (у свободных рельс в записи до 9 значений, у обычных — как раньше).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== Настройки =====
local GRID = 4
local BASE_HEIGHT = 0.4
local SLOT_COUNT = 5
local MAX_RAILS = 500
local SAVE_DELAY = 3
local RISE = 2          -- на сколько студов поднимается уклон = один уровень высоты
local MAX_LEVEL = 100    -- максимум уровней вверх
local CART_SPEEDS = { 8, 16, 28 }
local CART_SPEED_NAMES = { "🐢 Медленно", "🏃 Средне", "⚡ Быстро" }
local SEAT_OFFSET = CFrame.new(0, 2.3, 0.1) -- где сидит игрок относительно вагонетки
local SIGN_MAX_CHARS = 80   -- максимум символов на табличке
local SIGN_MAX_LINES = 4    -- максимум строк на табличке
local SIGN_DEFAULT = "Привет!"

-- картинки интерфейса
local IMG = {
	PLACE = "rbxassetid://4485364377",      -- кнопка «Поставить»
	DECOR = "rbxassetid://136476233036438", -- кнопка «Украшения»
}

-- ID моделей из каталога (для справки: из LocalScript модели по ID не загрузить, поэтому все украшения собраны в скрипте)
local MODELS = {
	pumpkin = 15429930446,     -- 🎃 Halloween: Тыква
	hay = 5117398695,          -- 🎃 Halloween: Сено
	tree = 11720499037,        -- 🎄 Merry Christmas: Ёлка
	gift = 332163549,          -- 🎄 Merry Christmas: Подарок
}

-- всё, что связано с украшениями, лежит в одной таблице (в скрипте и так много переменных)
local Decor = {
	list = { -- порядок и подписи карточек (для каждого ключа есть сборщик в Decor.builders)
		{ key = "door", name = "Дверь", tag = "Дом", turn = 90 },
		{ key = "wall", name = "Стена", tag = "Дом", turn = 90 },
		{ key = "kotost", name = "Котость", tag = "Питомец" },
		{ key = "water", name = "Вода", tag = "Разное" },
		{ key = "pumpkin", name = "Тыква", tag = "Halloween" },
		{ key = "hay", name = "Сено", tag = "Halloween" },
		{ key = "tombstone", name = "Надгробие", tag = "Halloween" },
		{ key = "cauldron", name = "Котёл", tag = "Halloween" },
		{ key = "tree", name = "Ёлка", tag = "Новый год" },
		{ key = "gift", name = "Подарок", tag = "Новый год" },
		{ key = "snowman", name = "Снеговик", tag = "Новый год" },
		{ key = "bush", name = "Куст", tag = "Природа" },
		{ key = "mushroom", name = "Гриб", tag = "Природа" },
		{ key = "rock", name = "Камень", tag = "Природа" },
		{ key = "flowers", name = "Цветы", tag = "Природа" },
		{ key = "campfire", name = "Костёр", tag = "Природа" },
		{ key = "fence", name = "Забор", tag = "Разное", turn = 90 },
		{ key = "barrel", name = "Бочка", tag = "Разное" },
		{ key = "crate", name = "Ящик", tag = "Разное" },
		{ key = "lamp", name = "Фонарь", tag = "Разное" },
	},
	GRID = 1,            -- шаг привязки украшений (студы)
	TURN = 15,           -- на сколько градусов поворачивает R
	open = false,        -- панель украшений открыта
	key = "door",        -- выбранное украшение
	ghostKey = nil,      -- какое украшение сейчас нарисовано призраком
	builders = {}, spinners = {}, cards = {}, angle = 0,
}

-- эффект «рыбий глаз»: на большой скорости (когда ты сидишь в вагонетке) угол обзора камеры раскрывается шире
local FX = {
	START = 18, -- с какой скорости (студов/с) начинается эффект
	FULL = 32,  -- на какой скорости эффект работает на полную
	ADD = 40,   -- на сколько градусов раскрывается угол обзора (обычно 70 → 110)
	IN = 3,     -- как быстро камера «разъезжается»
	OUT = 2.5,  -- как быстро возвращается обратно
	add = 0,    -- сколько градусов добавлено прямо сейчас
}

-- карточка игрока после загрузки (аватарка скина, ник, регион-флаг)
local Profile = {
	HOLD = 2.2,   -- сколько секунд карточка висит по центру, пока появляются панели
	KEEP = true,  -- true: потом уменьшается в правый верхний угол и остаётся поверх панелей; false: исчезает
	SMALL = 0.5,  -- во сколько раз уменьшается в углу
}

-- двери и жители (NPC)
local Home = {
	-- двери
	IMAGE = "rbxassetid://11274293900", -- картинка над дверью, когда к ней подходишь
	HOLD = 0.1,                         -- сколько секунд держать кнопку у двери
	RANGE = 11,                          -- с какого расстояния дверь замечает тебя (студы)
	-- жители
	MAX_NPC = 3,          -- сколько жителей (появляются, когда на базе есть хотя бы одна дверь)
	SMALL_CHANCE = 0.4,   -- шанс, что житель окажется малышом (если жителей 3, хотя бы один малыш будет всегда)
	SMALL_SCALE_MIN = 0.55, -- размер малыша: от ... (1 = обычный рост)
	SMALL_SCALE_MAX = 0.75, -- ... до ...
	WALK = 8,             -- скорость ходьбы
	IN_ROOM = 9,          -- насколько далеко от двери гуляют внутри (студы)
	OUT_ROOM = 12,         -- и снаружи
	SEE = 32,             -- с какого расстояния замечают тебя (студы)
	WAVE_CHANCE = 0.4,    -- шанс помахать, когда увидели тебя
	WAVE_COOLDOWN = 8,   -- не чаще, чем раз в столько секунд
	OUT_CHANCE = 0.4,     -- шанс выйти погулять, когда пришло время
	JOY_CHANCE = 0.6,     -- шанс подпрыгнуть от радости у двери, когда нагулялись
	SCARE_CHANCE = 0.7,   -- шанс испугаться, если ты появился слишком резко
	SCARE_DIST = 11,      -- ближе этого расстояния можно испугаться (студы)
	SCARE_SPEED = 30,     -- так быстро (студов/с) нужно к жителю приблизиться, чтобы он испугался
	SCARE_COOLDOWN = 40,  -- не чаще, чем раз в столько секунд
	ROUTE_MIN = 4,        -- самый короткий маршрут, который можно сохранить (точек; одна точка = STEP студов)
	ROUTE_SLOTS = 5,      -- сколько слотов маршрутов в разделе «Обучение»
	NPC_IMAGE = "rbxassetid://6236978075", -- картинка на кнопке «НПС» в нижней панели
	TITLE_IMAGE = "rbxassetid://11130226997", -- картинка в начале заголовка окна «НПС»
	DEBUG = true,         -- писать в консоль (Output), что происходит с обучением; потом можно поставить false
	LEARN_CHANCE = 1,     -- шанс, что житель пойдёт учиться (1 = каждый)
	STARE = 5,            -- сколько секунд удивляются на месте
	VISIT_MIN = 60,       -- как часто житель сам ходит на выученное место: от ... секунд
	VISIT_MAX = 120,      -- ... до ... секунд
	VISIT_CHANCE = 0.6,   -- и с каким шансом
	STEP = 2.5,           -- через сколько студов записывается точка твоего маршрута
	MAX_TRAIL = 600,      -- самый длинный маршрут (точек)
	FEAR_RADIUS = 18,     -- чужой NPC (модель с Humanoid, не игрок) ближе этого расстояния пугает жителей — они убегают
	FEAR_COOLDOWN = 15,   -- не чаще, чем раз в столько секунд
	ALARM_RADIUS = 22,    -- объект с AnimationController ближе этого — паника: бегут вдвое быстрее к двери
	FAST = 2,             -- во сколько раз быстрее бегут при испуге и панике
	SOUNDS = {
		wave = "rbxassetid://130780071265356",   -- здоровается: машет рукой и говорит «Hi!»
		joy = "rbxassetid://130926713428015",  -- прыгает от радости
		scare = "rbxassetid://75049633628598", -- испугался
		laugh = "rbxassetid://102769336849011", -- смеётся
	},
	ANIMS = { -- стандартные анимации Roblox для R6
		idle = 180435571, walk = 180426354, wave = 128777973, cheer = 129423030, laugh = 129423131,
	},
	SKIN = Color3.fromRGB(235, 205, 165), -- кожа (голова и руки) всегда бежевая
	SHIRTS = { -- футболки жителей (ID из каталога): McDonalds, Mellstroy, Red Bakon Boi, без названия
		90787762613314, 16350897656, 5171326293, 93665648144394,
	},
	PANTS = { -- штаны жителей (ID из каталога); shirt — какая футболка полагается именно к этим штанам
		{ id = 10174536646 }, -- Poor
		{ id = 8592697362 },  -- Bacon
		{ id = 1923579875, shirt = 6297766966 }, -- Sleep (к ним — футболка Sleep)
		{ id = 14285822913 }, -- Kit bermuda black
	},
	HAIRS = { -- волосы жителей (ID из каталога): Pal Hair, True Blue Hair, Brown Charmer Hair
		63690008, 451221329, 376548738,
	},
	hairNext = math.random(0, 2),
	FACES = { -- лица для эмоций (ID лиц из каталога); обычное лицо не меняем. ID — строками!
		prescare = "89760806612988",  -- готовится испугаться
		scared = "124751387086397",   -- испугался
		wave = "99812701718083",      -- машет тебе
		joy = "125715171707930",      -- рад
		terrified = "72403229016812", -- перепугался (убегает, паника)
		laugh = "16775193696",        -- смеётся
		amazed = "8595439578",        -- удивился (на месте, где «научился»)
	},
	shirtNext = math.random(0, 3),
	GREET = "Hi! 👋",      -- облачко над головой, когда здоровается
	doors = {}, npcs = {}, spawning = 0, acc = 0, lastSync = 0, failedAt = -100,
}

-- настройки экрана загрузки
local LOAD = {
	TIME = 5,                              -- сколько секунд длится загрузка
	IMAGE = "rbxassetid://136476233036438", -- картинка в центре
	SOUND = "rbxassetid://88060724643515",  -- музыка, под которую пульсирует картинка
	TITLE = "Котость.Rails",               -- текст под картинкой
	VOLUME = 0.8,                          -- громкость музыки
	PULSE = 0.16,                          -- насколько сильно картинка «бьётся» (0.16 = до +16% размера)
}

-- настройки свободного режима
local FCFG = {
	GRID = 1,                -- шаг привязки по горизонтали (студы)
	STEP = 1,                -- на сколько студов поднимает один шаг высоты
	MAX_LEVEL = 400,         -- максимум шагов высоты
	ANGLES = { 90, 45, 15 }, -- шаги поворота / наклона / крена (градусы), кнопка «Шаг»
	MAGNET = 3,              -- «липкость» магнита (студы)
	LOOP_RADIUS = 9,         -- радиус мёртвой петли
	LOOP_SHIFT = 4,          -- на сколько выезд из петли сдвинут вбок (чтобы не врезаться во въезд)
	LOOP_SEGMENTS = 36,      -- из скольких кусочков собрана петля
	END_TOL = 1.25,          -- насколько близко концы рельс должны быть друг к другу, чтобы вагонетка переехала
}

local RAMP_ANGLE = math.atan(RISE / GRID)
local RAMP_LEN = math.sqrt(GRID * GRID + RISE * RISE)

local WHITE = Color3.new(1, 1, 1)
local C = {
	bg = Color3.fromRGB(16, 18, 28),
	panel = Color3.fromRGB(24, 27, 41),
	card = Color3.fromRGB(37, 41, 61),
	accent = Color3.fromRGB(86, 204, 255),
	accentDark = Color3.fromRGB(38, 104, 158),
	good = Color3.fromRGB(80, 225, 140),
	goodDark = Color3.fromRGB(36, 128, 84),
	bad = Color3.fromRGB(255, 96, 96),
	badDark = Color3.fromRGB(156, 52, 60),
	warn = Color3.fromRGB(255, 205, 90),
	text = Color3.fromRGB(240, 244, 255),
	sub = Color3.fromRGB(148, 156, 184),
	swOn = Color3.fromRGB(52, 199, 89),  -- зелёный, как у переключателя на iPhone
	swOff = Color3.fromRGB(72, 76, 100),
}
local TOUCH_ONLY = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local KIND_CODE = { straight = 0, curve = 1, ramp = 2, sign = 3, loop = 4, decor = 5, route = 6 }
local CODE_KIND = { [0] = "straight", [1] = "curve", [2] = "ramp", [3] = "sign", [4] = "loop", [5] = "decor", [6] = "route" }

-- ===== Состояние =====
local data = nil
local railCount = 0
local busy = true
local saveFn = nil
local saveQueued = false
local saveState = "off" -- off / saving / saved / error

local buildMode = false
local tool = "straight" -- straight / curve / ramp / loop / sign / edit / erase / cart / decor
local rotTarget = 0
local level, refY = 0, 0 -- уровень высоты и высота земли для уровня 0
local ghost, ghostKind, ghostHL
local ghostShown, ghostCF -- ghostShown — где призрак нарисован сейчас, ghostCF — куда реально встанет рельса
local ghostValid = false
local hoverRail
local holding = false
local touchPos
local lastInputTouch = TOUCH_ONLY
local lastLimitToast = 0
local slotsOpen = false
local signText = SIGN_DEFAULT -- текст, который ставится на новые таблички

-- свободный режим: все его переменные собраны в одну таблицу
local FM = {
	on = false,          -- переключатель включён
	magnet = true,       -- магнит: прилипание к свободным концам других рельс
	flip = false,        -- «сторона»: рельса прикладывается концом, а не началом
	angle = 1,           -- номер шага угла в FCFG.ANGLES
	snapped = false,     -- призрак сейчас прилип к концу рельсы
	pitch = 0, roll = 0, -- наклон и крен «в воздухе» (поворот вокруг вертикали — это rotTarget)
	rel = { yaw = 0, pitch = 0, roll = 0 }, -- повороты относительно конца рельсы, к которому прилип призрак
}

function FM.wrap(v)
	return ((v + 180) % 360) - 180
end

function FM.levelStep() -- на сколько студов поднимается один «уровень» высоты
	return FM.on and FCFG.STEP or RISE
end

function FM.stepAngle()
	return FCFG.ANGLES[FM.angle]
end

-- сбрасываем всё, что настроено «под свободный режим»: наклон, крен, углы стыка, сторону, прилипание
function FM.resetAngles()
	FM.pitch, FM.roll = 0, 0
	FM.rel.yaw, FM.rel.pitch, FM.rel.roll = 0, 0, 0
	FM.flip = false
	FM.snapped = false
end

-- ближайший прямой угол (0 / 90 / 180 / 270) — обычные рельсы всегда стоят ровно по сетке
function FM.flatYaw(v)
	return (math.round(v / 90) * 90) % 360
end

local tileAt = {} -- [ "gx,gz" ] = модель рельсы / таблички (только обычный режим)
local pieces = {} -- [модель] = данные о пути рельсы / таблички
local eps = {}    -- концы всех рельс (для магнита и для переезда вагонетки)
local cart = nil

local toast, removeCart, refreshCartHud, refreshPill, refreshSlots

-- ===== Помощники =====
local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function round2(v)
	local r = math.round(v * 100) / 100
	if r ~= r then
		return 0
	end
	return r
end

local function cellKey(x, z)
	return (math.round(x / GRID) + 0) .. "," .. (math.round(z / GRID) + 0)
end

-- привязка к сетке: 4 студа в обычном режиме, 1 студ в свободном
local function snap(v)
	local g = FM.on and FCFG.GRID or GRID
	return math.round(v / g) * g
end

-- «5 объектов», «1 объект», «2 объекта»
local function objWord(n)
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then
		return n .. " объект"
	elseif m10 >= 2 and m10 <= 4 and (m100 < 10 or m100 >= 20) then
		return n .. " объекта"
	end
	return n .. " объектов"
end

-- Текст таблички: убираем управляющие символы, ограничиваем строки и длину
local function cleanSignText(s)
	s = tostring(s or "")
	s = s:gsub("\r", "")
	s = s:gsub("%c", function(ch)
		return (ch == "\n") and "\n" or ""
	end)
	if not utf8.len(s) then
		return ""
	end
	local lines = s:split("\n")
	if #lines > SIGN_MAX_LINES then
		s = table.concat(lines, "\n", 1, SIGN_MAX_LINES)
	end
	if utf8.len(s) > SIGN_MAX_CHARS then
		s = s:sub(1, utf8.offset(s, SIGN_MAX_CHARS + 1) - 1)
	end
	return s
end

-- то же, но ещё и обрезаем пробелы/пустые строки по краям
local function finalSignText(s)
	return (cleanSignText(s):match("^%s*(.-)%s*$")) or ""
end

-- записать текст на табличку (на обе стороны)
local function setSignText(model, text)
	model:SetAttribute("Text", text)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
end

-- ===== Фейковый экран загрузки =====
-- Картинка плавно прилетает в центр, ниже появляется название, а сама картинка пульсирует под музыку.
-- Громкость музыки читаем через PlaybackLoudness; пока музыка не заиграла (или не загрузилась),
-- картинка пульсирует по таймеру, чтобы экран не выглядел мёртвым.
local Loading = { done = false, uiReady = false }
do
	local vp = camera.ViewportSize
	local imgSize = math.clamp(math.min(vp.X, vp.Y) * 0.36, 120, 260)
	local half = imgSize / 2
	local titleY = half + imgSize * 0.12 + 30 -- где (по вертикали от центра экрана) стоит название
	local T = math.max(LOAD.TIME, 2)
	local FADE = 0.5                          -- последние полсекунды экран плавно гаснет

	local lgui = make("ScreenGui", {
		Name = "RailLoadingUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- CanvasGroup — чтобы гасить весь экран целиком одним твином
	local screen = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0,
		Active = true, GroupTransparency = 0, -- Active — чтобы клики не проходили сквозь экран загрузки
	}, lgui)

	local img = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.4), -- стартует за верхним краем экрана
		Size = UDim2.fromOffset(imgSize, imgSize),
		BackgroundTransparency = 1, Image = LOAD.IMAGE, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Rotation = -18,
	}, screen)
	local pulse = make("UIScale", {}, img)

	local title = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, titleY + 22),
		Size = UDim2.fromOffset(420, 44),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 34,
		TextColor3 = C.text, TextTransparency = 1, Text = LOAD.TITLE,
	}, screen)

	local track = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, titleY + 44),
		Size = UDim2.fromOffset(220, 6),
		BackgroundColor3 = C.card, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, screen)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0,
	}, track)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)

	local sound = make("Sound", {
		Name = "LoadingMusic", SoundId = LOAD.SOUND, Volume = LOAD.VOLUME, Looped = true,
	}, lgui)

	-- подгружаем картинку и звук заранее (не блокируя остальной скрипт)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ img, sound })
		end)
	end)
	sound:Play()

	-- пульс: удар по громкости — быстро вверх, затем плавно вниз
	local smooth = 0
	local heard = false
	local pulseConn = RunService.RenderStepped:Connect(function(dt)
		local loud = sound.PlaybackLoudness
		if loud > 2 then
			heard = true
		end
		local target
		if heard then
			target = math.clamp(loud / 400, 0, 1)
		else
			target = (math.sin(os.clock() * 7) * 0.5 + 0.5) * 0.45
		end
		local k = (target > smooth) and 25 or 7
		smooth += (target - smooth) * math.min(1, dt * k)
		pulse.Scale = 1 + smooth * LOAD.PULSE
	end)

	-- 0.0 с: картинка прилетает в центр
	tween(img, 1.3, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }, Enum.EasingStyle.Quint)
	tween(img, 0.6, { ImageTransparency = 0 })

	-- 0.9 с: появляются название и полоска загрузки
	task.delay(0.9, function()
		tween(title, 0.7, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, titleY) }, Enum.EasingStyle.Quint)
		tween(track, 0.5, { BackgroundTransparency = 0 })
		tween(fill, math.max(0.1, T - 0.9 - FADE), { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end)

	-- последние полсекунды: экран и музыка плавно гаснут
	task.delay(T - FADE, function()
		tween(screen, FADE, { GroupTransparency = 1 })
		tween(sound, FADE, { Volume = 0 })
	end)

	-- ровно через LOAD.TIME секунд: убираем экран, и дальше показываются обычные панели
	task.delay(T, function()
		pulseConn:Disconnect()
		sound:Stop()
		lgui:Destroy()
		Loading.done = true
	end)
end

-- ===== Мир: контейнер рельс (клиентский → виден только тебе) =====
local railsFolder = make("Model", { Name = "MyRails_LocalOnly" }, workspace)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local hoverParams = RaycastParams.new()
hoverParams.FilterType = Enum.RaycastFilterType.Include
hoverParams.FilterDescendantsInstances = { railsFolder }

local supportParams = RaycastParams.new()
supportParams.FilterType = Enum.RaycastFilterType.Exclude

-- ===== Геометрия путей =====
-- У каждой рельсы есть «путь»: точки вдоль её центра, направление движения в каждой точке
-- и «верх» пути (куда смотрит крыша вагонетки). Всё это — в системе координат самой рельсы.
local Geo = {}
do
	local Y_UP = Vector3.new(0, 1, 0)
	local dataCache, frameCache = {}, {}

	-- точка петли в системе координат рельсы (вход — в нуле, едем вдоль +Z);
	-- сдвиг вбок плавный, поэтому и вход, и выход идут строго прямо
	local function loopPoint(theta)
		local R = FCFG.LOOP_RADIUS
		local t = theta / (2 * math.pi)
		local sm = t * t * (3 - 2 * t)
		local dsm = 6 * t * (1 - t)
		local pos = Vector3.new(FCFG.LOOP_SHIFT * sm, R * (1 - math.cos(theta)), R * math.sin(theta))
		local d = Vector3.new(FCFG.LOOP_SHIFT * dsm / (2 * math.pi), R * math.sin(theta), R * math.cos(theta))
		local tan = d.Unit
		local upc = Vector3.new(0, math.cos(theta), -math.sin(theta)) -- «верх» смотрит в центр круга
		return pos, tan, (upc - tan * upc:Dot(tan)).Unit
	end

	-- система координат «стыка»: Z — вперёд по пути, Y — «верх»
	function Geo.frameCF(pos, fwd, up)
		local z = fwd.Unit
		local x = up:Cross(z).Unit
		local y = z:Cross(x)
		return CFrame.fromMatrix(pos, x, y, z)
	end

	-- путь рельсы: pts — точки, tans — направление, ups — «верх»;
	-- sDir/sUp и eDir/eUp — направление и «верх» на стыках (у уклона стыки плоские)
	function Geo.localData(kind)
		local cached = dataCache[kind]
		if cached then
			return cached
		end
		local pts, tans, ups = {}, {}, {}
		local h = GRID / 2
		if kind == "curve" then
			local n = 12
			local center = Vector3.new(h, 0, -h)
			for k = 0, n do
				local phi = k / n * math.pi / 2
				pts[k + 1] = center + Vector3.new(-math.cos(phi), 0, math.sin(phi)) * h
				tans[k + 1] = Vector3.new(math.sin(phi), 0, math.cos(phi))
				ups[k + 1] = Y_UP
			end
		elseif kind == "ramp" then
			local tan = Vector3.new(0, math.sin(RAMP_ANGLE), math.cos(RAMP_ANGLE))
			local up = Vector3.new(0, math.cos(RAMP_ANGLE), -math.sin(RAMP_ANGLE))
			pts = { Vector3.new(0, 0, -h), Vector3.new(0, RISE, h) }
			tans = { tan, tan }
			ups = { up, up }
		elseif kind == "loop" then
			for k = 0, FCFG.LOOP_SEGMENTS do
				pts[k + 1], tans[k + 1], ups[k + 1] = loopPoint(k / FCFG.LOOP_SEGMENTS * 2 * math.pi)
			end
		else -- straight
			pts = { Vector3.new(0, 0, -h), Vector3.new(0, 0, h) }
			tans = { Vector3.new(0, 0, 1), Vector3.new(0, 0, 1) }
			ups = { Y_UP, Y_UP }
		end
		local n = #pts
		cached = {
			pts = pts, tans = tans, ups = ups,
			sDir = tans[1], sUp = ups[1], eDir = tans[n], eUp = ups[n],
		}
		if kind == "ramp" then
			cached.sDir, cached.sUp = Vector3.new(0, 0, 1), Y_UP
			cached.eDir, cached.eUp = Vector3.new(0, 0, 1), Y_UP
		end
		dataCache[kind] = cached
		return cached
	end

	-- системы координат начала (s) и конца (e) рельсы — по ним рельса стыкуется с другой
	function Geo.localFrames(kind)
		local cached = frameCache[kind]
		if cached then
			return cached
		end
		local d = Geo.localData(kind)
		local n = #d.pts
		cached = {
			s = Geo.frameCF(d.pts[1], d.sDir, d.sUp),
			e = Geo.frameCF(d.pts[n], d.eDir, d.eUp),
		}
		frameCache[kind] = cached
		return cached
	end

	-- положение рельсы: yaw — вокруг вертикали, pitch и roll — «сырые» углы Эйлера (порядок Y, X, Z)
	function Geo.pieceCF(x, y, z, yaw, pitch, roll)
		return CFrame.new(x, y, z) * CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw), math.rad(roll))
	end

	-- повороты, которые задаёт игрок: yaw — вокруг вертикали, pitchUp — наклон носом вверх, roll — крен
	function Geo.oriCF(yaw, pitchUp, roll)
		return CFrame.fromEulerAnglesYXZ(math.rad(-pitchUp), math.rad(yaw), math.rad(roll))
	end

	-- обратно: из CFrame в x, y, z, yaw, pitch, roll (то, что хранится в атрибутах и в сохранении)
	function Geo.decompose(cf)
		local rx, ry, rz = cf:ToEulerAnglesYXZ()
		return cf.X, cf.Y, cf.Z, math.deg(ry), math.deg(rx), math.deg(rz)
	end
end

-- ===== Модели =====
local function newPart(parent, name, size, offset, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = collide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- kind: "straight" (прямая), "curve" (поворот на 90°), "ramp" (уклон: нижний конец -Z, верхний +Z),
--       "sign" (деревянная табличка: лицевая сторона смотрит в -Z, текст есть и сзади),
--       "loop" (мёртвая петля: вход в нуле, едем вдоль +Z, выезд сдвинут вбок на LOOP_SHIFT)
local function newRailModel(kind, name)
	local model = Instance.new("Model")
	model.Name = name or "Rail"

	local wood = Color3.fromRGB(105, 72, 45)
	local steel = Color3.fromRGB(190, 195, 205)
	local gravel = Color3.fromRGB(88, 88, 94)

	if kind == "ramp" then
		-- начало координат модели = центр нижнего конца уклона
		local tilt = CFrame.new(0, RISE / 2, 0) * CFrame.Angles(-RAMP_ANGLE, 0, 0)

		local origin = newPart(model, "Origin", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), wood, Enum.Material.Wood, false)
		origin.Transparency = 1
		origin.CanQuery = false
		model.PrimaryPart = origin

		newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, RAMP_LEN), tilt, gravel, Enum.Material.Pebble, true)

		-- насыпь под уклоном (ступеньками, спрятана под плитой)
		for k = 0, 3 do
			local zk = -1.5 + k
			local top = (zk + 0.5 + 2) * RISE / 4 - 0.22
			local h = top + BASE_HEIGHT / 2
			if h > 0.05 then
				newPart(model, "Fill", Vector3.new(3.9, h, 0.98), CFrame.new(0, -BASE_HEIGHT / 2 + h / 2, zk),
					gravel, Enum.Material.Pebble, true)
			end
		end
		for k = -1.5, 1.5, 1 do
			newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), tilt * CFrame.new(0, 0.3, k * (RAMP_LEN / GRID)),
				wood, Enum.Material.Wood, false)
		end
		for _, x in ipairs({ -1.1, 1.1 }) do
			newPart(model, "Steel", Vector3.new(0.25, 0.3, RAMP_LEN), tilt * CFrame.new(x, 0.55, 0),
				steel, Enum.Material.Metal, false)
		end
		return model
	end

	if kind == "sign" then
		local planks = Color3.fromRGB(196, 150, 94)
		local base = newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, 4), CFrame.new(0, 0, 0), gravel, Enum.Material.Pebble, true)
		model.PrimaryPart = base
		local top = BASE_HEIGHT / 2

		-- два столба и перекладина сверху
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Post", Vector3.new(0.4, 3.4, 0.4), CFrame.new(sx * 1.75, top + 1.7, 0),
				wood, Enum.Material.Wood, true)
		end
		newPart(model, "TopBeam", Vector3.new(3.9, 0.25, 0.6), CFrame.new(0, top + 3.525, 0),
			wood, Enum.Material.Wood, false)

		-- доска с текстом (спереди и сзади)
		local board = newPart(model, "Board", Vector3.new(3.2, 1.6, 0.3), CFrame.new(0, top + 2.3, 0),
			planks, Enum.Material.WoodPlanks, true)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = make("SurfaceGui", {
				Face = face,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 100,
			}, board)
			local tl = make("TextLabel", {
				Name = "SignText",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.new(1, -24, 1, -20),
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(52, 30, 14),
				TextScaled = true,
				TextWrapped = true,
				Text = "",
			}, sg)
			make("UITextSizeConstraint", { MaxTextSize = 64, MinTextSize = 8 }, tl)
		end
		return model
	end

	if kind == "loop" then
		-- кольцо из коротких кусочков пути: плита, два рельса и шпалы; крыша вагонетки смотрит в центр круга
		local origin = newPart(model, "Origin", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), wood, Enum.Material.Wood, false)
		origin.Transparency = 1
		origin.CanQuery = false
		model.PrimaryPart = origin

		local d = Geo.localData("loop")
		for i = 1, #d.pts - 1 do
			local a, b = d.pts[i], d.pts[i + 1]
			local dir = b - a
			local len = dir.Magnitude
			local mid = (a + b) / 2
			local seg = CFrame.lookAt(mid, mid + dir, d.ups[i] + d.ups[i + 1])
			newPart(model, "Base", Vector3.new(3.6, BASE_HEIGHT, len + 0.12), seg, gravel, Enum.Material.Pebble, true)
			for _, x in ipairs({ -1.1, 1.1 }) do
				newPart(model, "Steel", Vector3.new(0.25, 0.3, len + 0.1), seg * CFrame.new(x, 0.55, 0),
					steel, Enum.Material.Metal, false)
			end
			if i % 2 == 1 then
				newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), seg * CFrame.new(0, 0.3, 0),
					wood, Enum.Material.Wood, false)
			end
		end
		return model
	end

	local base = newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, 4), CFrame.new(0, 0, 0), gravel, Enum.Material.Pebble, true)
	model.PrimaryPart = base

	if kind == "curve" then
		-- дуга вокруг угла клетки (2, -2): соединяет сторону -Z и сторону +X
		local center = Vector3.new(2, 0, -2)
		local function arcPoint(phi, r)
			return center + Vector3.new(-math.cos(phi), 0, math.sin(phi)) * r
		end
		local n = 4
		for k = 0, n - 1 do
			local phi = (k + 0.5) / n * math.pi / 2
			local pos = arcPoint(phi, 2) + Vector3.new(0, 0.3, 0)
			local tan = Vector3.new(math.sin(phi), 0, math.cos(phi))
			newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), CFrame.lookAt(pos, pos + tan), wood, Enum.Material.Wood, false)
		end
		local segs = 6
		for _, r in ipairs({ 0.9, 3.1 }) do
			for k = 0, segs - 1 do
				local a = arcPoint(k / segs * math.pi / 2, r)
				local b = arcPoint((k + 1) / segs * math.pi / 2, r)
				local mid = (a + b) / 2 + Vector3.new(0, 0.55, 0)
				newPart(model, "Steel", Vector3.new(0.25, 0.3, (b - a).Magnitude + 0.05), CFrame.lookAt(mid, mid + (b - a)),
					steel, Enum.Material.Metal, false)
			end
		end
	else
		for z = -1.5, 1.5, 1 do
			newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), CFrame.new(0, 0.3, z), wood, Enum.Material.Wood, false)
		end
		for _, x in ipairs({ -1.1, 1.1 }) do
			newPart(model, "Steel", Vector3.new(0.25, 0.3, 4), CFrame.new(x, 0.55, 0), steel, Enum.Material.Metal, false)
		end
	end
	return model
end

local function newCartModel()
	local model = Instance.new("Model")
	model.Name = "MineCart"
	local wood = Color3.fromRGB(139, 94, 52)
	local metal = Color3.fromRGB(64, 68, 82)

	local function p(name, size, cf, color, material, shape)
		local part = newPart(model, name, size, cf, color, material, false)
		part.CanQuery = false
		if shape then
			part.Shape = shape
		end
		return part
	end

	local pivot = p("Pivot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), wood, Enum.Material.Wood)
	pivot.Transparency = 1
	model.PrimaryPart = pivot -- точка (0,0,0) = верх рельсы

	p("Floor", Vector3.new(2.8, 0.25, 3.6), CFrame.new(0, 1.0, 0), wood, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		p("WallSide", Vector3.new(0.25, 1.0, 3.6), CFrame.new(sx * 1.275, 1.625, 0), wood, Enum.Material.Wood)
		p("RimSide", Vector3.new(0.4, 0.12, 3.7), CFrame.new(sx * 1.275, 2.185, 0), metal, Enum.Material.Metal)
	end
	for _, sz in ipairs({ -1, 1 }) do
		p("WallEnd", Vector3.new(2.3, 1.0, 0.25), CFrame.new(0, 1.625, sz * 1.675), wood, Enum.Material.Wood)
		p("RimEnd", Vector3.new(2.8, 0.12, 0.4), CFrame.new(0, 2.185, sz * 1.675), metal, Enum.Material.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			p("Wheel", Vector3.new(0.3, 0.9, 0.9), CFrame.new(sx * 1.1, 0.45, sz * 1.05), metal,
				Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	-- фонарь спереди (перед = -Z)
	local lamp = p("Lamp", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 2.45, -1.675),
		Color3.fromRGB(255, 205, 110), Enum.Material.Neon)
	make("PointLight", { Color = Color3.fromRGB(255, 200, 120), Range = 16, Brightness = 1.5 }, lamp)
	return model
end

-- ===== Украшения =====
-- Модели по ID (таблица MODELS) из LocalScript не подгрузить — InsertService работает только на сервере.
-- Поэтому каждое украшение собрано из деталей. Начало координат — центр основания (земля),
-- «лицо» смотрит в -Z. Внутри модели нет вложенных Model — иначе «Стереть» не сможет её найти.
do
	local PLASTIC, FABRIC = Enum.Material.SmoothPlastic, Enum.Material.Fabric
	local WOOD, NEON = Enum.Material.Wood, Enum.Material.Neon
	local SLATE, METAL, GRASS = Enum.Material.Slate, Enum.Material.Metal, Enum.Material.Grass
	local B = Decor.builders

	-- эллипсоид (шар, растянутый до нужного размера)
	local function ball(parent, name, size, cf, color, material, collide)
		local p = newPart(parent, name, size, cf, color, material, collide == true)
		make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
		return p
	end

	-- вертикальный цилиндр (у Part-цилиндра ось — X, поэтому поворачиваем на 90° вокруг Z)
	local function pillar(parent, name, height, diam, cf, color, material, collide)
		local p = newPart(parent, name, Vector3.new(height, diam, diam), cf * CFrame.Angles(0, 0, math.rad(90)),
			color, material, collide == true)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- 🎃 Тыква: шесть долек, светящееся лицо, хвостик
	B.pumpkin = function(m)
		local orange, orange2 = Color3.fromRGB(240, 118, 22), Color3.fromRGB(224, 100, 14)
		for k = 0, 5 do
			ball(m, "Lobe", Vector3.new(1.3, 2.3, 2.8), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.rad(k * 30 + 15), 0),
				(k % 2 == 0) and orange or orange2, PLASTIC, true)
		end
		newPart(m, "Stem", Vector3.new(0.45, 0.8, 0.45), CFrame.new(0.05, 2.5, 0) * CFrame.Angles(0, 0, math.rad(-12)),
			Color3.fromRGB(86, 116, 44), WOOD, false)
		local glow = Color3.fromRGB(255, 196, 60)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(m, "Eye", Vector3.new(0.42, 0.42, 0.3), CFrame.new(sx * 0.55, 1.5, -1.2) * CFrame.Angles(0, 0, math.rad(45)),
				glow, NEON, false)
		end
		local mid
		for i = -2, 2 do
			local part = newPart(m, "Mouth", Vector3.new(0.3, 0.26, 0.3),
				CFrame.new(i * 0.3, 0.78 + 0.07 * i * i, -1.2 + 0.03 * i * i), glow, NEON, false)
			if i == 0 then
				mid = part
			end
		end
		make("PointLight", { Color = Color3.fromRGB(255, 170, 60), Range = 8, Brightness = 0.9 }, mid)
	end

	-- 🎃 Сено: тюк с верёвками и торчащими соломинками
	B.hay = function(m)
		local straw, light = Color3.fromRGB(224, 186, 86), Color3.fromRGB(240, 212, 120)
		local strap = Color3.fromRGB(96, 66, 38)
		newPart(m, "Bale", Vector3.new(3.4, 2.1, 2.2), CFrame.new(0, 1.05, 0), straw, FABRIC, true)
		newPart(m, "Top", Vector3.new(3.3, 0.12, 2.1), CFrame.new(0, 2.1, 0), light, FABRIC, false)
		for _, sx in ipairs({ -0.95, 0.95 }) do
			newPart(m, "Strap", Vector3.new(0.14, 2.16, 2.26), CFrame.new(sx, 1.05, 0), strap, FABRIC, false)
		end
		local rng = Random.new(11) -- всегда одни и те же соломинки
		for i = 1, 18 do
			local cf = CFrame.new(rng:NextNumber(-1.6, 1.6), 2.14, rng:NextNumber(-1, 1))
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.6, 0.6))
			newPart(m, "Straw", Vector3.new(0.07, 0.07, rng:NextNumber(0.6, 1.1)), cf,
				(i % 2 == 0) and straw or light, FABRIC, false)
		end
		for i = 1, 8 do
			local sx = (i % 2 == 0) and 1 or -1
			local cf = CFrame.new(sx * 1.72, rng:NextNumber(0.3, 1.8), rng:NextNumber(-0.9, 0.9))
				* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.4, 0.4))
			newPart(m, "Straw", Vector3.new(0.7, 0.07, 0.07), cf, (i % 2 == 0) and light or straw, FABRIC, false)
		end
	end

	-- 🎄 Ёлка: три яруса ступенчатой «хвои», шарики и звезда
	B.tree = function(m)
		local trunk = Color3.fromRGB(104, 70, 42)
		local leaf, leaf2 = Color3.fromRGB(34, 122, 60), Color3.fromRGB(46, 148, 74)
		pillar(m, "Trunk", 1.0, 0.9, CFrame.new(0, 0.5, 0), trunk, WOOD, true)
		local tiers = { { 4.2, 0.9 }, { 3.2, 2.1 }, { 2.2, 3.3 } } -- { ширина нижнего диска, высота яруса }
		for t, tier in ipairs(tiers) do
			for j = 0, 2 do
				pillar(m, "Needles", 0.5, tier[1] * (1 - 0.28 * j), CFrame.new(0, tier[2] + 0.25 + j * 0.4, 0),
					((t + j) % 2 == 0) and leaf or leaf2, FABRIC, j == 0)
			end
		end
		pillar(m, "Tip", 0.5, 0.5, CFrame.new(0, 4.85, 0), leaf, FABRIC, false)
		local gold = Color3.fromRGB(255, 214, 70)
		for k = 0, 1 do
			newPart(m, "Star", Vector3.new(0.75, 0.75, 0.25), CFrame.new(0, 5.35, 0) * CFrame.Angles(0, 0, math.rad(k * 45)),
				gold, NEON, false)
		end
		local colors = {
			Color3.fromRGB(255, 70, 80), Color3.fromRGB(90, 160, 255),
			Color3.fromRGB(255, 214, 70), Color3.fromRGB(255, 130, 220),
		}
		local n = 0
		for t, tier in ipairs(tiers) do
			for k = 0, 3 do
				n += 1
				local a = math.rad(t * 37 + k * 90)
				local r = tier[1] / 2 - 0.05
				ball(m, "Ornament", Vector3.new(0.38, 0.38, 0.38),
					CFrame.new(math.cos(a) * r, tier[2] + 0.18, math.sin(a) * r), colors[n % #colors + 1], NEON, false)
			end
		end
	end

	-- 🎄 Подарок: коробка с крышкой, лентой и бантом
	B.gift = function(m)
		local box, ribbon = Color3.fromRGB(214, 48, 60), Color3.fromRGB(250, 220, 90)
		newPart(m, "Box", Vector3.new(2.4, 1.9, 2.4), CFrame.new(0, 0.95, 0), box, PLASTIC, true)
		newPart(m, "Lid", Vector3.new(2.6, 0.45, 2.6), CFrame.new(0, 1.9, 0), box, PLASTIC, true)
		newPart(m, "RibbonX", Vector3.new(2.46, 1.7, 0.45), CFrame.new(0, 0.95, 0), ribbon, PLASTIC, false)
		newPart(m, "RibbonZ", Vector3.new(0.45, 1.7, 2.46), CFrame.new(0, 0.95, 0), ribbon, PLASTIC, false)
		newPart(m, "LidRibbonX", Vector3.new(2.66, 0.5, 0.45), CFrame.new(0, 1.9, 0), ribbon, PLASTIC, false)
		newPart(m, "LidRibbonZ", Vector3.new(0.45, 0.5, 2.66), CFrame.new(0, 1.9, 0), ribbon, PLASTIC, false)
		for _, s in ipairs({ -1, 1 }) do
			ball(m, "Bow", Vector3.new(0.95, 0.55, 0.5), CFrame.new(s * 0.45, 2.38, 0) * CFrame.Angles(0, 0, math.rad(s * -25)),
				ribbon, PLASTIC, false)
		end
		ball(m, "Knot", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.32, 0), ribbon, PLASTIC, false)
	end

	-- 🎃 Надгробие: плита с круглым верхом, крестом и холмиком земли
	B.tombstone = function(m)
		local stone, dark = Color3.fromRGB(122, 126, 134), Color3.fromRGB(58, 60, 68)
		newPart(m, "Slab", Vector3.new(2.6, 0.35, 1.6), CFrame.new(0, 0.175, 0), Color3.fromRGB(96, 100, 108), SLATE, true)
		newPart(m, "Stone", Vector3.new(1.7, 1.7, 0.45), CFrame.new(0, 1.2, 0), stone, SLATE, true)
		local top = newPart(m, "StoneTop", Vector3.new(0.45, 1.7, 1.7), CFrame.new(0, 2.05, 0) * CFrame.Angles(0, math.rad(90), 0),
			stone, SLATE, true)
		top.Shape = Enum.PartType.Cylinder -- круглый верх плиты
		newPart(m, "CrossV", Vector3.new(0.2, 1.1, 0.1), CFrame.new(0, 1.75, -0.24), dark, SLATE, false)
		newPart(m, "CrossH", Vector3.new(0.75, 0.2, 0.1), CFrame.new(0, 2.05, -0.24), dark, SLATE, false)
		ball(m, "Mound", Vector3.new(2.2, 0.6, 1.5), CFrame.new(0, 0.1, -1.2), Color3.fromRGB(82, 60, 40), Enum.Material.Ground, false)
	end

	-- 🎃 Котёл: чёрный горшок с кипящим зелёным зельем (светится)
	B.cauldron = function(m)
		local iron, green = Color3.fromRGB(40, 42, 48), Color3.fromRGB(120, 255, 90)
		ball(m, "Pot", Vector3.new(3.0, 2.0, 3.0), CFrame.new(0, 0.95, 0), iron, METAL, true)
		pillar(m, "Rim", 0.3, 2.5, CFrame.new(0, 1.85, 0), iron, METAL, true)
		local brew = pillar(m, "Brew", 0.1, 2.0, CFrame.new(0, 2.03, 0), green, NEON, false)
		make("PointLight", { Color = green, Range = 10, Brightness = 1 }, brew)
		for _, p in ipairs({ { 0.5, 0.3 }, { -0.6, -0.2 }, { 0.1, -0.7 } }) do
			ball(m, "Bubble", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p[1], 2.1, p[2]), green, NEON, false)
		end
		for _, sx in ipairs({ -1, 1 }) do
			ball(m, "Handle", Vector3.new(0.45, 0.45, 0.45), CFrame.new(sx * 1.35, 1.5, 0), iron, METAL, false)
		end
	end

	-- 🎄 Снеговик: три шара, шляпа, морковка, шарф и руки-палки
	B.snowman = function(m)
		local snow, coal, red = Color3.fromRGB(246, 250, 255), Color3.fromRGB(28, 28, 34), Color3.fromRGB(200, 40, 48)
		ball(m, "Bottom", Vector3.new(2.1, 1.9, 2.1), CFrame.new(0, 0.95, 0), snow, PLASTIC, true)
		ball(m, "Middle", Vector3.new(1.55, 1.45, 1.55), CFrame.new(0, 2.5, 0), snow, PLASTIC, true)
		ball(m, "Head", Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, 3.55, 0), snow, PLASTIC, false)
		ball(m, "Nose", Vector3.new(0.18, 0.18, 0.6), CFrame.new(0, 3.5, -0.72), Color3.fromRGB(255, 140, 30), PLASTIC, false)
		for _, sx in ipairs({ -1, 1 }) do
			ball(m, "Eye", Vector3.new(0.14, 0.14, 0.1), CFrame.new(sx * 0.21, 3.68, -0.51), coal, PLASTIC, false)
			newPart(m, "Arm", Vector3.new(1.4, 0.09, 0.09), CFrame.new(sx * 1.25, 2.85, 0) * CFrame.Angles(0, 0, math.rad(sx * 25)),
				Color3.fromRGB(96, 66, 40), WOOD, false)
		end
		for i = -2, 2 do -- улыбка из угольков
			ball(m, "Mouth", Vector3.new(0.09, 0.09, 0.08), CFrame.new(i * 0.1, 3.3 + 0.025 * i * i, -0.51), coal, PLASTIC, false)
		end
		for _, b in ipairs({ { 2.85, -0.68 }, { 2.5, -0.75 }, { 2.15, -0.68 } }) do
			ball(m, "Button", Vector3.new(0.18, 0.18, 0.14), CFrame.new(0, b[1], b[2]), coal, PLASTIC, false)
		end
		pillar(m, "HatBrim", 0.1, 1.5, CFrame.new(0, 4.08, 0), coal, PLASTIC, false)
		pillar(m, "Hat", 0.75, 0.9, CFrame.new(0, 4.5, 0), coal, PLASTIC, false)
		pillar(m, "HatBand", 0.16, 0.93, CFrame.new(0, 4.2, 0), red, FABRIC, false)
		pillar(m, "Scarf", 0.3, 1.2, CFrame.new(0, 3.0, 0), red, FABRIC, false)
		newPart(m, "ScarfEnd", Vector3.new(0.3, 0.8, 0.1), CFrame.new(0.4, 2.6, -0.7) * CFrame.Angles(0, 0, math.rad(-8)),
			red, FABRIC, false)
	end

	-- 🌿 Куст: несколько зелёных «облачков» и красные ягоды
	B.bush = function(m)
		local greens = { Color3.fromRGB(52, 120, 46), Color3.fromRGB(64, 140, 52), Color3.fromRGB(44, 104, 42) }
		local blobs = { -- { x, y, z, ширина, высота, глубина }
			{ 0, 0.9, 0, 2.7, 1.9, 2.5 }, { -1.0, 0.7, 0.2, 1.9, 1.5, 1.9 }, { 1.0, 0.7, -0.1, 2.0, 1.6, 1.9 },
			{ 0.2, 1.3, 0.3, 1.9, 1.5, 1.7 }, { -0.4, 0.6, -0.8, 1.6, 1.2, 1.4 },
		}
		for i, b in ipairs(blobs) do
			ball(m, "Leaves", Vector3.new(b[4], b[5], b[6]), CFrame.new(b[1], b[2], b[3]), greens[i % 3 + 1], GRASS, i == 1)
		end
		local rng = Random.new(5)
		for _ = 1, 10 do
			local x, z = rng:NextNumber(-1.2, 1.2), rng:NextNumber(-1, 1)
			local k = 1 - (x / 1.35) ^ 2 - (z / 1.25) ^ 2
			if k > 0.2 then
				ball(m, "Berry", Vector3.new(0.22, 0.22, 0.22), CFrame.new(x, 0.95 + 0.95 * math.sqrt(k), z),
					Color3.fromRGB(210, 40, 50), PLASTIC, false)
			end
		end
	end

	-- 🌿 Гриб: большой мухомор и два маленьких рядом
	B.mushroom = function(m)
		local cream, red, spot = Color3.fromRGB(240, 228, 205), Color3.fromRGB(205, 45, 52), Color3.fromRGB(255, 250, 245)
		local function shroom(x, z, h, w) -- ножка, шляпка и белые пятнышки
			pillar(m, "Stem", h, w * 0.3, CFrame.new(x, h / 2, z), cream, PLASTIC, true)
			local capH = w * 0.55
			local cy = h + capH * 0.2
			ball(m, "Cap", Vector3.new(w, capH, w), CFrame.new(x, cy, z), red, PLASTIC, false)
			for _, s in ipairs({ { 0.25, 0.1 }, { -0.2, 0.3 }, { 0.05, -0.32 }, { -0.3, -0.12 } }) do
				local px, pz = s[1] * w, s[2] * w
				local k = 1 - (px / (w / 2)) ^ 2 - (pz / (w / 2)) ^ 2
				ball(m, "Spot", Vector3.new(w * 0.17, w * 0.07, w * 0.17),
					CFrame.new(x + px, cy + capH / 2 * math.sqrt(k), z + pz), spot, PLASTIC, false)
			end
		end
		shroom(0, 0, 1.3, 2.6)
		shroom(1.7, 0.6, 0.7, 1.4)
		shroom(-1.5, 0.9, 0.5, 1.0)
	end

	-- 🌿 Камень: три валуна разного размера
	B.rock = function(m)
		local g1, g2, g3 = Color3.fromRGB(118, 120, 128), Color3.fromRGB(104, 106, 114), Color3.fromRGB(132, 134, 140)
		ball(m, "Rock", Vector3.new(3.0, 1.9, 2.4), CFrame.new(0, 0.8, 0) * CFrame.Angles(0.05, math.rad(20), 0.08), g1, SLATE, true)
		ball(m, "Rock", Vector3.new(1.9, 1.2, 1.6), CFrame.new(1.5, 0.45, 0.7) * CFrame.Angles(0, math.rad(-30), -0.1), g2, SLATE, true)
		ball(m, "Rock", Vector3.new(1.5, 1.0, 1.4), CFrame.new(-1.4, 0.35, -0.6) * CFrame.Angles(0.1, math.rad(50), 0), g3, SLATE, true)
	end

	-- 🌿 Цветы: полянка с пятью разноцветными цветами
	B.flowers = function(m)
		ball(m, "Patch", Vector3.new(3.2, 0.3, 2.8), CFrame.new(0, 0.05, 0), Color3.fromRGB(70, 130, 56), GRASS, false)
		local stem = Color3.fromRGB(60, 130, 52)
		local petals = {
			Color3.fromRGB(240, 70, 90), Color3.fromRGB(255, 160, 200), Color3.fromRGB(170, 110, 240),
			Color3.fromRGB(250, 250, 255), Color3.fromRGB(255, 190, 60),
		}
		local spots = { { -0.9, 0.3, 1.2 }, { 0.2, -0.6, 1.5 }, { 0.9, 0.4, 1.0 }, { -0.2, 0.8, 1.3 }, { 0.5, -0.05, 1.7 } }
		for i, f in ipairs(spots) do
			local x, z, h = f[1], f[2], f[3]
			pillar(m, "Stem", h, 0.1, CFrame.new(x, h / 2, z), stem, PLASTIC, false)
			ball(m, "Leaf", Vector3.new(0.45, 0.08, 0.2), CFrame.new(x + 0.2, h * 0.4, z) * CFrame.Angles(0, 0, math.rad(25)),
				stem, PLASTIC, false)
			for k = 0, 4 do
				local a = math.rad(k * 72)
				ball(m, "Petal", Vector3.new(0.34, 0.1, 0.34), CFrame.new(x + math.cos(a) * 0.24, h, z + math.sin(a) * 0.24),
					petals[i], PLASTIC, false)
			end
			ball(m, "Center", Vector3.new(0.26, 0.16, 0.26), CFrame.new(x, h + 0.04, z), Color3.fromRGB(255, 210, 60), PLASTIC, false)
		end
	end

	-- 🌿 Костёр: круг камней, шалашик из брёвен, огонь и тёплый свет
	B.campfire = function(m)
		local logC, stone = Color3.fromRGB(96, 64, 38), Color3.fromRGB(120, 122, 130)
		for k = 0, 7 do
			local a = math.rad(k * 45)
			ball(m, "Stone", Vector3.new(0.75, 0.5, 0.75), CFrame.new(math.cos(a) * 1.7, 0.2, math.sin(a) * 1.7), stone, SLATE, k % 2 == 0)
		end
		for k = 0, 5 do
			local a = math.rad(k * 60)
			local mid = Vector3.new(math.cos(a) * 0.65, 0.7, math.sin(a) * 0.65)
			newPart(m, "Log", Vector3.new(0.4, 0.4, 2.0), CFrame.lookAt(mid, Vector3.new(0, 1.85, 0)), logC, WOOD, false)
		end
		ball(m, "Flame", Vector3.new(1.0, 1.4, 1.0), CFrame.new(0, 1.0, 0), Color3.fromRGB(255, 140, 30), NEON, false)
		local core = ball(m, "Flame", Vector3.new(0.65, 1.1, 0.65), CFrame.new(0, 1.05, 0), Color3.fromRGB(255, 205, 70), NEON, false)
		ball(m, "Flame", Vector3.new(0.3, 0.7, 0.3), CFrame.new(0, 1.0, 0), Color3.fromRGB(255, 240, 160), NEON, false)
		make("PointLight", { Color = Color3.fromRGB(255, 160, 70), Range = 20, Brightness = 1.6 }, core)
		make("Fire", { Size = 4, Heat = 6 }, core)
	end

	-- 🧱 Забор: пять досок с остриями и две перекладины (по ширине одной клетки)
	B.fence = function(m)
		local paint, rail = Color3.fromRGB(238, 230, 210), Color3.fromRGB(150, 110, 70)
		for _, y in ipairs({ 0.65, 1.45 }) do
			newPart(m, "Rail", Vector3.new(4.0, 0.25, 0.14), CFrame.new(0, y, 0.16), rail, WOOD, false)
		end
		for i = -2, 2 do
			local x = i * 0.8
			newPart(m, "Picket", Vector3.new(0.4, 2.0, 0.18), CFrame.new(x, 1.0, 0), paint, WOOD, i % 2 == 0)
			newPart(m, "PicketTip", Vector3.new(0.28, 0.28, 0.18), CFrame.new(x, 2.05, 0) * CFrame.Angles(0, 0, math.rad(45)),
				paint, WOOD, false)
		end
	end

	-- 🧱 Бочка: доски, три железных обруча и крышка
	B.barrel = function(m)
		local wood, hoop = Color3.fromRGB(140, 96, 56), Color3.fromRGB(58, 60, 68)
		pillar(m, "Barrel", 2.2, 1.8, CFrame.new(0, 1.1, 0), wood, WOOD, true)
		for _, y in ipairs({ 0.3, 1.1, 1.9 }) do
			pillar(m, "Hoop", 0.14, 1.88, CFrame.new(0, y, 0), hoop, METAL, false)
		end
		pillar(m, "Lid", 0.1, 1.5, CFrame.new(0, 2.2, 0), Color3.fromRGB(170, 124, 76), WOOD, false)
	end

	-- 🧱 Ящик: деревянный куб с рамой и диагональными планками
	B.crate = function(m)
		local plank, frame = Color3.fromRGB(176, 130, 80), Color3.fromRGB(120, 82, 48)
		newPart(m, "Box", Vector3.new(2.0, 2.0, 2.0), CFrame.new(0, 1.0, 0), plank, Enum.Material.WoodPlanks, true)
		for _, s in ipairs({ -1, 1 }) do
			for _, t in ipairs({ -1, 1 }) do
				newPart(m, "Post", Vector3.new(0.22, 2.06, 0.22), CFrame.new(s * 0.95, 1.0, t * 0.95), frame, WOOD, false)
			end
			for _, y in ipairs({ 0.1, 1.9 }) do
				newPart(m, "BarX", Vector3.new(2.06, 0.2, 0.2), CFrame.new(0, y, s * 0.95), frame, WOOD, false)
				newPart(m, "BarZ", Vector3.new(0.2, 0.2, 2.06), CFrame.new(s * 0.95, y, 0), frame, WOOD, false)
			end
			newPart(m, "BraceF", Vector3.new(0.2, 2.2, 0.08), CFrame.new(0, 1.0, s * 1.02) * CFrame.Angles(0, 0, math.rad(45)),
				frame, WOOD, false)
			newPart(m, "BraceS", Vector3.new(0.08, 2.2, 0.2), CFrame.new(s * 1.02, 1.0, 0) * CFrame.Angles(math.rad(45), 0, 0),
				frame, WOOD, false)
		end
	end

	-- 🧱 Фонарь: чугунный столб с тёплой лампой (по-настоящему светит)
	B.lamp = function(m)
		local iron, glow = Color3.fromRGB(44, 46, 54), Color3.fromRGB(255, 222, 150)
		pillar(m, "Base", 0.5, 0.95, CFrame.new(0, 0.25, 0), iron, METAL, true)
		pillar(m, "Post", 3.6, 0.3, CFrame.new(0, 2.0, 0), iron, METAL, true)
		pillar(m, "Plate", 0.15, 0.95, CFrame.new(0, 3.85, 0), iron, METAL, false)
		local bulb = ball(m, "Bulb", Vector3.new(0.9, 1.1, 0.9), CFrame.new(0, 4.4, 0), glow, NEON, false)
		pillar(m, "Cap", 0.2, 1.1, CFrame.new(0, 5.05, 0), iron, METAL, false)
		pillar(m, "CapTop", 0.2, 0.5, CFrame.new(0, 5.25, 0), iron, METAL, false)
		make("PointLight", { Color = Color3.fromRGB(255, 214, 140), Range = 26, Brightness = 1.8 }, bulb)
	end

	-- 🏠 Дверь в стене: стена 8 × 9 с проёмом 3.8 × 6.8 (пролезет любой персонаж), рама и створка.
	-- Створку помечаем "Leaf" — она открывается (см. Home). Снаружи (там, где коврик) — «лицо» двери; створка открывается внутрь.
	B.door = function(m)
		local wall, frame = Color3.fromRGB(226, 214, 190), Color3.fromRGB(104, 70, 42)
		local wood, dark, gold = Color3.fromRGB(150, 104, 60), Color3.fromRGB(112, 76, 44), Color3.fromRGB(240, 200, 80)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(m, "WallSide", Vector3.new(1.85, 7.05, 0.6), CFrame.new(sx * 3.075, 3.525, 0), wall, PLASTIC, true)
			newPart(m, "Jamb", Vector3.new(0.25, 7.05, 0.76), CFrame.new(sx * 2.025, 3.525, 0), frame, WOOD, true)
			newPart(m, "Skirting", Vector3.new(1.88, 0.8, 0.7), CFrame.new(sx * 3.075, 0.4, 0), frame, WOOD, false)
		end
		newPart(m, "WallTop", Vector3.new(8, 1.95, 0.6), CFrame.new(0, 8.025, 0), wall, PLASTIC, true)
		newPart(m, "Lintel", Vector3.new(4.3, 0.25, 0.76), CFrame.new(0, 6.925, 0), frame, WOOD, true)
		newPart(m, "Cornice", Vector3.new(8.06, 0.5, 0.8), CFrame.new(0, 8.75, 0), frame, WOOD, false)
		newPart(m, "Sill", Vector3.new(3.9, 0.1, 0.9), CFrame.new(0, 0.05, 0), dark, WOOD, false)
		-- коврик снаружи
		newPart(m, "Mat", Vector3.new(3.4, 0.08, 1.6), CFrame.new(0, 0.04, -1.4), Color3.fromRGB(150, 50, 56), FABRIC, false)

		-- створка: петли слева (x = -1.9); всё, что помечено "Leaf", поворачивается вместе с ней
		local function leaf(part)
			part:SetAttribute("Leaf", true)
			return part
		end
		leaf(newPart(m, "Leaf", Vector3.new(3.8, 6.7, 0.25), CFrame.new(0, 3.45, 0), wood, Enum.Material.WoodPlanks, true))
		for _, sz in ipairs({ -1, 1 }) do
			leaf(newPart(m, "Panel", Vector3.new(2.8, 2.4, 0.08), CFrame.new(0, 5.0, sz * 0.14), dark, WOOD, false))
			leaf(newPart(m, "Panel", Vector3.new(2.8, 2.4, 0.08), CFrame.new(0, 1.9, sz * 0.14), dark, WOOD, false))
			leaf(ball(m, "Knob", Vector3.new(0.34, 0.34, 0.34), CFrame.new(1.4, 3.3, sz * 0.3), gold, METAL, false))
		end
	end

	-- 🏠 Стена: такой же кусок стены 8 × 9, как у двери, но без проёма (чтобы построить дом)
	B.wall = function(m)
		local wall, trim = Color3.fromRGB(226, 214, 190), Color3.fromRGB(104, 70, 42)
		newPart(m, "Wall", Vector3.new(8, 9, 0.6), CFrame.new(0, 4.5, 0), wall, PLASTIC, true)
		newPart(m, "Skirting", Vector3.new(8.06, 0.8, 0.7), CFrame.new(0, 0.4, 0), trim, WOOD, false)
		newPart(m, "Cornice", Vector3.new(8.06, 0.5, 0.8), CFrame.new(0, 8.75, 0), trim, WOOD, false)
	end

	-- 🐈 Котость: огромный круглый трёхцветный кот (как на картинке): белое пузо, рыжие и чёрные пятна, чёрная «маска»
	-- с белой полоской на голове, большие круглые глаза (смотрит вверх), прижатые ушки, крошечные лапки
	B.kotost = function(m)
		local white, orange, black = Color3.fromRGB(248, 244, 238), Color3.fromRGB(222, 124, 44), Color3.fromRGB(28, 28, 32)
		-- туловище, пятна, хвост, лапки
		ball(m, "Body", Vector3.new(4.2, 3.7, 3.9), CFrame.new(0, 1.85, 0.2), white, FABRIC, true)
		ball(m, "PatchR", Vector3.new(0.75, 2.3, 2.1), CFrame.new(1.78, 2.1, 0.3), orange, FABRIC, false)
		ball(m, "PatchR2", Vector3.new(0.75, 1.5, 1.4), CFrame.new(1.65, 3.0, -0.9), orange, FABRIC, false)
		ball(m, "PatchL", Vector3.new(0.75, 1.7, 1.6), CFrame.new(-1.78, 2.6, 0.5), orange, FABRIC, false)
		ball(m, "PatchBlack", Vector3.new(0.75, 1.4, 1.6), CFrame.new(-1.8, 1.0, 0.0), black, FABRIC, false)
		ball(m, "PatchBack", Vector3.new(2.0, 1.1, 1.6), CFrame.new(0.3, 3.45, 1.2), orange, FABRIC, false)
		ball(m, "Tail", Vector3.new(0.9, 0.9, 1.5), CFrame.new(1.0, 0.9, 2.4), orange, FABRIC, false)
		-- голова: белая, сверху и вокруг глаз чёрная «маска», между глаз белая полоска
		ball(m, "Head", Vector3.new(3.3, 2.5, 2.7), CFrame.new(0, 3.25, -0.75), white, FABRIC, false)
		ball(m, "Mask", Vector3.new(3.36, 1.55, 2.74), CFrame.new(0, 3.85, -0.75), black, FABRIC, false)
		ball(m, "Blaze", Vector3.new(0.55, 1.4, 0.4), CFrame.new(0, 3.6, -2.0), white, FABRIC, false)
		ball(m, "Nose", Vector3.new(0.3, 0.22, 0.22), CFrame.new(0, 2.9, -1.98), Color3.fromRGB(240, 150, 170), PLASTIC, false)
		for _, sx in ipairs({ -1, 1 }) do
			ball(m, "Paw", Vector3.new(1.0, 0.55, 1.3), CFrame.new(sx * 0.95, 0.28, -1.75), white, FABRIC, false)
			ball(m, "Cheek", Vector3.new(1.1, 1.3, 1.1), CFrame.new(sx * 1.35, 2.7, -1.0), white, FABRIC, false)
			ball(m, "Muzzle", Vector3.new(0.95, 0.75, 0.8), CFrame.new(sx * 0.42, 2.7, -1.65), white, FABRIC, false)
			-- большие круглые глаза: белок, радужка, зрачок (смещён вверх — кот смотрит вверх) и блик
			ball(m, "EyeWhite", Vector3.new(0.8, 0.8, 0.3), CFrame.new(sx * 0.7, 3.75, -1.78), Color3.fromRGB(252, 252, 252), PLASTIC, false)
			ball(m, "Iris", Vector3.new(0.62, 0.62, 0.2), CFrame.new(sx * 0.7, 3.82, -1.9), Color3.fromRGB(62, 42, 32), PLASTIC, false)
			ball(m, "Pupil", Vector3.new(0.34, 0.4, 0.2), CFrame.new(sx * 0.7, 3.88, -1.97), black, PLASTIC, false)
			ball(m, "Shine", Vector3.new(0.13, 0.13, 0.1), CFrame.new(sx * 0.6, 4.0, -2.04), white, PLASTIC, false)
			-- ушки прижаты к голове (чёрные)
			ball(m, "Ear", Vector3.new(0.95, 0.7, 0.6), CFrame.new(sx * 1.25, 4.5, -0.95) * CFrame.Angles(math.rad(-15), 0, math.rad(sx * -28)),
				black, FABRIC, false)
			for _, dy in ipairs({ -0.08, 0.1 }) do
				newPart(m, "Whisker", Vector3.new(0.9, 0.03, 0.03),
					CFrame.new(sx * 1.3, 2.75 + dy, -1.6) * CFrame.Angles(0, math.rad(sx * 18), math.rad(sx * dy * 150)),
					Color3.fromRGB(60, 60, 66), PLASTIC, false)
			end
		end
	end

	-- 💧 Вода: стеклянная бутылка с водой внутри; на этикетке голубая надпись «вода» с чёрной обводкой, ниже «мировая»
	B.water = function(m)
		local GLASS = Enum.Material.Glass
		local glass, water = Color3.fromRGB(205, 232, 245), Color3.fromRGB(80, 180, 255)
		local function soft(part, t) -- прозрачность детали
			part.Transparency = t
			return part
		end
		-- стекло: корпус, плечики и горлышко
		soft(pillar(m, "Bottle", 3.2, 1.9, CFrame.new(0, 1.6, 0), glass, GLASS, true), 0.5)
		soft(ball(m, "Shoulder", Vector3.new(1.9, 1.3, 1.9), CFrame.new(0, 3.2, 0), glass, GLASS, false), 0.5)
		soft(pillar(m, "Neck", 0.9, 0.85, CFrame.new(0, 4.1, 0), glass, GLASS, false), 0.5)
		-- вода внутри
		soft(pillar(m, "Water", 2.9, 1.72, CFrame.new(0, 1.55, 0), water, GLASS, false), 0.25)
		soft(ball(m, "WaterTop", Vector3.new(1.72, 0.9, 1.72), CFrame.new(0, 3.0, 0), water, GLASS, false), 0.25)
		for _, b in ipairs({ { -0.3, 2.2, 0.2 }, { 0.35, 2.6, -0.25 }, { 0.1, 2.9, 0.3 } }) do
			soft(ball(m, "Bubble", Vector3.new(0.16, 0.16, 0.16), CFrame.new(b[1], b[2], b[3]), WHITE, PLASTIC, false), 0.35)
		end
		-- крышка и блик на стекле
		pillar(m, "CapRing", 0.12, 1.1, CFrame.new(0, 4.5, 0), Color3.fromRGB(40, 110, 190), PLASTIC, false)
		pillar(m, "Cap", 0.5, 1.05, CFrame.new(0, 4.8, 0), Color3.fromRGB(50, 140, 230), PLASTIC, false)
		soft(newPart(m, "Glint", Vector3.new(0.1, 2.2, 0.05), CFrame.new(-0.55, 1.8, -0.77) * CFrame.Angles(0, math.rad(35), 0),
			WHITE, PLASTIC, false), 0.55)
		-- этикетка: белая лента вокруг бутылки + надпись спереди и сзади
		soft(pillar(m, "Label", 1.35, 1.99, CFrame.new(0, 1.55, 0), Color3.fromRGB(236, 246, 255), PLASTIC, false), 0.05)
		for _, side in ipairs({ { -1.025, Enum.NormalId.Front }, { 1.025, Enum.NormalId.Back } }) do
			local plate = newPart(m, "LabelPlate", Vector3.new(1.7, 1.2, 0.04), CFrame.new(0, 1.55, side[1]), WHITE, PLASTIC, false)
			plate.Transparency = 1 -- сама деталь невидима, видна только надпись на ней
			local sg = make("SurfaceGui", {
				Face = side[2], SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 100,
			}, plate)
			local function line(text, y, h, size, color, thick)
				local t = make("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h),
					Font = Enum.Font.GothamBlack, TextSize = size, TextColor3 = color, Text = text,
				}, sg)
				make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thick }, t) -- чёрная обводка букв
			end
			line("вода", 8, 66, 60, Color3.fromRGB(120, 205, 255), 3)
			line("мировая", 78, 36, 28, Color3.fromRGB(235, 245, 255), 2)
		end
	end

	-- собрать украшение по ключу
	function Decor.newModel(key, name)
		local m = Instance.new("Model")
		m.Name = name or "Decor"
		local origin = newPart(m, "Origin", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), WHITE, PLASTIC, false)
		origin.Transparency = 1
		origin.CanQuery = false
		m.PrimaryPart = origin
		local build = B[key] or B.gift
		build(m)
		return m
	end

	-- карточка с вращающейся моделью (ViewportFrame): вместо картинки крутится сама модель
	function Decor.addSpinner(parent, key)
		local vp = make("ViewportFrame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 66),
			BackgroundTransparency = 1, Active = false,
			Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 244, 225),
			LightDirection = Vector3.new(-0.5, -1, -0.6),
		}, parent)
		local m = Decor.newModel(key, "Preview")
		m.Parent = vp
		local bbCF, bbSize = m:GetBoundingBox()
		local c = bbCF.Position
		-- модель крутится вокруг своей оси (x = 0, z = 0), поэтому камера смотрит на эту ось
		local radius = bbSize.Magnitude / 2 + Vector3.new(c.X, 0, c.Z).Magnitude
		local look = Vector3.new(0, c.Y, 0)
		local dist = radius / math.sin(math.rad(20)) * 1.05
		local cam = make("Camera", { FieldOfView = 40 }, vp)
		cam.CFrame = CFrame.lookAt(look + Vector3.new(0, dist * 0.3, dist * 0.95), look)
		vp.CurrentCamera = cam
		Decor.spinners[#Decor.spinners + 1] = { model = m, phase = #Decor.spinners * 0.9 }
		return vp
	end

	-- крутим все модели в панели (вызывается каждый кадр, пока панель открыта)
	function Decor.spin(dt)
		Decor.angle += dt * 1.4
		for _, s in ipairs(Decor.spinners) do
			s.model:PivotTo(CFrame.Angles(0, Decor.angle + s.phase, 0))
		end
	end
end

-- опора под приподнятой рельсой (бетонный столб до земли)
local function groundBelow(x, y, z)
	local filter = { railsFolder, camera }
	if cart then
		table.insert(filter, cart.model)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(filter, pl.Character)
		end
	end
	supportParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -400, 0), supportParams)
	return hit and hit.Position.Y or nil
end

local function addSupport(model, x, y, z)
	local bottom = y - BASE_HEIGHT / 2
	local gy = groundBelow(x, bottom - 0.05, z)
	if not gy then
		return
	end
	local h = bottom - gy
	if h < 0.5 then
		return
	end
	local concrete = Color3.fromRGB(110, 112, 122)
	newPart(model, "Support", Vector3.new(0.9, h, 0.9), CFrame.new(0, -BASE_HEIGHT / 2 - h / 2, 0), concrete, Enum.Material.Concrete, true)
	newPart(model, "SupportCap", Vector3.new(2.4, 0.3, 2.4), CFrame.new(0, -BASE_HEIGHT / 2 - 0.15, 0), concrete, Enum.Material.Concrete, true)
end

-- ===== Подсветки (Highlight) =====
local allHL = make("Highlight", {
	FillColor = C.accent,
	FillTransparency = 0.88,
	OutlineColor = C.accent,
	OutlineTransparency = 0.15,
	DepthMode = Enum.HighlightDepthMode.Occluded,
	Enabled = false,
}, railsFolder) -- один Highlight на все рельсы

local hoverHL = make("Highlight", {
	FillColor = C.bad,
	OutlineColor = WHITE,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
})

local function flashRail(target, color)
	local hl = make("Highlight", {
		FillColor = WHITE,
		OutlineColor = color or C.good,
		FillTransparency = 0,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, target)
	local tw = tween(hl, 0.7, { FillTransparency = 1, OutlineTransparency = 1 })
	tw.Completed:Once(function()
		hl:Destroy()
	end)
end

-- ===== Дома: двери и жители (NPC) =====
-- ДВЕРЬ — украшение «Дверь» (панель «Декор»). Подойди — дверь подсветится и над ней появится картинка;
-- зажми кнопку на 0.1 с — створка откроется или закроется. Снаружи (там, где коврик) — «лицо» двери, створка открывается внутрь.
-- ЖИТЕЛИ (NPC) появляются, когда на базе есть хотя бы одна дверь. Они гуляют внутри (за дверью), иногда выходят
-- погулять на улицу и возвращаются. Если увидят тебя — могут помахать; нагулявшись у двери — подпрыгивают от радости;
-- если ты появишься перед ними слишком резко — пугаются, смотрят на тебя, смеются и уходят гулять или к двери.
Home.folder = make("Folder", { Name = "MyResidents_LocalOnly" }, workspace)
Home.rayParams = RaycastParams.new()
Home.rayParams.FilterType = Enum.RaycastFilterType.Exclude
Home.overlap = OverlapParams.new()
Home.overlap.FilterType = Enum.RaycastFilterType.Exclude
Home.overlap.MaxParts = 80
do
	local list = {}
	for key, id in pairs(Home.FACES) do
		list[#list + 1] = make("Decal", { Name = key, Texture = "rbxassetid://" .. id }, Home.folder)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list) -- заранее подгружаем картинки лиц
		end)
	end)
end
Home.kindCache = setmetatable({}, { __mode = "k" }) -- что за модель рядом (человек / объект с аниматором / ничего), помним 4 секунды

-- на сколько градусов поворачивает кнопка R у выбранного украшения (стены и двери — по 90°)
function Decor.turnStep()
	for _, it in ipairs(Decor.list) do
		if it.key == Decor.key then
			return it.turn or Decor.TURN
		end
	end
	return Decor.TURN
end

-- ----- Двери -----
-- повернуть створку на angle градусов вокруг петель (петли — на левом краю проёма, x = -1.9)
function Home.setAngle(d, angle)
	local base = d.model.PrimaryPart.CFrame
	local hinge = CFrame.new(-1.9, 0, 0)
	local rot = hinge * CFrame.Angles(0, math.rad(angle), 0) * hinge:Inverse()
	for _, l in ipairs(d.leaf) do
		l.part.CFrame = base * rot * l.rel
	end
end

-- делаем из поставленной модели настоящую дверь: кнопка, подсветка, картинка, створка
function Home.attachDoor(m, cf)
	local d = { model = m, leaf = {}, open = false, hintOn = false }
	local origin = m.PrimaryPart
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Leaf") then
			d.leaf[#d.leaf + 1] = { part = p, rel = origin.CFrame:ToObjectSpace(p.CFrame), collide = p.CanCollide }
		end
	end

	-- где «снаружи» и «внутри»: лицо двери (коврик) смотрит наружу, створка открывается внутрь
	local back = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z).Unit
	d.pos0 = cf.Position
	d.back = back
	d.inGate = d.pos0 + back * 4.4 -- дальше, чем размах створки (3.8), чтобы она не задевала жителя
	d.outGate = d.pos0 - back * 3.4
	d.inCenter = d.pos0 + back * (Home.IN_ROOM * 0.6 + 5)
	d.outCenter = d.pos0 - back * (Home.OUT_ROOM * 0.6 + 5)

	-- невидимая точка, к которой привязана кнопка
	local trigger = newPart(m, "Trigger", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 3.4, 0), WHITE, Enum.Material.SmoothPlastic, false)
	trigger.Transparency = 1
	trigger.CanQuery = false
	d.trigger = trigger

	d.prompt = make("ProximityPrompt", {
		ActionText = "Открыть", ObjectText = "Дверь",
		HoldDuration = Home.HOLD, MaxActivationDistance = Home.RANGE,
		RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E,
		Enabled = not buildMode, -- в режиме строительства двери «спят»
	}, trigger)

	-- подсветка (включается, когда подходишь) и картинка над дверью
	d.hl = make("Highlight", {
		FillColor = C.accent, FillTransparency = 0.75, OutlineColor = WHITE, OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false,
	}, m)
	d.gui = make("BillboardGui", {
		Adornee = trigger, Size = UDim2.fromOffset(84, 84), StudsOffset = Vector3.new(0, 6.6, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 80, Enabled = false,
	}, m)
	d.img = make("ImageLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Home.IMAGE, ImageTransparency = 1,
	}, d.gui)
	d.imgScale = make("UIScale", { Scale = 0.6 }, d.img)

	-- угол створки хранится в NumberValue — его удобно плавно менять твином
	d.val = Instance.new("NumberValue")
	d.val.Changed:Connect(function(v)
		if m.Parent then
			Home.setAngle(d, v)
		end
	end)

	d.prompt.Triggered:Connect(function()
		Home.setOpen(d, not d.open)
	end)
	Home.doors[m] = d
	if Home.refreshNpcBtn then
		Home.refreshNpcBtn() -- появилась дверь — появляется кнопка «НПС»
	end
	return d
end

function Home.detachDoor(m)
	local d = Home.doors[m]
	if d then
		d.val:Destroy()
		Home.doors[m] = nil
		if Home.refreshNpcBtn then
			Home.refreshNpcBtn()
		end
	end
end

function Home.clearDoors()
	for m in pairs(Home.doors) do
		Home.detachDoor(m)
	end
	Home.resetRoutes() -- маршруты принадлежат слоту постройки: при очистке/смене слота забываем
end

-- открыть / закрыть; autoClose — через сколько секунд закрыть самой (для жителей)
function Home.setOpen(d, on, autoClose)
	if d.open == on then
		if on and autoClose then
			d.closeAt = os.clock() + autoClose
		end
		return
	end
	d.open = on
	d.closeAt = (on and autoClose) and (os.clock() + autoClose) or nil
	d.prompt.ActionText = on and "Закрыть" or "Открыть"
	for _, l in ipairs(d.leaf) do
		l.part.CanCollide = false -- пока створка движется, сквозь неё можно пройти
	end
	local tw = tween(d.val, 0.45, { Value = on and -90 or 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	tw.Completed:Once(function()
		if d.model.Parent and not d.open then
			for _, l in ipairs(d.leaf) do
				l.part.CanCollide = l.collide
			end
		end
	end)
end

-- подсветка и картинка, когда игрок рядом
function Home.hint(d, on)
	if d.hintOn == on then
		return
	end
	d.hintOn = on
	d.hl.Enabled = on
	if on then
		d.gui.Enabled = true
		tween(d.img, 0.25, { ImageTransparency = 0 })
		tween(d.imgScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		tween(d.img, 0.2, { ImageTransparency = 1 })
		tween(d.imgScale, 0.2, { Scale = 0.6 })
		task.delay(0.25, function()
			if not d.hintOn then
				d.gui.Enabled = false
			end
		end)
	end
end

-- в режиме строительства двери не реагируют (чтобы кнопка не мешала клавишам)
function Home.setBuild(on)
	for _, d in pairs(Home.doors) do
		d.prompt.Enabled = not on
		if on then
			Home.hint(d, false)
		end
	end
end

function Home.stepDoors(now)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for m, d in pairs(Home.doors) do
		if m.Parent then
			if d.closeAt and now >= d.closeAt then
				Home.setOpen(d, false)
			end
			local near = false
			if root and d.prompt.Enabled then
				near = (root.Position - d.trigger.Position).Magnitude <= Home.RANGE
			end
			Home.hint(d, near)
		end
	end
end

-- ----- Жители: помощники -----
function Home.filter()
	local f = { Home.folder, camera }
	if player.Character then
		f[#f + 1] = player.Character
	end
	return f
end

function Home.playerPos()
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

function Home.alive(n)
	return n.alive and n.model.Parent ~= nil and n.hum.Health > 0
end

-- точка земли под pos (и то, на что она попала)
function Home.groundAt(pos)
	Home.rayParams.FilterDescendantsInstances = Home.filter()
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), Home.rayParams)
	if hit then
		return hit.Position, hit.Instance
	end
	return nil, nil
end

-- по верху украшений (камень, ящик…) жители не ходят
function Home.blocked(inst)
	local m = inst and inst:FindFirstAncestorOfClass("Model")
	return m ~= nil and m.Parent == railsFolder and m:GetAttribute("Kind") == "decor"
end

-- между a и b нет преград
function Home.clear(a, b)
	Home.rayParams.FilterDescendantsInstances = Home.filter()
	local from, to = a + Vector3.new(0, 2.2, 0), b + Vector3.new(0, 2.2, 0)
	return workspace:Raycast(from, to - from, Home.rayParams) == nil
end

-- случайная точка рядом с center, куда можно дойти по прямой
function Home.pick(n, center, radius)
	local baseY = n.door.pos0.Y
	for _ = 1, 8 do
		local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
		local g, inst = Home.groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		if g and math.abs(g.Y - baseY) < 3 and not Home.blocked(inst) and Home.clear(n.root.Position, g)
			and Vector3.new(g.X - n.root.Position.X, 0, g.Z - n.root.Position.Z).Magnitude > 4 then
			return g
		end
	end
	return nil
end

-- звук у жителя (звучит из его тела)
function Home.getSound(n, key)
	local s = n.sounds[key]
	if not s then
		s = make("Sound", {
			SoundId = Home.SOUNDS[key], Volume = 1, RollOffMinDistance = 12, RollOffMaxDistance = 90,
			PlaybackSpeed = n.pitch or 1,
		}, n.root)
		n.sounds[key] = s
	end
	return s
end

function Home.say(n, key)
	Home.getSound(n, key):Play()
end

-- мимика: key = "prescare" / "scared" / "wave" / "joy" / "terrified" / "laugh"; nil — обычное лицо
function Home.setFace(n, key)
	if n.faceKey == key then
		return
	end
	n.faceKey = key
	local decal = n.faceDecal
	if not decal or not decal.Parent then
		return
	end
	if key and Home.FACES[key] then
		decal.Texture = "rbxassetid://" .. Home.FACES[key]
	else
		decal.Texture = n.faceNormal or ""
	end
end

function Home.play(n, name)
	local t = n.anim[name]
	if t then
		t:Play(0.15)
	end
end

function Home.stop(n, name)
	local t = n.anim[name]
	if t then
		t:Stop(0.2)
	end
end

-- плавно повернуться лицом к точке
function Home.face(n, pos)
	local root = n.root
	n.hum.AutoRotate = false
	for _ = 1, 8 do
		if not Home.alive(n) then
			return
		end
		local from = root.Position
		local flat = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
		if flat.Magnitude < 0.05 then
			break
		end
		root.CFrame = root.CFrame:Lerp(CFrame.lookAt(from, from + flat), 0.35)
		task.wait()
	end
	n.hum.AutoRotate = true
end

-- руки вверх (испуг): поворачиваем «плечи» R6-скелета
function Home.armsUp(n, on)
	n.c0 = n.c0 or {}
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder" }) do
		local j = n.model:FindFirstChild(name, true)
		if j and j:IsA("Motor6D") then
			n.c0[name] = n.c0[name] or j.C0
			j.C0 = on and (n.c0[name] * CFrame.Angles(math.rad(-150), 0, 0)) or n.c0[name]
		end
	end
end

-- ждём seconds; false — если прервало событие (помахать / испугаться) или жителя уже нет
function Home.pause(n, seconds)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if not Home.alive(n) or n.event or (n.pending and not n.lock and not n.panic and os.clock() >= n.pendingAt) then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- облачко над головой («Hi!»)
function Home.bubble(n, text)
	local head = n.model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = make("BillboardGui", {
		Adornee = head, Size = UDim2.fromOffset(120, 48), StudsOffset = Vector3.new(0, 2.1 * n.scale + 0.3, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 90,
	}, n.model)
	local box = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, box)
	local lbl = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 26,
		TextColor3 = Color3.fromRGB(30, 34, 50), TextTransparency = 1, Text = text,
	}, box)
	tween(box, 0.2, { BackgroundTransparency = 0.05 })
	tween(lbl, 0.2, { TextTransparency = 0 })
	task.delay(2.0, function()
		tween(box, 0.3, { BackgroundTransparency = 1 })
		tween(lbl, 0.3, { TextTransparency = 1 })
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end)
end

-- постоять: если рядом ты — повернуться к тебе, а не пялиться в стену
function Home.idle(n, seconds)
	local pp = Home.playerPos()
	if pp and n.seen and (pp - n.root.Position).Magnitude < 16 and math.random() < 0.6 then
		Home.face(n, pp)
	end
	Home.pause(n, seconds)
end

-- идём к точке: "ok" — дошли, "event" — прервали, "stuck" — застряли, "dead" — жителя нет
function Home.walkRaw(n, target, stopDist, timeout)
	local hum, root = n.hum, n.root
	local t0 = os.clock()
	local lastPos, lastMove = root.Position, t0
	local nextMove = t0
	while true do
		if not Home.alive(n) then
			return "dead"
		end
		hum.WalkSpeed = (n.speed or Home.WALK) * (n.fast and Home.FAST or 1) -- в панике и при испуге бегут быстрее
		if n.event or (n.pending and not n.lock and not n.panic and os.clock() >= n.pendingAt) then
			hum:MoveTo(root.Position)
			return "event" -- событие или пора идти учиться
		end
		local now = os.clock()
		local p = root.Position
		if Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude <= stopDist then
			return "ok"
		end
		if now - t0 > timeout then
			return "stuck"
		end
		if (p - lastPos).Magnitude > 0.6 then
			lastPos, lastMove = p, now
		elseif now - lastMove > 1.2 then
			hum.Jump = true -- попробуем перепрыгнуть препятствие
			if now - lastMove > 3 then
				return "stuck"
			end
		end
		if now >= nextMove then
			hum:MoveTo(target) -- MoveTo «затухает» через 8 секунд, поэтому повторяем
			nextMove = now + 1.5
		end
		task.wait(0.1)
	end
end

-- Обёртка над walkRaw. Если «дошли» мгновенно (уже стоим у цели), walkRaw возвращается без единой паузы —
-- и цикл, который вызывает walkTo снова и снова, мог крутиться без остановки и вешать всю игру.
-- Теперь каждый вызов гарантированно отдаёт управление хотя бы на 0.1 секунды.
function Home.walkTo(n, target, stopDist, timeout)
	local t0 = os.clock()
	local r = Home.walkRaw(n, target, stopDist, timeout)
	if os.clock() - t0 < 0.05 then
		task.wait(0.1)
	end
	return r
end

-- ----- Жители: поведение -----
-- подпрыгнуть от радости (со звуком)
function Home.joy(n)
	Home.say(n, "joy")
	Home.play(n, "cheer")
	Home.setFace(n, "joy")
	for _ = 1, n.small and 5 or 3 do
		if not Home.alive(n) then
			return
		end
		n.hum.Jump = true
		task.wait(0.6)
	end
	Home.stop(n, "cheer")
	Home.setFace(n, nil)
end

-- испугался → посмотрел на тебя → засмеялся → пошёл гулять или к двери
function Home.scared(n)
	n.lock = true
	local hum, root = n.hum, n.root
	hum:MoveTo(root.Position)
	Home.setFace(n, "prescare") -- готовится испугаться
	task.wait(0.35)
	Home.setFace(n, "scared")
	Home.say(n, "scare")
	Home.armsUp(n, true)
	local pp = Home.playerPos()
	if pp then
		local away = Vector3.new(root.Position.X - pp.X, 0, root.Position.Z - pp.Z)
		if away.Magnitude > 0.1 then
			away = away.Unit
			hum.Jump = true
			local k = 0.6 + 0.4 * n.scale
			root.AssemblyLinearVelocity = Vector3.new(away.X * 14 * k, 20 * k, away.Z * 14 * k) -- отскочил назад
		end
	end
	task.wait(0.9)
	Home.armsUp(n, false)
	Home.setFace(n, nil)
	pp = Home.playerPos()
	if pp then
		Home.face(n, pp) -- посмотрел на тебя
	end
	task.wait(0.8)
	if Home.alive(n) then
		Home.say(n, "laugh") -- посмеялся
		Home.play(n, "laugh")
		Home.setFace(n, "laugh")
		task.wait(2.4)
		Home.stop(n, "laugh")
		Home.setFace(n, nil)
	end
	if math.random() < 0.5 then
		n.wantDoor = true -- пошёл к двери (выйти или вернуться), иначе просто продолжит гулять
	end
	n.lock = false
end

-- ----- Обучение: жители повторяют твой маршрут -----
-- Пока ты ходишь, скрипт записывает твой путь. Когда ты уходишь далеко от дома и там остаёшься (или возвращаешься),
-- из записи получается «урок»: жители выходят из дома, идут ТОЧНО по твоему маршруту (по тем же точкам),
-- на месте смотрят и удивляются, потом бегом возвращаются домой по тому же пути. Иногда ходят туда сами.

-- ближайшая дверь к точке (и расстояние до неё)
function Home.nearestDoor(pos)
	local best, bestD = nil, math.huge
	for m, d in pairs(Home.doors) do
		if m.Parent then
			local dist = (d.pos0 - pos).Magnitude
			if dist < bestD then
				best, bestD = d, dist
			end
		end
	end
	return best, bestD
end

-- вывод в консоль (Output) для отладки обучения; выключается через Home.DEBUG = false
function Home.log(...)
	if Home.DEBUG then
		print("[Обучение]", ...)
	end
end

-- ----- Маршруты: ты сам записываешь путь, жители его повторяют -----
-- В разделе «НПС → Обучение» есть слоты маршрутов. В слоте нажимаешь ⏺, идёшь нужным путём и жмёшь «Сохранить» —
-- маршрут запоминается (и сохраняется вместе со слотом постройки). Кнопка ▶ отправляет жителей по этому маршруту:
-- они выходят из дома, идут точно по твоей линии (с подсветкой), на месте удивляются и бегом возвращаются.

function Home.newRoutes()
	local list = {}
	for i = 1, Home.ROUTE_SLOTS do
		list[i] = { name = "Маршрут " .. i, pts = {} }
	end
	return list
end
Home.routes = Home.newRoutes()

function Home.routeLength(pts)
	local len = 0
	for i = 2, #pts do
		len += (pts[i] - pts[i - 1]).Magnitude
	end
	return len
end

-- «урок» для жителей: точки маршрута и направление, куда смотреть на месте
function Home.makeLesson(r, look)
	local pts = r.pts
	if not look and #pts >= 2 then
		local a, b = pts[#pts - 1], pts[#pts]
		look = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	end
	r.lesson = { pts = pts, look = (look and look.Magnitude > 0.1) and look.Unit or nil }
end

-- все готовые уроки (из слотов, где есть маршрут)
function Home.lessonList()
	local list = {}
	for _, r in ipairs(Home.routes) do
		if r.lesson and #r.pts >= Home.ROUTE_MIN then
			list[#list + 1] = r.lesson
		end
	end
	return list
end

-- маршрут ↔ строка (для сохранения вместе с постройкой)
function Home.packRoute(pts)
	local parts = {}
	for i, p in ipairs(pts) do
		parts[i] = string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
	end
	return table.concat(parts, ";")
end

function Home.unpackRoute(str)
	local pts = {}
	if type(str) ~= "string" then
		return pts
	end
	for x, y, z in str:gmatch("(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)") do
		local fx, fy, fz = tonumber(x), tonumber(y), tonumber(z)
		if fx and fy and fz and #pts < Home.MAX_TRAIL then
			pts[#pts + 1] = Vector3.new(fx, fy, fz)
		end
	end
	return pts
end

-- запись маршрута из сохранения: { 0, 0, 0, 0, 6, имя, "x,y,z;x,y,z;…", номер слота }
function Home.loadRoute(r)
	local i = r[8]
	if type(i) ~= "number" or i < 1 or i > Home.ROUTE_SLOTS then
		return
	end
	i = math.floor(i)
	local rt = { name = (type(r[6]) == "string") and r[6] or ("Маршрут " .. i), pts = Home.unpackRoute(r[7]) }
	if #rt.pts >= Home.ROUTE_MIN then
		Home.makeLesson(rt)
	end
	Home.routes[i] = rt
	if Home.ui then
		Home.ui.refresh()
	end
end

-- забываем маршруты (при смене слота постройки или очистке); если шла запись — она отменяется
function Home.resetRoutes()
	Home.rec = nil
	Home.routes = Home.newRoutes()
	if Home.ui then
		Home.ui.showRec(false)
		Home.ui.refresh()
	end
	if Home.refreshNpcBtn then
		Home.refreshNpcBtn()
	end
end

-- начать запись маршрута в слот
function Home.startRecord(slot)
	Home.rec = { slot = slot, pts = {}, length = 0, look = nil }
	if Home.ui then
		Home.ui.showRec(true)
		Home.ui.refresh()
	end
	toast("Запись пошла: пройди нужный путь и нажми «Сохранить»", C.bad)
end

-- закончить запись; save = true — сохранить в слот. Возвращает true, если маршрут сохранён.
function Home.stopRecord(save)
	local rec = Home.rec
	if not rec then
		return false
	end
	Home.rec = nil
	if Home.ui then
		Home.ui.showRec(false)
	end
	local saved = false
	if save then
		if #rec.pts >= Home.ROUTE_MIN then
			local r = Home.routes[rec.slot]
			r.pts = rec.pts
			Home.makeLesson(r, rec.look)
			saved = true
			toast("Маршрут сохранён в слот " .. rec.slot, C.good)
		else
			toast("Маршрут слишком короткий — пройди подальше", C.warn)
		end
	end
	if Home.ui then
		Home.ui.refresh()
	end
	return saved
end

-- пока идёт запись: добавляем точки твоего пути (каждый тик)
function Home.recordStep(now)
	local rec = Home.rec
	if not rec then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	Home.rayParams.FilterDescendantsInstances = Home.filter()
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), Home.rayParams) -- точка земли под тобой
	if not hit then
		return
	end
	local feet = hit.Position
	local last = rec.pts[#rec.pts]
	if not last or (feet - last).Magnitude >= Home.STEP then
		rec.pts[#rec.pts + 1] = feet
		if last then
			rec.length += (feet - last).Magnitude
		end
		if #rec.pts >= Home.MAX_TRAIL then
			toast("Маршрут достиг предельной длины — сохраняю", C.warn)
			if Home.stopRecord(true) then
				Home.needSave = true -- сохранить в данные слота (это делает основной цикл)
			end
			return
		end
	end
	local lv = root.CFrame.LookVector
	rec.look = Vector3.new(lv.X, 0, lv.Z) -- куда ты смотришь: так же будут смотреть жители на месте
end

-- отправить жителей по готовому уроку (каждый стартует чуть позже остальных; кто уже учится — не трогаем).
-- Возвращает, скольким жителям дали задание.
function Home.dispatch(lesson)
	local count = 0
	for _, n in ipairs(Home.npcs) do
		if Home.alive(n) and not n.studyHL and math.random() < Home.LEARN_CHANCE then
			n.pending = lesson
			n.pendingAt = os.clock() + math.random() * 4
			count += 1
		end
	end
	Home.log("отправлено жителей:", count)
	if count > 0 and toast then
		toast("Жители идут по твоему маршруту — учатся!", C.accent)
	end
	return count
end

-- кнопка ▶ в слоте: отправить жителей по сохранённому маршруту
function Home.sendRoute(i)
	local r = Home.routes[i]
	if not r or #r.pts < Home.ROUTE_MIN or not r.lesson then
		toast("В этом слоте нет маршрута — сначала нажми «Запомнить»", C.warn)
		return
	end
	if #Home.npcs == 0 then
		toast("Жителей пока нет — они появляются у двери, подожди немного", C.warn)
		return
	end
	if Home.dispatch(r.lesson) == 0 then
		toast("Все жители сейчас заняты — попробуй чуть позже", C.warn)
	end
end

-- на сколько корень (HumanoidRootPart) жителя выше земли, когда он стоит (считаем по ногам)
function Home.liftOf(n)
	local leg = n.model:FindFirstChild("Left Leg")
	if leg and leg:IsA("BasePart") then
		return math.max(1, n.root.Position.Y - (leg.Position.Y - leg.Size.Y / 2))
	end
	return 3 * (n.scale or 1)
end

-- идти ТОЧНО по маршруту; reverse — с конца в начало. true — дошёл до конца.
-- Житель не «ищет дорогу», а скользит вдоль самой линии маршрута: корень закреплён и двигается по твоим точкам,
-- а ноги сами идут (анимация ходьбы). Поэтому он не застревает, не сворачивает и идёт ровно там, где шёл ты.
function Home.followRoute(n, pts, reverse)
	local root = n.root
	local route = {}
	if reverse then
		for i = #pts, 1, -1 do
			route[#route + 1] = pts[i]
		end
	else
		for i = 1, #pts do
			route[i] = pts[i]
		end
	end
	local cum, total = { 0 }, 0
	for i = 2, #route do
		total += (route[i] - route[i - 1]).Magnitude
		cum[i] = total
	end
	if total < 1 then
		return true
	end
	n.lift = n.lift or Home.liftOf(n)
	local A = n.anim
	n.hum:MoveTo(root.Position)
	root.Anchored = true
	n.routeMove = true -- пока идёт по маршруту, походкой управляю я (а не событие Running)
	if A.idle then
		A.idle:Stop(0.15)
	end
	if A.walk then
		A.walk:Play(0.15)
	end
	local function finish(ok)
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		n.routeMove = false
		n.walking = false
		if A.walk then
			A.walk:Stop(0.2)
		end
		if A.idle then
			A.idle:Play(0.2)
		end
		return ok
	end

	local s, i, heading = 0, 1, nil
	while true do
		if not Home.alive(n) or n.panic or not n.door.model.Parent then
			return finish(false) -- паника, дверь убрали или жителя нет — обучение прерывается
		end
		local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
		local speed = (n.speed or Home.WALK) * (n.fast and Home.FAST or 1)
		s = math.min(total, s + speed * dt)
		while i < #route - 1 and cum[i + 1] < s do
			i += 1
		end
		local a, b = route[i], route[i + 1]
		local seg = cum[i + 1] - cum[i]
		local pos = a:Lerp(b, seg > 0 and (s - cum[i]) / seg or 1)
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if dir.Magnitude > 0.01 then
			-- поворачивается плавно, чтобы на изгибах не дёргался
			heading = heading and heading:Lerp(dir.Unit, math.min(1, dt * 10)) or dir.Unit
		end
		local p3 = Vector3.new(pos.X, pos.Y + n.lift, pos.Z)
		if heading and heading.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(p3, p3 + heading)
		else
			root.CFrame = CFrame.new(p3)
		end
		if A.walk then
			A.walk:AdjustSpeed(speed / (14.5 * n.scale))
		end
		if s >= total then
			return finish(true)
		end
	end
end

-- «учёба»: выйти из дома → пройти по маршруту → на месте удивиться → бегом обратно домой.
-- Пока житель учится, он подсвечен (Highlight), чтобы его было видно.
function Home.study(n, lesson)
	local d = n.door
	n.lock = true
	Home.log("житель идёт учиться; маршрут:", #lesson.pts, "точек")
	n.studyHL = make("Highlight", {
		FillColor = C.accent, FillTransparency = 0.6, OutlineColor = WHITE, OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, n.model)
	local function finish()
		n.lock = false
		n.fast = n.panic == true
		Home.setFace(n, nil)
		if n.studyHL then
			n.studyHL:Destroy()
			n.studyHL = nil
		end
	end
	-- маршрут начинаем с первой точки, которая уже снаружи дома (по ту сторону двери, где коврик)
	local first = 1
	for i, p in ipairs(lesson.pts) do
		if (p - d.pos0):Dot(d.back) < -1 then
			first = i
			break
		end
	end
	local pts = {}
	for i = first, #lesson.pts do
		pts[#pts + 1] = lesson.pts[i]
	end
	if #pts < 4 then
		return finish()
	end
	-- 1) выйти из дома
	if n.place == "in" then
		local r = Home.walkTo(n, d.inGate, 1.2, 16)
		if r ~= "ok" or not Home.passDoor(n, d.inGate, d.outGate) then
			return finish()
		end
		n.place = "out"
	end
	if not Home.alive(n) or n.panic or not d.model.Parent then
		return finish()
	end
	-- 2) к началу маршрута (если не дошёл за разумное время — переносим к началу, чтобы дальше всё шло ровно)
	local r = Home.walkTo(n, pts[1], 2.5, 25)
	if r ~= "ok" and Home.alive(n) and not n.panic then
		n.root.CFrame = CFrame.new(pts[1] + Vector3.new(0, n.lift or 3, 0))
	end
	-- 3) точно по твоему маршруту
	if not Home.followRoute(n, pts, false) then
		return finish()
	end
	-- 4) на месте: смотрят туда, куда смотрел ты, и удивляются
	n.hum:MoveTo(n.root.Position)
	Home.setFace(n, "amazed")
	Home.bubble(n, "!")
	if lesson.look then
		Home.face(n, n.root.Position + lesson.look * 10)
	end
	local t0 = os.clock()
	while Home.alive(n) and not n.panic and os.clock() - t0 < Home.STARE do
		task.wait(0.2)
	end
	Home.setFace(n, nil)
	if not Home.alive(n) or n.panic then
		return finish()
	end
	-- 5) бегом обратно по тому же маршруту
	n.fast = true
	if not Home.followRoute(n, pts, true) then
		return finish()
	end
	-- 6) домой
	Home.walkTo(n, d.outGate, 1.5, 25)
	if Home.passDoor(n, d.outGate, d.inGate) then
		n.place = "in"
		n.nextOut = os.clock() + math.random(12, 25)
	else
		n.wantDoor = true
		n.backAt = os.clock() + 2
	end
	finish()
end

-- ----- Чужие рядом: чужой NPC пугает, объект с AnimationController вызывает панику -----
-- что это за модель: "npc" — человек (Humanoid), "obj" — объект с AnimationController, "none" — просто модель
function Home.kindOf(model, now)
	local c = Home.kindCache[model]
	if c and now - c.at < 4 then
		return c.kind, c.hum
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local kind = "none"
	if hum then
		kind = "npc"
	elseif model:FindFirstChildOfClass("AnimationController")
		or (model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("AnimationController")) then
		kind = "obj"
	end
	Home.kindCache[model] = { kind = kind, hum = hum, at = now }
	return kind, hum
end

-- ищем рядом чужих: позиция ближайшего чужого NPC (FEAR_RADIUS) и ближайшего объекта с AnimationController (ALARM_RADIUS)
function Home.scan(n, now)
	local filter = { Home.folder, camera, railsFolder }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			filter[#filter + 1] = pl.Character -- игроки — это не «чужие NPC»
		end
	end
	Home.overlap.FilterDescendantsInstances = filter
	local center = n.root.Position
	local radius = math.max(Home.FEAR_RADIUS, Home.ALARM_RADIUS)
	local parts = workspace:GetPartBoundsInRadius(center, radius, Home.overlap)
	local checked = {}
	local npcPos, npcDist, objPos, objDist
	for _, part in ipairs(parts) do
		-- AnimationController может лежать прямо в детали
		if part:FindFirstChildOfClass("AnimationController") and not part:FindFirstAncestorOfClass("Model") then
			local dist = (part.Position - center).Magnitude
			if dist <= Home.ALARM_RADIUS and (not objDist or dist < objDist) then
				objPos, objDist = part.Position, dist
			end
		end
		local inst = part.Parent
		for _ = 1, 6 do
			if not inst or inst == workspace then
				break
			end
			if inst:IsA("Model") and not checked[inst] then
				checked[inst] = true
				local kind, hum = Home.kindOf(inst, now)
				if kind ~= "none" then
					local pos = inst:GetPivot().Position
					local dist = (pos - center).Magnitude
					if kind == "npc" and hum.Health > 0 and dist <= Home.FEAR_RADIUS and (not npcDist or dist < npcDist) then
						npcPos, npcDist = pos, dist
					elseif kind == "obj" and dist <= Home.ALARM_RADIUS and (not objDist or dist < objDist) then
						objPos, objDist = pos, dist
					end
				end
			end
			inst = inst.Parent
		end
	end
	return npcPos, objPos
end

-- куда бежать от угрозы: в сторону от неё, по прямой без преград
function Home.fleePoint(n, threat)
	local p = n.root.Position
	local away = Vector3.new(p.X - threat.X, 0, p.Z - threat.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	end
	away = away.Unit
	local baseY = n.door.pos0.Y
	for _, deg in ipairs({ 0, 40, -40, 80, -80, 120, -120 }) do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(away)
		local g, inst = Home.groundAt(p + dir * 14)
		if g and math.abs(g.Y - baseY) < 4 and not Home.blocked(inst) and Home.clear(p, g) then
			return g
		end
	end
	return nil
end

-- чужой NPC рядом: испугался, вскрикнул и убежал от него (вдвое быстрее)
function Home.fear(n, from)
	n.lock = true
	n.lastFear = os.clock()
	local hum, root = n.hum, n.root
	hum:MoveTo(root.Position)
	Home.setFace(n, "prescare")
	task.wait(0.3)
	Home.setFace(n, "scared")
	Home.say(n, "scare")
	Home.armsUp(n, true)
	hum.Jump = true
	task.wait(0.5)
	Home.armsUp(n, false)
	Home.setFace(n, "terrified") -- убегает перепуганный
	n.fast = true
	local t0 = os.clock()
	local laps = 0
	while Home.alive(n) and os.clock() - t0 < 7 and laps < 40 do
		laps += 1
		local threat = n.threat or from
		if (root.Position - threat).Magnitude > Home.FEAR_RADIUS + 8 then
			break -- убежал достаточно далеко
		end
		local target = Home.fleePoint(n, threat)
		if not target then
			-- бежать некуда (стены): жмётся к двери и пережидает
			target = (n.place == "in") and n.door.inGate or n.door.outGate
		end
		Home.walkTo(n, target, 2, 3)
		task.wait(0.15) -- каждый круг цикла обязательно отдаёт управление — раньше здесь игра зависала
	end
	n.lastFear = os.clock() -- пауза до следующего испуга считается с конца бегства
	n.fast = n.panic == true
	Home.setFace(n, n.panic and "terrified" or nil)
	if n.place == "out" then
		n.wantDoor = true -- если был на улице, потом возвращается к двери
	end
	n.lock = false
end

-- паника (рядом объект с AnimationController): бегом к двери — снаружи заходят внутрь, а те, кто уже внутри, жмутся у двери
function Home.panicStep(n)
	local d = n.door
	Home.setFace(n, "terrified") -- перепугался
	if n.place == "out" then
		local r = Home.walkTo(n, d.outGate, 1.5, 14)
		if r == "ok" then
			n.lock = true
			if Home.alive(n) and Home.passDoor(n, d.outGate, d.inGate) then
				n.place = "in"
				n.nextOut = os.clock() + math.random(12, 25)
			end
			n.lock = false
		elseif r == "stuck" then
			task.wait(0.5)
		end
	else
		Home.walkTo(n, d.inGate, 1.5, 10)
		Home.pause(n, 0.4)
	end
end

function Home.react(n)
	local ev = n.event
	n.event = nil
	if ev.type == "fear" then
		Home.fear(n, ev.from)
	elseif ev.type == "scare" then
		Home.scared(n)
	elseif ev.type == "wave" then
		n.lock = true
		n.hum:MoveTo(n.root.Position)
		local pp = Home.playerPos()
		if pp then
			Home.face(n, pp)
		end
		Home.say(n, "wave")
		Home.bubble(n, Home.GREET)
		Home.play(n, "wave")
		Home.setFace(n, "wave")
		task.wait(2.4)
		Home.stop(n, "wave")
		Home.setFace(n, nil)
		n.lock = false
	end
end

-- пройти через дверь: открыть, пройти по оси двери, закрыть за собой
function Home.passDoor(n, fromGate, toGate)
	local d = n.door
	Home.setOpen(d, true, 5)
	task.wait(0.5)
	local r = Home.walkTo(n, d.pos0, 1.0, 6)
	if r == "ok" then
		r = Home.walkTo(n, toGate, 1.2, 6)
	end
	task.delay(0.6, function()
		if d.model.Parent then
			Home.setOpen(d, false)
		end
	end)
	return r == "ok"
end

-- выйти погулять
function Home.exit(n)
	local d = n.door
	local r = Home.walkTo(n, d.inGate, 1.2, 16)
	if r == "event" or r == "dead" then
		return -- wantDoor остаётся: вернёмся к этому после реакции
	end
	if r ~= "ok" then
		n.wantDoor = false
		return
	end
	n.lock = true
	if Home.passDoor(n, d.inGate, d.outGate) then
		n.place = "out"
		n.backAt = os.clock() + math.random(14, 28)
	end
	n.wantDoor = false
	n.lock = false
end

-- нагулялся: идёт к двери, прыгает от радости и заходит внутрь
function Home.returnHome(n)
	local d = n.door
	local r = Home.walkTo(n, d.outGate, 1.5, 22)
	if r == "event" or r == "dead" then
		return
	end
	if r ~= "ok" then
		n.wantDoor = false
		n.backAt = os.clock() + 6
		if (n.root.Position - d.outGate).Magnitude > 40 then
			n.root.CFrame = CFrame.new(d.outGate + Vector3.new(0, 3, 0)) -- слишком далеко от дома и путь не нашёлся — возвращаем к двери
		end
		return
	end
	n.lock = true
	Home.face(n, d.pos0)
	if not n.panic and math.random() < (n.small and math.min(1, Home.JOY_CHANCE + 0.25) or Home.JOY_CHANCE) then
		Home.joy(n)
	end
	if Home.alive(n) and Home.passDoor(n, d.outGate, d.inGate) then
		n.place = "in"
		n.nextOut = os.clock() + math.random(12, 25)
	end
	n.wantDoor = false
	n.lock = false
end

function Home.insideStep(n)
	local now = os.clock()
	if not n.wantDoor and now >= n.nextOut then
		n.nextOut = now + math.random(12, 25)
		if math.random() < Home.OUT_CHANCE then
			n.wantDoor = true
		end
	end
	if n.wantDoor then
		return Home.exit(n)
	end
	local target = Home.pick(n, n.door.inCenter, Home.IN_ROOM)
	if target then
		Home.walkTo(n, target, 1.5, 12)
	end
	Home.idle(n, 0.8 + math.random() * 2.5) -- постоял, огляделся
end

function Home.outsideStep(n)
	local now = os.clock()
	if now >= n.backAt then
		n.wantDoor = true
	end
	if n.wantDoor then
		return Home.returnHome(n)
	end
	local target = Home.pick(n, n.door.outCenter, Home.OUT_ROOM)
	if target then
		Home.walkTo(n, target, 1.5, 12)
	end
	Home.idle(n, 0.8 + math.random() * 2.5)
end

-- дверь убрали: идём к ближайшей оставшейся, а если дверей нет — житель исчезает
function Home.rehome(n)
	local best, bestD
	for m, d in pairs(Home.doors) do
		if m.Parent then
			local dist = (d.pos0 - n.root.Position).Magnitude
			if not bestD or dist < bestD then
				best, bestD = d, dist
			end
		end
	end
	if not best then
		Home.despawn(n)
		return
	end
	n.door = best
	n.wantDoor = false
	n.place = ((n.root.Position - best.pos0):Dot(best.back) > 0) and "in" or "out"
	n.nextOut = os.clock() + math.random(8, 16)
	n.backAt = os.clock() + math.random(8, 16)
end

-- один «шаг» жизни жителя
function Home.tick(n)
	n.fast = n.panic == true -- в панике бегут вдвое быстрее
	if not n.panic and n.faceKey == "terrified" and not n.lock then
		Home.setFace(n, nil) -- паника кончилась — лицо снова обычное
	end
	local now = os.clock()
	-- иногда сам идёт на выученное место
	if not n.pending and now >= n.nextVisit then
		n.nextVisit = now + math.random(Home.VISIT_MIN, Home.VISIT_MAX)
		local lessons = Home.lessonList()
		if #lessons > 0 and math.random() < Home.VISIT_CHANCE then
			n.pending = lessons[math.random(1, #lessons)]
			n.pendingAt = now
		end
	end
	if n.event then
		Home.react(n)
	elseif not n.door.model.Parent then
		Home.rehome(n)
	elseif n.panic then
		Home.panicStep(n)
	elseif n.pending and now >= n.pendingAt then
		local lesson = n.pending
		n.pending = nil
		Home.study(n, lesson) -- идёт учиться по твоему маршруту
	elseif n.place == "in" then
		Home.insideStep(n)
	else
		Home.outsideStep(n)
	end
	task.wait()
end

function Home.run(n)
	while Home.alive(n) do
		local ok, err = pcall(Home.tick, n)
		if not ok then
			-- что-то пошло не так: пишем в консоль, сбрасываем состояние и продолжаем жить
			warn("Жители: ошибка в поведении:", err)
			n.lock, n.event, n.fast = false, nil, false
			if n.studyHL then
				n.studyHL:Destroy()
				n.studyHL = nil
			end
			n.root.Anchored = false
			n.routeMove = false
			pcall(Home.armsUp, n, false)
			pcall(Home.setFace, n, nil)
			task.wait(1)
		end
	end
end

-- ----- Жители: зрение (видят тебя → машут; слишком резко появился → пугаются) -----
function Home.perceive(n, now, dt)
	local proot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not proot or not Home.alive(n) then
		return
	end
	-- упал с карты — вернём к двери
	if n.root.Position.Y < n.door.pos0.Y - 80 then
		n.model:PivotTo(CFrame.new(n.door.inGate + Vector3.new(0, 4, 0)))
		return
	end
	local eye = n.root.Position + Vector3.new(0, 1.5 * n.scale, 0)
	local to = proot.Position - n.root.Position
	local dist = to.Magnitude
	local flat = Vector3.new(to.X, 0, to.Z)
	local visible = dist < Home.SEE and flat.Magnitude > 0.1 and n.root.CFrame.LookVector:Dot(flat.Unit) > 0.5 -- видит в пределах ±60°
	if visible then
		Home.rayParams.FilterDescendantsInstances = Home.filter()
		local target = proot.Position + Vector3.new(0, 1, 0)
		visible = workspace:Raycast(eye, target - eye, Home.rayParams) == nil -- стены загораживают
	end
	-- как быстро именно ТЫ приближаешься к жителю (его собственная ходьба не считается)
	local ppos = proot.Position
	local pclosing = 0
	if n.prevP then
		local npcPos = n.root.Position
		pclosing = ((npcPos - n.prevP).Magnitude - (npcPos - ppos).Magnitude) / math.max(dt, 0.05)
	end
	n.prevP = ppos
	local unseenFor = now - n.lastSeen
	local wasSeen = n.seen
	if visible then
		n.seen = true
		n.lastSeen = now
	elseif unseenFor > 1.5 then
		n.seen = false
	end
	-- чужие рядом? проверяем раз в полсекунды
	if now >= n.nextScan then
		n.nextScan = now + 0.7 + math.random() * 0.3
		local npcPos, objPos = Home.scan(n, now)
		n.threat = npcPos -- позиция чужого NPC (или nil)
		if objPos then
			n.panicUntil = now + 3 -- паника длится, пока объект рядом, и ещё 3 секунды
		end
	end
	n.panic = now < n.panicUntil
	if n.lock or n.event then
		return
	end
	-- чужой NPC рядом → пугаются и убегают
	if n.threat and not n.panic and now - n.lastFear > Home.FEAR_COOLDOWN then
		n.event = { type = "fear", from = n.threat }
		return
	end
	-- испуг — только если ты очень резко оказался рядом: подлетел на огромной скорости (телепорт, быстрая вагонетка)
	-- или вынырнул из-за угла после долгого отсутствия. Обычная ходьба и бег не пугают.
	if visible and not n.panic and dist < Home.SCARE_DIST and now - n.lastScare > Home.SCARE_COOLDOWN and now - n.bornAt > 8 then
		local sudden = pclosing > Home.SCARE_SPEED
			or (unseenFor > 3 and dist < Home.SCARE_DIST * 0.6 and pclosing > Home.SCARE_SPEED * 0.55)
		if sudden then
			n.lastScare = now
			if math.random() < Home.SCARE_CHANCE then
				n.event = { type = "scare" }
				return
			end
		end
	end
	-- заметил тебя → с шансом 40% здоровается: машет рукой и говорит «Hi!»
	if visible and not n.panic and not wasSeen and now - n.lastWave > Home.WAVE_COOLDOWN then
		n.lastWave = now
		if math.random() < Home.WAVE_CHANCE then
			n.event = { type = "wave" }
		end
	end
end

-- ----- Жители: появление и исчезновение -----
function Home.newModel(i)
	local rng = Random.new(os.time() + i * 101)
	local legColors = {
		Color3.fromRGB(50, 56, 80), Color3.fromRGB(70, 60, 50), Color3.fromRGB(40, 40, 46), Color3.fromRGB(90, 100, 120),
	}
	local legColor = legColors[rng:NextInteger(1, #legColors)] -- цвет ног (виден, если штаны не загрузятся)
	local pants = Home.PANTS[rng:NextInteger(1, #Home.PANTS)]
	Home.shirtNext = Home.shirtNext % #Home.SHIRTS + 1 -- футболки по очереди, чтобы у соседей были разные
	local shirtId = pants.shirt or Home.SHIRTS[Home.shirtNext] -- к некоторым штанам футболка полагается своя
	Home.hairNext = Home.hairNext % #Home.HAIRS + 1 -- волосы тоже по очереди
	local hairId = Home.HAIRS[Home.hairNext]

	local function build(asTShirt)
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Home.SKIN
		desc.LeftArmColor = Home.SKIN
		desc.RightArmColor = Home.SKIN
		desc.TorsoColor = Color3.fromRGB(245, 245, 245) -- фон под принтом футболки
		desc.LeftLegColor = legColor
		desc.RightLegColor = legColor
		desc.Pants = pants.id
		desc.HairAccessory = tostring(hairId)
		if asTShirt then
			desc.GraphicTShirt = shirtId
		else
			desc.Shirt = shirtId
		end
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
		end)
		desc:Destroy()
		if ok and typeof(model) == "Instance" then
			return model
		end
		return nil
	end

	local model = build(true)
	if model and not model:FindFirstChildOfClass("ShirtGraphic") then
		-- футболка не появилась: вдруг это обычная рубашка — пробуем так
		local alt = build(false)
		if alt and alt:FindFirstChildOfClass("Shirt") then
			model:Destroy()
			model = alt
		elseif alt then
			alt:Destroy()
		end
	end
	return model
end

function Home.loadAnims(n)
	local animator = n.hum:FindFirstChildOfClass("Animator") or make("Animator", {}, n.hum)
	n.anim = {}
	for name, id in pairs(Home.ANIMS) do
		local a = make("Animation", { AnimationId = "rbxassetid://" .. id })
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			n.anim[name] = track
		end
	end
	local A = n.anim
	if A.idle then
		A.idle.Looped = true
		A.idle.Priority = Enum.AnimationPriority.Idle
		A.idle:Play(0)
	end
	if A.walk then
		A.walk.Looped = true
		A.walk.Priority = Enum.AnimationPriority.Movement
	end
	for _, name in ipairs({ "wave", "cheer", "laugh" }) do
		if A[name] then
			A[name].Priority = Enum.AnimationPriority.Action
		end
	end
	-- ходит — играет походка, стоит — стойка
	n.walking = false
	n.hum.Running:Connect(function(speed)
		if n.routeMove then
			return -- по маршруту ходьбой управляет followRoute
		end
		local moving = speed > 0.5
		if moving ~= n.walking then
			n.walking = moving
			if moving then
				if A.idle then A.idle:Stop(0.2) end
				if A.walk then A.walk:Play(0.2) end
			else
				if A.walk then A.walk:Stop(0.2) end
				if A.idle then A.idle:Play(0.2) end
			end
		end
		if moving and A.walk then
			A.walk:AdjustSpeed(speed / (14.5 * n.scale)) -- у малыша шаг короче, ногами перебирает чаще
		end
	end)
end

function Home.pickDoor()
	local list = {}
	for m, d in pairs(Home.doors) do
		if m.Parent then
			list[#list + 1] = d
		end
	end
	return list[math.random(1, math.max(#list, 1))], #list
end

function Home.spawnNpc(index)
	Home.spawning += 1
	task.spawn(function()
		local model = Home.newModel(index) -- создание модели занимает немного времени
		Home.spawning -= 1
		if not model then
			Home.failedAt = os.clock()
			warn("Жители: не удалось создать модель человека — попробую позже")
			return
		end
		local door = Home.pickDoor() -- за это время дверь могли убрать, поэтому выбираем заново
		if not door then
			model:Destroy()
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not hum or not root then
			model:Destroy()
			return
		end
		-- иногда житель — малыш (уменьшаем всю модель вместе со скелетом)
		local smallCount = 0
		for _, o in ipairs(Home.npcs) do
			if o.small then
				smallCount += 1
			end
		end
		local small = math.random() < Home.SMALL_CHANCE or (smallCount == 0 and #Home.npcs + 1 >= Home.MAX_NPC)
		local scale = small and (Home.SMALL_SCALE_MIN + math.random() * (Home.SMALL_SCALE_MAX - Home.SMALL_SCALE_MIN))
			or (0.95 + math.random() * 0.15)
		pcall(function()
			model:ScaleTo(scale)
		end)
		model.Name = small and "ResidentKid" or "Resident"
		hum.WalkSpeed = Home.WALK
		hum.UseJumpPower = false
		hum.JumpHeight = 4 * scale
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local g = Home.groundAt(door.inCenter) or door.pos0
		model:PivotTo(CFrame.new(g + Vector3.new(0, 3.5, 0)))
		model.Parent = Home.folder

		local n = {
			model = model, hum = hum, root = root, door = door, alive = true, place = "in",
			sounds = {}, anim = {}, seen = false, lastSeen = -99, lastWave = -99, lastScare = -99,
			nextScan = os.clock() + math.random() * 0.8, panicUntil = 0, lastFear = -99, panic = false, fast = false,
			pending = nil, pendingAt = 0, nextVisit = os.clock() + math.random(Home.VISIT_MIN, Home.VISIT_MAX),
			nextOut = os.clock() + math.random(8, 20), backAt = 0,
			speed = Home.WALK * (0.85 + math.random() * 0.4) * (small and 1.1 or 1), bornAt = os.clock(),
			small = small, scale = scale, pitch = small and (1 + (1 - scale) * 0.7) or (0.92 + math.random() * 0.12), -- у малышей голос повыше
		}
		local head = model:FindFirstChild("Head")
		local decal = head and (head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal"))
		if head and not decal then
			decal = make("Decal", { Name = "face", Face = Enum.NormalId.Front, Texture = "" }, head)
		end
		n.faceDecal = decal
		n.faceNormal = decal and decal.Texture or "" -- обычное лицо
		hum.Died:Connect(function()
			n.alive = false
		end)
		n.lift = Home.liftOf(n) -- высота корня над землёй (нужна, чтобы ходить по маршруту)
		Home.loadAnims(n)
		Home.npcs[#Home.npcs + 1] = n
		-- заранее загружаем звуки, чтобы первый раз они не запаздывали
		local list = {}
		for key in pairs(Home.SOUNDS) do
			list[#list + 1] = Home.getSound(n, key)
		end
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
		task.spawn(Home.run, n)
	end)
end

function Home.despawn(n)
	n.alive = false
	local i = table.find(Home.npcs, n)
	if i then
		table.remove(Home.npcs, i)
	end
	n.model:Destroy()
end

-- раз в секунду: есть двери — должны быть жители, нет дверей — жителей нет
function Home.sync(now)
	local _, doorCount = Home.pickDoor()
	local want = (doorCount > 0) and Home.MAX_NPC or 0
	while #Home.npcs > want do
		Home.despawn(Home.npcs[#Home.npcs])
	end
	for i = #Home.npcs, 1, -1 do
		local n = Home.npcs[i]
		if not n.alive or not n.model.Parent then
			table.remove(Home.npcs, i)
		end
	end
	if #Home.npcs + Home.spawning < want and now - Home.failedAt > 20 then
		Home.spawnNpc(#Home.npcs + Home.spawning + 1)
	end
end

function Home.step(dt)
	Home.acc += dt
	if Home.acc < 0.12 then
		return
	end
	local tick = Home.acc
	Home.acc = 0
	local now = os.clock()
	Home.stepDoors(now)
	local ok, err = pcall(Home.recordStep, now) -- если идёт запись маршрута — добавляем точки
	if not ok and not Home.recordErr then
		Home.recordErr = true -- пишем только один раз, чтобы не засорять консоль
		warn("[Обучение] ошибка записи маршрута:", err)
	end
	if Home.rec and Home.ui then
		Home.ui.updateRec()
	end
	for _, n in ipairs(Home.npcs) do
		Home.perceive(n, now, tick)
	end
	if now - Home.lastSync > 1 then
		Home.lastSync = now
		Home.sync(now)
	end
end
RunService.Heartbeat:Connect(Home.step)

-- ===== Рельсы, таблички и украшения: создание / удаление / данные =====
local function dropIn(m, cf)
	local nv = Instance.new("NumberValue")
	nv.Value = 1
	m:PivotTo(cf * CFrame.new(0, 3, 0))
	local conn = nv.Changed:Connect(function(v)
		if m.Parent then
			m:PivotTo(cf * CFrame.new(0, v * 3, 0))
		end
	end)
	local tw = tween(nv, 0.45, { Value = 0 }, Enum.EasingStyle.Bounce)
	tw.Completed:Once(function()
		conn:Disconnect()
		nv:Destroy()
		if m.Parent then
			m:PivotTo(cf)
		end
	end)
end

-- заносим рельсу в списки: путь (по нему ездит вагонетка) и концы (для магнита и для переезда)
-- у табличек и украшений пути нет
local function registerPiece(m, kind, cf)
	local info = { model = m, kind = kind, cf = cf }
	if kind ~= "sign" and kind ~= "decor" then
		local d = Geo.localData(kind)
		local pts, tans, ups, cum = {}, {}, {}, { 0 }
		for i, pt in ipairs(d.pts) do
			pts[i] = cf * pt
			tans[i] = cf:VectorToWorldSpace(d.tans[i])
			ups[i] = cf:VectorToWorldSpace(d.ups[i])
			if i > 1 then
				cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude
			end
		end
		local n = #pts
		info.pts, info.tans, info.ups, info.cum, info.len = pts, tans, ups, cum, cum[n]
		-- dir у конца — куда смотрит «продолжение» рельсы (наружу от неё)
		eps[#eps + 1] = {
			pos = pts[1], dir = cf:VectorToWorldSpace(-d.sDir), up = cf:VectorToWorldSpace(d.sUp),
			info = info, which = 1,
		}
		eps[#eps + 1] = {
			pos = pts[n], dir = cf:VectorToWorldSpace(d.eDir), up = cf:VectorToWorldSpace(d.eUp),
			info = info, which = 2,
		}
	end
	pieces[m] = info
	return info
end

-- yaw — поворот вокруг вертикали (у обычных рельс 0 / 90 / 180 / 270), pitch и roll — наклон и крен (у обычных 0);
-- free = true — свободная рельса (не привязана к клетке сетки); text — текст таблички; deco — ключ украшения из MODELS
local function spawnPiece(kind, x, y, z, yaw, pitch, roll, free, animate, text, deco)
	local m
	if kind == "decor" then
		m = Decor.newModel(deco, "Rail")
	else
		m = newRailModel(kind, "Rail")
	end
	local cf = Geo.pieceCF(x, y, z, yaw, pitch, roll)
	if kind ~= "loop" and kind ~= "decor" and math.abs(pitch) < 0.5 and math.abs(roll) < 0.5 then
		addSupport(m, x, y, z) -- опора до земли — только под ровными рельсами
	end
	m:SetAttribute("Rot", yaw)
	m:SetAttribute("Pitch", pitch)
	m:SetAttribute("Roll", roll)
	m:SetAttribute("Free", free)
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Pos", Vector3.new(x, y, z))
	if kind == "sign" then
		setSignText(m, text or "")
	elseif kind == "decor" then
		m:SetAttribute("Deco", deco)
	end
	m:PivotTo(cf)
	m.Parent = railsFolder
	registerPiece(m, kind, cf)
	if kind == "decor" and deco == "door" then
		Home.attachDoor(m, cf) -- кнопка, подсветка, картинка и створка
	end
	if not free then
		tileAt[cellKey(x, z)] = m
	end
	railCount += 1
	if animate then
		dropIn(m, cf)
		flashRail(m, C.good)
	end
	return m
end

local function removeRail(m)
	local p = m:GetAttribute("Pos")
	if p then
		local k = cellKey(p.X, p.Z)
		if tileAt[k] == m then
			tileAt[k] = nil
		end
	end
	local info = pieces[m]
	if info then
		for i = #eps, 1, -1 do
			if eps[i].info == info then
				table.remove(eps, i)
			end
		end
		pieces[m] = nil
	end
	Home.detachDoor(m)
	m:Destroy()
	railCount -= 1
end

local function serialize()
	local out = {}
	for _, m in ipairs(railsFolder:GetChildren()) do
		if m:IsA("Model") then
			local p = m:GetAttribute("Pos")
			if p then
				local kind = m:GetAttribute("Kind")
				local entry = {
					round2(p.X), round2(p.Y), round2(p.Z),
					round2(m:GetAttribute("Rot") or 0),
					KIND_CODE[kind] or 0,
				}
				if kind == "sign" then
					entry[6] = m:GetAttribute("Text") or "" -- текст таблички
				elseif kind == "decor" then
					entry[6] = m:GetAttribute("Deco") or "gift" -- название украшения
				end
				if m:GetAttribute("Free") == true then
					-- свободная рельса: ещё наклон, крен и метка «свободная»
					entry[6] = entry[6] or 0
					entry[7] = round2(m:GetAttribute("Pitch") or 0)
					entry[8] = round2(m:GetAttribute("Roll") or 0)
					entry[9] = 1
				end
				out[#out + 1] = entry
			end
		end
	end
	-- маршруты жителей: { 0, 0, 0, 0, 6, имя, "x,y,z;x,y,z;…", номер слота }
	for i, r in ipairs(Home.routes) do
		if #r.pts >= Home.ROUTE_MIN then
			out[#out + 1] = { 0, 0, 0, 0, KIND_CODE.route, r.name, Home.packRoute(r.pts), i }
		end
	end
	return out
end

local function clearRails()
	if cart then
		removeCart()
	end
	for _, m in ipairs(railsFolder:GetChildren()) do
		if m:IsA("Model") then
			m:Destroy()
		end
	end
	Home.clearDoors()
	table.clear(tileAt)
	table.clear(pieces)
	table.clear(eps)
	railCount = 0
	hoverRail = nil
	hoverHL.Parent = nil
end

local function loadRails(rails)
	for i, r in ipairs(rails) do
		if type(r) == "table" and r[5] == KIND_CODE.route then
			Home.loadRoute(r) -- это не рельса, а сохранённый маршрут
		elseif type(r) == "table"
			and type(r[1]) == "number" and type(r[2]) == "number"
			and type(r[3]) == "number" and type(r[4]) == "number"
			and railCount < MAX_RAILS then
			local kind = CODE_KIND[r[5]] or "straight"
			-- украшения всегда «свободные»; неизвестное название (нет в MODELS) — пропускаем
			local free = (r[9] == 1) or kind == "decor"
			local deco = (kind == "decor" and type(r[6]) == "string" and Decor.builders[r[6]]) and r[6] or nil
			if (free or not tileAt[cellKey(r[1], r[3])]) and (kind ~= "decor" or deco) then
				local text = (kind == "sign" and type(r[6]) == "string") and cleanSignText(r[6]) or nil
				local pitch = (free and type(r[7]) == "number") and r[7] or 0
				local roll = (free and type(r[8]) == "number") and r[8] or 0
				spawnPiece(kind, r[1], r[2], r[3], r[4], pitch, roll, free, false, text, deco)
			end
		end
		if i % 40 == 0 then
			task.wait()
		end
	end
end

local function normalize(raw)
	if type(raw) ~= "table" then
		raw = nil
	end
	local d = { active = 1, slots = {} }
	if raw and type(raw.active) == "number" and raw.active == raw.active then
		d.active = math.clamp(math.floor(raw.active), 1, SLOT_COUNT)
	end
	for i = 1, SLOT_COUNT do
		local s = raw and type(raw.slots) == "table" and raw.slots[i] or nil
		d.slots[i] = {
			name = (type(s) == "table" and type(s.name) == "string") and s.name or ("Слот " .. i),
			rails = (type(s) == "table" and type(s.rails) == "table") and s.rails or {},
		}
	end
	return d
end

-- ===== Сохранение =====
local function flush()
	if not saveFn or not data then
		return
	end
	if busy then
		task.delay(1, flush)
		return
	end
	data.slots[data.active].rails = serialize()
	saveState = "saving"
	refreshPill()
	local ok, res = pcall(function()
		return saveFn:InvokeServer("Save", data)
	end)
	saveState = (ok and res) and "saved" or "error"
	refreshPill()
	if slotsOpen then
		refreshSlots()
	end
end

local function markDirty()
	if not saveFn then
		return
	end
	saveState = "saving"
	refreshPill()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(SAVE_DELAY, function()
		saveQueued = false
		flush()
	end)
end

-- ===== Вагонетка: логика =====
-- Вагонетка едет по «пути» рельсы. Когда путь кончается, она ищет рядом конец другой рельсы
-- (подходящий и по месту, и по направлению) и переезжает на неё. Так одинаково работают
-- обычные рельсы, свободные рельсы и мёртвые петли.

-- точка пути на расстоянии s от начала рельсы: позиция, направление и «верх»
function Geo.samplePath(info, s)
	local pts, cum = info.pts, info.cum
	local n = #pts
	s = math.clamp(s, 0, info.len)
	local i = 1
	while i < n - 1 and cum[i + 1] < s do
		i += 1
	end
	local a, b = cum[i], cum[i + 1]
	local f = (b > a) and (s - a) / (b - a) or 0
	local pos = pts[i]:Lerp(pts[i + 1], f)
	local tan = info.tans[i]:Lerp(info.tans[i + 1], f)
	local up = info.ups[i]:Lerp(info.ups[i + 1], f)
	return pos, tan.Unit, up
end

-- поворот вагонетки: нос — по движению, крыша — к «верху» пути (на петле это может быть вниз)
function Geo.frameFrom(heading, up)
	local back = -heading
	local right = up:Cross(back)
	if right.Magnitude < 1e-4 then
		right = Vector3.new(1, 0, 0):Cross(back)
		if right.Magnitude < 1e-4 then
			right = Vector3.new(0, 0, 1):Cross(back)
		end
	end
	right = right.Unit
	return CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
end

-- переезд на следующую рельсу; false — дальше пути нет
local function advanceCart(c)
	local info = c.info
	local pos, tan
	if c.dir > 0 then
		pos, tan = info.pts[#info.pts], info.tans[#info.tans]
	else
		pos, tan = info.pts[1], -info.tans[1]
	end
	local best, bestD
	for _, ep in ipairs(eps) do
		if ep.info ~= info then
			local d = (ep.pos - pos).Magnitude
			if d < FCFG.END_TOL and (not bestD or d < bestD) and tan:Dot(ep.dir) < -0.5 then
				best, bestD = ep, d
			end
		end
	end
	if not best then
		return false
	end
	c.gap += pos - best.pos -- если концы чуть не совпали, вагонетка «доезжает» плавно, без рывка
	c.info = best.info
	if best.which == 1 then
		c.dir, c.s = 1, 0
	else
		c.dir, c.s = -1, best.info.len
	end
	return true
end

local function spawnCart(tile)
	local info = pieces[tile]
	if not info or not info.pts then
		return
	end
	if cart then
		removeCart()
	end
	local s = info.len / 2
	local pos, tan, up = Geo.samplePath(info, s)
	-- едем туда, куда смотрит камера
	local look = camera.CFrame.LookVector
	local d = Vector3.new(tan.X, 0, tan.Z):Dot(Vector3.new(look.X, 0, look.Z))
	if math.abs(d) < 1e-3 then
		d = tan:Dot(look)
	end
	local dir = (d >= 0) and 1 or -1

	local model = newCartModel()
	model.Parent = workspace
	local rot = Geo.frameFrom(tan * dir, up)
	local cf = CFrame.new(pos) * rot * CFrame.new(0, 0.7, 0)
	model:PivotTo(cf)

	cart = {
		model = model, info = info, dir = dir, s = s,
		speed = 0, running = false, speedIdx = 2, wait = 0, riding = false,
		cf = cf, lastRot = rot, kink = CFrame.new(), gap = Vector3.zero, rebase = false,
	}
	flashRail(model, C.warn)
	refreshCartHud()
	toast("🚃 Вагонетка готова — нажми «Ехать»", C.warn)
end

removeCart = function(msg)
	if not cart then
		return
	end
	local c = cart
	cart = nil
	if c.riding then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.Sit = false
		end
		if root then
			root.CFrame = c.cf * CFrame.new(3.2, 2.5, 0)
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	c.model:Destroy()
	refreshCartHud()
	if msg then
		toast(msg, C.bad)
	end
end

local function setRiding(on)
	if not cart then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	cart.riding = on
	if on then
		hum.Sit = true
		toast("🪑 Поехали! Прыжок — слезть", C.accent)
	else
		hum.Sit = false
		root.CFrame = cart.cf * CFrame.new(3.2, 2.5, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	refreshCartHud()
end

local function stepCart(dt)
	local c = cart
	if not c then
		return
	end
	if c.info.model.Parent ~= railsFolder then
		removeCart("🚃 Вагонетка слетела — рельсу убрали")
		return
	end

	if c.wait > 0 then
		c.wait -= dt
	else
		-- в гору медленнее, с горы быстрее (не больше, чем на уклоне)
		local _, tan0 = Geo.samplePath(c.info, c.s)
		local climb = math.clamp(tan0.Y * c.dir / math.sin(RAMP_ANGLE), -1, 1)
		local slope = 1 - 0.25 * climb
		local goal = c.running and CART_SPEEDS[c.speedIdx] * slope or 0
		c.speed += (goal - c.speed) * math.min(1, dt * 2.5)
		if not c.running and c.speed < 0.1 then
			c.speed = 0
		end
		local dist = c.speed * dt
		for _ = 1, 8 do
			if dist <= 0 then
				break
			end
			local info = c.info
			local remain = (c.dir > 0) and (info.len - c.s) or c.s
			if dist < remain then
				c.s += c.dir * dist
				dist = 0
			else
				dist -= remain
				c.s = (c.dir > 0) and info.len or 0
				c.rebase = true
				if not advanceCart(c) then
					-- конец пути: разворот на этой же рельсе
					c.dir = -c.dir
					c.speed = 0
					c.wait = 0.45
					break
				end
			end
		end
	end

	-- поза вагонетки: положение берём точно с пути, а поворот при смене рельсы доворачиваем плавно
	local pos, tan, up = Geo.samplePath(c.info, c.s)
	local trot = Geo.frameFrom(tan * c.dir, up)
	if c.rebase then
		c.kink = trot:Inverse() * c.lastRot
		c.rebase = false
	end
	c.kink = c.kink:Lerp(CFrame.new(), 1 - math.exp(-dt * 10))
	local rot = trot * c.kink
	c.lastRot = rot
	c.gap = c.gap * math.exp(-dt * 10)

	local cf = CFrame.new(pos + c.gap) * rot * CFrame.new(0, 0.7, 0)
	c.cf = cf
	c.model:PivotTo(cf)

	if c.riding then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root then
			hum.Sit = true
			root.CFrame = cf * SEAT_OFFSET
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		else
			c.riding = false
			refreshCartHud()
		end
	end
end

-- ===== Камера на большой скорости: «рыбий глаз» =====
-- Камера не отъезжает назад, а раскрывает угол обзора (FieldOfView): края «растягиваются», как у объектива «рыбий глаз».
-- Эффект работает, пока ты сидишь в вагонетке; когда замедляешься или слезаешь — угол плавно возвращается.
function FX.update(dt)
	local target = 0
	if cart and cart.riding then
		target = FX.ADD * math.clamp((cart.speed - FX.START) / (FX.FULL - FX.START), 0, 1)
	end
	if target == 0 and FX.add < 0.05 then
		if FX.add ~= 0 then
			camera.FieldOfView = math.clamp(camera.FieldOfView - FX.add, 1, 120)
			FX.add = 0
		end
		return
	end
	local base = camera.FieldOfView - FX.add -- обычный угол обзора (вдруг его поменял другой скрипт)
	local k = (target > FX.add) and FX.IN or FX.OUT
	FX.add += (target - FX.add) * (1 - math.exp(-dt * k))
	camera.FieldOfView = math.clamp(base + FX.add, 1, 120)
end

-- ===== Интерфейс =====
local gui = make("ScreenGui", {
	Name = "RailBuilderUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local root = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local rootScale = make("UIScale", {}, root)
local function updateScale()
	local vp = camera.ViewportSize
	local s = math.clamp(math.min(vp.X / 820, vp.Y / 460), 0.55, 1.2)
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local function corner(o, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end

local function stroke(o, color, th, tr)
	return make("UIStroke", {
		Color = color, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function pad(o, v, h)
	h = h or v
	return make("UIPadding", {
		PaddingTop = UDim.new(0, v), PaddingBottom = UDim.new(0, v),
		PaddingLeft = UDim.new(0, h), PaddingRight = UDim.new(0, h),
	}, o)
end

local function label(parent, props)
	local p = { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = C.text, Text = "" }
	for k, v in pairs(props) do
		p[k] = v
	end
	return make("TextLabel", p, parent)
end

local function button(parent, props, base)
	local p = {
		AutoButtonColor = false, BackgroundColor3 = base, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 15, Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local b = make("TextButton", p, parent)
	corner(b, 10)
	local sc = make("UIScale", {}, b)
	b:SetAttribute("Base", base)
	b.MouseEnter:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = b:GetAttribute("Base"):Lerp(WHITE, 0.12) })
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = b:GetAttribute("Base") })
		tween(sc, 0.1, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(sc, 0.08, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(sc, 0.1, { Scale = 1 })
	end)
	return b
end

local function setBase(b, color)
	b:SetAttribute("Base", color)
	tween(b, 0.15, { BackgroundColor3 = color })
end

local function setActive(b, on, color)
	setBase(b, on and (color or C.accentDark) or C.card)
	local st = b:FindFirstChildOfClass("UIStroke")
	if st then
		tween(st, 0.15, { Transparency = on and 0 or 1 })
	end
end

-- Уведомления сверху
local toastHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, ZIndex = 20,
}, root)
make("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

toast = function(text, color)
	color = color or C.accent
	local f = make("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = C.panel, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, toastHolder)
	corner(f, 14)
	local st = stroke(f, color, 1.5, 1)
	pad(f, 7, 14)
	local l = label(f, { AutomaticSize = Enum.AutomaticSize.XY, TextTransparency = 1, Text = text })
	tween(f, 0.2, { BackgroundTransparency = 0.05 })
	tween(st, 0.2, { Transparency = 0.15 })
	tween(l, 0.2, { TextTransparency = 0 })
	task.delay(2.4, function()
		tween(f, 0.3, { BackgroundTransparency = 1 })
		tween(st, 0.3, { Transparency = 1 })
		local tw = tween(l, 0.3, { TextTransparency = 1 })
		tw.Completed:Once(function()
			f:Destroy()
		end)
	end)
end

-- ===== Карточка игрока: после загрузки «падает» сверху (аватарка скина, ник и регион смайликом) =====
-- Потом появляются панели, а карточка остаётся перед ними (поверх), и чуть позже уезжает в угол.
do
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -150),
		Size = UDim2.fromOffset(300, 112), BackgroundColor3 = C.panel, BorderSizePixel = 0,
		Visible = false, ZIndex = 30, Rotation = -6, -- ZIndex 30 — выше всех панелей
	}, root)
	corner(card, 20)
	stroke(card, C.accent, 2, 0.15)
	Profile.scale = make("UIScale", {}, card)

	-- круглая аватарка (голова твоего скина)
	local ring = make("Frame", {
		Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, card)
	corner(ring, 42)
	stroke(ring, C.accent, 3, 0)
	Profile.avatarImg = make("ImageLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop,
	}, ring)
	corner(Profile.avatarImg, 42)

	-- ник и логин
	label(card, {
		Position = UDim2.fromOffset(112, 14), Size = UDim2.fromOffset(174, 28), Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = player.DisplayName,
	})
	label(card, {
		Position = UDim2.fromOffset(112, 42), Size = UDim2.fromOffset(174, 18), TextSize = 13, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "@" .. player.Name,
	})

	-- регион: флаг-смайлик
	local chip = make("Frame", {
		Position = UDim2.fromOffset(112, 66), Size = UDim2.fromOffset(54, 32),
		BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, card)
	corner(chip, 16)
	Profile.flagL = label(chip, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "🌍" })
	label(card, {
		Position = UDim2.fromOffset(174, 66), Size = UDim2.fromOffset(110, 32), TextSize = 12, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "регион",
	})
	Profile.card = card
end

-- «RU» → 🇷🇺 (флаг собирается из двух «региональных» символов Unicode)
function Profile.flag(code)
	if type(code) ~= "string" or #code ~= 2 then
		return "🌍"
	end
	local a, b = code:upper():byte(1, 2)
	if a < 65 or a > 90 or b < 65 or b > 90 then
		return "🌍"
	end
	return utf8.char(0x1F1E6 + a - 65, 0x1F1E6 + b - 65)
end

-- код региона игрока (например "RU"); если Roblox не ответил — берём регион из языка Roblox ("ru-ru" → "RU")
function Profile.fetchRegion()
	local service = game:GetService("LocalizationService")
	local ok, code = pcall(function()
		return service:GetCountryRegionForPlayerAsync(player)
	end)
	if ok and type(code) == "string" and #code == 2 then
		return code
	end
	local ok2, locale = pcall(function()
		return service.RobloxLocaleId
	end)
	if ok2 and type(locale) == "string" then
		return locale:match("[-_](%a%a)$")
	end
	return nil
end

-- картинка головы скина; миниатюра иногда ещё не готова — пробуем несколько раз
function Profile.fetchAvatar()
	local last
	for _ = 1, 8 do
		local ok, content, ready = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and content then
			last = content
			if ready then
				break
			end
		end
		task.wait(0.5)
	end
	return last
end

-- грузим аватарку и регион заранее (пока идёт экран загрузки)
Profile.pending = 2
function Profile.load()
	task.spawn(function()
		local img = Profile.fetchAvatar()
		if img then
			Profile.avatarImg.Image = img
		end
		Profile.pending -= 1
	end)
	task.spawn(function()
		Profile.flagL.Text = Profile.flag(Profile.fetchRegion())
		Profile.pending -= 1
	end)
end
task.spawn(Profile.load)

-- карточка падает сверху в центр экрана; возвращает управление, когда приземлилась
function Profile.drop()
	local t0 = os.clock()
	while Profile.pending > 0 and os.clock() - t0 < 2 do -- чуть подождём, если аватарка ещё не загрузилась
		task.wait(0.1)
	end
	local card = Profile.card
	card.Position = UDim2.new(0.5, 0, 0, -150)
	card.Rotation = -6
	Profile.scale.Scale = 1
	card.Visible = true
	tween(card, 1.2, { Position = UDim2.new(0.5, 0, 0.5, -20) }, Enum.EasingStyle.Bounce)
	tween(card, 0.9, { Rotation = 0 }, Enum.EasingStyle.Quint)
	task.wait(1.2)
end

-- потом карточка уменьшается и уезжает в правый верхний угол (остаётся поверх панелей) или исчезает
function Profile.settle()
	local card = Profile.card
	if Profile.KEEP then
		local s = Profile.SMALL
		tween(Profile.scale, 0.7, { Scale = s }, Enum.EasingStyle.Quint)
		tween(card, 0.7, { Position = UDim2.new(1, -(14 + 300 * s / 2), 0, 10 + 112 * s / 2) }, Enum.EasingStyle.Quint)
	else
		local tw = tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, -170), Rotation = 6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw.Completed:Once(function()
			card.Visible = false
		end)
	end
end

-- Плашка активного слота (сверху по центру)
local pill = button(root, {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(310, 52), Visible = false,
}, C.panel)
stroke(pill, WHITE, 1, 0.88)
label(pill, { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(30, 52), Font = Enum.Font.GothamBold, TextSize = 22, Text = "📁" })
local pillTop = label(pill, { Position = UDim2.fromOffset(48, 7), Size = UDim2.new(1, -160, 0, 14), TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left })
local pillName = label(pill, { Position = UDim2.fromOffset(48, 22), Size = UDim2.new(1, -160, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
local pillSave = label(pill, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 20), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right })

refreshPill = function()
	if not data then
		return
	end
	pillTop.Text = "СЛОТ " .. data.active .. " ИЗ " .. SLOT_COUNT .. "  ·  нажми, чтобы сменить"
	pillName.Text = data.slots[data.active].name
	local txt, col = "⚠ не сохраняется", C.sub
	if saveState == "saved" then
		txt, col = "✓ сохранено", C.good
	elseif saveState == "saving" then
		txt, col = "● сохраняю…", C.warn
	elseif saveState == "error" then
		txt, col = "⚠ ошибка", C.bad
	end
	pillSave.Text = txt
	pillSave.TextColor3 = col
end

-- Нижняя панель
local dock = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(dock, 18)
stroke(dock, WHITE, 1, 0.88)
pad(dock, 8)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, dock)

local function dockButton(parent, icon, text, order, width)
	local b = button(parent, { Size = UDim2.fromOffset(width or 66, 62), LayoutOrder = order }, C.card)
	stroke(b, C.accent, 2, 1)
	local ic = label(b, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 5), Font = Enum.Font.GothamBold, TextSize = 24, Text = icon })
	local lb = label(b, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -21), TextSize = 11, TextColor3 = C.sub, Text = text })
	return b, ic, lb
end

local buildBtn, buildIcon, buildLbl = dockButton(dock, "🚂", "Строить", 1)
setBase(buildBtn, C.goodDark)
local slotsBtn = dockButton(dock, "📁", "Слоты", 2)
local divider = make("Frame", {
	Size = UDim2.fromOffset(2, 44), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88,
	BorderSizePixel = 0, LayoutOrder = 4, Visible = false,
}, dock)
local tools = make("Frame", {
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1, LayoutOrder = 5, Visible = false,
}, dock)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, tools)

-- кнопки инструментов чуть уже, чтобы панель с табличками и украшениями поместилась на экран
local function toolButton(icon, text, order)
	local b, ic, lb = dockButton(tools, icon, text, order, 58)
	lb.TextSize = 10
	return b, ic, lb
end

-- картинка вместо значка-эмодзи на кнопке
function Decor.icon(btn, image)
	return make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit,
	}, btn)
end

local toolBtns = {}
toolBtns.straight = toolButton("➖", "Прямая", 1)
toolBtns.curve = toolButton("↪", "Поворот", 2)
toolBtns.ramp = toolButton("📐", "Уклон", 3)
toolBtns.erase = toolButton("❌", "Стереть", 4)
toolBtns.cart = toolButton("🚃", "Вагонетка", 5)
toolBtns.sign = toolButton("🪧", "Табличка", 6)
toolBtns.edit = toolButton("✏️", "Текст", 7)
do
	local b, ic = toolButton("🎄", "Декор", 8) -- кнопка «Украшения» (картинка вместо значка)
	ic.Text = ""
	Decor.icon(b, IMG.DECOR)
	Decor.btn = b
end
local rotateBtn = toolButton("↻", "Повернуть", 9)
local actionBtn, actionIcon, actionLbl = toolButton("✔", "Поставить", 10)
setBase(actionBtn, C.goodDark)
actionBtn.Visible = UserInputService.TouchEnabled
Decor.placeImg = Decor.icon(actionBtn, IMG.PLACE) -- картинка «Поставить» вместо галочки

-- ===== Свободный режим: интерфейс =====
local FUI = {}

-- нижняя панель над основной: петля, наклон, крен, сторона, магнит, шаг угла
FUI.dock = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(FUI.dock, 18)
stroke(FUI.dock, WHITE, 1, 0.88)
pad(FUI.dock, 8)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, FUI.dock)

do
	local function freeButton(key, icon, text, order)
		local b, _, lb = dockButton(FUI.dock, icon, text, order, 64)
		FUI[key] = b
		FUI[key .. "Lbl"] = lb
		return b
	end
	toolBtns.loop = freeButton("loop", "🎢", "Петля", 1) -- «Петля» — такой же инструмент, как остальные
	freeButton("pitch", "↗", "Наклон", 2)
	freeButton("roll", "🔃", "Крен", 3)
	freeButton("side", "↔", "Сторона", 4)
	freeButton("magnet", "🧲", "Магнит", 5)
	freeButton("step", "📏", "Шаг", 6)
	FUI.pitchLbl.TextSize = 10
	FUI.rollLbl.TextSize = 10
	FUI.stepLbl.TextSize = 10
	FUI.only = { FUI.pitch, FUI.roll, FUI.side, FUI.magnet, FUI.step } -- кнопки, нужные только когда что-то ставишь
end

-- маленький светящийся шарик на конце рельсы, к которому прилип призрак
FUI.mark = make("Part", {
	Name = "MagnetMark", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1),
	Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	Material = Enum.Material.Neon, Color = C.accent, Transparency = 0.15,
})

local function refreshFreeButtons()
	local o = FM.snapped and FM.rel or FM -- когда призрак прилип, углы считаются от конца рельсы
	FUI.pitchLbl.Text = "Наклон " .. math.round(o.pitch) .. "°"
	FUI.rollLbl.Text = "Крен " .. math.round(o.roll) .. "°"
	FUI.stepLbl.Text = "Шаг " .. FM.stepAngle() .. "°"
	FUI.magnetLbl.Text = (FM.magnet and FM.snapped) and "Прилип ✓" or "Магнит"
	setActive(FUI.side, FM.flip, C.accentDark)
	setActive(FUI.magnet, FM.magnet, C.goodDark)
end
refreshFreeButtons()

-- переключатель «Свободный режим» — как на iPhone (слева сверху, виден в режиме строительства)
do
	local SW_W, SW_H, KNOB = 54, 32, 28
	FUI.card = make("Frame", {
		Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(226, 54),
		BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
	}, root)
	corner(FUI.card, 16)
	stroke(FUI.card, WHITE, 1, 0.88)
	label(FUI.card, {
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -92, 0, 20),
		Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Свободный режим",
	})
	FUI.sub = label(FUI.card, {
		Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -92, 0, 16),
		TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	})
	FUI.track = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(SW_W, SW_H), BackgroundColor3 = C.swOff,
		AutoButtonColor = false, BorderSizePixel = 0, Text = "",
	}, FUI.card)
	corner(FUI.track, SW_H / 2)
	FUI.knob = make("Frame", {
		Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, FUI.track)
	corner(FUI.knob, KNOB / 2)
	stroke(FUI.knob, Color3.new(0, 0, 0), 1, 0.8) -- лёгкая «тень» вокруг ползунка

	-- положение ползунка и цвет дорожки; animate — плавно, как на iPhone
	function FUI.refreshSwitch(animate)
		local on = FM.on
		local goalPos = UDim2.fromOffset(on and (SW_W - KNOB - 2) or 2, 2)
		local goalSize = UDim2.fromOffset(KNOB, KNOB)
		local color = on and C.swOn or C.swOff
		if animate then
			tween(FUI.knob, 0.28, { Position = goalPos, Size = goalSize }, Enum.EasingStyle.Quint)
			tween(FUI.track, 0.22, { BackgroundColor3 = color })
		else
			FUI.knob.Position = goalPos
			FUI.knob.Size = goalSize
			FUI.track.BackgroundColor3 = color
		end
		FUI.sub.Text = on and "без правил · петли" or "по сетке, как обычно"
		FUI.sub.TextColor3 = on and C.good or C.sub
	end

	-- пока палец / мышь прижаты, ползунок слегка вытягивается (как у настоящего переключателя)
	FUI.track.MouseButton1Down:Connect(function()
		local w = KNOB + 6
		tween(FUI.knob, 0.1, {
			Size = UDim2.fromOffset(w, KNOB),
			Position = UDim2.fromOffset(FM.on and (SW_W - w - 2) or 2, 2),
		})
	end)
	FUI.track.MouseLeave:Connect(function()
		FUI.refreshSwitch(true)
	end)
end
FUI.refreshSwitch(false)

local hint = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -106),
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.2, Font = Enum.Font.GothamMedium,
	TextSize = 13, TextColor3 = C.text, Text = "", Visible = false,
}, root)
corner(hint, 12)
pad(hint, 7, 14)

local HINTS = {
	straight = TOUCH_ONLY and "Тапни место → «Поставить»  ·  ▲▼ — высота" or "ЛКМ — поставить  ·  зажми и веди — цепочка  ·  R — повернуть  ·  E / Q — выше / ниже",
	curve = TOUCH_ONLY and "Тапни место → «Поставить»  ·  поворот соединяет две соседние стороны" or "ЛКМ — поставить поворот  ·  R — повернуть  ·  E / Q — выше / ниже",
	ramp = TOUCH_ONLY and "Уклон: нижний конец на текущей высоте. Подъём: ▲ после постановки" or "Уклон: нижний конец — на текущей высоте  ·  R — повернуть  ·  E / Q — выше / ниже",
	erase = TOUCH_ONLY and "Тапни рельсу, табличку или украшение → «Удалить»" or "Наведи на рельсу, табличку или украшение и нажми ЛКМ  ·  зажми и води — стирать подряд",
	cart = TOUCH_ONLY and "Тапни рельсу → «Поставить» вагонетку" or "Нажми на рельсу, чтобы поставить на неё вагонетку",
	sign = TOUCH_ONLY and "Напиши текст в поле → тапни место → «Поставить»  ·  ↻ — повернуть" or "Напиши текст в поле выше  ·  ЛКМ — поставить  ·  R — повернуть  ·  E / Q — выше / ниже",
	edit = TOUCH_ONLY and "Напиши новый текст → тапни табличку → «Применить»" or "Напиши новый текст в поле выше и нажми ЛКМ на табличке",
	loop = "Мёртвая петля ставится только в свободном режиме",
	decor = TOUCH_ONLY and "Выбери украшение → тапни место → «Поставить»  ·  ↻ — повернуть" or "ЛКМ — поставить  ·  R — повернуть  ·  E / Q — выше / ниже  ·  можно ставить и на рельсы",
	-- подсказки свободного режима (для всего, что ставится); короткие, чтобы не залезать на боковые панели
	free = {
		place = TOUCH_ONLY and "Тапни место → «Поставить»  ·  внизу: наклон, крен, магнит" or "ЛКМ — поставить  ·  R поворот  ·  T наклон  ·  Y крен  ·  M магнит",
		loop = TOUCH_ONLY and "Подведи к концу рельсы — прилипнет  ·  «Поставить»" or "Подведи к концу рельсы — прилипнет 🧲  ·  ЛКМ — поставить",
		sign = TOUCH_ONLY and "Напиши текст → тапни место → «Поставить»" or "Текст в поле выше  ·  ЛКМ — поставить  ·  R / T / Y — повороты",
	},
}
-- { значок, подпись, true = вместо значка показать картинку «Поставить» }
local ACTIONS = {
	straight = { "✔", "Поставить", true }, curve = { "✔", "Поставить", true }, ramp = { "✔", "Поставить", true },
	erase = { "🗑", "Удалить" }, cart = { "🚃", "Поставить", true },
	sign = { "✔", "Поставить", true }, edit = { "✏️", "Применить" }, loop = { "✔", "Поставить", true },
	decor = { "✔", "Поставить", true },
}

-- Поле для текста таблички (над подсказкой)
local signPanel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150),
	Size = UDim2.fromOffset(330, 78),
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(signPanel, 14)
stroke(signPanel, WHITE, 1, 0.88)
label(signPanel, {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 16), TextSize = 11, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "🪧 ТЕКСТ ТАБЛИЧКИ",
})
local signCount = label(signPanel, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(70, 16),
	TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right,
})
local signBox = make("TextBox", {
	Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 42),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, TextColor3 = C.text, PlaceholderColor3 = C.sub,
	PlaceholderText = "Напиши что угодно…", Font = Enum.Font.GothamMedium, TextSize = 15,
	ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, ClipsDescendants = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = signText,
}, signPanel)
corner(signBox, 8)
pad(signBox, 4, 8)

local function refreshSignCounter()
	signCount.Text = (utf8.len(signText) or 0) .. "/" .. SIGN_MAX_CHARS
end
refreshSignCounter()

signBox:GetPropertyChangedSignal("Text"):Connect(function()
	local t = cleanSignText(signBox.Text)
	if t ~= signBox.Text then
		signBox.Text = t -- вызовет это событие ещё раз уже с чистым текстом
		return
	end
	signText = t
	refreshSignCounter()
	if ghost and ghostKind == "sign" then
		setSignText(ghost, signText) -- призрак показывает текст сразу
	end
end)

signBox.FocusLost:Connect(function()
	local t = finalSignText(signBox.Text)
	if t ~= signBox.Text then
		signBox.Text = t
	end
end)

-- когда над основной панелью висит панель свободного режима (или открыта панель украшений, она выше),
-- подсказку и поле текста поднимаем выше
local function layoutBottom()
	local extra = 0
	if Decor.open then
		extra = 46
	elseif FUI.dock.Visible then
		extra = 80
	end
	hint.Position = UDim2.new(0.5, 0, 1, -106 - extra)
	signPanel.Position = UDim2.new(0.5, 0, 1, -150 - extra)
end

-- ===== Панель украшений: заменяет нижнюю панель, пока открыта =====
-- в каждой карточке крутится модель (ViewportFrame), а не картинка
Decor.dock = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(Decor.dock, 18)
stroke(Decor.dock, WHITE, 1, 0.88)
pad(Decor.dock, 8)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, Decor.dock)

Decor.backBtn = dockButton(Decor.dock, "◀", "Назад", 1, 62)
Decor.prevBtn = button(Decor.dock, { Size = UDim2.fromOffset(30, 100), LayoutOrder = 2, Text = "‹", TextSize = 28 }, C.card)
-- карточек много, поэтому они лежат в прокручиваемом списке: тяни пальцем / мышью или жми стрелки по бокам
Decor.scroll = make("ScrollingFrame", {
	Size = UDim2.fromOffset(86 * 4.5 + 8 * 4, 108), LayoutOrder = 3,
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.sub,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
}, Decor.dock)
pad(Decor.scroll, 3)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, Decor.scroll)
Decor.nextBtn = button(Decor.dock, { Size = UDim2.fromOffset(30, 100), LayoutOrder = 4, Text = "›", TextSize = 28 }, C.card)
for i, item in ipairs(Decor.list) do
	local card = button(Decor.scroll, { Size = UDim2.fromOffset(86, 100), LayoutOrder = i }, C.card)
	stroke(card, C.accent, 2, 1)
	Decor.addSpinner(card, item.key)
	label(card, {
		Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.GothamBold, TextSize = 12, Text = item.name,
	})
	label(card, {
		Position = UDim2.fromOffset(0, 87), Size = UDim2.new(1, 0, 0, 12),
		TextSize = 9, TextColor3 = C.sub, Text = item.tag,
	})
	Decor.cards[item.key] = card
end
make("Frame", {
	Size = UDim2.fromOffset(2, 44), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88,
	BorderSizePixel = 0, LayoutOrder = 20,
}, Decor.dock)
Decor.rotateBtn = dockButton(Decor.dock, "↻", "Повернуть", 21, 62)
do
	local b, ic = dockButton(Decor.dock, "", "Поставить", 22, 62)
	Decor.actionBtn = b
	setBase(b, C.goodDark)
	b.Visible = UserInputService.TouchEnabled
	Decor.icon(b, IMG.PLACE)
end

-- Панель высоты (слева)
local hpanel = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.4, 0),
	Size = UDim2.fromOffset(78, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(hpanel, 16)
stroke(hpanel, WHITE, 1, 0.88)
pad(hpanel, 8)
make("UIListLayout", {
	Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, hpanel)
label(hpanel, { Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = C.sub, Text = "ВЫСОТА", LayoutOrder = 0 })
local hUp = button(hpanel, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1, Text = "▲", TextSize = 20 }, C.card)
local hLabel = label(hpanel, { Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBold, TextSize = 24, Text = "0", LayoutOrder = 2 })
local hDown = button(hpanel, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 3, Text = "▼", TextSize = 20 }, C.card)
local hReset = button(hpanel, { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 4, Text = "🌍 земля", TextSize = 11 }, C.bg)

-- Панель вагонетки (справа)
local hud = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.45, 0),
	Size = UDim2.fromOffset(180, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false,
}, root)
corner(hud, 16)
stroke(hud, WHITE, 1, 0.88)
pad(hud, 10)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, hud)
label(hud, { Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold, TextSize = 16, Text = "🚃 Вагонетка", LayoutOrder = 0 })
local function hudButton(text, order, base)
	return button(hud, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Text = text, TextSize = 14 }, base or C.card)
end
local hudGo = hudButton("▶ Ехать", 1, C.goodDark)
local hudRev = hudButton("⇄ Развернуть", 2)
local hudSpeed = hudButton("", 3)
local hudRide = hudButton("🪑 Сесть", 4)
local hudDel = hudButton("✖ Убрать", 5, C.badDark)
local hudHint = label(hud, { Size = UDim2.new(1, 0, 0, 30), TextSize = 11, TextColor3 = C.sub, TextWrapped = true, LayoutOrder = 6 })

refreshCartHud = function()
	hud.Visible = cart ~= nil
	if not cart then
		return
	end
	hudGo.Text = cart.running and "⏸ Стоп" or "▶ Ехать"
	setBase(hudGo, cart.running and C.badDark or C.goodDark)
	hudSpeed.Text = CART_SPEED_NAMES[cart.speedIdx]
	hudRide.Text = cart.riding and "🚪 Слезть" or "🪑 Сесть"
	hudHint.Text = cart.riding and "Прыжок — тоже слезть" or "Сядь, чтобы прокатиться"
end

hudGo.Activated:Connect(function()
	if cart then
		cart.running = not cart.running
		refreshCartHud()
	end
end)
hudRev.Activated:Connect(function()
	if cart then
		cart.dir = -cart.dir
		cart.speed = 0
		cart.wait = 0
		cart.rebase = true -- вагонетка плавно развернётся на месте
	end
end)
hudSpeed.Activated:Connect(function()
	if cart then
		cart.speedIdx = cart.speedIdx % #CART_SPEEDS + 1
		refreshCartHud()
	end
end)
hudRide.Activated:Connect(function()
	if cart then
		setRiding(not cart.riding)
	end
end)
hudDel.Activated:Connect(function()
	removeCart("🚃 Вагонетка убрана")
end)

-- ===== Панель слотов =====
local backdrop = make("TextButton", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	AutoButtonColor = false, Text = "", Visible = false, ZIndex = 5,
}, root)
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 400, 0.9, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true,
}, backdrop)
corner(panel, 18)
stroke(panel, WHITE, 1, 0.85)
make("UISizeConstraint", { MaxSize = Vector2.new(400, 470) }, panel)
local panelScale = make("UIScale", {}, panel)

label(panel, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -80, 0, 26), Font = Enum.Font.GothamBold, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Text = "📁 Слоты строительства" })
label(panel, { Position = UDim2.fromOffset(18, 39), Size = UDim2.new(1, -80, 0, 18), TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, Text = "Каждый слот — отдельная постройка. Нажми на слот, чтобы открыть." })
local closeBtn = button(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(36, 36), Text = "✕", TextSize = 16 }, C.card)

local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 1, -128),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.sub, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local footer = label(panel, {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -10), Size = UDim2.new(1, -36, 0, 42),
	TextSize = 12, TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
})

local cards = {}

refreshSlots = function()
	if not data then
		return
	end
	for i, c in ipairs(cards) do
		local active = (i == data.active)
		local count = active and railCount or #data.slots[i].rails
		c.name.Text = data.slots[i].name
		local countText = (count == 0) and "Пусто" or objWord(count)
		c.info.Text = active
			and ('<font color="#50E18C"><b>● АКТИВНЫЙ</b></font>  ·  ' .. countText)
			or (countText .. "  ·  нажми, чтобы открыть")
		tween(c.stroke, 0.15, { Transparency = active and 0 or 1 })
		setBase(c.card, active and Color3.fromRGB(34, 66, 56) or C.card)
		c.badge.BackgroundColor3 = active and C.good or C.bg
		c.badge.TextColor3 = active and C.bg or C.text
	end
	if saveState == "off" then
		footer.Text = "⚠ Сохранение между заходами выключено: слоты работают, но пропадут при выходе. Добавь серверный скрипт RailSaveServer."
		footer.TextColor3 = C.warn
	elseif saveState == "saving" then
		footer.Text = "● Сохраняю…"
		footer.TextColor3 = C.warn
	elseif saveState == "error" then
		footer.Text = "⚠ Не удалось сохранить. Попробую снова при следующем изменении."
		footer.TextColor3 = C.bad
	else
		footer.Text = "✓ Всё сохранено — постройки вернутся при следующем заходе."
		footer.TextColor3 = C.good
	end
	refreshPill()
end

local function setSlotsOpen(on)
	if on and Home.ui and Home.ui.isOpen then
		Home.ui.setOpen(false) -- «НПС» и «Слоты» не открываются одновременно
	end
	slotsOpen = on
	setActive(slotsBtn, on, C.accentDark)
	if on then
		refreshSlots()
		backdrop.Visible = true
		panelScale.Scale = 0.88
		tween(backdrop, 0.2, { BackgroundTransparency = 0.45 })
		tween(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		local tw = tween(backdrop, 0.15, { BackgroundTransparency = 1 })
		tween(panelScale, 0.15, { Scale = 0.92 })
		tw.Completed:Once(function()
			if not slotsOpen then
				backdrop.Visible = false
			end
		end)
	end
end

local function switchSlot(i)
	if busy or i == data.active then
		return
	end
	busy = true
	data.slots[data.active].rails = serialize()
	clearRails()
	data.active = i
	refreshSlots()
	loadRails(data.slots[i].rails)
	busy = false
	refreshSlots()
	markDirty()
	toast("📁 Открыт слот " .. i .. ": " .. data.slots[i].name, C.accent)
end

local function commitName(i, text)
	local name = text:match("^%s*(.-)%s*$")
	local len = utf8.len(name)
	if len and len >= 1 and len <= 20 and name ~= data.slots[i].name then
		data.slots[i].name = name
		refreshSlots()
		markDirty()
		toast("✏️ Слот " .. i .. " переименован", C.good)
	end
end

local function buildSlotCards()
	for i = 1, SLOT_COUNT do
		local card = button(list, { Size = UDim2.new(1, -8, 0, 68), LayoutOrder = i }, C.card)
		local st = stroke(card, C.good, 2, 1)
		local badge = label(card, {
			Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(38, 38),
			BackgroundTransparency = 0, BackgroundColor3 = C.bg,
			Font = Enum.Font.GothamBold, TextSize = 18, Text = tostring(i),
		})
		corner(badge, 19)
		local nameL = label(card, {
			Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -160, 0, 24),
			Font = Enum.Font.GothamBold, TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local info = label(card, {
			Position = UDim2.fromOffset(62, 36), Size = UDim2.new(1, -160, 0, 20),
			TextSize = 12, TextColor3 = C.sub, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
		})
		local box = make("TextBox", {
			Position = nameL.Position, Size = nameL.Size, BackgroundColor3 = C.bg, TextColor3 = C.text,
			Font = Enum.Font.GothamBold, TextSize = 15, ClearTextOnFocus = false,
			PlaceholderText = "Название (до 20 символов)", TextXAlignment = Enum.TextXAlignment.Left,
			Visible = false, BorderSizePixel = 0,
		}, card)
		corner(box, 8)
		pad(box, 0, 8)

		local edit = button(card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(34, 34), Text = "✏️", TextSize = 15 }, C.bg)
		local trash = button(card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 34), Text = "🗑", TextSize = 15 }, C.bg)

		card.Activated:Connect(function()
			if not box.Visible then
				switchSlot(i)
			end
		end)

		edit.Activated:Connect(function()
			nameL.Visible = false
			box.Text = data.slots[i].name
			box.Visible = true
			box:CaptureFocus()
		end)
		box.FocusLost:Connect(function()
			box.Visible = false
			nameL.Visible = true
			commitName(i, box.Text)
		end)

		local armed = false
		local function disarm()
			armed = false
			trash.Text = "🗑"
			setBase(trash, C.bg)
		end
		trash.Activated:Connect(function()
			if busy then
				return
			end
			if not armed then
				armed = true
				trash.Text = "❓"
				setBase(trash, C.badDark)
				toast("Нажми ещё раз — слот " .. i .. " будет очищен", C.warn)
				task.delay(2.5, function()
					if armed then
						disarm()
					end
				end)
				return
			end
			disarm()
			if i == data.active then
				clearRails()
			else
				data.slots[i].rails = {}
			end
			refreshSlots()
			markDirty()
			toast("🗑 Слот " .. i .. " очищен", C.bad)
		end)

		cards[i] = { card = card, stroke = st, badge = badge, name = nameL, info = info }
	end
end

-- ===== Кнопка «НПС» (появляется, когда построена дверь) и раздел «Обучение» =====
-- В «Обучении» — слоты маршрутов. В каждом слоте один ровный ряд из трёх кнопок: Запомнить (записать свой путь и сохранить),
-- Отправить (жители пойдут по маршруту) и Очистить.
Home.npcBtn = dockButton(dock, "", "НПС", 3, 66)
Decor.icon(Home.npcBtn, Home.NPC_IMAGE)
Home.npcBtn.BackgroundTransparency = 1 -- фон кнопки полностью прозрачный: видна только картинка
Home.npcBtn.Visible = false
function Home.refreshNpcBtn()
	Home.npcBtn.Visible = next(Home.doors) ~= nil and not buildMode -- есть хотя бы одна дверь (в режиме строительства кнопка прячется)
end

Home.ui = { isOpen = false, cards = {} }
do
	local ui = Home.ui
	ui.backdrop = make("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		AutoButtonColor = false, Text = "", Visible = false, ZIndex = 5,
	}, root)
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 420, 0.9, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true,
	}, ui.backdrop)
	corner(panel, 18)
	stroke(panel, WHITE, 1, 0.85)
	make("UISizeConstraint", { MaxSize = Vector2.new(420, 480) }, panel)
	ui.scale = make("UIScale", {}, panel)

	-- заголовок: в начале картинка, потом слово «НПС»
	make("ImageLabel", {
		Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1,
		Image = Home.TITLE_IMAGE, ScaleType = Enum.ScaleType.Fit,
	}, panel)
	label(panel, {
		Position = UDim2.fromOffset(56, 12), Size = UDim2.new(1, -170, 0, 30), Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "НПС",
	})
	ui.closeBtn = button(panel, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(86, 30),
		Text = "Закрыть", TextSize = 13,
	}, C.card)

	-- раздел «Обучение»
	local tab = make("Frame", {
		Position = UDim2.fromOffset(18, 52), Size = UDim2.fromOffset(130, 28),
		BackgroundColor3 = C.accentDark, BorderSizePixel = 0,
	}, panel)
	corner(tab, 14)
	label(tab, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 13, Text = "Обучение" })
	label(panel, {
		Position = UDim2.fromOffset(18, 88), Size = UDim2.new(1, -36, 0, 34), TextSize = 12, TextColor3 = C.sub,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Запомнить: пройди маршрут сам и нажми «Сохранить». Отправить: жители повторят его. Очистить: убрать маршрут из слота.",
	})

	local rlist = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 128), Size = UDim2.new(1, -24, 1, -176),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.sub, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rlist)
	ui.footer = label(panel, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -10), Size = UDim2.new(1, -36, 0, 32),
		TextSize = 12, TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- слоты маршрутов: сверху номер, название и сведения, снизу ровный ряд из трёх кнопок одинаковой ширины
	for i = 1, Home.ROUTE_SLOTS do
		local card = button(rlist, { Size = UDim2.new(1, -8, 0, 100), LayoutOrder = i }, C.card)
		local st = stroke(card, C.bad, 2, 1)
		local badge = label(card, {
			Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 0, BackgroundColor3 = C.bg,
			Font = Enum.Font.GothamBold, TextSize = 17, Text = tostring(i),
		})
		corner(badge, 18)
		label(card, {
			Position = UDim2.fromOffset(58, 9), Size = UDim2.new(1, -70, 0, 22), Font = Enum.Font.GothamBold, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Маршрут " .. i,
		})
		local info = label(card, {
			Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -70, 0, 18), TextSize = 12, TextColor3 = C.sub,
			RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local row = make("Frame", {
			Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 36), BackgroundTransparency = 1,
		}, card)
		make("UIGridLayout", {
			FillDirection = Enum.FillDirection.Horizontal, CellPadding = UDim2.fromOffset(8, 0),
			CellSize = UDim2.new(1 / 3, -6, 1, 0), SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		local rec = button(row, { LayoutOrder = 1, Text = "Запомнить", TextSize = 13 }, C.badDark)
		local play = button(row, { LayoutOrder = 2, Text = "Отправить", TextSize = 13 }, C.goodDark)
		local trash = button(row, { LayoutOrder = 3, Text = "Очистить", TextSize = 13 }, C.bg)
		ui.cards[i] = {
			card = card, stroke = st, badge = badge, info = info, rec = rec, play = play, trash = trash, armed = false,
		}
	end

	-- обновить надписи и вид кнопок в слотах
	function ui.refresh()
		for i, c in ipairs(ui.cards) do
			local r = Home.routes[i]
			local n = r and #r.pts or 0
			local has = n >= Home.ROUTE_MIN
			local recording = Home.rec ~= nil and Home.rec.slot == i
			if recording then
				c.info.Text = '<font color="#FF6060"><b>Идёт запись…</b></font>'
			elseif has then
				c.info.Text = n .. " точек, " .. math.floor(Home.routeLength(r.pts)) .. " студов"
			else
				c.info.Text = "Пусто"
			end
			setBase(c.play, has and C.goodDark or C.bg) -- нет маршрута — «Отправить» тусклая
			c.play.TextColor3 = has and C.text or C.sub
			setBase(c.trash, c.armed and C.badDark or C.bg)
			c.trash.Text = c.armed and "Точно?" or "Очистить"
			c.trash.TextColor3 = (has or c.armed) and C.text or C.sub
			c.badge.BackgroundColor3 = has and C.good or C.bg
			c.badge.TextColor3 = has and C.bg or C.text
			tween(c.stroke, 0.15, { Transparency = recording and 0 or 1 })
		end
		if saveState == "off" then
			ui.footer.Text = "Сохранение между заходами выключено: маршруты работают, но пропадут при выходе."
			ui.footer.TextColor3 = C.warn
		else
			ui.footer.Text = "Маршруты сохраняются вместе со слотом постройки."
			ui.footer.TextColor3 = C.sub
		end
	end

	function ui.setOpen(on)
		ui.isOpen = on
		setActive(Home.npcBtn, on, C.accentDark)
		if on then
			if slotsOpen then
				setSlotsOpen(false)
			end
			ui.refresh()
			ui.backdrop.Visible = true
			ui.scale.Scale = 0.88
			tween(ui.backdrop, 0.2, { BackgroundTransparency = 0.45 })
			tween(ui.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			local tw = tween(ui.backdrop, 0.15, { BackgroundTransparency = 1 })
			tween(ui.scale, 0.15, { Scale = 0.92 })
			tw.Completed:Once(function()
				if not ui.isOpen then
					ui.backdrop.Visible = false
				end
			end)
		end
	end

	-- панелька «идёт запись» (слева сверху): заголовок, сведения и два ровных кнопки внизу
	ui.hud = make("Frame", {
		Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(240, 92),
		BackgroundColor3 = C.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, ZIndex = 6,
	}, root)
	corner(ui.hud, 16)
	stroke(ui.hud, C.bad, 2, 0.2)
	label(ui.hud, {
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 20), Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = C.bad, TextXAlignment = Enum.TextXAlignment.Left, Text = "ЗАПИСЬ МАРШРУТА",
	})
	ui.hudInfo = label(ui.hud, {
		Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 16), TextSize = 12, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local hrow = make("Frame", {
		Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1,
	}, ui.hud)
	make("UIGridLayout", {
		FillDirection = Enum.FillDirection.Horizontal, CellPadding = UDim2.fromOffset(8, 0),
		CellSize = UDim2.new(0.5, -4, 1, 0), SortOrder = Enum.SortOrder.LayoutOrder,
	}, hrow)
	ui.recSave = button(hrow, { LayoutOrder = 1, Text = "Сохранить", TextSize = 13 }, C.goodDark)
	ui.recCancel = button(hrow, { LayoutOrder = 2, Text = "Отмена", TextSize = 13 }, C.badDark)
	function ui.updateRec()
		local rec = Home.rec
		if rec then
			ui.hudInfo.Text = "Слот " .. rec.slot .. ": " .. #rec.pts .. " точек, " .. math.floor(rec.length) .. " студов"
		end
	end
	function ui.showRec(on)
		ui.hud.Visible = on
		if on then
			ui.updateRec()
		end
	end
	ui.refresh()
end

pill.Activated:Connect(function()
	setSlotsOpen(not slotsOpen)
end)
slotsBtn.Activated:Connect(function()
	setSlotsOpen(not slotsOpen)
end)
closeBtn.Activated:Connect(function()
	setSlotsOpen(false)
end)
backdrop.Activated:Connect(function()
	setSlotsOpen(false)
end)

-- ===== Призрак, подсветка под курсором, действия =====
-- инструменты-рельсы (их можно наклонять, крутить в свободном режиме, они стыкуются магнитом)
function Decor.railTool(t)
	return t == "straight" or t == "curve" or t == "ramp" or t == "sign" or t == "loop"
end

local function isPlacing(t)
	return Decor.railTool(t) or t == "decor"
end

-- инструменты, которые можно «тянуть» зажатой кнопкой мыши
-- (в свободном режиме рельсы ставятся по одной — иначе магнит за секунду выстроил бы бесконечную цепочку)
local function isHoldTool(t)
	if t == "erase" then
		return true
	end
	return (not FM.on) and (t == "straight" or t == "curve" or t == "ramp")
end

local function hintFor(t)
	if t == "decor" then
		return HINTS.decor
	end
	if FM.on and isPlacing(t) then
		return HINTS.free[t] or HINTS.free.place
	end
	return HINTS[t]
end

local function destroyGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostKind, ghostHL, ghostShown, ghostCF = nil, nil, nil, nil, nil
	Decor.ghostKey = nil
	FUI.mark.Parent = nil
	FM.snapped = false
end

local function createGhost(kind)
	destroyGhost()
	if kind == "decor" then
		ghost = Decor.newModel(Decor.key, "Ghost")
		Decor.ghostKey = Decor.key
	else
		ghost = newRailModel(kind, "Ghost")
	end
	ghostKind = kind
	if kind == "sign" then
		setSignText(ghost, signText)
	end
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d.Name ~= "Origin" then
				d.Transparency = 0.35
			end
		elseif d:IsA("TextLabel") then
			d.TextTransparency = 0.3
		end
	end
	ghostHL = make("Highlight", {
		OutlineColor = WHITE, FillColor = C.good,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, ghost)
end

local function getRay()
	if lastInputTouch then
		if not touchPos then
			return nil
		end
		return camera:ScreenPointToRay(touchPos.X, touchPos.Y)
	end
	local m = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(m.X, m.Y)
end

-- ----- Магнит (свободный режим) -----
-- конец рельсы «свободен», если рядом нет конца другой рельсы
function Geo.endpointOpen(ep)
	for _, o in ipairs(eps) do
		if o.info ~= ep.info and (o.pos - ep.pos).Magnitude < 0.8 then
			return false
		end
	end
	return true
end

-- ближайший к лучу свободный конец рельсы (чем дальше конец, тем щедрее допуск)
function Geo.findMagnet(ray)
	local best, bestD
	for _, ep in ipairs(eps) do
		local v = ep.pos - ray.Origin
		local t = v:Dot(ray.Direction)
		if t > 1 and t < 250 then
			local d = (v - ray.Direction * t).Magnitude
			if d < FCFG.MAGNET + t * 0.015 and (not bestD or d < bestD) and Geo.endpointOpen(ep) then
				best, bestD = ep, d
			end
		end
	end
	return best
end

-- где окажется рельса, если стыковать её с концом ep: началом (обычно) или концом («Сторона»);
-- FM.rel — доворот от идеального продолжения (по умолчанию нули — рельса продолжает путь ровно)
function Geo.attachCF(kind, ep)
	local lf = Geo.localFrames(kind)
	local rel = Geo.oriCF(FM.rel.yaw, FM.rel.pitch, FM.rel.roll)
	if FM.flip then
		return Geo.frameCF(ep.pos, -ep.dir, ep.up) * rel * lf.e:Inverse()
	end
	return Geo.frameCF(ep.pos, ep.dir, ep.up) * rel * lf.s:Inverse()
end

-- такая же рельса уже стоит ровно в этом месте (две одинаковые друг на друге не нужны)
function Geo.isDuplicate(kind, cf)
	for _, info in pairs(pieces) do
		if info.kind == kind
			and (info.cf.Position - cf.Position).Magnitude < 0.3
			and info.cf.LookVector:Dot(cf.LookVector) > 0.98
			and info.cf.UpVector:Dot(cf.UpVector) > 0.98 then
			return true
		end
	end
	return false
end

local function updateGhost(dt)
	local ray = getRay()
	if not ray then
		return
	end

	-- украшения ставятся на любую поверхность (в том числе на рельсы) и привязываются к сетке в 1 стад
	local isDecor = ghostKind == "decor"
	local gs = isDecor and Decor.GRID or (FM.on and FCFG.GRID or GRID)

	-- точка под курсором: земля (уровень 0) или горизонтальная плоскость нужной высоты
	local pos
	if level == 0 then
		-- на земле: луч до поверхности
		local filter = { ghost }
		if not isDecor then
			table.insert(filter, railsFolder)
		end
		if player.Character then
			table.insert(filter, player.Character)
		end
		rayParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
		if hit then
			if not hit.Instance:IsDescendantOf(railsFolder) then
				refY = hit.Position.Y
			end
			local hy = isDecor and hit.Position.Y or (hit.Position.Y + BASE_HEIGHT / 2)
			pos = Vector3.new(math.round(hit.Position.X / gs) * gs, hy, math.round(hit.Position.Z / gs) * gs)
		end
	else
		-- в воздухе: луч до горизонтальной плоскости нужной высоты
		-- (украшение стоит на верхней грани рельсы этого уровня)
		local py = refY + (isDecor and BASE_HEIGHT or BASE_HEIGHT / 2) + level * FM.levelStep()
		local dy = ray.Direction.Y
		if math.abs(dy) > 1e-4 then
			local t = (py - ray.Origin.Y) / dy
			if t > 0 and t < 400 then
				local h = ray.Origin + ray.Direction * t
				pos = Vector3.new(math.round(h.X / gs) * gs, py, math.round(h.Z / gs) * gs)
			end
		end
	end

	local tcf, valid, snapEp
	if isDecor then
		-- украшение: только поворот вокруг вертикали
		if pos then
			tcf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotTarget), 0)
			valid = railCount < MAX_RAILS
		end
	elseif FM.on then
		-- магнит: прилипаем к ближайшему свободному концу другой рельсы
		if FM.magnet and ghostKind ~= "sign" then
			snapEp = Geo.findMagnet(ray)
		end
		if snapEp then
			tcf = Geo.attachCF(ghostKind, snapEp)
		elseif pos then
			tcf = CFrame.new(pos) * Geo.oriCF(rotTarget, FM.pitch, FM.roll)
		end
		valid = tcf ~= nil and railCount < MAX_RAILS and not Geo.isDuplicate(ghostKind, tcf)
	elseif pos then
		-- обычный режим: рельса всегда стоит строго ровно — только поворот вокруг вертикали на 0 / 90 / 180 / 270
		tcf = CFrame.new(pos) * CFrame.Angles(0, math.rad(FM.flatYaw(rotTarget)), 0)
		valid = (railCount < MAX_RAILS) and not tileAt[cellKey(pos.X, pos.Z)]
	end

	-- призрак «прилип» или «отлип» — обновляем подписи кнопок
	local snapped = snapEp ~= nil
	if snapped ~= FM.snapped then
		FM.snapped = snapped
		refreshFreeButtons()
	end

	if not tcf then
		ghost.Parent = nil
		ghostCF, ghostShown = nil, nil
		FUI.mark.Parent = nil
		return
	end

	ghostCF = tcf
	ghostValid = valid

	-- призрак плавно догоняет цель (и по положению, и по повороту)
	ghostShown = ghostShown and ghostShown:Lerp(tcf, 1 - math.exp(-dt * 20)) or tcf
	local bob = 0.1 + math.sin(os.clock() * 4) * 0.06
	ghost.Parent = camera
	ghost:PivotTo(CFrame.new(0, bob, 0) * ghostShown)

	ghostHL.FillColor = (not ghostValid) and C.bad or (snapped and C.accent or C.good)
	ghostHL.FillTransparency = 0.5 + math.sin(os.clock() * 6) * 0.15

	-- светящийся шарик на конце рельсы, к которому прилип призрак
	if snapEp then
		local sz = 1.1 + math.sin(os.clock() * 8) * 0.15
		FUI.mark.Size = Vector3.new(sz, sz, sz)
		FUI.mark.Position = snapEp.pos + snapEp.up * 0.7
		FUI.mark.Parent = camera
	else
		FUI.mark.Parent = nil
	end
end

local function updateHover()
	local rail
	local ray = getRay()
	if ray then
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, hoverParams)
		if hit then
			local m = hit.Instance:FindFirstAncestorOfClass("Model")
			if m and m.Parent == railsFolder then
				rail = m
			end
		end
	end
	-- «Текст» работает только с табличками, «Вагонетка» — только с рельсами (не с табличками и украшениями)
	if rail then
		local kind = rail:GetAttribute("Kind")
		local isSign = kind == "sign"
		if (tool == "edit" and not isSign) or (tool == "cart" and (isSign or kind == "decor")) then
			rail = nil
		end
	end
	if rail ~= hoverRail then
		hoverRail = rail
		hoverHL.Parent = rail
	end
	hoverHL.FillColor = (tool == "erase") and C.bad or ((tool == "edit") and C.good or C.warn)
	hoverHL.FillTransparency = 0.4 + math.sin(os.clock() * 8) * 0.15
end

local function onRailsChanged()
	if slotsOpen then
		refreshSlots()
	end
end

local function doAction(fromHold)
	if not buildMode or busy then
		return
	end
	if tool == "erase" then
		if not hoverRail then
			return
		end
		local r = hoverRail
		hoverRail = nil
		hoverHL.Parent = nil
		removeRail(r)
		markDirty()
		onRailsChanged()
	elseif tool == "cart" then
		if fromHold or not hoverRail then
			return
		end
		spawnCart(hoverRail)
	elseif tool == "edit" then
		if fromHold or not hoverRail then
			return
		end
		setSignText(hoverRail, finalSignText(signText))
		flashRail(hoverRail, C.warn)
		markDirty()
		toast("✏️ Текст таблички обновлён", C.good)
	else
		if fromHold and (tool == "sign" or FM.on) then
			return
		end
		if railCount >= MAX_RAILS then
			if os.clock() - lastLimitToast > 2 then
				lastLimitToast = os.clock()
				toast("Лимит объектов в слоте: " .. MAX_RAILS, C.bad)
			end
			return
		end
		if not ghostCF or not ghostValid then
			return
		end
		local txt = finalSignText(signText)
		if tool == "decor" then
			-- украшение: положение и поворот берём из призрака, наклона и крена нет
			local x, y, z, yaw = Geo.decompose(ghostCF)
			spawnPiece("decor", round2(x), round2(y), round2(z), round2(yaw), 0, 0, true, true, nil, Decor.key)
		elseif FM.on then
			-- свободная рельса: положение и углы берём прямо из призрака
			local x, y, z, yaw, pitch, roll = Geo.decompose(ghostCF)
			spawnPiece(tool, round2(x), round2(y), round2(z), round2(yaw), round2(pitch), round2(roll), true, true, txt)
		else
			-- обычная рельса: наклон и крен всегда 0, поворот — только 0 / 90 / 180 / 270
			local p = ghostCF.Position
			spawnPiece(tool, p.X, round2(p.Y), p.Z, FM.flatYaw(rotTarget), 0, 0, false, true, txt)
		end
		ghostValid = false
		markDirty()
		onRailsChanged()
	end
end

-- поворот вокруг вертикали: у украшений по 15°, в обычном режиме по 90°, в свободном — на выбранный шаг
local function rotate(dir)
	if tool == "decor" then
		rotTarget += Decor.turnStep() * dir
	elseif not FM.on then
		rotTarget += 90 * dir
	elseif FM.snapped then
		FM.rel.yaw = FM.wrap(FM.rel.yaw + FM.stepAngle() * dir)
	else
		rotTarget += FM.stepAngle() * dir
	end
end

-- наклон (pitch) и крен (roll): «в воздухе» — относительно мира, у прилипшего призрака — относительно конца рельсы
function FM.tilt(which, dir)
	if not FM.on or tool == "decor" then
		return
	end
	local o = FM.snapped and FM.rel or FM
	o[which] = FM.wrap(o[which] + FM.stepAngle() * dir)
	refreshFreeButtons()
end

function FM.toggleMagnet()
	FM.magnet = not FM.magnet
	refreshFreeButtons()
	toast(FM.magnet and "🧲 Магнит включён" or "🧲 Магнит выключен", FM.magnet and C.good or C.sub)
end

function FM.cycleStep()
	FM.angle = FM.angle % #FCFG.ANGLES + 1
	refreshFreeButtons()
end

local function setLevel(n)
	n = math.clamp(n, 0, FM.on and FCFG.MAX_LEVEL or MAX_LEVEL)
	if n == level then
		return
	end
	level = n
	hLabel.Text = tostring(level)
end

local function sampleRefY()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, railsFolder }
	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -60, 0), params)
	if hit then
		refY = hit.Position.Y
	end
end

local function setTool(t)
	if t == "loop" and not FM.on then
		t = "straight" -- петля есть только в свободном режиме
	end
	tool = t
	hoverRail = nil
	hoverHL.Parent = nil
	holding = false
	for name, b in pairs(toolBtns) do
		setActive(b, name == t)
	end
	local placing = isPlacing(t)
	rotateBtn.Visible = placing
	hpanel.Visible = placing
	signPanel.Visible = (t == "sign" or t == "edit")
	for _, b in ipairs(FUI.only) do
		b.Visible = placing and t ~= "decor" -- наклон, крен, магнит и т.д. — только для рельс
	end
	if placing then
		if ghostKind ~= t or (t == "decor" and Decor.ghostKey ~= Decor.key) then
			createGhost(t)
		end
	else
		destroyGhost()
	end
	local act = ACTIONS[t]
	actionIcon.Text = act[1]
	actionLbl.Text = act[2]
	Decor.placeImg.Visible = act[3] == true -- для «Поставить» вместо значка показываем картинку
	actionIcon.Visible = act[3] ~= true
	hint.Text = hintFor(t)
end

-- переключатель «Свободный режим»
local function setFreeMode(on)
	if on == FM.on then
		return
	end
	local oldStep = FM.levelStep()
	FM.on = on
	-- высота хранится в «шагах»: переводим в новые шаги, чтобы рельса осталась на той же высоте
	level = math.clamp(math.round(level * oldStep / FM.levelStep()), 0, on and FCFG.MAX_LEVEL or MAX_LEVEL)
	hLabel.Text = tostring(level)
	-- сбрасываем всё «свободное»: наклон, крен, углы стыка, сторону, прилипание.
	-- Иначе после выключения режима рельсы могли остаться повёрнутыми не по сетке.
	FM.resetAngles()
	if not on then
		rotTarget = FM.flatYaw(rotTarget) -- обычный режим знает только прямые углы
	end
	-- старый призрак выбрасываем и строим заново, чтобы он не тащил за собой старый поворот
	destroyGhost()
	ghostValid = false
	FUI.refreshSwitch(true)
	refreshFreeButtons()
	FUI.dock.Visible = buildMode and on and not Decor.open
	layoutBottom()
	if buildMode then
		setTool(tool)
	end
	toast(on and "🔓 Свободный режим: рельсы без правил" or "🔒 Обычный режим: рельсы по сетке", on and C.good or C.sub)
end

-- ===== Панель украшений: открыть / закрыть / выбрать =====
-- когда панель открыта, обычная нижняя панель (и переключатель свободного режима) скрыты
function Decor.setOpen(on)
	if on == Decor.open then
		return
	end
	Decor.open = on
	dock.Visible = not on
	Decor.dock.Visible = on
	if on then
		setSlotsOpen(false)
		if Home.ui and Home.ui.isOpen then
			Home.ui.setOpen(false)
		end
		Decor.dock.Position = UDim2.new(0.5, 0, 1, 140)
		tween(Decor.dock, 0.4, { Position = UDim2.new(0.5, 0, 1, -14) }, Enum.EasingStyle.Back)
		FUI.card.Visible = false
		FUI.dock.Visible = false
		Decor.select(Decor.key) -- подсвечивает выбранную карточку и включает инструмент «украшение»
	else
		dock.Position = UDim2.new(0.5, 0, 1, 90)
		tween(dock, 0.4, { Position = UDim2.new(0.5, 0, 1, -14) }, Enum.EasingStyle.Back)
		FUI.card.Visible = buildMode
		FUI.dock.Visible = buildMode and FM.on
		if tool == "decor" then
			setTool("straight")
		end
	end
	layoutBottom()
end

function Decor.select(key)
	Decor.key = key
	if Decor.turnStep() == 90 then
		rotTarget = FM.flatYaw(rotTarget) -- стены и двери ставятся строго по прямым углам
	end
	for k, b in pairs(Decor.cards) do
		setActive(b, k == key, C.accentDark)
	end
	if Decor.open then
		setTool("decor") -- если украшение другое, призрак пересоздастся
	end
end

local function setBuildMode(on)
	if on and Home.rec then
		toast("Сначала сохрани или отмени запись маршрута", C.warn)
		return
	end
	if not on then
		Decor.setOpen(false) -- выходим из строительства — возвращаем обычную панель
	end
	buildMode = on
	Home.setBuild(on) -- в режиме строительства кнопки дверей отключены
	Home.refreshNpcBtn() -- и кнопка «НПС» тоже прячется
	allHL.Enabled = on
	tools.Visible = on
	divider.Visible = on
	hint.Visible = on
	FUI.dock.Visible = on and FM.on
	if on then
		FUI.card.Position = UDim2.fromOffset(-250, 10)
		FUI.card.Visible = true
		tween(FUI.card, 0.4, { Position = UDim2.fromOffset(14, 10) }, Enum.EasingStyle.Back)
	else
		FUI.card.Visible = false
	end
	layoutBottom()
	buildIcon.Text = on and "✖" or "🚂"
	buildLbl.Text = on and "Выйти" or "Строить"
	setBase(buildBtn, on and C.badDark or C.goodDark)
	if on then
		sampleRefY()
		setTool(tool)
	else
		holding = false
		hoverRail = nil
		hoverHL.Parent = nil
		hpanel.Visible = false
		signPanel.Visible = false
		destroyGhost()
	end
end

buildBtn.Activated:Connect(function()
	setBuildMode(not buildMode)
end)
for name, b in pairs(toolBtns) do
	b.Activated:Connect(function()
		setTool(name)
	end)
end
rotateBtn.Activated:Connect(function()
	rotate(1)
end)
actionBtn.Activated:Connect(function()
	doAction(false)
end)
hUp.Activated:Connect(function()
	setLevel(level + 1)
end)
hDown.Activated:Connect(function()
	setLevel(level - 1)
end)
hReset.Activated:Connect(function()
	setLevel(0)
end)

-- кнопки свободного режима
FUI.track.Activated:Connect(function()
	setFreeMode(not FM.on)
end)
FUI.pitch.Activated:Connect(function()
	FM.tilt("pitch", 1)
end)
FUI.roll.Activated:Connect(function()
	FM.tilt("roll", 1)
end)
FUI.side.Activated:Connect(function()
	FM.flip = not FM.flip
	refreshFreeButtons()
end)
FUI.magnet.Activated:Connect(function()
	FM.toggleMagnet()
end)
FUI.step.Activated:Connect(function()
	FM.cycleStep()
end)

-- кнопки украшений
Decor.btn.Activated:Connect(function()
	if buildMode then
		Decor.setOpen(true)
	end
end)
Decor.backBtn.Activated:Connect(function()
	Decor.setOpen(false)
end)
-- стрелки по бокам листают список украшений (примерно на три карточки)
function Decor.scrollBy(dx)
	local sf = Decor.scroll
	tween(sf, 0.25, { CanvasPosition = Vector2.new(math.max(0, sf.CanvasPosition.X + dx), 0) })
end
Decor.prevBtn.Activated:Connect(function()
	Decor.scrollBy(-282)
end)
Decor.nextBtn.Activated:Connect(function()
	Decor.scrollBy(282)
end)
Decor.rotateBtn.Activated:Connect(function()
	rotate(1)
end)
Decor.actionBtn.Activated:Connect(function()
	doAction(false)
end)
for key, card in pairs(Decor.cards) do
	card.Activated:Connect(function()
		Decor.select(key)
	end)
end

-- ===== НПС: раздел «Обучение» =====
Home.npcBtn.Activated:Connect(function()
	Home.ui.setOpen(not Home.ui.isOpen)
end)
Home.ui.closeBtn.Activated:Connect(function()
	Home.ui.setOpen(false)
end)
Home.ui.backdrop.Activated:Connect(function()
	Home.ui.setOpen(false)
end)
for i, c in ipairs(Home.ui.cards) do
	c.rec.Activated:Connect(function() -- «Запомнить»: начать запись маршрута
		if Home.rec then
			toast("Сначала сохрани или отмени текущую запись", C.warn)
			return
		end
		Home.ui.setOpen(false)
		if buildMode then
			setBuildMode(false)
		end
		Home.startRecord(i)
	end)
	c.play.Activated:Connect(function() -- «Отправить»: жители идут по маршруту
		Home.sendRoute(i)
	end)
	c.trash.Activated:Connect(function() -- «Очистить» (нужно нажать дважды)
		if (Home.rec and Home.rec.slot == i) or #Home.routes[i].pts == 0 then
			return
		end
		if not c.armed then
			c.armed = true
			Home.ui.refresh()
			toast("Нажми ещё раз: маршрут " .. i .. " будет очищен", C.warn)
			task.delay(2.5, function()
				if c.armed then
					c.armed = false
					Home.ui.refresh()
				end
			end)
			return
		end
		c.armed = false
		Home.routes[i] = { name = "Маршрут " .. i, pts = {} }
		Home.ui.refresh()
		markDirty()
		toast("Маршрут " .. i .. " очищен", C.bad)
	end)
end
Home.ui.recSave.Activated:Connect(function() -- «Сохранить» записанный маршрут
	if Home.stopRecord(true) then
		markDirty()
	end
end)
Home.ui.recCancel.Activated:Connect(function() -- «Отмена»: не сохранять
	Home.stopRecord(false)
	toast("Запись отменена", C.sub)
end)

-- ===== Ввод =====
local TOOL_KEYS = {
	[Enum.KeyCode.One] = "straight",
	[Enum.KeyCode.Two] = "curve",
	[Enum.KeyCode.Three] = "ramp",
	[Enum.KeyCode.Four] = "erase",
	[Enum.KeyCode.Five] = "cart",
	[Enum.KeyCode.Six] = "sign",
	[Enum.KeyCode.Seven] = "edit",
	[Enum.KeyCode.Eight] = "loop",
}

UserInputService.LastInputTypeChanged:Connect(function(t)
	lastInputTouch = (t == Enum.UserInputType.Touch)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	local back = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 1
	if t == Enum.UserInputType.Touch then
		touchPos = input.Position -- на телефоне тап двигает призрак, ставим кнопкой в панели
	elseif t == Enum.UserInputType.MouseButton1 then
		if buildMode then
			holding = isHoldTool(tool)
			doAction(false)
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		if buildMode and isPlacing(tool) then
			rotate(back)
		end
	elseif input.KeyCode == Enum.KeyCode.T then
		if buildMode and Decor.railTool(tool) then
			FM.tilt("pitch", back)
		end
	elseif input.KeyCode == Enum.KeyCode.Y then
		if buildMode and Decor.railTool(tool) then
			FM.tilt("roll", back)
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		if buildMode and FM.on and Decor.railTool(tool) then
			FM.flip = not FM.flip
			refreshFreeButtons()
		end
	elseif input.KeyCode == Enum.KeyCode.M then
		if buildMode and FM.on and not Decor.open then
			FM.toggleMagnet()
		end
	elseif input.KeyCode == Enum.KeyCode.N then
		if buildMode and FM.on and not Decor.open then
			FM.cycleStep()
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		if buildMode and not Decor.open then
			setFreeMode(not FM.on)
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		if buildMode and isPlacing(tool) then
			setLevel(level + 1)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		if buildMode and isPlacing(tool) then
			setLevel(level - 1)
		end
	elseif input.KeyCode == Enum.KeyCode.G then
		if buildMode and isPlacing(tool) then
			setLevel(0)
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		if data and Loading.uiReady then -- пока идут загрузка и появление панелей, строить нельзя
			setBuildMode(not buildMode)
		end
	elseif input.KeyCode == Enum.KeyCode.Nine then
		if buildMode then
			Decor.setOpen(not Decor.open)
		end
	elseif TOOL_KEYS[input.KeyCode] and buildMode then
		local name = TOOL_KEYS[input.KeyCode]
		if name ~= "loop" or FM.on then
			if Decor.open then
				Decor.setOpen(false) -- выбрал другой инструмент — панель украшений закрываем
			end
			setTool(name)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	if cart and cart.riding then
		setRiding(false)
	end
end)

player.CharacterRemoving:Connect(function()
	if cart and cart.riding then
		cart.riding = false
		refreshCartHud()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if Home.needSave then
		Home.needSave = false
		markDirty() -- маршрут сохранился сам (дошёл до предельной длины)
	end
	if Decor.open then
		Decor.spin(dt) -- модели в карточках крутятся
	end
	if buildMode then
		if tool == "erase" or tool == "cart" or tool == "edit" then
			updateHover()
		elseif ghost then
			updateGhost(dt)
		end
		if holding then
			doAction(true)
		end
	end
	stepCart(dt)
	FX.update(dt)
end)

-- ===== Старт: загрузка сохранения (если есть серверный скрипт) =====
-- Всё грузится, пока идёт экран загрузки; панели появляются, когда он закончился.
task.spawn(function()
	local fn = ReplicatedStorage:WaitForChild("RailSaveFunction", 5)
	local raw
	if fn then
		local ok, res = pcall(function()
			return fn:InvokeServer("Load")
		end)
		if ok then
			saveFn = fn
			raw = res
		end
	end

	data = normalize(raw)
	saveState = saveFn and "saved" or "off"
	buildSlotCards()
	refreshSlots()

	loadRails(data.slots[data.active].rails)
	busy = false
	refreshSlots()

	-- ждём конец экрана загрузки
	while not Loading.done do
		task.wait(0.1)
	end

	-- 1) карточка игрока падает сверху: аватарка скина, ник и регион
	Profile.drop()
	task.wait(0.3)

	-- 2) появляются панели; карточка остаётся перед ними (она выше по слоям)
	pill.Position = UDim2.new(0.5, 0, 0, -70)
	pill.Visible = true
	tween(pill, 0.5, { Position = UDim2.new(0.5, 0, 0, 10) }, Enum.EasingStyle.Back)
	dock.Position = UDim2.new(0.5, 0, 1, 90)
	dock.Visible = true
	tween(dock, 0.5, { Position = UDim2.new(0.5, 0, 1, -14) }, Enum.EasingStyle.Back)
	Loading.uiReady = true

	-- 3) карточка висит ещё немного, потом уезжает в угол
	task.wait(Profile.HOLD)
	Profile.settle()
end)
