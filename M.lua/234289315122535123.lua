-- HYPER HUB | Cali Shootout (optimized build, same UI)
local env = (getgenv and getgenv()) or _G
if env._HyperUnload then pcall(env._HyperUnload) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function() Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
    LocalPlayer = LocalPlayer or Players.LocalPlayer
end

-- ===== lifecycle / connection tracking =====
local running = true
local conns = {}
local function track(c) conns[#conns + 1] = c return c end

pcall(function()
    if LocalPlayer then
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoomless
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end
end)

-- ===== character part cache (noclip) =====
local charParts = {}
local function cacheParts(char)
    table.clear(charParts)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then charParts[#charParts + 1] = p end
    end
end
local function noclipStep()
    for i = 1, #charParts do
        local p = charParts[i]
        if p.CanCollide then p.CanCollide = false end
    end
end
if LocalPlayer and LocalPlayer.Character then cacheParts(LocalPlayer.Character) end

-- ===== forward declarations =====
local Window, AimbotSettings, Whitelist, getArmor
local WLset = {}

-- ===== config =====
local CONFIG_FILE = "Singularity_CaliShootout_Config.json"
local DefaultConfig = {
    AutoRobBank = false, AutoServerHop = false, FastCollect = true, FlySpeed = 150,
    GhostFlyEnabled = false, GhostFlySpeed = 50, GhostFlyNoclip = true,
    GodmodeEnabled = false, AntiFallDamage = true, AutoArmor = false, AutoArmorInterval = 10,
    BankESP = false, PlayerESP = false, NameESP = true, HealthESP = true, ToolESP = true,
    DistESP = true, BoxESP = true, TracerESP = true, ESPStyle = "2D", ESPColorName = "Red",
    aimbotEnabled = true, Toggle = false, teamCheck = false, wallCheck = true, lockMode = "Head",
    fov = 150, smoothing = 0.15, predictionFactor = 0.165, showFOV = true, fovFilled = false,
    OrbitAttack = false, OrbitDistance = 15, OrbitSpeed = 3, OrbitHeight = 5,
    Whitelist = {}, AutoSave = true,
}
local ENV_KEYS = {
    "AutoRobBank", "AutoServerHop", "FastCollect", "FlySpeed",
    "GhostFlyEnabled", "GhostFlySpeed", "GhostFlyNoclip", "GodmodeEnabled", "AntiFallDamage",
    "AutoArmor", "AutoArmorInterval",
    "BankESP", "PlayerESP", "NameESP", "HealthESP", "ToolESP", "DistESP", "BoxESP", "TracerESP",
    "ESPStyle", "ESPColorName",
    "OrbitAttack", "OrbitDistance", "OrbitSpeed", "OrbitHeight",
}
local AIM_KEYS = {
    "aimbotEnabled", "Toggle", "teamCheck", "wallCheck", "lockMode",
    "fov", "smoothing", "predictionFactor", "showFOV", "fovFilled",
}
local ConfigState = {}
for k, v in pairs(DefaultConfig) do ConfigState[k] = v end

local function LoadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local content = readfile(CONFIG_FILE)
            if content and content ~= "" then
                local decoded = HttpService:JSONDecode(content)
                if type(decoded) == "table" then
                    for k, v in pairs(decoded) do ConfigState[k] = v end
                end
            end
        end
    end)
    for _, k in ipairs(ENV_KEYS) do env[k] = ConfigState[k] end
    env.AutoArmor = env.AutoArmor or false
    env.AutoArmorInterval = env.AutoArmorInterval or 10
    env.ESPColorName = env.ESPColorName or "Red"
    -- these always start off (same as the original behaviour)
    env.GhostFlyEnabled = false
    env.GodmodeEnabled = false
    env.AutoArmor = false
    env.OrbitAttack = false
    if AimbotSettings then
        for _, k in ipairs(AIM_KEYS) do AimbotSettings[k] = ConfigState[k] end
    end
end
LoadConfig()

AimbotSettings = {
    teamCheck = ConfigState.teamCheck, fov = ConfigState.fov, smoothing = ConfigState.smoothing,
    predictionFactor = ConfigState.predictionFactor, aimbotEnabled = ConfigState.aimbotEnabled,
    Toggle = ConfigState.Toggle, toggleKey = Enum.KeyCode.E, toggleKeyName = "E",
    lockMode = ConfigState.lockMode, wallCheck = ConfigState.wallCheck, maxWallDistance = 1000,
    showFOV = ConfigState.showFOV, fovFilled = ConfigState.fovFilled, fovThickness = 2,
    fovColor = Color3.fromRGB(255, 50, 50),
}
Whitelist = (type(ConfigState.Whitelist) == "table" and ConfigState.Whitelist) or {}
local function rebuildWL()
    table.clear(WLset)
    for _, n in ipairs(Whitelist) do WLset[n:lower()] = true end
end
rebuildWL()

local saveDebounce = false
local function SaveConfig()
    if not writefile then return end
    if not (ConfigState.AutoSave == nil or ConfigState.AutoSave == true) then return end
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.4, function()
        pcall(function()
            for _, k in ipairs(ENV_KEYS) do ConfigState[k] = env[k] end
            ConfigState.ESPColorName = env.ESPColorName or "Red"
            for _, k in ipairs(AIM_KEYS) do ConfigState[k] = AimbotSettings[k] end
            ConfigState.Whitelist = Whitelist
            writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigState))
        end)
        saveDebounce = false
    end)
end

local function notify(title, desc, t)
    if not Window then return end
    pcall(function()
        Window:Notify({ Title = title, Desc = desc, Description = desc, Time = t or 3, Lifetime = t or 3 })
    end)
end

-- ===== bank helpers =====
local robbedBanks = {}

local function getBankState(bank)
    local ld = bank:FindFirstChild("LaserDisabler")
    local main = ld and ld:FindFirstChild("Main")
    if main then
        local c = main.Color
        local r, g, b = math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)
        if r == 255 and g == 0 and b == 0 then return "READY", main
        elseif r == 0 and g == 170 and b == 0 then return "ROBBABLE", main
        else return "COOLDOWN", main end
    end
    return "NONE", nil
end

local function getBanks()
    local banks = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Bank" then
            banks[#banks + 1] = child
            local state = getBankState(child)
            if state == "COOLDOWN" or state == "NONE" then robbedBanks[child] = nil end
        end
    end
    return banks
end

local function flyTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    if #charParts == 0 then cacheParts(char) end

    humanoid.PlatformStand = true
    local old = hrp:FindFirstChild("GhostFlyVelocity"); if old then old:Destroy() end
    old = hrp:FindFirstChild("GhostFlyGyro"); if old then old:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "GhostFlyVelocity"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "GhostFlyGyro"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 3000; bg.D = 500
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    local speed = env.FlySpeed or 100
    local targetPos = targetCFrame.Position
    local startTime = tick()
    local timeout = ((targetPos - hrp.Position).Magnitude / speed) + 5
    local stepConn = RunService.Stepped:Connect(noclipStep)

    while running and hrp.Parent and env.AutoRobBank do
        local delta = targetPos - hrp.Position
        if delta.Magnitude < 5 or (tick() - startTime) > timeout then break end
        bv.Velocity = delta.Unit * speed
        bg.CFrame = CFrame.new(hrp.Position, targetPos)
        task.wait()
    end

    stepConn:Disconnect()
    bv:Destroy(); bg:Destroy()
    humanoid.PlatformStand = false
    if hrp.Parent then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

-- ===== UI cleanup + loading (cached) =====
local REPO = "https://raw.githubusercontent.com/projecthyper10-stack/HYPER-UI/refs/heads/main/"

pcall(function()
    for _, holder in ipairs({ env, _G }) do
        local g = holder._MacLibScreenGui
        if g and typeof(g) == "Instance" then pcall(function() g:Destroy() end) end
        holder._MacLibScreenGui = nil
    end
    local containers = {}
    if typeof(gethui) == "function" then pcall(function() table.insert(containers, gethui()) end) end
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    if LocalPlayer:FindFirstChild("PlayerGui") then table.insert(containers, LocalPlayer.PlayerGui) end
    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") and (child.Name == "MacLibScreenGui"
                    or (child:FindFirstChild("Base") and child.Base:FindFirstChild("Sidebar"))
                    or child:FindFirstChild("Breadcrumb")) then
                    child:Destroy()
                end
            end
        end)
    end
end)

