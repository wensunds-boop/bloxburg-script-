print("[Venice] START v2.3")

local VERSION = "2.3"
local tWait = wait
pcall(function() tWait = task.wait end)
local tSpawn = spawn
pcall(function() tSpawn = task.spawn end)
local tDelay = delay
pcall(function() tDelay = task.delay end)

-- Executor-funktioner (säkert)
local firePrompt = nil
pcall(function() if getgenv and getgenv().fireproximityprompt then firePrompt = getgenv().fireproximityprompt end end)
local fireClick = nil
pcall(function() if getgenv and getgenv().fireclickdetector then fireClick = getgenv().fireclickdetector end end)
local getConns = nil
pcall(function() if getgenv and getgenv().getconnections then getConns = getgenv().getconnections end end)

print("[Venice] fp=" .. tostring(firePrompt ~= nil) .. " fc=" .. tostring(fireClick ~= nil) .. " gc=" .. tostring(getConns ~= nil))

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local function notify(msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Venice", Text = msg, Duration = dur or 3})
    end)
end

-- ============================================================
--  GUI
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
if not ScreenGui then warn("[Venice] KAN INTE SKAPA GUI") return end
print("[Venice] GUI OK")

-- ============================================================
--  FÄRGER
-- ============================================================
local C = {
    bg = Color3.fromRGB(12,14,19), panel = Color3.fromRGB(20,24,31),
    card = Color3.fromRGB(28,33,42), track = Color3.fromRGB(44,50,62),
    text = Color3.fromRGB(233,237,245), dim = Color3.fromRGB(132,142,160),
    good = Color3.fromRGB(88,214,141), warn = Color3.fromRGB(255,186,84),
    bad = Color3.fromRGB(255,106,106), accent = Color3.fromRGB(94,141,255),
}
local FONT = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold

local function mkC(r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0,8); return c end
local function mkS(p, col) local s = Instance.new("UIStroke"); s.Color = col or C.track; s.Thickness = 1; s.Parent = p end

-- ============================================================
--  KONFIG
-- ============================================================
local CFG = "VeniceSpeedSuite.json"
local cfg = {
    player = {enabled=false, speed=34, jumpEnabled=false, jump=50},
    vehicle = {enabled=false, maxSpeed=130, accel=110, brake=190},
    job = {enabled=false, interval=0.15, radius=15, mode="aggressive",
        firePrompts=true, fireClicks=true, useBlacklist=true, maxPerTick=6,
        blacklist="door,gate,exit,entrance,sleep,bed,sit,chair,seat,menu,shop,buy,sell,radio,tv,toilet,sink,shower,bath,trash,bin",
        keywords="dough,sauce,cheese,pepperoni,topping,oven,bake,cook,cut,slice,box,order,deliver,pizza,knead,prepare,serve,grab,take,put,flatten,roll"},
    limits = {enabled=false, global=110, zones={}},
    ui = {keybind="K"},
}
pcall(function()
    if isfile and isfile(CFG) and readfile then
        local d = HttpService:JSONDecode(readfile(CFG))
        local function m(s,t) for k,v in pairs(s) do if type(v)=="table" and type(t[k])=="table" then m(v,t[k]) elseif t[k]==nil then t[k]=v end end end
        m(d, cfg)
    end
end)
local sTok = 0
local function saveCfg()
    sTok = sTok + 1; local t = sTok
    tDelay(0.6, function() if t ~= sTok then return end; pcall(function() if writefile then writefile(CFG, HttpService:JSONEncode(cfg)) end end) end)
end

-- ============================================================
--  FÖNSTER
-- ============================================================
local main = Instance.new("Frame")
main.Name = "Main"; main.Size = UDim2.fromOffset(460, 560)
main.Position = UDim2.fromOffset(80, 80); main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true
mkC(main); mkS(main); main.Parent = ScreenGui

local tbar = Instance.new("Frame")
tbar.Size = UDim2.new(1,0,0,36); tbar.BackgroundColor3 = C.panel; tbar.BorderSizePixel = 0; tbar.Parent = main; mkC(tbar)

local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1,-80,1,0); ttl.Position = UDim2.fromOffset(12,0)
ttl.BackgroundTransparency = 1; ttl.Text = "⚡ Venice v" .. VERSION
ttl.TextColor3 = C.accent; ttl.TextSize = 14; ttl.Font = FONTB
ttl.TextXAlignment = Enum.TextXAlignment.Left; ttl.Parent = tbar

