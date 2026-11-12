-- ============================================================
--  VENICE SPEED SUITE v2.1  –  Full features, Xeno-safe
-- ============================================================
local VERSION = "2.1"

-- [1] SÄKRA task-LIBRARY
local tWait  = (task and task.wait)  or wait
local tSpawn = (task and task.spawn) or spawn
local tDelay = (task and task.delay) or delay
local tDefer = (task and task.defer) or tSpawn

-- [2] SKAPA GUI OMEDELBART
local ScreenGui
do
    local sg = Instance.new("ScreenGui")
    sg.Name = "VeniceSpeedSuite"
    sg.ResetPlayerGuiOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    local parent = nil
    pcall(function() parent = gethui() end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end
    sg.Parent = parent
    ScreenGui = sg
end

-- [3] EXECUTOR-FUNKTIONER
local firePrompt = rawget(getfenv(0),"fireproximityprompt") or (getgenv and getgenv().fireproximityprompt) or nil
local fireClick  = rawget(getfenv(0),"fireclickdetector")  or (getgenv and getgenv().fireclickdetector)  or nil
local getConns   = rawget(getfenv(0),"getconnections")     or (getgenv and getgenv().getconnections)     or nil

-- [4] SERVICES
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local player      = Players.LocalPlayer

local function notify(msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="Venice Suite",Text=msg,Duration=dur or 3})
    end)
end

-- ============================================================
--  FÄRGER
-- ============================================================
local C = {
    bg=Color3.fromRGB(12,14,19), panel=Color3.fromRGB(20,24,31),
    card=Color3.fromRGB(28,33,42), track=Color3.fromRGB(44,50,62),
    text=Color3.fromRGB(233,237,245), dim=Color3.fromRGB(132,142,160),
    good=Color3.fromRGB(88,214,141), warn=Color3.fromRGB(255,186,84),
    bad=Color3.fromRGB(255,106,106), accent=Color3.fromRGB(94,141,255),
}
local FONT  = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold
local CORN  = UDim.new(0,8)

local function corner(r) local c=Instance.new("UICorner"); c.CornerRadius=r or CORN; return c end
local function stroke(p,col,t) local s=Instance.new("UIStroke"); s.Color=col or C.track; s.Thickness=t or 1; s.Parent=p; return s end

-- ============================================================
--  KONFIGURATION
-- ============================================================
local CFG_FILE = "VeniceSpeedSuite.json"
local cfg = {
    player  = {enabled=false, speed=34, jumpEnabled=false, jump=50},
    vehicle = {enabled=false, maxSpeed=130, accel=110, brake=190, assist=true},
    job = {
        enabled=false, interval=0.1, radius=15, mode="aggressive",
        firePrompts=true, fireClicks=true, useBlacklist=true, maxPerTick=8,
        blacklist="door,gate,exit,entrance,sleep,bed,sit,chair,seat,menu,shop,buy,purchase,sell,radio,tv,television,stereo,toilet,sink,shower,bath,trash,bin,garbage",
        keywords="dough,sauce,cheese,pepperoni,topping,oven,bake,cook,cut,slice,box,package,order,deliver,pizza,knead,prepare,serve,grab,take,put,flatten,roll",
    },
    limits = {enabled=false, global=110, zones={}, MAX_ZONES=40},
    ui = {accent={94,141,255}, keybind="K"},
}

local function loadCfg()
    pcall(function()
        if not (isfile and isfile(CFG_FILE) and readfile) then return end
        local d = HttpService:JSONDecode(readfile(CFG_FILE))
        local function merge(src, dst)
            for k,v in pairs(src) do
                if type(v)=="table" and type(dst[k])=="table" then merge(v, dst[k])
                elseif dst[k]==nil then dst[k]=v end
            end
        end
        merge(d, cfg)
    end)
end

local saveTok = 0
local function saveCfg()
    saveTok = saveTok + 1
    local tok = saveTok
    tDelay(0.6, function()
        if tok ~= saveTok then return end
        pcall(function() if writefile then writefile(CFG_FILE, HttpService:JSONEncode(cfg)) end end)
    end)
