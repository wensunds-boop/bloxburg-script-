-- ============================================================
--  VENICE SPEED SUITE v2.4  –  loggande, lågrisk-start
-- ============================================================
local VERSION = "2.4"
local LOG = "VeniceLog.txt"

local function log(s)
    print("[Venice] " .. s)
    pcall(function()
        if appendfile then appendfile(LOG, s .. "\n")
        elseif writefile then writefile(LOG, s .. "\n") end
    end)
end
pcall(function() if writefile then writefile(LOG, "") end end)
log("0 start v" .. VERSION)

local tWait, tSpawn, tDelay = wait, spawn, delay
pcall(function() tWait = task.wait; tSpawn = task.spawn; tDelay = task.delay end)

-- Vänta tills spelet är laddat (viktigt vid injection)
pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
while not player do tWait(0.2); player = Players.LocalPlayer end
tWait(2)
log("1 spel laddat")

local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

-- Executor-funktioner
local function getFn(name)
    local f
    pcall(function() f = getgenv()[name] end)
    if not f then pcall(function() f = _G[name] end) end
    return f
end
local firePrompt = getFn("fireproximityprompt")
local fireClick  = getFn("fireclickdetector")
log("2 exec: fp=" .. tostring(firePrompt ~= nil) .. " fc=" .. tostring(fireClick ~= nil))

local function notify(msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title = "Venice", Text = msg, Duration = dur or 3})
    end)
end

-- ============================================================
--  GUI-förälder: gethui -> CoreGui -> PlayerGui
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VeniceSpeedSuite"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false
local where = ""
pcall(function()
    if gethui then ScreenGui.Parent = gethui(); parented = ScreenGui.Parent ~= nil; where = "gethui" end
end)
if not parented then pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui"); parented = ScreenGui.Parent ~= nil; where = "CoreGui"
end) end
if not parented then pcall(function()
    ScreenGui.Parent = player:WaitForChild("PlayerGui", 10); parented = ScreenGui.Parent ~= nil; where = "PlayerGui"
end) end
if not parented then log("FEL: ingen GUI-förälder"); return end
log("3 GUI-förälder: " .. where)

-- ============================================================
--  Stil
-- ============================================================
local C = {
    bg=Color3.fromRGB(12,14,19), panel=Color3.fromRGB(20,24,31), card=Color3.fromRGB(28,33,42),
    track=Color3.fromRGB(44,50,62), text=Color3.fromRGB(233,237,245), dim=Color3.fromRGB(132,142,160),
    good=Color3.fromRGB(88,214,141), warn=Color3.fromRGB(255,186,84), bad=Color3.fromRGB(255,106,106),
    accent=Color3.fromRGB(94,141,255),
}
local FONT, FONTB = Enum.Font.GothamMedium, Enum.Font.GothamBold

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0, 8); c.Parent = p
end

-- ============================================================
--  Config
-- ============================================================
local CFG = "VeniceSpeedSuite.json"
local cfg = {
    player  = {enabled=false, speed=34, jumpEnabled=false, jump=50},
    vehicle = {enabled=false, maxSpeed=130},
    job = {enabled=false, interval=0.15, radius=15, maxPerTick=6, useBlacklist=true, mode="aggressive",
        blacklist="door,gate,exit,entrance,sleep,bed,sit,chair,seat,menu,shop,buy,sell,radio,tv,toilet,sink,shower,bath,trash,bin",
        keywords="dough,sauce,cheese,pepperoni,topping,oven,bake,cook,cut,slice,box,order,deliver,pizza,knead,prepare,serve,grab,take,put"},
    limits = {enabled=false, global=110, zones={}},
    ui = {keybind="K"},
}
pcall(function()
    if isfile and readfile and isfile(CFG) then
        local d = HttpService:JSONDecode(readfile(CFG))
        local function merge(src, dst)
            for k, v in pairs(src) do
                if type(v) == "table" and type(dst[k]) == "table" then merge(v, dst[k]) else dst[k] = v end
            end
        end
        merge(d, cfg)
    end
end)
local sTok = 0
local function saveCfg()
    sTok = sTok + 1
    local t = sTok
    tDelay(0.8, function()
        if t ~= sTok then return end
        pcall(function() if writefile then writefile(CFG, HttpService:JSONEncode(cfg)) end end)
    end)