local closeB = Instance.new("TextButton")
closeB.Size = UDim2.fromOffset(28,28); closeB.Position = UDim2.new(1,-32,0,4)
closeB.BackgroundColor3 = C.bad; closeB.Text = "✕"; closeB.TextColor3 = C.text
closeB.TextSize = 13; closeB.Font = FONTB; closeB.BorderSizePixel = 0; closeB.Parent = tbar; mkC(closeB)
closeB.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local minB = Instance.new("TextButton")
minB.Size = UDim2.fromOffset(28,28); minB.Position = UDim2.new(1,-64,0,4)
minB.BackgroundColor3 = C.warn; minB.Text = "—"; minB.TextColor3 = C.text
minB.TextSize = 13; minB.Font = FONTB; minB.BorderSizePixel = 0; minB.Parent = tbar; mkC(minB)
local mini = false
minB.MouseButton1Click:Connect(function() mini = not mini; main.Size = mini and UDim2.fromOffset(460,36) or UDim2.fromOffset(460,560) end)

-- ============================================================
--  TABS
-- ============================================================
local TABS = {"Player","Vehicle","Job","Players","Settings"}
local tF, tB = {}, {}
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,0,0,34); tabBar.Position = UDim2.fromOffset(0,36)
tabBar.BackgroundColor3 = C.panel; tabBar.BorderSizePixel = 0; tabBar.Parent = main

local tCon = Instance.new("Frame")
tCon.Size = UDim2.new(1,-16,1,-86); tCon.Position = UDim2.fromOffset(8,78)
tCon.BackgroundTransparency = 1; tCon.ClipsDescendants = true; tCon.Parent = main

for i, name in ipairs(TABS) do
    local w = 1/#TABS
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w,0,1,0); b.Position = UDim2.new(w*(i-1),0,0,0)
    b.BackgroundColor3 = C.bg; b.Text = name; b.TextColor3 = C.dim
    b.TextSize = 11; b.Font = FONT; b.BorderSizePixel = 0; b.Parent = tabBar

    local fr = Instance.new("ScrollingFrame")
    fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.BorderSizePixel = 0
    fr.ScrollBarThickness = 4; fr.ScrollBarImageColor3 = C.track
    fr.AutomaticCanvasSize = Enum.AutomaticSize.Y; fr.Visible = false; fr.Parent = tCon
    local ul = Instance.new("UIListLayout"); ul.SortOrder = Enum.SortOrder.LayoutOrder; ul.Padding = UDim.new(0,6); ul.Parent = fr
    local up = Instance.new("UIPadding"); up.PaddingTop = UDim.new(0,4); up.PaddingBottom = UDim.new(0,8); up.Parent = fr

    tF[name] = fr; tB[name] = b
    b.MouseButton1Click:Connect(function()
        for n in pairs(tF) do tF[n].Visible = false; tB[n].BackgroundColor3 = C.bg; tB[n].TextColor3 = C.dim end
        fr.Visible = true; b.BackgroundColor3 = C.card; b.TextColor3 = C.accent
    end)
end
tB["Player"].BackgroundColor3 = C.card; tB["Player"].TextColor3 = C.accent; tF["Player"].Visible = true
print("[Venice] Tabs OK")

-- ============================================================
--  UI-KOMPONENTER
-- ============================================================
local function mkCard(p, title)
    local c = Instance.new("Frame"); c.Size = UDim2.new(1,-4,0,0)
    c.AutomaticSize = Enum.AutomaticSize.Y; c.BackgroundColor3 = C.card; c.BorderSizePixel = 0; c.Parent = p; mkC(c)
    local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0,10); pd.PaddingRight = UDim.new(0,10)
    pd.PaddingTop = UDim.new(0,8); pd.PaddingBottom = UDim.new(0,8); pd.Parent = c
    local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Padding = UDim.new(0,5); l.Parent = c
    if title then
        local t = Instance.new("TextLabel"); t.Size = UDim2.new(1,0,0,18); t.BackgroundTransparency = 1
        t.Text = title; t.TextColor3 = C.accent; t.TextSize = 12; t.Font = FONTB
        t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = c
    end
    return c
end