end
loadCfg()

-- ============================================================
--  HUVUDFÖNSTER
-- ============================================================
local WIN_W, WIN_H = 460, 560
local main = Instance.new("Frame")
main.Name="Main"; main.Size=UDim2.fromOffset(WIN_W,WIN_H)
main.Position=UDim2.fromOffset(80,80); main.BackgroundColor3=C.bg
main.BorderSizePixel=0; main.Active=true; main.Draggable=true
corner(main); stroke(main,C.track,1.5); main.Parent=ScreenGui

-- Titelbar
local tbar = Instance.new("Frame")
tbar.Size=UDim2.new(1,0,0,36); tbar.BackgroundColor3=C.panel
tbar.BorderSizePixel=0; tbar.Parent=main; corner(tbar)

local ttl = Instance.new("TextLabel")
ttl.Size=UDim2.new(1,-80,1,0); ttl.Position=UDim2.fromOffset(12,0)
ttl.BackgroundTransparency=1; ttl.Text="⚡ Venice Speed Suite v"..VERSION
ttl.TextColor3=C.accent; ttl.TextSize=14; ttl.Font=FONTB
ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Parent=tbar

local closeBtn = Instance.new("TextButton")
closeBtn.Size=UDim2.fromOffset(28,28); closeBtn.Position=UDim2.new(1,-32,0,4)
closeBtn.BackgroundColor3=C.bad; closeBtn.Text="✕"; closeBtn.TextColor3=C.text
closeBtn.TextSize=13; closeBtn.Font=FONTB; closeBtn.BorderSizePixel=0
closeBtn.Parent=tbar; corner(closeBtn)
closeBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local minBtn = Instance.new("TextButton")
minBtn.Size=UDim2.fromOffset(28,28); minBtn.Position=UDim2.new(1,-64,0,4)
minBtn.BackgroundColor3=C.warn; minBtn.Text="—"; minBtn.TextColor3=C.text
minBtn.TextSize=13; minBtn.Font=FONTB; minBtn.BorderSizePixel=0
minBtn.Parent=tbar; corner(minBtn)
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    main.Size = minimized and UDim2.fromOffset(WIN_W,36) or UDim2.fromOffset(WIN_W,WIN_H)
end)

-- ============================================================
--  TAB-SYSTEM
-- ============================================================
local TABS = {"Player","Vehicle","Job","Players","Settings"}
local tFrames, tBtns = {}, {}
local tabBar = Instance.new("Frame")
tabBar.Size=UDim2.new(1,0,0,34); tabBar.Position=UDim2.fromOffset(0,36)
tabBar.BackgroundColor3=C.panel; tabBar.BorderSizePixel=0; tabBar.Parent=main

local tContent = Instance.new("Frame")
tContent.Size=UDim2.new(1,-16,1,-86); tContent.Position=UDim2.fromOffset(8,78)
tContent.BackgroundTransparency=1; tContent.ClipsDescendants=true; tContent.Parent=main

local tw = 1/#TABS
for i,name in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(tw,0,1,0); btn.Position=UDim2.new(tw*(i-1),0,0,0)
    btn.BackgroundColor3=C.bg; btn.Text=name; btn.TextColor3=C.dim
    btn.TextSize=11; btn.Font=FONT; btn.BorderSizePixel=0; btn.Parent=tabBar

    local fr = Instance.new("ScrollingFrame")
    fr.Size=UDim2.new(1,0,1,0); fr.BackgroundTransparency=1; fr.BorderSizePixel=0
    fr.ScrollBarThickness=4; fr.ScrollBarImageColor3=C.track
    fr.CanvasSize=UDim2.new(0,0,0,0); fr.AutomaticCanvasSize=Enum.AutomaticSize.Y
    fr.Visible=false; fr.Parent=tContent
    local ul = Instance.new("UIListLayout"); ul.SortOrder=Enum.SortOrder.LayoutOrder
    ul.Padding=UDim.new(0,6); ul.Parent=fr
    local up = Instance.new("UIPadding"); up.PaddingTop=UDim.new(0,4)
    up.PaddingBottom=UDim.new(0,8); up.Parent=fr

    tFrames[name]=fr; tBtns[name]=btn
    btn.MouseButton1Click:Connect(function()
        for n,f in pairs(tFrames) do f.Visible=false; tBtns[n].BackgroundColor3=C.bg; tBtns[n].TextColor3=C.dim end
        fr.Visible=true; btn.BackgroundColor3=C.card; btn.TextColor3=C.accent
    end)
