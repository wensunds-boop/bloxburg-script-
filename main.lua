--!nocheck
--[[=====================================================================
  Venice Speed Suite  v1.5  ·  Bloxburg client tuning suite
  Author: Venice · MIT
  ---------------------------------------------------------------------
  CLIENT-SIDE ONLY. The server stays authoritative.
  KICK: Player:Kick() from a client is a request, not a server ban.
  The script verifies after 1.5s and falls back to local removal,
  reporting honestly which of the two actually happened.
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local StarterGui       = game:GetService("StarterGui")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)

if not PlayerGui then
    return warn("[Venice] PlayerGui never appeared.")
end

local function log(m) print("[Venice] " .. m) end

--=====================================================================
-- CONFIG
--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    ui      = { accent = Color3.fromRGB(94, 141, 255), keybind = Enum.KeyCode.K },
}

local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == "table" and deepCopy(v) or v
    end
    return out
end

local state = deepCopy(DEFAULTS)
local hasFS = pcall(function() return writefile ~= nil end)

local function num(v, fallback, min, max)
    if type(v) ~= "number" or v ~= v then return fallback end
    return math.clamp(v, min, max)
end

local function loadConfig()
    if not hasFS then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" or #raw < 2 then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end

    local p = data.player
    if type(p) == "table" then
        if type(p.enabled) == "boolean" then state.player.enabled = p.enabled end
        state.player.speed = num(p.speed, DEFAULTS.player.speed, 16, 300)
        if type(p.jumpEnabled) == "boolean" then state.player.jumpEnabled = p.jumpEnabled end
        state.player.jump = num(p.jump, DEFAULTS.player.jump, 30, 220)
    end

    local v = data.vehicle
    if type(v) == "table" then
        if type(v.enabled) == "boolean" then state.vehicle.enabled = v.enabled end
        state.vehicle.maxSpeed = num(v.maxSpeed, DEFAULTS.vehicle.maxSpeed, 30, 600)
        state.vehicle.accel = num(v.accel, DEFAULTS.vehicle.accel, 20, 600)
        state.vehicle.brake = num(v.brake, DEFAULTS.vehicle.brake, 40, 900)
        if type(v.assist) == "boolean" then state.vehicle.assist = v.assist end
    end

    local l = data.limits
    if type(l) == "table" then
        if type(l.enabled) == "boolean" then state.limits.enabled = l.enabled end
        state.limits.global = num(l.global, DEFAULTS.limits.global, 16, 300)
        if type(l.zones) == "table" then
            local clean = {}
            for _, z in ipairs(l.zones) do
                if #clean >= MAX_ZONES then break end
                if type(z) == "table" and type(z.min) == "table"
                    and type(z.max) == "table" and type(z.limit) == "number" then
                    table.insert(clean, {
                        name = type(z.name) == "string" and z.name or "Zone",
                        min = { X = z.min.X or 0, Y = z.min.Y or 0, Z = z.min.Z or 0 },
                        max = { X = z.max.X or 0, Y = z.max.Y or 0, Z = z.max.Z or 0 },
                        limit = math.clamp(z.limit, 5, 300),
                    })
                end
            end
            state.limits.zones = clean
        end
    end

    local u = data.ui
    if type(u) == "table" then
        if type(u.accent) == "table" then
            local okc, c = pcall(Color3.fromRGB,
                u.accent[1] or 94, u.accent[2] or 141, u.accent[3] or 255)
            if okc then state.ui.accent = c end
        end
        if type(u.keybind) == "string" then
            local oke, key = pcall(function() return Enum.KeyCode[u.keybind] end)
            if oke and key then state.ui.keybind = key end
        end
    end
end

local function snapshot()
    return {
        player  = { enabled = state.player.enabled, speed = state.player.speed,
                    jumpEnabled = state.player.jumpEnabled, jump = state.player.jump },
        vehicle = { enabled = state.vehicle.enabled, maxSpeed = state.vehicle.maxSpeed,
                    accel = state.vehicle.accel, brake = state.vehicle.brake,
                    assist = state.vehicle.assist },
        limits  = { enabled = state.limits.enabled, global = state.limits.global,
                    zones = state.limits.zones },
        ui      = {
            accent = {
                math.floor(state.ui.accent.R * 255 + 0.5),
                math.floor(state.ui.accent.G * 255 + 0.5),
                math.floor(state.ui.accent.B * 255 + 0.5),
            },
            keybind = state.ui.keybind.Name,
        },
    }
end

local saveToken = 0
local function saveConfig()
    if not hasFS then return end
    saveToken += 1
    local mine = saveToken
    task.delay(0.6, function()
        if mine ~= saveToken then return end
        local ok, encoded = pcall(function() return HttpService:JSONEncode(snapshot()) end)
        if ok then pcall(writefile, CONFIG_FILE, encoded) end
    end)
end

loadConfig()

--=====================================================================
-- BOOKKEEPING
--=====================================================================
local connections = {}
local function track(c)
    table.insert(connections, c)
    return c
end

local accentTargets = {}
local function acc(inst, prop)
    table.insert(accentTargets, { inst = inst, prop = prop })
    return inst
end

local generation = 0
local clearAssistRig
local rebuild

local function teardown()
    generation += 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    table.clear(accentTargets)
    if clearAssistRig then pcall(clearAssistRig) end
    local rec = _G.__VeniceSpeedSuite
    if rec and rec.gui then pcall(function() rec.gui:Destroy() end) end
    _G.__VeniceSpeedSuite = nil
end

--=====================================================================
-- HELPERS
--=====================================================================
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = parent or props.Parent
    return inst
end

