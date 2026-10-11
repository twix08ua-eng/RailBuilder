-- LocalScript (ВСЁ В ОДНОМ) — ФИНАЛ
-- Положи в: StarterPlayer > StarterPlayerScripts > RailBuilder
-- Рельсы и вагонетка существуют только на твоём клиенте — другие игроки их не видят.
-- Сохранение между заходами работает, если в игре есть серверный скрипт RailSaveServer.

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
local MAX_LEVEL = 15    -- максимум уровней вверх
local CART_SPEEDS = { 8, 16, 28 }
local CART_SPEED_NAMES = { "🐢 Медленно", "🏃 Средне", "⚡ Быстро" }
local SEAT_OFFSET = CFrame.new(0, 2.3, 0.1) -- где сидит игрок относительно вагонетки

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
}
local TOUCH_ONLY = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local KIND_CODE = { straight = 0, curve = 1, ramp = 2 }
local CODE_KIND = { [0] = "straight", [1] = "curve", [2] = "ramp" }

-- ===== Состояние =====
local data = nil
local railCount = 0
local busy = true
local saveFn = nil
local saveQueued = false
local saveState = "off" -- off / saving / saved / error

local buildMode = false
local tool = "straight" -- straight / curve / ramp / erase / cart
local rotTarget, rotCurrent = 0, 0
local level, refY = 0, 0 -- уровень высоты и высота земли для уровня 0
local ghost, ghostKind, ghostHL
local ghostPos, ghostCF
local ghostValid = false
local hoverRail
local holding = false
local touchPos
local lastInputTouch = TOUCH_ONLY
local lastLimitToast = 0
local slotsOpen = false

local tileAt = {} -- [ "gx,gz" ] = модель рельсы
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
    return math.round(v * 100) / 100
end

local function cellKey(x, z)
    return (math.round(x / GRID) + 0) .. "," .. (math.round(z / GRID) + 0)
end

local function snap(v)
    return math.round(v / GRID) * GRID
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

-- kind: "straight" (прямая), "curve" (поворот на 90°), "ramp" (уклон: нижний конец -Z, верхний +Z)
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

-- ===== Рельсы: создание / удаление / данные =====
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

local function spawnRail(x, y, z, rot, kind, animate)
    local m = newRailModel(kind, "Rail")
    addSupport(m, x, y, z)
    local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rot), 0)
    m:SetAttribute("Rot", rot)
    m:SetAttribute("Kind", kind)
    m:SetAttribute("Pos", Vector3.new(x, y, z))
    m:PivotTo(cf)
    m.Parent = railsFolder
    tileAt[cellKey(x, z)] = m
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
    m:Destroy()
    railCount -= 1
end

local function serialize()
    local out = {}
    for _, m in ipairs(railsFolder:GetChildren()) do
        if m:IsA("Model") then
            local p = m:GetAttribute("Pos")
            if p then
                out[#out + 1] = {
                    round2(p.X), round2(p.Y), round2(p.Z),
                    m:GetAttribute("Rot") or 0,
                    KIND_CODE[m:GetAttribute("Kind")] or 0,
                }
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
    railCount = 0
    hoverRail = nil
    hoverHL.Parent = nil
end

local function loadRails(rails)
    for i, r in ipairs(rails) do
        if type(r) == "table"
            and type(r[1]) == "number" and type(r[2]) == "number"
            and type(r[3]) == "number" and type(r[4]) == "number"
            and railCount < MAX_RAILS
            and not tileAt[cellKey(r[1], r[3])] then
            spawnRail(r[1], r[2], r[3], r[4], CODE_KIND[r[5]] or "straight", false)
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
-- У каждой рельсы два «порта» — направления на соседние клетки.
-- Для уклона первый порт — НИЖНИЙ конец, второй — верхний.
local function tilePorts(tile)
    local rot = tile:GetAttribute("Rot") or 0
    local cf = CFrame.Angles(0, math.rad(rot), 0)
    local a = Vector3.new(0, 0, -1)
    local b = (tile:GetAttribute("Kind") == "curve") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local function w(v)
        local r = cf:VectorToWorldSpace(v)
        return Vector3.new(math.round(r.X), 0, math.round(r.Z))
    end
    return w(a), w(b)
end

local function tileLength(tile)
    local kind = tile:GetAttribute("Kind")
    if kind == "curve" then
        return math.pi
    elseif kind == "ramp" then
        return RAMP_LEN
    end
    return GRID
end

-- высота центральной линии рельсы на краю клетки (в сторону dir)
local function edgeY(tile, dir)
    local y = tile:GetAttribute("Pos").Y
    if tile:GetAttribute("Kind") == "ramp" then
        local low = tilePorts(tile)
        if dir ~= low then
            y += RISE
        end
    end
    return y
end

