--!nocheck
--[[=====================================================================
  Venice Speed Suite  v1.8  ·  Bloxburg  ·  Xeno stable build
  ---------------------------------------------------------------------
  Fixar från v1.7.1:
    · ingen mer workspace:GetDescendants() i hot-loopar
    · prompt-cache via DescendantAdded/Removing (eventbaserad)
    · chunked initial scan med task.wait mellan chunks
    · throttlad vehicle-loop (20 Hz) och player-loop (15 Hz)
    · pizza-loopen rör bara cachade prompts, aldrig hela workspace
    · robustare executor-detektion (Xeno, Synapse, Fluxus, Delta)
    · borttaget fallback-tryck på okända prompts
    · borttaget :Fire()-hack på TextButton
    · minnesskydd på cooldown-tabellen
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)
if not PlayerGui then return warn("[Venice] ingen PlayerGui") end

local VERSION = "1.8"
local function log(m) print(string.format("[Venice %s] %s", VERSION, m)) end

--=====================================================================
-- CONFIG & STATE
--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local DEFAULT_KEYWORDS = {
    "dough", "sauce", "cheese", "pepperoni", "topping", "oven",
    "bake", "cook", "cut", "slice", "box", "package", "order",
    "deliver", "pizza", "knead", "prepare", "serve",
}

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    job     = { enabled = false, interval = 0.15, radius = 25, keywords = DEFAULT_KEYWORDS },
    ui      = { accent = Color3.fromRGB(94, 141, 255), keybind = Enum.KeyCode.K },
}

local function deepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and deepCopy(v) or v end
    return o
end

local state = deepCopy(DEFAULTS)

--=====================================================================
-- FILESYSTEM (robust executor detection)
--=====================================================================
local fs = { has = false, read = nil, write = nil, exists = nil }
do
    local function try(name)
        local ok, fn = pcall(function()
            local v = rawget(getfenv(0), name)
            if type(v) == "function" then return v end
            if type(getgenv) == "function" then
                local env = getgenv()
                if env and type(env[name]) == "function" then return env[name] end
            end
        end)
        return ok and fn or nil
    end
    fs.read   = try("readfile")
    fs.write  = try("writefile")
    fs.exists = try("isfile")
    fs.has = (fs.read ~= nil and fs.write ~= nil)
end

--=====================================================================
-- CONFIG I/O
--=====================================================================
local function clampNum(v, fallback, mn, mx)
    if type(v) ~= "number" or v ~= v then return fallback end
    return math.clamp(v, mn, mx)
end

local function loadConfig()
    if not fs.has then return end
    if fs.exists and not pcall(fs.exists, CONFIG_FILE) then return end
    local ok, raw = pcall(fs.read, CONFIG_FILE)
    if not ok or type(raw) ~= "string" or #raw < 2 then return end
    local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(d) ~= "table" then return end

    if type(d.player) == "table" then
        local p = d.player
        if type(p.enabled) == "boolean" then state.player.enabled = p.enabled end
        state.player.speed = clampNum(p.speed, 34, 16, 300)
        if type(p.jumpEnabled) == "boolean" then state.player.jumpEnabled = p.jumpEnabled end
        state.player.jump = clampNum(p.jump, 50, 30, 220)
    end
    if type(d.vehicle) == "table" then
        local v = d.vehicle
        if type(v.enabled) == "boolean" then state.vehicle.enabled = v.enabled end
        state.vehicle.maxSpeed = clampNum(v.maxSpeed, 130, 30, 600)
        state.vehicle.accel    = clampNum(v.accel, 110, 20, 600)
        state.vehicle.brake    = clampNum(v.brake, 190, 40, 900)
        if type(v.assist) == "boolean" then state.vehicle.assist = v.assist end
    end
    if type(d.limits) == "table" then
        local l = d.limits
        if type(l.enabled) == "boolean" then state.limits.enabled = l.enabled end
        state.limits.global = clampNum(l.global, 110, 16, 300)
        if type(l.zones) == "table" then
            local out = {}
            for _, z in ipairs(l.zones) do
                if #out >= MAX_ZONES then break end
                if type(z) == "table" and type(z.min) == "table"
                    and type(z.max) == "table" and type(z.limit) == "number" then
                    table.insert(out, {
                        name = type(z.name) == "string" and z.name or "Zone",
                        min = { X = z.min.X or 0, Y = z.min.Y or 0, Z = z.min.Z or 0 },
                        max = { X = z.max.X or 0, Y = z.max.Y or 0, Z = z.max.Z or 0 },
                        limit = math.clamp(z.limit, 5, 300),
                    })
                end
            end
            state.limits.zones = out
        end
    end
    if type(d.job) == "table" then
        local j = d.job
        if type(j.enabled) == "boolean" then state.job.enabled = j.enabled end
        state.job.interval = clampNum(j.interval, 0.15, 0.05, 3)
        state.job.radius   = clampNum(j.radius, 25, 4, 60)
        if type(j.keywords) == "table" then
            local out = {}
            for _, w in ipairs(j.keywords) do
                if type(w) == "string" and #w > 0 then
                    table.insert(out, w:lower())
                end
            end
            if #out > 0 then state.job.keywords = out end
        end
    end
    if type(d.ui) == "table" then
        if type(d.ui.accent) == "table" then
            local ok3, col = pcall(Color3.fromRGB,
                d.ui.accent[1] or 94, d.ui.accent[2] or 141, d.ui.accent[3] or 255)
            if ok3 then state.ui.accent = col end
        end
        if type(d.ui.keybind) == "string" then
            local ok4, k = pcall(function() return Enum.KeyCode[d.ui.keybind] end)
            if ok4 and k then state.ui.keybind = k end
        end
    end
end

