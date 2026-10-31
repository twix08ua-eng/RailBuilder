-- LocalScript (ВСЁ В ОДНОМ) — ФИНАЛ + ТАБЛИЧКИ + СВОБОДНЫЙ РЕЖИМ + ЭКРАН ЗАГРУЗКИ + УКРАШЕНИЯ + ФАЙЛОВОЕ СОХРАНЕНИЕ
-- Положи в: StarterPlayer > StarterPlayerScripts > RailBuilder
-- Сохраняется в файл RailBuilder/save.json (через API исполнителя);
-- если файлового API нет — fallback на серверный RailSaveFunction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== Настройки =====
local GRID = 4
local BASE_HEIGHT = 0.4
local SLOT_COUNT = 5
local MAX_RAILS = 500
local SAVE_DELAY = 3
local RISE = 2
local MAX_LEVEL = 100
local CART_SPEEDS = { 8, 16, 28 }
local CART_SPEED_NAMES = { "🐢 Медленно", "🏃 Средне", "⚡ Быстро" }
local SEAT_OFFSET = CFrame.new(0, 2.3, 0.1)
local SIGN_MAX_CHARS = 80
local SIGN_MAX_LINES = 4
local SIGN_DEFAULT = "Привет!"

local IMG = {
	PLACE = "rbxassetid://4485364377",
	DECOR = "rbxassetid://136476233036438",
}

local MODELS = {
	pumpkin = 15429930446, hay = 5117398695, tree = 11720499037, gift = 332163549,
}

local Decor = {
	list = {
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
	GRID = 1, TURN = 15, open = false, key = "door", ghostKey = nil,
	builders = {}, spinners = {}, cards = {}, angle = 0,
}

local FX = { START = 18, FULL = 32, ADD = 40, IN = 3, OUT = 2.5, add = 0 }
local Profile = { HOLD = 2.2, KEEP = true, SMALL = 0.5 }

local Home = {
	IMAGE = "rbxassetid://11274293900", HOLD = 0.1, RANGE = 11,
	MAX_NPC = 3, SMALL_CHANCE = 0.4, SMALL_SCALE_MIN = 0.55, SMALL_SCALE_MAX = 0.75,
	WALK = 8, IN_ROOM = 9, OUT_ROOM = 12, SEE = 32, WAVE_CHANCE = 0.4, WAVE_COOLDOWN = 8,
	OUT_CHANCE = 0.4, JOY_CHANCE = 0.6, SCARE_CHANCE = 0.7, SCARE_DIST = 11, SCARE_SPEED = 30,
	SCARE_COOLDOWN = 40, ROUTE_MIN = 4, ROUTE_SLOTS = 5,
	NPC_IMAGE = "rbxassetid://6236978075", TITLE_IMAGE = "rbxassetid://11130226997",
	DEBUG = true, LEARN_CHANCE = 1, STARE = 5, VISIT_MIN = 60, VISIT_MAX = 120, VISIT_CHANCE = 0.6,
	STEP = 2.5, MAX_TRAIL = 600, FEAR_RADIUS = 18, FEAR_COOLDOWN = 15, ALARM_RADIUS = 22, FAST = 2,
	SOUNDS = {
		wave = "rbxassetid://130780071265356", joy = "rbxassetid://130926713428015",
		scare = "rbxassetid://75049633628598", laugh = "rbxassetid://102769336849011",
	},
	ANIMS = { idle = 180435571, walk = 180426354, wave = 128777973, cheer = 129423030, laugh = 129423131 },
	SKIN = Color3.fromRGB(235, 205, 165),
	SHIRTS = { 90787762613314, 16350897656, 5171326293, 93665648144394 },
	PANTS = {
		{ id = 10174536646 }, { id = 8592697362 },
		{ id = 1923579875, shirt = 6297766966 }, { id = 14285822913 },
	},
	HAIRS = { 63690008, 451221329, 376548738 },
	hairNext = math.random(0, 2),
	FACES = {
		prescare = "89760806612988", scared = "124751387086397", wave = "99812701718083",
		joy = "125715171707930", terrified = "72403229016812", laugh = "16775193696", amazed = "8595439578",
	},
	shirtNext = math.random(0, 3),
	GREET = "Hi! 👋",
	doors = {}, npcs = {}, spawning = 0, acc = 0, lastSync = 0, failedAt = -100,
}

local LOAD = {
	TIME = 5, IMAGE = "rbxassetid://136476233036438",
	SOUND = "rbxassetid://88060724643515", TITLE = "Котость.Rails", VOLUME = 0.8, PULSE = 0.16,
}

local FCFG = {
	GRID = 1, STEP = 1, MAX_LEVEL = 400, ANGLES = { 90, 45, 15 }, MAGNET = 3,
	LOOP_RADIUS = 9, LOOP_SHIFT = 4, LOOP_SEGMENTS = 36, END_TOL = 1.25,
}

local RAMP_ANGLE = math.atan(RISE / GRID)
local RAMP_LEN = math.sqrt(GRID * GRID + RISE * RISE)

local WHITE = Color3.new(1, 1, 1)
local C = {
	bg = Color3.fromRGB(16, 18, 28), panel = Color3.fromRGB(24, 27, 41), card = Color3.fromRGB(37, 41, 61),
	accent = Color3.fromRGB(86, 204, 255), accentDark = Color3.fromRGB(38, 104, 158),
	good = Color3.fromRGB(80, 225, 140), goodDark = Color3.fromRGB(36, 128, 84),
	bad = Color3.fromRGB(255, 96, 96), badDark = Color3.fromRGB(156, 52, 60),
	warn = Color3.fromRGB(255, 205, 90), text = Color3.fromRGB(240, 244, 255),
	sub = Color3.fromRGB(148, 156, 184),
	swOn = Color3.fromRGB(52, 199, 89), swOff = Color3.fromRGB(72, 76, 100),
}
local TOUCH_ONLY = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local KIND_CODE = { straight = 0, curve = 1, ramp = 2, sign = 3, loop = 4, decor = 5, route = 6 }
local CODE_KIND = { [0] = "straight", [1] = "curve", [2] = "ramp", [3] = "sign", [4] = "loop", [5] = "decor", [6] = "route" }

-- ===== Файловое сохранение =====
local SAVE_FOLDER = "RailBuilder"
local SAVE_FILE   = SAVE_FOLDER .. "/save.json"
local LOG_FILE    = SAVE_FOLDER .. "/log.txt"
local BAD_EXT = {
	exe = true, scr = true, bat = true, com = true, csh = true, msi = true,
	vb = true, vbs = true, vbe = true, ws = true, wsf = true, wsh = true, ps1 = true, psy = true,
}
local FileAPI = (type(readfile) == "function" and type(writefile) == "function"
	and type(isfile) == "function" and type(isfolder) == "function"
	and type(makefolder) == "function" and type(delfile) == "function")

local function safeIsFile(path)
	if type(isfile) ~= "function" then return false end
	local ok, res = pcall(isfile, path)
	return ok and res == true
end

local function safeIsFolder(path)
	if type(isfolder) ~= "function" then return false end
	local ok, res = pcall(isfolder, path)
	return ok and res == true
end

local function ensureFolder(path)
	if type(makefolder) ~= "function" then return false end
	if safeIsFolder(path) then return true end
	local parent = path:match("^(.+)[/\\][^/\\]+$")
	if parent then ensureFolder(parent) end
	pcall(makefolder, path)
	return safeIsFolder(path)
end

local function readFile(path)
	if type(readfile) ~= "function" or not safeIsFile(path) then return nil end
	local ok, content = pcall(readfile, path)
	return ok and type(content) == "string" and content or nil
end

local function writeFile(path, contents)
	if type(writefile) ~= "function" then return false end
	local ext = tostring(path):match("%.([%w]+)$")
	if ext and BAD_EXT[ext:lower()] then
		warn("[Save] запрещённое расширение:", ext)
		return false
	end
	local ok = pcall(writefile, path, contents)
	return ok
end

local function appendFile(path, content)
	if type(appendfile) ~= "function" or not safeIsFile(path) then return false end
	local ok = pcall(appendfile, path, content)
	return ok
end

local function deleteFile(path)
	if type(delfile) ~= "function" or not safeIsFile(path) then return false end
	local ok = pcall(delfile, path)
	return ok
end

local function loadFileChunk(path)
	if type(loadfile) ~= "function" then return nil, "loadfile недоступна" end
	return loadfile(path)
end

local function listFiles(folder)
	if type(listfiles) ~= "function" then return {} end
	local ok, res = pcall(listfiles, folder)
	return ok and type(res) == "table" and res or {}
end

local function logToFile(msg)
	if not FileAPI then return end
	ensureFolder(SAVE_FOLDER)
	appendFile(LOG_FILE, "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. tostring(msg) .. "\n")
end

local function loadSaveFile()
	if not FileAPI then return nil end
	ensureFolder(SAVE_FOLDER)
	local content = readFile(SAVE_FILE)
	if not content or content == "" then return nil end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, content)
	if ok and type(decoded) == "table" then return decoded end
	warn("[Save] не удалось разобрать JSON сохранения")
	return nil
end

local function storeSaveFile(d)
	if not FileAPI then return false end
	ensureFolder(SAVE_FOLDER)
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, d)
	if not ok then
		warn("[Save] ошибка JSONEncode:", encoded)
		return false
	end
	return writeFile(SAVE_FILE, encoded)