-- Key verification (optional avatar / username)
local KeyAvatarURL = env.KeyAvatar

-- disk cache for UI libs with fresh GitHub sync.
local function fetchCached(name)
    if typeof(isfile) == "function" then
        if isfile(name) then return readfile(name) end
        local mac = "Maclib/" .. name
        if isfile(mac) then return readfile(mac) end
    end
    local can = typeof(isfile) == "function" and typeof(writefile) == "function" and typeof(readfile) == "function"
    local path, stamp = "HYPER_Cache/" .. name, "HYPER_Cache/" .. name .. ".t"
    
    local ok, code = pcall(function() return game:HttpGet(REPO .. name .. "?t=" .. tostring(os.time())) end)
    if ok and code and #code > 0 then
        if can then pcall(function()
            if makefolder and isfolder and not isfolder("HYPER_Cache") then makefolder("HYPER_Cache") end
            writefile(path, code)
            writefile(stamp, tostring(os.time()))
        end) end
        return code
    end
    if can and isfile(path) then return readfile(path) end -- stale fallback
    error("download failed: " .. name)
end

pcall(function()
    local f = loadstring(fetchCached("icon.lua"))
    if f then
        local ok, result = pcall(f)
        if ok and result then _G._MacLibIconEngine = result end
    end
end)

local MacLib
local okLoad, resLoad = pcall(function()
    local func, err = loadstring(fetchCached("ui-main.lua"))
    if not func then error("[ui-main.lua Compile Error]: " .. tostring(err)) end
    local ok, result = pcall(func)
    if not ok then error("[ui-main.lua Runtime Error]: " .. tostring(result)) end
    return result
end)
if okLoad and resLoad then MacLib = resLoad else warn("[MacLib] Failed to load: " .. tostring(resLoad)) return end

local SCRIPT_VERSION = "v1.0"

Window = MacLib:Window({
    Title = "HYPER HUB", Subtitle = "Cali Shootout", Version = SCRIPT_VERSION,
    Logo = "rbxassetid://108952102602834", Size = UDim2.fromOffset(710, 450), DragStyle = 1,
    SidebarMinSize = 50, SidebarMaxSize = 250, DisabledWindowControls = {}, ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl, AccentColor = Color3.fromRGB(29, 235, 169),
    WindowControlSize = 12, Transparency = 0.2, AcrylicBlur = false,
})

Window:GlobalSetting({ Name = "UI Blur", Default = Window:GetAcrylicBlurState(), Callback = function(b) Window:SetAcrylicBlurState(b) end })
Window:GlobalSetting({ Name = "Notifications", Default = Window:GetNotificationsState(), Callback = function(b) Window:SetNotificationsState(b) end })

local tabGroups = {
    General = Window:TabGroup("General"), Combat = Window:TabGroup("Combat"),
    Farming = Window:TabGroup("Farming"), Visuals = Window:TabGroup("Visuals"),
    Movement = Window:TabGroup("Movement & World"), SettingsGroup = Window:TabGroup("Settings"),
}
local tabs = {
    Home = tabGroups.General:Tab({ Name = "Home", Icon = "lucide-home" }),
    Aimbot = tabGroups.Combat:Tab({ Name = "Aimbot", Icon = "lucide-crosshair" }),
    Whitelist = tabGroups.Combat:Tab({ Name = "Whitelist", Icon = "lucide-users" }),
    Farm = tabGroups.Farming:Tab({ Name = "Auto Farm", Icon = "lucide-zap" }),
    ESP = tabGroups.Visuals:Tab({ Name = "ESP", Icon = "lucide-eye" }),
    Player = tabGroups.Movement:Tab({ Name = "Player", Icon = "lucide-user" }),
    Teleport = tabGroups.Movement:Tab({ Name = "Teleport", Icon = "lucide-map-pin" }),
    UISettings = tabGroups.SettingsGroup:Tab({ Name = "UI Settings", Icon = "lucide-settings" }),
}
local sections = {
    HomeWelcome = tabs.Home:Section({ Name = "Welcome", Side = "Left" }),
    HomeStats = tabs.Home:Section({ Name = "System Information", Side = "Right" }),
    AimbotMain = tabs.Aimbot:Section({ Name = "Main Settings", Side = "Left" }),
    AimbotTargeting = tabs.Aimbot:Section({ Name = "Targeting Rules", Side = "Right" }),
    AimbotAccuracy = tabs.Aimbot:Section({ Name = "Accuracy & Prediction", Side = "Left" }),
    AimbotVisuals = tabs.Aimbot:Section({ Name = "FOV Visuals", Side = "Right" }),
    WhitelistConfig = tabs.Whitelist:Section({ Name = "Whitelist Configuration", Side = "Left" }),
    WhitelistManage = tabs.Whitelist:Section({ Name = "Whitelist Management", Side = "Right" }),
    FarmMain = tabs.Farm:Section({ Name = "Bank Robbery Automation", Side = "Left" }),
    FarmHop = tabs.Farm:Section({ Name = "Server Hop", Side = "Right" }),
    PlayerFlight = tabs.Player:Section({ Name = "Ghost Flight", Side = "Left" }),
    PlayerDefense = tabs.Player:Section({ Name = "Godmode & Defense", Side = "Right" }),
    ESPMain = tabs.ESP:Section({ Name = "Master ESP", Side = "Left" }),
    ESPElements = tabs.ESP:Section({ Name = "Player Elements", Side = "Left" }),
    ESPCustom = tabs.ESP:Section({ Name = "Visual Customization", Side = "Right" }),
    TeleportPlayers = tabs.Teleport:Section({ Name = "Player Teleport", Side = "Left" }),
    TeleportOrbit = tabs.Teleport:Section({ Name = "Orbit & Attack", Side = "Right" }),
    SettingsMain = tabs.UISettings:Section({ Name = "Appearance & Controls", Side = "Left" }),
    SettingsConfig = tabs.UISettings:Section({ Name = "Configuration Manager", Side = "Right" }),
}

-- UI builders (remove repetition)
local function envToggle(sec, name, desc, key, id, extra)
    sec:Toggle({ Name = name, Description = desc, Default = env[key], Callback = function(v)
        env[key] = v
        if extra then extra(v) end
        SaveConfig()
    end }, id)
end
local function envSlider(sec, name, desc, mn, mx, key, fallback, id)
    sec:Slider({ Name = name, Description = desc, Minimum = mn, Maximum = mx, Precision = 0,
        DisplayMethod = "Value", Default = env[key] or fallback, Callback = function(v)
            env[key] = v
            SaveConfig()
        end }, id)
end

-- ===== Home =====
sections.HomeWelcome:Label({ Text = "Welcome, " .. (LocalPlayer.DisplayName or "User") .. "!" })
sections.HomeWelcome:SubLabel({ Text = "Thanks for using HYPER HUB - Cali Shootout" })
local function stat(label, value) sections.HomeStats:Label({ Text = label }) return sections.HomeStats:SubLabel({ Text = value }) end
stat("User", env.KeyUsername or LocalPlayer.Name)
stat("Executor", (identifyexecutor and identifyexecutor()) or "Unknown")
stat("Script Version", SCRIPT_VERSION)
stat("UI Version", tostring(MacLib.Version or "v2.0"))
stat("Device / Platform", UIS.TouchEnabled and "Mobile / Touch" or "Windows / PC")
local timeSub = stat("Current Time", os.date("%X"))
task.spawn(function()
    while running and task.wait(1) do
        pcall(function()
            if timeSub.SetText then timeSub:SetText(os.date("%X"))
            elseif timeSub.SetDesc then timeSub:SetDesc(os.date("%X")) end
        end)
    end
end)

-- ===== Server hop =====
local isHopping = false
local function serverHop()
    if isHopping then return end
    isHopping = true
    notify("Auto Server Hop", "Finding new server...", 4)

    task.spawn(function()
        local placeId, currentJobId = game.PlaceId, game.JobId
        local ok, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"))
        end)
        local targetJob
        if ok and result and result.data then
            local valid = {}
            for _, s in ipairs(result.data) do
                if type(s) == "table" and s.id and s.id ~= currentJobId and s.playing and s.maxPlayers
                    and s.playing < s.maxPlayers and s.playing > 1 then
                    valid[#valid + 1] = s.id
                end
            end
            if #valid > 0 then targetJob = valid[math.random(1, #valid)] end
        end
        if targetJob then
            notify("Server Found", "Teleporting to server (" .. tostring(targetJob):sub(1, 8) .. ")...", 5)
            task.wait(1.5)
            TeleportService:TeleportToPlaceInstance(placeId, targetJob, LocalPlayer)
        else
            notify("Server Hop", "Connecting to new server instance...", 5)
            task.wait(1.5)
            TeleportService:Teleport(placeId, LocalPlayer)
        end
        task.wait(15)
        isHopping = false
    end)
