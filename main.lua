print("[Venice] START")

local VERSION = "2.2"

-- ============================================================
--  STEG 1: SKAPA GUI ALLRA FÖRST (inga riskabla anrop)
-- ============================================================
local ScreenGui = nil
pcall(function()
    local sg = Instance.new("ScreenGui")
    sg.Name = "VeniceSpeedSuite"
    sg.ResetPlayerGuiOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui", 10)
    ScreenGui = sg
end)

if not ScreenGui then
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "VeniceSpeedSuite"
        sg.ResetPlayerGuiOnSpawn = false
        sg.Parent = game:GetService("CoreGui")
        ScreenGui = sg
    end)
end

if not ScreenGui then
    warn("[Venice] KAN INTE SKAPA GUI")
    return
end

print("[Venice] GUI skapad OK")

-- ============================================================
--  STEG 2: SÄKRA FUNKTIONER (allt i pcall)
-- ============================================================
local tWait  = wait
pcall(function() tWait = task.wait end)

local tSpawn = spawn
pcall(function() tSpawn = task.spawn end)

local tDelay = delay
pcall(function() tDelay = task.delay end)

local firePrompt = nil
pcall(function()
    if getgenv and getgenv().fireproximityprompt then
        firePrompt = getgenv().fireproximityprompt
    end
end)
if not firePrompt then
    pcall(function()
        if _G.fireproximityprompt then firePrompt = _G.fireproximityprompt end
    end)
end

local fireClick = nil
pcall(function()
    if getgenv and getgenv().fireclickdetector then
        fireClick = getgenv().fireclickdetector
    end
end)
if not fireClick then
    pcall(function()
        if _G.fireclickdetector then fireClick = _G.fireclickdetector end
    end)
end

local getConns = nil
pcall(function()
    if getgenv and getgenv().getconnections then
        getConns = getgenv().getconnections
    end
end)
if not getConns then
    pcall(function()
        if _G.getconnections then getConns = _G.getconnections end
    end)
end

print("[Venice] Executor: fp=" .. tostring(firePrompt~=nil) .. " fc=" .. tostring(fireClick~=nil) .. " gc=" .. tostring(getConns~=nil))

-- ============================================================
--  STEG 3: SERVICES
-- ============================================================
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local player      = Players.LocalPlayer

local function notify(msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Venice Suite", Text = msg, Duration = dur or 3
        })
    end)
end

-- ============================================================
--  FÄRGER & STIL
-- ============================================================
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
    accent = Color3.fromRGB(94, 141, 255),
}
local FONT  = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold

