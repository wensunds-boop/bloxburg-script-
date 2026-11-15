--!nocheck
-- VeniceSpeedSuite v3.6  |  Bloxburg
-- Leverans via DataFunction/DataEvent + PathfindingService (anti-teleport-vänlig).

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local StarterGui        = game:GetService("StarterGui")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
if not lp then return end
local pg = lp:WaitForChild("PlayerGui")

local G = getgenv()
G.VeniceSuite = G.VeniceSuite or {}
local S = G.VeniceSuite
S.dead = false

local stale = pg:FindFirstChild("VeniceSuite")
if stale then stale:Destroy() end

local function nc(f)
    local n = rawget(G, "newcclosure") or newcclosure
    if type(n) == "function" then local ok, r = pcall(n, f); if ok then return r end end
    return f
end
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
    farmOn = false, autoDeliver = true, walkMode = true,
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
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Color3.fromRGB(24, 24, 28),
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
    Text = "VENICE SUITE  v3.6", ZIndex = 21,
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

local function getSeat()
    local c = lp.Character
    if not c then return nil end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("VehicleSeat") then return d end
    end
    local h = c:FindFirstChildOfClass("Humanoid")
    local s = h and h.SeatPart
    if s and s:IsA("VehicleSeat") then return s end
    for _, d in ipairs(c:GetChildren()) do
        if d.Name:sub(1, 8) == "Vehicle_" then
            local s2 = d:FindFirstChildOfClass("VehicleSeat")
            if s2 then return s2 end
        end
    end
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
        "remotes: " .. tostring(diag.remotes or "-"),
        "conveyor: " .. tostring(diag.conveyor or "-"),
        "box: " .. tostring(diag.box or 0),
        "kund: " .. tostring(diag.cust or "-"),
        "metod: " .. tostring(diag.mode or "-"),
        "jobb: " .. tostring(diag.job or "saknas"),
        "fel: " .. tostring(diag.err or "-"),
    }, "\n")
end

local statusLabel = readout(pJob, "Status", "redo")
local function status(t) statusLabel.Text = t end

------------------------------------------------------------
-- SPELLAGER
------------------------------------------------------------
local blox = { takeFn = nil, deliverEv = {}, uiMode = "none" }

local function pizzaPlanet()
    return workspace:FindFirstChild("PizzaPlanet")
end

local function conveyor()
    local pp = pizzaPlanet()
    if not pp then return nil end
    local c = pp:FindFirstChild("Conveyor")
    if not c then
        for _, d in ipairs(pp:GetDescendants()) do
            if d.Name == "MovingBoxes" then return d end
        end
        return nil
    end
    return c:FindFirstChild("MovingBoxes") or c
end

local function boxCount()
    local mb = conveyor()
    if not mb then return 0 end
    local n = 0
    for _, d in ipairs(mb:GetChildren()) do
        if d:IsA("Model") or d:IsA("BasePart") then n = n + 1 end
    end
    return n
end

local function heldBox()
    local c = lp.Character
    if not c then return nil end
    local b = c:FindFirstChild("Pizza Box")
    if b then return b end
    for _, d in ipairs(c:GetChildren()) do
        if d:IsA("Tool") and d.Name:lower():find("pizza") then return d end
    end
    return nil
end

local function scanRemotes()
    local fn, ev = {}, {}
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteFunction") then table.insert(fn, d)
        elseif d:IsA("RemoteEvent") then table.insert(ev, d) end
    end
    local function score(x)
        local n = x.Name:lower()
        if n == "datafunction" then return 0 end
        if n == "dataevent" then return 0 end
        if n:find("data") then return 1 end
        if n:find("job") or n:find("pizza") or n:find("item") then return 2 end
        return 3
    end
    table.sort(fn, function(a, b) return score(a) < score(b) end)
    table.sort(ev, function(a, b) return score(a) < score(b) end)
    blox.takeFn = fn[1]
    blox.deliverEv = ev
    diag.remotes = #fn .. "/" .. #ev
end

-- Ta box via remote
local function takeBoxViaRemote(box)
    local fns = {}
    if blox.takeFn then table.insert(fns, blox.takeFn) end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteFunction") and d ~= blox.takeFn then table.insert(fns, d) end
    end
    for _, f in ipairs(fns) do
        for _, arg in ipairs({ { Type = "TakePizzaBox", Box = box }, { "TakePizzaBox", box } }) do
            local ok, res = pcall(function() return f:InvokeServer(arg) end)
            if ok and typeof(res) == "Instance" then
                blox.uiMode = "remote:" .. f.Name
                return res
            end
            task.wait(0.1)
        end
    end
    return nil
end

local function deliverViaRemote(customer)
    local sent = false
    for _, ev in ipairs(blox.deliverEv) do
        if pcall(function() ev:FireServer({ Type = "DeliverPizza", Customer = customer }) end) then sent = true end
    end
    if sent then blox.uiMode = "remote" end
    return sent
end

local function dropLeftover()
    local b = heldBox()
    if not b then return end
    for _, ev in ipairs(blox.deliverEv) do
        pcall(function() ev:FireServer({ Item = b, Type = "UnequipItem" }) end)
    end
end

-- UI-reserv
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

