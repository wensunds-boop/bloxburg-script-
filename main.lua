Här är det fixade skriptet:

```lua
--ägg zon här", Color3.fromRGB(50, 42, 95), function()
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
local plrList = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    LayoutOrder = 2,
    ZIndex = 7,
}, plrCard)
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
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Color3.fromRGB(215, 215, 220),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. pl.Name,
                LayoutOrder = i,
                AutoButtonColor = true,
                ZIndex = 8,
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
    Size = UDim2.new(1, 0, 0, 100),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(180, 180, 195),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    Text = "väntar...",
    LayoutOrder = 2,
    ZIndex = 7,
}, card(pJob, "Diagnostik", 134))

local diag = {}
local function diagDraw()
    diagLabel.Text = table.concat({
        "getloadedmodules: " .. tostring(diag.loaded or "nej"),
        "moduler: " .. tostring(diag.modules or "saknas"),
        "hook: " .. tostring(diag.hook or "nej"),
        "interaktion: " .. tostring(diag.interact or "nej"),
        "jobb: " .. tostring(diag.job or "saknas"),
        "pizza: " .. tostring(diag.pizza or 0),
        "fel: " .. tostring(diag.err or "-"),
    }, "\n")
end

local statusLabel = readout(pJob, "Status", "redo")
local function status(t) statusLabel.Text = t end

------------------------------------------------------------
-- BLOX-LAGER
------------------------------------------------------------
local blox = { interaction = nil, job = nil, hook = false, mode = "none" }

local function scanModules()
    local gl = gfn("getloadedmodules")
    if not gl then diag.loaded = "nej"; return end
    local ok, mods = pcall(gl)
    if not ok or type(mods) ~= "table" then diag.loaded = "fel"; return end
    local n = 0
    for k, v in pairs(mods) do
        n = n + 1
        if type(v) == "table" then
            if type(v.ShowMenu) == "function" and not blox.interaction then blox.interaction = v end
            if (type(v.GetJob) == "function" or type(v.GoToWork) == "function") and not blox.job then blox.job = v end
        elseif type(k) == "table" then
            if type(k.ShowMenu) == "function" and not blox.interaction then blox.interaction = k end
            if (type(k.GetJob) == "function" or type(k.GoToWork) == "function") and not blox.job then blox.job = k end
        end
    end
    diag.loaded = n
    local found = {}
    if blox.interaction then table.insert(found, "Interaction") end
    if blox.job then table.insert(found, "Job") end
    diag.modules = #found > 0 and table.concat(found, ",") or "saknas"
end

local function tryRequire()
    if blox.interaction and blox.job then return end
    local containers = {
        lp.PlayerScripts:FindFirstChild("Modules"),
        lp.PlayerScripts,
        game:GetService("ReplicatedStorage"):FindFirstChild("Modules"),
    }
    local setid = gfn("setthreadidentity") or gfn("setidentity")
    for _, c in ipairs(containers) do
        if c then
            for _, id in ipairs({ 2, 7, 8, 0 }) do
                pcall(function()
                    if setid then setid(id) end
                    if not blox.interaction then
                        local m = c:FindFirstChild("InteractionHandler")
                        if m then local ok, r = pcall(require, m); if ok then blox.interaction = r end end
                    end
                    if not blox.job then
                        local m = c:FindFirstChild("JobHandler")
                        if m then local ok, r = pcall(require, m); if ok then blox.job = r end end
                    end
                end)
            end
        end
    end
    pcall(function() if setid then setid(0) end end)
end

local function hookNamecall()
    local hm = gfn("hookmetamethod")
    if hm then
        local ok = pcall(function()
            local old
            old = hm(game, "__namecall", nc(function(self, ...)
                local method
                pcall(function() method = getnamecallmethod() end)
                if method ~= "InvokeServer" then return old(self, ...) end
                local res = old(self, ...)
                pcall(function()
                    local tb = debug.traceback()
                    if tb:find("JobHandler") or tb:find("Delivery") or tb:find("Pizza") then
                        if typeof(res) == "Instance" then captured = res end
                    end
                end)
                return res
            end))
        end)
        if ok then blox.hook = true; diag.hook = "metod"; return end
    end

    local getmt, setro, hookfn = gfn("getrawmetatable"), gfn("setreadonly"), gfn("hookfunction")
    if getmt then
        local ok, mt = pcall(getmt, game)
        if ok and type(mt) == "table" then
            local old = rawget(mt, "__namecall")
            if type(old) == "function" then
                local wrapped = nc(function(self, ...)
                    local method
                    pcall(function() method = getnamecallmethod() end)
                    if method ~= "InvokeServer" then return old(self, ...) end
                    local res = old(self, ...)
                    pcall(function()
                        local tb = debug.traceback()
                        if tb:find("JobHandler") or tb:find("Delivery") or tb:find("Pizza") then
                            if typeof(res) == "Instance" then captured = res end
                        end
                    end)
                    return res
                end)
                local done = false
                if hookfn then done = pcall(hookfn, old, wrapped) end
                if not done and setro then
                    pcall(setro, mt, false)
                    pcall(function() mt.__namecall = wrapped end)
                    pcall(setro, mt, true)
                    done = true
                end
                if done then blox.hook = true; diag.hook = "raw"; return end
            end
        end
    end
    diag.hook = "nej"
end

local function fireButton(btn)
    if not btn or not btn:IsA("GuiButton") or not btn.Visible then return false end
    local gc = gfn("getconnections")
    if gc then
        local ok, conns = pcall(gc, btn.Activated)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if pcall(function() c:Fire() end) then blox.mode = "connections"; return true end
            end
        end
    end
    local fs = gfn("firesignal")
    if fs then
        if pcall(fs, btn.Activated) then blox.mode = "signal"; return true end
    end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    local ok = pcall(function()
        VirtualUser:Button1Down(Vector2.new(pos.X, pos.Y), cam.CFrame)
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(pos.X, pos.Y), cam.CFrame)
    end)
    if ok then blox.mode = "mus" end
    return ok
end

local function interactUI()
    local ui = pg:FindFirstChild("_interactUI")
    if not ui then return 0 end
    local btns = {}
    for _, d in ipairs(ui:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then table.insert(btns, d) end
    end
    table.sort(btns, function(a, b) return a.AbsolutePosition.X < b.AbsolutePosition.X end)
    local n = 0
    for _, b in ipairs(btns) do
        if fireButton(b) then n = n + 1 end
        task.wait(0.35)
    end
    return n
end

local function pizzaPlanet()
    local p = workspace:FindFirstChild("PizzaPlanet")
    if p then
        local part = p:FindFirstChildWhichIsA("BasePart", true)
        if part then return part end
    end
    local env = workspace:FindFirstChild("Environment")
    local locs = env and env:FindFirstChild("Locations")
    if locs then
        for _, d in ipairs(locs:GetDescendants()) do
            if d:IsA("BasePart") and d.Name:lower():find("pizza") then return d end
        end
    end
    return nil
end

local function pizzaCount()
    local n = 0
    for _, box in ipairs({ lp.Character, lp:FindFirstChild("Backpack") }) do
        if box then
            for _, d in ipairs(box:GetChildren()) do
                if d:IsA("Tool") and d.Name:lower():find("pizza") then n = n + 1 end
            end
        end
    end
    return n
end

local function nearestCustomer()
    local r = root()
    if not r then return nil end
    local best, bestD = nil, 900
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(d) then
            local hrp = d:FindFirstChild("HumanoidRootPart")
            if hrp and d:FindFirstChildWhichIsA("BillboardGui", true) then
                local dist = (hrp.Position - r.Position).Magnitude
                if dist < bestD then best, bestD = hrp, dist end
            end
        end
    end
    return best
end

local function tp(target, steps)
    local r = root()
    if not r or not target then return end
    steps = steps or 4
    local start = r.Position
    for i = 1, steps do
        local dest = start:Lerp(target, i / steps)
        pcall(function() r.CFrame = CFrame.new(dest + Vector3.new(0, 3, 0)) end)
        task.wait(0.06)
    end
    pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
end

------------------------------------------------------------
-- JOBB
------------------------------------------------------------
local function jobName()
    if blox.job then
        local ok, j = pcall(function() return blox.job:GetJob() end)
        if ok and j then return tostring(j) end
    end
    local pp, r = pizzaPlanet(), root()
    if pp and r and (pp.Position - r.Position).Magnitude < 60 then return "PizzaPlanet" end
    if pizzaCount() > 0 then return "Leverans" end
    return nil
end

local farmRun = false
local function farmLoop()
    if farmRun then return end
    farmRun = true
    task.spawn(function()
        while CFG.farmOn and not S.dead do
            local ok, err = pcall(function()
                diag.pizza = pizzaCount()
                diag.job = jobName() or "saknas"
                diag.interact = blox.mode
                diagDraw()

                local pp = pizzaPlanet()
                if not pp then diag.err = "PizzaPlanet saknas"; return end

                local r = root()
                if not (r and (pp.Position - r.Position).Magnitude < 60) and pizzaCount() == 0 then
                    status("går till Pizza Planet")
                    tp(pp.Position, 6)
                    task.wait(1.2)
                end

                if pizzaCount() == 0 then
                    status("tar pizza")
                    interactUI()
                    task.wait(1)
                    if pizzaCount() == 0 then diag.err = "ingen pizza togs" end
                    return
                end

                if CFG.autoDeliver then
                    local target = captured and captured:IsDescendantOf(workspace) and captured:FindFirstChild("HumanoidRootPart")
                    if not target then target = nearestCustomer() end
                    if target then
                        status("levererar")
                        tp(target.Position, 5)
                        task.wait(0.8)
                        interactUI()
                        task.wait(1)
                        captured = nil
                    else
                        status("kund saknas")
                        diag.err = "ingen kund"
                    end
                end
            end)
            if not ok then diag.err = tostring(err) end
            diagDraw()
            for _ = 1, 18 do
                if not CFG.farmOn or S.dead then break end
                task.wait(1)
            end
        end
        farmRun = false
        status("farm stoppad")
    end)
end

button(pJob, "Kontroll", "Starta farm", Color3.fromRGB(60, 110, 170), function()
    farmLoop()
end)

button(pJob, "Kontroll", "Stoppa farm", Color3.fromRGB(180, 60, 60), function()
    farmRun = false
end)