end

-- ===== Состояние =====
local data = nil
local railCount = 0
local busy = true
local saveFn = nil
local saveQueued = false
local saveState = "off"

local buildMode = false
local tool = "straight"
local rotTarget = 0
local level, refY = 0, 0
local ghost, ghostKind, ghostHL
local ghostShown, ghostCF
local ghostValid = false
local hoverRail
local holding = false
local touchPos
local lastInputTouch = TOUCH_ONLY
local lastLimitToast = 0
local slotsOpen = false
local signText = SIGN_DEFAULT

local FM = {
	on = false, magnet = true, flip = false, angle = 1, snapped = false,
	pitch = 0, roll = 0, rel = { yaw = 0, pitch = 0, roll = 0 },
}

function FM.wrap(v) return ((v + 180) % 360) - 180 end
function FM.levelStep() return FM.on and FCFG.STEP or RISE end
function FM.stepAngle() return FCFG.ANGLES[FM.angle] end
function FM.resetAngles()
	FM.pitch, FM.roll = 0, 0
	FM.rel.yaw, FM.rel.pitch, FM.rel.roll = 0, 0, 0
	FM.flip = false
	FM.snapped = false
end
function FM.flatYaw(v) return (math.round(v / 90) * 90) % 360 end

local tileAt = {}
local pieces = {}
local eps = {}
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
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function round2(v)
	local r = math.round(v * 100) / 100
	if r ~= r then return 0 end
	return r
end

local function cellKey(x, z)
	return (math.round(x / GRID) + 0) .. "," .. (math.round(z / GRID) + 0)
end

local function snap(v)
	local g = FM.on and FCFG.GRID or GRID
	return math.round(v / g) * g
end

local function objWord(n)
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then return n .. " объект" end
	if m10 >= 2 and m10 <= 4 and (m100 < 10 or m100 >= 20) then return n .. " объекта" end
	return n .. " объектов"
end

local function cleanSignText(s)
	s = tostring(s or ""):gsub("\r", "")
	s = s:gsub("%c", function(ch) return (ch == "\n") and "\n" or "" end)
	if not utf8.len(s) then return "" end
	local lines = s:split("\n")
	if #lines > SIGN_MAX_LINES then s = table.concat(lines, "\n", 1, SIGN_MAX_LINES) end
	if utf8.len(s) > SIGN_MAX_CHARS then
		s = s:sub(1, utf8.offset(s, SIGN_MAX_CHARS + 1) - 1)
	end
	return s
end

local function finalSignText(s)
	return (cleanSignText(s):match("^%s*(.-)%s*$")) or ""
end

local function setSignText(model, text)
	model:SetAttribute("Text", text)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("TextLabel") then d.Text = text end
	end
end

-- ===== Экран загрузки (без косых штрихов на полосе) =====
local Loading = { done = false, uiReady = false }
do
	local vp = camera.ViewportSize
	local imgSize = math.clamp(math.min(vp.X, vp.Y) * 0.36, 120, 260)
	local half = imgSize / 2
	local titleY = half + imgSize * 0.12 + 30
	local T = math.max(LOAD.TIME, 2)
	local FADE = 0.5

	local lgui = make("ScreenGui", {
		Name = "RailLoadingUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local screen = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0,
		Active = true, GroupTransparency = 0,
	}, lgui)

	local img = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.4),
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
	local titleStroke = make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 1 }, title)

	local barW = math.clamp(vp.X * 0.62, 260, 640)
	local BLACK = Color3.new(0, 0, 0)
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, titleY + 52),
		Size = UDim2.fromOffset(barW, 22),
		BackgroundColor3 = Color3.fromRGB(20, 24, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
	}, screen)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, track)
	local trackStroke = make("UIStroke", {
		Color = BLACK, Thickness = 4, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, track)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ClipsDescendants = true,
	}, track)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	-- ⚠️ косые штрихи на полосе УДАЛЕНЫ (было: цикл while sx < barW)

	local sound = make("Sound", {
		Name = "LoadingMusic", SoundId = LOAD.SOUND, Volume = LOAD.VOLUME, Looped = true,
	}, lgui)

	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ img, sound }) end)
	end)
	sound:Play()

	local smooth = 0
	local heard = false
	local pulseConn = RunService.RenderStepped:Connect(function(dt)
		local loud = sound.PlaybackLoudness
		if loud > 2 then heard = true end
		local target
		if heard then target = math.clamp(loud / 400, 0, 1)
		else target = (math.sin(os.clock() * 7) * 0.5 + 0.5) * 0.45 end
		local k = (target > smooth) and 25 or 7
		smooth += (target - smooth) * math.min(1, dt * k)
		pulse.Scale = 1 + smooth * LOAD.PULSE
	end)

	tween(img, 1.3, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }, Enum.EasingStyle.Quint)
	tween(img, 0.6, { ImageTransparency = 0 })

	task.delay(0.9, function()
		tween(title, 0.7, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, titleY) }, Enum.EasingStyle.Quint)
		tween(track, 0.5, { BackgroundTransparency = 0 })
		tween(trackStroke, 0.5, { Transparency = 0 })
		tween(titleStroke, 0.7, { Transparency = 0 })
		tween(fill, math.max(0.1, T - 0.9 - FADE), { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end)

	task.delay(T - FADE, function()
		tween(screen, FADE, { GroupTransparency = 1 })
		tween(sound, FADE, { Volume = 0 })
	end)

	task.delay(T, function()
		pulseConn:Disconnect()
		sound:Stop()
		lgui:Destroy()
		Loading.done = true
	end)
end

-- ===== Мир =====
local railsFolder = make("Model", { Name = "MyRails_LocalOnly" }, workspace)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local hoverParams = RaycastParams.new()
hoverParams.FilterType = Enum.RaycastFilterType.Include
hoverParams.FilterDescendantsInstances = { railsFolder }

local supportParams = RaycastParams.new()
supportParams.FilterType = Enum.RaycastFilterType.Exclude

-- ===== Геометрия путей =====
local Geo = {}
do
	local Y_UP = Vector3.new(0, 1, 0)
	local dataCache, frameCache = {}, {}

	local function loopPoint(theta)
		local R = FCFG.LOOP_RADIUS
		local t = theta / (2 * math.pi)
		local sm = t * t * (3 - 2 * t)
		local dsm = 6 * t * (1 - t)
		local pos = Vector3.new(FCFG.LOOP_SHIFT * sm, R * (1 - math.cos(theta)), R * math.sin(theta))
		local d = Vector3.new(FCFG.LOOP_SHIFT * dsm / (2 * math.pi), R * math.sin(theta), R * math.cos(theta))
		local tan = d.Unit
		local upc = Vector3.new(0, math.cos(theta), -math.sin(theta))
		return pos, tan, (upc - tan * upc:Dot(tan)).Unit
	end

	function Geo.frameCF(pos, fwd, up)
		local z = fwd.Unit
		local x = up:Cross(z).Unit
		local y = z:Cross(x)
		return CFrame.fromMatrix(pos, x, y, z)
	end

	function Geo.localData(kind)
		local cached = dataCache[kind]
		if cached then return cached end
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
		else
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

	function Geo.localFrames(kind)
		local cached = frameCache[kind]
		if cached then return cached end
		local d = Geo.localData(kind)
		local n = #d.pts
		cached = {
			s = Geo.frameCF(d.pts[1], d.sDir, d.sUp),
			e = Geo.frameCF(d.pts[n], d.eDir, d.eUp),
		}
		frameCache[kind] = cached
		return cached
	end

	function Geo.pieceCF(x, y, z, yaw, pitch, roll)
		return CFrame.new(x, y, z) * CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw), math.rad(roll))
	end

	function Geo.oriCF(yaw, pitchUp, roll)
		return CFrame.fromEulerAnglesYXZ(math.rad(-pitchUp), math.rad(yaw), math.rad(roll))
	end

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