end
tBtns["Player"].BackgroundColor3=C.card; tBtns["Player"].TextColor3=C.accent
tFrames["Player"].Visible=true

-- ============================================================
--  UI-KOMPONENTER
-- ============================================================
local function card(parent, title)
    local c=Instance.new("Frame"); c.Size=UDim2.new(1,-4,0,0)
    c.AutomaticSize=Enum.AutomaticSize.Y; c.BackgroundColor3=C.card
    c.BorderSizePixel=0; c.Parent=parent; corner(c)
    local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,10)
    p.PaddingRight=UDim.new(0,10); p.PaddingTop=UDim.new(0,8)
    p.PaddingBottom=UDim.new(0,8); p.Parent=c
    local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,5); l.Parent=c
    if title then
        local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,18)
        t.BackgroundTransparency=1; t.Text=title; t.TextColor3=C.accent
        t.TextSize=12; t.Font=FONTB; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=c
    end
    return c
end

local function toggle(parent, label, def, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,28)
    row.BackgroundTransparency=1; row.Parent=parent
    local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,-50,1,0)
    t.BackgroundTransparency=1; t.Text=label; t.TextColor3=C.text
    t.TextSize=12; t.Font=FONT; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=row
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(42,22)
    b.Position=UDim2.new(1,-44,0,3); b.BackgroundColor3=def and C.good or C.track
    b.Text=def and "PÅ" or "AV"; b.TextColor3=C.text; b.TextSize=10
    b.Font=FONTB; b.BorderSizePixel=0; b.Parent=row; corner(b,UDim.new(0,6))
    local st=def
    b.MouseButton1Click:Connect(function()
        st=not st; b.BackgroundColor3=st and C.good or C.track
        b.Text=st and "PÅ" or "AV"; if cb then cb(st) end
    end)
    return function(v) st=v; b.BackgroundColor3=st and C.good or C.track; b.Text=st and "PÅ" or "AV" end
end

local function slider(parent, label, mn, mx, def, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,36)
    row.BackgroundTransparency=1; row.Parent=parent
    local t=Instance.new("TextLabel"); t.Size=UDim2.new(0.6,0,0,16)
    t.BackgroundTransparency=1; t.Text=label; t.TextColor3=C.text
    t.TextSize=11; t.Font=FONT; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=row
    local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0.4,0,0,16)
    vl.BackgroundTransparency=1; vl.Text=tostring(def); vl.TextColor3=C.accent
    vl.TextSize=11; vl.Font=FONTB; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row
    local tr=Instance.new("Frame"); tr.Size=UDim2.new(1,0,0,6)
    tr.Position=UDim2.fromOffset(0,22); tr.BackgroundColor3=C.track
    tr.BorderSizePixel=0; tr.Parent=row; corner(tr,UDim.new(0,3))
    local fl=Instance.new("Frame"); fl.Size=UDim2.new((def-mn)/(mx-mn),0,1,0)
    fl.BackgroundColor3=C.accent; fl.BorderSizePixel=0; fl.Parent=tr; corner(fl,UDim.new(0,3))
    local drag=false
    tr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local r=math.clamp((i.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        local v=math.floor(mn+r*(mx-mn)+0.5)
        fl.Size=UDim2.new(r,0,1,0); vl.Text=tostring(v); if cb then cb(v) end
    end)
    return vl
end

local function lbl(parent, text, color, sz)
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,sz or 16)
    l.BackgroundTransparency=1; l.Text=text; l.TextColor3=color or C.dim
    l.TextSize=11; l.Font=FONT; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextWrapped=true; l.Parent=parent; return l
end