local function tw(inst, dur, props, style)
    local t = TweenService:Create(
        inst,
        TweenInfo.new(dur, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function corner(inst, px)
    return new("UICorner", { CornerRadius = UDim.new(0, px or 10) }, inst)
end

local function stroke(inst, color, thickness, transparency)
    return new("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
end

local function getHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

--=====================================================================
-- PALETTE
--=====================================================================
local C = {
    bg      = Color3.fromRGB(12, 14, 19),
    panel   = Color3.fromRGB(18, 21, 28),
    card    = Color3.fromRGB(26, 30, 39),
    cardAlt = Color3.fromRGB(32, 37, 48),
    stroke  = Color3.fromRGB(43, 49, 63),
    track   = Color3.fromRGB(38, 43, 55),
    text    = Color3.fromRGB(233, 237, 245),
    dim     = Color3.fromRGB(132, 142, 160),
    good    = Color3.fromRGB(88, 214, 141),
    warn    = Color3.fromRGB(255, 186, 84),
    bad     = Color3.fromRGB(255, 106, 106),
}

--=====================================================================
-- FALLBACK
--=====================================================================
local function buildFallback(err)
    pcall(function()
        local g = new("ScreenGui", { Name = "VeniceFallback", ResetOnSpawn = false }, PlayerGui)
        local f = new("Frame", {
            Size = UDim2.new(0, 340, 0, 90),
            Position = UDim2.new(0.5, -170, 0.5, -45),
            BackgroundColor3 = Color3.fromRGB(20, 20, 26),
            BorderSizePixel = 0,
        }, g)
        corner(f, 10)
        new("TextLabel", {
            Size = UDim2.new(1, -20, 0, 60),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextWrapped = true,
            TextColor3 = Color3.fromRGB(255, 140, 140),
            Text = "GUI kunde inte byggas:\n" .. tostring(err),
        }, f)
        log("fallback GUI visad")
    end)
end

--=====================================================================
-- BUILD
--=====================================================================
local WIN_W, WIN_H = 430, 540
local PAGE_CANVAS = 820

local function buildGUI()
    local myGen = generation

    log("1 shell")
    local gui = new("ScreenGui", {
        Name = "VeniceSpeedSuite",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 5000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    _G.__VeniceSpeedSuite = { gui = gui, teardown = teardown }

    local win = new("Frame", {
        Name = "Window",
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    corner(win, 14)
    stroke(win, C.stroke, 1)

    log("2 header")
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, win)

    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.stroke,
        BorderSizePixel = 0,
    }, header)

    local accentBar = new("Frame", {
        Size = UDim2.new(0, 34, 0, 3),
        Position = UDim2.new(0, 18, 0, 34),
        BackgroundColor3 = state.ui.accent,
        BorderSizePixel = 0,
    }, header)
    corner(accentBar, 2)
    acc(accentBar, "BackgroundColor3")

    new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 20),
        Position = UDim2.new(0, 18, 0, 12),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Venice Speed Suite",
    }, header)

    new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 14),
        Position = UDim2.new(0, 18, 0, 32),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Bloxburg · v1.5",
    }, header)

    local function headerButton(glyph, xOffset, color)
        local btn = new("TextButton", {
            Size = UDim2.new(0, 26, 0, 26),
            Position = UDim2.new(1, xOffset, 0, 13),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = color or C.dim,
            Text = glyph,
        }, header)
        corner(btn, 8)
        return btn
    end

    local minBtn   = headerButton("–", -68, C.dim)
    local closeBtn = headerButton("×", -36, C.bad)

    log("3 drag")
    local dragging, dragOffset = false, nil

    track(header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragOffset = Vector2.new(input.Position.X, input.Position.Y) - win.AbsolutePosition
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local vp = viewport()
        local x = math.clamp(input.Position.X - dragOffset.X, -WIN_W + 90, vp.X - 90)
        local y = math.clamp(input.Position.Y - dragOffset.Y, 0, vp.Y - 46)
        win.Position = UDim2.new(0, x, 0, y)
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    log("4 toasts")
    local toastHolder = new("Frame", {
        Size = UDim2.new(0, 250, 1, -80),
        Position = UDim2.new(1, -262, 0, 64),
        BackgroundTransparency = 1,
    }, gui)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 6),
    }, toastHolder)

    local function renderToast(text, kind)
        local color = kind == "bad" and C.bad or kind == "good" and C.good or state.ui.accent
        local box = new("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, toastHolder)
        corner(box, 8)
        new("Frame", {
            Size = UDim2.new(0, 3, 1, -12),
            Position = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
        }, box)
        new("TextLabel", {
            Size = UDim2.new(1, -22, 1, 0),
            Position = UDim2.new(0, 16, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextWrapped = true,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
        }, box)
        task.delay(2.6, function()
            if not box.Parent then return end
            local t = tw(box, 0.2, { BackgroundTransparency = 1 })
            t.Completed:Connect(function() box:Destroy() end)
        end)
    end

    local notifyQueue = {}
    local function notify(text, kind)
        table.insert(notifyQueue, { text = text, kind = kind })
    end
    task.spawn(function()
        while gui.Parent do
            task.wait(0.08)
            if #notifyQueue > 0 then
                local batch = notifyQueue
                notifyQueue = {}
                for _, item in ipairs(batch) do
                    pcall(renderToast, item.text, item.kind)
                end
            end
        end
    end)

    log("5 tabs")
    local tabBar = new("Frame", {
        Size = UDim2.new(1, -28, 0, 34),
        Position = UDim2.new(0, 14, 0, 62),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, win)
    corner(tabBar, 9)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }, tabBar)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingTop = UDim.new(0, 4),
    }, tabBar)

    local content = new("Frame", {
        Size = UDim2.new(1, -28, 1, -160),
        Position = UDim2.new(0, 14, 0, 104),
        BackgroundTransparency = 1,
    }, win)

    local pages, tabButtons = {}, {}

    local function buildTab(name, order)
        local btn = new("TextButton", {
            Size = UDim2.new(0, #name * 6 + 26, 1, -8),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = order,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = C.dim,
            Text = name,
        }, tabBar)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 11),
            PaddingRight = UDim.new(0, 11),
        }, btn)
        corner(btn, 7)

        local page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.stroke,
            CanvasSize = UDim2.new(0, 0, 0, PAGE_CANVAS),
            Visible = false,
        }, content)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        }, page)
        new("UIPadding", { PaddingBottom = UDim.new(0, 14) }, page)

        pages[name] = page
        tabButtons[name] = btn

        track(btn.MouseButton1Click:Connect(function()
            for other, p in pairs(pages) do
                p.Visible = (other == name)
                pcall(function()
                    tabButtons[other].BackgroundColor3 = other == name and C.card or C.panel
                    tabButtons[other].TextColor3 = other == name and C.text or C.dim
                end)
            end
        end))
        return page
    end

    local playerPage   = buildTab("Player", 1)
    local vehiclePage  = buildTab("Vehicle", 2)
    local playersPage  = buildTab("Players", 3)
    local settingsPage = buildTab("Settings", 4)

    ---------------------------------------------------------------
    -- widget factories
    ---------------------------------------------------------------
    local function card(parent, height, order)
        local box = new("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            LayoutOrder = order,
        }, parent)
        corner(box, 10)
        return box
    end

    local function sectionLabel(parent, text, y)
        return new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 12),
            Position = UDim2.new(0, 12, 0, y or 10),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(text),
        }, parent)
    end

    local function createSlider(parent, cfg)
        local row = new("Frame", {
            Size = UDim2.new(1, -24, 0, 46),
            Position = UDim2.new(0, 12, 0, cfg.y or 0),
            BackgroundTransparency = 1,
        }, parent)

        local head = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1 }, row)

        new("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = cfg.label,
        }, head)

        local valLabel = new("TextLabel", {
            Size = UDim2.new(0, 80, 1, 0),
            Position = UDim2.new(1, -80, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = state.ui.accent,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "",
        }, head)
        acc(valLabel, "TextColor3")

        local trackFrame = new("Frame", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 0, 28),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
        }, row)
        corner(trackFrame, 3)

        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = state.ui.accent,
            BorderSizePixel = 0,
        }, trackFrame)
        corner(fill, 3)
        acc(fill, "BackgroundColor3")

        local knob = new("Frame", {
            Size = UDim2.new(0, 14, 0, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 2,
        }, trackFrame)
        corner(knob, 7)

        local hit = new("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            Position = UDim2.new(0, 0, 0.5, -12),
            BackgroundTransparency = 1,
            ZIndex = 3,
        }, trackFrame)

        local value = math.clamp(cfg.value, cfg.min, cfg.max)

        local function render()
            local a = (value - cfg.min) / math.max(cfg.max - cfg.min, 1e-6)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            valLabel.Text = cfg.format and cfg.format(value) or tostring(value)
        end

        local function setValue(v, fire)
            v = math.clamp(math.floor(v / cfg.step + 0.5) * cfg.step, cfg.min, cfg.max)
            if v == value then return end
            value = v
            render()
            if fire and cfg.onChanged then cfg.onChanged(value) end
        end

        local holding = false
        local function fromX(x)
            local w = trackFrame.AbsoluteSize.X
            if w <= 0 then return end
            setValue(cfg.min + math.clamp((x - trackFrame.AbsolutePosition.X) / w, 0, 1)
                * (cfg.max - cfg.min), true)
        end

        track(hit.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                holding = true
                fromX(i.Position.X)
            end
        end))
        track(UserInputService.InputChanged:Connect(function(i)
            if not holding then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then
                fromX(i.Position.X)
            end
        end))
        track(UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                holding = false
            end
        end))

        render()
        return { set = function(v) setValue(v, false) end, get = function() return value end }
    end

    local function createToggle(parent, cfg)
        local row = new("Frame", {
            Size = UDim2.new(1, -24, 0, 30),
            Position = UDim2.new(0, 12, 0, cfg.y or 0),
            BackgroundTransparency = 1,
        }, parent)

        new("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = cfg.label,
        }, row)

        local pill = new("TextButton", {
            Size = UDim2.new(0, 40, 0, 20),
            Position = UDim2.new(1, -40, 0.5, -10),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        }, row)
        corner(pill, 10)

        local dot = new("Frame", {
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 3, 0.5, -7),
            BackgroundColor3 = C.dim,
            BorderSizePixel = 0,
        }, pill)
        corner(dot, 7)

        local on = cfg.value and true or false
        local function render()
            pill.BackgroundColor3 = on and state.ui.accent or C.track
            dot.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            dot.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
        render()

        track(pill.MouseButton1Click:Connect(function()
            on = not on
            render()
            if cfg.onChanged then cfg.onChanged(on) end
        end))

        return { get = function() return on end, set = function(v) on = v and true or false; render() end }
    end

    local function actionButton(parent, cfg)
        local btn = new("TextButton", {
            Size = UDim2.new(1, -24, 0, 32),
            Position = UDim2.new(0, 12, 0, cfg.y or 0),
            BackgroundColor3 = cfg.danger and Color3.fromRGB(48, 26, 30) or C.cardAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = cfg.danger and C.bad or C.text,
            Text = cfg.label,
        }, parent)
        corner(btn, 8)
        track(btn.MouseButton1Click:Connect(function()
            if cfg.onClick then
                local ok, err = pcall(cfg.onClick)
                if not ok then notify(tostring(err), "bad") end
            end
        end))
        return btn
    end

    local function readout(parent, order, labelText)
        local box = new("Frame", {
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            LayoutOrder = order,
        }, parent)
        corner(box, 8)

        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 14),
            Position = UDim2.new(0, 12, 0, 6),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 9,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(labelText),
        }, box)

        local valueLabel = new("TextLabel", {
            Size = UDim2.new(1, -150, 0, 18),
            Position = UDim2.new(0, 12, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "—",
        }, box)

        local badge = new("TextLabel", {
            Size = UDim2.new(0, 126, 0, 16),
            Position = UDim2.new(1, -138, 0, 23),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextColor3 = C.warn,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "",
        }, box)

        return valueLabel, badge
    end

    ---------------------------------------------------------------
    -- engine state (declared before page stages)
    ---------------------------------------------------------------
    local jumpForced = false
    local rig = { part = nil, attachment = nil, force = nil }
    local assist = {
        mode = "detect", timer = 0, seat = nil, lastSeat = nil, seats = {},
        applied = nil, writeTimer = 0,
        direct = false, probe = 0, probeFrom = 0,
        primary = nil, anchored = false, lastNote = 0,
    }
    local selected = {}

    clearAssistRig = function()
        if rig.force then pcall(function() rig.force:Destroy() end) end
        if rig.attachment then pcall(function() rig.attachment:Destroy() end) end
        rig.force, rig.attachment, rig.part = nil, nil, nil
    end

    local function zoneLimitAt(pos)
        if not state.limits.enabled then return nil end
        for _, zone in ipairs(state.limits.zones) do
            local mn, mx = zone.min, zone.max
            if pos.X >= math.min(mn.X, mx.X) and pos.X <= math.max(mn.X, mx.X)
                and pos.Y >= math.min(mn.Y, mx.Y) and pos.Y <= math.max(mn.Y, mx.Y)
                and pos.Z >= math.min(mn.Z, mx.Z) and pos.Z <= math.max(mn.Z, mx.Z) then
                return zone.limit
            end
        end
        return state.limits.global
    end

    local function applyPlayer()
        local hum = getHumanoid()
        if not hum or hum.Health <= 0 then return end

        local root = getRoot()
        local limit = root and zoneLimitAt(root.Position) or nil
        local target = state.player.speed
        if limit then target = math.min(target, limit) end

        if state.player.enabled and math.abs(hum.WalkSpeed - target) > 0.05 then
            pcall(function() hum.WalkSpeed = target end)
        end

        if state.player.jumpEnabled then
            if not jumpForced then
                jumpForced = true
                pcall(function() hum.UseJumpPower = true end)
            end
            if math.abs(hum.JumpPower - state.player.jump) > 0.05 then
                pcall(function() hum.JumpPower = state.player.jump end)
            end
        else
            jumpForced = false
        end

        local u = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.updatePlayerReadout
        if u then u(hum.WalkSpeed, limit) end
    end

    local function getVehicle()
        local hum = getHumanoid()
        if not hum or not hum.SeatPart then return nil end
        local seat = hum.SeatPart
        local model = seat:FindFirstAncestorOfClass("Model")
        if not model then return nil end
        local depth = 0
        while model.Parent and model.Parent ~= workspace and depth < 4 do
            local up = model.Parent:FindFirstAncestorOfClass("Model")
            if not up then break end
            model = up
            depth += 1
        end
        return model, seat
    end

    local function pickPrimary(model, seat)
        local okRoot, assemblyRoot = pcall(function() return seat.AssemblyRootPart end)
        if okRoot and assemblyRoot and assemblyRoot.Parent and not assemblyRoot.Anchored
            and not assemblyRoot:IsA("Seat") and not assemblyRoot:IsA("VehicleSeat") then
            return assemblyRoot
        end
        local best, bestScore = nil, -1
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and not d.Anchored
                and not d:IsA("Seat") and not d:IsA("VehicleSeat") then
                local n = d.Name:lower()
                local wheel = n:find("wheel") or n:find("tire")
                    or n:find("tyre") or n:find("rim")
                local score = d.AssemblyMass * (wheel and 0.2 or 1)
                if score > bestScore then best, bestScore = d, score end
            end
        end
        return best or model.PrimaryPart or assemblyRoot
    end

    local function ensureRig(part)
        if rig.part == part and rig.force and rig.force.Parent then return true end
        clearAssistRig()
        local ok = pcall(function()
            local att = new("Attachment", { Name = "VeniceAssistAtt" }, part)
            local lv = new("LinearVelocity", {
                Name = "VeniceAssist",
                Attachment0 = att,
                VelocityConstraintMode = Enum.VelocityConstraintMode.Line,
                RelativeTo = Enum.ActuatorRelativeTo.World,
                MaxForce = 0,
            }, part)
            rig.part, rig.attachment, rig.force = part, att, lv
        end)
        return ok and rig.force ~= nil and rig.force.Parent ~= nil
    end

    local function cacheSeats(model)
        table.clear(assist.seats)
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("VehicleSeat") then table.insert(assist.seats, d) end
        end
    end

    local function resetAssist()
        assist.mode, assist.timer = "detect", 0
        assist.seat, assist.lastSeat = nil, nil
        assist.applied, assist.writeTimer = nil, 0
        assist.direct, assist.probe = false, 0
        assist.primary, assist.anchored = nil, false
        table.clear(assist.seats)
        clearAssistRig()
    end

    local function applyVehicle(dt)
        local model, seat = getVehicle()
        local u = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.updateVehicleReadout

        if not model then
            if assist.lastSeat ~= nil then
                assist.lastSeat = nil
                resetAssist()
            end
            if u then u(nil, 0) end
            return
        end

        if assist.lastSeat ~= seat then
            assist.lastSeat = seat
            assist.seat, assist.mode, assist.timer = seat, "detect", 0
            assist.applied, assist.writeTimer = nil, 0
            assist.direct, assist.probe = false, 0
            clearAssistRig()
            cacheSeats(model)
            local okPick, picked = pcall(pickPrimary, model, seat)
            assist.primary = okPick and picked or nil
            assist.anchored = assist.primary ~= nil and assist.primary.Anchored
            if assist.anchored and os.clock() - assist.lastNote > 3 then
                assist.lastNote = os.clock()
                notify("Bilen har anchrade delar — fart går ej att ändra", "bad")
            end
        end

        local primary = assist.primary
        if not primary or not primary.Parent then
            local okPick, picked = pcall(pickPrimary, model, seat)
            primary = okPick and picked or nil
            assist.primary = primary
            assist.anchored = primary ~= nil and primary.Anchored
        end

        local velocity = Vector3.zero
        if primary then
            local okV, v = pcall(function() return primary.AssemblyLinearVelocity end)
            if okV and typeof(v) == "Vector3" then velocity = v end
        end
        local speed = velocity.Magnitude

        local method = assist.anchored and "anchrad"
            or (assist.direct and "direkt" or "constraint")
        local info = string.format("metod: %s · %d säten", method, #assist.seats)

        if not state.vehicle.enabled then
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if u then u(model.Name, speed, nil, info) end
            return
        end

        assist.writeTimer -= dt
        if assist.writeTimer <= 0 or assist.applied ~= state.vehicle.maxSpeed then
            assist.writeTimer = 0.25
            assist.applied = state.vehicle.maxSpeed
            pcall(function()
                for _, s in ipairs(assist.seats) do
                    s.MaxSpeed = state.vehicle.maxSpeed
                    s.MaxTorque = math.max(60000, state.vehicle.maxSpeed * 1400)
                end
                model:SetAttribute("MaxSpeed", state.vehicle.maxSpeed)
            end)
        end

        if not state.vehicle.assist or not primary or assist.anchored then
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if u then u(model.Name, speed, nil, info) end
            return
        end

        local throttle = 0
        if seat:IsA("VehicleSeat") then
            local okT, raw = pcall(function() return seat.ThrottleFloat end)
            if okT and type(raw) == "number" then throttle = raw end
        end

        assist.timer += dt
        if math.abs(throttle) > 0.02 then
            assist.mode = "throttle"
        elseif assist.mode == "detect" and assist.timer > 1.2 then
            assist.mode = "hold"
        end

        local okF, forward = pcall(function() return primary.CFrame.LookVector end)
        if not okF or typeof(forward) ~= "Vector3" then
            if u then u(model.Name, speed, nil, info) end
            return
        end

        local forwardSpeed = velocity:Dot(forward)
        local desired
        if assist.mode == "throttle" then
            desired = throttle * state.vehicle.maxSpeed
        elseif forwardSpeed > 0.05 then
            desired = state.vehicle.maxSpeed
        elseif forwardSpeed < -0.05 then
            desired = -state.vehicle.maxSpeed
        else
            desired = 0
        end

        local increasing = math.abs(desired) > math.abs(forwardSpeed)
        local rate = increasing and state.vehicle.accel or state.vehicle.brake
        local step = math.clamp(desired - forwardSpeed, -rate * dt, rate * dt)
        local engaged = math.abs(step) > 0.01

        if engaged and increasing and not assist.direct then
            if assist.probe == 0 then
                assist.probe = 0.0001
                assist.probeFrom = forwardSpeed
            else
                assist.probe += dt
                if assist.probe > 1.0 then
                    if math.abs(forwardSpeed - assist.probeFrom) < 2 then
                        assist.direct = true
                        notify("Assist: ingen effekt — byter metod", "bad")
                    end
                    assist.probe = 0
                end
            end
        elseif not increasing then
            assist.probe = 0
        end

        if not assist.direct and ensureRig(primary) then
            rig.force.LineDirection = forward
            rig.force.LineVelocity = forwardSpeed + step
            rig.force.MaxForce = engaged
                and math.max(primary.AssemblyMass * rate * 2, 12000)
                or 0
        else
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if engaged then
                local nv = forward * (forwardSpeed + step) + Vector3.new(0, velocity.Y, 0)
                pcall(function() primary.AssemblyLinearVelocity = nv end)
            end
        end

        if u then u(model.Name, speed, assist.mode, info) end
    end

    ---------------------------------------------------------------
    -- PAGE STAGES
    ---------------------------------------------------------------
    local speedSlider

    local function stagePlayer()
        log("6 player page")
        local head = card(playerPage, 118, 1)
        sectionLabel(head, "Player movement", 10)

        createToggle(head, {
            label = "Enable player tuning",
            y = 28,
            value = state.player.enabled,
            onChanged = function(v)
                state.player.enabled = v
                saveConfig()
                notify(v and "Player tuning enabled" or "Player tuning disabled", v and "good" or nil)
                if not v then
                    local hum = getHumanoid()
                    if hum then pcall(function() hum.WalkSpeed = 16 end) end
                end
            end,
        })

        speedSlider = createSlider(head, {
            label = "Walk speed",
            min = 16, max = 300, step = 1,
            value = state.player.speed,
            y = 60,
            format = function(v) return v .. " st/s" end,
            onChanged = function(v) state.player.speed = v; saveConfig() end,
        })

        local live, badge = readout(playerPage, 2, "Effective walk speed")
        live.Text = "16.0 st/s"

        local jumpCard = card(playerPage, 88, 3)
        sectionLabel(jumpCard, "Jump", 10)
        createToggle(jumpCard, {
            label = "Override jump power",
            y = 28,
            value = state.player.jumpEnabled,
            onChanged = function(v) state.player.jumpEnabled = v; saveConfig() end,
        })
        createSlider(jumpCard, {
            label = "Jump power",
            min = 30, max = 220, step = 1,
            value = state.player.jump,
            y = 56,
            onChanged = function(v) state.player.jump = v; saveConfig() end,
        })

        local resetCard = card(playerPage, 80, 4)
        actionButton(resetCard, {
            label = "Reset to defaults (speed 16, jump 50)",
            y = 10,
            onClick = function()
                state.player.speed = 16
                state.player.jump = 50
                speedSlider.set(16)
                saveConfig()
                local hum = getHumanoid()
                if hum then
                    pcall(function()
                        hum.WalkSpeed = 16
                        hum.UseJumpPower = true
                        hum.JumpPower = 50
                    end)
                end
                notify("Player settings reset", "good")
            end,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 28),
            Position = UDim2.new(0, 12, 0, 48),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 9,
            TextWrapped = true,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Server stays authoritative. Values above ~250 may rubber-band.",
        }, resetCard)

        _G.__VeniceSpeedSuite.updatePlayerReadout = function(current, limit)
            live.Text = string.format("%.1f st/s", current)
            live.TextColor3 = limit and C.warn or C.text
            badge.Text = limit and ("ZONE LIMIT " .. limit) or ""
        end
    end

    local detectLabel, vehSpeed, vehInfo

    local function stageVehicle()
        log("7 vehicle page")
        local detect = card(vehiclePage, 90, 1)
        sectionLabel(detect, "Vehicle detection", 10)

        detectLabel = new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 18),
            Position = UDim2.new(0, 12, 0, 28),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Not seated",
        }, detect)

        vehSpeed = new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 14),
            Position = UDim2.new(0, 12, 0, 50),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "0.0 st/s",
        }, detect)

        vehInfo = new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 14),
            Position = UDim2.new(0, 12, 0, 68),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 9,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "metod: —",
        }, detect)

        local main = card(vehiclePage, 152, 2)
        sectionLabel(main, "Vehicle tuning", 10)
        createToggle(main, {
            label = "Enable vehicle tuning",
            y = 26,
            value = state.vehicle.enabled,
            onChanged = function(v)
                state.vehicle.enabled = v
                saveConfig()
                notify(v and "Vehicle tuning enabled" or "Vehicle tuning disabled", v and "good" or nil)
            end,
        })
        createSlider(main, {
            label = "Max speed",
            min = 30, max = 600, step = 5,
            value = state.vehicle.maxSpeed,
            y = 56,
            format = function(v) return v .. " st/s" end,
            onChanged = function(v) state.vehicle.maxSpeed = v; saveConfig() end,
        })
        createSlider(main, {
            label = "Acceleration",
            min = 20, max = 600, step = 5,
            value = state.vehicle.accel,
            y = 98,
            format = function(v) return v .. " st/s²" end,
            onChanged = function(v) state.vehicle.accel = v; saveConfig() end,
        })

        local brakeCard = card(vehiclePage, 104, 3)
        sectionLabel(brakeCard, "Braking", 10)
        createSlider(brakeCard, {
            label = "Brake force",
            min = 40, max = 900, step = 10,
            value = state.vehicle.brake,
            y = 28,
            format = function(v) return v .. " st/s²" end,
            onChanged = function(v) state.vehicle.brake = v; saveConfig() end,
        })
        createToggle(brakeCard, {
            label = "Physics assist (recommended)",
            y = 70,
            value = state.vehicle.assist,
            onChanged = function(v)
                state.vehicle.assist = v
                saveConfig()
                notify(v and "Assist on" or "Assist off — bara fältskrivning", nil)
            end,
        })

        local resetVeh = card(vehiclePage, 56, 4)
        actionButton(resetVeh, {
            label = "Reset vehicle settings",
            y = 10,
            onClick = function()
                state.vehicle.maxSpeed = DEFAULTS.vehicle.maxSpeed
                state.vehicle.accel = DEFAULTS.vehicle.accel
                state.vehicle.brake = DEFAULTS.vehicle.brake
                saveConfig()
                rebuild()
            end,
        })

        _G.__VeniceSpeedSuite.updateVehicleReadout = function(name, speed, mode, info)
            detectLabel.Text = name and ("Detected: " .. name) or "Not seated"
            detectLabel.TextColor3 = name and C.good or C.dim
            vehSpeed.Text = string.format("%.1f st/s", speed)
            vehSpeed.TextColor3 = speed > 0.5 and C.text or C.dim
            vehInfo.Text = info or "metod: —"
            vehInfo.TextColor3 = (info and info:find("anchrad")) and C.bad or C.dim
        end
    end

    local refreshPlayers

    local function stagePlayers()
        log("8 players page")
        local head = card(playersPage, 148, 1)
        sectionLabel(head, "Server", 10)

        local countLabel = new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 16),
            Position = UDim2.new(0, 12, 0, 28),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "—",
        }, head)

        local function smallButton(label, x, y, w, onClick, danger)
            local b = new("TextButton", {
                Size = UDim2.new(0, w, 0, 26),
                Position = UDim2.new(0, x, 0, y),
                BackgroundColor3 = danger and Color3.fromRGB(48, 26, 30) or C.cardAlt,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextColor3 = danger and C.bad or C.text,
                Text = label,
            }, head)
            corner(b, 6)
            b.MouseButton1Click:Connect(function() pcall(onClick) end)
            return b
        end

        smallButton("Select all", 12, 50, 108, function()
            table.clear(selected)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then selected[p.UserId] = true end
            end
            refreshPlayers()
        end)
        smallButton("Clear", 128, 50, 70, function()
            table.clear(selected)
            refreshPlayers()
        end)
        smallButton("Kick selected", 206, 50, 118, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and selected[p.UserId] then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice Speed Suite") end)
                end
            end
            if n == 0 then return notify("Ingen markerad", "bad") end
            notify("Kick skickat till " .. n .. " spelare", "good")
            task.delay(1.6, refreshPlayers)
        end, true)

        smallButton("Kick everyone else", 12, 84, 200, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice Speed Suite") end)
                end
            end
            notify(n > 0 and ("Kick skickat till " .. n) or "Ingen att kicka",
                n > 0 and "good" or "bad")
            task.delay(1.6, refreshPlayers)
        end)

        local listCard = card(playersPage, 230, 2)
        sectionLabel(listCard, "Spelare", 10)

        local list = new("ScrollingFrame", {
            Size = UDim2.new(1, -24, 0, 188),
            Position = UDim2.new(0, 12, 0, 30),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.stroke,
            CanvasSize = UDim2.new(0, 0, 0, 188),
        }, listCard)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
        }, list)

        refreshPlayers = function()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
            end

            local all = Players:GetPlayers()
            countLabel.Text = string.format("%d i servern · du är %s", #all, LP.Name)

            local shown = 0
            for _, plr in ipairs(all) do
                if plr ~= LP then
                    shown += 1
                    local on = selected[plr.UserId] and true or false

                    local row = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = C.panel,
                        BorderSizePixel = 0,
                        LayoutOrder = shown,
                    }, list)
                    corner(row, 6)

                    local box = new("TextButton", {
                        Size = UDim2.new(0, 16, 0, 16),
                        Position = UDim2.new(0, 6, 0.5, -8),
                        BackgroundColor3 = on and state.ui.accent or C.track,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = on and "✓" or "",
                        Font = Enum.Font.GothamBold,
                        TextSize = 10,
                        TextColor3 = Color3.new(1, 1, 1),
                    }, row)
                    corner(box, 4)
                    box.MouseButton1Click:Connect(function()
                        selected[plr.UserId] = not selected[plr.UserId] or nil
                        refreshPlayers()
                    end)

                    new("TextLabel", {
                        Size = UDim2.new(1, -92, 1, 0),
                        Position = UDim2.new(0, 28, 0, 0),
                        BackgroundTransparency = 1,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 10,
                        TextColor3 = C.text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = string.format("%s  (%s)", plr.DisplayName, plr.Name),
                    }, row)

                    local kb = new("TextButton", {
                        Size = UDim2.new(0, 46, 0, 18),
                        Position = UDim2.new(1, -52, 0.5, -9),
                        BackgroundColor3 = Color3.fromRGB(48, 26, 30),
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Font = Enum.Font.GothamBold,
                        TextSize = 9,
                        TextColor3 = C.bad,
                        Text = "kick",
                    }, row)
                    corner(kb, 5)
                    kb.MouseButton1Click:Connect(function()
                        pcall(function() plr:Kick("Kickad av Venice Speed Suite") end)
                        notify("Kick skickat till " .. plr.Name, "good")
                        task.delay(1.6, refreshPlayers)
                    end)
                end
            end

            list.CanvasSize = UDim2.new(0, 0, 0, math.max(188, shown * 30 + 8))

            if shown == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 10,
                    TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "Du är ensam i servern.",
                }, list)
            end
        end
        refreshPlayers()

        track(Players.PlayerAdded:Connect(function() task.delay(0.5, refreshPlayers) end))
        track(Players.PlayerRemoving:Connect(function()
            task.delay(0.5, refreshPlayers)
        end))
        track(tabButtons.Players.MouseButton1Click:Connect(refreshPlayers))

        task.spawn(function()
            while gui.Parent do
                task.wait(3)
                if playersPage.Visible then pcall(refreshPlayers) end
            end
        end)

        local note = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 9,
            TextWrapped = true,
            TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Kick skickas från din klient och tas bort lokalt om servern "
                .. "lägger tillbaka spelaren. Det är inte en ban.",
        }, playersPage)
        note.LayoutOrder = 3
    end

    local function stageSettings()
        log("9 settings page")
        local limits = card(settingsPage, 110, 1)
        sectionLabel(limits, "Speed limits", 10)
        createToggle(limits, {
            label = "Enforce speed limits",
            y = 26,
            value = state.limits.enabled,
            onChanged = function(v)
                state.limits.enabled = v
                saveConfig()
                notify(v and "Limits armed" or "Limits off", nil)
            end,
        })
        createSlider(limits, {
            label = "Default limit (outside zones)",
            min = 16, max = 300, step = 1,
            value = state.limits.global,
            y = 58,
            format = function(v) return v .. " st/s" end,
            onChanged = function(v) state.limits.global = v; saveConfig() end,
        })

        local zoneCard = card(settingsPage, 172, 2)
        sectionLabel(zoneCard, "Zones", 10)

        local addBtn = new("TextButton", {
            Size = UDim2.new(1, -162, 0, 26),
            Position = UDim2.new(0, 12, 0, 26),
            BackgroundColor3 = C.cardAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  Add zone here",
        }, zoneCard)
        corner(addBtn, 7)

        local function field(xOffset, ph, dt)
            local b = new("TextBox", {
                Size = UDim2.new(0, 62, 0, 26),
                Position = UDim2.new(1, xOffset, 0, 26),
                BackgroundColor3 = C.panel,
                BorderSizePixel = 0,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                TextColor3 = C.text,
                PlaceholderText = ph,
                Text = dt,
                ClearTextOnFocus = false,
                ZIndex = 2,
            }, zoneCard)
            corner(b, 6)
            return b
        end

        local limitBox  = field(-142, "limit", "60")
        local radiusBox = field(-74, "radius", "45")

        local zoneList = new("ScrollingFrame", {
            Size = UDim2.new(1, -24, 0, 104),
            Position = UDim2.new(0, 12, 0, 60),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.stroke,
            CanvasSize = UDim2.new(0, 0, 0, 104),
        }, zoneCard)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
        }, zoneList)

        local function renderZones()
            for _, c in ipairs(zoneList:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
            end
            local n = #state.limits.zones
            zoneList.CanvasSize = UDim2.new(0, 0, 0, math.max(104, n * 30 + 8))

            if n == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 10,
                    TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "No zones.",
                }, zoneList)
                return
            end

            for index, zone in ipairs(state.limits.zones) do
                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = C.panel,
                    BorderSizePixel = 0,
                    LayoutOrder = index,
                }, zoneList)
                corner(row, 6)
                new("TextLabel", {
                    Size = UDim2.new(1, -40, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 10,
                    TextColor3 = C.text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = string.format("%s · %dst/s", zone.name or ("Zone " .. index), zone.limit),
                }, row)
                local del = new("TextButton", {
                    Size = UDim2.new(0, 24, 0, 18),
                    Position = UDim2.new(1, -30, 0.5, -9),
                    BackgroundColor3 = Color3.fromRGB(48, 26, 30),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    TextColor3 = C.bad,
                    Text = "×",
                }, row)
                corner(del, 5)
                del.MouseButton1Click:Connect(function()
                    table.remove(state.limits.zones, index)
                    saveConfig()
                    renderZones()
                    notify("Zone removed", nil)
                end)
            end
        end
        renderZones()

        track(addBtn.MouseButton1Click:Connect(function()
            local root = getRoot()
            if not root then return notify("No character", "bad") end
            if #state.limits.zones >= MAX_ZONES then
                return notify("Zon-gräns nådd", "bad")
            end
            local radius = math.clamp(tonumber(radiusBox.Text) or 45, 5, 500)
            local limit  = math.clamp(tonumber(limitBox.Text) or 60, 5, 300)
            local p = root.Position
            table.insert(state.limits.zones, {
                name = string.format("Zone %d", #state.limits.zones + 1),
                min = { X = p.X - radius, Y = p.Y - 60, Z = p.Z - radius },
                max = { X = p.X + radius, Y = p.Y + 200, Z = p.Z + radius },
                limit = limit,
            })
            saveConfig()
            renderZones()
            notify(string.format("Zone tillagd · %dst/s", limit), "good")
        end))

        local persist = card(settingsPage, 104, 3)
        sectionLabel(persist, "Config", 10)
        actionButton(persist, {
            label = "Save config now",
            y = 26,
            onClick = function()
                if not hasFS then return notify("Ingen filsystem", "bad") end
                saveConfig()
                notify("Sparad", "good")
            end,
        })
        actionButton(persist, {
            label = "Reset everything",
            y = 64,
            onClick = function()
                state = deepCopy(DEFAULTS)
                saveConfig()
                notify("Allt återställt", "good")
                task.delay(0.15, rebuild)
            end,
        })

        local swatchCard = card(settingsPage, 62, 4)
        sectionLabel(swatchCard, "Accent", 8)
        local palette = {
            Color3.fromRGB(94, 141, 255),
            Color3.fromRGB(163, 118, 255),
            Color3.fromRGB(88, 214, 141),
            Color3.fromRGB(255, 186, 84),
            Color3.fromRGB(255, 106, 106),
        }
        for i, color in ipairs(palette) do
            local sw = new("TextButton", {
                Size = UDim2.new(0, 26, 0, 26),
                Position = UDim2.new(0, 12 + (i - 1) * 32, 0, 26),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
            }, swatchCard)
            corner(sw, 7)
            sw.MouseButton1Click:Connect(function()
                state.ui.accent = color
                saveConfig()
                for _, e in ipairs(accentTargets) do
                    pcall(function() e.inst[e.prop] = color end)
                end
            end)
        end

        local danger = card(settingsPage, 56, 5)
        actionButton(danger, {
            label = "Unload script",
            y = 10,
            danger = true,
            onClick = function()
                notify("Laddar ur…", "bad")
                task.wait(0.35)
                teardown()
            end,
        })
    end

    local function stageControls()
        log("10 controls")
        local minimized = false
        local expandedHeight = WIN_H

        track(minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            minBtn.Text = minimized and "+" or "–"
            if minimized then
                expandedHeight = win.Size.Y.Offset
                win.Size = UDim2.new(0, WIN_W, 0, 52)
                tabBar.Visible = false
                content.Visible = false
            else
                tabBar.Visible = true
                content.Visible = true
                win.Size = UDim2.new(0, WIN_W, 0, expandedHeight)
            end
        end))

        local hidden = false
        local function setHidden(v)
            hidden = v
            win.Visible = not v
            win.Size = UDim2.new(0, WIN_W, 0, v and 0 or (minimized and 52 or expandedHeight))
        end

        track(closeBtn.MouseButton1Click:Connect(function()
            setHidden(true)
            notify("Gömd · " .. state.ui.keybind.Name .. " visar igen", nil)
        end))

        track(UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == state.ui.keybind then setHidden(not hidden) end
        end))
    end

    -- staged execution
    task.spawn(function()
        local stages = { stagePlayer, stageVehicle, stagePlayers, stageSettings, stageControls }
        for i, fn in ipairs(stages) do
            if myGen ~= generation then return end
            local ok, err = pcall(fn)
            if not ok then warn("[Venice] stage " .. i .. " failed: " .. tostring(err)) end
            task.wait(0.04)
        end

        if myGen ~= generation then return end

        log("11 loop")
        track(RunService.Heartbeat:Connect(function(dt)
            local ok, err = pcall(function()
                applyPlayer()
                applyVehicle(dt)
            end)
            if not ok then warn("[Venice] loop error: " .. tostring(err)) end
        end))

        track(LP.CharacterAdded:Connect(function()
            task.wait(0.6)
            resetAssist()
            notify("Respawnad — redo", nil)
        end))

        tabButtons.Player.MouseButton1Click:Fire()
        notify("Venice v1.5 · " .. state.ui.keybind.Name .. " visar GUI", "good")
        log("12 done")
    end)
end

rebuild = function()
    teardown()
    task.wait(0.05)
    local ok, err = pcall(buildGUI)
    if not ok then
        warn("[Venice] rebuild failed: " .. tostring(err))
        buildFallback(err)
    end
end

local okBuild, buildErr = pcall(buildGUI)
if not okBuild then
    warn("[Venice] BUILD FAILED: " .. tostring(buildErr))
    buildFallback(buildErr)
end
