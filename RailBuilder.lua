-- LocalScript (ВСЁ В ОДНОМ) — ФИНАЛ + ТАБЛИЧКИ + СВОБОДНЫЙ РЕЖИМ
-- Положи в: StarterPlayer > StarterPlayerScripts > RailBuilder
-- Рельсы, таблички и вагонетка существуют только на твоём клиенте — другие игроки их не видят.
-- Сохранение между заходами работает, если в игре есть серверный скрипт RailSaveServer.
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

local KIND_CODE = { straight = 0, curve = 1, ramp = 2, sign = 3, loop = 4 }
local CODE_KIND = { [0] = "straight", [1] = "curve", [2] = "ramp", [3] = "sign", [4] = "loop" }

-- ===== Состояние =====
local data = nil
local railCount = 0
local busy = true
local saveFn = nil
local saveQueued = false
local saveState = "off" -- off / saving / saved / error

local buildMode = false
local tool = "straight" -- straight / curve / ramp / loop / sign / edit / erase / cart
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

-- ===== Рельсы и таблички: создание / удаление / данные =====
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
local function registerPiece(m, kind, cf)
	local info = { model = m, kind = kind, cf = cf }
	if kind ~= "sign" then
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
-- free = true — свободная рельса (не привязана к клетке сетки)
local function spawnPiece(kind, x, y, z, yaw, pitch, roll, free, animate, text)
	local m = newRailModel(kind, "Rail")
	local cf = Geo.pieceCF(x, y, z, yaw, pitch, roll)
	if kind ~= "loop" and math.abs(pitch) < 0.5 and math.abs(roll) < 0.5 then
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
	end
	m:PivotTo(cf)
	m.Parent = railsFolder
	registerPiece(m, kind, cf)
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
	table.clear(tileAt)
	table.clear(pieces)
	table.clear(eps)
	railCount = 0
	hoverRail = nil
	hoverHL.Parent = nil
end

local function loadRails(rails)
	for i, r in ipairs(rails) do
		if type(r) == "table"
			and type(r[1]) == "number" and type(r[2]) == "number"
			and type(r[3]) == "number" and type(r[4]) == "number"
			and railCount < MAX_RAILS then
			local free = (r[9] == 1)
			if free or not tileAt[cellKey(r[1], r[3])] then
				local kind = CODE_KIND[r[5]] or "straight"
				local text = (kind == "sign" and type(r[6]) == "string") and cleanSignText(r[6]) or nil
				local pitch = (free and type(r[7]) == "number") and r[7] or 0
				local roll = (free and type(r[8]) == "number") and r[8] or 0
				spawnPiece(kind, r[1], r[2], r[3], r[4], pitch, roll, free, false, text)
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
	BorderSizePixel = 0, LayoutOrder = 3, Visible = false,
}, dock)
local tools = make("Frame", {
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1, LayoutOrder = 4, Visible = false,
}, dock)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
}, tools)

-- кнопки инструментов чуть уже, чтобы панель с табличками поместилась на экран
local function toolButton(icon, text, order)
	return dockButton(tools, icon, text, order, 62)
end