-- Gångväg
local function walkTo(pos, timeout)
    local h, r = hum(), root()
    if not h or not r or not pos then return false end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6,
    })
    local ok = pcall(function() path:ComputeAsync(r.Position, pos) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        h:MoveTo(pos)
        task.wait(1)
        return false
    end
    local deadline = tick() + (timeout or 25)
    for _, wp in ipairs(path:GetWaypoints()) do
        if tick() > deadline then break end
        if wp.Action == Enum.PathWaypointAction.Jump then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
        h:MoveTo(wp.Position)
        repeat
            task.wait(0.1)
        until (r.Position - wp.Position).Magnitude < 5 or tick() > deadline
    end
    return true
end

local function tp(target, steps)
    local r = root()
    if not r or not target then return end
    steps = steps or 5
    local start = r.Position
    for i = 1, steps do
        local dest = start:Lerp(target, i / steps)
        pcall(function() r.CFrame = CFrame.new(dest + Vector3.new(0, 3, 0)) end)
        task.wait(0.06)
    end
    pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
end

local function goTo(pos, timeout)
    if CFG.walkMode then
        local ok = walkTo(pos, timeout)
        if not ok and root() then tp(pos, 4) end
    else
        tp(pos, 4)
    end
end

local function removeMoped()
    local c = lp.Character
    if not c then return end
    local m = c:FindFirstChild("Delivery Moped")
    if m then pcall(function() m:Destroy() end) end
    local pp = pizzaPlanet()
    local ring = pp and pp:FindFirstChild("Ring")
    if ring then pcall(function() ring:Destroy() end) end
end

local function atJob()
    local pp, r = pizzaPlanet(), root()
    if not pp or not r then return false end
    local p = pp:FindFirstChildWhichIsA("BasePart", true)
    if not p then return false end
    return (p.Position - r.Position).Magnitude < 70
end

------------------------------------------------------------
-- FARM
------------------------------------------------------------
local farmRun = false
local function farmLoop()
    if farmRun then return end
    farmRun = true
    task.spawn(function()
        while CFG.farmOn and not S.dead do
            local ok, err = pcall(function()
                diag.box = boxCount()
                diag.cust = "-"
                diag.mode = blox.uiMode
                diag.err = "-"
                diagDraw()

                removeMoped()

                if not atJob() and not heldBox() then
                    status("går till Pizza Planet")
                    local pp = pizzaPlanet()
                    local p = pp and pp:FindFirstChildWhichIsA("BasePart", true)
                    if p then goTo(p.Position, 30) end
                    task.wait(0.8)
                end

                -- 1. Ta box
                local box = heldBox()
                if not box then
                    local mb = conveyor()
                    local raw = mb and mb:GetChildren()[1]
                    if raw then
                        status("tar box via remote")
                        local customer = takeBoxViaRemote(raw)
                        if customer then
                            diag.cust = customer.Name
                            diagDraw()
                            -- 2. Leverera
                            local hrp = customer:FindFirstChild("HumanoidRootPart")
                            if hrp and CFG.autoDeliver then
                                status("går till " .. customer.Name)
                                goTo(hrp.Position, 45)
                                task.wait(0.4)
                                if deliverViaRemote(customer) then
                                    status("levererad")
                                else
                                    interactUI()
                                end
                                task.wait(1)
                            end
                        else
                            status("remote tog inte, testar klick")
                            diag.mode = "klick"
                            interactUI()
                            task.wait(0.6)
                        end
                    else
                        status("ingen box på bandet")
                        interactUI()
                        task.wait(0.6)
                    end
                end

                dropLeftover()
            end)
            if not ok then diag.err = tostring(err) end
            diagDraw()
            for _ = 1, 6 do
                if not CFG.farmOn or S.dead then break end
                task.wait(1)
            end
        end
        farmRun = false
        status("farm stoppad")
    end)
end

------------------------------------------------------------
-- JOBBKNAPPAR
------------------------------------------------------------
button(pJob, "Kontroll", "Starta farm", Color3.fromRGB(60, 110, 70), function()
    CFG.farmOn = true
    scanRemotes()
    status("startar")
    farmLoop()
end)
button(pJob, "Kontroll", "Stoppa", Color3.fromRGB(110, 55, 55), function()
    CFG.farmOn = false
    status("stoppad")
end)
button(pJob, "Test", "Läs in remotes", Color3.fromRGB(50, 50, 60), function()
    scanRemotes()
    status("remotes: " .. tostring(diag.remotes))
    diagDraw()
end)
button(pJob, "Test", "Ta en box (test)", Color3.fromRGB(50, 50, 60), function()
    local mb = conveyor()
    local raw = mb and mb:GetChildren()[1]
    if not raw then status("inget på bandet"); return end
    local c = takeBoxViaRemote(raw)
    status(c and ("kund: " .. c.Name) or "remote nekade")
    diag.cust = c and c.Name or "-"
    diagDraw()
end)
toggle(pJob, "Gå istället för teleport", CFG.walkMode, function(v) CFG.walkMode = v end)

------------------------------------------------------------
-- START
------------------------------------------------------------
task.spawn(function()
    task.wait(0.4)
    scanRemotes()
    diag.conveyor = conveyor() and "finns" or "saknas"
    diagDraw()
    status("redo")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Venice Suite v3.6",
            Text = "Remotes: " .. tostring(diag.remotes) .. " | Conveyor: " .. tostring(diag.conveyor),
            Duration = 4,
        })
    end)
end)

lp.CharacterAdded:Connect(function()
    task.wait(1)
    applyWalk()
end)
