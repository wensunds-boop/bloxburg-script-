--!nocheck
-- VeniceSpeedSuite v3.8  |  Bloxburg
-- Karaktärsstyrd leverans: följer den gula pilen.

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local VirtualUser        = game:GetService("VirtualUser")
local StarterGui         = game:GetService("StarterGui")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
if not lp then return end
local pg = lp:WaitForChild("PlayerGui")

local G = getgenv()
G.VeniceSuite = G.VeniceSuite or {}
local S = G.VeniceSuite
S.dead = false

local stale = pg:FindFirstChild("VeniceSuite")
if stale then stale:Destroy() end

local function gfn(name)
    local f = rawget(G, name)
    if type(f) == "function" then return f end
    local ok, r = pcall(function() return _G[name] end)
    if ok and type(r) == "function" then return r end
    return nil
end
local function bind(btn, fn)
    local last = 0
    local function run()
        local t = tick()
        if t - last < 0.15 then return end
        last = t
        local ok, err = pcall(fn)
        if not ok then warn("[Venice] " .. tostring(err)) end
    end
    btn.MouseButton1Down:Connect(run)
    btn.Activated:Connect(run)
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then run() end
    end)
end

------------------------------------------------------------
-- KONFIG
------------------------------------------------------------
local CFG = {
    walk = 32, walkOn = true,
    vehMax = 220, vehOn = false,
    zoneLimit = 60, zoneOn = false,
    farmOn = false, farmSpeed = 42,
}

local function saveCfg()
    if not writefile then return end
    pcall(function() writefile("VeniceSpeedSuite.json", HttpService:JSONEncode(CFG)) end)
end
if isfile and readfile then
    pcall(function()
        if isfile("VeniceSpeedSuite.json") then
            local d = HttpService:JSONDecode(readfile("VeniceSpeedSuite.json"))
            for k, v in pairs(d) do if CFG[k] ~= nil then CFG[k] = v end end
        end
    end)
end

------------------------------------------------------------
-- BYGGHJÄLP
------------------------------------------------------------
local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then i[k] = v end
    end
    i.Parent = parent or props.Parent
    return i
end

local gui = mk("ScreenGui", {
    Name = "VeniceSuite", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, pg)

local win = mk("Frame", {
    Size = UDim2.fromOffset(400, 470),
    Position = UDim2.new(0.5, -200, 0.5, -235),
    BackgroundColor3 = Color3.fromRGB(18, 18, 21),
    BorderSizePixel = 0, Active = true, ZIndex = 1,
}, gui)

local top = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.fromRGB(24, 24, 28),
    BorderSizePixel = 0, Active = true, ZIndex = 20,
}, win)

local body = mk("Frame", {
    Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46),
    BackgroundTransparency = 1, ZIndex = 1,
}, win)

mk("Frame", {
    Size = UDim2.fromOffset(4, 46), BackgroundColor3 = Color3.fromRGB(120, 90, 255),
    BorderSizePixel = 0, ZIndex = 21,
}, top)

mk("TextLabel", {
    Size = UDim2.new(1, -180, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
    TextColor3 = Color3.fromRGB(235, 235, 240), TextXAlignment = Enum.TextXAlignment.Left,
    Text = "VENICE SUITE  v3.8", ZIndex = 21,
}, top)

local activeLabel = mk("TextLabel", {
    Size = UDim2.new(1, -180, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = Color3.fromRGB(140, 120, 240), TextXAlignment = Enum.TextXAlignment.Right,
    Text = "", ZIndex = 21,
}, top)

local minBtn = mk("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0, 8),
    BackgroundColor3 = Color3.fromRGB(38, 38, 44), BorderSizePixel = 0,
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 210),
    Text = "–", AutoButtonColor = true, ZIndex = 22,
}, top)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(38, 38, 44), BorderSizePixel = 0,
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 210),
    Text = "X", AutoButtonColor = true, ZIndex = 22,
}, top)

local tabBar = mk("Frame", {
    Size = UDim2.fromOffset(380, 30), Position = UDim2.fromOffset(10, 52),
    BackgroundTransparency = 1, Active = true, ZIndex = 15,
}, win)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

