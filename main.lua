--!nocheck
--[[=====================================================================
  Venice Speed Suite  v1.9  ·  Bloxburg
  Author: Venice · MIT
  ---------------------------------------------------------------------
  v1.9 — bygger på hur Bloxburg faktiskt fungerar, inte på antaganden:
    · fordon hittas via "Vehicle_*"-barnet i karaktären
    · interaktion via PlayerScripts.Modules.InteractionHandler:ShowMenu
      + knappar i PlayerGui._interactUI (firesignal)
    · jobb via PlayerScripts.Modules.JobHandler (GetJob / GoToWork)
  Kräver executor med require, firesignal och setthreadidentity.
  CLIENT-SIDE ONLY. Kicken är lokal.
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)
if not PlayerGui then return warn("[Venice] ingen PlayerGui") end

local function log(m) print("[Venice] " .. m) end
log("0 start")

local function ident(n)
    if setthreadidentity then pcall(setthreadidentity, n) end
end

local function fireSignal(sig)
    if type(firesignal) == "function" then
        return (pcall(firesignal, sig))
    end
    return (pcall(function() sig:Fire() end))
end

--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local DEFAULT_KEYWORDS = {
    "dough", "deg", "sauce", "sås", "cheese", "ost", "topping",
    "oven", "ugn", "bake", "grädda", "cut", "skär", "box", "låda",
    "serve", "give", "counter", "disk",
}

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    job     = {
        enabled = false, interval = 0.4, radius = 30, walk = true,
        jobName = "PizzaPlanetDelivery", keywords = DEFAULT_KEYWORDS,
    },
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
    local j = d.job
    if type(j) == "table" then
        if type(j.enabled) == "boolean" then state.job.enabled = j.enabled end
        if type(j.walk) == "boolean" then state.job.walk = j.walk end
        if type(j.jobName) == "string" then state.job.jobName = j.jobName end
        state.job.interval = num(j.interval, 0.4, 0.15, 3)
        state.job.radius = num(j.radius, 30, 4, 60)
        if type(j.keywords) == "table" then
            local k = {}
            for _, w in ipairs(j.keywords) do
                if type(w) == "string" and #w > 0 then table.insert(k, w:lower()) end
            end
            if #k > 0 then state.job.keywords = k end
        end
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
        player = state.player, vehicle = state.vehicle, limits = state.limits, job = state.job,
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
    bg     = Color3.fromRGB(12, 14, 19),
    panel  = Color3.fromRGB(20, 24, 31),
    card   = Color3.fromRGB(28, 33, 42),
    track  = Color3.fromRGB(44, 50, 62),
    text   = Color3.fromRGB(233, 237, 245),
    dim    = Color3.fromRGB(132, 142, 160),
    good   = Color3.fromRGB(88, 214, 141),
    warn   = Color3.fromRGB(255, 186, 84),
    bad    = Color3.fromRGB(255, 106, 106),
}

local function buildFallback(err)
    pcall(function()
        local g = new("ScreenGui", { ResetOnSpawn = false }, PlayerGui)
        local f = new("Frame", {
            Size = UDim2.new(0, 340, 0, 90), Position = UDim2.new(0.5, -170, 0.5, -45),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
        }, g)
        new("TextLabel", {
            Size = UDim2.new(1, -20, 1, -20), Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
            TextWrapped = true, TextColor3 = C.bad, Text = "GUI fel: " .. tostring(err),
        }, f)
        log("fallback")
    end)
end

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
-- Bloxburg-moduler
--=====================================================================
local blox = { interaction = nil, job = nil, ui = nil }

local function initBlox()
    if blox.interaction then return true end
    local ok = pcall(function()
        local modules = LP:WaitForChild("PlayerScripts", 15):WaitForChild("Modules", 15)
        ident(2)
        blox.interaction = require(modules:WaitForChild("InteractionHandler", 15))
        blox.job = require(modules:WaitForChild("JobHandler", 15))
        ident(0)
    end)
    if not ok then log("kunde inte läsa Bloxburg-moduler") end
    return ok and blox.interaction ~= nil
end

local function getInteractUI()
    if blox.ui and blox.ui.Parent then return blox.ui end
    local ok, ui = pcall(function() return PlayerGui:WaitForChild("_interactUI", 3) end)
    if ok and ui then blox.ui = ui end
    return blox.ui
end

local function showMenu(model, part)
    if not initBlox() then return false end
    local pos = part.Position
    local ok = pcall(function()
        ident(2)
        blox.interaction:ShowMenu(model, pos, part)
        ident(0)
    end)
    if ok then task.wait() end
    return ok
end