local function snapshot()
    return {
        player = state.player, vehicle = state.vehicle,
        limits = state.limits, job = state.job,
        ui = {
            accent  = {
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
    if not fs.has then return end
    saveToken += 1
    local mine = saveToken
    task.delay(0.6, function()
        if mine ~= saveToken then return end
        local ok, enc = pcall(function() return HttpService:JSONEncode(snapshot()) end)
        if ok then pcall(fs.write, CONFIG_FILE, enc) end
    end)
end

loadConfig()

--=====================================================================
-- UTILITIES
--=====================================================================
local connections = {}
local function track(c)
    if c then table.insert(connections, c) end
    return c
end

local generation = 0

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

local function newInstance(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    inst.Parent = parent or props.Parent
    return inst
end

local C = {
    bg    = Color3.fromRGB(12, 14, 19),
    panel = Color3.fromRGB(20, 24, 31),
    card  = Color3.fromRGB(28, 33, 42),
    track = Color3.fromRGB(44, 50, 62),
    text  = Color3.fromRGB(233, 237, 245),
    dim   = Color3.fromRGB(132, 142, 160),
    good  = Color3.fromRGB(88, 214, 141),
    warn  = Color3.fromRGB(255, 186, 84),
    bad   = Color3.fromRGB(255, 106, 106),
}

--=====================================================================
-- EXECUTOR-SÄKER PROMPT & CLICK FIRING
--=====================================================================
local Exec = {}
do
    local function resolve(name)
        local v = rawget(getfenv(0), name)
        if type(v) == "function" then return v end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and env and type(env[name]) == "function" then return env[name] end
        end
        return nil
    end
    Exec.fireprompt = resolve("fireproximityprompt")
    Exec.fireclick  = resolve("fireclickdetector")
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    if Exec.fireprompt then
        local ok = pcall(Exec.fireprompt, prompt)
        if ok then return true end
    end
    -- Fallback: simulate hold
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.delay(math.max(prompt.HoldDuration, 0.05) + 0.02, function()
            if prompt and prompt.Parent then
                pcall(function() prompt:InputHoldEnd() end)
            end
        end)
    end)
    return ok
end

local function fireClick(cd)
    if not cd or not cd.Parent then return false end
    if Exec.fireclick then
        local ok = pcall(Exec.fireclick, cd, 0)
        if ok then return true end
    end
    return false
end

--=====================================================================
-- PROMPT/CLICK CACHE  (eventbaserad - inget tungt iterande)
--=====================================================================
local Cache = {
    prompts = {},        -- [prompt] = { text = str, part = BasePart }
    clicks  = {},        -- [cd]     = { text = str, part = BasePart }
    promptCount = 0,
    clickCount  = 0,
    primed = false,
}

local function textFor(inst, part)
    local parts = { part.Name }
    if inst:IsA("ProximityPrompt") then
        if inst.ActionText and #inst.ActionText > 0 then
            table.insert(parts, inst.ActionText)
        end
        if inst.ObjectText and #inst.ObjectText > 0 then
            table.insert(parts, inst.ObjectText)
        end
    end
    return table.concat(parts, " "):lower()
end

local function cacheAdd(desc)
    if desc:IsA("ProximityPrompt") then
        local par = desc.Parent
        if par and par:IsA("BasePart") and not Cache.prompts[desc] then
            Cache.prompts[desc] = { text = textFor(desc, par), part = par }
            Cache.promptCount += 1
        end
    elseif desc:IsA("ClickDetector") then
        local par = desc.Parent
        if par and par:IsA("BasePart") and not Cache.clicks[desc] then
            Cache.clicks[desc] = { text = par.Name:lower(), part = par }
            Cache.clickCount += 1
        end
    end
end

local function cacheRemove(desc)
    if Cache.prompts[desc] then
        Cache.prompts[desc] = nil
        Cache.promptCount -= 1
    elseif Cache.clicks[desc] then
        Cache.clicks[desc] = nil
        Cache.clickCount -= 1
    end
end

local function primeCache()
    if Cache.primed then return end
    Cache.primed = true
    task.spawn(function()
        local gen = generation
        local scanned, batch = 0, 0
        local descendants = workspace:GetDescendants()
        for i = 1, #descendants do
            if gen ~= generation then return end
            cacheAdd(descendants[i])
            scanned += 1
            batch += 1
            if batch >= 500 then           -- yielda var 500:e
                batch = 0
                task.wait()
            end
        end
        log(string.format("cache primed · %d prompts · %d clicks", Cache.promptCount, Cache.clickCount))
    end)
    track(workspace.DescendantAdded:Connect(cacheAdd))
    track(workspace.DescendantRemoving:Connect(cacheRemove))
end

--=====================================================================
-- INPUT (delad för drag + slider)
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
        if s and s.move then s.move(i.Position.X) end
    end))

    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag, inputState.slider = false, nil
    end))
end

--=====================================================================
-- VEHICLE ENGINE
--=====================================================================
local rig = { part = nil, att = nil, force = nil }
local assist = {
    mode = "detect", timer = 0, lastSeat = nil, seats = {},
    applied = nil, writeTimer = 0, direct = false, probe = 0,
    probeFrom = 0, primary = nil, anchored = false, lastNote = 0,
}

local function clearAssistRig()
    if rig.force then pcall(function() rig.force:Destroy() end) end
    if rig.att   then pcall(function() rig.att:Destroy()   end) end
    rig.force, rig.att, rig.part = nil, nil, nil
end

local function seatFromWeld(hum)
    local char = hum.Parent
    if not char then return nil end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Weld") or d:IsA("WeldConstraint") then
            local ok, other = pcall(function() return d.Part1 end)
            if ok and other and (other:IsA("Seat") or other:IsA("VehicleSeat")) then
                return other
            end
        end
    end
    return nil
end

local function getVehicle()
    local hum = getHumanoid()
    if not hum then return nil end

    local seat = nil
    pcall(function() seat = hum.SeatPart end)
    if not seat then seat = seatFromWeld(hum) end
    if not seat then return nil end

    local m = seat:FindFirstAncestorOfClass("Model")
    if not m then return nil end
    local d = 0
    while m.Parent and m.Parent ~= workspace and d < 4 do
        local up = m.Parent:FindFirstAncestorOfClass("Model")
        if not up then break end
        m, d = up, d + 1
    end
    return m, seat
