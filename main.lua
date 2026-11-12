--!nocheck
--[[=====================================================================
  Venice Speed Suite  v1.7  ·  Bloxburg  ·  lättversion
  Author: Venice · MIT
  ---------------------------------------------------------------------
  v1.7
    · all klickhantering delar tre globala lyssnare istället för en per reglage
    · fordonsdetektion: SeatPart, sedan SeatWeld i karaktären, sedan
      skanning efter VehicleSeat med dig som Occupant
    · ny Jobb-flik: automatisk pizza via ProximityPrompt/ClickDetector
  CLIENT-SIDE ONLY. Kicken är lokal. Pizzaläget är nyckelordsdrivet och
  behöver trimmas mot det som faktiskt står i Bloxburg.
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)
if not PlayerGui then return warn("[Venice] ingen PlayerGui") end

local function log(m) print("[Venice] " .. m) end

--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local DEFAULT_KEYWORDS = {
    "dough", "sauce", "cheese", "topping", "oven", "bake", "cut", "box", "order",
}

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    job     = { enabled = false, interval = 0.25, radius = 18, keywords = DEFAULT_KEYWORDS },
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
        state.job.interval = num(j.interval, 0.25, 0.1, 3)
        state.job.radius = num(j.radius, 18, 4, 60)
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
            Size = UDim2.new(0, 320, 0, 80), Position = UDim2.new(0.5, -160, 0.5, -40),
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
-- delad inmatning
--=====================================================================
local inputState = { drag = false, off = nil, slider = nil }

local function bindSharedInput()
    track(UserInputService.InputChanged:Connect(function(i)
        local isMove = i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch
        if not isMove then return end

        if inputState.drag and inputState.off then
            local vp = viewport()
            local w = _G.__VeniceSpeedSuite
            if w and w.win then
                w.win.Position = UDim2.new(0,
                    math.clamp(i.Position.X - inputState.off.X, -420 + 80, vp.X - 80),
                    0, math.clamp(i.Position.Y - inputState.off.Y, 0, vp.Y - 40))
            end
            return
        end

        local s = inputState.slider
        if s then s.move(i.Position.X) end
    end))

    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag, inputState.slider = false, nil
    end))
end