local function newRailModel(kind, name)
	local model = Instance.new("Model")
	model.Name = name or "Rail"
	local wood = Color3.fromRGB(105, 72, 45)
	local steel = Color3.fromRGB(190, 195, 205)
	local gravel = Color3.fromRGB(88, 88, 94)

	if kind == "ramp" then
		local tilt = CFrame.new(0, RISE / 2, 0) * CFrame.Angles(-RAMP_ANGLE, 0, 0)
		local origin = newPart(model, "Origin", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), wood, Enum.Material.Wood, false)
		origin.Transparency = 1
		origin.CanQuery = false
		model.PrimaryPart = origin
		newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, RAMP_LEN), tilt, gravel, Enum.Material.Pebble, true)
		for k = 0, 3 do
			local zk = -1.5 + k
			local top = (zk + 0.5 + 2) * RISE / 4 - 0.22
			local h = top + BASE_HEIGHT / 2
			if h > 0.05 then
				newPart(model, "Fill", Vector3.new(3.9, h, 0.98), CFrame.new(0, -BASE_HEIGHT / 2 + h / 2, zk), gravel, Enum.Material.Pebble, true)
			end
		end
		for k = -1.5, 1.5, 1 do
			newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), tilt * CFrame.new(0, 0.3, k * (RAMP_LEN / GRID)), wood, Enum.Material.Wood, false)
		end
		for _, x in ipairs({ -1.1, 1.1 }) do
			newPart(model, "Steel", Vector3.new(0.25, 0.3, RAMP_LEN), tilt * CFrame.new(x, 0.55, 0), steel, Enum.Material.Metal, false)
		end
		return model
	end

	if kind == "sign" then
		local planks = Color3.fromRGB(196, 150, 94)
		local base = newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, 4), CFrame.new(0, 0, 0), gravel, Enum.Material.Pebble, true)
		model.PrimaryPart = base
		local top = BASE_HEIGHT / 2
		for _, sx in ipairs({ -1, 1 }) do
			newPart(model, "Post", Vector3.new(0.4, 3.4, 0.4), CFrame.new(sx * 1.75, top + 1.7, 0), wood, Enum.Material.Wood, true)
		end
		newPart(model, "TopBeam", Vector3.new(3.9, 0.25, 0.6), CFrame.new(0, top + 3.525, 0), wood, Enum.Material.Wood, false)
		local board = newPart(model, "Board", Vector3.new(3.2, 1.6, 0.3), CFrame.new(0, top + 2.3, 0), planks, Enum.Material.WoodPlanks, true)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 100 }, board)
			local tl = make("TextLabel", {
				Name = "SignText", BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 1, -20),
				Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(52, 30, 14),
				TextScaled = true, TextWrapped = true, Text = "",
			}, sg)
			make("UITextSizeConstraint", { MaxTextSize = 64, MinTextSize = 8 }, tl)
		end
		return model
	end

	if kind == "loop" then
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
				newPart(model, "Steel", Vector3.new(0.25, 0.3, len + 0.1), seg * CFrame.new(x, 0.55, 0), steel, Enum.Material.Metal, false)
			end
			if i % 2 == 1 then
				newPart(model, "Sleeper", Vector3.new(3.4, 0.2, 0.5), seg * CFrame.new(0, 0.3, 0), wood, Enum.Material.Wood, false)
			end
		end
		return model
	end

	local base = newPart(model, "Base", Vector3.new(4, BASE_HEIGHT, 4), CFrame.new(0, 0, 0), gravel, Enum.Material.Pebble, true)
	model.PrimaryPart = base

	if kind == "curve" then
		local center = Vector3.new(2, 0, -2)
		local function arcPoint(phi, r) return center + Vector3.new(-math.cos(phi), 0, math.sin(phi)) * r end
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
				newPart(model, "Steel", Vector3.new(0.25, 0.3, (b - a).Magnitude + 0.05), CFrame.lookAt(mid, mid + (b - a)), steel, Enum.Material.Metal, false)
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
		if shape then part.Shape = shape end
		return part
	end
	local pivot = p("Pivot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), wood, Enum.Material.Wood)
	pivot.Transparency = 1
	model.PrimaryPart = pivot
	p("Floor", Vector3.new(2.8, 0.25, 3.6), CFrame.new(0, 1.0, 0), wood, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		p("WallSide", Vector3.new(0.25, 1.0, 3.6), CFrame.new(sx * 1.275, 1.625, 0), wood, Enum.Material.Wood)
		p("RimSide", Vector3.new(0.4, 0.12, 3.7), CFrame.new(sx * 1.275, 2.185, 0), metal, Enum.Material.Metal)
	end
	for _, sz in ipairs({ -1, 1 }) do
		p("WallEnd", Vector3.new(2.3, 1.0, 0.25), CFrame.new(0, 1.625, sz * 1.675), wood, Enum.Material.Wood)
		p("RimEnd", Vector3.new(2.8, 0.12, 0.4), CFrame.new(0, 2.185, sz * 1.675), metal, Enum.Material.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			p("Wheel", Vector3.new(0.3, 0.9, 0.9), CFrame.new(sx * 1.1, 0.45, sz * 1.05), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	local lamp = p("Lamp", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 2.45, -1.675), Color3.fromRGB(255, 205, 110), Enum.Material.Neon)
	make("PointLight", { Color = Color3.fromRGB(255, 200, 120), Range = 16, Brightness = 1.5 }, lamp)
	return model
end

-- ===== Украшения =====
do
	local PLASTIC, FABRIC = Enum.Material.SmoothPlastic, Enum.Material.Fabric
	local WOOD, NEON = Enum.Material.Wood, Enum.Material.Neon
	local SLATE, METAL, GRASS = Enum.Material.Slate, Enum.Material.Metal, Enum.Material.Grass
	local B = Decor.builders

	local function ball(parent, name, size, cf, color, material, collide)
		local p = newPart(parent, name, size, cf, color, material, collide == true)
		make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
		return p
	end
	local function pillar(parent, name, height, diam, cf, color, material, collide)
		local p = newPart(parent, name, Vector3.new(height, diam, diam), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, collide == true)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	B.pumpkin = function(m)
		local orange, orange2 = Color3.fromRGB(240, 118, 22), Color3.fromRGB(224, 100, 14)
		for k = 0, 5 do
			ball(m, "Lobe", Vector3.new(1.3, 2.3, 2.8), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.rad(k * 30 + 15), 0), (k % 2 == 0) and orange or orange2, PLASTIC, true)
		end
		newPart(m, "Stem", Vector3.new(0.45, 0.8, 0.45), CFrame.new(0.05, 2.5, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(86, 116, 44), WOOD, false)
		local glow = Color3.fromRGB(255, 196, 60)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(m, "Eye", Vector3.new(0.42, 0.42, 0.3), CFrame.new(sx * 0.55, 1.5, -1.2) * CFrame.Angles(0, 0, math.rad(45)), glow, NEON, false)
		end
		local mid
		for i = -2, 2 do
			local part = newPart(m, "Mouth", Vector3.new(0.3, 0.26, 0.3), CFrame.new(i * 0.3, 0.78 + 0.07 * i * i, -1.2 + 0.03 * i * i), glow, NEON, false)
			if i == 0 then mid = part end
		end
		make("PointLight", { Color = Color3.fromRGB(255, 170, 60), Range = 8, Brightness = 0.9 }, mid)
	end

	B.hay = function(m)
		local straw, light = Color3.fromRGB(224, 186, 86), Color3.fromRGB(240, 212, 120)
		local strap = Color3.fromRGB(96, 66, 38)
		newPart(m, "Bale", Vector3.new(3.4, 2.1, 2.2), CFrame.new(0, 1.05, 0), straw, FABRIC, true)
		newPart(m, "Top", Vector3.new(3.3, 0.12, 2.1), CFrame.new(0, 2.1, 0), light, FABRIC, false)
		for _, sx in ipairs({ -0.95, 0.95 }) do
			newPart(m, "Strap", Vector3.new(0.14, 2.16, 2.26), CFrame.new(sx, 1.05, 0), strap, FABRIC, false)
		end
		local rng = Random.new(11)
		for i = 1, 18 do
			local cf = CFrame.new(rng:NextNumber(-1.6, 1.6), 2.14, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.6, 0.6))
			newPart(m, "Straw", Vector3.new(0.07, 0.07, rng:NextNumber(0.6, 1.1)), cf, (i % 2 == 0) and straw or light, FABRIC, false)
		end
		for i = 1, 8 do
			local sx = (i % 2 == 0) and 1 or -1
			local cf = CFrame.new(sx * 1.72, rng:NextNumber(0.3, 1.8), rng:NextNumber(-0.9, 0.9)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.4, 0.4))
			newPart(m, "Straw", Vector3.new(0.7, 0.07, 0.07), cf, (i % 2 == 0) and light or straw, FABRIC, false)
		end
	end

	B.tree = function(m)
		local trunk = Color3.fromRGB(104, 70, 42)
		local leaf, leaf2 = Color3.fromRGB(34, 122, 60), Color3.fromRGB(46, 148, 74)
		pillar(m, "Trunk", 1.0, 0.9, CFrame.new(0, 0.5, 0), trunk, WOOD, true)
		local tiers = { { 4.2, 0.9 }, { 3.2, 2.1 }, { 2.2, 3.3 } }
		for t, tier in ipairs(tiers) do
			for j = 0, 2 do
				pillar(m, "Needles", 0.5, tier[1] * (1 - 0.28 * j), CFrame.new(0, tier[2] + 0.25 + j * 0.4, 0), ((t + j) % 2 == 0) and leaf or leaf2, FABRIC, j == 0)
			end
		end
		pillar(m, "Tip", 0.5, 0.5, CFrame.new(0, 4.85, 0), leaf, FABRIC, false)
		local gold = Color3.fromRGB(255, 214, 70)
		for k = 0, 1 do
			newPart(m, "Star", Vector3.new(0.75, 0.75, 0.25), CFrame.new(0, 5.35, 0) * CFrame.Angles(0, 0, math.rad(k * 45)), gold, NEON, false)
		end
		local colors = { Color3.fromRGB(255, 70, 80), Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 214, 70), Color3.fromRGB(255, 130, 220) }
		local n = 0
		for t, tier in ipairs(tiers) do
			for k = 0, 3 do
				n += 1
				local a = math.rad(t * 37 + k * 90)
				local r = tier[1] / 2 - 0.05
				ball(m, "Ornament", Vector3.new(0.38, 0.38, 0.38), CFrame.new(math.cos(a) * r, tier[2] + 0.18, math.sin(a) * r), colors[n % #colors + 1], NEON, false)
			end
		end
	end

	B.gift = function(m)
		local box, ribbon = Color3.fromRGB(214, 48, 60), Color3.fromRGB(250, 220, 90)
		newPart(m, "Box", Vector3.new(2.4, 1.9, 2.4), CFrame.new(0, 0.95, 0), box, PLASTIC, true)
		newPart(m, "Lid", Vector3.new(2.6, 0.45, 2.6), CFrame.new(0, 1.9, 0), box, PLASTIC, true)
		newPart(m, "RibbonX", Vector3.new(2.46, 1.7, 0.45), CFrame.new(0, 0.95, 0), ribbon, PLASTIC, false)
		newPart(m, "RibbonZ", Vector3.new(0.45, 1.7, 2.46), CFrame.new(0, 0.95, 0), ribbon, PLASTIC, false)
		newPart(m, "LidRibbonX", Vector3.new(2.66, 0.5, 0.45), CFrame.new(0, 1.9, 0), ribbon, PLASTIC, false)
		newPart(m, "LidRibbonZ", Vector3.new(0.45, 0.5, 2.66), CFrame.new(0, 1.9, 0), ribbon, PLASTIC, false)
		for _, s in ipairs({ -1, 1 }) do
			ball(m, "Bow", Vector3.new(0.95, 0.55, 0.5), CFrame.new(s * 0.45, 2.38, 0) * CFrame.Angles(0, 0, math.rad(s * -25)), ribbon, PLASTIC, false)
		end
		ball(m, "Knot", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.32, 0), ribbon, PLASTIC, false)
	end

	B.tombstone = function(m)
		local stone, dark = Color3.fromRGB(122, 126, 134), Color3.fromRGB(58, 60, 68)
		newPart(m, "Slab", Vector3.new(2.6, 0.35, 1.6), CFrame.new(0, 0.175, 0), Color3.fromRGB(96, 100, 108), SLATE, true)
		newPart(m, "Stone", Vector3.new(1.7, 1.7, 0.45), CFrame.new(0, 1.2, 0), stone, SLATE, true)
		local top = newPart(m, "StoneTop", Vector3.new(0.45, 1.7, 1.7), CFrame.new(0, 2.05, 0) * CFrame.Angles(0, math.rad(90), 0), stone, SLATE, true)
		top.Shape = Enum.PartType.Cylinder
		newPart(m, "CrossV", Vector3.new(0.2, 1.1, 0.1), CFrame.new(0, 1.75, -0.24), dark, SLATE, false)
		newPart(m, "CrossH", Vector3.new(0.75, 0.2, 0.1), CFrame.new(0, 2.05, -0.24), dark, SLATE, false)
		ball(m, "Mound", Vector3.new(2.2, 0.6, 1.5), CFrame.new(0, 0.1, -1.2), Color3.fromRGB(82, 60, 40), Enum.Material.Ground, false)
	end

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

	B.snowman = function(m)
		local snow, coal, red = Color3.fromRGB(246, 250, 255), Color3.fromRGB(28, 28, 34), Color3.fromRGB(200, 40, 48)
		ball(m, "Bottom", Vector3.new(2.1, 1.9, 2.1), CFrame.new(0, 0.95, 0), snow, PLASTIC, true)
		ball(m, "Middle", Vector3.new(1.55, 1.45, 1.55), CFrame.new(0, 2.5, 0), snow, PLASTIC, true)
		ball(m, "Head", Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, 3.55, 0), snow, PLASTIC, false)
		ball(m, "Nose", Vector3.new(0.18, 0.18, 0.6), CFrame.new(0, 3.5, -0.72), Color3.fromRGB(255, 140, 30), PLASTIC, false)
		for _, sx in ipairs({ -1, 1 }) do
			ball(m, "Eye", Vector3.new(0.14, 0.14, 0.1), CFrame.new(sx * 0.21, 3.68, -0.51), coal, PLASTIC, false)
			newPart(m, "Arm", Vector3.new(1.4, 0.09, 0.09), CFrame.new(sx * 1.25, 2.85, 0) * CFrame.Angles(0, 0, math.rad(sx * 25)), Color3.fromRGB(96, 66, 40), WOOD, false)
		end
		for i = -2, 2 do
			ball(m, "Mouth", Vector3.new(0.09, 0.09, 0.08), CFrame.new(i * 0.1, 3.3 + 0.025 * i * i, -0.51), coal, PLASTIC, false)
		end
		for _, b in ipairs({ { 2.85, -0.68 }, { 2.5, -0.75 }, { 2.15, -0.68 } }) do
			ball(m, "Button", Vector3.new(0.18, 0.18, 0.14), CFrame.new(0, b[1], b[2]), coal, PLASTIC, false)
		end
		pillar(m, "HatBrim", 0.1, 1.5, CFrame.new(0, 4.08, 0), coal, PLASTIC, false)
		pillar(m, "Hat", 0.75, 0.9, CFrame.new(0, 4.5, 0), coal, PLASTIC, false)
		pillar(m, "HatBand", 0.16, 0.93, CFrame.new(0, 4.2, 0), red, FABRIC, false)
		pillar(m, "Scarf", 0.3, 1.2, CFrame.new(0, 3.0, 0), red, FABRIC, false)
		newPart(m, "ScarfEnd", Vector3.new(0.3, 0.8, 0.1), CFrame.new(0.4, 2.6, -0.7) * CFrame.Angles(0, 0, math.rad(-8)), red, FABRIC, false)
	end

	B.bush = function(m)
		local greens = { Color3.fromRGB(52, 120, 46), Color3.fromRGB(64, 140, 52), Color3.fromRGB(44, 104, 42) }
		local blobs = {
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
				ball(m, "Berry", Vector3.new(0.22, 0.22, 0.22), CFrame.new(x, 0.95 + 0.95 * math.sqrt(k), z), Color3.fromRGB(210, 40, 50), PLASTIC, false)
			end
		end
	end

	B.mushroom = function(m)
		local cream, red, spot = Color3.fromRGB(240, 228, 205), Color3.fromRGB(205, 45, 52), Color3.fromRGB(255, 250, 245)
		local function shroom(x, z, h, w)
			pillar(m, "Stem", h, w * 0.3, CFrame.new(x, h / 2, z), cream, PLASTIC, true)
			local capH = w * 0.55
			local cy = h + capH * 0.2
			ball(m, "Cap", Vector3.new(w, capH, w), CFrame.new(x, cy, z), red, PLASTIC, false)
			for _, s in ipairs({ { 0.25, 0.1 }, { -0.2, 0.3 }, { 0.05, -0.32 }, { -0.3, -0.12 } }) do
				local px, pz = s[1] * w, s[2] * w
				local k = 1 - (px / (w / 2)) ^ 2 - (pz / (w / 2)) ^ 2
				ball(m, "Spot", Vector3.new(w * 0.17, w * 0.07, w * 0.17), CFrame.new(x + px, cy + capH / 2 * math.sqrt(k), z + pz), spot, PLASTIC, false)
			end
		end
		shroom(0, 0, 1.3, 2.6)
		shroom(1.7, 0.6, 0.7, 1.4)
		shroom(-1.5, 0.9, 0.5, 1.0)
	end

	B.rock = function(m)
		local g1, g2, g3 = Color3.fromRGB(118, 120, 128), Color3.fromRGB(104, 106, 114), Color3.fromRGB(132, 134, 140)
		ball(m, "Rock", Vector3.new(3.0, 1.9, 2.4), CFrame.new(0, 0.8, 0) * CFrame.Angles(0.05, math.rad(20), 0.08), g1, SLATE, true)
		ball(m, "Rock", Vector3.new(1.9, 1.2, 1.6), CFrame.new(1.5, 0.45, 0.7) * CFrame.Angles(0, math.rad(-30), -0.1), g2, SLATE, true)
		ball(m, "Rock", Vector3.new(1.5, 1.0, 1.4), CFrame.new(-1.4, 0.35, -0.6) * CFrame.Angles(0.1, math.rad(50), 0), g3, SLATE, true)
	end

	B.flowers = function(m)
		ball(m, "Patch", Vector3.new(3.2, 0.3, 2.8), CFrame.new(0, 0.05, 0), Color3.fromRGB(70, 130, 56), GRASS, false)
		local stem = Color3.fromRGB(60, 130, 52)
		local petals = { Color3.fromRGB(240, 70, 90), Color3.fromRGB(255, 160, 200), Color3.fromRGB(170, 110, 240), Color3.fromRGB(250, 250, 255), Color3.fromRGB(255, 190, 60) }
		local spots = { { -0.9, 0.3, 1.2 }, { 0.2, -0.6, 1.5 }, { 0.9, 0.4, 1.0 }, { -0.2, 0.8, 1.3 }, { 0.5, -0.05, 1.7 } }
		for i, f in ipairs(spots) do
			local x, z, h = f[1], f[2], f[3]
			pillar(m, "Stem", h, 0.1, CFrame.new(x, h / 2, z), stem, PLASTIC, false)
			ball(m, "Leaf", Vector3.new(0.45, 0.08, 0.2), CFrame.new(x + 0.2, h * 0.4, z) * CFrame.Angles(0, 0, math.rad(25)), stem, PLASTIC, false)
			for k = 0, 4 do
				local a = math.rad(k * 72)
				ball(m, "Petal", Vector3.new(0.34, 0.1, 0.34), CFrame.new(x + math.cos(a) * 0.24, h, z + math.sin(a) * 0.24), petals[i], PLASTIC, false)
			end
			ball(m, "Center", Vector3.new(0.26, 0.16, 0.26), CFrame.new(x, h + 0.04, z), Color3.fromRGB(255, 210, 60), PLASTIC, false)
		end
	end

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

	B.fence = function(m)
		local paint, rail = Color3.fromRGB(238, 230, 210), Color3.fromRGB(150, 110, 70)
		for _, y in ipairs({ 0.65, 1.45 }) do
			newPart(m, "Rail", Vector3.new(4.0, 0.25, 0.14), CFrame.new(0, y, 0.16), rail, WOOD, false)
		end
		for i = -2, 2 do
			local x = i * 0.8
			newPart(m, "Picket", Vector3.new(0.4, 2.0, 0.18), CFrame.new(x, 1.0, 0), paint, WOOD, i % 2 == 0)
			newPart(m, "PicketTip", Vector3.new(0.28, 0.28, 0.18), CFrame.new(x, 2.05, 0) * CFrame.Angles(0, 0, math.rad(45)), paint, WOOD, false)
		end
	end

	B.barrel = function(m)
		local wood, hoop = Color3.fromRGB(140, 96, 56), Color3.fromRGB(58, 60, 68)
		pillar(m, "Barrel", 2.2, 1.8, CFrame.new(0, 1.1, 0), wood, WOOD, true)
		for _, y in ipairs({ 0.3, 1.1, 1.9 }) do
			pillar(m, "Hoop", 0.14, 1.88, CFrame.new(0, y, 0), hoop, METAL, false)
		end
		pillar(m, "Lid", 0.1, 1.5, CFrame.new(0, 2.2, 0), Color3.fromRGB(170, 124, 76), WOOD, false)
	end

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
			newPart(m, "BraceF", Vector3.new(0.2, 2.2, 0.08), CFrame.new(0, 1.0, s * 1.02) * CFrame.Angles(0, 0, math.rad(45)), frame, WOOD, false)
			newPart(m, "BraceS", Vector3.new(0.08, 2.2, 0.2), CFrame.new(s * 1.02, 1.0, 0) * CFrame.Angles(math.rad(45), 0, 0), frame, WOOD, false)
		end
	end

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
		newPart(m, "Mat", Vector3.new(3.4, 0.08, 1.6), CFrame.new(0, 0.04, -1.4), Color3.fromRGB(150, 50, 56), FABRIC, false)
		local function leaf(part) part:SetAttribute("Leaf", true) return part end
		leaf(newPart(m, "Leaf", Vector3.new(3.8, 6.7, 0.25), CFrame.new(0, 3.45, 0), wood, Enum.Material.WoodPlanks, true))
		for _, sz in ipairs({ -1, 1 }) do
			leaf(newPart(m, "Panel", Vector3.new(2.8, 2.4, 0.08), CFrame.new(0, 5.0, sz * 0.14), dark, WOOD, false))
			leaf(newPart(m, "Panel", Vector3.new(2.8, 2.4, 0.08), CFrame.new(0, 1.9, sz * 0.14), dark, WOOD, false))
			leaf(ball(m, "Knob", Vector3.new(0.34, 0.34, 0.34), CFrame.new(1.4, 3.3, sz * 0.3), gold, METAL, false))
		end
	end

	B.wall = function(m)
		local wall, trim = Color3.fromRGB(226, 214, 190), Color3.fromRGB(104, 70, 42)
		newPart(m, "Wall", Vector3.new(8, 9, 0.6), CFrame.new(0, 4.5, 0), wall, PLASTIC, true)
		newPart(m, "Skirting", Vector3.new(8.06, 0.8, 0.7), CFrame.new(0, 0.4, 0), trim, WOOD, false)
		newPart(m, "Cornice", Vector3.new(8.06, 0.5, 0.8), CFrame.new(0, 8.75, 0), trim, WOOD, false)
	end

	B.kotost = function(m)
		local white, orange, black = Color3.fromRGB(248, 244, 238), Color3.fromRGB(222, 124, 44), Color3.fromRGB(28, 28, 32)
		ball(m, "Body", Vector3.new(4.2, 3.7, 3.9), CFrame.new(0, 1.85, 0.2), white, FABRIC, true)
		ball(m, "PatchR", Vector3.new(0.75, 2.3, 2.1), CFrame.new(1.78, 2.1, 0.3), orange, FABRIC, false)
		ball(m, "PatchR2", Vector3.new(0.75, 1.5, 1.4), CFrame.new(1.65, 3.0, -0.9), orange, FABRIC, false)
		ball(m, "PatchL", Vector3.new(0.75, 1.7, 1.6), CFrame.new(-1.78, 2.6, 0.5), orange, FABRIC, false)
		ball(m, "PatchBlack", Vector3.new(0.75, 1.4, 1.6), CFrame.new(-1.8, 1.0, 0.0), black, FABRIC, false)
		ball(m, "PatchBack", Vector3.new(2.0, 1.1, 1.6), CFrame.new(0.3, 3.45, 1.2), orange, FABRIC, false)
		ball(m, "Tail", Vector3.new(0.9, 0.9, 1.5), CFrame.new(1.0, 0.9, 2.4), orange, FABRIC, false)
		ball(m, "Head", Vector3.new(3.3, 2.5, 2.7), CFrame.new(0, 3.25, -0.75), white, FABRIC, false)
		ball(m, "Mask", Vector3.new(3.36, 1.55, 2.74), CFrame.new(0, 3.85, -0.75), black, FABRIC, false)
		ball(m, "Blaze", Vector3.new(0.55, 1.4, 0.4), CFrame.new(0, 3.6, -2.0), white, FABRIC, false)
		ball(m, "Nose", Vector3.new(0.3, 0.22, 0.22), CFrame.new(0, 2.9, -1.98), Color3.fromRGB(240, 150, 170), PLASTIC, false)
		for _, sx in ipairs({ -1, 1 }) do
			ball(m, "Paw", Vector3.new(1.0, 0.55, 1.3), CFrame.new(sx * 0.95, 0.28, -1.75), white, FABRIC, false)
			ball(m, "Cheek", Vector3.new(1.1, 1.3, 1.1), CFrame.new(sx * 1.35, 2.7, -1.0), white, FABRIC, false)
			ball(m, "Muzzle", Vector3.new(0.95, 0.75, 0.8), CFrame.new(sx * 0.42, 2.7, -1.65), white, FABRIC, false)
			ball(m, "EyeWhite", Vector3.new(0.8, 0.8, 0.3), CFrame.new(sx * 0.7, 3.75, -1.78), Color3.fromRGB(252, 252, 252), PLASTIC, false)
			ball(m, "Iris", Vector3.new(0.62, 0.62, 0.2), CFrame.new(sx * 0.7, 3.82, -1.9), Color3.fromRGB(62, 42, 32), PLASTIC, false)
			ball(m, "Pupil", Vector3.new(0.34, 0.4, 0.2), CFrame.new(sx * 0.7, 3.88, -1.97), black, PLASTIC, false)
			ball(m, "Shine", Vector3.new(0.13, 0.13, 0.1), CFrame.new(sx * 0.6, 4.0, -2.04), white, PLASTIC, false)
			ball(m, "Ear", Vector3.new(0.95, 0.7, 0.6), CFrame.new(sx * 1.25, 4.5, -0.95) * CFrame.Angles(math.rad(-15), 0, math.rad(sx * -28)), black, FABRIC, false)
			for _, dy in ipairs({ -0.08, 0.1 }) do
				newPart(m, "Whisker", Vector3.new(0.9, 0.03, 0.03), CFrame.new(sx * 1.3, 2.75 + dy, -1.6) * CFrame.Angles(0, math.rad(sx * 18), math.rad(sx * dy * 150)), Color3.fromRGB(60, 60, 66), PLASTIC, false)
			end
		end
	end

	B.water = function(m)
		local GLASS = Enum.Material.Glass
		local glass, water = Color3.fromRGB(205, 232, 245), Color3.fromRGB(80, 180, 255)
		local function soft(part, t) part.Transparency = t return part end
		soft(pillar(m, "Bottle", 3.2, 1.9, CFrame.new(0, 1.6, 0), glass, GLASS, true), 0.5)
		soft(ball(m, "Shoulder", Vector3.new(1.9, 1.3, 1.9), CFrame.new(0, 3.2, 0), glass, GLASS, false), 0.5)
		soft(pillar(m, "Neck", 0.9, 0.85, CFrame.new(0, 4.1, 0), glass, GLASS, false), 0.5)
		soft(pillar(m, "Water", 2.9, 1.72, CFrame.new(0, 1.55, 0), water, GLASS, false), 0.25)
		soft(ball(m, "WaterTop", Vector3.new(1.72, 0.9, 1.72), CFrame.new(0, 3.0, 0), water, GLASS, false), 0.25)
		for _, b in ipairs({ { -0.3, 2.2, 0.2 }, { 0.35, 2.6, -0.25 }, { 0.1, 2.9, 0.3 } }) do
			soft(ball(m, "Bubble", Vector3.new(0.16, 0.16, 0.16), CFrame.new(b[1], b[2], b[3]), WHITE, PLASTIC, false), 0.35)
		end
		pillar(m, "CapRing", 0.12, 1.1, CFrame.new(0, 4.5, 0), Color3.fromRGB(40, 110, 190), PLASTIC, false)
		pillar(m, "Cap", 0.5, 1.05, CFrame.new(0, 4.8, 0), Color3.fromRGB(50, 140, 230), PLASTIC, false)
		soft(newPart(m, "Glint", Vector3.new(0.1, 2.2, 0.05), CFrame.new(-0.55, 1.8, -0.77) * CFrame.Angles(0, math.rad(35), 0), WHITE, PLASTIC, false), 0.55)
		soft(pillar(m, "Label", 1.35, 1.99, CFrame.new(0, 1.55, 0), Color3.fromRGB(236, 246, 255), PLASTIC, false), 0.05)
		for _, side in ipairs({ { -1.025, Enum.NormalId.Front }, { 1.025, Enum.NormalId.Back } }) do
			local plate = newPart(m, "LabelPlate", Vector3.new(1.7, 1.2, 0.04), CFrame.new(0, 1.55, side[1]), WHITE, PLASTIC, false)
			plate.Transparency = 1
			local sg = make("SurfaceGui", { Face = side[2], SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 100 }, plate)
			local function line(text, y, h, size, color, thick)
				local t = make("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h),
					Font = Enum.Font.GothamBlack, TextSize = size, TextColor3 = color, Text = text,
				}, sg)
				make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thick }, t)
			end
			line("вода", 8, 66, 60, Color3.fromRGB(120, 205, 255), 3)
			line("мировая", 78, 36, 28, Color3.fromRGB(235, 245, 255), 2)
		end
	end

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
		local radius = bbSize.Magnitude / 2 + Vector3.new(c.X, 0, c.Z).Magnitude
		local look = Vector3.new(0, c.Y, 0)
		local dist = radius / math.sin(math.rad(20)) * 1.05
		local cam = make("Camera", { FieldOfView = 40 }, vp)
		cam.CFrame = CFrame.lookAt(look + Vector3.new(0, dist * 0.3, dist * 0.95), look)
		vp.CurrentCamera = cam
		Decor.spinners[#Decor.spinners + 1] = { model = m, phase = #Decor.spinners * 0.9 }
		return vp
	end

	function Decor.spin(dt)
		Decor.angle += dt * 1.4
		for _, s in ipairs(Decor.spinners) do
			s.model:PivotTo(CFrame.Angles(0, Decor.angle + s.phase, 0))
		end
	end
end

-- ===== Опора под рельсой =====
local function groundBelow(x, y, z)
	local filter = { railsFolder, camera }
	if cart then table.insert(filter, cart.model) end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(filter, pl.Character) end
	end
	supportParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -400, 0), supportParams)
	return hit and hit.Position.Y or nil