local function btn(parent, text, color, cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=color or C.accent; b.Text=text; b.TextColor3=C.text
    b.TextSize=12; b.Font=FONTB; b.BorderSizePixel=0; b.Parent=parent; corner(b)
    if cb then b.MouseButton1Click:Connect(cb) end; return b
end

local function separator(parent)
    local s=Instance.new("Frame"); s.Size=UDim2.new(1,0,0,1)
    s.BackgroundColor3=C.track; s.BorderSizePixel=0; s.Parent=parent; return s
end

-- ============================================================
--  TAB: PLAYER
-- ============================================================
pcall(function()
    local f = tFrames["Player"]
    local c1 = card(f, "🏃 Rörelse")
    toggle(c1, "Walkspeed-hack", cfg.player.enabled, function(v) cfg.player.enabled=v; saveCfg() end)
    slider(c1, "Hastighet", 16, 300, cfg.player.speed, function(v) cfg.player.speed=v; saveCfg() end)
    separator(c1)
    toggle(c1, "Jump-hack", cfg.player.jumpEnabled, function(v) cfg.player.jumpEnabled=v; saveCfg() end)
    slider(c1, "Hopphöjd", 50, 400, cfg.player.jump, function(v) cfg.player.jump=v; saveCfg() end)

    local c2 = card(f, "📊 Status")
    local pStatus = lbl(c2, "WalkSpeed: -- | JumpPower: --", C.dim)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(1/15)
            pcall(function()
                local ch=player.Character; if not ch then return end
                local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                if cfg.player.enabled then h.WalkSpeed=cfg.player.speed end
                if cfg.player.jumpEnabled then h.JumpPower=cfg.player.jump; h.UseJumpPower=true end
                pStatus.Text=string.format("WalkSpeed: %d | JumpPower: %d", math.floor(h.WalkSpeed), math.floor(h.JumpPower))
                pStatus.TextColor3 = cfg.player.enabled and C.good or C.dim
            end)
        end
    end)
end)

-- ============================================================
--  TAB: VEHICLE
-- ============================================================
pcall(function()
    local f = tFrames["Vehicle"]
    local c1 = card(f, "🚗 Fordonshack")
    toggle(c1, "Aktivera", cfg.vehicle.enabled, function(v) cfg.vehicle.enabled=v; saveCfg() end)
    slider(c1, "Maxhastighet", 30, 500, cfg.vehicle.maxSpeed, function(v) cfg.vehicle.maxSpeed=v; saveCfg() end)
    slider(c1, "Acceleration", 20, 600, cfg.vehicle.accel, function(v) cfg.vehicle.accel=v; saveCfg() end)
    slider(c1, "Broms", 30, 600, cfg.vehicle.brake, function(v) cfg.vehicle.brake=v; saveCfg() end)
    separator(c1)
    toggle(c1, "Fysik-assist (anti-vält)", cfg.vehicle.assist, function(v) cfg.vehicle.assist=v; saveCfg() end)

    local c2 = card(f, "📊 Fordonsinfo")
    local vStatus = lbl(c2, "Inget fordon", C.dim)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(1/20)
            pcall(function()
                if not cfg.vehicle.enabled then vStatus.Text="Hack AV"; vStatus.TextColor3=C.dim; return end
                local ch=player.Character; if not ch then return end
                local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                local seat=h.SeatPart
                if not seat then vStatus.Text="Sitter inte i fordon"; vStatus.TextColor3=C.warn; return end
                local vs = seat:IsA("VehicleSeat") and seat or seat:FindFirstAncestorWhichIsA("VehicleSeat")
                if not vs then
                    local m=seat:FindFirstAncestorWhichIsA("Model")
                    if m then vs=m:FindFirstChildWhichIsA("VehicleSeat") end
                end
                if not vs then vStatus.Text="Ingen VehicleSeat hittad"; vStatus.TextColor3=C.warn; return end
                vs.MaxSpeed=cfg.vehicle.maxSpeed
                if vs:FindFirstChild("Torque") then vs.Torque=cfg.vehicle.accel end
                vStatus.Text=string.format("Fordon: %s | Speed: %d", (vs.Parent and vs.Parent.Name or "?"), math.floor(cfg.vehicle.maxSpeed))
                vStatus.TextColor3=C.good
                if cfg.vehicle.assist then
                    local root=seat:FindFirstAncestorWhichIsA("Model")
                    if root then
                        local pp=root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart")
                        if pp then
                            local cf=pp.CFrame
                            local up=CFrame.fromMatrix(cf.Position, cf.RightVector, Vector3.new(0,1,0))
                            pp.CFrame=pp.CFrame:Lerp(up, 0.08)
                        end
                    end
                end
            end)
        end
    end)