end
log("4 config klar")

-- ============================================================
--  Fönster
-- ============================================================
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(460, 560)
main.Position = UDim2.fromOffset(80, 80)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Parent = ScreenGui
corner(main)

local tbar = Instance.new("Frame")
tbar.Size = UDim2.new(1, 0, 0, 36)
tbar.BackgroundColor3 = C.panel
tbar.BorderSizePixel = 0
tbar.Parent = main
corner(tbar)

-- Egen drag (Draggable är föråldrat)
do
    local dragging, startPos, startMouse = false
    tbar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; startMouse = i.Position; startPos = main.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - startMouse
            main.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        end
    end)
end

local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1, -80, 1, 0)
ttl.Position = UDim2.fromOffset(12, 0)
ttl.BackgroundTransparency = 1
ttl.Text = "Venice Speed Suite v" .. VERSION
ttl.TextColor3 = C.accent
ttl.TextSize = 14
ttl.Font = FONTB
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Parent = tbar

local function titleBtn(text, col, x, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28)
    b.Position = UDim2.new(1, x, 0, 4)
    b.BackgroundColor3 = col
    b.Text = text
    b.TextColor3 = C.text
    b.TextSize = 13
    b.Font = FONTB
    b.BorderSizePixel = 0
    b.Parent = tbar
    corner(b)
    b.MouseButton1Click:Connect(cb)
end

local alive = true
titleBtn("X", C.bad, -32, function() alive = false; ScreenGui:Destroy() end)
local mini = false
titleBtn("-", C.warn, -64, function()
    mini = not mini
    main.Size = mini and UDim2.fromOffset(460, 36) or UDim2.fromOffset(460, 560)
end)
log("5 fönster klart")

-- ============================================================
--  Tabs
-- ============================================================
local TABS = {"Player", "Vehicle", "Job", "Players", "Settings"}
local tF, tB = {}, {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.fromOffset(0, 36)
tabBar.BackgroundColor3 = C.panel
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local tCon = Instance.new("Frame")
tCon.Size = UDim2.new(1, -16, 1, -86)
tCon.Position = UDim2.fromOffset(8, 78)
tCon.BackgroundTransparency = 1
tCon.ClipsDescendants = true
tCon.Parent = main

for i, name in ipairs(TABS) do
    local w = 1 / #TABS
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w, 0, 1, 0)
    b.Position = UDim2.new(w * (i - 1), 0, 0, 0)
    b.BackgroundColor3 = C.bg
    b.Text = name
    b.TextColor3 = C.dim
    b.TextSize = 11
    b.Font = FONT
    b.BorderSizePixel = 0
    b.Parent = tabBar

    local fr = Instance.new("ScrollingFrame")
    fr.Size = UDim2.new(1, 0, 1, 0)
    fr.BackgroundTransparency = 1
    fr.BorderSizePixel = 0
    fr.ScrollBarThickness = 4
    fr.CanvasSize = UDim2.new(0, 0, 0, 0)
    fr.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fr.Visible = false
    fr.Parent = tCon

    local ul = Instance.new("UIListLayout")
    ul.SortOrder = Enum.SortOrder.LayoutOrder
    ul.Padding = UDim.new(0, 6)
    ul.Parent = fr

    tF[name] = fr
    tB[name] = b
    b.MouseButton1Click:Connect(function()
        for n in pairs(tF) do
            tF[n].Visible = false
            tB[n].BackgroundColor3 = C.bg
            tB[n].TextColor3 = C.dim
        end
        fr.Visible = true
        b.BackgroundColor3 = C.card
        b.TextColor3 = C.accent
    end)
end
tB.Player.BackgroundColor3 = C.card
tB.Player.TextColor3 = C.accent
tF.Player.Visible = true
log("6 tabs klara")