local tabs, pages, pageCards = {}, {}, {}
local order = 0

local function addTab(name)
    order = order + 1
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(68, 28), BackgroundColor3 = Color3.fromRGB(28, 28, 33),
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(170, 170, 180), Text = name, LayoutOrder = order,
        AutoButtonColor = true, ZIndex = 16,
    }, tabBar)

    local p = mk("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -92), Position = UDim2.fromOffset(10, 88),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80),
        CanvasSize = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 5,
    }, win)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)

    tabs[name] = b; pages[name] = p; pageCards[p] = {}

    bind(b, function()
        for n, bb in pairs(tabs) do
            local on = (n == name)
            bb.BackgroundColor3 = on and Color3.fromRGB(45, 38, 70) or Color3.fromRGB(28, 28, 33)
            bb.TextColor3 = on and Color3.fromRGB(210, 200, 255) or Color3.fromRGB(170, 170, 180)
            pages[n].Visible = on
        end
        activeLabel.Text = name
    end)
    return p
end

local function recalc(page)
    local total = 0
    for _, h in pairs(pageCards[page]) do total = total + h + 8 end
    page.CanvasSize = UDim2.fromOffset(0, total + 14)
end

local cardOrder = 0
local function card(page, title, height)
    cardOrder = cardOrder + 1
    local c = mk("Frame", {
        Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = Color3.fromRGB(25, 25, 30),
        BorderSizePixel = 0, LayoutOrder = cardOrder, ZIndex = 6,
    }, page)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, c)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = Color3.fromRGB(150, 130, 255),
        TextXAlignment = Enum.TextXAlignment.Left, Text = title, LayoutOrder = 1, ZIndex = 7,
    }, c)
    pageCards[page][c] = height
    recalc(page)
    return c
end

local function slider(page, label, min, max, def, cb)
    local c = card(page, label, 78)
    local val = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = Color3.fromRGB(200, 200, 210),
        TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(def), LayoutOrder = 2, ZIndex = 7,
    }, c)
    local bar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(40, 40, 48),
        BorderSizePixel = 0, Active = true, LayoutOrder = 3, ZIndex = 7,
    }, c)
    local fill = mk("Frame", {
        Size = UDim2.fromScale((def - min) / (max - min), 1),
        BackgroundColor3 = Color3.fromRGB(120, 90, 255), BorderSizePixel = 0, ZIndex = 8,
    }, bar)
    local dragging = false
    local function set(v)
        v = math.clamp(v, min, max)
        fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
        val.Text = tostring(math.floor(v))
        cb(v)
    end
    local function fromX(x)
        set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1))
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromX(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    set(def)
    return c
end

local function toggle(page, label, def, cb)
    local c = card(page, label, 66)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = def and Color3.fromRGB(70, 55, 140) or Color3.fromRGB(38, 38, 45),
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(230, 230, 235), Text = def and "PÅ" or "AV",
        LayoutOrder = 2, AutoButtonColor = true, ZIndex = 7,
    }, c)
    local state = def
    bind(b, function()
        state = not state
        b.Text = state and "PÅ" or "AV"
        b.BackgroundColor3 = state and Color3.fromRGB(70, 55, 140) or Color3.fromRGB(38, 38, 45)
        cb(state); saveCfg()
    end)
    return b
end

local function button(page, label, text, color, cb, h)
    local c = card(page, label, h or 66)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = color, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(235, 235, 240),
        Text = text, LayoutOrder = 2, AutoButtonColor = true, ZIndex = 7,
    }, c)
    bind(b, cb)
    return b
end

local function readout(page, label, text)
    local c = card(page, label, 52)
    local l = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = Color3.fromRGB(160, 160, 170),
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = 2, ZIndex = 7,
    }, c)
    return l, c
end

------------------------------------------------------------
-- DRAG / MINIMERA
------------------------------------------------------------
local dragOff, dragging
top.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragOff = win.AbsolutePosition - UserInputService:GetMouseLocation()
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local m = UserInputService:GetMouseLocation()
        local vp = workspace.CurrentCamera.ViewportSize
        win.Position = UDim2.fromOffset(
            math.clamp(m.X + dragOff.X, 0, math.max(0, vp.X - win.AbsoluteSize.X)),
            math.clamp(m.Y + dragOff.Y, 0, math.max(0, vp.Y - win.AbsoluteSize.Y))
        )
    end