-- позиция, направление и наклон на рельсе (u от 0 до 1)
local function pathPoint(tile, entry, exit, u)
    local c = tile:GetAttribute("Pos")
    local kind = tile:GetAttribute("Kind")
    if kind == "curve" then
        local corner = c + (entry + exit) * 2
        local phi = u * math.pi / 2
        local pos = corner - (exit * math.cos(phi) + entry * math.sin(phi)) * 2
        local heading = exit * math.sin(phi) - entry * math.cos(phi)
        return pos, heading, 0
    end
    local p = (c + entry * 2):Lerp(c + exit * 2, u)
    if kind == "ramp" then
        local low = tilePorts(tile)
        local rising = (entry == low)
        local t = rising and u or (1 - u)
        return Vector3.new(p.X, c.Y + RISE * t, p.Z), exit, rising and RAMP_ANGLE or -RAMP_ANGLE
    end
    return p, exit, 0
end

local function advanceTile()
    local c = cart.tile:GetAttribute("Pos")
    local nt = tileAt[cellKey(c.X + cart.exit.X * GRID, c.Z + cart.exit.Z * GRID)]
    if not nt or nt.Parent ~= railsFolder then
        return false
    end
    local a, b = tilePorts(nt)
    local back = -cart.exit
    local newEntry, newExit
    if a == back then
        newEntry, newExit = a, b
    elseif b == back then
        newEntry, newExit = b, a
    else
        return false
    end
    -- высоты на стыке должны совпадать, иначе путь «оборван»
    if math.abs(edgeY(cart.tile, cart.exit) - edgeY(nt, newEntry)) > 0.35 then
        return false
    end
    cart.tile, cart.entry, cart.exit, cart.u = nt, newEntry, newExit, 0
    cart.len = tileLength(nt)
    return true
end

local function spawnCart(tile)
    if cart then
        removeCart()
    end
    local a, b = tilePorts(tile)
    local look = camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    local exit, entry = a, b
    if b:Dot(flat) > a:Dot(flat) then
        exit, entry = b, a
    end

    local model = newCartModel()
    model.Parent = workspace
    local u = 0.5
    local pos, heading, pitch = pathPoint(tile, entry, exit, u)
    local yaw = math.atan2(-heading.X, -heading.Z)
    local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 0.7, 0)
    model:PivotTo(cf)

    cart = {
        model = model, tile = tile, entry = entry, exit = exit, u = u,
        len = tileLength(tile), speed = 0, running = false, speedIdx = 2,
        yaw = yaw, pitch = pitch, wait = 0, riding = false, cf = cf,
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
    if c.tile.Parent ~= railsFolder then
        removeCart("🚃 Вагонетка слетела — рельсу убрали")
        return
    end

    if c.wait > 0 then
        c.wait -= dt
    else
        -- в гору медленнее, с горы быстрее
        local slope = 1 - 0.25 * (c.pitch / RAMP_ANGLE)
        local target = c.running and CART_SPEEDS[c.speedIdx] * slope or 0
        c.speed += (target - c.speed) * math.min(1, dt * 2.5)
        if not c.running and c.speed < 0.1 then
            c.speed = 0
        end
        local dist = c.speed * dt
        for _ = 1, 8 do
            if dist <= 0 then
                break
            end
            local remain = (1 - c.u) * c.len
            if dist < remain then
                c.u += dist / c.len
                dist = 0
            else
                dist -= remain
                if not advanceTile() then
                    -- конец пути: разворот на этой же рельсе
                    c.entry, c.exit = c.exit, c.entry
                    c.u = 0
                    c.speed = 0
                    c.wait = 0.45
                    break
                end
            end
        end
    end

    local pos, heading, pitch = pathPoint(c.tile, c.entry, c.exit, c.u)
    local targetYaw = math.atan2(-heading.X, -heading.Z)
    local d = (targetYaw - c.yaw + math.pi) % (2 * math.pi) - math.pi
    c.yaw += d * (1 - math.exp(-dt * 12))
    c.pitch += (pitch - c.pitch) * (1 - math.exp(-dt * 10))

    local cf = CFrame.new(pos) * CFrame.Angles(0, c.yaw, 0) * CFrame.Angles(c.pitch, 0, 0) * CFrame.new(0, 0.7, 0)
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

local function dockButton(parent, icon, text, order)
    local b = button(parent, { Size = UDim2.fromOffset(66, 62), LayoutOrder = order }, C.card)
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

local toolBtns = {}
toolBtns.straight = dockButton(tools, "➖", "Прямая", 1)
toolBtns.curve = dockButton(tools, "↪", "Поворот", 2)
toolBtns.ramp = dockButton(tools, "📐", "Уклон", 3)
toolBtns.erase = dockButton(tools, "❌", "Стереть", 4)
toolBtns.cart = dockButton(tools, "🚃", "Вагонетка", 5)
local rotateBtn = dockButton(tools, "↻", "Повернуть", 6)
local actionBtn, actionIcon, actionLbl = dockButton(tools, "✔", "Поставить", 7)
setBase(actionBtn, C.goodDark)
actionBtn.Visible = UserInputService.TouchEnabled

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
    erase = TOUCH_ONLY and "Тапни рельсу → «Удалить»" or "Наведи на рельсу и нажми ЛКМ  ·  зажми и води — стирать подряд",
    cart = TOUCH_ONLY and "Тапни рельсу → «Поставить» вагонетку" or "Нажми на рельсу, чтобы поставить на неё вагонетку",
}
local ACTIONS = {
    straight = { "✔", "Поставить" }, curve = { "✔", "Поставить" }, ramp = { "✔", "Поставить" },
    erase = { "🗑", "Удалить" }, cart = { "🚃", "Поставить" },
}

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
        cart.entry, cart.exit = cart.exit, cart.entry
        cart.u = 1 - cart.u
        cart.speed = 0
        cart.wait = 0
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
        local countText = (count == 0) and "Пусто" or (count .. " рельс")
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
    return t == "straight" or t == "curve" or t == "ramp"