local function mkCorner(r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    return c
end

local function mkStroke(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or C.track
    s.Thickness = t or 1
    s.Parent = p
end

-- ============================================================
--  KONFIGURATION
-- ============================================================
local CFG_FILE = "VeniceSpeedSuite.json"
local cfg = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    job = {
        enabled = false, interval = 0.1, radius = 15, mode = "aggressive",
        firePrompts = true, fireClicks = true, useBlacklist = true, maxPerTick = 8,
        blacklist = "door,gate,exit,entrance,sleep,bed,sit,chair,seat,menu,shop,buy,purchase,sell,radio,tv,television,stereo,toilet,sink,shower,bath,trash,bin,garbage",
        keywords  = "dough,sauce,cheese,pepperoni,topping,oven,bake,cook,cut,slice,box,package,order,deliver,pizza,knead,prepare,serve,grab,take,put,flatten,roll",
    },
    limits = { enabled = false, global = 110, zones = {} },
    ui = { keybind = "K" },
}

pcall(function()
    if isfile and isfile(CFG_FILE) and readfile then
        local d = HttpService:JSONDecode(readfile(CFG_FILE))
        local function merge(s, t)
            for k, v in pairs(s) do
                if type(v) == "table" and type(t[k]) == "table" then merge(v, t[k])
                elseif t[k] == nil then t[k] = v end
            end
        end
        merge(d, cfg)
    end
end)

local saveTok = 0
local function saveCfg()
    saveTok = saveTok + 1
    local tok = saveTok
    tDelay(0.6, function()
        if tok ~= saveTok then return end
        pcall(function()
            if writefile then writefile(CFG_FILE, HttpService:JSONEncode(cfg)) end
        end)
    end)
end

-- ============================================================
--  HUVUDFÖNSTER
-- ============================================================
local WIN_W, WIN_H = 460, 560
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(WIN_W, WIN_H)
main.Position = UDim2.fromOffset(80, 80)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
mkCorner(main)
mkStroke(main, C.track, 1.5)
main.Parent = ScreenGui

-- Titelbar
local tbar = Instance.new("Frame")
tbar.Size = UDim2.new(1, 0, 0, 36)
tbar.BackgroundColor3 = C.panel
tbar.BorderSizePixel = 0
tbar.Parent = main
mkCorner(tbar)

local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1, -80, 1, 0)
ttl.Position = UDim2.fromOffset(12, 0)
ttl.BackgroundTransparency = 1
ttl.Text = "⚡ Venice Speed Suite v" .. VERSION
ttl.TextColor3 = C.accent
ttl.TextSize = 14
ttl.Font = FONTB
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Parent = tbar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = C.bad
closeBtn.Text = "✕"
closeBtn.TextColor3 = C.text
closeBtn.TextSize = 13
closeBtn.Font = FONTB
closeBtn.BorderSizePixel = 0
closeBtn.Parent = tbar
mkCorner(closeBtn)
closeBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.Position = UDim2.new(1, -64, 0, 4)
minBtn.BackgroundColor3 = C.warn
minBtn.Text = "—"
minBtn.TextColor3 = C.text
minBtn.TextSize = 13
minBtn.Font = FONTB
minBtn.BorderSizePixel = 0
minBtn.Parent = tbar
mkCorner(minBtn)
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    main.Size = minimized and UDim2.fromOffset(WIN_W, 36) or UDim2.fromOffset(WIN_W, WIN_H)
end)

-- ============================================================
--  TAB-SYSTEM
-- ============================================================
local TABS = { "Player", "Vehicle", "Job", "Players", "Settings" }
local tFrames = {}
local tBtns = {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.fromOffset(0, 36)
tabBar.BackgroundColor3 = C.panel
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local tContent = Instance.new("Frame")
tContent.Size = UDim2.new(1, -16, 1, -86)
tContent.Position = UDim2.fromOffset(8, 78)
tContent.BackgroundTransparency = 1
tContent.ClipsDescendants = true
tContent.Parent = main

local tw = 1 / #TABS
for i, name in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(tw, 0, 1, 0)
    btn.Position = UDim2.new(tw * (i - 1), 0, 0, 0)
    btn.BackgroundColor3 = C.bg
    btn.Text = name
    btn.TextColor3 = C.dim
    btn.TextSize = 11
    btn.Font = FONT
    btn.BorderSizePixel = 0
    btn.Parent = tabBar

    local fr = Instance.new("ScrollingFrame")
    fr.Size = UDim2.new(1, 0, 1, 0)
    fr.BackgroundTransparency = 1
    fr.BorderSizePixel = 0
    fr.ScrollBarThickness = 4
    fr.ScrollBarImageColor3 = C.track
    fr.CanvasSize = UDim2.new(0, 0, 0, 0)
    fr.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fr.Visible = false
    fr.Parent = tContent

    local ul = Instance.new("UIListLayout")
    ul.SortOrder = Enum.SortOrder.LayoutOrder
    ul.Padding = UDim.new(0, 6)
    ul.Parent = fr

    local up = Instance.new("UIPadding")
    up.PaddingTop = UDim.new(0, 4)
    up.PaddingBottom = UDim.new(0, 8)
    up.Parent = fr

    tFrames[name] = fr
    tBtns[name] = btn

    btn.MouseButton1Click:Connect(function()
        for n, f in pairs(tFrames) do
            f.Visible = false
            tBtns[n].BackgroundColor3 = C.bg
            tBtns[n].TextColor3 = C.dim
        end
        fr.Visible = true
        btn.BackgroundColor3 = C.card
        btn.TextColor3 = C.accent
    end)
end

tBtns["Player"].BackgroundColor3 = C.card
tBtns["Player"].TextColor3 = C.accent
tFrames["Player"].Visible = true

print("[Venice] Tabs skapade OK")

-- ============================================================
--  UI-KOMPONENTER
-- ============================================================
local function mkCard(parent, title)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, -4, 0, 0)
    c.AutomaticSize = Enum.AutomaticSize.Y
    c.BackgroundColor3 = C.card
    c.BorderSizePixel = 0
    c.Parent = parent
    mkCorner(c)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 10)
    p.PaddingRight = UDim.new(0, 10)
    p.PaddingTop = UDim.new(0, 8)
    p.PaddingBottom = UDim.new(0, 8)
    p.Parent = c
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 5)
    l.Parent = c
    if title then
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 0, 18)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = C.accent
        t.TextSize = 12
        t.Font = FONTB
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = c
    end
    return c