local function mkTog(p, label, def, cb)
    local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,28); r.BackgroundTransparency = 1; r.Parent = p
    local t = Instance.new("TextLabel"); t.Size = UDim2.new(1,-50,1,0); t.BackgroundTransparency = 1
    t.Text = label; t.TextColor3 = C.text; t.TextSize = 12; t.Font = FONT
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = r
    local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(42,22); b.Position = UDim2.new(1,-44,0,3)
    b.BackgroundColor3 = def and C.good or C.track; b.Text = def and "PÅ" or "AV"
    b.TextColor3 = C.text; b.TextSize = 10; b.Font = FONTB; b.BorderSizePixel = 0; b.Parent = r; mkC(b, UDim.new(0,6))
    local st = def
    b.MouseButton1Click:Connect(function() st = not st; b.BackgroundColor3 = st and C.good or C.track; b.Text = st and "PÅ" or "AV"; pcall(cb, st) end)
    return function(v) st = v; b.BackgroundColor3 = st and C.good or C.track; b.Text = st and "PÅ" or "AV" end
end

local function mkSli(p, label, mn, mx, def, cb)
    local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,36); r.BackgroundTransparency = 1; r.Parent = p
    local t = Instance.new("TextLabel"); t.Size = UDim2.new(0.6,0,0,16); t.BackgroundTransparency = 1
    t.Text = label; t.TextColor3 = C.text; t.TextSize = 11; t.Font = FONT
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = r
    local vl = Instance.new("TextLabel"); vl.Size = UDim2.new(0.4,0,0,16); vl.BackgroundTransparency = 1
    vl.Text = tostring(def); vl.TextColor3 = C.accent; vl.TextSize = 11; vl.Font = FONTB
    vl.TextXAlignment = Enum.TextXAlignment.Right; vl.Parent = r
    local tr = Instance.new("Frame"); tr.Size = UDim2.new(1,0,0,6); tr.Position = UDim2.fromOffset(0,22)
    tr.BackgroundColor3 = C.track; tr.BorderSizePixel = 0; tr.Parent = r; mkC(tr, UDim.new(0,3))
    local fl = Instance.new("Frame"); fl.Size = UDim2.new(math.clamp((def-mn)/(mx-mn),0,1),0,1,0)
    fl.BackgroundColor3 = C.accent; fl.BorderSizePixel = 0; fl.Parent = tr; mkC(fl, UDim.new(0,3))
    local drag = false
    tr.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local rv = math.clamp((i.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X,1), 0, 1)
        local v = math.floor(mn + rv*(mx-mn) + 0.5)
        fl.Size = UDim2.new(rv,0,1,0); vl.Text = tostring(v); pcall(cb, v)
    end)
    return vl
end

local function mkL(p, text, col, sz)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,0,sz or 16)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = col or C.dim
    l.TextSize = 11; l.Font = FONT; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true; l.Parent = p; return l
end

local function mkB(p, text, col, cb)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,30)
    b.BackgroundColor3 = col or C.accent; b.Text = text; b.TextColor3 = C.text
    b.TextSize = 12; b.Font = FONTB; b.BorderSizePixel = 0; b.Parent = p; mkC(b)
    if cb then b.MouseButton1Click:Connect(function() pcall(cb) end) end; return b
end

local function mkSep(p) local s = Instance.new("Frame"); s.Size = UDim2.new(1,0,0,1); s.BackgroundColor3 = C.track; s.BorderSizePixel = 0; s.Parent = p end

-- ============================================================
--  TAB: PLAYER
-- ============================================================
pcall(function()
    local f = tF["Player"]
    local c = mkCard(f, "🏃 Rörelse")
    mkTog(c, "Walkspeed-hack", cfg.player.enabled, function(v) cfg.player.enabled = v; saveCfg() end)
    mkSli(c, "Hastighet", 16, 300, cfg.player.speed, function(v) cfg.player.speed = v; saveCfg() end)
    mkSep(c)
    mkTog(c, "Jump-hack", cfg.player.jumpEnabled, function(v) cfg.player.jumpEnabled = v; saveCfg() end)
    mkSli(c, "Hopphöjd", 50, 400, cfg.player.jump, function(v) cfg.player.jump = v; saveCfg() end)
    local st = mkL(c, "WS: -- | JP: --", C.dim)
    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.1)
            pcall(function()
                local ch = player.Character; if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                if cfg.player.enabled then h.WalkSpeed = cfg.player.speed end
                if cfg.player.jumpEnabled then h.JumpPower = cfg.player.jump; h.UseJumpPower = true end
                st.Text = "WS: " .. math.floor(h.WalkSpeed) .. " | JP: " .. math.floor(h.JumpPower)
                st.TextColor3 = cfg.player.enabled and C.good or C.dim
            end)
        end
    end)