end)

local minimized = false
bind(minBtn, function()
    minimized = not minimized
    body.Visible = not minimized
    tabBar.Visible = not minimized
    win.Size = UDim2.fromOffset(400, minimized and 46 or 470)
    minBtn.Text = minimized and "+" or "–"
end)
bind(closeBtn, function() S.dead = true; gui:Destroy() end)

------------------------------------------------------------
-- FLIKAR
------------------------------------------------------------
local pPlayer = addTab("Player")
local pVeh    = addTab("Fordon")
local pZone   = addTab("Zoner")
local pPlr    = addTab("Spelare")
local pJob    = addTab("Jobb")
activeLabel.Text = "Player"
pages.Player.Visible = true
tabs.Player.BackgroundColor3 = Color3.fromRGB(45, 38, 70)

------------------------------------------------------------
-- SÖKHJÄLP
------------------------------------------------------------
local function nameHas(inst, ...)
    local ok, n = pcall(function() return inst.Name:lower() end)
    if not ok or not n then return false end
    for _, s in ipairs({ ... }) do if n:find(s, 1, true) then return true end end
    return false
end

local function deepFind(from, pred, maxDepth)
    local out = {}
    local function rec(inst, d)
        if d > (maxDepth or 6) then return end
        local ok, kids = pcall(function() return inst:GetChildren() end)
        if not ok then return end
        for _, c in ipairs(kids) do
            if pcall(pred, c) then table.insert(out, c) end
            rec(c, d + 1)
        end
    end
    rec(from, 0)
    return out
end

------------------------------------------------------------
-- KARAKTÄR
------------------------------------------------------------
local function char()
    local c = lp.Character
    if c and c:FindFirstChildOfClass("Humanoid") then return c end
    return nil
end
local function root()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end
local function applyWalk()
    local h = hum()
    if h and CFG.walkOn then h.WalkSpeed = CFG.walk end
end

RunService.Heartbeat:Connect(function()
    if CFG.farmOn then return end
    if not CFG.walkOn then return end
    local h = hum()
    if h and math.abs(h.WalkSpeed - CFG.walk) > 0.6 then h.WalkSpeed = CFG.walk end
end)

slider(pPlayer, "Gånghastighet", 16, 200, CFG.walk, function(v) CFG.walk = v; applyWalk(); saveCfg() end)
toggle(pPlayer, "Gånghastighet på", CFG.walkOn, function(v) CFG.walkOn = v; applyWalk() end)

------------------------------------------------------------
-- FORDON
------------------------------------------------------------
local vehLabel = readout(pVeh, "Status", "Inget fordon")
local seatCache, seatScanAt = nil, 0

local function getSeat()
    local c = lp.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h and h.SeatPart then return h.SeatPart end
    local s = c:FindFirstChildWhichIsA("VehicleSeat", true)
    if s then return s end
    if h and tick() - seatScanAt > 0.6 then
        seatScanAt = tick()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("VehicleSeat") and d.Occupant == h then
                seatCache = d
                return d
            end
        end
        seatCache = nil
    end
    if seatCache and seatCache.Parent and seatCache.Occupant == h then return seatCache end
    return nil
end

local lastWrite = 0
RunService.Heartbeat:Connect(function()
    local seat = getSeat()
    if not seat then
        if vehLabel.Text ~= "Inget fordon" then vehLabel.Text = "Inget fordon" end
        return
    end
    if vehLabel.Text ~= "Fordon: " .. seat.Name then vehLabel.Text = "Fordon: " .. seat.Name end
    if not CFG.vehOn then return end
    local t = tick()
    if t - lastWrite < 0.25 then return end
    lastWrite = t
    pcall(function() seat.MaxSpeed = CFG.vehMax; seat.MaxTorque = math.huge end)
end)