local toolBtns = {}
toolBtns.straight = toolButton("➖", "Прямая", 1)
toolBtns.curve = toolButton("↪", "Поворот", 2)
toolBtns.ramp = toolButton("📐", "Уклон", 3)
toolBtns.erase = toolButton("❌", "Стереть", 4)
toolBtns.cart = toolButton("🚃", "Вагонетка", 5)
toolBtns.sign = toolButton("🪧", "Табличка", 6)
toolBtns.edit = toolButton("✏️", "Текст", 7)
local rotateBtn = toolButton("↻", "Повернуть", 8)
local actionBtn, actionIcon, actionLbl = toolButton("✔", "Поставить", 9)
setBase(actionBtn, C.goodDark)
actionBtn.Visible = UserInputService.TouchEnabled

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
	erase = TOUCH_ONLY and "Тапни рельсу или табличку → «Удалить»" or "Наведи на рельсу или табличку и нажми ЛКМ  ·  зажми и води — стирать подряд",
	cart = TOUCH_ONLY and "Тапни рельсу → «Поставить» вагонетку" or "Нажми на рельсу, чтобы поставить на неё вагонетку",
	sign = TOUCH_ONLY and "Напиши текст в поле → тапни место → «Поставить»  ·  ↻ — повернуть" or "Напиши текст в поле выше  ·  ЛКМ — поставить  ·  R — повернуть  ·  E / Q — выше / ниже",
	edit = TOUCH_ONLY and "Напиши новый текст → тапни табличку → «Применить»" or "Напиши новый текст в поле выше и нажми ЛКМ на табличке",
	loop = "Мёртвая петля ставится только в свободном режиме",
	-- подсказки свободного режима (для всего, что ставится); короткие, чтобы не залезать на боковые панели
	free = {
		place = TOUCH_ONLY and "Тапни место → «Поставить»  ·  внизу: наклон, крен, магнит" or "ЛКМ — поставить  ·  R поворот  ·  T наклон  ·  Y крен  ·  M магнит",
		loop = TOUCH_ONLY and "Подведи к концу рельсы — прилипнет  ·  «Поставить»" or "Подведи к концу рельсы — прилипнет 🧲  ·  ЛКМ — поставить",
		sign = TOUCH_ONLY and "Напиши текст → тапни место → «Поставить»" or "Текст в поле выше  ·  ЛКМ — поставить  ·  R / T / Y — повороты",
	},
}
local ACTIONS = {
	straight = { "✔", "Поставить" }, curve = { "✔", "Поставить" }, ramp = { "✔", "Поставить" },
	erase = { "🗑", "Удалить" }, cart = { "🚃", "Поставить" },
	sign = { "✔", "Поставить" }, edit = { "✏️", "Применить" }, loop = { "✔", "Поставить" },
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

-- когда над основной панелью висит панель свободного режима, подсказку и поле текста поднимаем выше
local function layoutBottom()
	local extra = FUI.dock.Visible and 80 or 0
	hint.Position = UDim2.new(0.5, 0, 1, -106 - extra)
	signPanel.Position = UDim2.new(0.5, 0, 1, -150 - extra)
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
local function isPlacing(t)
	return t == "straight" or t == "curve" or t == "ramp" or t == "sign" or t == "loop"
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
	FUI.mark.Parent = nil
	FM.snapped = false
end

local function createGhost(kind)
	destroyGhost()
	ghost = newRailModel(kind, "Ghost")
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

	-- точка под курсором: земля (уровень 0) или горизонтальная плоскость нужной высоты
	local pos
	if level == 0 then
		-- на земле: луч до поверхности
		local filter = { ghost, railsFolder }
		if player.Character then
			table.insert(filter, player.Character)
		end
		rayParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
		if hit then
			refY = hit.Position.Y
			pos = Vector3.new(snap(hit.Position.X), hit.Position.Y + BASE_HEIGHT / 2, snap(hit.Position.Z))
		end
	else
		-- в воздухе: луч до горизонтальной плоскости нужной высоты
		local py = refY + BASE_HEIGHT / 2 + level * FM.levelStep()
		local dy = ray.Direction.Y
		if math.abs(dy) > 1e-4 then
			local t = (py - ray.Origin.Y) / dy
			if t > 0 and t < 400 then
				local h = ray.Origin + ray.Direction * t
				pos = Vector3.new(snap(h.X), py, snap(h.Z))
			end
		end
	end

	local tcf, valid, snapEp
	if FM.on then
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
		tcf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotTarget % 360), 0)
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
	-- «Текст» работает только с табличками, «Вагонетка» — только с рельсами
	if rail then
		local isSign = rail:GetAttribute("Kind") == "sign"
		if (tool == "edit" and not isSign) or (tool == "cart" and isSign) then
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
		if FM.on then
			-- свободная рельса: положение и углы берём прямо из призрака
			local x, y, z, yaw, pitch, roll = Geo.decompose(ghostCF)
			spawnPiece(tool, round2(x), round2(y), round2(z), round2(yaw), round2(pitch), round2(roll), true, true, txt)
		else
			local p = ghostCF.Position
			spawnPiece(tool, p.X, round2(p.Y), p.Z, rotTarget % 360, 0, 0, false, true, txt)
		end
		ghostValid = false
		markDirty()
		onRailsChanged()
	end
end

-- поворот вокруг вертикали: в обычном режиме по 90°, в свободном — на выбранный шаг
local function rotate(dir)
	if not FM.on then
		rotTarget += 90 * dir
	elseif FM.snapped then
		FM.rel.yaw = FM.wrap(FM.rel.yaw + FM.stepAngle() * dir)
	else
		rotTarget += FM.stepAngle() * dir
	end
end

-- наклон (pitch) и крен (roll): «в воздухе» — относительно мира, у прилипшего призрака — относительно конца рельсы
function FM.tilt(which, dir)
	if not FM.on then
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
		b.Visible = placing
	end
	if placing then
		if ghostKind ~= t then
			createGhost(t)
		end
	else
		destroyGhost()
	end
	actionIcon.Text = ACTIONS[t][1]
	actionLbl.Text = ACTIONS[t][2]
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
	if not on then
		rotTarget = math.round(rotTarget / 90) * 90 -- обычный режим знает только прямые углы
	end
	FM.snapped = false
	ghostShown = nil
	FUI.refreshSwitch(true)
	refreshFreeButtons()
	FUI.dock.Visible = buildMode and on
	layoutBottom()
	if buildMode then
		setTool(tool)
	end
	toast(on and "🔓 Свободный режим: рельсы без правил" or "🔒 Обычный режим: рельсы по сетке", on and C.good or C.sub)
end

local function setBuildMode(on)
	buildMode = on
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
		if buildMode and isPlacing(tool) then
			FM.tilt("pitch", back)
		end
	elseif input.KeyCode == Enum.KeyCode.Y then
		if buildMode and isPlacing(tool) then
			FM.tilt("roll", back)
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		if buildMode and FM.on and isPlacing(tool) then
			FM.flip = not FM.flip
			refreshFreeButtons()
		end
	elseif input.KeyCode == Enum.KeyCode.M then
		if buildMode and FM.on then
			FM.toggleMagnet()
		end
	elseif input.KeyCode == Enum.KeyCode.N then
		if buildMode and FM.on then
			FM.cycleStep()
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		if buildMode then
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
		if data then
			setBuildMode(not buildMode)
		end
	elseif TOOL_KEYS[input.KeyCode] and buildMode then
		local name = TOOL_KEYS[input.KeyCode]
		if name ~= "loop" or FM.on then
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
end)

-- ===== Старт: загрузка сохранения (если есть серверный скрипт) =====
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

	pill.Position = UDim2.new(0.5, 0, 0, -70)
	pill.Visible = true
	tween(pill, 0.5, { Position = UDim2.new(0.5, 0, 0, 10) }, Enum.EasingStyle.Back)
	dock.Position = UDim2.new(0.5, 0, 1, 90)
	dock.Visible = true
	tween(dock, 0.5, { Position = UDim2.new(0.5, 0, 1, -14) }, Enum.EasingStyle.Back)

	loadRails(data.slots[data.active].rails)
	busy = false
	refreshSlots()
end)