-- ============================================================
--  Komponenter
-- ============================================================
local function mkCard(parent, title)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, -6, 0, 0)
    c.AutomaticSize = Enum.AutomaticSize.Y
    c.BackgroundColor3 = C.card
    c.BorderSizePixel = 0
    c.Parent = parent
    corner(c)
    local pd = Instance.new("UIPadding")
    pd.PaddingLeft = UDim.new(0, 10); pd.PaddingRight = UDim.new(0, 10)
    pd.PaddingTop = UDim.new(0, 8);   pd.PaddingBottom = UDim.new(0, 8)
    pd.Parent = c
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

local function mkLabel(parent, text, col, h)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, h or 16)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = col or C.dim
    l.TextSize = 11
    l.Font = FONT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function mkToggle(parent, label, def, cb)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 28)
    r.BackgroundTransparency = 1
    r.Parent = parent
    mkLabel(r, label, C.text, 28).Size = UDim2.new(1, -50, 1, 0)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(42, 22)
    b.Position = UDim2.new(1, -44, 0, 3)
    b.TextColor3 = C.text
    b.TextSize = 10
    b.Font = FONTB
    b.BorderSizePixel = 0
    b.Parent = r
    corner(b, UDim.new(0, 6))
    local st = def
    local function paint() b.BackgroundColor3 = st and C.good or C.track; b.Text = st and "PÅ" or "AV" end
    paint()
    b.MouseButton1Click:Connect(function() st = not st; paint(); pcall(cb, st) end)
end