end

local function destroyGhost()
    if ghost then
        ghost:Destroy()
    end
    ghost, ghostKind, ghostHL, ghostPos, ghostCF = nil, nil, nil, nil, nil
end

local function createGhost(kind)
    destroyGhost()
    ghost = newRailModel(kind, "Ghost")
    ghostKind = kind
    for _, d in ipairs(ghost:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d.Name ~= "Origin" then
                d.Transparency = 0.35
            end
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

local function updateGhost(dt)
    -- плавный поворот (всегда в одну сторону, без «обратной прокрутки»)
    rotCurrent += (rotTarget - rotCurrent) * (1 - math.exp(-dt * 16))

    local ray = getRay()
    if not ray then
        return
    end

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
        local py = refY + BASE_HEIGHT / 2 + level * RISE
        local dy = ray.Direction.Y
        if math.abs(dy) > 1e-4 then
            local t = (py - ray.Origin.Y) / dy
            if t > 0 and t < 400 then
                local h = ray.Origin + ray.Direction * t
                pos = Vector3.new(snap(h.X), py, snap(h.Z))
            end
        end
    end

    if not pos then
        ghost.Parent = nil
        ghostCF, ghostPos = nil, nil
        return
    end

    ghostCF = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotTarget % 360), 0)
    ghostValid = (railCount < MAX_RAILS) and not tileAt[cellKey(pos.X, pos.Z)]

    ghostPos = ghostPos and ghostPos:Lerp(pos, 1 - math.exp(-dt * 24)) or pos
    local bob = 0.1 + math.sin(os.clock() * 4) * 0.06
    ghost.Parent = camera
    ghost:PivotTo(CFrame.new(ghostPos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, math.rad(rotCurrent), 0))

    ghostHL.FillColor = ghostValid and C.good or C.bad
    ghostHL.FillTransparency = 0.5 + math.sin(os.clock() * 6) * 0.15
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
    if rail ~= hoverRail then
        hoverRail = rail
        hoverHL.Parent = rail
    end
    hoverHL.FillColor = (tool == "erase") and C.bad or C.warn
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
    else
        if railCount >= MAX_RAILS then
            if os.clock() - lastLimitToast > 2 then
                lastLimitToast = os.clock()
                toast("Лимит рельс в слоте: " .. MAX_RAILS, C.bad)
            end
            return
        end
        if not ghostCF or not ghostValid then
            return
        end
        local p = ghostCF.Position
        spawnRail(p.X, round2(p.Y), p.Z, rotTarget % 360, tool, true)
        ghostValid = false
        markDirty()
        onRailsChanged()
    end
end

local function rotate(dir)
    rotTarget += 90 * dir
end

local function setLevel(n)
    n = math.clamp(n, 0, MAX_LEVEL)
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
    if placing then
        if ghostKind ~= t then
            createGhost(t)
        end
    else
        destroyGhost()
    end
    actionIcon.Text = ACTIONS[t][1]
    actionLbl.Text = ACTIONS[t][2]
    hint.Text = HINTS[t]
end

local function setBuildMode(on)
    buildMode = on
    allHL.Enabled = on
    tools.Visible = on
    divider.Visible = on
    hint.Visible = on
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

-- ===== Ввод =====
local TOOL_KEYS = {
    [Enum.KeyCode.One] = "straight",
    [Enum.KeyCode.Two] = "curve",
    [Enum.KeyCode.Three] = "ramp",
    [Enum.KeyCode.Four] = "erase",
    [Enum.KeyCode.Five] = "cart",
}

UserInputService.LastInputTypeChanged:Connect(function(t)
    lastInputTouch = (t == Enum.UserInputType.Touch)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    local t = input.UserInputType
    if t == Enum.UserInputType.Touch then
        touchPos = input.Position -- на телефоне тап двигает призрак, ставим кнопкой в панели
    elseif t == Enum.UserInputType.MouseButton1 then
        if buildMode then
            holding = (tool ~= "cart")
            doAction(false)
        end
    elseif input.KeyCode == Enum.KeyCode.R then
        if buildMode and isPlacing(tool) then
            rotate(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 1)
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
        setTool(TOOL_KEYS[input.KeyCode])
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
        if tool == "erase" or tool == "cart" then
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