end

local function addSupport(model, x, y, z)
	local bottom = y - BASE_HEIGHT / 2
	local gy = groundBelow(x, bottom - 0.05, z)
	if not gy then return end
	local h = bottom - gy
	if h < 0.5 then return end
	local concrete = Color3.fromRGB(110, 112, 122)
	newPart(model, "Support", Vector3.new(0.9, h, 0.9), CFrame.new(0, -BASE_HEIGHT / 2 - h / 2, 0), concrete, Enum.Material.Concrete, true)
	newPart(model, "SupportCap", Vector3.new(2.4, 0.3, 2.4), CFrame.new(0, -BASE_HEIGHT / 2 - 0.15, 0), concrete, Enum.Material.Concrete, true)
end

-- ===== Подсветки =====
local allHL = make("Highlight", {
	FillColor = C.accent, FillTransparency = 0.88, OutlineColor = C.accent, OutlineTransparency = 0.15,
	DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false,
}, railsFolder)

local hoverHL = make("Highlight", {
	FillColor = C.bad, OutlineColor = WHITE, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
})

local function flashRail(target, color)
	local hl = make("Highlight", {
		FillColor = WHITE, OutlineColor = color or C.good, FillTransparency = 0, OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, target)
	local tw = tween(hl, 0.7, { FillTransparency = 1, OutlineTransparency = 1 })
	tw.Completed:Once(function() hl:Destroy() end)
end

-- ===== Дома: двери и жители =====
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
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(list) end) end)
end
Home.kindCache = setmetatable({}, { __mode = "k" })