end)

-- ============================================================
--  TAB: VEHICLE (ingen CFrame!)
-- ============================================================
pcall(function()
    local f = tF["Vehicle"]
    local c = mkCard(f, "🚗 Fordonshack")
    mkTog(c, "Aktivera", cfg.vehicle.enabled, function(v) cfg.vehicle.enabled = v; saveCfg() end)
    mkSli(c, "Maxhastighet", 30, 500, cfg.vehicle.maxSpeed, function(v) cfg.vehicle.maxSpeed = v; saveCfg() end)
    mkSli(c, "Acceleration", 20, 600, cfg.vehicle.accel, function(v) cfg.vehicle.accel = v; saveCfg() end)
    mkSli(c, "Broms", 30, 600, cfg.vehicle.brake, function(v) cfg.vehicle.brake = v; saveCfg() end)
    local st = mkL(c, "Inget fordon", C.dim)
    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.1)
            pcall(function()
                if not cfg.vehicle.enabled then st.Text = "AV"; st.TextColor3 = C.dim; return end
                local ch = player.Character; if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                local seat = h.SeatPart
                if not seat then st.Text = "Sitter ej"; st.TextColor3 = C.warn; return end
                local vs = nil
                pcall(function()
                    if seat:IsA("VehicleSeat") then vs = seat
                    else vs = seat:FindFirstAncestorWhichIsA("VehicleSeat") end
                end)
                if not vs then st.Text = "Ingen VehicleSeat"; st.TextColor3 = C.warn; return end
                pcall(function() vs.MaxSpeed = cfg.vehicle.maxSpeed end)
                st.Text = "Fordon: " .. (vs.Parent and vs.Parent.Name or "?") .. " | " .. cfg.vehicle.maxSpeed
                st.TextColor3 = C.good
            end)
        end
    end)
end)