end

local function mkToggle(parent, label, def, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -50, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = label
    t.TextColor3 = C.text
    t.TextSize = 12
    t.Font = FONT
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = row
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(42, 22)
    b.Position = UDim2.new(1, -44, 0, 3)
    b.BackgroundColor3 = def and C.good or C.track
    b.Text = def and "PÅ" or "AV"
    b.TextColor3 = C.text
    b.TextSize = 10
    b.Font = FONTB
    b.BorderSizePixel = 0
    b.Parent = row
    mkCorner(b, UDim.new(0, 6))
    local st = def
    b.MouseButton1Click:Connect(function()
        st = not st
        b.BackgroundColor3 = st and C.good or C.track
        b.Text = st and "PÅ" or "AV"
        if cb then pcall(cb, st) end
    end)
    return function(v)
        st = v
        b.BackgroundColor3 = st and C.good or C.track
        b.Text = st and "PÅ" or "AV"
    end
end

local function mkSlider(parent, label, mn, mx, def, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0.6, 0, 0, 16)
    t.BackgroundTransparency = 1
    t.Text = label
    t.TextColor3 = C.text
    t.TextSize = 11
    t.Font = FONT
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = row
    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0.4, 0, 0, 16)
    vl.BackgroundTransparency = 1
    vl.Text = tostring(def)
    vl.TextColor3 = C.accent
    vl.TextSize = 11
    vl.Font = FONTB
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = row
    local tr = Instance.new("Frame")
    tr.Size = UDim2.new(1, 0, 0, 6)
    tr.Position = UDim2.fromOffset(0, 22)
    tr.BackgroundColor3 = C.track
    tr.BorderSizePixel = 0
    tr.Parent = row
    mkCorner(tr, UDim.new(0, 3))
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new(math.clamp((def - mn) / (mx - mn), 0, 1), 0, 1, 0)
    fl.BackgroundColor3 = C.accent
    fl.BorderSizePixel = 0
    fl.Parent = tr
    mkCorner(fl, UDim.new(0, 3))
    local drag = false
    tr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not drag then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            local r = math.clamp((inp.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
            local v = math.floor(mn + r * (mx - mn) + 0.5)
            fl.Size = UDim2.new(r, 0, 1, 0)
            vl.Text = tostring(v)
            if cb then pcall(cb, v) end
        end
    end)
    return vl
end

local function mkLabel(parent, text, color, sz)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, sz or 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or C.dim
    l.TextSize = 11
    l.Font = FONT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function mkBtn(parent, text, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = color or C.accent
    b.Text = text
    b.TextColor3 = C.text
    b.TextSize = 12
    b.Font = FONTB
    b.BorderSizePixel = 0
    b.Parent = parent
    mkCorner(b)
    if cb then b.MouseButton1Click:Connect(function() pcall(cb) end) end
    return b
end

local function mkSep(parent)
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1, 0, 0, 1)
    s.BackgroundColor3 = C.track
    s.BorderSizePixel = 0
    s.Parent = parent
end

-- ============================================================
--  TAB: PLAYER
-- ============================================================
pcall(function()
    local f = tFrames["Player"]
    local c1 = mkCard(f, "🏃 Rörelse")
    mkToggle(c1, "Walkspeed-hack", cfg.player.enabled, function(v) cfg.player.enabled = v; saveCfg() end)
    mkSlider(c1, "Hastighet", 16, 300, cfg.player.speed, function(v) cfg.player.speed = v; saveCfg() end)
    mkSep(c1)
    mkToggle(c1, "Jump-hack", cfg.player.jumpEnabled, function(v) cfg.player.jumpEnabled = v; saveCfg() end)
    mkSlider(c1, "Hopphöjd", 50, 400, cfg.player.jump, function(v) cfg.player.jump = v; saveCfg() end)

    local c2 = mkCard(f, "📊 Status")
    local pStat = mkLabel(c2, "WalkSpeed: -- | JumpPower: --", C.dim)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.07)
            pcall(function()
                local ch = player.Character
                if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid")
                if not h then return end
                if cfg.player.enabled then h.WalkSpeed = cfg.player.speed end
                if cfg.player.jumpEnabled then h.JumpPower = cfg.player.jump; h.UseJumpPower = true end
                pStat.Text = string.format("WalkSpeed: %d | JumpPower: %d", math.floor(h.WalkSpeed), math.floor(h.JumpPower))
                pStat.TextColor3 = cfg.player.enabled and C.good or C.dim
            end)
        end
    end)