slider(pVeh, "Maxhastighet fordon", 50, 600, CFG.vehMax, function(v) CFG.vehMax = v; saveCfg() end)
toggle(pVeh, "Fordonsboost på", CFG.vehOn, function(v) CFG.vehOn = v end)

------------------------------------------------------------
-- ZONER
------------------------------------------------------------
local zoneLabel = readout(pZone, "Status", "Ingen zon")
local zoneCountLabel = readout(pZone, "Antal", "0 zoner")
local zones = {}

RunService.Heartbeat:Connect(function()
    if not CFG.zoneOn then return end
    local r = root()
    if not r then return end
    for _, z in pairs(zones) do
        if z.part and z.part.Parent then
            local rel = z.part.CFrame:PointToObjectSpace(r.Position)
            local half = z.part.Size / 2
            if math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z then
                local h = hum()
                if h then h.WalkSpeed = math.min(CFG.walk, z.limit) end
                zoneLabel.Text = "Zon: " .. z.limit
                return
            end
        end
    end
    zoneLabel.Text = "Ingen zon"
end)

local zoneId = 0
button(pZone, "Skapa", "Lägg zon här", Color3.fromRGB(50, 42, 95), function()
    local r = root()
    if not r then return end
    zoneId = zoneId + 1
    local p = Instance.new("Part")
    p.Name = "VeniceZone" .. zoneId
    p.Size = Vector3.new(60, 40, 60)
    p.CFrame = r.CFrame
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 0.85
    p.Color = Color3.fromRGB(120, 90, 255)
    p.Parent = workspace
    zones[zoneId] = { part = p, limit = CFG.zoneLimit }
    local n = 0
    for _ in pairs(zones) do n = n + 1 end
    zoneCountLabel.Text = n .. " zoner"
end)

slider(pZone, "Zonhastighet", 16, 120, CFG.zoneLimit, function(v) CFG.zoneLimit = v; saveCfg() end)
toggle(pZone, "Zoner på", CFG.zoneOn, function(v) CFG.zoneOn = v end)

------------------------------------------------------------
-- SPELARE
------------------------------------------------------------
local plrCard = card(pPlr, "Server", 60)
local plrList = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 7 }, plrCard)
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, plrList)

local selected = {}
local function refreshPlayers()
    for _, c in ipairs(plrList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local i = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp then
            i = i + 1
            local b = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = selected[pl] and Color3.fromRGB(70, 55, 140) or Color3.fromRGB(34, 34, 40),
                BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11,
                TextColor3 = Color3.fromRGB(215, 215, 220), TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. pl.Name, LayoutOrder = i, AutoButtonColor = true, ZIndex = 8,
            }, plrList)
            bind(b, function()
                selected[pl] = not selected[pl] and true or nil
                refreshPlayers()
            end)
        end
    end
    plrList.Size = UDim2.new(1, 0, 0, i * 28)
    pageCards[pPlr][plrCard] = 44 + i * 28
    plrCard.Size = UDim2.new(1, -8, 0, 44 + i * 28)
    recalc(pPlr)
end

button(pPlr, "Åtgärd", "Kicka valda", Color3.fromRGB(120, 45, 60), function()
    for pl in pairs(selected) do
        if pl.Parent then pcall(function() pl:Kick("Venice Suite") end) end
    end
    selected = {}
    task.delay(0.3, refreshPlayers)
end)

Players.PlayerAdded:Connect(function() task.wait(0.5) refreshPlayers() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2) refreshPlayers() end)
task.spawn(refreshPlayers)

------------------------------------------------------------
-- DIAGNOSTIK
------------------------------------------------------------
local diagLabel = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 118), BackgroundTransparency = 1, Font = Enum.Font.Code,
    TextSize = 10, TextColor3 = Color3.fromRGB(180, 180, 195),
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, Text = "väntar...", LayoutOrder = 2, ZIndex = 7,
}, card(pJob, "Diagnostik", 152))

local diag = {}
local function diagDraw()
    diagLabel.Text = table.concat({
        "pil: " .. tostring(diag.arrow or "ingen"),
        "pilavst: " .. tostring(diag.arrowDist or "-"),
        "fas: " .. tostring(diag.phase or "-"),
        "pizza i hand: " .. tostring(diag.held and "ja" or "nej"),
        "pizzaplanet: " .. tostring(diag.pp or "-"),
        "conveyor: " .. tostring(diag.conv or "-"),
        "fel: " .. tostring(diag.err or "-"),
    }, "\n")