end)

-- ============================================================
--  TAB: JOB (Pizza Auto-Farm v3)
-- ============================================================
pcall(function()
    local f = tFrames["Job"]
    local c1 = card(f, "🍕 Pizza Auto-Farm")

    local statusLbl = lbl(c1, "Status: AV", C.dim)
    local statsLbl  = lbl(c1, "Actions: 0 | Prompts: 0 | Clicks: 0 | Fails: 0", C.dim)
    local debugLbl  = lbl(c1, "Debug: väntar på aktivering...", C.dim, 48)
    debugLbl.AutomaticSize = Enum.AutomaticSize.Y

    local stats = {actions=0, prompts=0, clicks=0, fails=0}

    toggle(c1, "Aktivera pizza-farm", cfg.job.enabled, function(v)
        cfg.job.enabled=v
        statusLbl.Text=v and "Status: PÅ ✓" or "Status: AV"
        statusLbl.TextColor3=v and C.good or C.dim
        saveCfg()
    end)

    separator(c1)
    slider(c1, "Intervall (ms×10)", 1, 10, math.floor(cfg.job.interval*10), function(v) cfg.job.interval=v/10; saveCfg() end)
    slider(c1, "Radie (studs)", 5, 50, cfg.job.radius, function(v) cfg.job.radius=v; saveCfg() end)
    slider(c1, "Max per tick", 1, 20, cfg.job.maxPerTick, function(v) cfg.job.maxPerTick=v; saveCfg() end)

    separator(c1)
    toggle(c1, "Avfyra ProximityPrompts", cfg.job.firePrompts, function(v) cfg.job.firePrompts=v; saveCfg() end)
    toggle(c1, "Avfyra ClickDetectors", cfg.job.fireClicks, function(v) cfg.job.fireClicks=v; saveCfg() end)
    toggle(c1, "Använd svartlista", cfg.job.useBlacklist, function(v) cfg.job.useBlacklist=v; saveCfg() end)

    separator(c1)
    local modeLbl = lbl(c1, "Läge: " .. cfg.job.mode, C.accent)
    btn(c1, "🔄 Växla läge (aggressive/keyword)", C.warn, function()
        cfg.job.mode = cfg.job.mode=="aggressive" and "keyword" or "aggressive"
        modeLbl.Text = "Läge: " .. cfg.job.mode
        saveCfg()
        notify("Läge: " .. cfg.job.mode)
    end)

    local c2 = card(f, "🔧 Verktyg")
    local promptCacheDirty = true
    local fireManual = false

    btn(c2, "🔍 FORCE SCAN (bygg om cache)", C.warn, function()
        promptCacheDirty = true
        notify("Skannar om workspace...")
    end)
    btn(c2, "🎯 Avfyra närmaste manuellt", C.accent, function() fireManual = true end)
    btn(c2, "🗑️ Nollställ statistik", C.bad, function()
        stats={actions=0,prompts=0,clicks=0,fails=0}
        notify("Statistik nollställd")
    end)

    -- Cache
    local pCache, cCache = {}, {}
    local cooldowns = {}

    local function rebuild()
        pCache={}; cCache={}
        pcall(function()
            local desc = workspace:GetDescendants()
            for i=1,#desc do
                local d=desc[i]
                if d:IsA("ProximityPrompt") then pCache[#pCache+1]=d
                elseif d:IsA("ClickDetector") then cCache[#cCache+1]=d end
                if i%500==0 then tWait() end
            end
        end)
        promptCacheDirty=false
        notify("Cache: " .. #pCache .. " prompts, " .. #cCache .. " clicks")
    end

    pcall(function()
        workspace.DescendantAdded:Connect(function(d)
            if d:IsA("ProximityPrompt") then pCache[#pCache+1]=d
            elseif d:IsA("ClickDetector") then cCache[#cCache+1]=d end
        end)
        workspace.DescendantRemoving:Connect(function(d)
            if d:IsA("ProximityPrompt") then
                for i=#pCache,1,-1 do if pCache[i]==d then table.remove(pCache,i) break end end
            elseif d:IsA("ClickDetector") then
                for i=#cCache,1,-1 do if cCache[i]==d then table.remove(cCache,i) break end end
            end
        end)
    end)

    local function blacklisted(text)
        if not cfg.job.useBlacklist then return false end
        local lo=string.lower(text or "")
        for w in string.gmatch(cfg.job.blacklist,"[^,]+") do
            if string.find(lo, string.lower(w)) then return true end
        end
        return false
    end

    local function matchKW(text)
        if cfg.job.mode=="aggressive" then return true end
        local lo=string.lower(text or "")
        for w in string.gmatch(cfg.job.keywords,"[^,]+") do
            if string.find(lo, string.lower(w)) then return true end
        end
        return false
    end

    local function fireP(p)
        if not p or not p.Parent then return false end
        if firePrompt then
            local ok=pcall(function() firePrompt(p) end)
            if ok then return true,"fp" end
        end
        local ok2=pcall(function()
            local old=p.HoldDuration; p.HoldDuration=0; tWait(0.05); p.HoldDuration=old
        end)
        if ok2 then return true,"h0" end
        local ok3=pcall(function() p:InputHoldBegin(); tWait(0.05); p:InputHoldEnd() end)
        if ok3 then return true,"ih" end
        return false,"fail"
    end

    local function fireC(cd)
        if not cd or not cd.Parent then return false end
        if fireClick then
            local ok=pcall(function() fireClick(cd) end)
            if ok then return true,"fc" end
        end
        if getConns then
            local ok2=pcall(function()
                local cn=getConns(cd.MouseClick)
                for _,c in ipairs(cn or {}) do if c.Function then c.Function(player) end end
            end)
            if ok2 then return true,"gc" end
        end
        return false,"fail"
    end

    tSpawn(function()
        tWait(3)
        while ScreenGui and ScreenGui.Parent do
            tWait(cfg.job.interval)
            pcall(function()
                if not cfg.job.enabled and not fireManual then return end
                local ch=player.Character; if not ch then return end
                local root=ch:FindFirstChild("HumanoidRootPart"); if not root then return end
                local pos=root.Position

                if promptCacheDirty then rebuild() end

                local fired=0; local dbg={}

                if cfg.job.firePrompts then
                    for i=1,#pCache do
                        if fired>=cfg.job.maxPerTick then break end
                        local p=pCache[i]
                        if not p or not p.Parent then continue end
                        local part=p.Parent
                        if not part:IsA("BasePart") then part=part:FindFirstChildWhichIsA("BasePart") end
                        if not part then continue end
                        local dist=(part.Position-pos).Magnitude
                        if dist>cfg.job.radius then continue end
                        local ot=p.ObjectText or ""; local at=p.ActionText or ""
                        local full=ot.." "..at
                        if blacklisted(full) then
                            if #dbg<4 then dbg[#dbg+1]="SKIP(bl):"..string.sub(full,1,18) end
                            continue
                        end
                        if not matchKW(full) then continue end
                        local now=tick(); local key=tostring(p)
                        if cooldowns[key] and (now-cooldowns[key])<0.6 then continue end
                        local ok,m=fireP(p)
                        if ok then
                            fired=fired+1; stats.actions=stats.actions+1; stats.prompts=stats.prompts+1
                            cooldowns[key]=now
                            if #dbg<4 then dbg[#dbg+1]="OK("..m.."):"..string.sub(full,1,18) end
                        else stats.fails=stats.fails+1 end
                    end
                end

                if cfg.job.fireClicks then
                    for i=1,#cCache do
                        if fired>=cfg.job.maxPerTick then break end
                        local cd=cCache[i]
                        if not cd or not cd.Parent then continue end
                        local part=cd.Parent
                        if not part:IsA("BasePart") then continue end
                        local dist=(part.Position-pos).Magnitude
                        if dist>cfg.job.radius then continue end
                        local nm=part.Name or ""
                        if blacklisted(nm) then continue end
                        local now=tick(); local key="cd"..tostring(cd)
                        if cooldowns[key] and (now-cooldowns[key])<0.6 then continue end
                        local ok,m=fireC(cd)
                        if ok then
                            fired=fired+1; stats.actions=stats.actions+1; stats.clicks=stats.clicks+1
                            cooldowns[key]=now
                            if #dbg<4 then dbg[#dbg+1]="CLK("..m.."):"..string.sub(nm,1,18) end
                        end
                    end
                end

                if fireManual then
                    fireManual=false
                    local near=nil; local nd=math.huge
                    for i=1,#pCache do
                        local p=pCache[i]; if not p or not p.Parent then continue end
                        local pt=p.Parent:IsA("BasePart") and p.Parent or p.Parent:FindFirstChildWhichIsA("BasePart")
                        if not pt then continue end
                        local d=(pt.Position-pos).Magnitude
                        if d<nd then nd=d; near=p end
                    end
                    if near then fireP(near); notify("Avfyrade närmaste!") else notify("Ingen prompt hittad") end
                end

                statsLbl.Text=string.format("A:%d | P:%d | C:%d | F:%d", stats.actions, stats.prompts, stats.clicks, stats.fails)
                if #dbg>0 then
                    debugLbl.Text="Debug:\n"..table.concat(dbg,"\n")
                    debugLbl.TextColor3=C.good
                else
                    debugLbl.Text="Debug: inget i radie ("..cfg.job.radius.." studs) | cache:"..#pCache.."p/"..#cCache.."c"
                    debugLbl.TextColor3=C.dim
                end

                if math.random(1,50)==1 then
                    local now=tick()
                    for k,t in pairs(cooldowns) do if now-t>10 then cooldowns[k]=nil end end
                end
            end)
        end
    end)
end)

-- ============================================================
--  TAB: PLAYERS (Kick-lista)
-- ============================================================
pcall(function()
    local f = tFrames["Players"]
    local c1 = card(f, "👥 Spelare i servern")
    local pList = lbl(c1, "Laddar...", C.dim, 64)
    pList.AutomaticSize = Enum.AutomaticSize.Y

    local c2 = card(f, "🥾 Lokal Kick")
    local kickInput = Instance.new("TextBox")
    kickInput.Size=UDim2.new(1,0,0,30); kickInput.BackgroundColor3=C.card
    kickInput.TextColor3=C.text; kickInput.TextSize=12; kickInput.Font=FONT
    kickInput.PlaceholderText="Spelarnamn att kicka (lokalt)"; kickInput.PlaceholderColor3=C.dim
    kickInput.BorderSizePixel=0; kickInput.Parent=c2; corner(kickInput)

    btn(c2, "Kicka (lokal)", C.bad, function()
        local name=kickInput.Text
        if name=="" then notify("Skriv ett namn först"); return end
        local target=Players:FindFirstChild(name)
        if not target then notify("Spelare ej hittad"); return end
        pcall(function()
            local ch=target.Character
            if ch then
                local h=ch:FindFirstChildOfClass("Humanoid")
                if h then h.Health=0 end
            end
        end)
        notify("Försökte kicka " .. name)
    end)

    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(2)
            pcall(function()
                local lines={}
                for _,p in ipairs(Players:GetPlayers()) do
                    lines[#lines+1] = (p==player and "⭐ " or "  ") .. p.Name .. " [" .. p.DisplayName .. "]"
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

    -- Speed Zones
    local c1 = card(f, "🗺️ Hastighetszoner")
    toggle(c1, "Aktivera zoner", cfg.limits.enabled, function(v) cfg.limits.enabled=v; saveCfg() end)
    slider(c1, "Global maxhastighet", 16, 300, cfg.limits.global, function(v) cfg.limits.global=v; saveCfg() end)

    local zoneLbl = lbl(c1, "Zoner: " .. #cfg.limits.zones .. "/" .. cfg.limits.MAX_ZONES, C.dim)

    btn(c1, "➕ Lägg till zon här", C.good, function()
        if #cfg.limits.zones >= cfg.limits.MAX_ZONES then notify("Max zoner!"); return end
        local ch=player.Character; if not ch then return end
        local root=ch:FindFirstChild("HumanoidRootPart"); if not root then return end
        local pos=root.Position
        table.insert(cfg.limits.zones, {
            x=math.floor(pos.X), y=math.floor(pos.Y), z=math.floor(pos.Z),
            r=30, speed=50, name="Zon "..(#cfg.limits.zones+1)
        })
        zoneLbl.Text="Zoner: "..#cfg.limits.zones.."/"..cfg.limits.MAX_ZONES
        saveCfg(); notify("Zon tillagd!")
    end)

    btn(c1, "🗑️ Rensa alla zoner", C.bad, function()
        cfg.limits.zones={}; zoneLbl.Text="Zoner: 0/"..cfg.limits.MAX_ZONES
        saveCfg(); notify("Zoner rensade")
    end)

    -- Zon-loop
    tSpawn(function()
        while ScreenGui and ScreenGui.Parent do
            tWait(1/10)
            pcall(function()
                if not cfg.limits.enabled then return end
                local ch=player.Character; if not ch then return end
                local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return end
                local root=ch:FindFirstChild("HumanoidRootPart"); if not root then return end
                local pos=root.Position
                local limit = cfg.limits.global
                for _,z in ipairs(cfg.limits.zones) do
                    local zp=Vector3.new(z.x,z.y,z.z)
                    if (pos-zp).Magnitude <= z.r then
                        limit = math.min(limit, z.speed)
                    end
                end
                if h.WalkSpeed > limit then h.WalkSpeed = limit end
            end)
        end
    end)

    -- Config
    local c2 = card(f, "💾 Konfiguration")
    btn(c2, "Spara nu", C.good, function() saveCfg(); notify("Sparad!") end)
    btn(c2, "Återställ till standard", C.bad, function()
        pcall(function() if isfile and isfile(CFG_FILE) and delfile then delfile(CFG_FILE) end end)
        notify("Återställd! Starta om scriptet.")
    end)

    -- Info
    local c3 = card(f, "ℹ️ Info")
    lbl(c3, "Venice Speed Suite v" .. VERSION, C.accent)
    lbl(c3, "Executor-funktioner:", C.text)
    lbl(c3, "  fireproximityprompt: " .. (firePrompt and "✓ JA" or "✗ SAKNAS"), firePrompt and C.good or C.bad)
    lbl(c3, "  fireclickdetector:   " .. (fireClick and "✓ JA" or "✗ SAKNAS"), fireClick and C.good or C.bad)
    lbl(c3, "  getconnections:      " .. (getConns and "✓ JA" or "✗ SAKNAS"), getConns and C.good or C.bad)
    local hasHui = false; pcall(function() hasHui = gethui() ~= nil end)
    lbl(c3, "  gethui:              " .. (hasHui and "✓ JA" or "✗ SAKNAS (fallback aktiv)"), hasHui and C.good or C.warn)
    lbl(c3, "  task library:        " .. (task and "✓ JA" or "✗ SAKNAS (fallback aktiv)"), task and C.good or C.warn)
end)

-- ============================================================
--  KEYBIND
-- ============================================================
pcall(function()
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode[cfg.ui.keybind] then
            main.Visible = not main.Visible
        end
    end)
end)

-- ============================================================
--  KLART
-- ============================================================
notify("Venice Speed Suite v" .. VERSION .. " laddad! [" .. cfg.ui.keybind .. "]", 4)
print("[Venice] v" .. VERSION .. " loaded — all tabs OK")