end)

-- ============================================================
--  TAB: VEHICLE
-- ============================================================
pcall(function()
    local f = tFrames["Vehicle"]
    local c1 = mkCard(f, "🚗 Fordonshack")
    mkToggle(c1, "Aktivera", cfg.vehicle.enabled, function(v) cfg.vehicle.enabled = v; saveCfg() end)
    mkSlider(c1, "Maxhastighet", 30, 500, cfg.vehicle.maxSpeed, function(v) cfg.vehicle.maxSpeed = v; saveCfg() end)
    mkSlider(c1, "Acceleration", 20, 600, cfg.vehicle.accel, function(v) cfg.vehicle.accel = v; saveCfg() end)
    mkSlider(c1, "Broms", 30, 600, cfg.vehicle.brake, function(v) cfg.vehicle.brake = v; saveCfg() end)
    mkSep(c1)
    mkToggle(c1, "Fysik-assist (anti-vält)", cfg.vehicle.assist, function(v) cfg.vehicle.assist = v; saveCfg() end)

    local c2 = mkCard(f, "📊 Fordonsinfo")
    local vStat = mkLabel(c2, "Inget fordon", C.dim)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.05)
            pcall(function()
                if not cfg.vehicle.enabled then
                    vStat.Text = "Hack AV"
                    vStat.TextColor3 = C.dim
                    return
                end
                local ch = player.Character
                if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid")
                if not h then return end
                local seat = h.SeatPart
                if not seat then
                    vStat.Text = "Sitter inte i fordon"
                    vStat.TextColor3 = C.warn
                    return
                end
                local vs = nil
                if seat:IsA("VehicleSeat") then
                    vs = seat
                else
                    pcall(function() vs = seat:FindFirstAncestorWhichIsA("VehicleSeat") end)
                end
                if not vs then
                    pcall(function()
                        local m = seat:FindFirstAncestorWhichIsA("Model")
                        if m then vs = m:FindFirstChildWhichIsA("VehicleSeat") end
                    end)
                end
                if not vs then
                    vStat.Text = "Ingen VehicleSeat hittad"
                    vStat.TextColor3 = C.warn
                    return
                end
                vs.MaxSpeed = cfg.vehicle.maxSpeed
                pcall(function()
                    if vs:FindFirstChild("Torque") then vs.Torque = cfg.vehicle.accel end
                end)
                vStat.Text = string.format("Fordon: %s | Speed: %d", (vs.Parent and vs.Parent.Name or "?"), cfg.vehicle.maxSpeed)
                vStat.TextColor3 = C.good
                if cfg.vehicle.assist then
                    pcall(function()
                        local root = seat:FindFirstAncestorWhichIsA("Model")
                        if root then
                            local pp = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart")
                            if pp then
                                local cf = pp.CFrame
                                local up = CFrame.fromMatrix(cf.Position, cf.RightVector, Vector3.new(0, 1, 0))
                                pp.CFrame = pp.CFrame:Lerp(up, 0.08)
                            end
                        end
                    end)
                end
            end)
        end
    end)