local function mkSlider(parent, label, mn, mx, def, cb)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 36)
    r.BackgroundTransparency = 1
    r.Parent = parent
    mkLabel(r, label, C.text, 16).Size = UDim2.new(0.6, 0, 0, 16)
    local vl = mkLabel(r, tostring(def), C.accent, 16)
    vl.Size = UDim2.new(0.4, 0, 0, 16)
    vl.Position = UDim2.new(0.6, 0, 0, 0)
    vl.TextXAlignment = Enum.TextXAlignment.Right
    local tr = Instance.new("Frame")
    tr.Size = UDim2.new(1, 0, 0, 8)
    tr.Position = UDim2.fromOffset(0, 22)
    tr.BackgroundColor3 = C.track
    tr.BorderSizePixel = 0
    tr.Parent = r
    corner(tr, UDim.new(0, 4))
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new(math.clamp((def - mn) / (mx - mn), 0, 1), 0, 1, 0)
    fl.BackgroundColor3 = C.accent
    fl.BorderSizePixel = 0
    fl.Parent = tr
    corner(fl, UDim.new(0, 4))
    local drag = false
    local function setFrom(x)
        local rv = math.clamp((x - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(mn + rv * (mx - mn) + 0.5)
        fl.Size = UDim2.new(rv, 0, 1, 0)
        vl.Text = tostring(v)
        pcall(cb, v)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; setFrom(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then setFrom(i.Position.X) end
    end)
end

local function mkButton(parent, text, col, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = col or C.accent
    b.Text = text
    b.TextColor3 = C.text
    b.TextSize = 12
    b.Font = FONTB
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end
log("7 komponenter klara")

-- ============================================================
--  Tab-innehåll (inget startar i bakgrunden här)
-- ============================================================
local playerStatus, vehicleStatus

pcall(function()
    local c = mkCard(tF.Player, "Rörelse")
    mkToggle(c, "Walkspeed", cfg.player.enabled, function(v) cfg.player.enabled = v; saveCfg() end)
    mkSlider(c, "Hastighet", 16, 300, cfg.player.speed, function(v) cfg.player.speed = v; saveCfg() end)
    mkToggle(c, "Jump", cfg.player.jumpEnabled, function(v) cfg.player.jumpEnabled = v; saveCfg() end)
    mkSlider(c, "Hopphöjd", 50, 400, cfg.player.jump, function(v) cfg.player.jump = v; saveCfg() end)
    playerStatus = mkLabel(c, "WS: -- | JP: --", C.dim)
end)

pcall(function()
    local c = mkCard(tF.Vehicle, "Fordon")
    mkToggle(c, "Aktivera", cfg.vehicle.enabled, function(v) cfg.vehicle.enabled = v; saveCfg() end)
    mkSlider(c, "Maxhastighet", 30, 500, cfg.vehicle.maxSpeed, function(v) cfg.vehicle.maxSpeed = v; saveCfg() end)
    vehicleStatus = mkLabel(c, "Inget fordon", C.dim)
end)

-- JOB
local pCache, cCache, cooldowns = {}, {}, {}
local scanning = false
local jobStats = {a = 0, p = 0, c = 0, f = 0}
local jobStatus, jobDebug

local function listMatch(text, csv)
    local lo = string.lower(text or "")
    for w in string.gmatch(csv, "[^,]+") do
        if string.find(lo, w, 1, true) then return true end
    end
    return false
end

local function posOf(inst)
    local par = inst.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    local bp = par:FindFirstChildWhichIsA("BasePart")
    return bp and bp.Position or nil
end

pcall(function()
    local c = mkCard(tF.Job, "Pizza Auto-Farm")
    jobStatus = mkLabel(c, "Tryck FORCE SCAN först, slå sedan på", C.dim, 32)
    jobDebug = mkLabel(c, "A:0 P:0 C:0 F:0", C.dim, 32)
    mkToggle(c, "Aktivera", cfg.job.enabled, function(v) cfg.job.enabled = v; saveCfg() end)
    mkSlider(c, "Intervall (x0.1 s)", 1, 10, math.floor(cfg.job.interval * 10), function(v) cfg.job.interval = v / 10; saveCfg() end)
    mkSlider(c, "Radie (studs)", 5, 50, cfg.job.radius, function(v) cfg.job.radius = v; saveCfg() end)
    mkSlider(c, "Max per tick", 1, 15, cfg.job.maxPerTick, function(v) cfg.job.maxPerTick = v; saveCfg() end)
    mkToggle(c, "Svartlista", cfg.job.useBlacklist, function(v) cfg.job.useBlacklist = v; saveCfg() end)
    local modeL = mkLabel(c, "Läge: " .. cfg.job.mode, C.accent)
    mkButton(c, "Växla läge (aggressive/keyword)", C.warn, function()
        cfg.job.mode = cfg.job.mode == "aggressive" and "keyword" or "aggressive"
        modeL.Text = "Läge: " .. cfg.job.mode
        saveCfg()
    end)

    local c2 = mkCard(tF.Job, "Verktyg")
    mkButton(c2, "FORCE SCAN (kan ta några sek)", C.warn, function()
        if scanning then return end
        scanning = true
        tSpawn(function()
            log("scan start")
            local np, nc = {}, {}
            pcall(function()
                local desc = workspace:GetDescendants()
                for i = 1, #desc do
                    local d = desc[i]
                    if d:IsA("ProximityPrompt") then np[#np + 1] = d
                    elseif d:IsA("ClickDetector") then nc[#nc + 1] = d end
                    if i % 300 == 0 then tWait(0.03) end
                end
            end)
            pCache, cCache = np, nc
            scanning = false
            log("scan klar " .. #np .. "p/" .. #nc .. "c")
            notify("Scan klar: " .. #np .. " prompts, " .. #nc .. " clicks")
        end)
    end)
    mkButton(c2, "Avfyra närmaste prompt", C.accent, function()
        local ch = player.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local best, bd = nil, math.huge
        for _, p in ipairs(pCache) do
            local pp = p.Parent and posOf(p)
            if pp then
                local d = (pp - root.Position).Magnitude
                if d < bd then bd = d; best = p end
            end
        end
        if best and firePrompt then pcall(firePrompt, best); notify("Avfyrade (" .. math.floor(bd) .. " studs)")
        else notify("Ingen prompt / fireproximityprompt saknas") end
    end)
    mkButton(c2, "Nollställ statistik", C.bad, function() jobStats = {a = 0, p = 0, c = 0, f = 0} end)
end)

-- PLAYERS
pcall(function()
    local c = mkCard(tF.Players, "Spelare i servern")
    local list = mkLabel(c, "...", C.text, 16)
    list.AutomaticSize = Enum.AutomaticSize.Y
    local function refresh()
        local l = {}
        for _, p in ipairs(Players:GetPlayers()) do l[#l + 1] = (p == player and "* " or "  ") .. p.Name end
        list.Text = table.concat(l, "\n")
    end
    refresh()
    local c2 = mkCard(tF.Players, "Lokal kick (bara du ser det)")
    local kb = Instance.new("TextBox")
    kb.Size = UDim2.new(1, 0, 0, 30)
    kb.BackgroundColor3 = C.panel
    kb.TextColor3 = C.text
    kb.TextSize = 12
    kb.Font = FONT
    kb.PlaceholderText = "Spelarnamn..."
    kb.Text = ""
    kb.BorderSizePixel = 0
    kb.Parent = c2
    corner(kb)
    mkButton(c2, "Uppdatera lista", C.accent, refresh)
    mkButton(c2, "Dölj spelare lokalt", C.bad, function()
        local t = Players:FindFirstChild(kb.Text)
        if t and t.Character then t.Character.Parent = nil; notify("Dold lokalt") else notify("Ej hittad") end
    end)
end)

-- SETTINGS
pcall(function()
    local c = mkCard(tF.Settings, "Hastighetszoner")
    mkToggle(c, "Aktivera zoner", cfg.limits.enabled, function(v) cfg.limits.enabled = v; saveCfg() end)
    mkSlider(c, "Global max", 16, 300, cfg.limits.global, function(v) cfg.limits.global = v; saveCfg() end)
    local zl = mkLabel(c, "Zoner: " .. #cfg.limits.zones, C.dim)
    mkButton(c, "Lägg till zon här", C.good, function()
        local ch = player.Character
        local r = ch and ch:FindFirstChild("HumanoidRootPart")
        if not r or #cfg.limits.zones >= 40 then return end
        table.insert(cfg.limits.zones, {x = math.floor(r.Position.X), y = math.floor(r.Position.Y), z = math.floor(r.Position.Z), r = 30, speed = 50})
        zl.Text = "Zoner: " .. #cfg.limits.zones
        saveCfg()
    end)
    mkButton(c, "Rensa zoner", C.bad, function() cfg.limits.zones = {}; zl.Text = "Zoner: 0"; saveCfg() end)

    local c2 = mkCard(tF.Settings, "Config")
    mkButton(c2, "Återställ config (starta om efter)", C.bad, function()
        pcall(function() if delfile and isfile and isfile(CFG) then delfile(CFG) end end)
        notify("Config raderad, kör scriptet igen")
    end)

    local c3 = mkCard(tF.Settings, "Diagnostik")
    mkLabel(c3, "GUI-förälder: " .. where, C.accent)
    mkLabel(c3, "fireproximityprompt: " .. (firePrompt and "ja" or "nej"), firePrompt and C.good or C.bad)
    mkLabel(c3, "fireclickdetector: " .. (fireClick and "ja" or "nej"), fireClick and C.good or C.bad)
    mkLabel(c3, "Loggfil: " .. LOG, C.dim)
end)
log("8 tab-innehåll klart")

-- ============================================================
--  EN gemensam bakgrundsloop (10 Hz)
-- ============================================================
local jobAcc = 0
tSpawn(function()
    log("9 loop startad")
    local last = tick()
    while alive and ScreenGui.Parent do
        tWait(0.1)
        local now = tick()
        local dt = now - last
        last = now
        pcall(function()
            local ch = player.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if not hum then return end

            -- Spelare
            if cfg.player.enabled then hum.WalkSpeed = cfg.player.speed end
            if cfg.player.jumpEnabled then hum.UseJumpPower = true; hum.JumpPower = cfg.player.jump end

            -- Zoner
            if cfg.limits.enabled and root then
                local lim = cfg.limits.global
                for _, z in ipairs(cfg.limits.zones) do
                    if (root.Position - Vector3.new(z.x, z.y, z.z)).Magnitude <= z.r then lim = math.min(lim, z.speed) end
                end
                if hum.WalkSpeed > lim then hum.WalkSpeed = lim end
            end
            if playerStatus then playerStatus.Text = "WS: " .. math.floor(hum.WalkSpeed) .. " | JP: " .. math.floor(hum.JumpPower) end

            -- Fordon
            if vehicleStatus then
                local seat = hum.SeatPart
                if cfg.vehicle.enabled and seat then
                    local vs = seat:IsA("VehicleSeat") and seat or seat:FindFirstAncestorWhichIsA("VehicleSeat")
                    if vs then
                        vs.MaxSpeed = cfg.vehicle.maxSpeed
                        vehicleStatus.Text = "Fordon: " .. (vs.Parent and vs.Parent.Name or "?")
                        vehicleStatus.TextColor3 = C.good
                    else
                        vehicleStatus.Text = "Ingen VehicleSeat"
                        vehicleStatus.TextColor3 = C.warn
                    end
                else
                    vehicleStatus.Text = cfg.vehicle.enabled and "Sitter ej i fordon" or "AV"
                    vehicleStatus.TextColor3 = C.dim
                end
            end

            -- Pizza
            jobAcc = jobAcc + dt
            if cfg.job.enabled and root and jobAcc >= cfg.job.interval then
                jobAcc = 0
                if #pCache == 0 and #cCache == 0 then
                    if jobStatus then jobStatus.Text = "Cache tom - tryck FORCE SCAN"; jobStatus.TextColor3 = C.warn end
                    return
                end
                local pos, fired, seen = root.Position, 0, 0
                for i = 1, #pCache do
                    if fired >= cfg.job.maxPerTick then break end
                    local p = pCache[i]
                    if p and p.Parent and p.Enabled then
                        local pp = posOf(p)
                        if pp and (pp - pos).Magnitude <= cfg.job.radius then
                            seen = seen + 1
                            local text = (p.ObjectText or "") .. " " .. (p.ActionText or "") .. " " .. p.Parent.Name
                            local skip = (cfg.job.useBlacklist and listMatch(text, cfg.job.blacklist))
                                or (cfg.job.mode == "keyword" and not listMatch(text, cfg.job.keywords))
                            local last_t = cooldowns[p]
                            if not skip and not (last_t and now - last_t < 0.6) then
                                local ok = false
                                if firePrompt then ok = pcall(firePrompt, p) end
                                if ok then
                                    fired = fired + 1; jobStats.a = jobStats.a + 1; jobStats.p = jobStats.p + 1
                                    cooldowns[p] = now
                                else jobStats.f = jobStats.f + 1 end
                            end
                        end
                    end
                end
                if fireClick then
                    for i = 1, #cCache do
                        if fired >= cfg.job.maxPerTick then break end
                        local cd = cCache[i]
                        if cd and cd.Parent then
                            local pp = posOf(cd)
                            if pp and (pp - pos).Magnitude <= cfg.job.radius
                                and not (cfg.job.useBlacklist and listMatch(cd.Parent.Name, cfg.job.blacklist))
                                and not (cooldowns[cd] and now - cooldowns[cd] < 0.6) then
                                seen = seen + 1
                                if pcall(fireClick, cd) then
                                    fired = fired + 1; jobStats.a = jobStats.a + 1; jobStats.c = jobStats.c + 1
                                    cooldowns[cd] = now
                                else jobStats.f = jobStats.f + 1 end
                            end
                        end
                    end
                end
                if jobStatus then
                    jobStatus.Text = "Aktiv | i radie: " .. seen .. " | cache: " .. #pCache .. "p/" .. #cCache .. "c"
                    jobStatus.TextColor3 = seen > 0 and C.good or C.dim
                end
                if jobDebug then
                    jobDebug.Text = string.format("A:%d P:%d C:%d F:%d", jobStats.a, jobStats.p, jobStats.c, jobStats.f)
                end
                -- rensa gamla cooldowns
                if math.random(1, 40) == 1 then
                    for k, t in pairs(cooldowns) do
                        if not k.Parent or now - t > 10 then cooldowns[k] = nil end
                    end
                end
            end
        end)
    end
end)

-- Keybind
pcall(function()
    local kc = Enum.KeyCode[cfg.ui.keybind]
    UIS.InputBegan:Connect(function(i, g)
        if not g and kc and i.KeyCode == kc then main.Visible = not main.Visible end
    end)
end)

log("10 KLAR")
notify("Venice v" .. VERSION .. " laddad [" .. cfg.ui.keybind .. " = visa/dölj]", 4)