--=====================================================================
local WIN_W, WIN_H = 420, 500
local CANVAS = 760

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
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "v1.7",
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

    local function tab(name, order, short)
        local b = new("TextButton", {
            Size = UDim2.new(0, #(short or name) * 6 + 20, 1, -8),
            BackgroundColor3 = C.panel, BorderSizePixel = 0, AutoButtonColor = false,
            LayoutOrder = order, Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = C.dim, Text = short or name,
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

    -- widgets -------------------------------------------------------
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
        probeFrom = 0, primary = nil, anchored = false, lastNote = 0, lastScan = 0,
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

    local function seatFromWeld(hum)
        local char = hum.Parent
        if not char then return nil end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") then
                local other = d.Part1
                if other and (other:IsA("Seat") or other:IsA("VehicleSeat")) then
                    return other
                end
            end
        end
        return nil
    end

    local function seatFromOccupant(hum)
        local ok, res = pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("VehicleSeat") and d.Occupant == hum then return d end
            end
        end)
        if ok then return res end
        return nil
    end

    local function getVehicle()
        local hum = getHumanoid()
        if not hum then return nil end

        local seat = hum.SeatPart
        if not seat then seat = seatFromWeld(hum) end
        if not seat and hum.Sit and os.clock() - assist.lastScan > 0.5 then
            assist.lastScan = os.clock()
            seat = seatFromOccupant(hum)
        end
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
        local okR, ar = pcall(function() return seat.AssemblyRootPart end)
        if okR and ar and ar.Parent and not ar.Anchored
            and not ar:IsA("Seat") and not ar:IsA("VehicleSeat") then
            return ar
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
        return best or model.PrimaryPart or ar
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
            if assist.lastSeat ~= nil then resetAssist() end
            if u then u(nil, 0) end
            return
        end

        if assist.lastSeat ~= seat then
            assist.lastSeat = seat
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
        if seat:IsA("VehicleSeat") then
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

    -- pizza ---------------------------------------------------------
    local function firePrompt(p)
        if type(fireproximityprompt) == "function" then
            local ok = pcall(fireproximityprompt, p)
            if ok then return true end
        end
        return (pcall(function()
            p:InputHoldBegin()
            task.delay(math.max(p.HoldDuration, 0.05), function()
                pcall(function() p:InputHoldEnd() end)
            end)
        end))
    end

    local function fireClick(cd)
        if type(fireclickdetector) == "function" then
            return (pcall(fireclickdetector, cd))
        end
        return false
    end

    local function scanNearby(radius)
        local root = getRoot()
        if not root then return {} end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LP.Character }

        local ok, parts = pcall(function()
            return workspace:GetPartBoundsInRadius(root.Position, radius, params)
        end)
        if not ok or not parts then return {} end

        local found = {}
        for _, part in ipairs(parts) do
            for _, ch in ipairs(part:GetChildren()) do
                if ch:IsA("ProximityPrompt") and ch.Enabled then
                    table.insert(found, {
                        prompt = ch,
                        text = (ch.ActionText .. " " .. ch.ObjectText .. " " .. part.Name):lower(),
                    })
                elseif ch:IsA("ClickDetector") then
                    table.insert(found, { click = ch, text = part.Name:lower() })
                end
            end
        end
        return found
    end

    local function pizzaStep()
        if not state.job.enabled then return end
        local found = scanNearby(state.job.radius)
        if #found == 0 then return end

        for _, kw in ipairs(state.job.keywords) do
            for _, cand in ipairs(found) do
                if cand.text:find(kw, 1, true) then
                    local ok = cand.prompt and firePrompt(cand.prompt) or fireClick(cand.click)
                    local j = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.jobReadout
                    if j then j(ok and ("Tryckte: " .. kw) or ("Misslyckades: " .. kw), ok) end
                    return
                end
            end
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
        detLabel = label(d, "Inte i säte", 24, 12, C.dim)
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
            detLabel.Text = name and ("I: " .. name) or "Inte i säte"
            detLabel.TextColor3 = name and C.good or C.dim
            spdLabel.Text = string.format("%.1f st/s", speed)
            spdLabel.TextColor3 = speed > 0.5 and C.text or C.dim
            infoLabel.Text = info or "metod: —"
            infoLabel.TextColor3 = (info and info:find("anchrad")) and C.bad or C.dim
        end
    end

    local function stageJob()
        log("7 job")
        local c = card(jobPage, 108, 1)
        label(c, "PIZZABAK", 8)
        toggle(c, {
            label = "Baka automatiskt", y = 24, value = state.job.enabled,
            onChanged = function(v)
                state.job.enabled = v
                saveConfig()
                notify(v and "Auto-pizza på" or "Auto-pizza av", v and "good" or nil)
            end,
        })
        slider(c, {
            label = "Intervall", min = 0.1, max = 3, step = 0.05,
            value = state.job.interval, y = 54,
            format = function(x) return string.format("%.2f s", x) end,
            onChanged = function(x) state.job.interval = x; saveConfig() end,
        })

        local rc = card(jobPage, 92, 2)
        slider(rc, {
            label = "Sökradie", min = 4, max = 60, step = 1,
            value = state.job.radius, y = 8,
            format = function(x) return x .. " st" end,
            onChanged = function(x) state.job.radius = x; saveConfig() end,
        })
        local jr = label(rc, "redo", 52, 9, C.dim)
        _G.__VeniceSpeedSuite.jobReadout = function(txt, ok)
            jr.Text = txt
            jr.TextColor3 = ok and C.good or C.bad
        end

        local kc = card(jobPage, 96, 3)
        label(kc, "NYCKELORD (ordning = prioritet)", 8)
        local kb = new("TextBox", {
            Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0, 10, 0, 24),
            BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham,
            TextSize = 10, TextColor3 = C.text, TextWrapped = true,
            ClearTextOnFocus = false, Text = table.concat(state.job.keywords, ", "),
        }, kc)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, kb)

        local function parseKeywords()
            local out = {}
            for w in string.gmatch(kb.Text:lower(), "[^,%s]+") do
                if #w > 0 then table.insert(out, w) end
            end
            if #out > 0 then
                state.job.keywords = out
                saveConfig()
            end
        end
        track(kb.FocusLost:Connect(parseKeywords))

        local sc = card(jobPage, 48, 4)
        button(sc, {
            label = "Skanna nu", y = 10,
            onClick = function()
                local found = scanNearby(state.job.radius)
                notify(string.format("%d träffar inom %d st", #found, state.job.radius),
                    #found > 0 and "good" or "bad")
                if #found > 0 then
                    local names = {}
                    for i = 1, math.min(3, #found) do
                        table.insert(names, found[i].text:sub(1, 22))
                    end
                    jr.Text = table.concat(names, " | ")
                    jr.TextColor3 = C.text
                end
            end,
        })

        local nc = card(jobPage, 74, 5)
        new("TextLabel", {
            Size = UDim2.new(1, -20, 1, -16), Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Trycker ProximityPrompt och ClickDetector i den ordning nyckelorden "
                .. "står. Står du still vid stationen går kedjan deg → sås → ost → ugn "
                .. "→ skär → låda. Ordna om eller lägg till egna ord om något missas.",
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
        local stages = { stagePlayer, stageVehicle, stageJob, stagePlayers, stageSettings, stageControls }
        for i, fn in ipairs(stages) do
            if myGen ~= generation then return end
            local ok, e = pcall(fn)
            if not ok then warn("[Venice] steg " .. i .. ": " .. tostring(e)) end
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
            while gui.Parent do
                task.wait(math.max(state.job.interval, 0.1))
                if state.job.enabled then pcall(pizzaStep) end
            end
        end)

        track(LP.CharacterAdded:Connect(function()
            task.wait(0.6)
            resetAssist()
        end))

        tabs.Player.MouseButton1Click:Fire()
        notify("Venice v1.7 · " .. state.ui.keybind.Name .. " visar", "good")
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

bindSharedInput()
local okB, errB = pcall(buildGUI)
if not okB then
    warn("[Venice] BYGGE MISSLYCKADES: " .. tostring(errB))
    buildFallback(errB)
end