end)

-- ============================================================
--  TAB: JOB (Pizza Auto-Farm)
-- ============================================================
pcall(function()
    local f = tFrames["Job"]
    local c1 = mkCard(f, "🍕 Pizza Auto-Farm")

    local statusLbl = mkLabel(c1, "Status: AV", C.dim)
    local statsLbl  = mkLabel(c1, "A:0 | P:0 | C:0 | F:0", C.dim)
    local debugLbl  = mkLabel(c1, "Debug: väntar...", C.dim, 48)
    debugLbl.AutomaticSize = Enum.AutomaticSize.Y

    local stats = { a = 0, p = 0, c = 0, f = 0 }

    mkToggle(c1, "Aktivera pizza-farm", cfg.job.enabled, function(v)
        cfg.job.enabled = v
        statusLbl.Text = v and "Status: PÅ ✓" or "Status: AV"
        statusLbl.TextColor3 = v and C.good or C.dim
        saveCfg()
    end)

    mkSep(c1)
    mkSlider(c1, "Intervall (ms×10)", 1, 10, math.floor(cfg.job.interval * 10), function(v) cfg.job.interval = v / 10; saveCfg() end)
    mkSlider(c1, "Radie (studs)", 5, 50, cfg.job.radius, function(v) cfg.job.radius = v; saveCfg() end)
    mkSlider(c1, "Max per tick", 1, 20, cfg.job.maxPerTick, function(v) cfg.job.maxPerTick = v; saveCfg() end)

    mkSep(c1)
    mkToggle(c1, "Avfyra ProximityPrompts", cfg.job.firePrompts, function(v) cfg.job.firePrompts = v; saveCfg() end)
    mkToggle(c1, "Avfyra ClickDetectors", cfg.job.fireClicks, function(v) cfg.job.fireClicks = v; saveCfg() end)
    mkToggle(c1, "Använd svartlista", cfg.job.useBlacklist, function(v) cfg.job.useBlacklist = v; saveCfg() end)

    mkSep(c1)
    local modeLbl = mkLabel(c1, "Läge: " .. cfg.job.mode, C.accent)
    mkBtn(c1, "🔄 Växla läge (aggressive/keyword)", C.warn, function()
        cfg.job.mode = cfg.job.mode == "aggressive" and "keyword" or "aggressive"
        modeLbl.Text = "Läge: " .. cfg.job.mode
        saveCfg()
        notify("Läge: " .. cfg.job.mode)
    end)

    local c2 = mkCard(f, "🔧 Verktyg")
    local cacheDirty = true
    local fireManual = false

    mkBtn(c2, "🔍 FORCE SCAN", C.warn, function()
        cacheDirty = true
        notify("Skannar om...")
    end)
    mkBtn(c2, "🎯 Avfyra närmaste manuellt", C.accent, function() fireManual = true end)
    mkBtn(c2, "🗑️ Nollställ statistik", C.bad, function()
        stats = { a = 0, p = 0, c = 0, f = 0 }
        notify("Nollställd")
    end)

    local pCache = {}
    local cCache = {}
    local cooldowns = {}

    local function rebuild()
        pCache = {}
        cCache = {}
        pcall(function()
            local desc = workspace:GetDescendants()
            for i = 1, #desc do
                local d = desc[i]
                if d:IsA("ProximityPrompt") then pCache[#pCache + 1] = d
                elseif d:IsA("ClickDetector") then cCache[#cCache + 1] = d end
                if i % 500 == 0 then tWait() end
            end
        end)
        cacheDirty = false
        notify("Cache: " .. #pCache .. "p / " .. #cCache .. "c")
    end

    pcall(function()
        workspace.DescendantAdded:Connect(function(d)
            if d:IsA("ProximityPrompt") then pCache[#pCache + 1] = d
            elseif d:IsA("ClickDetector") then cCache[#cCache + 1] = d end
        end)
        workspace.DescendantRemoving:Connect(function(d)
            if d:IsA("ProximityPrompt") then
                for i = #pCache, 1, -1 do if pCache[i] == d then table.remove(pCache, i) break end end
            elseif d:IsA("ClickDetector") then
                for i = #cCache, 1, -1 do if cCache[i] == d then table.remove(cCache, i) break end end
            end
        end)
    end)

    local function isBL(text)
        if not cfg.job.useBlacklist then return false end
        local lo = string.lower(text or "")
        for w in string.gmatch(cfg.job.blacklist, "[^,]+") do
            if string.find(lo, string.lower(w)) then return true end
        end
        return false
    end

    local function matchKW(text)
        if cfg.job.mode == "aggressive" then return true end
        local lo = string.lower(text or "")
        for w in string.gmatch(cfg.job.keywords, "[^,]+") do
            if string.find(lo, string.lower(w)) then return true end
        end
        return false
    end

    local function fireP(p)
        if not p or not p.Parent then return false end
        if firePrompt then
            local ok = pcall(firePrompt, p)
            if ok then return true, "fp" end
        end
        local ok2 = pcall(function()
            local old = p.HoldDuration
            p.HoldDuration = 0
            tWait(0.05)
            p.HoldDuration = old
        end)
        if ok2 then return true, "h0" end
        local ok3 = pcall(function()
            p:InputHoldBegin()
            tWait(0.05)
            p:InputHoldEnd()
        end)
        if ok3 then return true, "ih" end
        return false, "fail"
    end

    local function fireC(cd)
        if not cd or not cd.Parent then return false end
        if fireClick then
            local ok = pcall(fireClick, cd)
            if ok then return true, "fc" end
        end
        if getConns then
            local ok2 = pcall(function()
                local cn = getConns(cd.MouseClick)
                for _, c in ipairs(cn or {}) do
                    if c.Function then c.Function(player) end
                end
            end)
            if ok2 then return true, "gc" end
        end
        return false, "fail"
    end

    tSpawn(function()
        tWait(3)
        while ScreenGui and ScreenGui.Parent do
            tWait(math.max(cfg.job.interval, 0.05))
            pcall(function()
                if not cfg.job.enabled and not fireManual then return end
                local ch = player.Character
                if not ch then return end
                local root = ch:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local pos = root.Position

                if cacheDirty then rebuild() end

                local fired = 0
                local dbg = {}

                if cfg.job.firePrompts then
                    for i = 1, #pCache do
                        if fired >= cfg.job.maxPerTick then break end
                        local p = pCache[i]
                        if not p or not p.Parent then continue end
                        local part = p.Parent
                        if not part:IsA("BasePart") then
                            pcall(function() part = part:FindFirstChildWhichIsA("BasePart") end)
                        end
                        if not part or not part:IsA("BasePart") then continue end
                        local dist = (part.Position - pos).Magnitude
                        if dist > cfg.job.radius then continue end
                        local ot = p.ObjectText or ""
                        local at = p.ActionText or ""
                        local full = ot .. " " .. at
                        if isBL(full) then
                            if #dbg < 3 then dbg[#dbg + 1] = "BL:" .. string.sub(full, 1, 15) end
                            continue
                        end
                        if not matchKW(full) then continue end
                        local now = tick()
                        local key = tostring(p)
                        if cooldowns[key] and (now - cooldowns[key]) < 0.6 then continue end
                        local ok, m = fireP(p)
                        if ok then
                            fired = fired + 1
                            stats.a = stats.a + 1
                            stats.p = stats.p + 1
                            cooldowns[key] = now
                            if #dbg < 3 then dbg[#dbg + 1] = "OK(" .. m .. "):" .. string.sub(full, 1, 15) end
                        else
                            stats.f = stats.f + 1
                        end
                    end
                end

                if cfg.job.fireClicks then
                    for i = 1, #cCache do
                        if fired >= cfg.job.maxPerTick then break end
                        local cd = cCache[i]
                        if not cd or not cd.Parent then continue end
                        local part = cd.Parent
                        if not part:IsA("BasePart") then continue end
                        local dist = (part.Position - pos).Magnitude
                        if dist > cfg.job.radius then continue end
                        local nm = part.Name or ""
                        if isBL(nm) then continue end
                        local now = tick()
                        local key = "cd" .. tostring(cd)
                        if cooldowns[key] and (now - cooldowns[key]) < 0.6 then continue end
                        local ok, m = fireC(cd)
                        if ok then
                            fired = fired + 1
                            stats.a = stats.a + 1
                            stats.c = stats.c + 1
                            cooldowns[key] = now
                            if #dbg < 3 then dbg[#dbg + 1] = "CLK(" .. m .. "):" .. string.sub(nm, 1, 15) end
                        end
                    end
                end

                if fireManual then
                    fireManual = false
                    local near = nil
                    local nd = math.huge
                    for i = 1, #pCache do
                        local p = pCache[i]
                        if not p or not p.Parent then continue end
                        local pt = p.Parent
                        if not pt:IsA("BasePart") then
                            pcall(function() pt = pt:FindFirstChildWhichIsA("BasePart") end)
                        end
                        if not pt or not pt:IsA("BasePart") then continue end
                        local d = (pt.Position - pos).Magnitude
                        if d < nd then nd = d; near = p end
                    end
                    if near then fireP(near); notify("Avfyrade!") else notify("Ingen prompt") end
                end

                statsLbl.Text = string.format("A:%d | P:%d | C:%d | F:%d", stats.a, stats.p, stats.c, stats.f)
                if #dbg > 0 then
                    debugLbl.Text = table.concat(dbg, " | ")
                    debugLbl.TextColor3 = C.good
                else
                    debugLbl.Text = "Inget i radie (" .. cfg.job.radius .. ") | cache:" .. #pCache .. "p/" .. #cCache .. "c"
                    debugLbl.TextColor3 = C.dim
                end

                if math.random(1, 50) == 1 then
                    local now = tick()
                    for k, t in pairs(cooldowns) do if now - t > 10 then cooldowns[k] = nil end end
                end
            end)
        end
    end)
end)

-- ============================================================
--  TAB: PLAYERS
-- ============================================================
pcall(function()
    local f = tFrames["Players"]
    local c1 = mkCard(f, "👥 Spelare i servern")
    local pList = mkLabel(c1, "Laddar...", C.dim, 64)
    pList.AutomaticSize = Enum.AutomaticSize.Y

    local c2 = mkCard(f, "🥾 Lokal Kick")
    local kickBox = Instance.new("TextBox")
    kickBox.Size = UDim2.new(1, 0, 0, 30)
    kickBox.BackgroundColor3 = C.card
    kickBox.TextColor3 = C.text
    kickBox.TextSize = 12
    kickBox.Font = FONT
    kickBox.PlaceholderText = "Spelarnamn..."
    kickBox.PlaceholderColor3 = C.dim
    kickBox.BorderSizePixel = 0
    kickBox.Parent = c2
    mkCorner(kickBox)

    mkBtn(c2, "Kicka (lokal)", C.bad, function()
        local name = kickBox.Text
        if name == "" then notify("Skriv ett namn"); return end
        local target = Players:FindFirstChild(name)
        if not target then notify("Ej hittad"); return end
        pcall(function()
            local ch = target.Character
            if ch then
                local h = ch:FindFirstChildOfClass("Humanoid")
                if h then h.Health = 0 end
            end
        end)
        notify("Försökte kicka " .. name)
    end)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(2)
            pcall(function()
                local lines = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    lines[#lines + 1] = (p == player and "⭐ " or "  ") .. p.Name
                end
                pList.Text = table.concat(lines, "\n")
                pList.TextColor3 = C.text
            end)
        end
    end)
end)

-- ============================================================
--  TAB: SETTINGS
-- ============================================================
pcall(function()
    local f = tFrames["Settings"]

    local c1 = mkCard(f, "🗺️ Hastighetszoner")
    mkToggle(c1, "Aktivera zoner", cfg.limits.enabled, function(v) cfg.limits.enabled = v; saveCfg() end)
    mkSlider(c1, "Global maxhastighet", 16, 300, cfg.limits.global, function(v) cfg.limits.global = v; saveCfg() end)
    local zoneLbl = mkLabel(c1, "Zoner: " .. #cfg.limits.zones, C.dim)

    mkBtn(c1, "➕ Lägg till zon här", C.good, function()
        local ch = player.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local pos = root.Position
        table.insert(cfg.limits.zones, {
            x = math.floor(pos.X), y = math.floor(pos.Y), z = math.floor(pos.Z),
            r = 30, speed = 50, name = "Zon " .. (#cfg.limits.zones + 1)
        })
        zoneLbl.Text = "Zoner: " .. #cfg.limits.zones
        saveCfg()
        notify("Zon tillagd!")
    end)

    mkBtn(c1, "🗑️ Rensa zoner", C.bad, function()
        cfg.limits.zones = {}
        zoneLbl.Text = "Zoner: 0"
        saveCfg()
        notify("Rensade")
    end)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.1)
            pcall(function()
                if not cfg.limits.enabled then return end
                local ch = player.Character
                if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid")
                if not h then return end
                local root = ch:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local pos = root.Position
                local limit = cfg.limits.global
                for _, z in ipairs(cfg.limits.zones) do
                    if (pos - Vector3.new(z.x, z.y, z.z)).Magnitude <= z.r then
                        limit = math.min(limit, z.speed)
                    end
                end
                if h.WalkSpeed > limit then h.WalkSpeed = limit end
            end)
        end
    end)

    local c2 = mkCard(f, "💾 Konfiguration")
    mkBtn(c2, "Spara nu", C.good, function() saveCfg(); notify("Sparad!") end)
    mkBtn(c2, "Återställ standard", C.bad, function()
        pcall(function() if isfile and isfile(CFG_FILE) and delfile then delfile(CFG_FILE) end end)
        notify("Återställd! Starta om.")
    end)

    local c3 = mkCard(f, "ℹ️ Info & Diagnostik")
    mkLabel(c3, "Venice Speed Suite v" .. VERSION, C.accent)
    mkLabel(c3, "fireproximityprompt: " .. (firePrompt and "✓" or "✗"), firePrompt and C.good or C.bad)
    mkLabel(c3, "fireclickdetector: " .. (fireClick and "✓" or "✗"), fireClick and C.good or C.bad)
    mkLabel(c3, "getconnections: " .. (getConns and "✓" or "✗"), getConns and C.good or C.bad)
    local hasHui = false
    pcall(function() hasHui = gethui() ~= nil end)
    mkLabel(c3, "gethui: " .. (hasHui and "✓" or "✗ (fallback)"), hasHui and C.good or C.warn)
    mkLabel(c3, "task lib: " .. (task and "✓" or "✗ (fallback)"), task and C.good or C.warn)
    mkLabel(c3, "isfile/readfile: " .. (isfile and "✓" or "✗"), isfile and C.good or C.warn)
end)

-- ============================================================
--  KEYBIND
-- ============================================================
pcall(function()
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local kc = Enum.KeyCode[cfg.ui.keybind]
        if kc and input.KeyCode == kc then
            main.Visible = not main.Visible
        end
    end)
end)

-- ============================================================
--  KLART
-- ============================================================
print("[Venice] v" .. VERSION .. " LADDAD OK")
notify("Venice v" .. VERSION .. " laddad! [" .. cfg.ui.keybind .. "]", 4)
