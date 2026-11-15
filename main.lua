--!nocheck
-- VeniceSpeedSuite v4.1  |  Bloxburg
-- Kör moped. En knapp.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")

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
    farmOn = false, farmSpeed = 45, mopedSpeed = 180,
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
    Text = "VENICE SUITE  v4.1", ZIndex = 21,
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

local function partOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then return inst:FindFirstChildWhichIsA("BasePart", true) end
    return nil
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
    if CFG.farmOn or not CFG.walkOn then return end
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
    if not (CFG.vehOn or CFG.farmOn) then return end
    local t = tick()
    if t - lastWrite < 0.25 then return end
    lastWrite = t
    pcall(function()
        seat.MaxSpeed = CFG.farmOn and CFG.mopedSpeed or CFG.vehMax
        seat.MaxTorque = math.huge
    end)
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
-- JOBB: ETT KORT, EN KNAPP
------------------------------------------------------------
local jobCard = card(pJob, "Autofarm – pizza (moped)", 196)

local farmBtn = mk("TextButton", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Color3.fromRGB(60, 110, 70),
    BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = Color3.fromRGB(230, 255, 235), Text = "AV",
    LayoutOrder = 2, AutoButtonColor = true, ZIndex = 7,
}, jobCard)

local statusLabel = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
    TextSize = 11, TextColor3 = Color3.fromRGB(210, 210, 220),
    TextXAlignment = Enum.TextXAlignment.Left, Text = "redo", LayoutOrder = 3, ZIndex = 7,
}, jobCard)

local diagLabel = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1, Font = Enum.Code,
    TextSize = 10, TextColor3 = Color3.fromRGB(150, 150, 165),
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, Text = "", LayoutOrder = 4, ZIndex = 7,
}, jobCard)

local status = function(t) statusLabel.Text = t end

------------------------------------------------------------
-- MOPED
------------------------------------------------------------
local function findMoped()
    local c = lp.Character
    if c then
        local m = c:FindFirstChild("Delivery Moped")
        if m then return m end
    end
    local r = root()
    if not r then return nil end
    local best, bestD = nil, 500
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("VehicleSeat") then
            local model = d:FindFirstAncestorOfClass("Model")
            local nm = model and model.Name or ""
            if nameHas(d, "moped", "delivery") or (nm ~= "" and nameHas(model, "moped", "delivery")) then
                local dist = (d.Position - r.Position).Magnitude
                if dist < bestD then best, bestD = d, dist end
            end
        end
    end
    return best
end

local function seatPart(moped)
    if not moped then return nil end
    if moped:IsA("VehicleSeat") then return moped end
    return moped:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function mounted()
    local h = hum()
    return h and h.SeatPart ~= nil
end

------------------------------------------------------------
-- PIZZA
------------------------------------------------------------
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

local FALLBACK_JOB = Vector3.new(1169, 15, 273)

local function jobPoint()
    local r = root()
    if not r then return nil end
    local best, bestD = nil, 400
    local cands = deepFind(workspace, function(i)
        return (i:IsA("BasePart") or i:IsA("Model"))
            and nameHas(i, "pizzaplanet", "conveyor", "movingboxes", "pizzabox", "workstation")
    end, 8)
    for _, c in ipairs(cands) do
        local p = partOf(c)
        if p then
            local d = (p.Position - r.Position).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best, bestD
end

local function isPlayerModel(m)
    return Players:GetPlayerFromCharacter(m) ~= nil
end

local function deliveryPoint(blacklist)
    local r = root()
    if not r then return nil end
    local scored = {}
    local function add(inst, score)
        local p = partOf(inst)
        if not p then return end
        if blacklist[inst] or (inst.Parent and blacklist[inst.Parent]) then return end
        local d = (p.Position - r.Position).Magnitude
        if d > 1400 then return end
        table.insert(scored, { pos = p.Position, s = score, d = d })
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        local okName = pcall(function() return d.Name end)
        if okName then
            if d:IsA("BasePart") then
                if nameHas(d, "arrow", "delivery", "marker", "waypoint", "pointer") then
                    add(d, 0)
                elseif (d.Color.R > 0.6 and d.Color.G > 0.5 and d.Color.B < 0.45)
                    and (d.Transparency > 0.15 or not d.CanCollide) then
                    add(d, 1)
                end
            elseif d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not isPlayerModel(d) then
                add(d, 2)
            elseif d:IsA("BillboardGui") and d.Parent and not isPlayerModel(d.Parent) then
                add(d.Parent, 3)
            end
        end
    end
    table.sort(scored, function(a, b)
        if a.s ~= b.s then return a.s < b.s end
        return a.d < b.d
    end)
    local top = scored[1]
    return top and top.pos, top and top.s
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
        task.wait(0.25)
    end
    return n
end

