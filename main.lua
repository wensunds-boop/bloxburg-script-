--!nocheck
--[[=====================================================================
  Venice Speed Suite  v3.1  ·  Bloxburg
  Author: Venice · MIT
  ---------------------------------------------------------------------
  v3.1
    · hookmetamethod letas i global och getgenv, installeras vid start
    · reservväg utan hook: hittar kund genom att prova "Give"
    · ärlig diagnos: skiljer på om funktionen finns och om den installerats
  CLIENT-SIDE ONLY. Kicken är lokal.
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)
if not PlayerGui then return warn("[Venice] ingen PlayerGui") end

local function log(m) print("[Venice] " .. m) end
log("0 start")

local function ident(n) if setthreadidentity then pcall(setthreadidentity, n) end end
local function fireSignal(sig)
    if type(firesignal) == "function" then return (pcall(firesignal, sig)) end
    return (pcall(function() sig:Fire() end))
end
local function genv(k)
    if type(getgenv) ~= "function" then return nil end
    local ok, g = pcall(getgenv)
    if ok and type(g) == "table" then return g[k] end
    return nil
end

--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local INSIDE = CFrame.new(1169, 15, 273)
local UNDER  = Vector3.new(1169, -45, 273)
local JOB    = "PizzaPlanetDelivery"

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    job     = { enabled = false },
    ui      = { accent = Color3.fromRGB(94, 141, 255), keybind = Enum.KeyCode.K },
}

local function deepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and deepCopy(v) or v end
    return o
end

local state = deepCopy(DEFAULTS)
local hasFS = pcall(function() return writefile ~= nil end)

local function num(v, f, mn, mx)
    if type(v) ~= "number" or v ~= v then return f end
    return math.clamp(v, mn, mx)
end

local function loadConfig()
    if not hasFS then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" or #raw < 2 then return end
    local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(d) ~= "table" then return end

    local p = d.player
    if type(p) == "table" then
        if type(p.enabled) == "boolean" then state.player.enabled = p.enabled end
        state.player.speed = num(p.speed, 34, 16, 300)
        if type(p.jumpEnabled) == "boolean" then state.player.jumpEnabled = p.jumpEnabled end
        state.player.jump = num(p.jump, 50, 30, 220)
    end
    local v = d.vehicle
    if type(v) == "table" then
        if type(v.enabled) == "boolean" then state.vehicle.enabled = v.enabled end
        state.vehicle.maxSpeed = num(v.maxSpeed, 130, 30, 600)
        state.vehicle.accel = num(v.accel, 110, 20, 600)
        state.vehicle.brake = num(v.brake, 190, 40, 900)
        if type(v.assist) == "boolean" then state.vehicle.assist = v.assist end
    end
    local l = d.limits
    if type(l) == "table" then
        if type(l.enabled) == "boolean" then state.limits.enabled = l.enabled end
        state.limits.global = num(l.global, 110, 16, 300)
        if type(l.zones) == "table" then
            local c = {}
            for _, z in ipairs(l.zones) do
                if #c >= MAX_ZONES then break end
                if type(z) == "table" and type(z.min) == "table"
                    and type(z.max) == "table" and type(z.limit) == "number" then
                    table.insert(c, {
                        name = type(z.name) == "string" and z.name or "Zone",
                        min = { X = z.min.X or 0, Y = z.min.Y or 0, Z = z.min.Z or 0 },
                        max = { X = z.max.X or 0, Y = z.max.Y or 0, Z = z.max.Z or 0 },
                        limit = math.clamp(z.limit, 5, 300),
                    })
                end
            end
            state.limits.zones = c
        end
    end
    if type(d.job) == "table" and type(d.job.enabled) == "boolean" then
        state.job.enabled = d.job.enabled
    end
    local u = d.ui
    if type(u) == "table" then
        if type(u.accent) == "table" then
            local okc, col = pcall(Color3.fromRGB, u.accent[1] or 94, u.accent[2] or 141, u.accent[3] or 255)
            if okc then state.ui.accent = col end
        end
        if type(u.keybind) == "string" then
            local oke, k = pcall(function() return Enum.KeyCode[u.keybind] end)
            if oke and k then state.ui.keybind = k end
        end
    end
end