end

local statusLabel = readout(pJob, "Status", "redo")
local function status(t) statusLabel.Text = t end

------------------------------------------------------------
-- PIZZAPLANET
------------------------------------------------------------
local function pizzaPlanet()
    local direct = workspace:FindFirstChild("PizzaPlanet")
    if direct then return direct end
    return deepFind(workspace, function(i) return nameHas(i, "pizzaplanet") end, 6)[1]
end

local function conveyor()
    local pp = pizzaPlanet()
    if pp then
        local mb = deepFind(pp, function(i) return i.Name == "MovingBoxes" end, 7)[1]
        if mb then return mb end
        local c = deepFind(pp, function(i) return nameHas(i, "conveyor") end, 7)[1]
        if c then return c end
    end
    return deepFind(workspace, function(i) return i.Name == "MovingBoxes" end, 7)[1]
end

local function heldBox()
    local c = lp.Character
    if not c then return nil end
    local b = c:FindFirstChild("Pizza Box")
    if b then return b end
    for _, d in ipairs(c:GetChildren()) do
        if d:IsA("Tool") and nameHas(d, "pizza") then return d end
    end
    return nil
end

------------------------------------------------------------
-- PILEN
------------------------------------------------------------
local arrowCache, arrowAt = nil, 0

local function isYellow(part)
    local c = part.Color
    return c.R > 0.6 and c.G > 0.5 and c.B < 0.45
end

local function findArrow()
    local r = root()
    if not r then return nil end
    if tick() - arrowAt < 0.3 and arrowCache and arrowCache.Parent then return arrowCache end
    arrowAt = tick()

    local cands = deepFind(workspace, function(i)
        if i:IsA("BasePart") then
            if nameHas(i, "arrow", "delivery", "marker", "waypoint", "pointer", "indicator") then return true end
            if isYellow(i) and (i.Transparency > 0.15 or not i.CanCollide) then return true end
        elseif i:IsA("Beam") or i:IsA("BillboardGui") or i:IsA("Trail") then
            if nameHas(i, "arrow", "delivery", "marker") then return true end
        end
        return false
    end, 8)

    local best, bestD = nil, 800
    for _, c in ipairs(cands) do
        local pos
        if c:IsA("BasePart") then pos = c.Position
        elseif c:IsA("Model") then
            local p = c:FindFirstChildWhichIsA("BasePart", true)
            pos = p and p.Position
        end
        if pos then
            local d = (pos - r.Position).Magnitude
            if d < bestD then best, bestD = c, d end
        end
    end
    arrowCache = best
    return best
end

local function arrowPos(a)
    if not a then return nil end
    if a:IsA("BasePart") then return a.Position end
    local p = a:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

------------------------------------------------------------
-- INTERAKTION
------------------------------------------------------------
local function fireButton(btn)
    if not btn or not btn:IsA("GuiButton") or not btn.Visible then return false end
    local gc = gfn("getconnections")
    if gc then
        local ok, conns = pcall(gc, btn.Activated)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if pcall(function() c:Fire() end) then return true end
            end
        end
    end
    local fs = gfn("firesignal")
    if fs then
        if pcall(fs, btn.Activated) then return true end
    end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    return pcall(function()
        VirtualUser:Button1Down(Vector2.new(pos.X, pos.Y), cam.CFrame)
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(pos.X, pos.Y), cam.CFrame)
    end)
end

