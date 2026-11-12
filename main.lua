--!nocheck
--[[=====================================================================
  Venice Speed Suite  v1.9  ·  Bloxburg
  ---------------------------------------------------------------------
  v1.9 - Pizza auto-farm komplett omskriven
    · AGGRESSIVE-lage: trycker alla ProximityPrompts + ClickDetectors inom radien
    · Live debug-vy med avstand och text pa allt som detekteras
    · Fire-metoder: fireproximityprompt, hold-override, getconnections, fireclickdetector
    · Per-prompt cooldown justerbar
    · Blacklist mot forfeltraffar (dorrar, sangar, saten osv)
    · Testknapp for att trycka ett specifikt mal
    · Statistik: antal prompts/clicks tryckta, vilken metod funkade
=====================================================================]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui", 30)
if not PlayerGui then return warn("[Venice] ingen PlayerGui") end

local VERSION = "1.9"
local function log(m) print(string.format("[Venice %s] %s", VERSION, m)) end

--=====================================================================
-- CONFIG & STATE
--=====================================================================
local CONFIG_FILE = "VeniceSpeedSuite.json"
local MAX_ZONES   = 40

local DEFAULT_BLACKLIST = {
    "door", "gate", "exit", "entrance",
    "sleep", "bed", "sit", "chair", "seat",
    "menu", "shop", "buy", "purchase", "sell",
    "radio", "tv", "television", "stereo",
    "toilet", "sink", "shower", "bath",
    "trash", "bin", "garbage",
}

local DEFAULTS = {
    player  = { enabled = false, speed = 34, jumpEnabled = false, jump = 50 },
    vehicle = { enabled = false, maxSpeed = 130, accel = 110, brake = 190, assist = true },
    limits  = { enabled = false, global = 110, zones = {} },
    job     = {
        enabled   = false,
        mode      = "aggressive",     -- "aggressive" | "keyword"
        interval  = 0.1,
        radius    = 15,
        cooldown  = 0.6,
        firePrompts = true,
        fireClicks  = true,
        useBlacklist = true,
        blacklist = DEFAULT_BLACKLIST,
        keywords  = {
            "dough", "sauce", "cheese", "pepperoni", "topping", "oven",
            "bake", "cook", "cut", "slice", "box", "package", "order",
            "deliver", "pizza", "knead", "prepare", "serve", "grab",
            "take", "put", "flatten", "roll",
        },
    },
    ui = { accent = Color3.fromRGB(94, 141, 255), keybind = Enum.KeyCode.K },
}

local function deepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and deepCopy(v) or v end
    return o
end

local state = deepCopy(DEFAULTS)

--=====================================================================
-- FILESYSTEM
--=====================================================================
local fs = { has = false }
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

local function clampNum(v, f, mn, mx)
    if type(v) ~= "number" or v ~= v then return f end
    return math.clamp(v, mn, mx)
end

local function loadConfig()
    if not fs.has then return end
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
        if j.mode == "keyword" or j.mode == "aggressive" then state.job.mode = j.mode end
        state.job.interval = clampNum(j.interval, 0.1, 0.05, 3)
        state.job.radius   = clampNum(j.radius, 15, 2, 80)
        state.job.cooldown = clampNum(j.cooldown, 0.6, 0.1, 10)
        if type(j.firePrompts) == "boolean" then state.job.firePrompts = j.firePrompts end
        if type(j.fireClicks) == "boolean" then state.job.fireClicks = j.fireClicks end
        if type(j.useBlacklist) == "boolean" then state.job.useBlacklist = j.useBlacklist end
        if type(j.keywords) == "table" then
            local out = {}
            for _, w in ipairs(j.keywords) do
                if type(w) == "string" and #w > 0 then table.insert(out, w:lower()) end
            end
            if #out > 0 then state.job.keywords = out end
        end
        if type(j.blacklist) == "table" then
            local out = {}
            for _, w in ipairs(j.blacklist) do
                if type(w) == "string" and #w > 0 then table.insert(out, w:lower()) end
            end
            state.job.blacklist = out
        end
    end
    if type(d.ui) == "table" then
        if type(d.ui.accent) == "table" then
            local okc, col = pcall(Color3.fromRGB,
                d.ui.accent[1] or 94, d.ui.accent[2] or 141, d.ui.accent[3] or 255)
            if okc then state.ui.accent = col end
        end
        if type(d.ui.keybind) == "string" then
            local oke, k = pcall(function() return Enum.KeyCode[d.ui.keybind] end)
            if oke and k then state.ui.keybind = k end
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
local function track(c) if c then table.insert(connections, c) end; return c end

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
        if k ~= "Parent" then pcall(function() inst[k] = v end) end
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
-- EXECUTOR BRIDGE
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
    Exec.fireprompt     = resolve("fireproximityprompt")
    Exec.fireclick      = resolve("fireclickdetector")
    Exec.getconnections = resolve("getconnections")
    Exec.gethui         = resolve("gethui")
    log(string.format("exec: fireprompt=%s fireclick=%s getconnections=%s",
        tostring(Exec.fireprompt ~= nil),
        tostring(Exec.fireclick ~= nil),
        tostring(Exec.getconnections ~= nil)))
end

--=====================================================================
-- PIZZA MODULE  (from scratch)
--=====================================================================
local Pizza = {
    cache = {
        prompts = {},         -- [ProximityPrompt] = { part, text }
        clicks  = {},         -- [ClickDetector]   = { part, text }
        promptCount = 0,
        clickCount  = 0,
        primed = false,
    },
    cooldowns = {},           -- [instance] = os.clock when last fired
    stats = {
        actions = 0,
        promptFires = 0,
        clickFires = 0,
        failures = 0,
        lastMethod = "-",
        lastTarget = "-",
        lastFireTime = 0,
    },
    detected = {},            -- last scan result for debug view
    lastDebugUpdate = 0,
}

local function pizzaTextFor(inst, part)
    if inst:IsA("ProximityPrompt") then
        local a = inst.ActionText or ""
        local o = inst.ObjectText or ""
        return (a .. " " .. o .. " " .. part.Name):lower()
    end
    return part.Name:lower()
end

local function pizzaCacheAdd(desc)
    if desc:IsA("ProximityPrompt") then
        local par = desc.Parent
        if par and par:IsA("BasePart") and not Pizza.cache.prompts[desc] then
            Pizza.cache.prompts[desc] = { part = par, text = pizzaTextFor(desc, par) }
            Pizza.cache.promptCount += 1
        end
    elseif desc:IsA("ClickDetector") then
        local par = desc.Parent
        if par and par:IsA("BasePart") and not Pizza.cache.clicks[desc] then
            Pizza.cache.clicks[desc] = { part = par, text = par.Name:lower() }
            Pizza.cache.clickCount += 1
        end
    end
end

local function pizzaCacheRemove(desc)
    if Pizza.cache.prompts[desc] then
        Pizza.cache.prompts[desc] = nil
        Pizza.cache.promptCount -= 1
    elseif Pizza.cache.clicks[desc] then
        Pizza.cache.clicks[desc] = nil
        Pizza.cache.clickCount -= 1
    end
end

local function pizzaPrime()
    if Pizza.cache.primed then return end
    Pizza.cache.primed = true
    log("priming pizza cache...")
    task.spawn(function()
        local gen = generation
        local descendants = workspace:GetDescendants()
        local batch = 0
        for i = 1, #descendants do
            if gen ~= generation then return end
            pizzaCacheAdd(descendants[i])
            batch += 1
            if batch >= 400 then
                batch = 0
                task.wait()
            end
        end
        log(string.format("cache primed: %d prompts, %d clicks",
            Pizza.cache.promptCount, Pizza.cache.clickCount))
    end)
    track(workspace.DescendantAdded:Connect(pizzaCacheAdd))
    track(workspace.DescendantRemoving:Connect(pizzaCacheRemove))
end

-- Firing methods
local function pizzaFirePrompt(prompt)
    -- 1: executor method (bypass hold-time, LoS, enabled)
    if Exec.fireprompt then
        local ok = pcall(Exec.fireprompt, prompt, 0)
        if ok then return true, "fireproximityprompt" end
    end
    -- 2: temporarily zero out HoldDuration, then trigger
    local origHold = prompt.HoldDuration
    local okOverride = pcall(function()
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        prompt:InputHoldEnd()
    end)
    pcall(function() prompt.HoldDuration = origHold end)
    if okOverride then return true, "hold-override" end
    -- 3: natural hold
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.delay(prompt.HoldDuration + 0.05, function()
            if prompt and prompt.Parent then
                pcall(function() prompt:InputHoldEnd() end)
            end
        end)
    end)
    return ok, ok and "hold-natural" or "failed"