function Decor.turnStep()
	for _, it in ipairs(Decor.list) do
		if it.key == Decor.key then return it.turn or Decor.TURN end
	end
	return Decor.TURN
end

function Home.setAngle(d, angle)
	local base = d.model.PrimaryPart.CFrame
	local hinge = CFrame.new(-1.9, 0, 0)
	local rot = hinge * CFrame.Angles(0, math.rad(angle), 0) * hinge:Inverse()
	for _, l in ipairs(d.leaf) do
		l.part.CFrame = base * rot * l.rel
	end
end

function Home.attachDoor(m, cf)
	local d = { model = m, leaf = {}, open = false, hintOn = false }
	local origin = m.PrimaryPart
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Leaf") then
			d.leaf[#d.leaf + 1] = { part = p, rel = origin.CFrame:ToObjectSpace(p.CFrame), collide = p.CanCollide }
		end
	end
	local back = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z).Unit
	d.pos0 = cf.Position
	d.back = back
	d.inGate = d.pos0 + back * 4.4
	d.outGate = d.pos0 - back * 3.4
	d.inCenter = d.pos0 + back * (Home.IN_ROOM * 0.6 + 5)
	d.outCenter = d.pos0 - back * (Home.OUT_ROOM * 0.6 + 5)
	local trigger = newPart(m, "Trigger", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 3.4, 0), WHITE, Enum.Material.SmoothPlastic, false)
	trigger.Transparency = 1
	trigger.CanQuery = false
	d.trigger = trigger
	d.prompt = make("ProximityPrompt", {
		ActionText = "Открыть", ObjectText = "Дверь", HoldDuration = Home.HOLD, MaxActivationDistance = Home.RANGE,
		RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E, Enabled = not buildMode,
	}, trigger)
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
	d.val = Instance.new("NumberValue")
	d.val.Changed:Connect(function(v) if m.Parent then Home.setAngle(d, v) end end)
	d.prompt.Triggered:Connect(function() Home.setOpen(d, not d.open) end)
	Home.doors[m] = d
	if Home.refreshNpcBtn then Home.refreshNpcBtn() end
	return d