local function interactUI()
    local ui = pg:FindFirstChild("_interactUI")
    if not ui then return 0 end
    local btns = {}
    for _, d in ipairs(ui:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then table.insert(btns, d) end
    end
    local n = 0
    for _, b in ipairs(btns) do
        if fireButton(b) then n = n + 1 end
        task.wait(0.3)
    end
    return n
end

------------------------------------------------------------
-- STYRNING
------------------------------------------------------------
local function steer(target, jump)
    local h = hum()
    if not h then return end
    h:MoveTo(target)
    if jump then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end

local function walkToPoint(pos, timeout)
    local r = root()
    if not r or not pos then return false end
    local deadline = tick() + (timeout or 30)
    local lastPos, lastAt = r.Position, tick()
    while tick() < deadline and CFG.farmOn do
        local rr = root()
        if not rr then return false end
        if (rr.Position - pos).Magnitude < 8 then return true end
        steer(pos, false)
        if tick() - lastAt > 1.5 then
            if (rr.Position - lastPos).Magnitude < 3 then
                steer(pos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)), true)
            end
            lastPos, lastAt = rr.Position, tick()
        end
        task.wait(0.12)
    end
    return false
end

-- Följer pilen. Returnerar true när pizzan lämnats.
local function followArrow(timeout)
    local deadline = tick() + (timeout or 75)
    local lastPos, lastAt = nil, tick()
    local nextTry = 0

    while tick() < deadline and CFG.farmOn and not S.dead do
        if not heldBox() then return true end

        local a = findArrow()
        local r, h = root(), hum()
        if not r or not h then return false end
        if not a then
            diag.arrow = "ingen"
            diag.arrowDist = "-"
            diagDraw()
            return false
        end

        local ap = arrowPos(a)
        if not ap then return false end
        local dist = (ap - r.Position).Magnitude
        diag.arrow = a.Name .. " [" .. a.ClassName .. "]"
        diag.arrowDist = math.floor(dist)
        diagDraw()

        local target
        if dist > 30 then
            target = ap
        else
            local okLv, lv = pcall(function() return a.CFrame.LookVector end)
            if okLv and lv and lv.Magnitude > 0.1 then
                target = r.Position + lv.Unit * 35
            else
                target = ap
            end
            if tick() > nextTry then
                nextTry = tick() + 1.4
                interactUI()
                if not heldBox() then return true end
            end
        end

        steer(target, false)

        if tick() - lastAt > 1.6 then
            if lastPos and (r.Position - lastPos).Magnitude < 3 then
                steer(target + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)), true)
            end
            lastPos, lastAt = r.Position, tick()
        end

        task.wait(0.14)
    end
    return false
end

------------------------------------------------------------
-- FARM
------------------------------------------------------------
local farmRun = false
local function farmLoop()
    if farmRun then return end
    farmRun = true

    local savedWalk = CFG.walk
    local h0 = hum()
    if h0 then h0.WalkSpeed = CFG.farmSpeed end

    task.spawn(function()
        while CFG.farmOn and not S.dead do
            local ok, err = pcall(function()
                local hh = hum()
                if hh then hh.WalkSpeed = CFG.farmSpeed end

                diag.held = heldBox() ~= nil
                diag.err = "-"
                diagDraw()

                -- Ta bort mopeden så karaktären går fritt
                local c = lp.Character
                local moped = c and c:FindFirstChild("Delivery Moped")
                if moped then pcall(function() moped:Destroy() end) end

                if not heldBox() then
                    diag.phase = "till bandet"
                    local mb = conveyor()
                    local pp = pizzaPlanet()
                    local targetPart = (mb and mb:FindFirstChildWhichIsA("BasePart", true))
                        or (pp and pp:FindFirstChildWhichIsA("BasePart", true))
                    diag.conv = mb and mb:GetFullName() or "saknas"
                    diag.pp = pp and "finns" or "saknas"
                    diagDraw()

                    if targetPart then
                        local r = root()
                        if r and (targetPart.Position - r.Position).Magnitude > 12 then
                            status("går till bandet")
                            walkToPoint(targetPart.Position, 40)
                        end
                    end

                    status("tar pizza")
                    interactUI()
                    task.wait(1.2)
                    diag.held = heldBox() ~= nil
                    diagDraw()
                    if not heldBox() then
                        diag.err = "fick ingen pizza"
                        task.wait(2)
                        return
                    end
                end

                diag.phase = "följer pil"
                diagDraw()
                status("följer pilen")

                local delivered = followArrow(75)
                diag.held = heldBox() ~= nil
                diag.phase = delivered and "klar" or "misslyckad"
                diagDraw()

                if delivered then
                    status("levererad")
                    task.wait(1)
                else
                    status("leverans misslyckad")
                    if heldBox() then
                        interactUI()
                        task.wait(1)
                    end
                end
            end)
            if not ok then diag.err = tostring(err) end
            diagDraw()
            for _ = 1, 3 do
                if not CFG.farmOn or S.dead then break end
                task.wait(1)
            end
        end
        farmRun = false
        status("farm stoppad")
        local h = hum()
        if h then h.WalkSpeed = savedWalk end
    end)