end

-- ===== Ghost fly =====
env.GhostFlyKey = Enum.KeyCode.X
local ghostFlyVelocity, ghostFlyGyro, ghostRenderConn, ghostSteppedConn
local ghostKeys = { W = false, A = false, S = false, D = false, Space = false, LeftShift = false }

local function stopGhostFly()
    if ghostRenderConn then ghostRenderConn:Disconnect() ghostRenderConn = nil end
    if ghostSteppedConn then ghostSteppedConn:Disconnect() ghostSteppedConn = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("GhostFlyVelocity_Manual"); if bv then bv:Destroy() end
            local bg = hrp:FindFirstChild("GhostFlyGyro_Manual"); if bg then bg:Destroy() end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function startGhostFly()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    if #charParts == 0 then cacheParts(char) end

    ghostFlyVelocity = Instance.new("BodyVelocity")
    ghostFlyVelocity.Name = "GhostFlyVelocity_Manual"
    ghostFlyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    ghostFlyVelocity.Velocity = Vector3.zero
    ghostFlyVelocity.Parent = hrp

    ghostFlyGyro = Instance.new("BodyGyro")
    ghostFlyGyro.Name = "GhostFlyGyro_Manual"
    ghostFlyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    ghostFlyGyro.P = 3000; ghostFlyGyro.D = 500
    ghostFlyGyro.CFrame = workspace.CurrentCamera.CFrame
    ghostFlyGyro.Parent = hrp

    ghostRenderConn = RunService.RenderStepped:Connect(function()
        if not env.GhostFlyEnabled then return end
        local cam = workspace.CurrentCamera
        local cf = cam.CFrame
        local d = Vector3.zero
        if ghostKeys.W then d += cf.LookVector end
        if ghostKeys.S then d -= cf.LookVector end
        if ghostKeys.A then d -= cf.RightVector end
        if ghostKeys.D then d += cf.RightVector end
        d += Vector3.new(0, (ghostKeys.Space and 1 or 0) - (ghostKeys.LeftShift and 1 or 0), 0)
        if d.Magnitude > 0 then d = d.Unit end
        if ghostFlyVelocity.Parent then ghostFlyVelocity.Velocity = d * (env.GhostFlySpeed or 50) end
        if ghostFlyGyro.Parent then ghostFlyGyro.CFrame = cf end
    end)

    ghostSteppedConn = RunService.Stepped:Connect(function()
        if env.GhostFlyEnabled and env.GhostFlyNoclip then noclipStep() end
    end)
end

local function toggleGhostFly(state)
    env.GhostFlyEnabled = state
    stopGhostFly()
    if state then
        startGhostFly()
        notify("Ghost Fly", "Ghost Fly Enabled (WASD + Space/Shift)")
    else
        notify("Ghost Fly", "Ghost Fly Disabled")
    end
end

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local n = input.KeyCode.Name
    if ghostKeys[n] ~= nil then ghostKeys[n] = true end
    if input.KeyCode == (env.GhostFlyKey or Enum.KeyCode.X) then
        toggleGhostFly(not env.GhostFlyEnabled)
    end
end))
track(UIS.InputEnded:Connect(function(input)
    local n = input.KeyCode.Name
    if ghostKeys[n] ~= nil then ghostKeys[n] = false end
end))

-- ===== Godmode =====
local godmodeConn
local function applyGodmode(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    if godmodeConn then godmodeConn:Disconnect() godmodeConn = nil end
    if env.GodmodeEnabled then
        godmodeConn = hum.HealthChanged:Connect(function(h)
            if env.GodmodeEnabled and h < hum.MaxHealth and h > 0 then hum.Health = hum.MaxHealth end
        end)
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end
end

local function toggleGodmode(state)
    env.GodmodeEnabled = state
    local char = LocalPlayer.Character
    if state then
        applyGodmode(char)
        notify("Godmode", "Godmode Enabled (Health Lock & Anti-Ragdoll)")
    else
        if godmodeConn then godmodeConn:Disconnect() godmodeConn = nil end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
        notify("Godmode", "Godmode Disabled")
    end
end

track(LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    cacheParts(newChar)
    if env.GodmodeEnabled then applyGodmode(newChar) end
    if env.AutoArmor then task.wait(0.5) getArmor(true) end
end))