end

function Home.detachDoor(m)
	local d = Home.doors[m]
	if d then
		d.val:Destroy()
		Home.doors[m] = nil
		if Home.refreshNpcBtn then Home.refreshNpcBtn() end
	end
end

function Home.clearDoors()
	for m in pairs(Home.doors) do Home.detachDoor(m) end
	Home.resetRoutes()
end

function Home.setOpen(d, on, autoClose)
	if d.open == on then
		if on and autoClose then d.closeAt = os.clock() + autoClose end
		return
	end
	d.open = on
	d.closeAt = (on and autoClose) and (os.clock() + autoClose) or nil
	d.prompt.ActionText = on and "Закрыть" or "Открыть"
	for _, l in ipairs(d.leaf) do l.part.CanCollide = false end
	local tw = tween(d.val, 0.45, { Value = on and -90 or 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	tw.Completed:Once(function()
		if d.model.Parent and not d.open then
			for _, l in ipairs(d.leaf) do l.part.CanCollide = l.collide end
		end
	end)
end

function Home.hint(d, on)
	if d.hintOn == on then return end
	d.hintOn = on
	d.hl.Enabled = on
	if on then
		d.gui.Enabled = true
		tween(d.img, 0.25, { ImageTransparency = 0 })
		tween(d.imgScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		tween(d.img, 0.2, { ImageTransparency = 1 })
		tween(d.imgScale, 0.2, { Scale = 0.6 })
		task.delay(0.25, function() if not d.hintOn then d.gui.Enabled = false end end)
	end
end

function Home.setBuild(on)
	for _, d in pairs(Home.doors) do
		d.prompt.Enabled = not on
		if on then Home.hint(d, false) end
	end
end

function Home.stepDoors(now)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for m, d in pairs(Home.doors) do
		if m.Parent then
			if d.closeAt and now >= d.closeAt then Home.setOpen(d, false) end
			local near = false
			if root and d.prompt.Enabled then
				near = (root.Position - d.trigger.Position).Magnitude <= Home.RANGE
			end
			Home.hint(d, near)
		end
	end
end

function Home.filter()
	local f = { Home.folder, camera }
	if player.Character then f[#f + 1] = player.Character end
	return f
end

function Home.playerPos()
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

function Home.alive(n) return n.alive and n.model.Parent ~= nil and n.hum.Health > 0 end

function Home.groundAt(pos)
	Home.rayParams.FilterDescendantsInstances = Home.filter()
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), Home.rayParams)
	if hit then return hit.Position, hit.Instance end
	return nil, nil
end

function Home.blocked(inst)
	local m = inst and inst:FindFirstAncestorOfClass("Model")
	return m ~= nil and m.Parent == railsFolder and m:GetAttribute("Kind") == "decor"
end

function Home.clear(a, b)
	Home.rayParams.FilterDescendantsInstances = Home.filter()
	local from, to = a + Vector3.new(0, 2.2, 0), b + Vector3.new(0, 2.2, 0)
	return workspace:Raycast(from, to - from, Home.rayParams) == nil
end

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

function Home.say(n, key) Home.getSound(n, key):Play() end

function Home.setFace(n, key)
	if n.faceKey == key then return end
	n.faceKey = key
	local decal = n.faceDecal
	if not decal or not decal.Parent then return end
	if key and Home.FACES[key] then
		decal.Texture = "rbxassetid://" .. Home.FACES[key]
	else
		decal.Texture = n.faceNormal or ""
	end
end

function Home.play(n, name) local t = n.anim[name]; if t then t:Play(0.15) end end
function Home.stop(n, name) local t = n.anim[name]; if t then t:Stop(0.2) end end

function Home.face(n, pos)
	local root = n.root
	n.hum.AutoRotate = false
	for _ = 1, 8 do
		if not Home.alive(n) then return end
		local from = root.Position
		local flat = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
		if flat.Magnitude < 0.05 then break end
		root.CFrame = root.CFrame:Lerp(CFrame.lookAt(from, from + flat), 0.35)
		task.wait()
	end
	n.hum.AutoRotate = true
end

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

function Home.bubble(n, text)
	local head = n.model:FindFirstChild("Head")
	if not head then return end
	local gui = make("BillboardGui", {
		Adornee = head, Size = UDim2.fromOffset(120, 48), StudsOffset = Vector3.new(0, 2.1 * n.scale + 0.3, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 90,
	}, n.model)
	local box = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
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
		task.delay(0.35, function() gui:Destroy() end)
	end)
end

function Home.idle(n, seconds)
	local pp = Home.playerPos()
	if pp and n.seen and (pp - n.root.Position).Magnitude < 16 and math.random() < 0.6 then
		Home.face(n, pp)
	end
	Home.pause(n, seconds)
end

function Home.walkRaw(n, target, stopDist, timeout)
	local hum, root = n.hum, n.root
	local t0 = os.clock()
	local lastPos, lastMove = root.Position, t0
	local nextMove = t0
	while true do
		if not Home.alive(n) then return "dead" end
		hum.WalkSpeed = (n.speed or Home.WALK) * (n.fast and Home.FAST or 1)
		if n.event or (n.pending and not n.lock and not n.panic and os.clock() >= n.pendingAt) then
			hum:MoveTo(root.Position)
			return "event"
		end
		local now = os.clock()
		local p = root.Position
		if Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude <= stopDist then return "ok" end
		if now - t0 > timeout then return "stuck" end
		if (p - lastPos).Magnitude > 0.6 then
			lastPos, lastMove = p, now
		elseif now - lastMove > 1.2 then
			hum.Jump = true
			if now - lastMove > 3 then return "stuck" end
		end
		if now >= nextMove then
			hum:MoveTo(target)
			nextMove = now + 1.5
		end
		task.wait(0.1)
	end
end

function Home.walkTo(n, target, stopDist, timeout)
	local t0 = os.clock()
	local r = Home.walkRaw(n, target, stopDist, timeout)
	if os.clock() - t0 < 0.05 then task.wait(0.1) end
	return r
end

function Home.joy(n)
	Home.say(n, "joy")
	Home.play(n, "cheer")
	Home.setFace(n, "joy")
	for _ = 1, n.small and 5 or 3 do
		if not Home.alive(n) then return end
		n.hum.Jump = true
		task.wait(0.6)
	end
	Home.stop(n, "cheer")
	Home.setFace(n, nil)
end

function Home.scared(n)
	n.lock = true
	local hum, root = n.hum, n.root
	hum:MoveTo(root.Position)
	Home.setFace(n, "prescare")
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
			root.AssemblyLinearVelocity = Vector3.new(away.X * 14 * k, 20 * k, away.Z * 14 * k)
		end
	end
	task.wait(0.9)
	Home.armsUp(n, false)
	Home.setFace(n, nil)
	pp = Home.playerPos()
	if pp then Home.face(n, pp) end
	task.wait(0.8)
	if Home.alive(n) then
		Home.say(n, "laugh")
		Home.play(n, "laugh")
		Home.setFace(n, "laugh")
		task.wait(2.4)
		Home.stop(n, "laugh")
		Home.setFace(n, nil)
	end
	if math.random() < 0.5 then n.wantDoor = true end
	n.lock = false
end

function Home.nearestDoor(pos)
	local best, bestD = nil, math.huge
	for m, d in pairs(Home.doors) do
		if m.Parent then
			local dist = (d.pos0 - pos).Magnitude
			if dist < bestD then best, bestD = d, dist end
		end
	end
	return best, bestD
end

function Home.log(...) if Home.DEBUG then print("[Обучение]", ...) end end

function Home.newRoutes()
	local list = {}
	for i = 1, Home.ROUTE_SLOTS do list[i] = { name = "Маршрут " .. i, pts = {} } end
	return list
end
Home.routes = Home.newRoutes()

function Home.routeLength(pts)
	local len = 0
	for i = 2, #pts do len += (pts[i] - pts[i - 1]).Magnitude end
	return len
end

function Home.makeLesson(r, look)
	local pts = r.pts
	if not look and #pts >= 2 then
		local a, b = pts[#pts - 1], pts[#pts]
		look = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	end
	r.lesson = { pts = pts, look = (look and look.Magnitude > 0.1) and look.Unit or nil }
end

function Home.lessonList()