end

local function pizzaFireClick(cd)
    -- 1: executor method
    if Exec.fireclick then
        local ok = pcall(Exec.fireclick, cd, 0)
        if ok then return true, "fireclickdetector" end
    end
    -- 2: fire via getconnections on MouseClick signal
    if Exec.getconnections then
        local ok, fired = pcall(function()
            local count = 0
            for _, conn in ipairs(Exec.getconnections(cd.MouseClick)) do
                if conn.Function then
                    pcall(conn.Function, LP)
                    count += 1
                elseif conn.Fire then
                    pcall(conn.Fire, conn, LP)
                    count += 1
                end
            end
            return count > 0
        end)
        if ok and fired then return true, "getconnections" end
    end
    return false, "no-method"
end

local function pizzaInBlacklist(text)
    if not state.job.useBlacklist then return false end
    for _, bad in ipairs(state.job.blacklist) do
        if text:find(bad, 1, true) then return true, bad end
    end
    return false
end

local function pizzaMatchesKeyword(text)
    for _, kw in ipairs(state.job.keywords) do
        if text:find(kw, 1, true) then return true, kw end
    end
    return false
end

local function pizzaScan(rootPos)
    local radius = state.job.radius
    local radiusSq = radius * radius
    local found = {}

    if state.job.firePrompts then
        for prompt, info in pairs(Pizza.cache.prompts) do
            if prompt.Parent and info.part.Parent then
                local off = info.part.Position - rootPos
                local d2 = off.X*off.X + off.Y*off.Y + off.Z*off.Z
                if d2 <= radiusSq then
                    table.insert(found, {
                        kind = "prompt", inst = prompt, text = info.text,
                        dist = math.sqrt(d2),
                        display = string.format("[P] %s / %s @ %s",
                            prompt.ActionText or "", prompt.ObjectText or "", info.part.Name),
                    })
                end
            end
        end
    end
    if state.job.fireClicks then
        for cd, info in pairs(Pizza.cache.clicks) do
            if cd.Parent and info.part.Parent then
                local off = info.part.Position - rootPos
                local d2 = off.X*off.X + off.Y*off.Y + off.Z*off.Z
                if d2 <= radiusSq then
                    table.insert(found, {
                        kind = "click", inst = cd, text = info.text,
                        dist = math.sqrt(d2),
                        display = string.format("[C] %s", info.part.Name),
                    })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