------------------------------------------------------------
-- KÖRNING
------------------------------------------------------------
local function mount()
    local h = hum()
    if not h then return false end
    if h.SeatPart then return true end
    local moped = findMoped()
    local seat = seatPart(moped)
    if not seat then return false end
    local r = root()
    if r and (seat.Position - r.Position).Magnitude > 10 then
        -- gå fram till mopeden
        local deadline = tick() + 20
        while tick() < deadline and CFG.farmOn do
            local rr = root()
            if not rr or (seat.Position - rr.Position).Magnitude < 9 then break end
            h:MoveTo(seat.Position)
            task.wait(0.15)
        end
    end
    pcall(function() seat:Sit(h) end)
    task.wait(0.5)
    return h.SeatPart ~= nil
end

local function dismount()
    local h = hum()
    if not h then return end
    pcall(function() h.Sit = false end)
    pcall(function() h.Jump = true end)
    task.wait(0.4)
end

-- Kör/går mot punkt. watch avbryter direkt.
local function driveTo(pos, timeout, watch)
    local deadline = tick() + (timeout or 60)
    local lastPos, lastAt = nil, tick()
    local backing = 0
    while tick() < deadline and CFG.farmOn and not S.dead do
        local r, h = root(), hum()
        if not r or not h then return false end
        if watch and watch() then return true end
        local d = (r.Position - pos).Magnitude
        if d < 11 then return true end
        h:MoveTo(pos)
        if tick() - lastAt > 1.8 then
            local moved = lastPos and (r.Position - lastPos).Magnitude or 99
            if moved < 4 then
                if backing < 2 then
                    backing = backing + 1
                    h:MoveTo(r.Position - (pos - r.Position).Unit * 14)
                    task.wait(0.5)
                else
                    backing = 0
                    h:MoveTo(pos + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12)))
                    if not mounted() then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            else
                backing = 0
            end
            lastPos, lastAt = r.Position, tick()
        end
        task.wait(0.12)
    end
    return false
end

------------------------------------------------------------
-- LOOPEN
------------------------------------------------------------
local farmTask = nil
local blacklist = {}

local function cycle()
    if not root() then return end

    -- Se till att sitta på mopeden
    if not mounted() then
        status("hämtar mopeden")
        diagLabel.Text = "fas: moped"
        if not mount() then
            status("ingen moped – går")
        end
    end

    if not heldBox() then
        status("kör till bandet")
        local point, dist = jobPoint()
        if not point then
            status("hittar inte bandet – kör mot fast punkt")
            point = FALLBACK_JOB
            dist = 9999
        end
        diagLabel.Text = "fas: hämta\ntransport: " .. (mounted() and "moped" or "gång")

        if dist > 11 then driveTo(point, 70) end
        if not CFG.farmOn then return end

        if mounted() then dismount() end
        status("tar pizza")
        for _ = 1, 8 do
            interactUI()
            task.wait(0.6)
            if heldBox() then break end
        end
        if not heldBox() then
            status("fick ingen pizza")
            task.wait(2)
            return
        end
        mount()
    end

    status("letar efter kund")
    local tries = 0
    while heldBox() and tries < 4 and CFG.farmOn and not S.dead do
        tries = tries + 1
        local target, score = deliveryPoint(blacklist)
        if not target then
            status("hittar ingen kund")
            task.wait(1.5)
        else
            local names = { "pil", "gul markering", "npc", "skylt" }
            status("kör mot " .. (names[score + 1] or "mål"))
            diagLabel.Text = "fas: leverera\nmetod: " .. (names[score + 1] or "?") .. "\nförsök: " .. tries
            driveTo(target, 80, function() return heldBox() == nil end)

            if heldBox() then
                dismount()
                for _ = 1, 5 do
                    interactUI()
                    task.wait(0.6)
                    if not heldBox() then break end
                end
                if heldBox() then
                    mount()
                    status("lämnade inte – försöker igen")
                    task.wait(1)
                end
            end
        end
    end

    if not heldBox() then
        status("levererad")
        blacklist = {}
    else
        status("gav upp leveransen")
    end
    diagLabel.Text = "fas: klar"
end

local function startFarm()
    if farmTask then return end
    farmTask = task.spawn(function()
        while CFG.farmOn and not S.dead do
            local ok, err = pcall(cycle)
            if not ok then
                status("fel")
                diagLabel.Text = "fel: " .. tostring(err)
            end
            for _ = 1, 2 do
                if not CFG.farmOn or S.dead then break end
                task.wait(1)
            end
        end
        farmTask = nil
        status("redo")
        diagLabel.Text = ""
        local h = hum()
        if h then h.WalkSpeed = CFG.walk end
    end)
end

bind(farmBtn, function()
    CFG.farmOn = not CFG.farmOn
    if CFG.farmOn then
        farmBtn.Text = "PÅ"
        farmBtn.BackgroundColor3 = Color3.fromRGB(120, 45, 60)
        local h = hum()
        if h then h.WalkSpeed = CFG.farmSpeed end
        status("startar")
        startFarm()
    else
        farmBtn.Text = "AV"
        farmBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 70)
        status("stoppad")
        local h = hum()
        if h then h.WalkSpeed = CFG.walk end
    end
    saveCfg()
end)

------------------------------------------------------------
-- START
------------------------------------------------------------
lp.CharacterAdded:Connect(function()
    task.wait(1)
    applyWalk()
end)