-- ===== Auto armor =====
local armorCFrame = CFrame.new(-1439.97827, -81.8992996, 204.404205, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local armorPos = armorCFrame.Position
local isGettingArmor = false

local function promptFromGiver(item)
    local belt = item:FindFirstChild("Belt")
    local giver = belt and belt:FindFirstChild("Giver")
    local p = giver and (giver:FindFirstChildOfClass("ProximityPrompt") or giver:FindFirstChild("ProximityPrompt"))
    if p and p.Enabled then return p end
end

local function getArmorPrompt()
    local other = workspace:FindFirstChild("OtherItems")
    if other then
        local kids = other:GetChildren()
        local p = kids[180] and promptFromGiver(kids[180])
        if p then return p end
        for _, item in ipairs(kids) do
            p = promptFromGiver(item)
            if p then return p end
        end
    end
    for _, d in ipairs((other or workspace):GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled and d.Parent and d.Parent:IsA("BasePart")
            and (d.Parent.Position - armorPos).Magnitude <= 35 then
            return d
        end
    end
end

local function firePromptInstant(prompt)
    if not prompt then return end
    local oldHold = prompt.HoldDuration
    prompt.HoldDuration = 0
    if fireproximityprompt then
        fireproximityprompt(prompt, 0)
    else
        prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd()
    end
    task.wait(0.1)
    prompt.HoldDuration = oldHold
end

getArmor = function(silent)
    if isGettingArmor then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    isGettingArmor = true
    local orig = hrp.CFrame
    local success = false
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = armorCFrame
        task.wait(0.12)
        local prompt = getArmorPrompt()
        if prompt then
            firePromptInstant(prompt); success = true
        else
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled and d.Parent and d.Parent:IsA("BasePart")
                    and (d.Parent.Position - hrp.Position).Magnitude <= (d.MaxActivationDistance + 5) then
                    firePromptInstant(d); success = true
                    break
                end
            end
        end
        task.wait(0.1)
        if hrp.Parent then
            hrp.CFrame = orig
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    isGettingArmor = false
    if not silent then
        notify("Armor", success and "Equipped armor & returned to origin"
            or "Warped & returned (Armor prompt not found or on cooldown)")
    end
end

task.spawn(function()
    while running do
        task.wait(env.AutoArmorInterval or 10)
        if env.AutoArmor and not isGettingArmor then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local armorVal = char:FindFirstChild("Armor") or char:FindFirstChild("ArmorValue")
                local hasBelt = char:FindFirstChild("Belt") or char:FindFirstChild("Armor") or char:FindFirstChild("Vest")
                local need
                if armorVal and armorVal:IsA("ValueBase") then need = armorVal.Value <= 0 else need = not hasBelt end
                if need then getArmor(true) end
            end
        end
    end
end)

-- ===== Aimbot =====
local currentTarget
local aimbotToggleState = false
local aimCam = workspace.CurrentCamera

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local lastFilterChar

local FOVring
pcall(function()
    FOVring = Drawing.new("Circle")
    FOVring.Visible = AimbotSettings.showFOV
    FOVring.Thickness = AimbotSettings.fovThickness
    FOVring.Radius = AimbotSettings.fov
    FOVring.Transparency = 0.8
    FOVring.Color = AimbotSettings.fovColor
    FOVring.Filled = AimbotSettings.fovFilled
    FOVring.Position = Vector2.new(aimCam.ViewportSize.X / 2, aimCam.ViewportSize.Y / 2)
end)

local function isWhitelisted(player) return WLset[player.Name:lower()] == true end

local function isTargetVisible(pos)
    if not AimbotSettings.wallCheck then return true end
    local origin = aimCam.CFrame.Position
    local delta = pos - origin
    local char = LocalPlayer.Character
    if char ~= lastFilterChar then
        lastFilterChar = char
        if char then rayParams.FilterDescendantsInstances = { char } end
    end
    local result = workspace:Raycast(origin, delta.Unit * math.min(delta.Magnitude, AimbotSettings.maxWallDistance), rayParams)
    if not result then return true end
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local RANDOM_PARTS = { "Head", "UpperTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }
local function getTargetPart(player)
    local char = player and player.Character
    if not char then return nil end
    local mode = AimbotSettings.lockMode
    if mode == "Random" then
        local avail = {}
        for _, n in ipairs(RANDOM_PARTS) do
            local p = char:FindFirstChild(n)
            if p then avail[#avail + 1] = p end
        end
        if #avail > 0 then return avail[math.random(1, #avail)] end
    end
    if mode == "Head" then return char:FindFirstChild("Head")
    elseif mode == "Torso" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    elseif mode == "LeftArm" then return char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("LeftLowerArm")
    elseif mode == "RightArm" then return char:FindFirstChild("RightUpperArm") or char:FindFirstChild("RightLowerArm")
    elseif mode == "LeftLeg" then return char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("LeftLowerLeg")
    elseif mode == "RightLeg" then return char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("RightLowerLeg")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestPlayer()
    if not LocalPlayer.Character then return nil end
    local best, bestDist = nil, AimbotSettings.fov
    local vs = aimCam.ViewportSize
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and not (AimbotSettings.teamCheck and player.Team == LocalPlayer.Team)
            and not isWhitelisted(player) then
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local sp, on = aimCam:WorldToViewportPoint(hrp.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= bestDist and isTargetVisible(hrp.Position) then
                        bestDist, best = d, player
                    end
                end
            end
        end
    end
    return best
end

local searchTick = 0
local function updateAimbot()
    if not AimbotSettings.aimbotEnabled then currentTarget = nil return end
    if AimbotSettings.Toggle and not aimbotToggleState then currentTarget = nil return end
    aimCam = workspace.CurrentCamera

    local keep = false
    local char = currentTarget and currentTarget.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then
            local _, on = aimCam:WorldToViewportPoint(hrp.Position)
            keep = on
        end
    end
    if not keep then
        currentTarget = nil
        searchTick += 1
        if searchTick % 3 == 0 then currentTarget = getClosestPlayer() end
    end
    if not currentTarget then return end

    local part = getTargetPart(currentTarget)
    if not part or not isTargetVisible(part.Position) then currentTarget = nil return end

    local camPos = aimCam.CFrame.Position
    local dist = (part.Position - camPos).Magnitude
    local aimPos = part.Position + part.AssemblyLinearVelocity * (dist / 1000) * AimbotSettings.predictionFactor
    local cur = aimCam.CFrame
    aimCam.CFrame = cur:Lerp(CFrame.new(cur.Position, aimPos), AimbotSettings.smoothing)
end

-- Aimbot UI
sections.AimbotMain:Toggle({ Name = "Enable Aimbot", Description = "Enable camera aimbot assistance",
    Default = AimbotSettings.aimbotEnabled, Callback = function(v) AimbotSettings.aimbotEnabled = v SaveConfig() end }, "AimbotEnabled")
sections.AimbotMain:Toggle({ Name = "Keybind Mode", Description = "Use keybind to activate/deactivate aimbot",
    Default = AimbotSettings.Toggle, Callback = function(v) AimbotSettings.Toggle = v SaveConfig() end }, "AimbotToggleMode")
sections.AimbotMain:Keybind({ Name = "Target Key", Description = "Aimbot toggle keybind",
    Default = AimbotSettings.toggleKey or Enum.KeyCode.E,
    onBinded = function(key) AimbotSettings.toggleKey = key end,
    Callback = function(key)
        AimbotSettings.toggleKey = key
        if AimbotSettings.Toggle then
            aimbotToggleState = not aimbotToggleState
            notify("Aimbot", aimbotToggleState and "ACTIVATED" or "DEACTIVATED", 2)
        end
    end }, "AimbotKeybind")

sections.AimbotTargeting:Toggle({ Name = "Team Check", Description = "Don't aim at teammates",
    Default = AimbotSettings.teamCheck, Callback = function(v) AimbotSettings.teamCheck = v SaveConfig() end }, "AimbotTeamCheck")
sections.AimbotTargeting:Toggle({ Name = "Wall Check", Description = "Line of sight check through walls",
    Default = AimbotSettings.wallCheck, Callback = function(v) AimbotSettings.wallCheck = v SaveConfig() end }, "AimbotWallCheck")
sections.AimbotTargeting:Dropdown({ Name = "Target Part", Description = "Target body part to aim at",
    Options = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Random" },
    Default = AimbotSettings.lockMode or "Head", Callback = function(c) AimbotSettings.lockMode = c SaveConfig() end }, "AimbotLockMode")

sections.AimbotAccuracy:Slider({ Name = "FOV Radius", Description = "Aimbot detection radius", Minimum = 50, Maximum = 300,
    Precision = 0, DisplayMethod = "Value", Default = AimbotSettings.fov or 150,
    Callback = function(v) AimbotSettings.fov = v if FOVring then FOVring.Radius = v end SaveConfig() end }, "AimbotFOV")
sections.AimbotAccuracy:Slider({ Name = "Smoothness", Description = "Aimbot smoothing (lower is faster)", Minimum = 1, Maximum = 50,
    Precision = 0, DisplayMethod = "Value", Default = math.floor((AimbotSettings.smoothing or 0.15) * 100),
    Callback = function(v) AimbotSettings.smoothing = v / 100 SaveConfig() end }, "AimbotSmoothing")
sections.AimbotAccuracy:Slider({ Name = "Prediction", Description = "Target movement prediction factor", Minimum = 0, Maximum = 30,
    Precision = 0, DisplayMethod = "Value", Default = math.floor((AimbotSettings.predictionFactor or 0.165) * 100),
    Callback = function(v) AimbotSettings.predictionFactor = v / 100 SaveConfig() end }, "AimbotPrediction")

sections.AimbotVisuals:Toggle({ Name = "Draw FOV Circle", Description = "Draw circle around cursor indicating FOV",
    Default = AimbotSettings.showFOV, Callback = function(v) AimbotSettings.showFOV = v if FOVring then FOVring.Visible = v end SaveConfig() end }, "AimbotShowFOV")
sections.AimbotVisuals:Toggle({ Name = "Fill FOV Area", Description = "Fill interior area of FOV circle",
    Default = AimbotSettings.fovFilled, Callback = function(v) AimbotSettings.fovFilled = v if FOVring then FOVring.Filled = v end SaveConfig() end }, "AimbotFillFOV")

-- ===== Whitelist UI =====
local function playerNames()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then list[#list + 1] = p.Name end
    end
    if #list == 0 then list = { "(No Players)" } end
    return list
end

local function addToWhitelist(name)
    name = name:match("^%s*(.-)%s*$")
    if name == "" or WLset[name:lower()] then return false end
    table.insert(Whitelist, name); rebuildWL(); SaveConfig()
    return true
end
local function removeFromWhitelist(name)
    local l = name:lower()
    for i, n in ipairs(Whitelist) do
        if n:lower() == l then table.remove(Whitelist, i); rebuildWL(); SaveConfig() return true end
    end
    return false
end

local wlList = playerNames()
local selectedPlayerName = wlList[1]
sections.WhitelistConfig:Dropdown({ Name = "Select Player", Description = "Select from online players to ignore in aimbot",
    Options = wlList, Default = 1, Callback = function(c) selectedPlayerName = c end }, "WhitelistSelectPlayer")
sections.WhitelistConfig:Button({ Name = "Add Selected Player", Description = "Add selected player to Whitelist",
    Callback = function()
        if not selectedPlayerName or selectedPlayerName == "(No Players)" then return end
        notify("Whitelist", addToWhitelist(selectedPlayerName) and ("Added " .. selectedPlayerName)
            or (selectedPlayerName .. " is already in list"))
    end })
sections.WhitelistConfig:Button({ Name = "Remove Selected Player", Description = "Remove selected player from Whitelist",
    Callback = function()
        if not selectedPlayerName or selectedPlayerName == "(No Players)" then return end
        notify("Whitelist", removeFromWhitelist(selectedPlayerName) and ("Removed " .. selectedPlayerName)
            or (selectedPlayerName .. " is not in list"))
    end })
sections.WhitelistManage:Button({ Name = "View Whitelist", Description = "Show all whitelisted player names",
    Callback = function()
        if #Whitelist == 0 then notify("Whitelist", "No names in whitelist yet")
        else notify("Whitelist (" .. #Whitelist .. " players)", table.concat(Whitelist, ", "), 5) end
    end })
sections.WhitelistManage:Button({ Name = "Clear Whitelist", Description = "Clear all whitelisted player names",
    Callback = function()
        table.clear(Whitelist); rebuildWL(); SaveConfig()
        notify("Whitelist", "Cleared all names")
    end })

-- ===== Auto farm UI =====
envToggle(sections.FarmMain, "Auto Rob Bank", "Fly to bank, disable lasers, and collect cash automatically", "AutoRobBank", "AutoRobBank")
envToggle(sections.FarmMain, "Fast Collect", "Instantly trigger proximity prompts without hold delay", "FastCollect", "FastCollect")
envSlider(sections.FarmMain, "Auto Rob Fly Speed", "Adjust flying speed for bank robbery navigation", 50, 300, "FlySpeed", 150, "AutoRobFlySpeed")
envToggle(sections.FarmHop, "Auto Server Hop", "Auto hop server when all banks are robbed / on cooldown", "AutoServerHop", "AutoServerHop")
sections.FarmHop:Button({ Name = "Server Hop Now", Description = "Switch server and continue script automatically", Callback = serverHop })

-- ===== Player UI =====
envToggle(sections.PlayerFlight, "Ghost Fly", "Fly with WASD + Space (Up) / Shift (Down) [Key: X]", "GhostFlyEnabled", "GhostFlyEnabled", toggleGhostFly)
envSlider(sections.PlayerFlight, "Ghost Fly Speed", "Adjust manual flying speed", 10, 300, "GhostFlySpeed", 50, "GhostFlySpeed")
envToggle(sections.PlayerFlight, "Noclip While Flying", "Pass through walls and obstacles while flying", "GhostFlyNoclip", "GhostFlyNoclip")
envToggle(sections.PlayerDefense, "Godmode", "Continuous health protection & anti-ragdoll", "GodmodeEnabled", "GodmodeEnabled", toggleGodmode)
envToggle(sections.PlayerDefense, "Anti Fall Damage", "Prevents damage and knockdown from falling", "AntiFallDamage", "AntiFallDamage")
envToggle(sections.PlayerDefense, "Auto Armor", "Auto warp to get armor (0s cooldown) and return when missing", "AutoArmor", "AutoArmor",
    function(v) if v then task.spawn(getArmor, false) end end)
sections.PlayerDefense:Button({ Name = "Get Armor Now", Description = "Warp to Belt Giver, press E (0s cooldown) & warp back to origin",
    Callback = function() getArmor(false) end })
envSlider(sections.PlayerDefense, "Auto Armor Interval", "How often to check and re-equip armor (seconds)", 5, 60, "AutoArmorInterval", 10, "AutoArmorInterval")

-- ===== ESP UI =====
envToggle(sections.ESPMain, "Bank ESP", "Show bank locations, distance, and robbery status", "BankESP", "BankESP")
envToggle(sections.ESPMain, "Player ESP Master", "Master toggle for all player ESP highlights", "PlayerESP", "PlayerESP")
envToggle(sections.ESPElements, "Name ESP", "Show player display name and username", "NameESP", "NameESP")
envToggle(sections.ESPElements, "Health Bar & Numbers", "Shows health bar and numeric HP", "HealthESP", "HealthESP")
envToggle(sections.ESPElements, "Inventory / Tool Icons ESP", "Shows equipped gun & backpack items as icons", "ToolESP", "ToolESP")
envToggle(sections.ESPElements, "Distance ESP", "Displays distance in studs to target", "DistESP", "DistESP")
envToggle(sections.ESPElements, "2D Box ESP", "Draws 2D bounding boxes around players", "BoxESP", "BoxESP")
envToggle(sections.ESPElements, "Tracer Lines ESP", "Draws tracer line from bottom of screen to target", "TracerESP", "TracerESP")

local ESPColors = {
    Red = Color3.fromRGB(255, 60, 60), Green = Color3.fromRGB(40, 240, 80),
    Blue = Color3.fromRGB(60, 160, 255), Yellow = Color3.fromRGB(255, 230, 40),
    Orange = Color3.fromRGB(255, 140, 30), Purple = Color3.fromRGB(180, 80, 255),
    Cyan = Color3.fromRGB(40, 240, 240), White = Color3.fromRGB(255, 255, 255),
}
env.ESPColor = ESPColors[env.ESPColorName or "Red"] or ESPColors.Red

sections.ESPCustom:Dropdown({ Name = "ESP Style", Description = "Select visual style for player highlights",
    Options = { "2D", "3D" }, Default = env.ESPStyle or "2D",
    Callback = function(v) env.ESPStyle = v SaveConfig() end }, "ESPStyle")
sections.ESPCustom:Dropdown({ Name = "ESP Color", Description = "Select color theme for ESP boxes and highlights",
    Options = { "Red", "Green", "Blue", "Yellow", "Orange", "Purple", "Cyan", "White" },
    Default = env.ESPColorName or "Red",
    Callback = function(v)
        env.ESPColorName = v
        env.ESPColor = ESPColors[v] or ESPColors.Red
        SaveConfig()
    end }, "ESPColor")

-- ===== Teleport UI =====
local tpList = playerNames()
local tpSelectedPlayer = tpList[1]
local tpDropdown = sections.TeleportPlayers:Dropdown({ Name = "Select Player", Description = "Select from online players",
    Options = tpList, Default = 1, Callback = function(c) tpSelectedPlayer = c end }, "TeleportSelectPlayer")

sections.TeleportPlayers:Button({ Name = "Teleport To Player", Description = "Teleport directly behind selected player",
    Callback = function()
        if not tpSelectedPlayer or tpSelectedPlayer == "(No Players)" then return end
        local p = Players:FindFirstChild(tpSelectedPlayer)
        local thrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if thrp then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = thrp.CFrame * CFrame.new(0, 0, 3)
                notify("Teleport", "Teleported to " .. tpSelectedPlayer)
            end
        else
            notify("Teleport", "Target character not found")
        end
    end })
sections.TeleportPlayers:Button({ Name = "Teleport To Armor Giver", Description = "Teleport directly to armor belt giver machine",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = armorCFrame notify("Teleport", "Teleported to Armor Giver") end
    end })
sections.TeleportPlayers:Button({ Name = "Refresh Players", Description = "Refresh online players list in dropdown",
    Callback = function()
        local newList = playerNames()
        tpDropdown:ClearOptions()
        tpDropdown:InsertOptions(newList)
        tpDropdown:UpdateSelection(newList[1])
        tpSelectedPlayer = newList[1]
        notify("Teleport", "Player list updated")
    end })

envToggle(sections.TeleportOrbit, "Orbit & Attack", "Orbit selected player and auto-attack", "OrbitAttack", "OrbitAttack",
    function(v)
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and not env.GhostFlyEnabled then hum.PlatformStand = false end
        end
    end)
envSlider(sections.TeleportOrbit, "Orbit Distance", "Distance from target player", 5, 50, "OrbitDistance", 15, "OrbitDistance")
envSlider(sections.TeleportOrbit, "Orbit Speed", "Orbiting rotation speed", 1, 15, "OrbitSpeed", 3, "OrbitSpeed")

-- ===== UI Settings =====
sections.SettingsMain:Dropdown({ Name = "Closed UI Style", Description = "Select the style of the minimized UI.",
    Options = { "Hidden", "Breadcrumb" }, Default = 1,
    Callback = function(s) if Window.SetClosedUIStyle then Window:SetClosedUIStyle(s) end end }, "ClosedUIStyle")
local function setKey(key) if Window and Window.SetKeybind then Window:SetKeybind(key) end end
sections.SettingsMain:Keybind({ Name = "Toggle Keybind", Description = "Key used to open and close the interface.",
    Default = Enum.KeyCode.RightControl, onBinded = setKey, Callback = setKey }, "MenuKeybind")
sections.SettingsMain:Colorpicker({ Name = "Accent Color", Description = "Change the UI theme and sidebar icon color.",
    Default = Color3.fromRGB(29, 235, 169),
    Callback = function(c) if Window and Window.SetAccentColor then Window:SetAccentColor(c) end end }, "AccentColor")
sections.SettingsMain:Slider({ Name = "UI Scale", Description = "Adjust the overall size of the interface.",
    Default = 100, Minimum = 75, Maximum = 130, DisplayMethod = "%", Precision = 0,
    Callback = function(v) if Window and Window.SetScale then Window:SetScale(v / 100) end end }, "UIScale")
sections.SettingsMain:Slider({ Name = "UI Transparency", Description = "Adjust the transparency level of the interface.",
    Default = 20, Minimum = 0, Maximum = 80, DisplayMethod = "%", Precision = 0,
    Callback = function(v) if Window and Window.SetTransparency then Window:SetTransparency(v / 100) end end }, "UITransparency")
sections.SettingsMain:Button({ Name = "คืนค่าเริ่มต้น (Reset UI Settings)", Description = "รีเซ็ตการตั้งค่า UI ทั้งหมดกลับเป็นค่าเริ่มต้น",
    Callback = function()
        local O = MacLib.Options
        if O.MenuKeybind then O.MenuKeybind:SetKey(Enum.KeyCode.RightControl) end
        if O.AccentColor then O.AccentColor:SetColor(Color3.fromRGB(29, 235, 169)) end
        if O.UIScale then O.UIScale:SetValue(100) end
        if O.UITransparency then O.UITransparency:SetValue(20) end
        if Window.SetAcrylicBlurState then Window:SetAcrylicBlurState(false) end
        if Window.SetNotificationsState then Window:SetNotificationsState(true) end
        notify("Settings", "คืนค่าการตั้งค่า UI เป็นค่าเริ่มต้นแล้ว")
    end })

sections.SettingsConfig:Button({ Name = "Save Config Now", Description = "Manually save all current script settings to disk",
    Callback = function() SaveConfig() notify("Config Saved", "Settings saved to " .. CONFIG_FILE) end })
sections.SettingsConfig:Button({ Name = "Reload Config", Description = "Reload saved settings from disk",
    Callback = function() LoadConfig() rebuildWL() notify("Config Reloaded", "Settings reloaded from disk") end })
sections.SettingsConfig:Button({ Name = "Reset Config to Defaults", Description = "Reset all script gameplay settings to initial defaults",
    Callback = function()
        pcall(function() if delfile and isfile(CONFIG_FILE) then delfile(CONFIG_FILE) end end)
        for k, v in pairs(DefaultConfig) do ConfigState[k] = v end
        notify("Config Reset", "Settings reset to defaults")
    end })
sections.SettingsConfig:Toggle({ Name = "Auto Save Changes", Description = "Automatically save settings to disk whenever modified",
    Default = ConfigState.AutoSave == nil and true or ConfigState.AutoSave,
    Callback = function(v) ConfigState.AutoSave = v if v then SaveConfig() end end }, "AutoSaveChanges")

MacLib:SetFolder("Maclib_CaliShootout")
tabs.UISettings:InsertConfigSection("Right")
tabs.Home:Select()
MacLib:LoadAutoLoadConfig()

-- ===== Orbit & attack =====
local orbitAngle = 0
track(RunService.Stepped:Connect(function(_, dt)
    if not env.OrbitAttack or not tpSelectedPlayer or tpSelectedPlayer == "(No Players)" then return end
    local target = Players:FindFirstChild(tpSelectedPlayer)
    local tchar = target and target.Character
    local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
    local thum = tchar and tchar:FindFirstChildOfClass("Humanoid")
    if not (thrp and thum and thum.Health > 0) then return end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")
    if not (myHrp and myHum) then return end

    orbitAngle += (env.OrbitSpeed or 3) * dt
    local dist = env.OrbitDistance or 15
    local pos = thrp.Position + Vector3.new(math.cos(orbitAngle) * dist, env.OrbitHeight or 5, math.sin(orbitAngle) * dist)
    myHum.PlatformStand = true
    myHrp.CFrame = CFrame.new(pos, thrp.Position)
    myHrp.AssemblyLinearVelocity = Vector3.zero
    myHrp.AssemblyAngularVelocity = Vector3.zero
    local tool = myChar:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
end))

-- ===== Bank ESP =====
local bankEspActive = false
task.spawn(function()
    while running do
        task.wait(0.5)
        if env.BankESP then
            bankEspActive = true
            for _, bank in ipairs(workspace:GetChildren()) do
                if bank.Name == "Bank" then
                    local ld = bank:FindFirstChild("LaserDisabler")
                    local main = ld and ld:FindFirstChild("Main")
                    if main then
                        local esp = main:FindFirstChild("BankESP")
                        if not esp then
                            esp = Instance.new("BillboardGui")
                            esp.Name = "BankESP"
                            esp.Adornee = main
                            esp.Size = UDim2.new(0, 150, 0, 50)
                            esp.StudsOffset = Vector3.new(0, 5, 0)
                            esp.AlwaysOnTop = true
                            local tl = Instance.new("TextLabel")
                            tl.BackgroundTransparency = 1
                            tl.Size = UDim2.new(1, 0, 1, 0)
                            tl.TextScaled = true
                            tl.Font = Enum.Font.GothamBold
                            tl.TextStrokeTransparency = 0
                            tl.Parent = esp
                            esp.Parent = main
                        end
                        local tl = esp:FindFirstChildWhichIsA("TextLabel")
                        if tl then
                            local state = getBankState(bank)
                            local text, col
                            if state == "READY" then text, col = "READY [RED]", Color3.fromRGB(255, 50, 50)
                            elseif state == "ROBBABLE" then text, col = "ROBBABLE [GREEN]", Color3.fromRGB(50, 255, 50)
                            else text, col = "COOLDOWN [YELLOW]", Color3.fromRGB(255, 255, 50) end
                            if tl.Text ~= text then tl.Text = text; tl.TextColor3 = col end
                        end
                    end
                end
            end
        elseif bankEspActive then
            bankEspActive = false
            for _, bank in ipairs(workspace:GetChildren()) do
                if bank.Name == "Bank" then
                    local ld = bank:FindFirstChild("LaserDisabler")
                    local main = ld and ld:FindFirstChild("Main")
                    local e = main and main:FindFirstChild("BankESP")
                    if e then e:Destroy() end
                end
            end
        end
    end
end)

-- ===== Auto rob bank =====
local function getPromptPart(prompt)
    local parent = prompt and prompt.Parent
    if not parent then return nil end
    if parent:IsA("BasePart") then return parent end
    if parent:IsA("Model") then return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true) end
    if parent.Parent and parent.Parent:IsA("Model") then
        return parent.Parent.PrimaryPart or parent.Parent:FindFirstChildWhichIsA("BasePart", true)
    end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function isPurchasePrompt(p)
    local pName = string.lower(p.Parent and p.Parent.Name or "")
    local oName = string.lower(p.Name or "")
    local action = string.lower(p.ActionText or "")
    local object = string.lower(p.ObjectText or "")
    return string.find(action, "buy") or string.find(object, "buy")
        or string.find(pName, "robbery tools") or string.find(oName, "robbery tools")
        or string.find(object, "robbery tools")
end

local function triggerPrompt(prompt)
    if not prompt or not prompt.Enabled then return end
    local part = getPromptPart(prompt)
    if part then flyTo(part.CFrame) task.wait(0.15) end
    if env.FastCollect == nil or env.FastCollect == true then
        if fireproximityprompt then
            local old = prompt.HoldDuration
            prompt.HoldDuration = 0
            fireproximityprompt(prompt, 0)
            task.wait(0.15)
            prompt.HoldDuration = old
        end
    else
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.1)
        prompt:InputHoldEnd()
        task.wait(0.15)
    end
end

local promptCache = {} -- [bank] = {t=, list=}
local function bankPromptList(bank)
    local c = promptCache[bank]
    if c and os.clock() - c.t < 2 then return c.list end
    local list = {}
    for _, d in ipairs(bank:GetDescendants()) do
        if d:IsA("ProximityPrompt") then list[#list + 1] = d end
    end
    promptCache[bank] = { t = os.clock(), list = list }
    return list
end

local function getBankPrompts(bank)
    local laser, vault
    local lootList, seen = {}, {}
    for _, d in ipairs(bankPromptList(bank)) do
        if d.Parent and d.Enabled and not isPurchasePrompt(d) then
            local pName = string.lower(d.Parent.Name or "")
            local oName = string.lower(d.Name or "")
            local gName = string.lower(d.Parent.Parent and d.Parent.Parent.Name or "")
            if string.find(pName, "laser") or string.find(gName, "laser") then
                laser = d
            elseif string.find(pName, "vault") or string.find(gName, "vault") or string.find(pName, "door") then
                vault = d
            elseif not string.find(pName, "document") and not string.find(oName, "document") then
                local part = getPromptPart(d)
                if part then seen[d] = true; lootList[#lootList + 1] = { prompt = d, part = part } end
            end
        end
    end
    local folder = bank:FindFirstChild("Loot", true) or bank:FindFirstChild("Cash", true) or bank:FindFirstChild("Money", true)
    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
            local part = item:IsA("BasePart") and item
                or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
            if prompt and prompt.Enabled and part and not seen[prompt] and not isPurchasePrompt(prompt) then
                lootList[#lootList + 1] = { prompt = prompt, part = part }
            end
        end
    end
    return laser, vault, lootList
end

local function bagFull()
    local full = false
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("BankRobberyGUI")
        local lbl = gui and gui:FindFirstChild("MainRobbery") and gui.MainRobbery:FindFirstChild("MoneyCollectedLabel")
        if lbl then
            local cur, max = string.match((lbl.Text:gsub("[$,]", "")), "(%d+)%s*/%s*(%d+)")
            if cur and max and tonumber(cur) >= tonumber(max) then full = true end
        end
    end)
    return full
end

local cashoutCache
local function findCashout()
    if cashoutCache and cashoutCache.Parent then return cashoutCache end
    cashoutCache = nil
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BillboardGui") and d.Enabled and d.Parent and d.Parent.Name == "Marker" and d.Parent.Parent then
            cashoutCache = d.Parent.Parent
            return cashoutCache
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ProximityPrompt") and o.Enabled then
            local n = string.lower(o.Parent and o.Parent.Name or "")
            if string.find(n, "cashout") or string.find(n, "dealer") or string.find(n, "dropoff") or string.find(n, "sell") then
                cashoutCache = o.Parent
                return cashoutCache
            end
        end
    end
end

local function doCashout()
    pcall(function()
        local dest = findCashout()
        if not dest then print("Could not find active CashoutPoint") return end
        local cf
        if dest:IsA("Model") then
            cf = dest.PrimaryPart and dest.PrimaryPart.CFrame or dest:GetModelCFrame()
        elseif dest:IsA("BasePart") then
            cf = dest.CFrame
        end
        if not cf then
            local part = dest:FindFirstChildWhichIsA("BasePart", true)
            if part then cf = part.CFrame end
        end
        if not cf then return end
        flyTo(cf)
        task.wait(0.5)
        for _, o in ipairs(dest:GetDescendants()) do
            if o:IsA("ProximityPrompt") and o.Enabled then
                local pName = string.lower(o.Parent.Name)
                local oName = string.lower(o.Name)
                if not string.find(pName, "document") and not string.find(oName, "document") then
                    local old = o.HoldDuration
                    o.HoldDuration = 0
                    fireproximityprompt(o, 0)
                    task.wait(0.1)
                    o.HoldDuration = old
                end
            end
        end
        task.wait(1.5)
    end)
end

local function hopIfEnabled(msg)
    if env.AutoServerHop and env.AutoRobBank then
        notify("Auto Server Hop", msg, 4)
        task.wait(3)
        serverHop()
        task.wait(10)
    end
end

task.spawn(function()
    while running and task.wait(1) do
        if not env.AutoRobBank then continue end
        local targetBank, targetMain, level = nil, nil, 0
        for _, bank in ipairs(getBanks()) do
            local state, main = getBankState(bank)
            if main and not robbedBanks[bank] then
                if state == "READY" and level < 3 then targetBank, targetMain, level = bank, main, 3
                elseif state == "ROBBABLE" and level < 2 then targetBank, targetMain, level = bank, main, 2 end
            end
        end

        if targetBank then
            print("Target found! Flying to rob...")
            flyTo(targetMain.CFrame)
            local empty = 0
            while running and task.wait(0.3) do
                if not env.AutoRobBank then break end
                if bagFull() then print("Bag full! Going to cashout...") break end

                local laser, vault, loot = getBankPrompts(targetBank)
                if laser and laser.Enabled then
                    triggerPrompt(laser); empty = 0; task.wait(0.3)
                elseif vault and vault.Enabled then
                    triggerPrompt(vault); empty = 0; task.wait(0.5)
                elseif #loot > 0 then
                    empty = 0
                    local full = false
                    for _, item in ipairs(loot) do
                        if not env.AutoRobBank then break end
                        if bagFull() then full = true break end
                        if item.prompt.Enabled then triggerPrompt(item.prompt) task.wait(0.2) end
                    end
                    if full then print("Bag full! Going to cashout...") break end
                else
                    empty += 1
                    if empty <= 20 then task.wait(0.5)
                    else print("No more loot. Cashing out and changing bank.") break end
                end
            end

            doCashout()
            robbedBanks[targetBank] = true
            promptCache[targetBank] = nil

            local left = false
            for _, b in ipairs(getBanks()) do
                local st = getBankState(b)
                if (st == "READY" or st == "ROBBABLE") and not robbedBanks[b] then left = true break end
            end
            if not left then hopIfEnabled("All banks completed! Switching server in 3s...") end
        else
            hopIfEnabled("No robbable banks available. Hopping to another server in 3s...")
        end
    end
end)

-- ===== Player ESP =====
local espObjects = {}

local function toolIcon(name)
    local n = string.lower(name or "")
    for _, k in ipairs({ "gun", "ak", "m4", "rifle", "shotgun", "glock", "pistol", "deagle", "sniper", "revolver", "smg", "uzi", "weapon" }) do
        if string.find(n, k) then return "rbxassetid://6031086178" end
    end
    for _, k in ipairs({ "knife", "blade", "sword", "bat", "axe", "katana", "melee", "fist" }) do
        if string.find(n, k) then return "rbxassetid://6034684937" end
    end
    for _, k in ipairs({ "med", "heal", "bandage", "potion", "food", "apple", "drink" }) do
        if string.find(n, k) then return "rbxassetid://6031094667" end
    end
    return "rbxassetid://6031068426"
end

local function activeColor() return ESPColors[env.ESPColorName or "Red"] or ESPColors.Red end

local function mkLabel(parent, name, size, pos, color, stroke, font, ts)
    local l = Instance.new("TextLabel")
    l.Name = name; l.Size = size; l.Position = pos
    l.BackgroundTransparency = 1
    l.TextColor3 = color; l.TextStrokeTransparency = stroke
    l.Font = font; l.TextSize = ts
    l.Parent = parent
    return l
end

local function createPlayerESP(player)
    local o = {}
    local col = activeColor()
    pcall(function()
        o.Tracer = Drawing.new("Line")
        o.Tracer.Visible = false; o.Tracer.Color = col; o.Tracer.Thickness = 1; o.Tracer.Transparency = 1
        o.Box = Drawing.new("Square")
        o.Box.Visible = false; o.Box.Color = col; o.Box.Thickness = 1; o.Box.Transparency = 1; o.Box.Filled = false
    end)
    local hl = Instance.new("Highlight")
    hl.Name = "ESPHighlight"
    hl.FillColor = col; hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0; hl.Enabled = false
    o.Highlight = hl

    local gui = Instance.new("BillboardGui")
    gui.Name = "PlayerESP"
    gui.Size = UDim2.new(5, 0, 6, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 6000
    gui.ExtentsOffset = Vector3.new(0, 3, 0)

    o.Name = mkLabel(gui, "NameLabel", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, -28), Color3.new(1, 1, 1), 0.3, Enum.Font.GothamBold, 13)
    o.HpText = mkLabel(gui, "HealthText", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, -12), Color3.fromRGB(0, 255, 120), 0.3, Enum.Font.GothamMedium, 11)
    o.Dist = mkLabel(gui, "DistLabel", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, 6), Color3.fromRGB(220, 220, 220), 0.4, Enum.Font.Gotham, 11)

    local bg = Instance.new("Frame")
    bg.Name = "HealthBarBg"
    bg.Size = UDim2.new(0, 4, 1, 0); bg.Position = UDim2.new(0, -8, 0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20); bg.BorderSizePixel = 0
    bg.Parent = gui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 2)
    local bar = Instance.new("Frame")
    bar.Name = "HealthBar"
    bar.Size = UDim2.new(1, 0, 1, 0); bar.AnchorPoint = Vector2.new(0, 1); bar.Position = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(0, 255, 120); bar.BorderSizePixel = 0
    bar.Parent = bg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    o.HpBg, o.HpBar = bg, bar

    local inv = Instance.new("Frame")
    inv.Name = "InvContainer"
    inv.Size = UDim2.new(0, 110, 1, 0); inv.Position = UDim2.new(1, 8, 0, 0)
    inv.BackgroundTransparency = 1
    inv.Parent = gui
    local lay = Instance.new("UIListLayout")
    lay.FillDirection = Enum.FillDirection.Vertical
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 3)
    lay.Parent = inv
    o.Inv = inv

    o.Gui = gui
    o.ToolBadges = {}
    o.color = col
    espObjects[player] = o
    return o
end

local function removePlayerESP(player)
    local o = espObjects[player]
    if not o then return end
    if o.Tracer then pcall(function() o.Tracer:Remove() end) end
    if o.Box then pcall(function() o.Box:Remove() end) end
    pcall(function() o.Highlight:Destroy() end)
    pcall(function() o.Gui:Destroy() end)
    espObjects[player] = nil
end

local function hideESP(o)
    if o.Gui.Parent then o.Gui.Parent = nil end
    if o.Tracer then o.Tracer.Visible = false end
    if o.Box then o.Box.Visible = false end
    o.Highlight.Enabled = false
    o.Highlight.Parent = nil
end

local function updateToolBadges(o, player, char)
    local tools = {}
    local eq = char:FindFirstChildOfClass("Tool")
    if eq then tools[1] = { Tool = eq, Equipped = true } end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then tools[#tools + 1] = { Tool = t, Equipped = false } end
        end
    end
    for i = 1, math.max(#tools, #o.ToolBadges) do
        local item, badge = tools[i], o.ToolBadges[i]
        if item and i <= 4 then
            if not badge then
                badge = Instance.new("Frame")
                badge.Name = "ItemBadge_" .. i
                badge.Size = UDim2.new(1, 0, 0, 18)
                badge.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                badge.BackgroundTransparency = 0.3
                badge.BorderSizePixel = 0
                badge.Parent = o.Inv
                Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)
                local st = Instance.new("UIStroke")
                st.Name = "BadgeStroke"; st.Thickness = 1; st.Transparency = 0.4
                st.Parent = badge
                local icon = Instance.new("ImageLabel")
                icon.Name = "ItemIcon"; icon.AnchorPoint = Vector2.new(0, 0.5)
                icon.Position = UDim2.new(0, 3, 0.5, 0); icon.Size = UDim2.new(0, 13, 0, 13)
                icon.BackgroundTransparency = 1; icon.Parent = badge
                local label = Instance.new("TextLabel")
                label.Name = "ItemName"; label.AnchorPoint = Vector2.new(0, 0.5)
                label.Position = UDim2.new(0, 19, 0.5, 0); label.Size = UDim2.new(1, -21, 1, 0)
                label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamMedium; label.TextSize = 10
                label.TextColor3 = Color3.fromRGB(240, 240, 245)
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextTruncate = Enum.TextTruncate.AtEnd
                label.Parent = badge
                o.ToolBadges[i] = badge
            end
            local tool = item.Tool
            local tex = (tool.TextureId and tool.TextureId ~= "") and tool.TextureId or toolIcon(tool.Name)
            if badge.ItemIcon.Image ~= tex then badge.ItemIcon.Image = tex end
            if badge.ItemName.Text ~= tool.Name then badge.ItemName.Text = tool.Name end
            local st = badge:FindFirstChild("BadgeStroke")
            if item.Equipped then
                if st then st.Color = Color3.fromRGB(255, 180, 40) end
                badge.BackgroundColor3 = Color3.fromRGB(35, 30, 18)
            else
                if st then st.Color = Color3.fromRGB(60, 60, 80) end
                badge.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
            end
            badge.Visible = true
        elseif badge then
            badge.Visible = false
        end
    end
end

local espActive = false
local slowAcc, toolAcc = 0, 0
local lastVS = Vector2.zero

track(RunService.RenderStepped:Connect(function(dt)
    local cam = workspace.CurrentCamera
    if FOVring and cam then
        local vs = cam.ViewportSize
        if vs ~= lastVS then
            lastVS = vs
            FOVring.Position = Vector2.new(vs.X / 2, vs.Y / 2)
        end
    end
    updateAimbot()

    if not env.PlayerESP then
        if espActive then
            espActive = false
            for _, o in pairs(espObjects) do hideESP(o) end
        end
        return
    end
    espActive = true

    slowAcc += dt
    toolAcc += dt
    local slow = slowAcc >= 0.1
    if slow then slowAcc = 0 end
    local toolSlow = toolAcc >= 0.4
    if toolSlow then toolAcc = 0 end

    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local style2D = env.ESPStyle == "2D"
    local col = activeColor()
    local vs = cam.ViewportSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local o = espObjects[player] or createPlayerESP(player)
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                if o.Gui.Parent ~= hrp then o.Gui.Parent = hrp; o.Gui.Adornee = hrp end

                if slow then
                    if o.color ~= col then
                        o.color = col
                        if o.Tracer then o.Tracer.Color = col end
                        if o.Box then o.Box.Color = col end
                        o.Highlight.FillColor = col
                    end
                    local dist = myHrp and (hrp.Position - myHrp.Position).Magnitude or 0
                    local showDist, showName, showHp = env.DistESP, env.NameESP, env.HealthESP
                    o.Dist.Visible = showDist
                    if showDist then
                        local t = "[ " .. math.floor(dist) .. " studs ]"
                        if o.Dist.Text ~= t then o.Dist.Text = t end
                    end
                    o.Name.Visible = showName
                    if showName then
                        local t = (player.DisplayName or player.Name) .. " (@" .. player.Name .. ")"
                        if o.Name.Text ~= t then o.Name.Text = t end
                    end
                    o.HpBg.Visible = showHp
                    o.HpText.Visible = showHp
                    if showHp then
                        local hp = math.max(0, math.floor(hum.Health))
                        local maxHp = math.max(1, math.floor(hum.MaxHealth))
                        local pct = math.clamp(hp / maxHp, 0, 1)
                        local c = Color3.fromRGB(math.floor((1 - pct) * 255), math.floor(pct * 255), 40)
                        o.HpBar.Size = UDim2.new(1, 0, pct, 0)
                        o.HpBar.BackgroundColor3 = c
                        o.HpText.Text = hp .. " / " .. maxHp .. " HP"
                        o.HpText.TextColor3 = c
                    end
                    o.Inv.Visible = env.ToolESP and true or false
                    if env.ToolESP and toolSlow then updateToolBadges(o, player, char) end
                end

                if style2D then
                    if o.Highlight.Parent then o.Highlight.Enabled = false; o.Highlight.Parent = nil end
                    if o.Tracer and o.Box then
                        local hp3, on = cam:WorldToViewportPoint(hrp.Position)
                        if on then
                            local head = char:FindFirstChild("Head")
                            local top = cam:WorldToViewportPoint(head and (head.Position + Vector3.new(0, 0.5, 0)) or (hrp.Position + Vector3.new(0, 2, 0)))
                            local bottom = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                            local h = math.abs(top.Y - bottom.Y)
                            local w = h / 2
                            if env.BoxESP then
                                o.Box.Size = Vector2.new(w, h)
                                o.Box.Position = Vector2.new(hp3.X - w / 2, top.Y)
                                o.Box.Visible = true
                            else
                                o.Box.Visible = false
                            end
                            if env.TracerESP then
                                o.Tracer.From = Vector2.new(vs.X / 2, vs.Y)
                                o.Tracer.To = Vector2.new(hp3.X, hp3.Y)
                                o.Tracer.Visible = true
                            else
                                o.Tracer.Visible = false
                            end
                        else
                            o.Box.Visible = false
                            o.Tracer.Visible = false
                        end
                    end
                else
                    if o.Box then o.Box.Visible = false end
                    if o.Tracer then o.Tracer.Visible = false end
                    if o.Highlight.Parent ~= char then o.Highlight.Parent = char end
                    o.Highlight.Enabled = true
                end
            else
                hideESP(o)
            end
        end
    end
end))

track(Players.PlayerRemoving:Connect(removePlayerESP))

-- ===== unload =====
env._HyperUnload = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    stopGhostFly()
    if godmodeConn then godmodeConn:Disconnect() end
    for p in pairs(espObjects) do removePlayerESP(p) end
    if FOVring then pcall(function() FOVring:Remove() end) end
    env._HyperUnload = nil
end