local function readButtons()
    local ui = getInteractUI()
    if not ui then return {} end
    local out = {}
    for _, v in ipairs(ui:GetChildren()) do
        local btn = v:FindFirstChild("Button")
        if btn then
            local lbl = btn:FindFirstChild("TextLabel")
            if lbl and lbl.Text ~= "" then table.insert(out, { label = lbl.Text, sig = btn.Activated }) end
        end
    end
    return out
end

local function pressButton(text)
    for _, b in ipairs(readButtons()) do
        if b.label == text then
            fireSignal(b.sig)
            return true
        end
    end
    return false
end

--=====================================================================
local WIN_W, WIN_H = 420, 500
local CANVAS = 900

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
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, win)

    _G.__VeniceSpeedSuite = { gui = gui, win = win, teardown = teardown }

    log("2 header")
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)

    new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Venice Speed Suite",
    }, header)

    new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 12), Position = UDim2.new(0, 14, 0, 24),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "v1.9",
    }, header)

    local status = new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 12), Position = UDim2.new(0, 14, 0, 36),
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
            Size = UDim2.new(0, 26, 0, 24), Position = UDim2.new(1, x, 0, 12),
            BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = col, Text = g,
        }, header)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        return b
    end

    local minBtn, closeBtn = hbtn("–", -64, C.dim), hbtn("×", -34, C.bad)

    log("3 drag")
    track(header.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag = true
        inputState.off = Vector2.new(i.Position.X, i.Position.Y) - win.AbsolutePosition
    end))

    log("4 tabs")
    local bar = new("Frame", {
        Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 54),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
    }, bar)
    new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, bar)

    local content = new("Frame", {
        Size = UDim2.new(1, -20, 1, -150), Position = UDim2.new(0, 10, 0, 92),
        BackgroundTransparency = 1,
    }, win)

    local pages, tabs = {}, {}

    local function tab(name, order)
        local b = new("TextButton", {
            Size = UDim2.new(0, #name * 6 + 20, 1, -8), BackgroundColor3 = C.panel,
            BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = order,
            Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.dim, Text = name,
        }, bar)
        new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, b)

        local p = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.track, CanvasSize = UDim2.new(0, 0, 0, CANVAS),
            Visible = false,
        }, content)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        }, p)
        new("UIPadding", { PaddingBottom = UDim.new(0, 12) }, p)

        pages[name], tabs[name] = p, b
        track(b.MouseButton1Click:Connect(function()
            for o, pg in pairs(pages) do
                pg.Visible = (o == name)
                pcall(function()
                    tabs[o].BackgroundColor3 = o == name and C.card or C.panel
                    tabs[o].TextColor3 = o == name and C.text or C.dim
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
        new("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
        return f
    end

    local function label(parent, text, y, size, col)
        return new("TextLabel", {
            Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, y),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = size or 9, TextColor3 = col or C.dim,
            TextXAlignment = Enum.TextXAlignment.Left, Text = text,
        }, parent)
    end

    local function slider(parent, cfg)
        local row = new("Frame", {
            Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)

        new("TextLabel", {
            Size = UDim2.new(1, -70, 0, 14), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)

        local val = new("TextLabel", {
            Size = UDim2.new(0, 70, 0, 14), Position = UDim2.new(1, -70, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = state.ui.accent, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
        }, row)

        local trk = new("Frame", {
            Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 0, 24),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
        }, row)

        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = state.ui.accent,
            BorderSizePixel = 0,
        }, trk)

        local knob = new("Frame", {
            Size = UDim2.new(0, 12, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 2,
        }, trk)

        local hit = new("Frame", {
            Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11),
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
            v = nv
            render()
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
            Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)

        new("TextLabel", {
            Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)

        local pill = new("TextButton", {
            Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -36, 0.5, -9),
            BackgroundColor3 = C.track, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        }, row)

        local dot = new("Frame", {
            Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 3, 0.5, -6),
            BackgroundColor3 = C.dim, BorderSizePixel = 0,
        }, pill)

        local on = cfg.value and true or false
        local function render()
            pill.BackgroundColor3 = on and state.ui.accent or C.track
            dot.Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            dot.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
        render()

        track(pill.MouseButton1Click:Connect(function()
            on = not on
            render()
            if cfg.onChanged then cfg.onChanged(on) end
        end))
    end

    local function button(parent, cfg)
        local b = new("TextButton", {
            Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundColor3 = cfg.danger and Color3.fromRGB(50, 27, 32) or C.track,
            BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = cfg.danger and C.bad or C.text, Text = cfg.label,
        }, parent)
        track(b.MouseButton1Click:Connect(function()
            if cfg.onClick then
                local ok, e = pcall(cfg.onClick)
                if not ok then notify(e, "bad") end
            end
        end))
        return b
    end

    -- motor ---------------------------------------------------------
    local jumpForced = false
    local rig = { part = nil, att = nil, force = nil }
    local assist = {
        mode = "detect", timer = 0, lastSeat = nil, seats = {},
        applied = nil, writeTimer = 0, direct = false, probe = 0,
        probeFrom = 0, primary = nil, anchored = false, lastNote = 0,
    }
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

    -- fordon: Bloxburg lägger ett "Vehicle_*"-barn i karaktären
    local function vehicleFromCharacter()
        local char = LP.Character
        if not char then return nil end
        for _, d in ipairs(char:GetChildren()) do
            if d:IsA("Model") and d.Name:sub(1, 8) == "Vehicle_" then
                return d
            end
        end
        return nil
    end

    local function getVehicle()
        local hum = getHumanoid()
        if not hum then return nil end

        local model = vehicleFromCharacter()
        if model then
            return model, hum.SeatPart
        end

        local seat = hum.SeatPart
        if not seat then return nil end
        local m = seat:FindFirstAncestorOfClass("Model")
        if not m then return nil end
        local d = 0
        while m.Parent and m.Parent ~= workspace and d < 4 do
            local up = m.Parent:FindFirstAncestorOfClass("Model")
            if not up then break end
            m = up
            d += 1
        end
        return m, seat
    end

    local function pickPrimary(model, seat)
        if seat then
            local okR, ar = pcall(function() return seat.AssemblyRootPart end)
            if okR and ar and ar.Parent and not ar.Anchored
                and not ar:IsA("Seat") and not ar:IsA("VehicleSeat") then
                return ar
            end
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
        assist.mode, assist.timer = "detect", 0
        assist.lastSeat, assist.applied = nil, nil
        assist.writeTimer, assist.direct, assist.probe = 0, false, 0
        assist.primary, assist.anchored = nil, false
        table.clear(assist.seats)
        clearAssistRig()
    end

    local function applyVehicle(dt)
        local model, seat = getVehicle()
        local u = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.vehicleReadout

        if not model then
            if assist.lastSeat ~= nil or assist.primary ~= nil then resetAssist() end
            if u then u(nil, 0) end
            return
        end

        if assist.lastSeat ~= model then
            assist.lastSeat = model
            assist.mode, assist.timer = "detect", 0
            assist.applied, assist.writeTimer = nil, 0
            assist.direct, assist.probe = false, 0
            clearAssistRig()
            cacheSeats(model)
            local okP, p = pcall(pickPrimary, model, seat)
            assist.primary = okP and p or nil
            assist.anchored = assist.primary ~= nil and assist.primary.Anchored
            if assist.anchored and os.clock() - assist.lastNote > 3 then
                assist.lastNote = os.clock()
                notify("Bilen är anchrad — fart går ej att ändra", "bad")
            end
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
        local method = assist.anchored and "anchrad" or (assist.direct and "direkt" or "constraint")
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

        local thr = 0
        if seat and seat:IsA("VehicleSeat") then
            local okT, r = pcall(function() return seat.ThrottleFloat end)
            if okT and type(r) == "number" then thr = r end
        end

        assist.timer += dt
        if math.abs(thr) > 0.02 then assist.mode = "throttle"
        elseif assist.mode == "detect" and assist.timer > 1.2 then assist.mode = "hold" end

        local okF, fwd = pcall(function() return primary.CFrame.LookVector end)
        if not okF or typeof(fwd) ~= "Vector3" then
            if u then u(model.Name, speed, nil, info) end
            return
        end

        local fs = vel:Dot(fwd)
        local desired
        if assist.mode == "throttle" then desired = thr * state.vehicle.maxSpeed
        elseif fs > 0.05 then desired = state.vehicle.maxSpeed
        elseif fs < -0.05 then desired = -state.vehicle.maxSpeed
        else desired = 0 end

        local inc = math.abs(desired) > math.abs(fs)
        local rate = inc and state.vehicle.accel or state.vehicle.brake
        local step = math.clamp(desired - fs, -rate * dt, rate * dt)
        local engaged = math.abs(step) > 0.01

        if engaged and inc and not assist.direct then
            if assist.probe == 0 then
                assist.probe, assist.probeFrom = 0.0001, fs
            else
                assist.probe += dt
                if assist.probe > 1 then
                    if math.abs(fs - assist.probeFrom) < 2 then
                        assist.direct = true
                        notify("Assist: ingen effekt — byter metod", "bad")
                    end
                    assist.probe = 0
                end
            end
        elseif not inc then
            assist.probe = 0
        end

        if not assist.direct and ensureRig(primary) then
            rig.force.LineDirection = fwd
            rig.force.LineVelocity = fs + step
            rig.force.MaxForce = engaged and math.max(primary.AssemblyMass * rate * 2, 12000) or 0
        else
            if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
            if engaged then
                local nv = fwd * (fs + step) + Vector3.new(0, vel.Y, 0)
                pcall(function() primary.AssemblyLinearVelocity = nv end)
            end
        end

        if u then u(model.Name, speed, assist.mode, info) end
    end

    -- pizza via Bloxburgs interaktionsmodul -------------------------
    local jobStatus, jobCount, jobJob
    local jobDone = 0
    local cooldown = {}
    local stationCache = {}

    local function jset(txt, ok)
        if not jobStatus or not jobStatus.Parent then return end
        jobStatus.Text = txt
        jobStatus.TextColor3 = ok and C.good or C.bad
    end

    local function currentJobName()
        if not initBlox() or not blox.job then return nil end
        local ok, name = pcall(function()
            ident(2)
            local n = blox.job:GetJob()
            ident(0)
            return n
        end)
        if ok then return name end
        return nil
    end

    local function nearbyParts(radius)
        local root = getRoot()
        if not root then return {} end
        local ok, parts = pcall(function()
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { LP.Character }
            return workspace:GetPartBoundsInRadius(root.Position, radius, params)
        end)
        if ok and parts then return parts end

        local out = {}
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if #out > 60 then break end
                if d:IsA("BasePart") and (d.Position - root.Position).Magnitude <= radius then
                    table.insert(out, d)
                end
            end
        end)
        return out
    end

    -- fråga stationen vilka knappar den erbjuder
    local function probeStation(part)
        local model = part.Parent
        if not model then return nil end
        if stationCache[model] then return stationCache[model] end

        showMenu(model, part)
        local buttons = readButtons()
        if #buttons == 0 then return nil end

        local entry = { model = model, part = part, buttons = buttons, text = (model.Name .. " " .. part.Name):lower() }
        stationCache[model] = entry
        return entry
    end

    local function scanStations(radius)
        local out = {}
        local seen = {}
        for _, part in ipairs(nearbyParts(radius)) do
            local model = part.Parent
            if model and not seen[model] and model ~= LP.Character then
                seen[model] = true
                local e = probeStation(part)
                if e then table.insert(out, e) end
            end
        end
        return out
    end

    local function pickStation(stations)
        local now = os.clock()
        for _, kw in ipairs(state.job.keywords) do
            if (cooldown[kw] or 0) <= now then
                for _, st in ipairs(stations) do
                    local hitText = st.text:find(kw, 1, true)
                    local hitBtn = nil
                    for _, b in ipairs(st.buttons) do
                        if b.label:lower():find(kw, 1, true) then hitBtn = b; break end
                    end
                    if hitText or hitBtn then
                        return st, hitBtn, kw
                    end
                end
            end
        end
        return nil
    end

    local function pizzaStep()
        if not state.job.enabled then return end
        local hum, root = getHumanoid(), getRoot()
        if not hum or not root then return jset("Ingen karaktär", false) end
        if hum.Health <= 0 then return end
        if vehicleFromCharacter() then return jset("Sitter i fordon", false) end

        if not initBlox() then return jset("Kunde inte läsa InteractionHandler", false) end

        local stations = scanStations(state.job.radius)
        if #stations == 0 then
            stationCache = {}
            return jset("Inga stationer inom " .. math.floor(state.job.radius) .. " st", false)
        end

        local st, btn, kw = pickStation(stations)
        if not st then return jset(#stations .. " stationer, alla i vänteläge", true) end

        local dist = (st.part.Position - root.Position).Magnitude
        if dist > 8 and state.job.walk then
            pcall(function() hum:MoveTo(st.part.Position) end)
            return jset("Går till " .. kw .. string.format(" (%.0f st)", dist), true)
        end

        showMenu(st.model, st.part)
        local buttons = readButtons()
        if #buttons == 0 then
            stationCache[st.model] = nil
            return jset("Menyn tom på " .. kw, false)
        end

        local target = btn
        if not target then
            for _, b in ipairs(buttons) do
                if b.label:lower():find(kw, 1, true) then target = b; break end
            end
        end
        target = target or buttons[1]

        if fireSignal(target.sig) then
            cooldown[kw] = os.clock() + 1.2
            jobDone += 1
            if jobCount and jobCount.Parent then jobCount.Text = jobDone .. " åtgärder" end
            jset("Tryckte: " .. target.label .. " (" .. kw .. ")", true)
        else
            jset("Klick misslyckades: " .. target.label, false)
        end
    end

    -- steg ----------------------------------------------------------
    local speedSlider

    local function stagePlayer()
        log("5 player")
        local c = card(playerPage, 108, 1)
        label(c, "SPELARE", 8)
        toggle(c, {
            label = "Aktivera spelarjustering", y = 24, value = state.player.enabled,
            onChanged = function(v)
                state.player.enabled = v
                saveConfig()
                notify(v and "Spelarjustering på" or "Spelarjustering av", v and "good" or nil)
            end,
        })
        speedSlider = slider(c, {
            label = "Gånghastighet", min = 16, max = 300, step = 1,
            value = state.player.speed, y = 54,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.player.speed = x; saveConfig() end,
        })

        local live = label(playerPage, "16.0 st/s", 8, 13, C.text)
        live.Parent.LayoutOrder = 2

        local jc = card(playerPage, 92, 3)
        label(jc, "HOPP", 8)
        toggle(jc, {
            label = "Egen hoppkraft", y = 24, value = state.player.jumpEnabled,
            onChanged = function(v) state.player.jumpEnabled = v; saveConfig() end,
        })
        slider(jc, {
            label = "Hoppkraft", min = 30, max = 220, step = 1,
            value = state.player.jump, y = 52,
            onChanged = function(x) state.player.jump = x; saveConfig() end,
        })

        local rc = card(playerPage, 48, 4)
        button(rc, {
            label = "Återställ (16 / 50)", y = 10,
            onClick = function()
                state.player.speed, state.player.jump = 16, 50
                speedSlider.set(16)
                saveConfig()
                local hum = getHumanoid()
                if hum then pcall(function()
                    hum.WalkSpeed = 16
                    hum.UseJumpPower = true
                    hum.JumpPower = 50
                end) end
                notify("Återställt", "good")
            end,
        })

        _G.__VeniceSpeedSuite.playerReadout = function(cur, lim)
            live.Text = string.format("%.1f st/s%s", cur, lim and ("  ·  ZONGRÄNS " .. lim) or "")
            live.TextColor3 = lim and C.warn or C.text
        end
    end

    local detLabel, spdLabel, infoLabel

    local function stageVehicle()
        log("6 vehicle")
        local d = card(vehiclePage, 78, 1)
        label(d, "FORDON", 8)
        detLabel = label(d, "Inte i fordon", 24, 12, C.dim)
        spdLabel = label(d, "0.0 st/s", 42, 10, C.dim)
        infoLabel = label(d, "metod: —", 56, 9, C.dim)

        local c = card(vehiclePage, 140, 2)
        toggle(c, {
            label = "Aktivera fordonsjustering", y = 8, value = state.vehicle.enabled,
            onChanged = function(v)
                state.vehicle.enabled = v
                saveConfig()
                notify(v and "Fordonsjustering på" or "Fordonsjustering av", v and "good" or nil)
            end,
        })
        slider(c, {
            label = "Maxfart", min = 30, max = 600, step = 5,
            value = state.vehicle.maxSpeed, y = 38,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.vehicle.maxSpeed = x; saveConfig() end,
        })
        slider(c, {
            label = "Acceleration", min = 20, max = 600, step = 5,
            value = state.vehicle.accel, y = 78,
            format = function(x) return x .. " st/s²" end,
            onChanged = function(x) state.vehicle.accel = x; saveConfig() end,
        })

        local bc = card(vehiclePage, 110, 3)
        slider(bc, {
            label = "Bromskraft", min = 40, max = 900, step = 10,
            value = state.vehicle.brake, y = 8,
            format = function(x) return x .. " st/s²" end,
            onChanged = function(x) state.vehicle.brake = x; saveConfig() end,
        })
        toggle(bc, {
            label = "Fysikassist", y = 52, value = state.vehicle.assist,
            onChanged = function(v)
                state.vehicle.assist = v
                saveConfig()
                notify(v and "Assist på" or "Assist av", nil)
            end,
        })

        local rc = card(vehiclePage, 48, 4)
        button(rc, {
            label = "Återställ fordon", y = 10,
            onClick = function()
                state.vehicle.maxSpeed, state.vehicle.accel, state.vehicle.brake = 130, 110, 190
                saveConfig()
                rebuild()
            end,
        })

        _G.__VeniceSpeedSuite.vehicleReadout = function(name, speed, _, info)
            detLabel.Text = name and ("I: " .. name) or "Inte i fordon"
            detLabel.TextColor3 = name and C.good or C.dim
            spdLabel.Text = string.format("%.1f st/s", speed)
            spdLabel.TextColor3 = speed > 0.5 and C.text or C.dim
            infoLabel.Text = info or "metod: —"
            infoLabel.TextColor3 = (info and info:find("anchrad")) and C.bad or C.dim
        end
    end

    local function stageJob()
        log("7 job")
        local c = card(jobPage, 140, 1)
        label(c, "PIZZABAK", 8)
        toggle(c, {
            label = "Baka automatiskt", y = 24, value = state.job.enabled,
            onChanged = function(v)
                state.job.enabled = v
                saveConfig()
                table.clear(cooldown)
                stationCache = {}
                notify(v and "Auto-pizza på" or "Auto-pizza av", v and "good" or nil)
                if not v then jset("Avstängt", true) end
            end,
        })
        toggle(c, {
            label = "Gå fram själv", y = 52, value = state.job.walk,
            onChanged = function(v) state.job.walk = v; saveConfig() end,
        })
        slider(c, {
            label = "Intervall", min = 0.15, max = 3, step = 0.05,
            value = state.job.interval, y = 82,
            format = function(x) return string.format("%.2f s", x) end,
            onChanged = function(x) state.job.interval = x; saveConfig() end,
        })
        jobJob = label(c, "jobb: —", 120, 9, C.dim)

        local rc = card(jobPage, 84, 2)
        slider(rc, {
            label = "Sökradie", min = 6, max = 60, step = 1,
            value = state.job.radius, y = 6,
            format = function(x) return x .. " st" end,
            onChanged = function(x) state.job.radius = x; saveConfig(); stationCache = {} end,
        })
        jobStatus = label(rc, "redo", 44, 9, C.dim)
        jobCount = label(rc, "0 åtgärder", 58, 9, C.dim)

        local wc = card(jobPage, 78, 3)
        button(wc, {
            label = "Börja jobba", y = 8,
            onClick = function()
                if not initBlox() then return notify("Moduler saknas", "bad") end
                local ok, e = pcall(function()
                    ident(2)
                    blox.job:GoToWork(state.job.jobName)
                    ident(0)
                end)
                notify(ok and ("Startar " .. state.job.jobName) or tostring(e), ok and "good" or "bad")
            end,
        })
        button(wc, {
            label = "Avsluta passet", y = 42,
            onClick = function()
                local btn = PlayerGui:FindFirstChild("MainGUI")
                local sig
                pcall(function()
                    sig = btn.Bar.CharMenu.WorkFrame.WorkFrame.Action.Activated
                end)
                if sig then
                    fireSignal(sig)
                    notify("Avslutar", "good")
                else
                    notify("Hittade ingen avsluta-knapp", "bad")
                end
            end,
        })

        local kc = card(jobPage, 108, 4)
        label(kc, "NYCKELORD · ORDNING = PRIORITET", 8)
        local kb = new("TextBox", {
            Size = UDim2.new(1, -20, 0, 58), Position = UDim2.new(0, 10, 0, 24),
            BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham,
            TextSize = 10, TextColor3 = C.text, TextWrapped = true,
            ClearTextOnFocus = false, Text = table.concat(state.job.keywords, ", "),
        }, kc)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, kb)

        track(kb.FocusLost:Connect(function()
            local out = {}
            for w in string.gmatch(kb.Text:lower(), "[^,%s]+") do
                if #w > 0 then table.insert(out, w) end
            end
            if #out > 0 then
                state.job.keywords = out
                table.clear(cooldown)
                saveConfig()
                notify(#out .. " nyckelord sparade", "good")
            end
        end))

        local sc = card(jobPage, 48, 5)
        button(sc, {
            label = "Läs av stationer i närheten", y = 10,
            onClick = function()
                stationCache = {}
                local stations = scanStations(state.job.radius)
                notify(string.format("%d stationer hittade", #stations),
                    #stations > 0 and "good" or "bad")
                if #stations > 0 then
                    local parts = {}
                    for i = 1, math.min(4, #stations) do
                        local names = {}
                        for j = 1, math.min(2, #stations[i].buttons) do
                            table.insert(names, stations[i].buttons[j].label)
                        end
                        table.insert(parts, stations[i].model.Name .. "[" .. table.concat(names, "/") .. "]")
                    end
                    jset(table.concat(parts, " | "), true)
                end
            end,
        })

        local nc = card(jobPage, 96, 6)
        new("TextLabel", {
            Size = UDim2.new(1, -20, 1, -16), Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Läser Bloxburgs egna interaktionsmeny istället för att gissa. "
                .. "Tryck Läs av stationer först och se vilka namn och knappar som dyker "
                .. "upp, skriv sedan nyckelord som matchar dem. Ligger nästa station "
                .. "över 8 studs bort går karaktären dit. 1,2 s väntetid per station.",
        }, nc)
    end

    local refreshPlayers

    local function stagePlayers()
        log("8 players")
        local c = card(playersPage, 140, 1)
        label(c, "SERVER", 8)
        local count = label(c, "—", 22, 10, C.dim)

        local function sb(text, x, w, fn, danger)
            local b = new("TextButton", {
                Size = UDim2.new(0, w, 0, 24), Position = UDim2.new(0, x, 0, 40),
                BackgroundColor3 = danger and Color3.fromRGB(50, 27, 32) or C.track,
                BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.Gotham,
                TextSize = 9, TextColor3 = danger and C.bad or C.text, Text = text,
            }, c)
            b.MouseButton1Click:Connect(function() pcall(fn) end)
            return b
        end

        sb("Markera alla", 10, 100, function()
            table.clear(selected)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then selected[p.UserId] = true end
            end
            refreshPlayers()
        end)
        sb("Rensa", 116, 60, function()
            table.clear(selected)
            refreshPlayers()
        end)
        sb("Kick markerade", 182, 110, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and selected[p.UserId] then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice") end)
                end
            end
            if n == 0 then return notify("Ingen markerad", "bad") end
            notify("Kick skickat till " .. n, "good")
            task.delay(1.6, refreshPlayers)
        end, true)

        sb("Kick alla andra", 10, 140, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice") end)
                end
            end
            notify(n > 0 and ("Kick skickat till " .. n) or "Ingen att kicka",
                n > 0 and "good" or "bad")
            task.delay(1.6, refreshPlayers)
        end)

        local lc = card(playersPage, 200, 2)
        local list = new("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 184), Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 184),
        }, lc)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3),
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
                        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panel,
                        BorderSizePixel = 0, LayoutOrder = shown,
                    }, list)

                    local cb = new("TextButton", {
                        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 5, 0.5, -7),
                        BackgroundColor3 = on and state.ui.accent or C.track,
                        BorderSizePixel = 0, AutoButtonColor = false,
                        Font = Enum.Font.GothamBold, TextSize = 9,
                        TextColor3 = Color3.new(1, 1, 1), Text = on and "x" or "",
                    }, row)
                    cb.MouseButton1Click:Connect(function()
                        selected[p.UserId] = (not selected[p.UserId]) or nil
                        refreshPlayers()
                    end)

                    new("TextLabel", {
                        Size = UDim2.new(1, -86, 1, 0), Position = UDim2.new(0, 24, 0, 0),
                        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
                        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd, Text = p.Name,
                    }, row)

                    local kbb = new("TextButton", {
                        Size = UDim2.new(0, 42, 0, 16), Position = UDim2.new(1, -47, 0.5, -8),
                        BackgroundColor3 = Color3.fromRGB(50, 27, 32), BorderSizePixel = 0,
                        AutoButtonColor = false, Font = Enum.Font.GothamBold,
                        TextSize = 8, TextColor3 = C.bad, Text = "kick",
                    }, row)
                    kbb.MouseButton1Click:Connect(function()
                        pcall(function() p:Kick("Kickad av Venice") end)
                        notify("Kick skickat till " .. p.Name, "good")
                        task.delay(1.6, refreshPlayers)
                    end)
                end
            end

            list.CanvasSize = UDim2.new(0, 0, 0, math.max(184, shown * 27 + 6))
            if shown == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = "Ensam i servern.",
                }, list)
            end
        end
        refreshPlayers()

        track(Players.PlayerAdded:Connect(function() task.delay(0.5, refreshPlayers) end))
        track(Players.PlayerRemoving:Connect(function() task.delay(0.5, refreshPlayers) end))
        track(tabs.Players.MouseButton1Click:Connect(refreshPlayers))

        local note = label(playersPage, "Kick är lokalt — servern kan lägga tillbaka dem.", 0, 9, C.dim)
        note.LayoutOrder = 3
        note.TextWrapped = true
        note.Size = UDim2.new(1, 0, 0, 24)
    end

    local function stageSettings()
        log("9 settings")
        local c = card(settPage, 100, 1)
        label(c, "FARTSGRÄNSER", 8)
        toggle(c, {
            label = "Tillämpa gränser", y = 22, value = state.limits.enabled,
            onChanged = function(v)
                state.limits.enabled = v
                saveConfig()
                notify(v and "Gränser på" or "Gränser av", nil)
            end,
        })
        slider(c, {
            label = "Standardgräns", min = 16, max = 300, step = 1,
            value = state.limits.global, y = 52,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.limits.global = x; saveConfig() end,
        })

        local zc = card(settPage, 160, 2)
        label(zc, "ZONER", 8)
        local add = new("TextButton", {
            Size = UDim2.new(1, -150, 0, 24), Position = UDim2.new(0, 10, 0, 22),
            BackgroundColor3 = C.track, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "  Lägg zon här",
        }, zc)

        local function fld(x, ph, txt)
            return new("TextBox", {
                Size = UDim2.new(0, 58, 0, 24), Position = UDim2.new(1, x, 0, 22),
                BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham,
                TextSize = 9, TextColor3 = C.text, PlaceholderText = ph, Text = txt,
                ClearTextOnFocus = false, ZIndex = 2,
            }, zc)
        end
        local lb, rb = fld(-132, "gräns", "60"), fld(-70, "radie", "45")

        local zlist = new("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 96), Position = UDim2.new(0, 10, 0, 54),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 96),
        }, zc)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3),
        }, zlist)

        local function renderZones()
            for _, ch in ipairs(zlist:GetChildren()) do
                if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
            end
            local n = #state.limits.zones
            zlist.CanvasSize = UDim2.new(0, 0, 0, math.max(96, n * 27 + 6))
            if n == 0 then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = "Inga zoner.",
                }, zlist)
                return
            end
            for i, z in ipairs(state.limits.zones) do
                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panel,
                    BorderSizePixel = 0, LayoutOrder = i,
                }, zlist)
                new("TextLabel", {
                    Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
                    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = string.format("%s · %dst/s", z.name or ("Zon " .. i), z.limit),
                }, row)
                local del = new("TextButton", {
                    Size = UDim2.new(0, 20, 0, 16), Position = UDim2.new(1, -24, 0.5, -8),
                    BackgroundColor3 = Color3.fromRGB(50, 27, 32), BorderSizePixel = 0,
                    AutoButtonColor = false, Font = Enum.Font.GothamBold,
                    TextSize = 10, TextColor3 = C.bad, Text = "x",
                }, row)
                del.MouseButton1Click:Connect(function()
                    table.remove(state.limits.zones, i)
                    saveConfig()
                    renderZones()
                    notify("Zon borttagen", nil)
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
            saveConfig()
            renderZones()
            notify("Zon tillagd · " .. lim .. " st/s", "good")
        end))

        local pc = card(settPage, 80, 3)
        button(pc, {
            label = "Spara config", y = 6,
            onClick = function()
                if not hasFS then return notify("Inget filsystem", "bad") end
                saveConfig()
                notify("Sparad", "good")
            end,
        })
        button(pc, {
            label = "Återställ allt", y = 42,
            onClick = function()
                state = deepCopy(DEFAULTS)
                saveConfig()
                notify("Allt återställt", "good")
                task.delay(0.15, rebuild)
            end,
        })

        local dc = card(settPage, 46, 4)
        button(dc, {
            label = "Ladda ur", y = 9, danger = true,
            onClick = function()
                notify("Laddar ur…", "bad")
                task.wait(0.3)
                teardown()
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
                win.Size = UDim2.new(0, WIN_W, 0, 50)
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
            win.Size = UDim2.new(0, WIN_W, 0, v and 0 or (min and 50 or expH))
        end

        track(closeBtn.MouseButton1Click:Connect(function()
            setHidden(true)
            notify("Gömd · " .. state.ui.keybind.Name .. " visar", nil)
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
            local ok, e = pcall(fn)
            if not ok then
                warn("[Venice] steg " .. i .. ": " .. tostring(e))
                jset("Steg " .. i .. " fel: " .. tostring(e), false)
            end
            task.wait(0.05)
        end
        if myGen ~= generation then return end

        log("11 loop")
        task.wait(0.3)

        track(RunService.Heartbeat:Connect(function(dt)
            local ok, e = pcall(function()
                applyPlayer()
                applyVehicle(dt)
            end)
            if not ok then warn("[Venice] loop: " .. tostring(e)) end
        end))

        task.spawn(function()
            local tickCount = 0
            while gui.Parent do
                local iv = 0.4
                pcall(function() iv = math.max(tonumber(state.job.interval) or 0.4, 0.15) end)
                task.wait(iv)
                tickCount += 1
                if state.job.enabled then
                    local ok, e = pcall(pizzaStep)
                    if not ok then jset("Pizza-fel: " .. tostring(e), false) end
                end
                if tickCount % 8 == 0 and jobJob and jobJob.Parent then
                    local n = currentJobName()
                    jobJob.Text = "jobb: " .. (n or "inget")
                    jobJob.TextColor3 = n and C.good or C.dim
                end
            end
        end)

        track(LP.CharacterAdded:Connect(function()
            task.wait(0.6)
            resetAssist()
            stationCache = {}
        end))

        tabs.Player.MouseButton1Click:Fire()
        notify("Venice v1.9 · " .. state.ui.keybind.Name .. " visar", "good")
        log("12 klar")
    end)
end

rebuild = function()
    teardown()
    task.wait(0.05)
    local ok, e = pcall(buildGUI)
    if not ok then
        warn("[Venice] rebuild: " .. tostring(e))
        buildFallback(e)
    end
end

pcall(bindSharedInput)
local okB, errB = pcall(buildGUI)
if not okB then
    warn("[Venice] BYGGE MISSLYCKADES: " .. tostring(errB))
    buildFallback(errB)
end