-- ============================================================
--  TAB: JOB (MANUELL SCAN, ingen auto-GetDescendants)
-- ============================================================
pcall(function()
    local f = tF["Job"]
    local c = mkCard(f, "🍕 Pizza Auto-Farm")
    local stLbl = mkL(c, "Status: AV", C.dim)
    local stLbl2 = mkL(c, "A:0 P:0 C:0 F:0", C.dim)
    local dbgLbl = mkL(c, "Tryck FORCE SCAN först", C.dim, 36)
    dbgLbl.AutomaticSize = Enum.AutomaticSize.Y
    local stats = {a=0, p=0, c=0, f=0}

    mkTog(c, "Aktivera", cfg.job.enabled, function(v)
        cfg.job.enabled = v; stLbl.Text = v and "PÅ ✓" or "AV"; stLbl.TextColor3 = v and C.good or C.dim; saveCfg()
    end)
    mkSep(c)
    mkSli(c, "Intervall (ms×10)", 1, 10, math.floor(cfg.job.interval*10), function(v) cfg.job.interval = v/10; saveCfg() end)
    mkSli(c, "Radie", 5, 50, cfg.job.radius, function(v) cfg.job.radius = v; saveCfg() end)
    mkSli(c, "Max per tick", 1, 15, cfg.job.maxPerTick, function(v) cfg.job.maxPerTick = v; saveCfg() end)
    mkSep(c)
    mkTog(c, "Prompts", cfg.job.firePrompts, function(v) cfg.job.firePrompts = v; saveCfg() end)
    mkTog(c, "Clicks", cfg.job.fireClicks, function(v) cfg.job.fireClicks = v; saveCfg() end)
    mkTog(c, "Svartlista", cfg.job.useBlacklist, function(v) cfg.job.useBlacklist = v; saveCfg() end)
    local modeLbl = mkL(c, "Läge: " .. cfg.job.mode, C.accent)
    mkB(c, "🔄 Växla läge", C.warn, function()
        cfg.job.mode = cfg.job.mode == "aggressive" and "keyword" or "aggressive"
        modeLbl.Text = "Läge: " .. cfg.job.mode; saveCfg(); notify(cfg.job.mode)
    end)

    local c2 = mkCard(f, "🔧 Verktyg")
    local pCache = {}
    local cCache = {}
    local cooldowns = {}

    -- MANUELL SCAN (enda stället GetDescendants anropas)
    mkB(c2, "🔍 FORCE SCAN (kan ta 5-10 sek)", C.warn, function()
        notify("Skannar... vänta")
        pCache = {}; cCache = {}
        pcall(function()
            local desc = workspace:GetDescendants()
            local total = #desc
            for i = 1, total do
                local d = desc[i]
                if d:IsA("ProximityPrompt") then pCache[#pCache+1] = d
                elseif d:IsA("ClickDetector") then cCache[#cCache+1] = d end
                if i % 200 == 0 then tWait(0.05) end  -- Långsammare = säkrare
            end
        end)
        notify("Klar! " .. #pCache .. "p / " .. #cCache .. "c")
        dbgLbl.Text = "Cache: " .. #pCache .. " prompts, " .. #cCache .. " clicks"
        dbgLbl.TextColor3 = C.good
    end)

    mkB(c2, "🎯 Avfyra närmaste", C.accent, function()
        local ch = player.Character; if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
        local pos = root.Position
        local near = nil; local nd = math.huge
        for i = 1, #pCache do
            local p = pCache[i]; if not p or not p.Parent then continue end
            local pt = p.Parent
            pcall(function() if not pt:IsA("BasePart") then pt = pt:FindFirstChildWhichIsA("BasePart") end end)
            if not pt or not pt:IsA("BasePart") then continue end
            local d = (pt.Position - pos).Magnitude
            if d < nd then nd = d; near = p end
        end
        if near and firePrompt then pcall(firePrompt, near); notify("Avfyrade!") else notify("Ingen hittad") end
    end)

    mkB(c2, "🗑️ Nollställ", C.bad, function() stats = {a=0,p=0,c=0,f=0}; notify("OK") end)

    local function isBL(text)
        if not cfg.job.useBlacklist then return false end
        local lo = string.lower(text or "")
        for w in string.gmatch(cfg.job.blacklist, "[^,]+") do if string.find(lo, string.lower(w)) then return true end end
        return false
    end

    local function matchKW(text)
        if cfg.job.mode == "aggressive" then return true end
        local lo = string.lower(text or "")
        for w in string.gmatch(cfg.job.keywords, "[^,]+") do if string.find(lo, string.lower(w)) then return true end end
        return false
    end

    tSpawn(function()
        tWait(5)
        while ScreenGui and ScreenGui.Parent do
            tWait(math.max(cfg.job.interval, 0.1))
            pcall(function()
                if not cfg.job.enabled then return end
                if #pCache == 0 and #cCache == 0 then return end  -- Ingen cache = gör inget
                local ch = player.Character; if not ch then return end
                local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
                local pos = root.Position
                local fired = 0; local dbg = {}

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
                        if (part.Position - pos).Magnitude > cfg.job.radius then continue end
                        local full = (p.ObjectText or "") .. " " .. (p.ActionText or "")
                        if isBL(full) then continue end
                        if not matchKW(full) then continue end
                        local now = tick(); local key = tostring(p)
                        if cooldowns[key] and (now - cooldowns[key]) < 0.6 then continue end
                        local ok = false
                        if firePrompt then ok = pcall(firePrompt, p) end
                        if not ok then
                            ok = pcall(function() local o = p.HoldDuration; p.HoldDuration = 0; tWait(0.05); p.HoldDuration = o end)
                        end
                        if ok then
                            fired = fired + 1; stats.a = stats.a + 1; stats.p = stats.p + 1; cooldowns[key] = now
                            if #dbg < 3 then dbg[#dbg+1] = "OK:" .. string.sub(full,1,15) end
                        else stats.f = stats.f + 1 end
                    end
                end

                if cfg.job.fireClicks and fireClick then
                    for i = 1, #cCache do
                        if fired >= cfg.job.maxPerTick then break end
                        local cd = cCache[i]
                        if not cd or not cd.Parent or not cd.Parent:IsA("BasePart") then continue end
                        if (cd.Parent.Position - pos).Magnitude > cfg.job.radius then continue end
                        local now = tick(); local key = "cd" .. tostring(cd)
                        if cooldowns[key] and (now - cooldowns[key]) < 0.6 then continue end
                        if pcall(fireClick, cd) then
                            fired = fired + 1; stats.a = stats.a + 1; stats.c = stats.c + 1; cooldowns[key] = now
                        end
                    end
                end

                stLbl2.Text = string.format("A:%d P:%d C:%d F:%d", stats.a, stats.p, stats.c, stats.f)
                if #dbg > 0 then dbgLbl.Text = table.concat(dbg, " | "); dbgLbl.TextColor3 = C.good end

                if math.random(1,30) == 1 then
                    local now = tick()
                    for k, v in pairs(cooldowns) do if now - v > 10 then cooldowns[k] = nil end end
                end
            end)
        end
    end)
end)

-- ============================================================
--  TAB: PLAYERS
-- ============================================================
pcall(function()
    local f = tF["Players"]
    local c = mkCard(f, "👥 Spelare")
    local pL = mkL(c, "Laddar...", C.dim, 64); pL.AutomaticSize = Enum.AutomaticSize.Y
    local c2 = mkCard(f, "🥾 Kick")
    local kb = Instance.new("TextBox"); kb.Size = UDim2.new(1,0,0,30); kb.BackgroundColor3 = C.card
    kb.TextColor3 = C.text; kb.TextSize = 12; kb.Font = FONT
    kb.PlaceholderText = "Namn..."; kb.PlaceholderColor3 = C.dim; kb.BorderSizePixel = 0; kb.Parent = c2; mkC(kb)
    mkB(c2, "Kicka", C.bad, function()
        local n = kb.Text; if n == "" then return end
        local t = Players:FindFirstChild(n)
        if t then pcall(function() local h = t.Character and t.Character:FindFirstChildOfClass("Humanoid"); if h then h.Health = 0 end end) end
        notify("Försökte " .. n)
    end)
    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(3)
            pcall(function()
                local l = {}
                for _, p in ipairs(Players:GetPlayers()) do l[#l+1] = (p == player and "⭐ " or "  ") .. p.Name end
                pL.Text = table.concat(l, "\n"); pL.TextColor3 = C.text
            end)
        end
    end)
end)

-- ============================================================
--  TAB: SETTINGS
-- ============================================================
pcall(function()
    local f = tF["Settings"]
    local c = mkCard(f, "🗺️ Zoner")
    mkTog(c, "Aktivera", cfg.limits.enabled, function(v) cfg.limits.enabled = v; saveCfg() end)
    mkSli(c, "Global max", 16, 300, cfg.limits.global, function(v) cfg.limits.global = v; saveCfg() end)
    local zL = mkL(c, "Zoner: " .. #cfg.limits.zones, C.dim)
    mkB(c, "➕ Zon här", C.good, function()
        local ch = player.Character; if not ch then return end
        local r = ch:FindFirstChild("HumanoidRootPart"); if not r then return end
        table.insert(cfg.limits.zones, {x=math.floor(r.Position.X), y=math.floor(r.Position.Y), z=math.floor(r.Position.Z), r=30, speed=50})
        zL.Text = "Zoner: " .. #cfg.limits.zones; saveCfg(); notify("OK")
    end)
    mkB(c, "🗑️ Rensa", C.bad, function() cfg.limits.zones = {}; zL.Text = "Zoner: 0"; saveCfg() end)
    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(0.15)
            pcall(function()
                if not cfg.limits.enabled then return end
                local ch = player.Character; if not ch then return end
                local h = ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                local r = ch:FindFirstChild("HumanoidRootPart"); if not r then return end
                local lim = cfg.limits.global
                for _, z in ipairs(cfg.limits.zones) do
                    if (r.Position - Vector3.new(z.x,z.y,z.z)).Magnitude <= z.r then lim = math.min(lim, z.speed) end
                end
                if h.WalkSpeed > lim then h.WalkSpeed = lim end
            end)
        end
    end)
    local c2 = mkCard(f, "💾 Config")
    mkB(c2, "Spara", C.good, function() saveCfg(); notify("OK") end)
    mkB(c2, "Återställ", C.bad, function() pcall(function() if delfile and isfile and isfile(CFG) then delfile(CFG) end end); notify("Starta om") end)
    local c3 = mkCard(f, "ℹ️ Info")
    mkL(c3, "Venice v" .. VERSION, C.accent)
    mkL(c3, "fireproximityprompt: " .. (firePrompt and "✓" or "✗"), firePrompt and C.good or C.bad)
    mkL(c3, "fireclickdetector: " .. (fireClick and "✓" or "✗"), fireClick and C.good or C.bad)
    mkL(c3, "getconnections: " .. (getConns and "✓" or "✗"), getConns and C.good or C.bad)
end)

-- KEYBIND
pcall(function()
    UIS.InputBegan:Connect(function(i, g) if g then return end; if i.KeyCode == Enum.KeyCode[cfg.ui.keybind] then main.Visible = not main.Visible end end)
end)

print("[Venice] v" .. VERSION .. " KLAR")
notify("Venice v" .. VERSION .. " [" .. cfg.ui.keybind .. "]", 4)