local function pizzaFireOne(cand)
    local ok, method
    if cand.kind == "prompt" then
        ok, method = pizzaFirePrompt(cand.inst)
        if ok then Pizza.stats.promptFires += 1 end
    else
        ok, method = pizzaFireClick(cand.inst)
        if ok then Pizza.stats.clickFires += 1 end
    end
    if ok then
        Pizza.stats.actions += 1
        Pizza.stats.lastFireTime = os.clock()
    else
        Pizza.stats.failures += 1
    end
    Pizza.stats.lastMethod = method
    Pizza.stats.lastTarget = cand.display:sub(1, 50)
    return ok
end

local function pizzaTick()
    if not state.job.enabled then return end
    local root = getRoot()
    if not root then return end

    local now = os.clock()
    local found = pizzaScan(root.Position)
    Pizza.detected = found

    if #found == 0 then return end

    local fired = 0
    local maxPerTick = 8  -- fire multiple per tick for speed

    for _, cand in ipairs(found) do
        if fired >= maxPerTick then break end

        -- blacklist check
        local blocked, badword = pizzaInBlacklist(cand.text)
        if blocked then
            cand.skip = "svartlistad: " .. badword
        else
            -- keyword check (only in keyword mode)
            if state.job.mode == "keyword" then
                local matches, kw = pizzaMatchesKeyword(cand.text)
                if not matches then
                    cand.skip = "inget keyword"
                    goto continue
                end
                cand.matchedKw = kw
            end

            -- cooldown check
            local cd = Pizza.cooldowns[cand.inst]
            if cd and now - cd < state.job.cooldown then
                cand.skip = string.format("cooldown %.1fs", state.job.cooldown - (now - cd))
            else
                Pizza.cooldowns[cand.inst] = now
                local ok = pizzaFireOne(cand)
                cand.fireResult = ok and ("OK: " .. Pizza.stats.lastMethod) or ("FAIL: " .. Pizza.stats.lastMethod)
                if ok then fired += 1 end
            end
        end
        ::continue::
    end

    -- cleanup old cooldowns
    if now - (Pizza.lastCleanup or 0) > 15 then
        Pizza.lastCleanup = now
        local kept = {}
        for inst, t in pairs(Pizza.cooldowns) do
            if now - t < 10 then kept[inst] = t end
        end
        Pizza.cooldowns = kept
    end