end

local function pickPrimary(model, seat)
    local okR, ar = pcall(function() return seat.AssemblyRootPart end)
    if okR and ar and ar.Parent and not ar.Anchored
        and not ar:IsA("Seat") and not ar:IsA("VehicleSeat") then
        return ar
    end
    local best, bestScore = nil, -1
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and not d.Anchored
            and not d:IsA("Seat") and not d:IsA("VehicleSeat") then
            local n = d.Name:lower()
            local isWheel = n:find("wheel") or n:find("tire") or n:find("rim")
            local score = d.AssemblyMass * (isWheel and 0.2 or 1)
            if score > bestScore then best, bestScore = d, score end
        end
    end
    return best or model.PrimaryPart or (okR and ar) or nil
end

local function ensureRig(part)
    if not part then return false end
    if rig.part == part and rig.force and rig.force.Parent then return true end
    clearAssistRig()
    local ok = pcall(function()
        local a = newInstance("Attachment", { Name = "VeniceAtt" }, part)
        local lv = newInstance("LinearVelocity", {
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
        if d:IsA("VehicleSeat") then
            table.insert(assist.seats, d)
            if #assist.seats >= 20 then break end  -- safety
        end
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

local function tickVehicle(dt, notify)
    local model, seat = getVehicle()
    local readout = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.vehicleReadout

    if not model then
        if assist.lastSeat ~= nil then resetAssist() end
        if readout then pcall(readout, nil, 0) end
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
            notify("Bilen ar anchrad - fart gar ej att andra", "bad")
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
    local method = assist.anchored and "anchrad"
        or (assist.direct and "direkt" or "constraint")
    local info = string.format("metod: %s | %d saten", method, #assist.seats)

    if not state.vehicle.enabled then
        if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
        if readout then pcall(readout, model.Name, speed, nil, info) end
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
        if readout then pcall(readout, model.Name, speed, nil, info) end
        return
    end

    local thr = 0
    if seat:IsA("VehicleSeat") then
        local okT, r = pcall(function() return seat.ThrottleFloat end)
        if okT and type(r) == "number" then thr = r end
    end

    assist.timer += dt
    if math.abs(thr) > 0.02 then
        assist.mode = "throttle"
    elseif assist.mode == "detect" and assist.timer > 1.2 then
        assist.mode = "hold"
    end

    local okF, fwd = pcall(function() return primary.CFrame.LookVector end)
    if not okF or typeof(fwd) ~= "Vector3" then
        if readout then pcall(readout, model.Name, speed, nil, info) end
        return
    end

    local fs_ = vel:Dot(fwd)
    local desired
    if assist.mode == "throttle" then desired = thr * state.vehicle.maxSpeed
    elseif fs_ > 0.05  then desired = state.vehicle.maxSpeed
    elseif fs_ < -0.05 then desired = -state.vehicle.maxSpeed
    else desired = 0 end

    local inc = math.abs(desired) > math.abs(fs_)
    local rate = inc and state.vehicle.accel or state.vehicle.brake
    local step = math.clamp(desired - fs_, -rate * dt, rate * dt)
    local engaged = math.abs(step) > 0.01

    if engaged and inc and not assist.direct then
        if assist.probe == 0 then
            assist.probe, assist.probeFrom = 0.0001, fs_
        else
            assist.probe += dt
            if assist.probe > 1 then
                if math.abs(fs_ - assist.probeFrom) < 2 then
                    assist.direct = true
                    notify("Assist: ingen effekt - byter metod", "bad")
                end
                assist.probe = 0
            end
        end
    elseif not inc then
        assist.probe = 0
    end

    if not assist.direct and ensureRig(primary) then
        rig.force.LineDirection = fwd
        rig.force.LineVelocity  = fs_ + step
        rig.force.MaxForce = engaged
            and math.max(primary.AssemblyMass * rate * 2, 12000) or 0
    else
        if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
        if engaged then
            local nv = fwd * (fs_ + step) + Vector3.new(0, vel.Y, 0)
            pcall(function() primary.AssemblyLinearVelocity = nv end)
        end
    end

    if readout then pcall(readout, model.Name, speed, assist.mode, info) end
end

--=====================================================================
-- PLAYER ENGINE
--=====================================================================
local jumpForced = false

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

local function tickPlayer()
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

    local readout = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.playerReadout
    if readout then pcall(readout, hum.WalkSpeed, lim) end
end

--=====================================================================
-- PIZZA ENGINE (uses cache, zero workspace scanning)
--=====================================================================
local pizzaState = {
    actionCount = 0,
    cooldowns   = {},    -- [instance] = os.clock() when fired
    lastCleanup = 0,
}

local function cleanupCooldowns(now)
    if now - pizzaState.lastCleanup < 10 then return end
    pizzaState.lastCleanup = now
    local kept = {}
    for inst, t in pairs(pizzaState.cooldowns) do
        if now - t < 5 then kept[inst] = t end
    end
    pizzaState.cooldowns = kept
end

local function tickPizza()
    if not state.job.enabled then return end
    local root = getRoot()
    if not root then return end

    local now = os.clock()
    cleanupCooldowns(now)

    local rootPos = root.Position
    local radius  = state.job.radius
    local radiusSq = radius * radius
    local readout = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.jobReadout

    -- Build a list of nearby candidates from cache
    local candidates = {}
    local cCount = 0
    local maxCandidates = 80  -- safety ceiling

    for prompt, info in pairs(Cache.prompts) do
        if cCount >= maxCandidates then break end
        if prompt.Parent and info.part and info.part.Parent and prompt.Enabled then
            local offs = info.part.Position - rootPos
            local distSq = offs.X*offs.X + offs.Y*offs.Y + offs.Z*offs.Z
            if distSq <= radiusSq then
                cCount += 1
                candidates[cCount] = {
                    type = "prompt", inst = prompt,
                    text = info.text, distSq = distSq,
                }
            end
        end
    end
    for cd, info in pairs(Cache.clicks) do
        if cCount >= maxCandidates then break end
        if cd.Parent and info.part and info.part.Parent then
            local offs = info.part.Position - rootPos
            local distSq = offs.X*offs.X + offs.Y*offs.Y + offs.Z*offs.Z
            if distSq <= radiusSq then
                cCount += 1
                candidates[cCount] = {
                    type = "click", inst = cd,
                    text = info.text, distSq = distSq,
                }
            end
        end
    end

    if cCount == 0 then
        if readout then pcall(readout, "Inga prompts i narheten", false) end
        return
    end

    table.sort(candidates, function(a, b) return a.distSq < b.distSq end)

    -- Go through keywords in priority order
    for _, kw in ipairs(state.job.keywords) do
        for i = 1, cCount do
            local cand = candidates[i]
            if cand.text:find(kw, 1, true) then
                local cd = pizzaState.cooldowns[cand.inst]
                if not cd or now - cd >= 0.3 then
                    local ok = cand.type == "prompt"
                        and firePrompt(cand.inst)
                        or  fireClick(cand.inst)
                    if ok then
                        pizzaState.cooldowns[cand.inst] = now
                        pizzaState.actionCount += 1
                        if readout then
                            pcall(readout, string.format("%s  (#%d, %.1fm)",
                                kw, pizzaState.actionCount, math.sqrt(cand.distSq)), true)
                        end
                    else
                        if readout then pcall(readout, "Miss: " .. kw, false) end
                    end
                    return
                end
            end
        end
    end

    if readout then
        pcall(readout, string.format("%d prompts nara men inget keyword matchade", cCount), false)
    end
end

--=====================================================================
-- GUI
--=====================================================================
local WIN_W, WIN_H = 420, 500

local clearAssistRigRef
local rebuild

local function teardown()
    generation += 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if clearAssistRigRef then pcall(clearAssistRigRef) end
    local r = _G.__VeniceSpeedSuite
    if r and r.gui then pcall(function() r.gui:Destroy() end) end
    _G.__VeniceSpeedSuite = nil
end
clearAssistRigRef = clearAssistRig

local function buildFallback(err)
    pcall(function()
        local g = newInstance("ScreenGui", { ResetOnSpawn = false }, PlayerGui)
        local f = newInstance("Frame", {
            Size = UDim2.new(0, 320, 0, 80),
            Position = UDim2.new(0.5, -160, 0.5, -40),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
        }, g)
        newInstance("TextLabel", {
            Size = UDim2.new(1, -20, 1, -20),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 11, TextWrapped = true, TextColor3 = C.bad,
            Text = "GUI fel: " .. tostring(err),
        }, f)
    end)
end

local function buildGUI()
    local myGen = generation
    log("building shell")

    local gui = newInstance("ScreenGui", {
        Name = "VeniceSpeedSuite", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 5000,
    }, PlayerGui)

    local win = newInstance("Frame", {
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
    }, gui)
    newInstance("UICorner", { CornerRadius = UDim.new(0, 12) }, win)

    _G.__VeniceSpeedSuite = { gui = gui, win = win, teardown = teardown }

    -- HEADER ---------------------------------------------------------
    local header = newInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)

    newInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 15, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "Venice Speed Suite",
    }, header)

    newInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 12), Position = UDim2.new(0, 14, 0, 24),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 9, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "v" .. VERSION,
    }, header)

    local status = newInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 12), Position = UDim2.new(0, 14, 0, 36),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        TextSize = 9, TextColor3 = C.good,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }, header)

    local function notify(text, kind)
        if not status.Parent then return end
        local s = tostring(text)
        status.Text = s
        status.TextColor3 = kind == "bad" and C.bad
            or kind == "good" and C.good or C.text
        task.delay(3, function()
            pcall(function()
                if status.Parent and status.Text == s then status.Text = "" end
            end)
        end)
    end

    local function hbtn(g, x, col)
        local b = newInstance("TextButton", {
            Size = UDim2.new(0, 26, 0, 24), Position = UDim2.new(1, x, 0, 12),
            BackgroundColor3 = C.card, BorderSizePixel = 0,
            AutoButtonColor = false, Font = Enum.Font.GothamBold,
            TextSize = 13, TextColor3 = col, Text = g,
        }, header)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        return b
    end
    local minBtn   = hbtn("-", -64, C.dim)
    local closeBtn = hbtn("x", -34, C.bad)

    -- DRAG -----------------------------------------------------------
    track(header.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag = true
        inputState.off = Vector2.new(i.Position.X, i.Position.Y) - win.AbsolutePosition
    end))

    -- TAB BAR --------------------------------------------------------
    local bar = newInstance("Frame", {
        Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 54),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)
    newInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
    }, bar)
    newInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4),
    }, bar)

    local content = newInstance("Frame", {
        Size = UDim2.new(1, -20, 1, -150), Position = UDim2.new(0, 10, 0, 92),
        BackgroundTransparency = 1,
    }, win)

    local pages, tabs = {}, {}

    local function selectTab(name)
        for n, pg in pairs(pages) do
            pg.Visible = (n == name)
            pcall(function()
                tabs[n].BackgroundColor3 = n == name and C.card or C.panel
                tabs[n].TextColor3 = n == name and C.text or C.dim
            end)
        end
    end

    local function tab(name, order)
        local b = newInstance("TextButton", {
            Size = UDim2.new(0, #name * 6 + 20, 1, -8),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
            AutoButtonColor = false, LayoutOrder = order,
            Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = C.dim, Text = name,
        }, bar)
        newInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
        }, b)

        local p = newInstance("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 760), Visible = false,
        }, content)
        newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        }, p)
        newInstance("UIPadding", { PaddingBottom = UDim.new(0, 12) }, p)

        pages[name], tabs[name] = p, b
        track(b.MouseButton1Click:Connect(function() selectTab(name) end))
        return p
    end

    local playerPage  = tab("Player", 1)
    local vehiclePage = tab("Vehicle", 2)
    local jobPage     = tab("Job", 3)
    local playersPage = tab("Players", 4)
    local settPage    = tab("Settings", 5)

    -- WIDGETS --------------------------------------------------------
    local function card(parent, h, order)
        local f = newInstance("Frame", {
            Size = UDim2.new(1, 0, 0, h),
            BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order,
        }, parent)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
        return f
    end

    local function label(parent, text, y, size, col)
        return newInstance("TextLabel", {
            Size = UDim2.new(1, -20, 0, 14),
            Position = UDim2.new(0, 10, 0, y),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = size or 9, TextColor3 = col or C.dim,
            TextXAlignment = Enum.TextXAlignment.Left, Text = text,
        }, parent)
    end

    local function slider(parent, cfg)
        local row = newInstance("Frame", {
            Size = UDim2.new(1, -20, 0, 40),
            Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)

        newInstance("TextLabel", {
            Size = UDim2.new(1, -70, 0, 14),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)

        local valLbl = newInstance("TextLabel", {
            Size = UDim2.new(0, 70, 0, 14),
            Position = UDim2.new(1, -70, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 11, TextColor3 = state.ui.accent,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "",
        }, row)

        local trk = newInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 5),
            Position = UDim2.new(0, 0, 0, 24),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
        }, row)

        local fill = newInstance("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = state.ui.accent, BorderSizePixel = 0,
        }, trk)

        local knob = newInstance("Frame", {
            Size = UDim2.new(0, 12, 0, 12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 2,
        }, trk)

        local hit = newInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.new(0, 0, 0.5, -11),
            BackgroundTransparency = 1, ZIndex = 3,
        }, trk)

        local v = math.clamp(cfg.value, cfg.min, cfg.max)

        local function render()
            local a = (v - cfg.min) / math.max(cfg.max - cfg.min, 1e-6)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            valLbl.Text = cfg.format and cfg.format(v) or tostring(v)
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
            local alpha = math.clamp((x - trk.AbsolutePosition.X) / w, 0, 1)
            set(cfg.min + alpha * (cfg.max - cfg.min), true)
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
        local row = newInstance("Frame", {
            Size = UDim2.new(1, -20, 0, 26),
            Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundTransparency = 1,
        }, parent)

        newInstance("TextLabel", {
            Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)

        local pill = newInstance("TextButton", {
            Size = UDim2.new(0, 36, 0, 18),
            Position = UDim2.new(1, -36, 0.5, -9),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "",
        }, row)

        local dot = newInstance("Frame", {
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0, 3, 0.5, -6),
            BackgroundColor3 = C.dim, BorderSizePixel = 0,
        }, pill)

        local on = cfg.value and true or false
        local function render()
            pill.BackgroundColor3 = on and state.ui.accent or C.track
            dot.Position = on and UDim2.new(1, -15, 0.5, -6)
                or UDim2.new(0, 3, 0.5, -6)
            dot.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
        render()

        track(pill.MouseButton1Click:Connect(function()
            on = not on
            render()
            if cfg.onChanged then
                local ok, err = pcall(cfg.onChanged, on)
                if not ok then notify(err, "bad") end
            end
        end))
    end

    local function button(parent, cfg)
        local b = newInstance("TextButton", {
            Size = UDim2.new(1, -20, 0, 28),
            Position = UDim2.new(0, 10, 0, cfg.y),
            BackgroundColor3 = cfg.danger and Color3.fromRGB(50, 27, 32) or C.track,
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = cfg.danger and C.bad or C.text, Text = cfg.label,
        }, parent)
        track(b.MouseButton1Click:Connect(function()
            if cfg.onClick then
                local ok, e = pcall(cfg.onClick)
                if not ok then notify(e, "bad") end
            end
        end))
        return b
    end

    -- PLAYER PAGE ----------------------------------------------------
    local speedSlider
    do
        local c = card(playerPage, 108, 1)
        label(c, "SPELARE", 8)
        toggle(c, {
            label = "Aktivera spelarjustering", y = 24,
            value = state.player.enabled,
            onChanged = function(v)
                state.player.enabled = v; saveConfig()
                notify(v and "Spelarjustering pa" or "Spelarjustering av",
                    v and "good" or nil)
            end,
        })
        speedSlider = slider(c, {
            label = "Ganghastighet", min = 16, max = 300, step = 1,
            value = state.player.speed, y = 54,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.player.speed = x; saveConfig() end,
        })

        local liveCard = card(playerPage, 32, 2)
        local live = label(liveCard, "16.0 st/s", 8, 13, C.text)

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
            label = "Aterstall (16 / 50)", y = 10,
            onClick = function()
                state.player.speed, state.player.jump = 16, 50
                speedSlider.set(16); saveConfig()
                local hum = getHumanoid()
                if hum then pcall(function()
                    hum.WalkSpeed = 16
                    hum.UseJumpPower = true
                    hum.JumpPower = 50
                end) end
                notify("Aterstellt", "good")
            end,
        })

        _G.__VeniceSpeedSuite.playerReadout = function(cur, lim)
            pcall(function()
                live.Text = string.format("%.1f st/s%s", cur,
                    lim and ("  |  ZONGRANS " .. lim) or "")
                live.TextColor3 = lim and C.warn or C.text
            end)
        end
    end

    -- VEHICLE PAGE ---------------------------------------------------
    do
        local d = card(vehiclePage, 78, 1)
        label(d, "FORDON", 8)
        local detLbl  = label(d, "Inte i sate", 24, 12, C.dim)
        local spdLbl  = label(d, "0.0 st/s", 42, 10, C.dim)
        local infoLbl = label(d, "metod: -", 56, 9, C.dim)

        local c = card(vehiclePage, 140, 2)
        toggle(c, {
            label = "Aktivera fordonsjustering", y = 8,
            value = state.vehicle.enabled,
            onChanged = function(v)
                state.vehicle.enabled = v; saveConfig()
                notify(v and "Fordonsjustering pa" or "Fordonsjustering av",
                    v and "good" or nil)
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
            format = function(x) return x .. " st/s2" end,
            onChanged = function(x) state.vehicle.accel = x; saveConfig() end,
        })

        local bc = card(vehiclePage, 110, 3)
        slider(bc, {
            label = "Bromskraft", min = 40, max = 900, step = 10,
            value = state.vehicle.brake, y = 8,
            format = function(x) return x .. " st/s2" end,
            onChanged = function(x) state.vehicle.brake = x; saveConfig() end,
        })
        toggle(bc, {
            label = "Fysikassist", y = 52, value = state.vehicle.assist,
            onChanged = function(v)
                state.vehicle.assist = v; saveConfig()
                notify(v and "Assist pa" or "Assist av", nil)
            end,
        })

        local rc = card(vehiclePage, 48, 4)
        button(rc, {
            label = "Aterstall fordon", y = 10,
            onClick = function()
                state.vehicle.maxSpeed, state.vehicle.accel, state.vehicle.brake = 130, 110, 190
                saveConfig()
                rebuild()
            end,
        })

        _G.__VeniceSpeedSuite.vehicleReadout = function(name, speed, _, info)
            pcall(function()
                detLbl.Text = name and ("I: " .. name) or "Inte i sate"
                detLbl.TextColor3 = name and C.good or C.dim
                spdLbl.Text = string.format("%.1f st/s", speed or 0)
                spdLbl.TextColor3 = (speed or 0) > 0.5 and C.text or C.dim
                infoLbl.Text = info or "metod: -"
                infoLbl.TextColor3 = (info and info:find("anchrad")) and C.bad or C.dim
            end)
        end
    end

    -- JOB PAGE -------------------------------------------------------
    do
        local c = card(jobPage, 130, 1)
        label(c, "PIZZA AUTO-FARM", 8)
        toggle(c, {
            label = "Baka automatiskt", y = 24, value = state.job.enabled,
            onChanged = function(v)
                state.job.enabled = v
                if v then primeCache() end
                pizzaState.actionCount = 0
                saveConfig()
                notify(v and "Auto-pizza PA - sta vid stationen" or "Auto-pizza av",
                    v and "good" or nil)
            end,
        })
        slider(c, {
            label = "Intervall (lagre = snabbare)",
            min = 0.05, max = 2, step = 0.05,
            value = state.job.interval, y = 54,
            format = function(x) return string.format("%.2f s", x) end,
            onChanged = function(x) state.job.interval = x; saveConfig() end,
        })
        slider(c, {
            label = "Sokradie", min = 4, max = 60, step = 1,
            value = state.job.radius, y = 94,
            format = function(x) return x .. " st" end,
            onChanged = function(x) state.job.radius = x; saveConfig() end,
        })

        local sc = card(jobPage, 64, 2)
        label(sc, "STATUS", 8)
        local statusLbl = label(sc, "Vantar...", 24, 9, C.dim)
        local countLbl = label(sc, "Aktioner: 0", 40, 9, C.dim)

        _G.__VeniceSpeedSuite.jobReadout = function(txt, ok)
            pcall(function()
                statusLbl.Text = txt or ""
                statusLbl.TextColor3 = ok and C.good or C.dim
                countLbl.Text = string.format("Aktioner: %d  |  cache: %d prompts / %d clicks",
                    pizzaState.actionCount, Cache.promptCount, Cache.clickCount)
            end)
        end

        local kc = card(jobPage, 110, 3)
        label(kc, "NYCKELORD (ordning = prioritet)", 8)
        local kb = newInstance("TextBox", {
            Size = UDim2.new(1, -20, 0, 64), Position = UDim2.new(0, 10, 0, 24),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
            Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
            TextWrapped = true, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = table.concat(state.job.keywords, ", "),
        }, kc)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, kb)
        newInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4),
        }, kb)

        track(kb.FocusLost:Connect(function()
            local out = {}
            for w in string.gmatch(kb.Text:lower(), "[^,%s]+") do
                if #w > 0 then table.insert(out, w) end
            end
            if #out > 0 then
                state.job.keywords = out
                saveConfig()
                notify(#out .. " nyckelord sparade", "good")
            end
        end))

        local bc = card(jobPage, 80, 4)
        button(bc, {
            label = "Skanna cache nu (test)", y = 6,
            onClick = function()
                primeCache()
                local root = getRoot()
                if not root then return notify("Ingen karaktar", "bad") end
                local found, radiusSq = 0, state.job.radius^2
                local sample = {}
                for prompt, info in pairs(Cache.prompts) do
                    if prompt.Parent and info.part.Parent then
                        local d = (info.part.Position - root.Position).Magnitude
                        if d*d <= radiusSq then
                            found += 1
                            if #sample < 5 then
                                table.insert(sample, string.format("[%.0fm] %s",
                                    d, info.text:sub(1, 30)))
                            end
                        end
                    end
                end
                notify(string.format("%d prompts inom %d st (av %d totalt)",
                    found, state.job.radius, Cache.promptCount),
                    found > 0 and "good" or "bad")
                if #sample > 0 then
                    statusLbl.Text = table.concat(sample, "\n")
                    statusLbl.TextColor3 = C.text
                end
            end,
        })
        button(bc, {
            label = "Nollstall raknare", y = 40,
            onClick = function()
                pizzaState.actionCount = 0
                pizzaState.cooldowns = {}
                notify("Raknare nollstalld", "good")
            end,
        })

        local nc = card(jobPage, 90, 5)
        newInstance("TextLabel", {
            Size = UDim2.new(1, -20, 1, -16),
            Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 9, TextWrapped = true, TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = "GUIDE: 1) Ta pizza-jobbet  2) Ga till stationen  "
                .. "3) Sla pa 'Baka automatiskt'  4) Scriptet trycker prompts "
                .. "i prioritetsordning. Sank intervallet for snabbare bakning. "
                .. "Cachen byggs upp automatiskt - forsta skanningen tar nagra sekunder.",
        }, nc)
    end

    -- PLAYERS PAGE ---------------------------------------------------
    local selected, refreshPlayers = {}, nil
    do
        local c = card(playersPage, 140, 1)
        label(c, "SERVER", 8)
        local count = label(c, "-", 22, 10, C.dim)

        local function sb(text, x, y, w, fn, danger)
            local b = newInstance("TextButton", {
                Size = UDim2.new(0, w, 0, 24), Position = UDim2.new(0, x, 0, y),
                BackgroundColor3 = danger and Color3.fromRGB(50, 27, 32) or C.track,
                BorderSizePixel = 0, AutoButtonColor = false,
                Font = Enum.Font.Gotham, TextSize = 9,
                TextColor3 = danger and C.bad or C.text, Text = text,
            }, c)
            track(b.MouseButton1Click:Connect(function()
                local ok, e = pcall(fn)
                if not ok then notify(e, "bad") end
            end))
        end

        sb("Markera alla", 10, 40, 100, function()
            table.clear(selected)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then selected[p.UserId] = true end
            end
            if refreshPlayers then refreshPlayers() end
        end)
        sb("Rensa", 116, 40, 60, function()
            table.clear(selected)
            if refreshPlayers then refreshPlayers() end
        end)
        sb("Kick markerade", 182, 40, 110, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and selected[p.UserId] then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice") end)
                end
            end
            notify(n > 0 and ("Kick skickat till " .. n) or "Ingen markerad",
                n > 0 and "good" or "bad")
        end, true)
        sb("Kick alla andra", 10, 76, 150, function()
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    n += 1
                    pcall(function() p:Kick("Kickad av Venice") end)
                end
            end
            notify(n > 0 and ("Kick skickat till " .. n) or "Ingen att kicka",
                n > 0 and "good" or "bad")
        end)

        local lc = card(playersPage, 200, 2)
        local list = newInstance("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 184), Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 184),
        }, lc)
        newInstance("UIListLayout", {
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
                    local row = newInstance("Frame", {
                        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panel,
                        BorderSizePixel = 0, LayoutOrder = shown,
                    }, list)

                    local cb = newInstance("TextButton", {
                        Size = UDim2.new(0, 14, 0, 14),
                        Position = UDim2.new(0, 5, 0.5, -7),
                        BackgroundColor3 = on and state.ui.accent or C.track,
                        BorderSizePixel = 0, AutoButtonColor = false,
                        Font = Enum.Font.GothamBold, TextSize = 9,
                        TextColor3 = Color3.new(1, 1, 1), Text = on and "x" or "",
                    }, row)
                    track(cb.MouseButton1Click:Connect(function()
                        selected[p.UserId] = (not selected[p.UserId]) or nil
                        refreshPlayers()
                    end))

                    newInstance("TextLabel", {
                        Size = UDim2.new(1, -86, 1, 0),
                        Position = UDim2.new(0, 24, 0, 0),
                        BackgroundTransparency = 1,
                        Font = Enum.Font.Gotham, TextSize = 9,
                        TextColor3 = C.text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd, Text = p.Name,
                    }, row)

                    local kbb = newInstance("TextButton", {
                        Size = UDim2.new(0, 42, 0, 16),
                        Position = UDim2.new(1, -47, 0.5, -8),
                        BackgroundColor3 = Color3.fromRGB(50, 27, 32),
                        BorderSizePixel = 0, AutoButtonColor = false,
                        Font = Enum.Font.GothamBold, TextSize = 8,
                        TextColor3 = C.bad, Text = "kick",
                    }, row)
                    track(kbb.MouseButton1Click:Connect(function()
                        pcall(function() p:Kick("Kickad av Venice") end)
                        notify("Kick skickat till " .. p.Name, "good")
                    end))
                end
            end

            list.CanvasSize = UDim2.new(0, 0, 0, math.max(184, shown * 27 + 6))
            if shown == 0 then
                newInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "Ensam i servern.",
                }, list)
            end
        end
        refreshPlayers()

        track(Players.PlayerAdded:Connect(function()
            task.delay(0.5, function() pcall(refreshPlayers) end)
        end))
        track(Players.PlayerRemoving:Connect(function()
            task.delay(0.5, function() pcall(refreshPlayers) end)
        end))
        track(tabs.Players.MouseButton1Click:Connect(function()
            pcall(refreshPlayers)
        end))

        local nc = card(playersPage, 36, 3)
        newInstance("TextLabel", {
            Size = UDim2.new(1, -20, 1, -8), Position = UDim2.new(0, 10, 0, 4),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9,
            TextColor3 = C.dim, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Kick ar lokalt - servern kan lagga tillbaka dem.",
        }, nc)
    end

    -- SETTINGS PAGE --------------------------------------------------
    do
        local c = card(settPage, 100, 1)
        label(c, "FARTSGRANSER", 8)
        toggle(c, {
            label = "Tillampa granser", y = 22, value = state.limits.enabled,
            onChanged = function(v)
                state.limits.enabled = v; saveConfig()
                notify(v and "Granser pa" or "Granser av", nil)
            end,
        })
        slider(c, {
            label = "Standardgrans", min = 16, max = 300, step = 1,
            value = state.limits.global, y = 52,
            format = function(x) return x .. " st/s" end,
            onChanged = function(x) state.limits.global = x; saveConfig() end,
        })

        local zc = card(settPage, 160, 2)
        label(zc, "ZONER", 8)
        local add = newInstance("TextButton", {
            Size = UDim2.new(1, -150, 0, 24), Position = UDim2.new(0, 10, 0, 22),
            BackgroundColor3 = C.track, BorderSizePixel = 0,
            AutoButtonColor = false, Font = Enum.Font.Gotham,
            TextSize = 9, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "  Lagg zon har",
        }, zc)

        local function fld(x, ph, txt)
            return newInstance("TextBox", {
                Size = UDim2.new(0, 58, 0, 24), Position = UDim2.new(1, x, 0, 22),
                BackgroundColor3 = C.panel, BorderSizePixel = 0,
                Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
                PlaceholderText = ph, Text = txt, ClearTextOnFocus = false, ZIndex = 2,
            }, zc)
        end
        local lb = fld(-132, "grans", "60")
        local rb = fld(-70, "radie", "45")

        local zlist = newInstance("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 96), Position = UDim2.new(0, 10, 0, 54),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 96),
        }, zc)
        newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3),
        }, zlist)

        local function renderZones()
            for _, ch in ipairs(zlist:GetChildren()) do
                if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
            end
            local n = #state.limits.zones
            zlist.CanvasSize = UDim2.new(0, 0, 0, math.max(96, n * 27 + 6))
            if n == 0 then
                newInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = "Inga zoner.",
                }, zlist)
                return
            end
            for i, z in ipairs(state.limits.zones) do
                local row = newInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panel,
                    BorderSizePixel = 0, LayoutOrder = i,
                }, zlist)
                newInstance("TextLabel", {
                    Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                    TextSize = 9, TextColor3 = C.text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = string.format("%s | %dst/s",
                        z.name or ("Zon " .. i), z.limit),
                }, row)
                local del = newInstance("TextButton", {
                    Size = UDim2.new(0, 20, 0, 16),
                    Position = UDim2.new(1, -24, 0.5, -8),
                    BackgroundColor3 = Color3.fromRGB(50, 27, 32),
                    BorderSizePixel = 0, AutoButtonColor = false,
                    Font = Enum.Font.GothamBold, TextSize = 10,
                    TextColor3 = C.bad, Text = "x",
                }, row)
                track(del.MouseButton1Click:Connect(function()
                    table.remove(state.limits.zones, i)
                    saveConfig()
                    renderZones()
                    notify("Zon borttagen", nil)
                end))
            end
        end
        renderZones()

        track(add.MouseButton1Click:Connect(function()
            local root = getRoot()
            if not root then return notify("Ingen karaktar", "bad") end
            if #state.limits.zones >= MAX_ZONES then
                return notify("Zon-grans", "bad")
            end
            local rad = math.clamp(tonumber(rb.Text) or 45, 5, 500)
            local lim = math.clamp(tonumber(lb.Text) or 60, 5, 300)
            local p = root.Position
            table.insert(state.limits.zones, {
                name = "Zon " .. (#state.limits.zones + 1),
                min = { X = p.X - rad, Y = p.Y - 60, Z = p.Z - rad },
                max = { X = p.X + rad, Y = p.Y + 200, Z = p.Z + rad },
                limit = lim,
            })
            saveConfig(); renderZones()
            notify("Zon tillagd | " .. lim .. " st/s", "good")
        end))

        local pc = card(settPage, 80, 3)
        button(pc, {
            label = "Spara config", y = 6,
            onClick = function()
                if not fs.has then return notify("Inget filsystem", "bad") end
                saveConfig()
                notify("Sparad", "good")
            end,
        })
        button(pc, {
            label = "Aterstall allt", y = 42,
            onClick = function()
                state = deepCopy(DEFAULTS); saveConfig()
                notify("Allt aterstellt", "good")
                task.delay(0.15, rebuild)
            end,
        })

        local dc = card(settPage, 46, 4)
        button(dc, {
            label = "Ladda ur", y = 9, danger = true,
            onClick = function()
                notify("Laddar ur...", "bad")
                task.delay(0.3, teardown)
            end,
        })
    end

    -- CONTROLS (min/close/keybind) ----------------------------------
    do
        local minimized = false
        local expandedH = WIN_H

        track(minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            minBtn.Text = minimized and "+" or "-"
            if minimized then
                expandedH = win.Size.Y.Offset
                win.Size = UDim2.new(0, WIN_W, 0, 50)
                bar.Visible, content.Visible = false, false
            else
                bar.Visible, content.Visible = true, true
                win.Size = UDim2.new(0, WIN_W, 0, expandedH)
            end
        end))

        local hidden = false
        track(closeBtn.MouseButton1Click:Connect(function()
            hidden = true
            win.Visible = false
            notify("Gomd | " .. state.ui.keybind.Name .. " visar", nil)
        end))
        track(UserInputService.InputBegan:Connect(function(i, processed)
            if processed then return end
            if i.KeyCode == state.ui.keybind then
                hidden = not hidden
                win.Visible = not hidden
            end
        end))
    end

    -- MAIN LOOPS -----------------------------------------------------
    log("starting loops")
    selectTab("Player")

    task.spawn(function()
        local vehAccum, playerAccum = 0, 0
        local VEH_HZ, PLAYER_HZ = 1/20, 1/15   -- 20 Hz & 15 Hz

        while gui.Parent and myGen == generation do
            local dt = task.wait()
            if type(dt) ~= "number" then dt = 1/60 end

            vehAccum    += dt
            playerAccum += dt

            if playerAccum >= PLAYER_HZ then
                playerAccum = 0
                pcall(tickPlayer)
            end
            if vehAccum >= VEH_HZ then
                pcall(tickVehicle, vehAccum, notify)
                vehAccum = 0
            end
        end
    end)

    -- Pizza runs on its own schedule
    task.spawn(function()
        while gui.Parent and myGen == generation do
            local wait = math.max(state.job.interval, 0.05)
            task.wait(wait)
            if state.job.enabled then
                local ok, err = pcall(tickPizza)
                if not ok then
                    warn("[Venice] pizza: " .. tostring(err))
                    task.wait(1)    -- backoff on error
                end
            end
        end
    end)

    track(LP.CharacterAdded:Connect(function()
        task.wait(0.6)
        resetAssist()
        pizzaState.cooldowns = {}
    end))

    primeCache()   -- always prime so other features work smoothly
    notify("Venice v" .. VERSION .. " | " .. state.ui.keybind.Name .. " visar/gommer", "good")
end

rebuild = function()
    teardown()
    task.wait(0.15)
    local ok, err = pcall(buildGUI)
    if not ok then
        warn("[Venice] rebuild: " .. tostring(err))
        buildFallback(err)
    end
end

bindSharedInput()
task.wait(0.2)

local ok, err = pcall(buildGUI)
if not ok then
    warn("[Venice] start: " .. tostring(err))
    buildFallback(err)
end