local function snapshot()
    return {
        player = state.player, vehicle = state.vehicle, limits = state.limits,
        job = { enabled = state.job.enabled },
        ui = {
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
        local ok, enc = pcall(function() return HttpService:JSONEncode(snapshot()) end)
        if ok then pcall(writefile, CONFIG_FILE, enc) end
    end)
end

loadConfig()

--=====================================================================
local connections = {}
local function track(c) table.insert(connections, c); return c end

local generation = 0
local clearAssistRig
local rebuild

local function teardown()
    generation += 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if clearAssistRig then pcall(clearAssistRig) end
    local r = _G.__VeniceSpeedSuite
    if r and r.gui then pcall(function() r.gui:Destroy() end) end
    _G.__VeniceSpeedSuite = nil
end

local function new(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then i[k] = v end
    end
    i.Parent = parent or props.Parent
    return i
end

local function tw(inst, dur, props)
    local t = TweenService:Create(inst,
        TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function corner(inst, px) return new("UICorner", { CornerRadius = UDim.new(0, px) }, inst) end
local function edge(inst, col, tr)
    return new("UIStroke", { Color = col, Thickness = 1, Transparency = tr or 0.15,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function getHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local C = {
    bg = Color3.fromRGB(11, 13, 18), panel = Color3.fromRGB(18, 21, 28),
    card = Color3.fromRGB(24, 28, 36), cardHi = Color3.fromRGB(32, 37, 47),
    edge = Color3.fromRGB(44, 51, 64), track = Color3.fromRGB(44, 50, 62),
    text = Color3.fromRGB(240, 244, 250), dim = Color3.fromRGB(146, 156, 174),
    good = Color3.fromRGB(92, 220, 148), warn = Color3.fromRGB(255, 190, 90),
    bad = Color3.fromRGB(255, 112, 112),
}

--=====================================================================
local inputState = { drag = false, off = nil, slider = nil }

local function bindSharedInput()
    track(UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        if inputState.drag and inputState.off then
            local rec = _G.__VeniceSpeedSuite
            if rec and rec.win then
                local vp = viewport()
                rec.win.Position = UDim2.new(0,
                    math.clamp(i.Position.X - inputState.off.X, -340, vp.X - 80),
                    0, math.clamp(i.Position.Y - inputState.off.Y, 0, vp.Y - 40))
            end
            return
        end
        local s = inputState.slider
        if s then s.move(i.Position.X) end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            inputState.drag, inputState.slider = false, nil
        end
    end))
end

--=====================================================================
local blox = { interaction = nil, job = nil, ui = nil, tried = false }

local function initBlox()
    if blox.interaction then return true end
    if blox.tried then return blox.interaction ~= nil end
    blox.tried = true
    local modules
    if not pcall(function()
        modules = LP:WaitForChild("PlayerScripts", 15):WaitForChild("Modules", 15)
    end) or not modules then return false end

    pcall(function()
        ident(2)
        blox.interaction = require(modules:WaitForChild("InteractionHandler", 10))
        ident(0)
    end)
    pcall(function()
        ident(2)
        blox.job = require(modules:WaitForChild("JobHandler", 10))
        ident(0)
    end)
    return blox.interaction ~= nil
end

local function getInteractUI()
    if blox.ui and blox.ui.Parent then return blox.ui end
    local ok, ui = pcall(function() return PlayerGui:WaitForChild("_interactUI", 2) end)
    if ok and ui then blox.ui = ui end
    return blox.ui
end

local function clickBtn(text)
    local ui = getInteractUI()
    if not ui then return false end
    for _, v in ipairs(ui:GetChildren()) do
        local btn = v:FindFirstChild("Button")
        if btn then
            local lbl = btn:FindFirstChild("TextLabel")
            if lbl and lbl.Text == text then fireSignal(btn.Activated); return true end
        end
    end
    return false
end

local function quickInteract(model, text, part)
    if not initBlox() then return false end
    local p = part or model.PrimaryPart or model:FindFirstChildOfClass("MeshPart")
        or model:FindFirstChildOfClass("BasePart")
    if not p then return false end
    pcall(function()
        ident(2)
        blox.interaction:ShowMenu(model, p.Position, p)
        ident(0)
    end)
    task.wait(0.05)
    return clickBtn(text)
end

--=====================================================================
local WIN_W, WIN_H = 430, 520
local CANVAS = 700

local function buildGUI()
    local myGen = generation
    log("1 shell")

    local gui = new("ScreenGui", {
        Name = "VeniceSpeedSuite", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 5000,
    }, PlayerGui)

    local win = new("Frame", {
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
    }, gui)
    corner(win, 14)
    edge(win, C.edge, 0.05)

    _G.__VeniceSpeedSuite = { gui = gui, win = win, teardown = teardown }

    log("2 header")
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 33, 43)),
            ColorSequenceKeypoint.new(1, C.panel),
        }), Rotation = 15,
    }, header)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.edge, BorderSizePixel = 0,
    }, header)
    local accentBar = new("Frame", {
        Size = UDim2.new(0, 30, 0, 3), Position = UDim2.new(0, 16, 0, 37),
        BackgroundColor3 = state.ui.accent, BorderSizePixel = 0,
    }, header)
    corner(accentBar, 2)

    new("TextLabel", {
        Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 16, 0, 9),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Venice Speed Suite",
    }, header)
    new("TextLabel", {
        Size = UDim2.new(1, -110, 0, 12), Position = UDim2.new(0, 16, 0, 28),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "Bloxburg · v3.1",
    }, header)

    local status = new("TextLabel", {
        Size = UDim2.new(1, -110, 0, 13), Position = UDim2.new(0, 16, 0, 42),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
        TextColor3 = C.good, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }, header)

    local function notify(text, kind)
        if not status.Parent then return end
        local s = tostring(text)
        status.Text = s
        status.TextColor3 = kind == "bad" and C.bad or kind == "good" and C.good or C.text
        task.delay(3, function()
            if status.Parent and status.Text == s then status.Text = "" end
        end)
    end

    local function hbtn(g, x, col)
        local b = new("TextButton", {
            Size = UDim2.new(0, 27, 0, 25), Position = UDim2.new(1, x, 0, 15),
            BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = col, Text = g,
        }, header)
        corner(b, 7)
        local st = edge(b, C.edge, 0.3)
        track(b.MouseEnter:Connect(function()
            tw(b, 0.1, { BackgroundColor3 = C.cardHi })
            tw(st, 0.1, { Color = state.ui.accent })
        end))
        track(b.MouseLeave:Connect(function()
            tw(b, 0.1, { BackgroundColor3 = C.card })
            tw(st, 0.1, { Color = C.edge })
        end))
        return b
    end

    local minBtn, closeBtn = hbtn("–", -66, C.dim), hbtn("×", -36, C.bad)

    log("3 drag")
    track(header.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag = true
        inputState.off = Vector2.new(i.Position.X, i.Position.Y) - win.AbsolutePosition
    end))

    log("4 tabs")
    local bar = new("Frame", {
        Size = UDim2.new(1, -24, 0, 32), Position = UDim2.new(0, 12, 0, 66),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)
    corner(bar, 9)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3),
    }, bar)
    new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, bar)

    local content = new("Frame", {
        Size = UDim2.new(1, -24, 1, -166), Position = UDim2.new(0, 12, 0, 108),
        BackgroundTransparency = 1,
    }, win)

    local pages, tabs = {}, {}

    local function tab(name, order)
        local b = new("TextButton", {
            Size = UDim2.new(0, #name * 6 + 22, 1, -8), BackgroundColor3 = C.panel,
            BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = order,
            Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.dim, Text = name,
        }, bar)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
        corner(b, 7)
        local p = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.edge, CanvasSize = UDim2.new(0, 0, 0, CANVAS),
            Visible = false,
        }, content)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9),
        }, p)
        new("UIPadding", { PaddingBottom = UDim.new(0, 14) }, p)
        pages[name], tabs[name] = p, b
        track(b.MouseButton1Click:Connect(function()
            for o, pg in pairs(pages) do
                pg.Visible = (o == name)
                pcall(function()
                    tw(tabs[o], 0.12, {
                        BackgroundColor3 = o == name and C.card or C.panel,
                        TextColor3 = o == name and C.text or C.dim,
                    })
                end)
            end
        end))
        return p
    end

    local playerPage  = tab("Player", 1)
    local vehiclePage = tab("Vehicle", 2)
    local jobPage     = tab("Job", 3)
    local playersPage = tab("Players", 4)
    local settPage    = tab("Settings", 5)

    local function card(parent, h, order)
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card,
            BorderSizePixel = 0, LayoutOrder = order,
        }, parent)
        corner(f, 10)
        edge(f, C.edge, 0.2)
        return f
    end

    local function label(parent, text, y, size, col)
        return new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 15), Position = UDim2.new(0, 12, 0, y),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = size or 9, TextColor3 = col or C.dim,
            TextXAlignment = Enum.TextXAlignment.Left, Text = text,
        }, parent)
    end

    local function slider(parent, cfg)
        local row = new("Frame", {
            Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)
        new("TextLabel", {
            Size = UDim2.new(1, -76, 0, 15), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)
        local val = new("TextLabel", {
            Size = UDim2.new(0, 76, 0, 15), Position = UDim2.new(1, -76, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = state.ui.accent, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
        }, row)
        local trk = new("Frame", {
            Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 0, 26),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
        }, row)
        corner(trk, 3)
        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = state.ui.accent, BorderSizePixel = 0,
        }, trk)
        corner(fill, 3)
        local knob = new("Frame", {
            Size = UDim2.new(0, 13, 0, 13), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 2,
        }, trk)
        corner(knob, 7)
        local hit = new("Frame", {
            Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.5, -12),
            BackgroundTransparency = 1, ZIndex = 3,
        }, trk)

        local v = math.clamp(cfg.value, cfg.min, cfg.max)
        local function render()
            local a = (v - cfg.min) / math.max(cfg.max - cfg.min, 1e-6)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            val.Text = cfg.format and cfg.format(v) or tostring(v)
        end
        local function set(nv, fire)
            nv = math.clamp(math.floor(nv / cfg.step + 0.5) * cfg.step, cfg.min, cfg.max)
            if nv == v then return end
            v = nv; render()
            if fire and cfg.onChanged then cfg.onChanged(v) end
        end
        local function move(x)
            local w = trk.AbsoluteSize.X
            if w <= 0 then return end
            set(cfg.min + math.clamp((x - trk.AbsolutePosition.X) / w, 0, 1)
                * (cfg.max - cfg.min), true)
        end
        track(hit.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1
                and i.UserInputType ~= Enum.UserInputType.Touch then return end
            inputState.slider = { move = move }
            move(i.Position.X)
        end))
        render()
        return { set = function(n) set(n, false) end }
    end

    local function toggle(parent, cfg)
        local row = new("Frame", {
            Size = UDim2.new(1, -24, 0, 28), Position = UDim2.new(0, 12, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)
        new("TextLabel", {
            Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)
        local pill = new("TextButton", {
            Size = UDim2.new(0, 38, 0, 19), Position = UDim2.new(1, -38, 0.5, -9.5),
            BackgroundColor3 = C.track, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        }, row)
        corner(pill, 10)
        local dot = new("Frame", {
            Size = UDim2.new(0, 13, 0, 13), Position = UDim2.new(0, 3, 0.5, -6.5),
            BackgroundColor3 = C.dim, BorderSizePixel = 0,
        }, pill)
        corner(dot, 7)
        local on = cfg.value and true or false
        local function render()
            pill.BackgroundColor3 = on and state.ui.accent or C.track
            dot.Position = on and UDim2.new(1, -16, 0.5, -6.5) or UDim2.new(0, 3, 0.5, -6.5)
            dot.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
        render()
        track(pill.MouseButton1Click:Connect(function()
            on = not on; render()
            if cfg.onChanged then cfg.onChanged(on) end
        end))
    end

    local function button(parent, cfg)
        local b = new("TextButton", {
            Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, cfg.y),
            BackgroundColor3 = cfg.danger and Color3.fromRGB(52, 28, 33) or C.cardHi,
            BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = cfg.danger and C.bad or C.text, Text = cfg.label,
        }, parent)
        corner(b, 8)
        local st = edge(b, C.edge, 0.25)
        track(b.MouseEnter:Connect(function()
            tw(b, 0.1, { BackgroundColor3 = cfg.danger and Color3.fromRGB(64, 34, 40) or C.edge })
            tw(st, 0.1, { Color = state.ui.accent })
        end))
        track(b.MouseLeave:Connect(function()
            tw(b, 0.1, { BackgroundColor3 = cfg.danger and Color3.fromRGB(52, 28, 33) or C.cardHi })
            tw(st, 0.1, { Color = C.edge })
        end))
        track(b.MouseButton1Click:Connect(function()
            if cfg.onClick then
                local ok, e = pcall(cfg.onClick)
                if not ok then notify(e, "bad") end
            end
        end))
        return b
    end

    -- fordon --------------------------------------------------------
    local jumpForced = false
    local rig = { part = nil, att = nil, force = nil }
    local assist = { lastSeat = nil, seats = {}, applied = nil, writeTimer = 0,
        direct = false, probe = 0, probeFrom = 0, primary = nil, anchored = false, lastNote = 0 }
    local selected = {}

    clearAssistRig = function()
        if rig.force then pcall(function() rig.force:Destroy() end) end
        if rig.att then pcall(function() rig.att:Destroy() end) end
        rig.force, rig.att, rig.part = nil, nil, nil
    end

    local function zoneLimitAt(pos)
        if not state.limits.enabled then return nil end
        for _, z in ipairs(state.limits.zones) do
            local mn, mx = z.min, z.max
            if pos.X >= math.min(mn.X, mx.X) and pos.X <= math.max(mn.X, mx.X)
                and pos.Y >= math.min(mn.Y, mx.Y) and pos.Y <= math.max(mn.Y, mx.Y)
                and pos.Z >= math.min(mn.Z, mx.Z) and pos.Z <= math.max(mn.Z, mx.Z) then
                return z.limit
            end
        end
        return state.limits.global
    end

    local function applyPlayer()
        local hum = getHumanoid()
        if not hum or hum.Health <= 0 then return end
        local root = getRoot()
        local lim = root and zoneLimitAt(root.Position) or nil
        local target = state.player.speed
        if lim then target = math.min(target, lim) end
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
        local u = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.playerReadout
        if u then u(hum.WalkSpeed, lim) end
    end

    local function vehicleFromCharacter()
        local char = LP.Character
        if not char then return nil end
        for _, d in ipairs(char:GetChildren()) do
            if d:IsA("Model") and d.Name:sub(1, 8) == "Vehicle_" then return d end
        end
        return nil
    end

    local function getVehicle()
        local hum = getHumanoid()
        if not hum then return nil end
        local model = vehicleFromCharacter()
        if model then return model, hum.SeatPart end
        local seat = hum.SeatPart
        if not seat then return nil end
        return seat:FindFirstAncestorOfClass("Model"), seat
    end

    local function pickPrimary(model, seat)
        if seat then
            local okR, ar = pcall(function() return seat.AssemblyRootPart end)
            if okR and ar and ar.Parent and not ar.Anchored
                and not ar:IsA("Seat") and not ar:IsA("VehicleSeat") then return ar end
        end
        local best, bs = nil, -1
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and not d.Anchored
                and not d:IsA("Seat") and not d:IsA("VehicleSeat") then
                local n = d.Name:lower()
                local w = n:find("wheel") or n:find("tire") or n:find("rim")
                local s = d.AssemblyMass * (w and 0.2 or 1)
                if s > bs then best, bs = d, s end
            end
        end
        return best or model.PrimaryPart
    end

    local function ensureRig(part)
        if rig.part == part and rig.force and rig.force.Parent then return true end
        clearAssistRig()
        local ok = pcall(function()
            local a = new("Attachment", { Name = "VeniceAtt" }, part)
            local lv = new("LinearVelocity", {
                Name = "VeniceAssist", Attachment0 = a,
                VelocityConstraintMode = Enum.VelocityConstraintMode.Line,
                RelativeTo = Enum.ActuatorRelativeTo.World, MaxForce = 0,
            }, part)
            rig.part, rig.att, rig.force = part, a, lv
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
        assist.lastSeat, assist.applied = nil, nil
        assist.writeTimer, assist.direct, assist.probe = 0, false, 0
        assist.primary, assist.anchored = nil, false
        table.clear(assist.seats)
        clearAssistRig()
    end

    local function readThrottle()
        local uis = UserInputService
        if uis:IsKeyDown(Enum.KeyCode.W) or uis:IsKeyDown(Enum.KeyCode.Up) then return 1 end
        if uis:IsKeyDown(Enum.KeyCode.S) or uis:IsKeyDown(Enum.KeyCode.Down) then return -1 end
        return 0
    end

    local function applyVehicle(dt)
        local model, seat = getVehicle()
        local u = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.vehicleReadout
        if not model then
            if assist.lastSeat ~= nil then resetAssist() end
            if u then u(nil, 0) end
            return
        end
        if assist.lastSeat ~= model then
            assist.lastSeat = model
            assist.applied, assist.writeTimer = nil, 0
            assist.direct, assist.probe = false, 0
            clearAssistRig(); cacheSeats(model)
            local okP, p = pcall(pickPrimary, model, seat)
            assist.primary = okP and p or nil
            assist.anchored = assist.primary ~= nil and assist.primary.Anchored
        end
        local primary = assist.primary
        if not primary or not primary.Parent then
            local okP, p = pcall(pickPrimary, model, seat)
            primary = okP and p or nil
            assist.primary = primary
            assist.anchored = primary ~= nil and primary.Anchored
        end
        local vel = Vector3.zero
        if primary then
            local okV, v = pcall(function() return primary.AssemblyLinearVelocity end)
            if okV and typeof(v) == "Vector3" then vel = v end
        end
        local speed = vel.Magnitude
        if not state.vehicle.enabled then
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if u then u(model.Name, speed) end
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
        local thr = readThrottle()
        if thr == 0 or not state.vehicle.assist or not primary or assist.anchored then
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if u then u(model.Name, speed, thr) end
            return
        end
        local okF, fwd = pcall(function() return primary.CFrame.LookVector end)
        if not okF or typeof(fwd) ~= "Vector3" then
            if u then u(model.Name, speed, thr) end
            return
        end
        local fs = vel:Dot(fwd)
        local desired = thr * state.vehicle.maxSpeed
        local inc = math.abs(desired) > math.abs(fs)
        local rate = inc and state.vehicle.accel or state.vehicle.brake
        local step = math.clamp(desired - fs, -rate * dt, rate * dt)
        local engaged = math.abs(step) > 0.01
        if not assist.direct and ensureRig(primary) then
            rig.force.LineDirection = fwd
            rig.force.LineVelocity = fs + step
            rig.force.MaxForce = math.max(primary.AssemblyMass * rate * 2, 12000)
        else
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            local nv = fwd * (fs + step) + Vector3.new(0, vel.Y, 0)
            pcall(function() primary.AssemblyLinearVelocity = nv end)
        end
        if u then u(model.Name, speed, thr) end
    end

    -- leverans ------------------------------------------------------
    local customer = nil
    local hooked = false
    local hookErr = ""
    local jobStatus, jobCount
    local done = 0
    local jobRunning = false

    local function jset(txt, ok)
        if not jobStatus or not jobStatus.Parent then return end
        jobStatus.Text = txt
        jobStatus.TextColor3 = ok and C.good or C.bad
    end

    local function locations()
        local ok, l = pcall(function()
            return workspace:WaitForChild("Environment", 10):WaitForChild("Locations", 10)
        end)
        if ok then return l end
        return nil
    end

    local function hookFn()
        local f = hookmetamethod
        if type(f) ~= "function" then f = genv("hookmetamethod") end
        return f
    end

    local function installHook()
        if hooked then return true end
        local hmm = hookFn()
        if type(hmm) ~= "function" then
            hookErr = "hookmetamethod saknas"
            return false
        end
        local ok, e = pcall(function()
            local old
            old = hmm(game, "__namecall", function(...)
                if checkcaller and checkcaller() then return old(...) end
                local method = getnamecallmethod and getnamecallmethod() or ""
                if method == "InvokeServer" then
                    local tb = debug.traceback()
                    if type(tb) == "string"
                        and tb:find("JobHandler.PizzaPlanetDelivery", 1, true) then
                        local args = { ... }
                        local a2 = args[2]
                        if a2 and typeof(a2) == "Instance" and a2:FindFirstChild("Box") then
                            local res = old(...)
                            customer = res
                            return res
                        end
                    end
                end
                return old(...)
            end)
        end)
        if not ok then
            hookErr = tostring(e)
            return false
        end
        hooked = true
        return true
    end

    local function hasBox()
        local char = LP.Character
        if not char then return false end
        return char:FindFirstChild("Pizza Box") ~= nil
    end

    local function ourMoped()
        local char = LP.Character
        if not char then return nil end
        return char:FindFirstChild("Vehicle_Delivery Moped")
    end

    local function isWorking()
        if not initBlox() or not blox.job then return false, nil end
        local ok, j = pcall(function()
            ident(2)
            local n = blox.job:GetJob()
            ident(0)
            return n
        end)
        return ok and j == JOB, ok and j or nil
    end

    local function claimMoped()
        local m = ourMoped()
        if m then return m end
        local loc = locations()
        if not loc then return nil end
        local ok, model = pcall(function() return loc.PizzaPlanet.DeliveryMoped end)
        if not ok or not model then return nil end
        local root, char = getRoot(), LP.Character
        if root and char and model.PrimaryPart then
            if (root.Position - model.PrimaryPart.Position).Magnitude > 6 then
                pcall(function()
                    char:PivotTo(CFrame.new(model.PrimaryPart.Position + Vector3.new(0, 4, 0)))
                end)
                task.wait(0.2)
            end
        end
        for _ = 1, 12 do
            quickInteract(model, "Use")
            task.wait(0.25)
            if ourMoped() then break end
        end
        return ourMoped()
    end

    local function grabBox()
        if hasBox() then return true end
        local loc = locations()
        if not loc then return false end
        local ok, conv = pcall(function() return loc.PizzaPlanet.Conveyor.MovingBoxes end)
        if not ok or not conv then return false end
        for _, v in ipairs(conv:GetChildren()) do
            quickInteract(v, "Take", v)
            task.wait(0.2)
            if hasBox() then return true end
        end
        return false
    end

    -- reserv utan hook: prova "Give" på kandidater
    local function giveProbe()
        local root = getRoot()
        if not root then return false end
        local list = {}
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Model") and d.Name:lower():find("customer", 1, true) then
                    local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
                    if p then table.insert(list, { model = d, part = p }) end
                end
            end
        end)
        if #list == 0 then return false end
        table.sort(list, function(a, b)
            return (a.part.Position - root.Position).Magnitude
                < (b.part.Position - root.Position).Magnitude
        end)
        for i = 1, math.min(12, #list) do
            if not state.job.enabled then return false end
            local c = list[i]
            local char = LP.Character
            if char then
                pcall(function() char:PivotTo(CFrame.new(c.part.Position + Vector3.new(0, 4, 0))) end)
                task.wait(0.15)
            end
            quickInteract(c.model, "Give", c.part)
            task.wait(0.2)
            if not hasBox() then
                done += 1
                if jobCount and jobCount.Parent then jobCount.Text = done .. " leveranser" end
                jset("Gav pizza (reservväg)", true)
                return true
            end
        end
        return false
    end

    local function waitUntil(t0, seconds)
        while os.clock() - t0 < seconds do
            if not state.job.enabled then return false end
            jset(string.format("Väntar %d s", math.ceil(seconds - (os.clock() - t0))), true)
            task.wait(0.25)
        end
        return true
    end

    local function cycle()
        if not initBlox() then jset("Moduler saknas", false); return end
        local working = isWorking()
        if not working then
            if blox.job then
                pcall(function() ident(2); blox.job:GoToWork(JOB); ident(0) end)
                task.wait(1.5)
                jset("Startar passet…", true)
                return
            end
            jset("Inget jobb, ingen jobbmodul", false)
            return
        end

        local moped = claimMoped()
        if not moped then jset("Kunde inte hämta moped", false); return end

        customer = nil
        pcall(function() moped:PivotTo(INSIDE) end)
        task.wait(0.4)

        for _ = 1, 15 do
            if not state.job.enabled then return end
            grabBox()
            if hasBox() then break end
            task.wait(0.3)
        end
        if not hasBox() then jset("Fick ingen låda", false); return end

        local t0 = os.clock()
        local root = getRoot()

        if not customer then
            jset("Ingen kund via hook — provar direkt", true)
            if not giveProbe() then jset("Hittade ingen kund", false) end
            pcall(function() moped:PivotTo(INSIDE) end)
            if root then pcall(function() root.Anchored = false end) end
            return
        end

        pcall(function() moped:PivotTo(CFrame.new(UNDER)) end)
        task.wait(0.2)
        local okc, croot = pcall(function() return customer.HumanoidRootPart end)
        if not okc or not croot then jset("Kund utan root", false); return end
        pcall(function() moped:PivotTo(croot.CFrame - Vector3.new(0, 45, 0)) end)

        if root then pcall(function() root.Anchored = true end) end
        if not waitUntil(t0, 18) then
            if root then pcall(function() root.Anchored = false end) end
            return
        end
        if root then pcall(function() root.Anchored = false end) end

        for _ = 1, 12 do
            if not state.job.enabled then return end
            pcall(function() moped:PivotTo(croot.CFrame - Vector3.new(0, 5, 0)) end)
            quickInteract(customer, "Give")
            task.wait(0.25)
            if not hasBox() then break end
        end

        if hasBox() then jset("Kunde inte lämna pizzan", false); return end
        done += 1
        if jobCount and jobCount.Parent then jobCount.Text = done .. " leveranser" end

        pcall(function() moped:PivotTo(CFrame.new(UNDER)) end)
        if root then pcall(function() root.Anchored = true end) end
        waitUntil(t0, 36)
        if root then pcall(function() root.Anchored = false end) end
        pcall(function() moped:PivotTo(INSIDE) end)
        jset("Leverans klar", true)
    end

    local function startJobLoop()
        if jobRunning then return end
        jobRunning = true
        installHook()
        task.spawn(function()
            while state.job.enabled do
                local ok, e = pcall(cycle)
                if not ok then jset("Fel: " .. tostring(e), false) end
                task.wait(0.4)
            end
            jobRunning = false
        end)
    end

    -- sidor ---------------------------------------------------------
    local speedSlider

    local function stagePlayer()
        log("5 player")
        local c = card(playerPage, 112, 1)
        label(c, "SPELARE", 10)
        toggle(c, {
            label = "Aktivera spelarjustering", y = 28, value = state.player.enabled,
            onChanged = function(v)
                state.player.enabled = v; saveConfig()
                notify(v and "Spelarjustering på" or "av", v and "good" or nil)
            end,
        })
        speedSlider = slider(c, {
            label = "Gånghastighet", min = 16, max = 300, step = 1,
            value = state.player.speed, y = 60,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.player.speed = x; saveConfig() end,
        })
        local live = label(playerPage, "16.0 st/s", 10, 13, C.text)
        live.Parent.LayoutOrder = 2

        local jc = card(playerPage, 96, 3)
        label(jc, "HOPP", 10)
        toggle(jc, {
            label = "Egen hoppkraft", y = 28, value = state.player.jumpEnabled,
            onChanged = function(v) state.player.jumpEnabled = v; saveConfig() end,
        })
        slider(jc, {
            label = "Hoppkraft", min = 30, max = 220, step = 1,
            value = state.player.jump, y = 56,
            onChanged = function(x) state.player.jump = x; saveConfig() end,
        })

        local rc = card(playerPage, 52, 4)
        button(rc, {
            label = "Återställ 16 / 50", y = 11,
            onClick = function()
                state.player.speed, state.player.jump = 16, 50
                speedSlider.set(16); saveConfig()
                local hum = getHumanoid()
                if hum then pcall(function()
                    hum.WalkSpeed = 16; hum.UseJumpPower = true; hum.JumpPower = 50
                end) end
                notify("Återställt", "good")
            end,
        })

        _G.__VeniceSpeedSuite.playerReadout = function(cur, lim)
            live.Text = string.format("%.1f st/s%s", cur, lim and ("  ·  GRÄNS " .. lim) or "")
            live.TextColor3 = lim and C.warn or C.text
        end
    end

    local detLabel, spdLabel

    local function stageVehicle()
        log("6 vehicle")
        local d = card(vehiclePage, 76, 1)
        label(d, "FORDON", 10)
        detLabel = label(d, "Inte i fordon", 28, 12, C.dim)
        spdLabel = label(d, "0.0 st/s", 46, 10, C.dim)

        local c = card(vehiclePage, 148, 2)
        toggle(c, {
            label = "Aktivera fordonsjustering", y = 10, value = state.vehicle.enabled,
            onChanged = function(v)
                state.vehicle.enabled = v; saveConfig()
                notify(v and "Fordonsjustering på" or "av", v and "good" or nil)
            end,
        })
        slider(c, {
            label = "Maxfart", min = 30, max = 600, step = 5,
            value = state.vehicle.maxSpeed, y = 42,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.vehicle.maxSpeed = x; saveConfig() end,
        })
        slider(c, {
            label = "Acceleration", min = 20, max = 600, step = 5,
            value = state.vehicle.accel, y = 84,
            format = function(x) return x .. " st/s²" end,
            onChanged = function(x) state.vehicle.accel = x; saveConfig() end,
        })

        local bc = card(vehiclePage, 120, 3)
        slider(bc, {
            label = "Bromskraft", min = 40, max = 900, step = 10,
            value = state.vehicle.brake, y = 10,
            format = function(x) return x .. " st/s²" end,
            onChanged = function(x) state.vehicle.brake = x; saveConfig() end,
        })
        toggle(bc, {
            label = "Fysikassist (W/S)", y = 56, value = state.vehicle.assist,
            onChanged = function(v)
                state.vehicle.assist = v; saveConfig()
                notify(v and "Assist på — bara med gas" or "Assist av", nil)
            end,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 0, 88),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Släpper du gasen kopplas assisten ur.",
        }, bc)

        local rc = card(vehiclePage, 52, 4)
        button(rc, {
            label = "Återställ fordon", y = 11,
            onClick = function()
                state.vehicle.maxSpeed, state.vehicle.accel, state.vehicle.brake = 130, 110, 190
                saveConfig(); rebuild()
            end,
        })

        _G.__VeniceSpeedSuite.vehicleReadout = function(name, speed, thr)
            detLabel.Text = name and ("I: " .. name) or "Inte i fordon"
            detLabel.TextColor3 = name and C.good or C.dim
            spdLabel.Text = string.format("%.1f st/s%s", speed,
                thr == 1 and "  ·  GAS" or thr == -1 and "  ·  BACK" or "")
            spdLabel.TextColor3 = thr ~= 0 and C.accent or C.dim
        end
    end

    local function stageJob()
        log("7 job")
        local c = card(jobPage, 132, 1)
        label(c, "PIZZALEVERANS", 10)
        toggle(c, {
            label = "Autofarm", y = 28, value = state.job.enabled,
            onChanged = function(v)
                state.job.enabled = v
                saveConfig()
                if v then
                    notify("Autofarm startad", "good")
                    startJobLoop()
                else
                    notify("Autofarm stoppad", nil)
                end
            end,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 12, 0, 58),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Hämtar moped, tar låda, pivot till kund, ger pizzan, pivot "
                .. "tillbaka. Utan hook provas kunder direkt.",
        }, c)
        jobStatus = label(c, "redo", 96, 9, C.dim)
        jobCount = label(c, "0 leveranser", 112, 9, C.good)

        local wc = card(jobPage, 118, 2)
        button(wc, {
            label = "Börja jobba", y = 10,
            onClick = function()
                if not initBlox() then return notify("Moduler saknas", "bad") end
                if not blox.job then return notify("JobHandler saknas", "bad") end
                local ok, e = pcall(function()
                    ident(2); blox.job:GoToWork(JOB); ident(0)
                end)
                notify(ok and "Startar passet" or tostring(e), ok and "good" or "bad")
            end,
        })
        button(wc, {
            label = "Avsluta passet", y = 46,
            onClick = function()
                local sig
                pcall(function()
                    sig = PlayerGui.MainGUI.Bar.CharMenu.WorkFrame.WorkFrame.Action.Activated
                end)
                if sig then fireSignal(sig); notify("Avslutar", "good")
                else notify("Ingen avsluta-knapp", "bad") end
            end,
        })
        button(wc, {
            label = "Diagnos", y = 82,
            onClick = function()
                local hmm = hookFn()
                local working, j = isWorking()
                jset(string.format("hook-fn:%s · installerad:%s · interaktion:%s · jobb:%s",
                    type(hmm) == "function" and "OK" or "NEJ",
                    hooked and "OK" or "NEJ",
                    blox.interaction and "OK" or "NEJ",
                    tostring(j or "inget")),
                    type(hmm) == "function" or blox.interaction ~= nil)
                if hookErr ~= "" then notify("hook: " .. hookErr, "bad") end
            end,
        })

        local nc = card(jobPage, 96, 3)
        new("TextLabel", {
            Size = UDim2.new(1, -24, 1, -18), Position = UDim2.new(0, 12, 0, 10),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Kör Diagnos först. Kräver leveransjobbet. 36 s per leverans är "
                .. "spelets egen takt och går inte att skynda på.",
        }, nc)
    end

    local refreshPlayers

    local function stagePlayers()
        log("8 players")
        local c = card(playersPage, 146, 1)
        label(c, "SERVER", 10)
        local count = label(c, "—", 28, 10, C.dim)

        local function sb(text, x, w, fn, danger)
            local b = new("TextButton", {
                Size = UDim2.new(0, w, 0, 26), Position = UDim2.new(0, x, 0, 48),
                BackgroundColor3 = danger and Color3.fromRGB(52, 28, 33) or C.cardHi,
                BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Gotham,
                TextSize = 9, TextColor3 = danger and C.bad or C.text, Text = text,
            }, c)
            corner(b, 7)
            b.MouseButton1Click:Connect(function() pcall(fn) end)
            return b
        end

        sb("Markera alla", 12, 104, function()
            table.clear(selected)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then selected[p.UserId] = true end
            end
            refreshPlayers()
        end)
        sb("Rensa", 122, 62, function()
            table.clear(selected); refreshPlayers()
        end)
        sb("Kick markerade", 190, 112, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and selected[p.UserId] then
                    n += 1; pcall(function() p:Kick("Kickad av Venice") end)
                end
            end
            if n == 0 then return notify("Ingen markerad", "bad") end
            notify("Kickat " .. n, "good"); task.delay(1.6, refreshPlayers)
        end, true)
        sb("Kick alla andra", 12, 140, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then n += 1; pcall(function() p:Kick("Kickad av Venice") end) end
            end
            notify(n > 0 and ("Kickat " .. n) or "Ingen att kicka", n > 0 and "good" or "bad")
            task.delay(1.6, refreshPlayers)
        end)

        local lc = card(playersPage, 204, 2)
        local list = new("ScrollingFrame", {
            Size = UDim2.new(1, -24, 0, 186), Position = UDim2.new(0, 12, 0, 10),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.edge,
            CanvasSize = UDim2.new(0, 0, 0, 186),
        }, lc)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
        }, list)

        refreshPlayers = function()
            for _, ch in ipairs(list:GetChildren()) do
                if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
            end
            local all = Players:GetPlayers()
            count.Text = string.format("%d i servern", #all)
            local shown = 0
            for _, p in ipairs(all) do
                if p ~= LP then
                    shown += 1
                    local on = selected[p.UserId] and true or false
                    local row = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.panel,
                        BorderSizePixel = 0, LayoutOrder = shown,
                    }, list)
                    corner(row, 6)
                    local cb = new("TextButton", {
                        Size = UDim2.new(0, 15, 0, 15), Position = UDim2.new(0, 6, 0.5, -7.5),
                        BackgroundColor3 = on and state.ui.accent or C.track,
                        BorderSizePixel = 0, AutoButtonColor = false,
                        Font = Enum.Font.GothamBold, TextSize = 9,
                        TextColor3 = Color3.new(1, 1, 1), Text = on and "x" or "",
                    }, row)
                    corner(cb, 4)
                    cb.MouseButton1Click:Connect(function()
                        selected[p.UserId] = (not selected[p.UserId]) or nil
                        refreshPlayers()
                    end)
                    new("TextLabel", {
                        Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 26, 0, 0),
                        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd, Text = p.Name,
                    }, row)
                    local kbb = new("TextButton", {
                        Size = UDim2.new(0, 44, 0, 18), Position = UDim2.new(1, -50, 0.5, -9),
                        BackgroundColor3 = Color3.fromRGB(52, 28, 33), BorderSizePixel = 0,
                        AutoButtonColor = false, Font = Enum.Font.GothamBold,
                        TextSize = 9, TextColor3 = C.bad, Text = "kick",
                    }, row)
                    corner(kbb, 5)
                    kbb.MouseButton1Click:Connect(function()
                        pcall(function() p:Kick("Kickad av Venice") end)
                        notify("Kickat " .. p.Name, "good")
                        task.delay(1.6, refreshPlayers)
                    end)
                end
            end
            list.CanvasSize = UDim2.new(0, 0, 0, math.max(186, shown * 30 + 6))
            if shown == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = "Ensam i servern.",
                }, list)
            end
        end
        refreshPlayers()

        track(Players.PlayerAdded:Connect(function() task.delay(0.5, refreshPlayers) end))
        track(Players.PlayerRemoving:Connect(function() task.delay(0.5, refreshPlayers) end))
        track(tabs.Players.MouseButton1Click:Connect(refreshPlayers))

        local note = label(playersPage, "Kick är lokalt.", 0, 9, C.dim)
        note.LayoutOrder = 3
        note.Size = UDim2.new(1, 0, 0, 26)
    end

    local function stageSettings()
        log("9 settings")
        local c = card(settPage, 106, 1)
        label(c, "FARTSGRÄNSER", 10)
        toggle(c, {
            label = "Tillämpa gränser", y = 26, value = state.limits.enabled,
            onChanged = function(v)
                state.limits.enabled = v; saveConfig()
                notify(v and "Gränser på" or "av", nil)
            end,
        })
        slider(c, {
            label = "Standardgräns", min = 16, max = 300, step = 1,
            value = state.limits.global, y = 58,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.limits.global = x; saveConfig() end,
        })

        local zc = card(settPage, 168, 2)
        label(zc, "ZONER", 10)
        local add = new("TextButton", {
            Size = UDim2.new(1, -158, 0, 26), Position = UDim2.new(0, 12, 0, 26),
            BackgroundColor3 = C.cardHi, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "  Lägg zon här",
        }, zc)
        corner(add, 7)

        local function fld(x, ph, txt)
            return new("TextBox", {
                Size = UDim2.new(0, 60, 0, 26), Position = UDim2.new(1, x, 0, 26),
                BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham,
                TextSize = 9, TextColor3 = C.text, PlaceholderText = ph, Text = txt,
                ClearTextOnFocus = false, ZIndex = 2,
            }, zc)
        end
        local lb, rb = fld(-140, "gräns", "60"), fld(-74, "radie", "45")

        local zlist = new("ScrollingFrame", {
            Size = UDim2.new(1, -24, 0, 100), Position = UDim2.new(0, 12, 0, 58),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.edge,
            CanvasSize = UDim2.new(0, 0, 0, 100),
        }, zc)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
        }, zlist)

        local function renderZones()
            for _, ch in ipairs(zlist:GetChildren()) do
                if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
            end
            local n = #state.limits.zones
            zlist.CanvasSize = UDim2.new(0, 0, 0, math.max(100, n * 30 + 6))
            if n == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = "Inga zoner.",
                }, zlist)
                return
            end
            for i, z in ipairs(state.limits.zones) do
                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.panel,
                    BorderSizePixel = 0, LayoutOrder = i,
                }, zlist)
                corner(row, 6)
                new("TextLabel", {
                    Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
                    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = string.format("%s · %dst/s", z.name or ("Zon " .. i), z.limit),
                }, row)
                local del = new("TextButton", {
                    Size = UDim2.new(0, 22, 0, 18), Position = UDim2.new(1, -28, 0.5, -9),
                    BackgroundColor3 = Color3.fromRGB(52, 28, 33), BorderSizePixel = 0,
                    AutoButtonColor = false, Font = Enum.Font.GothamBold,
                    TextSize = 10, TextColor3 = C.bad, Text = "x",
                }, row)
                corner(del, 5)
                del.MouseButton1Click:Connect(function()
                    table.remove(state.limits.zones, i); saveConfig()
                    renderZones(); notify("Zon borttagen", nil)
                end)
            end
        end
        renderZones()

        track(add.MouseButton1Click:Connect(function()
            local root = getRoot()
            if not root then return notify("Ingen karaktär", "bad") end
            if #state.limits.zones >= MAX_ZONES then return notify("Zon-gräns", "bad") end
            local rad = math.clamp(tonumber(rb.Text) or 45, 5, 500)
            local lim = math.clamp(tonumber(lb.Text) or 60, 5, 300)
            local p = root.Position
            table.insert(state.limits.zones, {
                name = "Zon " .. (#state.limits.zones + 1),
                min = { X = p.X - rad, Y = p.Y - 60, Z = p.Z - rad },
                max = { X = p.X + rad, Y = p.Y + 200, Z = p.Z + rad },
                limit = lim,
            })
            saveConfig(); renderZones(); notify("Zon tillagd", "good")
        end))

        local pc = card(settPage, 84, 3)
        button(pc, {
            label = "Spara config", y = 8,
            onClick = function()
                if not hasFS then return notify("Inget filsystem", "bad") end
                saveConfig(); notify("Sparad", "good")
            end,
        })
        button(pc, {
            label = "Återställ allt", y = 46,
            onClick = function()
                state = deepCopy(DEFAULTS); saveConfig()
                notify("Återställt", "good"); task.delay(0.15, rebuild)
            end,
        })

        local dc = card(settPage, 50, 4)
        button(dc, {
            label = "Ladda ur", y = 10, danger = true,
            onClick = function()
                notify("Laddar ur…", "bad"); task.wait(0.3); teardown()
            end,
        })
    end

    local function stageControls()
        log("10 controls")
        local min = false
        local expH = WIN_H
        track(minBtn.MouseButton1Click:Connect(function()
            min = not min
            minBtn.Text = min and "+" or "–"
            if min then
                expH = win.Size.Y.Offset
                win.Size = UDim2.new(0, WIN_W, 0, 56)
                bar.Visible, content.Visible = false, false
            else
                bar.Visible, content.Visible = true, true
                win.Size = UDim2.new(0, WIN_W, 0, expH)
            end
        end))
        local hid = false
        local function setHidden(v)
            hid = v
            win.Visible = not v
            win.Size = UDim2.new(0, WIN_W, 0, v and 0 or (min and 56 or expH))
        end
        track(closeBtn.MouseButton1Click:Connect(function()
            setHidden(true); notify("Gömd · " .. state.ui.keybind.Name, nil)
        end))
        track(UserInputService.InputBegan:Connect(function(i, processed)
            if processed then return end
            if i.KeyCode == state.ui.keybind then setHidden(not hid) end
        end))
    end

    task.spawn(function()
        local stages = {
            stagePlayer, stageVehicle, stageJob, stagePlayers, stageSettings, stageControls,
        }
        for i, fn in ipairs(stages) do
            if myGen ~= generation then return end
            pcall(fn)
            task.wait(0.05)
        end
        if myGen ~= generation then return end
        log("11 klar")

        track(RunService.Heartbeat:Connect(function(dt)
            pcall(function() applyPlayer(); applyVehicle(dt) end)
        end))
        track(LP.CharacterAdded:Connect(function()
            task.wait(0.6); resetAssist()
        end))

        installHook()
        tabs.Player.MouseButton1Click:Fire()
        notify("Venice v3.1 · " .. state.ui.keybind.Name, "good")
        if state.job.enabled then startJobLoop() end
    end)
end

rebuild = function()
    teardown()
    task.wait(0.05)
    pcall(buildGUI)
end

pcall(bindSharedInput)
pcall(buildGUI)