end

------------------------------------------------------------
-- SKANNER
------------------------------------------------------------
local scanBox = mk("TextBox", {
    Size = UDim2.new(1, 0, 0, 260),
    BackgroundColor3 = Color3.fromRGB(14, 14, 17), BorderSizePixel = 0,
    Font = Enum.Font.Code, TextSize = 10, TextColor3 = Color3.fromRGB(190, 190, 205),
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, ClearTextOnFocus = false, TextEditable = true, MultiLine = true,
    Text = "tryck Skanna pil", LayoutOrder = 2, ZIndex = 7,
}, card(pJob, "Pilrapport", 300))

local function scanArrow()
    local out = {}
    local a = findArrow()
    if not a then
        scanBox.Text = "ingen pil hittad. Ta en pizza först — pilen syns bara med pizza i hand."
        return
    end
    table.insert(out, "vald pil: " .. a:GetFullName())
    table.insert(out, "klass: " .. a.ClassName)
    table.insert(out, "avstånd: " .. math.floor((arrowPos(a) - root().Position).Magnitude))
    if a:IsA("BasePart") then
        table.insert(out, "färg: " .. tostring(a.Color))
        table.insert(out, "transparens: " .. a.Transparency)
        table.insert(out, "CanCollide: " .. tostring(a.CanCollide))
    end
    table.insert(out, "")
    table.insert(out, "alla kandidater:")
    local cands = deepFind(workspace, function(i)
        return i:IsA("BasePart") and (nameHas(i, "arrow", "delivery", "marker") or isYellow(i))
    end, 8)
    for i = 1, math.min(#cands, 25) do
        table.insert(out, "  " .. cands[i]:GetFullName() .. " [" .. cands[i].ClassName .. "]")
    end
    scanBox.Text = table.concat(out, "\n")
end

------------------------------------------------------------
-- KNAPPAR
------------------------------------------------------------
button(pJob, "Kontroll", "Starta farm", Color3.fromRGB(60, 110, 70), function()
    CFG.farmOn = true
    status("startar")
    farmLoop()
end)
button(pJob, "Kontroll", "Stoppa", Color3.fromRGB(110, 55, 55), function()
    CFG.farmOn = false
    status("stoppad")
end)
button(pJob, "Test", "Skanna pil", Color3.fromRGB(50, 42, 95), function()
    scanArrow()
    diagDraw()
end)
button(pJob, "Test", "Följ pil 20s", Color3.fromRGB(50, 50, 60), function()
    CFG.farmOn = true
    local h = hum()
    if h then h.WalkSpeed = CFG.farmSpeed end
    task.spawn(function()
        status("följer pilen (test)")
        local ok = followArrow(20)
        CFG.farmOn = false
        status(ok and "levererad" or "test klar")
        local hh = hum()
        if hh then hh.WalkSpeed = CFG.walk end
    end)
end)
slider(pJob, "Farmhastighet", 20, 90, CFG.farmSpeed, function(v) CFG.farmSpeed = v; saveCfg() end)

------------------------------------------------------------
-- START
------------------------------------------------------------
task.spawn(function()
    task.wait(0.4)
    diag.pp = pizzaPlanet() and "finns" or "saknas"
    diag.conv = conveyor() and "finns" or "saknas"
    diag.held = false
    diagDraw()
    status("redo")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Venice Suite v3.8",
            Text = "PizzaPlanet: " .. tostring(diag.pp) .. " | Conveyor: " .. tostring(diag.conv),
            Duration = 4,
        })
    end)
end)

lp.CharacterAdded:Connect(function()
    task.wait(1)
    applyWalk()
end)