end

--=====================================================================
-- INPUT (shared drag + slider)
--=====================================================================
local inputState = { drag = false, off = nil, slider = nil }

local function bindSharedInput()
    track(UserInputService.InputChanged:Connect(function(i)
        local move = i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch
        if not move then return end
        if inputState.drag and inputState.off then
            local vp = viewport()
            local w = _G.__VeniceSpeedSuite
            if w and w.win then
                w.win.Position = UDim2.new(0,
                    math.clamp(i.Position.X - inputState.off.X, -340, vp.X - 80),
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
-- VEHICLE  (kept intact from v1.8 - well tested)
--=====================================================================
local rig = {}
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
        and not ar:IsA("Seat") and not ar:IsA("VehicleSeat") then return ar end
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
    return best or model.PrimaryPart
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
    return ok and rig.force ~= nil
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
    local ro = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.vehicleReadout

    if not model then
        if assist.lastSeat ~= nil then resetAssist() end
        if ro then pcall(ro, nil, 0) end
        return
    end

    if assist.lastSeat ~= seat then
        assist.lastSeat = seat
        assist.mode, assist.timer = "detect", 0
        assist.applied, assist.writeTimer, assist.direct, assist.probe = nil, 0, false, 0
        clearAssistRig()
        table.clear(assist.seats)
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("VehicleSeat") then table.insert(assist.seats, d) end
            if #assist.seats >= 20 then break end
        end
        local okP, p = pcall(pickPrimary, model, seat)
        assist.primary = okP and p or nil
        assist.anchored = assist.primary ~= nil and assist.primary.Anchored
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
    local info = string.format("metod: %s | %d saten", method, #assist.seats)

    if not state.vehicle.enabled then
        if rig.force and rig.force.Parent then rig.force.MaxForce = 0 end
        if ro then pcall(ro, model.Name, speed, nil, info) end
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
        if ro then pcall(ro, model.Name, speed, nil, info) end
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
        if ro then pcall(ro, model.Name, speed, nil, info) end
        return
    end

    local fs_ = vel:Dot(fwd)
    local desired = assist.mode == "throttle" and thr * state.vehicle.maxSpeed
        or (fs_ > 0.05 and state.vehicle.maxSpeed
        or fs_ < -0.05 and -state.vehicle.maxSpeed or 0)

    local inc = math.abs(desired) > math.abs(fs_)
    local rate = inc and state.vehicle.accel or state.vehicle.brake
    local step = math.clamp(desired - fs_, -rate * dt, rate * dt)
    local engaged = math.abs(step) > 0.01

    if not assist.direct and ensureRig(primary) then
        rig.force.LineDirection = fwd
        rig.force.LineVelocity  = fs_ + step
        rig.force.MaxForce = engaged and math.max(primary.AssemblyMass * rate * 2, 12000) or 0
    elseif engaged then
        pcall(function()
            primary.AssemblyLinearVelocity = fwd * (fs_ + step) + Vector3.new(0, vel.Y, 0)
        end)
    end

    if ro then pcall(ro, model.Name, speed, assist.mode, info) end
end

--=====================================================================
-- PLAYER
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
    local ro = _G.__VeniceSpeedSuite and _G.__VeniceSpeedSuite.playerReadout
    if ro then pcall(ro, hum.WalkSpeed, lim) end
end

--=====================================================================
-- GUI
--=====================================================================
local WIN_W, WIN_H = 460, 560
local rebuild

local function teardown()
    generation += 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    pcall(clearAssistRig)
    local r = _G.__VeniceSpeedSuite
    if r and r.gui then pcall(function() r.gui:Destroy() end) end
    _G.__VeniceSpeedSuite = nil
end

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
    log("building gui")

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

    -- HEADER
    local header = newInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }, win)

    newInstance("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 15, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Venice Speed Suite",
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

    track(header.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        inputState.drag = true
        inputState.off = Vector2.new(i.Position.X, i.Position.Y) - win.AbsolutePosition
    end))

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
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 900), Visible = false,
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
    local settPage    = tab("Settings", 4)

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
            Size = UDim2.new(1, -90, 0, 14), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.label,
        }, row)
        local valLbl = newInstance("TextLabel", {
            Size = UDim2.new(0, 90, 0, 14),
            Position = UDim2.new(1, -90, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 11, TextColor3 = state.ui.accent,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "",
        }, row)
        local trk = newInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 0, 24),
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
            dot.Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            dot.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
        render()
        track(pill.MouseButton1Click:Connect(function()
            on = not on
            render()
            if cfg.onChanged then pcall(cfg.onChanged, on) end
        end))
        return { set = function(v) on = v; render() end }
    end

    local function button(parent, cfg)
        local b = newInstance("TextButton", {
            Size = cfg.size or UDim2.new(1, -20, 0, 28),
            Position = UDim2.new(0, cfg.x or 10, 0, cfg.y),
            BackgroundColor3 = cfg.danger and Color3.fromRGB(50, 27, 32)
                or (cfg.primary and state.ui.accent or C.track),
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = cfg.danger and C.bad
                or (cfg.primary and Color3.new(1,1,1) or C.text),
            Text = cfg.label,
        }, parent)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
        track(b.MouseButton1Click:Connect(function()
            if cfg.onClick then
                local ok, e = pcall(cfg.onClick)
                if not ok then notify(e, "bad") end
            end
        end))
        return b
    end

    --=================================================================
    -- PLAYER PAGE
    --=================================================================
    do
        local c = card(playerPage, 108, 1)
        label(c, "SPELARE", 8)
        toggle(c, {
            label = "Aktivera spelarjustering", y = 24,
            value = state.player.enabled,
            onChanged = function(v)
                state.player.enabled = v; saveConfig()
                notify(v and "Spelarjustering pa" or "Spelarjustering av", v and "good" or nil)
            end,
        })
        local spd = slider(c, {
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
                spd.set(16); saveConfig()
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

    --=================================================================
    -- VEHICLE PAGE
    --=================================================================
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
                notify(v and "Fordonsjustering pa" or "Fordonsjustering av", v and "good" or nil)
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

    --=================================================================
    -- JOB PAGE (pizza auto-farm v3)
    --=================================================================
    local debugFrame, debugList
    local modeAggBtn, modeKwBtn, statsLbl, cacheLbl

    local function updateModeButtons()
        pcall(function()
            if state.job.mode == "aggressive" then
                modeAggBtn.BackgroundColor3 = state.ui.accent
                modeAggBtn.TextColor3 = Color3.new(1,1,1)
                modeKwBtn.BackgroundColor3 = C.track
                modeKwBtn.TextColor3 = C.text
            else
                modeKwBtn.BackgroundColor3 = state.ui.accent
                modeKwBtn.TextColor3 = Color3.new(1,1,1)
                modeAggBtn.BackgroundColor3 = C.track
                modeAggBtn.TextColor3 = C.text
            end
        end)
    end

    do
        -- Main controls
        local c = card(jobPage, 150, 1)
        label(c, "PIZZA AUTO-FARM", 8)

        toggle(c, {
            label = "Aktivera auto-farm", y = 24, value = state.job.enabled,
            onChanged = function(v)
                state.job.enabled = v
                if v then
                    pizzaPrime()
                    Pizza.stats.actions = 0
                    Pizza.stats.failures = 0
                    Pizza.stats.promptFires = 0
                    Pizza.stats.clickFires = 0
                end
                saveConfig()
                notify(v and "Auto-farm PA - sta vid stationen" or "Auto-farm av",
                    v and "good" or nil)
            end,
        })

        label(c, "LAGE", 56)
        modeAggBtn = button(c, {
            label = "AGGRESSIVE (tryck allt)", x = 10, y = 70,
            size = UDim2.new(0.5, -15, 0, 24),
            onClick = function()
                state.job.mode = "aggressive"; updateModeButtons(); saveConfig()
                notify("Aggressive lage - trycker ALLT inom radien", "good")
            end,
        })
        modeKwBtn = button(c, {
            label = "KEYWORD (filtrerat)",
            x = 230, y = 70,
            size = UDim2.new(0.5, -15, 0, 24),
            onClick = function()
                state.job.mode = "keyword"; updateModeButtons(); saveConfig()
                notify("Keyword lage - bara matchande prompts", "good")
            end,
        })
        updateModeButtons()

        label(c, "", 100)
        slider(c, {
            label = "Sokradie", min = 2, max = 80, step = 1,
            value = state.job.radius, y = 108,
            format = function(x) return x .. " st" end,
            onChanged = function(x) state.job.radius = x; saveConfig() end,
        })
    end

    do
        local c = card(jobPage, 92, 2)
        slider(c, {
            label = "Intervall", min = 0.05, max = 2, step = 0.05,
            value = state.job.interval, y = 8,
            format = function(x) return string.format("%.2fs", x) end,
            onChanged = function(x) state.job.interval = x; saveConfig() end,
        })
        slider(c, {
            label = "Cooldown per prompt", min = 0.1, max = 10, step = 0.1,
            value = state.job.cooldown, y = 48,
            format = function(x) return string.format("%.1fs", x) end,
            onChanged = function(x) state.job.cooldown = x; saveConfig() end,
        })
    end

    do
        local c = card(jobPage, 90, 3)
        toggle(c, {
            label = "Tryck ProximityPrompts", y = 8, value = state.job.firePrompts,
            onChanged = function(v) state.job.firePrompts = v; saveConfig() end,
        })
        toggle(c, {
            label = "Tryck ClickDetectors", y = 32, value = state.job.fireClicks,
            onChanged = function(v) state.job.fireClicks = v; saveConfig() end,
        })
        toggle(c, {
            label = "Anvand svartlista (hoppar dorrar/sangar/osv)",
            y = 56, value = state.job.useBlacklist,
            onChanged = function(v) state.job.useBlacklist = v; saveConfig() end,
        })
    end

    do
        -- Stats card
        local c = card(jobPage, 76, 4)
        label(c, "STATISTIK", 8)
        statsLbl = label(c, "0 aktioner | 0 prompts | 0 clicks", 24, 10, C.text)
        cacheLbl = label(c, "cache: 0 prompts / 0 clicks", 40, 9, C.dim)
        local lastLbl = label(c, "senaste: -", 56, 9, C.dim)
        _G.__VeniceSpeedSuite.pizzaStatsLbls = { stats = statsLbl, cache = cacheLbl, last = lastLbl }
    end

    do
        -- Action buttons
        local c = card(jobPage, 76, 5)
        button(c, {
            label = "FORCE SCAN (ominitiera cache)", y = 8, primary = true,
            onClick = function()
                Pizza.cache.primed = false
                Pizza.cache.prompts = {}
                Pizza.cache.clicks = {}
                Pizza.cache.promptCount = 0
                Pizza.cache.clickCount = 0
                pizzaPrime()
                notify("Scannar om workspace...", "good")
            end,
        })
        button(c, {
            label = "Nollstall stats", x = 10, y = 42,
            size = UDim2.new(0.5, -15, 0, 24),
            onClick = function()
                Pizza.stats.actions = 0
                Pizza.stats.failures = 0
                Pizza.stats.promptFires = 0
                Pizza.stats.clickFires = 0
                Pizza.cooldowns = {}
                notify("Stats nollstalld", "good")
            end,
        })
        button(c, {
            label = "Tryck narmaste manuellt", x = 230, y = 42,
            size = UDim2.new(0.5, -15, 0, 24),
            onClick = function()
                local root = getRoot()
                if not root then return notify("Ingen karaktar", "bad") end
                pizzaPrime()
                task.wait(0.1)
                local found = pizzaScan(root.Position)
                if #found == 0 then return notify("Inga prompts i narheten", "bad") end
                local ok = pizzaFireOne(found[1])
                notify((ok and "OK: " or "FAIL: ") .. Pizza.stats.lastMethod .. " @ " .. found[1].display:sub(1, 30),
                    ok and "good" or "bad")
            end,
        })
    end

    do
        -- Debug list
        local c = card(jobPage, 220, 6)
        label(c, "DETEKTERADE INTERAKTIONER (live)", 8)
        debugFrame = newInstance("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, 192), Position = UDim2.new(0, 10, 0, 22),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.track,
            CanvasSize = UDim2.new(0, 0, 0, 192),
        }, c)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, debugFrame)
        debugList = newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1),
        }, debugFrame)
        newInstance("UIPadding", {
            PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4),
        }, debugFrame)
    end

    do
        -- Keyword editor
        local c = card(jobPage, 90, 7)
        label(c, "NYCKELORD (for keyword-lage)", 8)
        local kb = newInstance("TextBox", {
            Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0, 10, 0, 24),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
            Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
            TextWrapped = true, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = table.concat(state.job.keywords, ", "),
        }, c)
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
                state.job.keywords = out; saveConfig()
                notify(#out .. " nyckelord sparade", "good")
            end
        end))
    end

    do
        -- Blacklist editor
        local c = card(jobPage, 90, 8)
        label(c, "SVARTLISTA (hoppas over, t.ex. 'door, sit, bed')", 8)
        local kb = newInstance("TextBox", {
            Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0, 10, 0, 24),
            BackgroundColor3 = C.panel, BorderSizePixel = 0,
            Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.text,
            TextWrapped = true, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = table.concat(state.job.blacklist, ", "),
        }, c)
        newInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, kb)
        newInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4),
        }, kb)
        track(kb.FocusLost:Connect(function()
            local out = {}
            for w in string.gmatch(kb.Text:lower(), "[^,%s]+") do
                if #w > 0 then table.insert(out, w) end
            end
            state.job.blacklist = out; saveConfig()
            notify(#out .. " svartlistord sparade", "good")
        end))
    end

    do
        -- Guide
        local c = card(jobPage, 100, 9)
        newInstance("TextLabel", {
            Size = UDim2.new(1, -20, 1, -16), Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 9, TextWrapped = true, TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = "GUIDE: 1) Ta ett jobb i Bloxburg (pizza/kassa/etc)  "
                .. "2) Ga narmare stationen  3) Tryck FORCE SCAN om 'cache: 0'  "
                .. "4) Sla pa auto-farm.  Debug-listan visar allt som detekteras - "
                .. "ser du malen dar men inget hander? Tryck 'Tryck narmaste manuellt' "
                .. "for att se vilken fire-metod som funkar. "
                .. "Fungerar inte aggressive lage? Minska radien till 5-8 och sta mitt i stationen.",
        }, c)
    end

    --=================================================================
    -- SETTINGS PAGE
    --=================================================================
    do
        local c = card(settPage, 100, 1)
        label(c, "FARTSGRANSER", 8)
        toggle(c, {
            label = "Tillampa granser", y = 22, value = state.limits.enabled,
            onChanged = function(v) state.limits.enabled = v; saveConfig() end,
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
                    Text = string.format("%s | %dst/s", z.name, z.limit),
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
                    saveConfig(); renderZones()
                end))
            end
        end
        renderZones()
        track(add.MouseButton1Click:Connect(function()
            local root = getRoot()
            if not root then return notify("Ingen karaktar", "bad") end
            if #state.limits.zones >= MAX_ZONES then return notify("Zon-grans", "bad") end
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

    -- min/close
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
            hidden = true; win.Visible = false
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

    --=================================================================
    -- Debug list renderer
    --=================================================================
    local function renderDebug()
        if not debugFrame or not debugFrame.Parent then return end
        for _, ch in ipairs(debugFrame:GetChildren()) do
            if ch:IsA("TextLabel") then ch:Destroy() end
        end
        local found = Pizza.detected
        if #found == 0 then
            newInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.dim,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Inget inom " .. state.job.radius .. " studs.",
            }, debugFrame)
        else
            for i = 1, math.min(#found, 30) do
                local cand = found[i]
                local col = C.text
                local suffix = ""
                if cand.fireResult then
                    if cand.fireResult:find("OK") then col = C.good
                    else col = C.bad end
                    suffix = "  <- " .. cand.fireResult
                elseif cand.skip then
                    col = C.dim
                    suffix = "  (" .. cand.skip .. ")"
                end
                newInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
                    Font = Enum.Font.Code, TextSize = 10, TextColor3 = col,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i,
                    Text = string.format("%.1fm  %s%s", cand.dist, cand.display, suffix),
                }, debugFrame)
            end
            debugFrame.CanvasSize = UDim2.new(0, 0, 0, math.min(#found, 30) * 15 + 10)
        end
    end

    local function updateStatsUI()
        if not statsLbl then return end
        pcall(function()
            statsLbl.Text = string.format("%d aktioner | %d prompts | %d clicks | %d fails",
                Pizza.stats.actions, Pizza.stats.promptFires,
                Pizza.stats.clickFires, Pizza.stats.failures)
            cacheLbl.Text = string.format("cache: %d prompts / %d clicks",
                Pizza.cache.promptCount, Pizza.cache.clickCount)
            local lastLbl = _G.__VeniceSpeedSuite.pizzaStatsLbls.last
            if lastLbl then
                if Pizza.stats.lastFireTime > 0 then
                    lastLbl.Text = string.format("senaste: [%s] %s",
                        Pizza.stats.lastMethod, Pizza.stats.lastTarget)
                end
            end
        end)
    end

    --=================================================================
    -- MAIN LOOPS
    --=================================================================
    log("starting loops")
    selectTab("Player")

    -- Vehicle + player @ 20Hz/15Hz
    task.spawn(function()
        local vA, pA = 0, 0
        while gui.Parent and myGen == generation do
            local dt = task.wait()
            if type(dt) ~= "number" then dt = 1/60 end
            vA += dt; pA += dt
            if pA >= 1/15 then pA = 0; pcall(tickPlayer) end
            if vA >= 1/20 then pcall(tickVehicle, vA, notify); vA = 0 end
        end
    end)

    -- Pizza loop
    task.spawn(function()
        while gui.Parent and myGen == generation do
            task.wait(math.max(state.job.interval, 0.05))
            if state.job.enabled then
                local ok, err = pcall(pizzaTick)
                if not ok then
                    warn("[Venice] pizzaTick: " .. tostring(err))
                    task.wait(1)
                end
            end
        end
    end)

    -- UI update loop (2 Hz)
    task.spawn(function()
        while gui.Parent and myGen == generation do
            task.wait(0.5)
            if jobPage.Visible then
                pcall(renderDebug)
                pcall(updateStatsUI)
            end
        end
    end)

    track(LP.CharacterAdded:Connect(function()
        task.wait(0.6)
        resetAssist()
        Pizza.cooldowns = {}
    end))

    pizzaPrime()
    notify("Venice v" .. VERSION .. " laddad - K visar/gommer", "good")
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
