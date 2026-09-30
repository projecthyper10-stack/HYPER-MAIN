-- ==============================================================================
-- Cali Shootout • Feature List
-- [ MAIN AUTO FARM ]
-- + Auto Rob Bank (Smart Detection & Laser Disabler)
-- + Fast Collect (Instant E / 0s Proximity Prompt Bypass)
-- + Auto Server Hop (Cooldown Detection & Auto Queue)
-- + Server Hop Now (Instant Active Server Finder)
-- + Adjustable Auto Rob Fly Speed
-- 
-- [ COMBAT & AIMBOT ]
-- + Smooth Camera Aimbot (Prediction & Lerp System)
-- + Hitbox Part Selection: Head, Torso, Arms, Legs, Random
-- + Raycast Wall Check & Team Check Bypass
-- + Dynamic FOV Circle & Filled Area Display
-- + Player Whitelist System (Add / Remove / Clear / Ignore)
-- 
-- [ PLAYER & DEFENSE ]
-- + Ghost Fly (6-Axis Manual Flight with WASD + Space/Shift [Key: X])
-- + Ghost Fly Noclip (Full Object Collision Bypass)
-- + Godmode & Anti-Ragdoll Protection
-- + Anti Fall Damage (Zero Impact Damage)
-- + Auto Armor (Auto Warp to Belt Giver & Return)
-- + Instant Get Armor (0s Cooldown Bypass)
-- + Adjustable Auto Armor Check Interval
-- 
-- [ VISUALS & ESP ]
-- + Bank Status ESP (Ready, Robbing, Cooldown & Distance)
-- + Player ESP Master Toggle
-- + Player Name & Real-time Health ESP (Bar + Number)
-- + Inventory / Weapon Tool Icons ESP (Equipped & Backpack Badges)
-- + Distance ESP & Tracer Lines (Bottom Screen)
-- + 2D Box ESP & 3D Character Highlight Modes
-- + Customizable ESP Color Palette (8 Colors)
-- 
-- [ TELEPORTS & EXPLOITS ]
-- + Teleport to Player (Online Dropdown Selector)
-- + Teleport to Armor Giver (Belt Machine)
-- + Orbit & Attack (Adjustable Speed, Distance & Auto Tool Attack)
-- 
-- [ SYSTEM & CONFIG ]
-- + Auto Config Save & Disk Sync (JSON Manager)
-- + Queue On Teleport (Seamless Persistence across Hops)
-- + Modern HYPER HUB Dark UI (Mobile & PC Adaptive)
-- ==============================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local UIS = UserInputService

pcall(function()
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoomless
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
end)

local robbedBanks = {}

local function getBankState(bank)
    local laserDisabler = bank:FindFirstChild("LaserDisabler")
    if laserDisabler then
        local main = laserDisabler:FindFirstChild("Main")
        if main then
            local color = main.Color
            local r = math.round(color.R * 255)
            local g = math.round(color.G * 255)
            local b = math.round(color.B * 255)
            
            if (r == 255 and g == 0 and b == 0) then
                return "READY", main
            elseif (r == 0 and g == 170 and b == 0) then
                return "ROBBABLE", main
            else
                return "COOLDOWN", main
            end
        end
    end
    return "NONE", nil
end

local function getBanks()
    local banks = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Bank" then
            table.insert(banks, child)
            local state, main = getBankState(child)
            if state == "COOLDOWN" or state == "NONE" then
                robbedBanks[child] = nil
            end
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
    
    humanoid.PlatformStand = true
    
    local oldBv = hrp:FindFirstChild("GhostFlyVelocity")
    if oldBv then oldBv:Destroy() end
    local oldBg = hrp:FindFirstChild("GhostFlyGyro")
    if oldBg then oldBg:Destroy() end
    
    local bv = Instance.new("BodyVelocity")
    bv.Name = "GhostFlyVelocity"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp
    
    local bg = Instance.new("BodyGyro")
    bg.Name = "GhostFlyGyro"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 3000
    bg.D = 500
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    
    local speed = getgenv().FlySpeed or 100
    local flying = true
    local startTime = tick()
    local startDist = (targetCFrame.Position - hrp.Position).Magnitude
    local timeout = (startDist / speed) + 5
    
    local steppedConn = RunService.Stepped:Connect(function()
        if not flying then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
    
    while flying and char and hrp.Parent and getgenv().AutoRobBank do
        local dist = (targetCFrame.Position - hrp.Position).Magnitude
        if dist < 5 or (tick() - startTime) > timeout then
            flying = false
            break
        end
        
        local dir = (targetCFrame.Position - hrp.Position).Unit
        bv.Velocity = dir * speed
        bg.CFrame = CFrame.new(hrp.Position, targetCFrame.Position)
        
        task.wait()
    end
    
    if steppedConn then steppedConn:Disconnect() end
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    
    if humanoid then humanoid.PlatformStand = false end
    if hrp then 
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

-- ==============================================================================
--  HYPER HUB / MACLIB - UI Initialization
-- ==============================================================================

local REPO = "https://raw.githubusercontent.com/projecthyper10-stack/HYPER-UI/refs/heads/main/"

-- Step 0: Clean up any previous UI instances thoroughly
pcall(function()
    local globalEnv = (getgenv and getgenv()) or _G
    if globalEnv._MacLibScreenGui and typeof(globalEnv._MacLibScreenGui) == "Instance" then
        pcall(function() globalEnv._MacLibScreenGui:Destroy() end)
        globalEnv._MacLibScreenGui = nil
    end
    if _G._MacLibScreenGui and typeof(_G._MacLibScreenGui) == "Instance" then
        pcall(function() _G._MacLibScreenGui:Destroy() end)
        _G._MacLibScreenGui = nil
    end

    local containers = {}
    if typeof(gethui) == "function" then
        pcall(function() table.insert(containers, gethui()) end)
    end
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        if CoreGui then table.insert(containers, CoreGui) end
    end)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") then
            table.insert(containers, lp.PlayerGui)
        end
    end)

    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") then
                    if child.Name == "MacLibScreenGui"
                        or (child:FindFirstChild("Base") and child.Base:FindFirstChild("Sidebar"))
                        or child:FindFirstChild("Breadcrumb") then
                        child:Destroy()
                    end
                end
            end
        end)
    end
end)

-- Singularity Key verification & profile avatar lookup
local KeyAvatarURL = getgenv().KeyAvatar
if not KeyAvatarURL then
    pcall(function()
        if isfile and isfile("SingularityKey.txt") then
            local savedKey = readfile("SingularityKey.txt")
            if savedKey and savedKey ~= "" then
                local rbx_user = game:GetService("Players").LocalPlayer.Name
                local rbx_id = game:GetService("Players").LocalPlayer.UserId
                
                local url = "https://projectsingularity.online/raw/verify-key?k=" .. savedKey .. "&rbx_user=" .. rbx_user .. "&rbx_id=" .. tostring(rbx_id)
                local req = (request or http_request or (syn and syn.request) or (http and http.request))
                
                local responseJson = nil
                if req then
                    local res = req({
                        Url = "https://projectsingularity.online/raw/verify-key",
                        Method = "POST",
                        Headers = { ["Content-Type"] = "application/json" },
                        Body = game:GetService("HttpService"):JSONEncode({ key = savedKey, rbx_user = rbx_user, rbx_id = rbx_id })
                    })
                    responseJson = game:GetService("HttpService"):JSONDecode(res.Body)
                else
                    responseJson = game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
                end

                if responseJson and responseJson.valid and responseJson.profile then
                    getgenv().KeyUsername = responseJson.profile.username
                    local rawAvatar = responseJson.profile.avatar_url
                    if rawAvatar and rawAvatar ~= "" then
                        KeyAvatarURL = rawAvatar
                    end
                end
            end
        end
    end)
end

-- Step 1: Pre-load icon.lua
pcall(function()
    local iconCode = ""
    if typeof(isfile) == "function" and isfile("icon.lua") then
        iconCode = readfile("icon.lua")
    elseif typeof(isfile) == "function" and isfile("Maclib/icon.lua") then
        iconCode = readfile("Maclib/icon.lua")
    else
        iconCode = game:HttpGet(REPO .. "icon.lua?t=" .. tostring(tick()))
    end
    local func = loadstring(iconCode)
    if func then
        local ok, result = pcall(func)
        if ok and result then _G._MacLibIconEngine = result end
    end
end)

-- Step 2: Load ui-main.lua
local MacLib
local okLoad, resLoad = pcall(function()
    local code = ""
    if typeof(isfile) == "function" and isfile("ui-main.lua") then
        code = readfile("ui-main.lua")
    elseif typeof(isfile) == "function" and isfile("Maclib/ui-main.lua") then
        code = readfile("Maclib/ui-main.lua")
    else
        code = game:HttpGet(REPO .. "ui-main.lua?t=" .. tostring(tick()))
    end
    local func, err = loadstring(code)
    if not func then error("[ui-main.lua Compile Error]: " .. tostring(err)) end
    local ok, result = pcall(func)
    if not ok then error("[ui-main.lua Runtime Error]: " .. tostring(result)) end
    return result
end)
if okLoad and resLoad then
    MacLib = resLoad
else
    warn("[MacLib] Failed to load: " .. tostring(resLoad))
    return
end

local SCRIPT_VERSION = "v1.0"

local Window = MacLib:Window({
    Title = "HYPER HUB",
    Subtitle = "Cali Shootout",
    Version = SCRIPT_VERSION,
    Logo = "rbxassetid://108952102602834",
    Size = UDim2.fromOffset(710, 450),
    DragStyle = 1,
    SidebarMinSize = 50,
    SidebarMaxSize = 250,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AccentColor = Color3.fromRGB(29, 235, 169),
    WindowControlSize = 12,
    Transparency = 0.2,
    AcrylicBlur = false,
})

Window:GlobalSetting({ Name = "UI Blur", Default = Window:GetAcrylicBlurState(), Callback = function(bool) Window:SetAcrylicBlurState(bool) end })
Window:GlobalSetting({ Name = "Notifications", Default = Window:GetNotificationsState(), Callback = function(bool) Window:SetNotificationsState(bool) end })

-- Tab Groups (Sidebar Categories)
local tabGroups = {
    General       = Window:TabGroup("General"),
    Combat        = Window:TabGroup("Combat"),
    Farming       = Window:TabGroup("Farming"),
    Visuals       = Window:TabGroup("Visuals"),
    Movement      = Window:TabGroup("Movement & World"),
    SettingsGroup = Window:TabGroup("Settings"),
}

-- Tabs
local tabs = {
    Home       = tabGroups.General:Tab({ Name = "Home",         Icon = "lucide-home" }),
    Aimbot     = tabGroups.Combat:Tab({ Name = "Aimbot",       Icon = "lucide-crosshair" }),
    Whitelist  = tabGroups.Combat:Tab({ Name = "Whitelist",    Icon = "lucide-users" }),
    Farm       = tabGroups.Farming:Tab({ Name = "Auto Farm",    Icon = "lucide-zap" }),
    ESP        = tabGroups.Visuals:Tab({ Name = "ESP",          Icon = "lucide-eye" }),
    Player     = tabGroups.Movement:Tab({ Name = "Player",       Icon = "lucide-user" }),
    Teleport   = tabGroups.Movement:Tab({ Name = "Teleport",     Icon = "lucide-map-pin" }),
    UISettings = tabGroups.SettingsGroup:Tab({ Name = "UI Settings", Icon = "lucide-settings" }),
}

-- Sections
local sections = {
    HomeWelcome     = tabs.Home:Section({ Name = "Welcome", Side = "Left" }),
    HomeStats       = tabs.Home:Section({ Name = "System Information", Side = "Right" }),
    AimbotMain      = tabs.Aimbot:Section({ Name = "Main Settings", Side = "Left" }),
    AimbotTargeting = tabs.Aimbot:Section({ Name = "Targeting Rules", Side = "Right" }),
    AimbotAccuracy  = tabs.Aimbot:Section({ Name = "Accuracy & Prediction", Side = "Left" }),
    AimbotVisuals   = tabs.Aimbot:Section({ Name = "FOV Visuals", Side = "Right" }),
    WhitelistConfig = tabs.Whitelist:Section({ Name = "Whitelist Configuration", Side = "Left" }),
    WhitelistManage = tabs.Whitelist:Section({ Name = "Whitelist Management", Side = "Right" }),
    FarmMain        = tabs.Farm:Section({ Name = "Bank Robbery Automation", Side = "Left" }),
    FarmHop         = tabs.Farm:Section({ Name = "Server Hop", Side = "Right" }),
    PlayerFlight    = tabs.Player:Section({ Name = "Ghost Flight", Side = "Left" }),
    PlayerDefense   = tabs.Player:Section({ Name = "Godmode & Defense", Side = "Right" }),
    ESPMain         = tabs.ESP:Section({ Name = "Master ESP", Side = "Left" }),
    ESPElements     = tabs.ESP:Section({ Name = "Player Elements", Side = "Left" }),
    ESPCustom       = tabs.ESP:Section({ Name = "Visual Customization", Side = "Right" }),
    TeleportPlayers = tabs.Teleport:Section({ Name = "Player Teleport", Side = "Left" }),
    TeleportOrbit   = tabs.Teleport:Section({ Name = "Orbit & Attack", Side = "Right" }),
    SettingsMain    = tabs.UISettings:Section({ Name = "Appearance & Controls", Side = "Left" }),
    SettingsConfig  = tabs.UISettings:Section({ Name = "Configuration Manager", Side = "Right" }),
}

-- Home Tab Population
local plr = game:GetService("Players").LocalPlayer

sections.HomeWelcome:Label({ Text = "Welcome, " .. (plr and plr.DisplayName or "User") .. "!" })
sections.HomeWelcome:SubLabel({ Text = "Thanks for using HYPER HUB - Cali Shootout" })

sections.HomeStats:Label({ Text = "User" })
sections.HomeStats:SubLabel({ Text = plr and (getgenv().KeyUsername or plr.Name) or "Unknown" })

sections.HomeStats:Label({ Text = "Executor" })
sections.HomeStats:SubLabel({ Text = (identifyexecutor and identifyexecutor()) or "Unknown" })

sections.HomeStats:Label({ Text = "Script Version" })
sections.HomeStats:SubLabel({ Text = SCRIPT_VERSION })

sections.HomeStats:Label({ Text = "UI Version" })
sections.HomeStats:SubLabel({ Text = tostring(MacLib.Version or "v2.0") })

sections.HomeStats:Label({ Text = "Device / Platform" })
sections.HomeStats:SubLabel({ Text = (game:GetService("UserInputService").TouchEnabled and "Mobile / Touch" or "Windows / PC") })

sections.HomeStats:Label({ Text = "Current Time" })
local timeSub = sections.HomeStats:SubLabel({ Text = os.date("%X") })

task.spawn(function()
    while task.wait(1) do
        if timeSub and timeSub.SetText then
            pcall(function() timeSub:SetText(os.date("%X")) end)
        elseif timeSub and timeSub.SetDesc then
            pcall(function() timeSub:SetDesc(os.date("%X")) end)
        end
    end
end)
-- ============================================
-- CONFIGURATION MANAGER (AUTO SAVE & LOAD)
-- ============================================
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "Singularity_CaliShootout_Config.json"

local DefaultConfig = {
    -- Auto Farm
    AutoRobBank = false,
    AutoServerHop = false,
    FastCollect = true,
    FlySpeed = 150,

    -- Player
    GhostFlyEnabled = false,
    GhostFlySpeed = 50,
    GhostFlyNoclip = true,
    GodmodeEnabled = false,
    AntiFallDamage = true,
    AutoArmor = false,
    AutoArmorInterval = 10,

    -- ESP
    BankESP = false,
    PlayerESP = false,
    NameESP = true,
    HealthESP = true,
    ToolESP = true,
    DistESP = true,
    BoxESP = true,
    TracerESP = true,
    ESPStyle = "2D",
    ESPColorName = "Red",

    -- Aimbot
    aimbotEnabled = true,
    Toggle = false,
    teamCheck = false,
    wallCheck = true,
    lockMode = "Head",
    fov = 150,
    smoothing = 0.15,
    predictionFactor = 0.165,
    showFOV = true,
    fovFilled = false,

    -- Teleport & Orbit
    OrbitAttack = false,
    OrbitDistance = 15,
    OrbitSpeed = 3,
    OrbitHeight = 5,

    -- Whitelist & System
    Whitelist = {},
    AutoSave = true,
}

local ConfigState = {}
for k, v in pairs(DefaultConfig) do
    ConfigState[k] = v
end

local function LoadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local content = readfile(CONFIG_FILE)
            if content and content ~= "" then
                local decoded = HttpService:JSONDecode(content)
                if type(decoded) == "table" then
                    for k, v in pairs(decoded) do
                        ConfigState[k] = v
                    end
                end
            end
        end
    end)

    getgenv().AutoRobBank = ConfigState.AutoRobBank
    getgenv().AutoServerHop = ConfigState.AutoServerHop
    getgenv().FastCollect = ConfigState.FastCollect
    getgenv().FlySpeed = ConfigState.FlySpeed
    
    getgenv().GhostFlyEnabled = ConfigState.GhostFlyEnabled
    getgenv().GhostFlySpeed = ConfigState.GhostFlySpeed
    getgenv().GhostFlyNoclip = ConfigState.GhostFlyNoclip
    getgenv().GodmodeEnabled = ConfigState.GodmodeEnabled
    getgenv().AntiFallDamage = ConfigState.AntiFallDamage
    getgenv().AutoArmor = ConfigState.AutoArmor or false
    getgenv().AutoArmorInterval = ConfigState.AutoArmorInterval or 10
    
    getgenv().BankESP = ConfigState.BankESP
    getgenv().PlayerESP = ConfigState.PlayerESP
    getgenv().NameESP = ConfigState.NameESP
    getgenv().HealthESP = ConfigState.HealthESP
    getgenv().ToolESP = ConfigState.ToolESP
    getgenv().DistESP = ConfigState.DistESP
    getgenv().BoxESP = ConfigState.BoxESP
    getgenv().TracerESP = ConfigState.TracerESP
    getgenv().ESPStyle = ConfigState.ESPStyle
    getgenv().ESPColorName = ConfigState.ESPColorName or "Red"

    getgenv().OrbitAttack = ConfigState.OrbitAttack
    getgenv().OrbitDistance = ConfigState.OrbitDistance
    getgenv().OrbitSpeed = ConfigState.OrbitSpeed
    getgenv().OrbitHeight = ConfigState.OrbitHeight
end

LoadConfig()

local saveDebounce = false
local function SaveConfig()
    if not writefile then return end
    if not (ConfigState.AutoSave == nil or ConfigState.AutoSave == true) then return end
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.4, function()
        pcall(function()
            ConfigState.AutoRobBank = getgenv().AutoRobBank
            ConfigState.AutoServerHop = getgenv().AutoServerHop
            ConfigState.FastCollect = getgenv().FastCollect
            ConfigState.FlySpeed = getgenv().FlySpeed

            ConfigState.GhostFlyEnabled = getgenv().GhostFlyEnabled
            ConfigState.GhostFlySpeed = getgenv().GhostFlySpeed
            ConfigState.GhostFlyNoclip = getgenv().GhostFlyNoclip
            ConfigState.GodmodeEnabled = getgenv().GodmodeEnabled
            ConfigState.AntiFallDamage = getgenv().AntiFallDamage
            ConfigState.AutoArmor = getgenv().AutoArmor
            ConfigState.AutoArmorInterval = getgenv().AutoArmorInterval

            ConfigState.BankESP = getgenv().BankESP
            ConfigState.PlayerESP = getgenv().PlayerESP
            ConfigState.NameESP = getgenv().NameESP
            ConfigState.HealthESP = getgenv().HealthESP
            ConfigState.ToolESP = getgenv().ToolESP
            ConfigState.DistESP = getgenv().DistESP
            ConfigState.BoxESP = getgenv().BoxESP
            ConfigState.TracerESP = getgenv().TracerESP
            ConfigState.ESPStyle = getgenv().ESPStyle
            ConfigState.ESPColorName = getgenv().ESPColorName or "Red"

            if AimbotSettings then
                ConfigState.aimbotEnabled = AimbotSettings.aimbotEnabled
                ConfigState.Toggle = AimbotSettings.Toggle
                ConfigState.teamCheck = AimbotSettings.teamCheck
                ConfigState.wallCheck = AimbotSettings.wallCheck
                ConfigState.lockMode = AimbotSettings.lockMode
                ConfigState.fov = AimbotSettings.fov
                ConfigState.smoothing = AimbotSettings.smoothing
                ConfigState.predictionFactor = AimbotSettings.predictionFactor
                ConfigState.showFOV = AimbotSettings.showFOV
                ConfigState.fovFilled = AimbotSettings.fovFilled
            end

            ConfigState.OrbitAttack = getgenv().OrbitAttack
            ConfigState.OrbitDistance = getgenv().OrbitDistance
            ConfigState.OrbitSpeed = getgenv().OrbitSpeed
            ConfigState.OrbitHeight = getgenv().OrbitHeight

            ConfigState.Whitelist = Whitelist

            writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigState))
        end)
        saveDebounce = false
    end)
end
-- ============================================
-- AUTO SERVER HOP & TELEPORT PERSISTENCE
-- ============================================
local isHopping = false
local function serverHop()
    if isHopping then return end
    isHopping = true

    pcall(function()
        Window:Notify({
            Title = "Auto Server Hop",
            Desc = "Queueing script & finding new server...",
            Time = 6
        })
    end)

    local queueteleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if queueteleport then
        queueteleport([[
            task.wait(3)
            pcall(function()
                loadstring(game:HttpGet("https://projectsingularity.online/raw/repos/191c9695-c9f9-4b5f-805f-d87e8e3b8fac/gun%20auto.lua"))()
            end)
        ]])
    end

    task.spawn(function()
        local placeId = game.PlaceId
        local currentJobId = game.JobId
        local serverListUrl = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"
        
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(serverListUrl))
        end)

        local targetJob = nil
        if success and result and result.data then
            local validServers = {}
            for _, s in ipairs(result.data) do
                if type(s) == "table" and s.id and s.id ~= currentJobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.playing > 1 then
                    table.insert(validServers, s.id)
                end
            end
            if #validServers > 0 then
                targetJob = validServers[math.random(1, #validServers)]
            end
        end

        if targetJob then
            pcall(function()
                Window:Notify({
                    Title = "Server Found",
                    Desc = "Teleporting to server (" .. tostring(targetJob):sub(1, 8) .. ")...",
                    Time = 5
                })
            end)
            task.wait(1.5)
            TeleportService:TeleportToPlaceInstance(placeId, targetJob, LocalPlayer)
        else
            pcall(function()
                Window:Notify({
                    Title = "Server Hop",
                    Desc = "Connecting to new server instance...",
                    Time = 5
                })
            end)
            task.wait(1.5)
            TeleportService:Teleport(placeId, LocalPlayer)
        end
    end)
end

-- ============================================
-- GHOST FLY SYSTEM
-- ============================================
getgenv().GhostFlyKey = Enum.KeyCode.X

local ghostFlyVelocity = nil
local ghostFlyGyro = nil
local ghostRenderConn = nil
local ghostSteppedConn = nil

local ghostKeys = {
    W = false,
    A = false,
    S = false,
    D = false,
    Space = false,
    LeftShift = false
}

local function startGhostFly()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    local oldBV = hrp:FindFirstChild("GhostFlyVelocity_Manual")
    if oldBV then oldBV:Destroy() end
    local oldBG = hrp:FindFirstChild("GhostFlyGyro_Manual")
    if oldBG then oldBG:Destroy() end

    ghostFlyVelocity = Instance.new("BodyVelocity")
    ghostFlyVelocity.Name = "GhostFlyVelocity_Manual"
    ghostFlyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    ghostFlyVelocity.Velocity = Vector3.new(0, 0, 0)
    ghostFlyVelocity.Parent = hrp
    
    ghostFlyGyro = Instance.new("BodyGyro")
    ghostFlyGyro.Name = "GhostFlyGyro_Manual"
    ghostFlyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    ghostFlyGyro.P = 3000
    ghostFlyGyro.D = 500
    ghostFlyGyro.CFrame = workspace.CurrentCamera.CFrame
    ghostFlyGyro.Parent = hrp
    
    if ghostRenderConn then ghostRenderConn:Disconnect() end
    ghostRenderConn = RunService.RenderStepped:Connect(function()
        if not getgenv().GhostFlyEnabled then return end
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)
        
        if ghostKeys.W then moveDir = moveDir + cam.CFrame.LookVector end
        if ghostKeys.S then moveDir = moveDir - cam.CFrame.LookVector end
        if ghostKeys.A then moveDir = moveDir - cam.CFrame.RightVector end
        if ghostKeys.D then moveDir = moveDir + cam.CFrame.RightVector end
        
        local upDown = 0
        if ghostKeys.Space then upDown = upDown + 1 end
        if ghostKeys.LeftShift then upDown = upDown - 1 end
        
        moveDir = moveDir + Vector3.new(0, upDown, 0)
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end
        
        if ghostFlyVelocity and ghostFlyVelocity.Parent then
            ghostFlyVelocity.Velocity = moveDir * (getgenv().GhostFlySpeed or 50)
        end
        if ghostFlyGyro and ghostFlyGyro.Parent then
            ghostFlyGyro.CFrame = cam.CFrame
        end
    end)
    
    if ghostSteppedConn then ghostSteppedConn:Disconnect() end
    ghostSteppedConn = RunService.Stepped:Connect(function()
        if not getgenv().GhostFlyEnabled then return end
        if getgenv().GhostFlyNoclip and character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopGhostFly()
    if ghostRenderConn then 
        ghostRenderConn:Disconnect() 
        ghostRenderConn = nil
    end
    if ghostSteppedConn then 
        ghostSteppedConn:Disconnect() 
        ghostSteppedConn = nil
    end
    
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("GhostFlyVelocity_Manual")
            if bv then bv:Destroy() end
            local bg = hrp:FindFirstChild("GhostFlyGyro_Manual")
            if bg then bg:Destroy() end
            
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end
end

local function toggleGhostFly(state)
    getgenv().GhostFlyEnabled = state
    if state then
        stopGhostFly()
        startGhostFly()
        Window:Notify({Title = "Ghost Fly", Desc = "Ghost Fly Enabled (WASD + Space/Shift)", Time = 3})
    else
        stopGhostFly()
        Window:Notify({Title = "Ghost Fly", Desc = "Ghost Fly Disabled", Time = 3})
    end
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then ghostKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then ghostKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then ghostKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then ghostKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then ghostKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then ghostKeys.LeftShift = true end
    
    if input.KeyCode == (getgenv().GhostFlyKey or Enum.KeyCode.X) then
        toggleGhostFly(not getgenv().GhostFlyEnabled)
    end
end)

UIS.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.W then ghostKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then ghostKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then ghostKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then ghostKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then ghostKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then ghostKeys.LeftShift = false end
end)

-- ============================================
-- GODMODE SYSTEM
-- ============================================
getgenv().GodmodeEnabled = false
getgenv().AntiFallDamage = true

local godmodeConn = nil
local function applyGodmode(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    
    if godmodeConn then godmodeConn:Disconnect() godmodeConn = nil end
    
    if getgenv().GodmodeEnabled then
        godmodeConn = hum.HealthChanged:Connect(function(newHealth)
            if getgenv().GodmodeEnabled and newHealth < hum.MaxHealth and newHealth > 0 then
                hum.Health = hum.MaxHealth
            end
        end)
        
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end
end

local function toggleGodmode(state)
    getgenv().GodmodeEnabled = state
    local char = LocalPlayer.Character
    if state then
        applyGodmode(char)
        Window:Notify({Title = "Godmode", Desc = "Godmode Enabled (Health Lock & Anti-Ragdoll)", Time = 3})
    else
        if godmodeConn then godmodeConn:Disconnect() godmodeConn = nil end
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                end)
            end
        end
        Window:Notify({Title = "Godmode", Desc = "Godmode Disabled", Time = 3})
    end
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    if getgenv().GodmodeEnabled then
        applyGodmode(newChar)
    end
    if getgenv().AutoArmor then
        task.wait(0.5)
        getArmor(true)
    end
end)

-- ============================================
-- AUTO ARMOR SYSTEM
-- ============================================
getgenv().AutoArmor = false
getgenv().AutoArmorInterval = 10

local armorCFrame = CFrame.new(-1439.97827, -81.8992996, 204.404205, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local isGettingArmor = false

local function getArmorPrompt()
    local prompt = nil
    -- 1. Try exact path specified: workspace.OtherItems:GetChildren()[180].Belt.Giver.ProximityPrompt
    pcall(function()
        local otherItems = workspace:FindFirstChild("OtherItems")
        if otherItems then
            local children = otherItems:GetChildren()
            local item180 = children[180]
            if item180 then
                local belt = item180:FindFirstChild("Belt")
                local giver = belt and belt:FindFirstChild("Giver")
                local p = giver and (giver:FindFirstChildOfClass("ProximityPrompt") or giver:FindFirstChild("ProximityPrompt"))
                if p and p.Enabled then
                    prompt = p
                end
            end
        end
    end)
    if prompt then return prompt end

    -- 2. Dynamic search across all items in OtherItems for Belt.Giver.ProximityPrompt
    pcall(function()
        local otherItems = workspace:FindFirstChild("OtherItems")
        if otherItems then
            for _, item in ipairs(otherItems:GetChildren()) do
                local belt = item:FindFirstChild("Belt")
                if belt then
                    local giver = belt:FindFirstChild("Giver")
                    if giver then
                        local p = giver:FindFirstChildOfClass("ProximityPrompt") or giver:FindFirstChild("ProximityPrompt")
                        if p and p.Enabled then
                            prompt = p
                            return
                        end
                    end
                end
            end
        end
    end)
    if prompt then return prompt end

    -- 3. Position-based search near target armor CFrame
    pcall(function()
        local targetPos = Vector3.new(-1439.97827, -81.8992996, 204.404205)
        local container = workspace:FindFirstChild("OtherItems") or workspace
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local parent = desc.Parent
                if parent and parent:IsA("BasePart") then
                    if (parent.Position - targetPos).Magnitude <= 35 then
                        prompt = desc
                        return
                    end
                end
            end
        end
    end)
    return prompt
end

local function firePromptInstant(prompt)
    if not prompt then return end
    local oldHold = prompt.HoldDuration
    prompt.HoldDuration = 0
    if fireproximityprompt then
        fireproximityprompt(prompt, 0)
    else
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end
    task.wait(0.1)
    prompt.HoldDuration = oldHold
end

local function getArmor(silent)
    if isGettingArmor then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    isGettingArmor = true
    local origCFrame = hrp.CFrame

    local success = false
    pcall(function()
        -- 1. Warp to armor giver location
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
        hrp.CFrame = armorCFrame
        task.wait(0.12)

        -- 2. Press E with 0 cooldown (like robbery prompt)
        local prompt = getArmorPrompt()
        if prompt then
            firePromptInstant(prompt)
            success = true
        else
            -- Proximity sweep near character
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled and desc.Parent and desc.Parent:IsA("BasePart") then
                    if (desc.Parent.Position - hrp.Position).Magnitude <= (desc.MaxActivationDistance + 5) then
                        firePromptInstant(desc)
                        success = true
                        break
                    end
                end
            end
        end

        task.wait(0.1)

        -- 3. Warp back to original position
        if hrp and hrp.Parent then
            hrp.CFrame = origCFrame
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end)

    isGettingArmor = false

    if not silent then
        if success then
            Window:Notify({Title = "Armor", Desc = "Equipped armor & returned to origin", Time = 3})
        else
            Window:Notify({Title = "Armor", Desc = "Warped & returned (Armor prompt not found or on cooldown)", Time = 3})
        end
    end
end

-- Auto Armor background monitor
task.spawn(function()
    while true do
        task.wait(getgenv().AutoArmorInterval or 10)
        if getgenv().AutoArmor then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 and not isGettingArmor then
                local hasBelt = char:FindFirstChild("Belt") or char:FindFirstChild("Armor") or char:FindFirstChild("Vest")
                local armorVal = char:FindFirstChild("Armor") or char:FindFirstChild("ArmorValue")
                local needArmor = false

                if armorVal and armorVal:IsA("ValueBase") then
                    if armorVal.Value <= 0 then
                        needArmor = true
                    end
                elseif not hasBelt then
                    needArmor = true
                end

                if needArmor then
                    getArmor(true)
                end
            end
        end
    end
end)


-- ============================================
-- AIMBOT SETTINGS & VARIABLES
-- ============================================
local AimbotSettings = {
    teamCheck = ConfigState.teamCheck,
    fov = ConfigState.fov,
    smoothing = ConfigState.smoothing,
    predictionFactor = ConfigState.predictionFactor,
    aimbotEnabled = ConfigState.aimbotEnabled,
    Toggle = ConfigState.Toggle,
    toggleKey = Enum.KeyCode.E,
    toggleKeyName = "E",
    lockMode = ConfigState.lockMode,
    wallCheck = ConfigState.wallCheck,
    maxWallDistance = 1000,
    showFOV = ConfigState.showFOV,
    fovFilled = ConfigState.fovFilled,
    fovThickness = 2,
    fovColor = Color3.fromRGB(255, 50, 50),
}

local Whitelist = (type(ConfigState.Whitelist) == "table" and ConfigState.Whitelist) or {}
local function isWhitelisted(player)
    local name = player.Name:lower()
    for _, wName in ipairs(Whitelist) do
        if wName:lower() == name then return true end
    end
    return false
end
local function addToWhitelist(name)
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return false end
    local nameLower = name:lower()
    for _, wName in ipairs(Whitelist) do
        if wName:lower() == nameLower then return false end
    end
    table.insert(Whitelist, name)
    SaveConfig()
    return true
end
local function removeFromWhitelist(name)
    name = name:lower()
    for i, wName in ipairs(Whitelist) do
        if wName:lower() == name then
            table.remove(Whitelist, i)
            SaveConfig()
            return true
        end
    end
    return false
end

local currentTarget = nil
local aimbotToggleState = false
local aimbotCamera = workspace.CurrentCamera

local cachedRaycastParams = RaycastParams.new()
cachedRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
cachedRaycastParams.IgnoreWater = true

local cachedAimRaycastParams = RaycastParams.new()
cachedAimRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
cachedAimRaycastParams.IgnoreWater = true

local lastFilterCharacter = nil

local FOVring = Drawing.new("Circle")
FOVring.Visible = AimbotSettings.showFOV
FOVring.Thickness = AimbotSettings.fovThickness
FOVring.Radius = AimbotSettings.fov
FOVring.Transparency = 0.8
FOVring.Color = AimbotSettings.fovColor
FOVring.Filled = AimbotSettings.fovFilled
FOVring.Position = Vector2.new(aimbotCamera.ViewportSize.X / 2, aimbotCamera.ViewportSize.Y / 2)

local function isTargetVisible(targetPosition)
    if not AimbotSettings.wallCheck then return true end
    local origin = aimbotCamera.CFrame.Position
    local direction = (targetPosition - origin).Unit
    local distance = (targetPosition - origin).Magnitude

    if LocalPlayer.Character ~= lastFilterCharacter then
        lastFilterCharacter = LocalPlayer.Character
        if LocalPlayer.Character then
            cachedRaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            cachedAimRaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        end
    end

    local result = workspace:Raycast(origin, direction * math.min(distance, AimbotSettings.maxWallDistance), cachedRaycastParams)
    if not result then return true end

    local hitPart = result.Instance
    if hitPart then
        local hitModel = hitPart:FindFirstAncestorOfClass("Model")
        if hitModel and Players:GetPlayerFromCharacter(hitModel) then
            return true
        end
        return false
    end
    return true
end

local function getTargetPart(player)
    if not player or not player.Character then return nil end
    local character = player.Character
    local mode = AimbotSettings.lockMode

    if mode == "Random" then
        local parts = {"Head","UpperTorso","HumanoidRootPart","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg"}
        local available = {}
        for _, name in ipairs(parts) do
            local p = character:FindFirstChild(name)
            if p then table.insert(available, p) end
        end
        if #available > 0 then return available[math.random(1, #available)] end
    end

    if mode == "Head" then return character:FindFirstChild("Head")
    elseif mode == "Torso" then return character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    elseif mode == "LeftArm" then return character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("LeftLowerArm")
    elseif mode == "RightArm" then return character:FindFirstChild("RightUpperArm") or character:FindFirstChild("RightLowerArm")
    elseif mode == "LeftLeg" then return character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("LeftLowerLeg")
    elseif mode == "RightLeg" then return character:FindFirstChild("RightUpperLeg") or character:FindFirstChild("RightLowerLeg")
    end

    return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function getClosestPlayer()
    if not AimbotSettings.aimbotEnabled then return nil end
    if not LocalPlayer.Character then return nil end

    local closestPlayer = nil
    local closestDistance = AimbotSettings.fov
    local screenCenter = Vector2.new(aimbotCamera.ViewportSize.X / 2, aimbotCamera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if AimbotSettings.teamCheck and player.Team == LocalPlayer.Team then continue end
        if isWhitelisted(player) then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChild("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not (humanoid and hrp) then continue end
        if humanoid.Health <= 0 then continue end

        local screenPosition, onScreen = aimbotCamera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end

        local screenPos = Vector2.new(screenPosition.X, screenPosition.Y)
        local distance = (screenPos - screenCenter).Magnitude

        if distance <= closestDistance then
            if AimbotSettings.wallCheck and not isTargetVisible(hrp.Position) then continue end
            closestDistance = distance
            closestPlayer = player
        end
    end
    return closestPlayer
end

local function getTargetPosition(player)
    if not player or not player.Character then return nil end
    local targetPart = getTargetPart(player)
    if not targetPart then return nil end
    if AimbotSettings.wallCheck and not isTargetVisible(targetPart.Position) then
        return nil
    end
    local velocity = targetPart.AssemblyLinearVelocity
    local distance = (targetPart.Position - aimbotCamera.CFrame.Position).Magnitude
    local travelTime = distance / 1000
    return targetPart.Position + (velocity * travelTime * AimbotSettings.predictionFactor)
end

local function aimAtPosition(targetPosition)
    if not targetPosition or not LocalPlayer.Character then return end
    local currentCF = aimbotCamera.CFrame
    local direction = (targetPosition - currentCF.Position).Unit

    if AimbotSettings.wallCheck then
        local result = workspace:Raycast(currentCF.Position, direction * 100, cachedAimRaycastParams)
        if result and result.Instance then
            local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
            if not Players:GetPlayerFromCharacter(hitModel) then return end
        end
    end

    local newCF = CFrame.new(currentCF.Position, currentCF.Position + direction)
    aimbotCamera.CFrame = currentCF:Lerp(newCF, AimbotSettings.smoothing)
end

local function updateAimbot()
    if not AimbotSettings.aimbotEnabled then currentTarget = nil; return end
    if AimbotSettings.Toggle and not aimbotToggleState then currentTarget = nil; return end

    local keepTarget = false
    if currentTarget and currentTarget.Character then
        local humanoid = currentTarget.Character:FindFirstChild("Humanoid")
        local hrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and hrp and humanoid.Health > 0 then
            local _, onScreen = aimbotCamera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                if AimbotSettings.wallCheck then
                    keepTarget = isTargetVisible(hrp.Position)
                else
                    keepTarget = true
                end
            end
        end
    end

    if not keepTarget then
        currentTarget = getClosestPlayer()
    end

    if currentTarget then
        local targetPosition = getTargetPosition(currentTarget)
        if targetPosition then
            aimAtPosition(targetPosition)
        else
            currentTarget = nil
        end
    end
end


-- ============================================
-- AIMBOT UI SETUP
-- ============================================
sections.AimbotMain:Toggle({
    Name = "Enable Aimbot",
    Description = "Enable camera aimbot assistance",
    Default = AimbotSettings.aimbotEnabled,
    Callback = function(v) 
        AimbotSettings.aimbotEnabled = v 
        SaveConfig()
    end
}, "AimbotEnabled")

sections.AimbotMain:Toggle({
    Name = "Keybind Mode",
    Description = "Use keybind to activate/deactivate aimbot",
    Default = AimbotSettings.Toggle,
    Callback = function(v) 
        AimbotSettings.Toggle = v 
        SaveConfig()
    end
}, "AimbotToggleMode")

sections.AimbotMain:Keybind({
    Name = "Target Key",
    Description = "Aimbot toggle keybind",
    Default = AimbotSettings.toggleKey or Enum.KeyCode.E,
    onBinded = function(key)
        AimbotSettings.toggleKey = key
    end,
    Callback = function(key)
        AimbotSettings.toggleKey = key
        if AimbotSettings.Toggle then
            aimbotToggleState = not aimbotToggleState
            Window:Notify({ Title = "Aimbot", Description = aimbotToggleState and "ACTIVATED" or "DEACTIVATED", Lifetime = 2 })
        end
    end
}, "AimbotKeybind")

sections.AimbotTargeting:Toggle({
    Name = "Team Check", 
    Description = "Don't aim at teammates", 
    Default = AimbotSettings.teamCheck, 
    Callback = function(v) 
        AimbotSettings.teamCheck = v 
        SaveConfig()
    end
}, "AimbotTeamCheck")

sections.AimbotTargeting:Toggle({
    Name = "Wall Check", 
    Description = "Line of sight check through walls", 
    Default = AimbotSettings.wallCheck, 
    Callback = function(v) 
        AimbotSettings.wallCheck = v 
        SaveConfig()
    end
}, "AimbotWallCheck")

sections.AimbotTargeting:Dropdown({
    Name = "Target Part",
    Description = "Target body part to aim at",
    Options = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Random"},
    Default = AimbotSettings.lockMode or "Head",
    Callback = function(choice) 
        AimbotSettings.lockMode = choice 
        SaveConfig()
    end
}, "AimbotLockMode")

sections.AimbotAccuracy:Slider({
    Name = "FOV Radius", 
    Description = "Aimbot detection radius", 
    Minimum = 50, 
    Maximum = 300, 
    Precision = 0,
    DisplayMethod = "Value",
    Default = AimbotSettings.fov or 150,
    Callback = function(val) 
        AimbotSettings.fov = val 
        if FOVring then FOVring.Radius = val end
        SaveConfig()
    end
}, "AimbotFOV")

sections.AimbotAccuracy:Slider({
    Name = "Smoothness", 
    Description = "Aimbot smoothing (lower is faster)", 
    Minimum = 1, 
    Maximum = 50, 
    Precision = 0,
    DisplayMethod = "Value",
    Default = math.floor((AimbotSettings.smoothing or 0.15) * 100),
    Callback = function(val) 
        AimbotSettings.smoothing = val / 100 
        SaveConfig()
    end
}, "AimbotSmoothing")

sections.AimbotAccuracy:Slider({
    Name = "Prediction", 
    Description = "Target movement prediction factor", 
    Minimum = 0, 
    Maximum = 30, 
    Precision = 0,
    DisplayMethod = "Value",
    Default = math.floor((AimbotSettings.predictionFactor or 0.165) * 100),
    Callback = function(val) 
        AimbotSettings.predictionFactor = val / 100 
        SaveConfig()
    end
}, "AimbotPrediction")

sections.AimbotVisuals:Toggle({
    Name = "Draw FOV Circle", 
    Description = "Draw circle around cursor indicating FOV", 
    Default = AimbotSettings.showFOV,
    Callback = function(v) 
        AimbotSettings.showFOV = v 
        if FOVring then FOVring.Visible = v end
        SaveConfig()
    end
}, "AimbotShowFOV")

sections.AimbotVisuals:Toggle({
    Name = "Fill FOV Area", 
    Description = "Fill interior area of FOV circle", 
    Default = AimbotSettings.fovFilled,
    Callback = function(v) 
        AimbotSettings.fovFilled = v 
        if FOVring then FOVring.Filled = v end
        SaveConfig()
    end
}, "AimbotFillFOV")

-- ============================================
-- WHITELIST UI SETUP
-- ============================================
local playerDropdownList = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(playerDropdownList, p.Name)
    end
end
if #playerDropdownList == 0 then
    playerDropdownList = {"(No Players)"}
end

local selectedPlayerName = playerDropdownList[1]
local whitelistDropdown = sections.WhitelistConfig:Dropdown({
    Name = "Select Player",
    Description = "Select from online players to ignore in aimbot",
    Options = playerDropdownList,
    Default = 1,
    Callback = function(choice)
        selectedPlayerName = choice
    end
}, "WhitelistSelectPlayer")

sections.WhitelistConfig:Button({
    Name = "Add Selected Player",
    Description = "Add selected player to Whitelist",
    Callback = function()
        if selectedPlayerName == "(No Players)" or not selectedPlayerName then return end
        if addToWhitelist(selectedPlayerName) then
            Window:Notify({ Title = "Whitelist", Description = "Added " .. selectedPlayerName, Lifetime = 3 })
        else
            Window:Notify({ Title = "Whitelist", Description = selectedPlayerName .. " is already in list", Lifetime = 3 })
        end
    end
})

sections.WhitelistConfig:Button({
    Name = "Remove Selected Player",
    Description = "Remove selected player from Whitelist",
    Callback = function()
        if selectedPlayerName == "(No Players)" or not selectedPlayerName then return end
        if removeFromWhitelist(selectedPlayerName) then
            Window:Notify({ Title = "Whitelist", Description = "Removed " .. selectedPlayerName, Lifetime = 3 })
        else
            Window:Notify({ Title = "Whitelist", Description = selectedPlayerName .. " is not in list", Lifetime = 3 })
        end
    end
})

sections.WhitelistManage:Button({
    Name = "View Whitelist",
    Description = "Show all whitelisted player names",
    Callback = function()
        if #Whitelist == 0 then
            Window:Notify({ Title = "Whitelist", Description = "No names in whitelist yet", Lifetime = 3 })
        else
            local names = table.concat(Whitelist, ", ")
            Window:Notify({ Title = "Whitelist (" .. #Whitelist .. " players)", Description = names, Lifetime = 5 })
        end
    end
})

sections.WhitelistManage:Button({
    Name = "Clear Whitelist",
    Description = "Clear all whitelisted player names",
    Callback = function()
        Whitelist = {}
        SaveConfig()
        Window:Notify({ Title = "Whitelist", Description = "Cleared all names", Lifetime = 3 })
    end
})

-- ============================================
-- AUTO FARM UI SETUP
-- ============================================
sections.FarmMain:Toggle({ 
    Name = "Auto Rob Bank", 
    Description = "Fly to bank, disable lasers, and collect cash automatically",
    Default = getgenv().AutoRobBank, 
    Callback = function(val) 
        getgenv().AutoRobBank = val 
        SaveConfig()
    end 
}, "AutoRobBank")

sections.FarmMain:Toggle({ 
    Name = "Fast Collect", 
    Description = "Instantly trigger proximity prompts without hold delay",
    Default = getgenv().FastCollect, 
    Callback = function(val) 
        getgenv().FastCollect = val 
        SaveConfig()
    end 
}, "FastCollect")

sections.FarmMain:Slider({
    Name = "Auto Rob Fly Speed",
    Description = "Adjust flying speed for bank robbery navigation",
    Minimum = 50,
    Maximum = 300,
    Precision = 0,
    DisplayMethod = "Value",
    Default = getgenv().FlySpeed or 150,
    Callback = function(val)
        getgenv().FlySpeed = val
        SaveConfig()
    end
}, "AutoRobFlySpeed")

sections.FarmHop:Toggle({ 
    Name = "Auto Server Hop", 
    Description = "Auto hop server when all banks are robbed / on cooldown",
    Default = getgenv().AutoServerHop, 
    Callback = function(val) 
        getgenv().AutoServerHop = val 
        SaveConfig()
    end 
}, "AutoServerHop")

sections.FarmHop:Button({
    Name = "Server Hop Now",
    Description = "Switch server and continue script automatically",
    Callback = function()
        serverHop()
    end
})

-- ============================================
-- PLAYER TAB CONTROLS (GHOST FLY & GODMODE)
-- ============================================
sections.PlayerFlight:Toggle({
    Name = "Ghost Fly",
    Description = "Fly with WASD + Space (Up) / Shift (Down) [Key: X]",
    Default = getgenv().GhostFlyEnabled,
    Callback = function(val)
        toggleGhostFly(val)
        SaveConfig()
    end
}, "GhostFlyEnabled")

sections.PlayerFlight:Slider({
    Name = "Ghost Fly Speed",
    Description = "Adjust manual flying speed",
    Minimum = 10,
    Maximum = 300,
    Precision = 0,
    DisplayMethod = "Value",
    Default = getgenv().GhostFlySpeed or 50,
    Callback = function(val)
        getgenv().GhostFlySpeed = val
        SaveConfig()
    end
}, "GhostFlySpeed")

sections.PlayerFlight:Toggle({
    Name = "Noclip While Flying",
    Description = "Pass through walls and obstacles while flying",
    Default = getgenv().GhostFlyNoclip,
    Callback = function(val)
        getgenv().GhostFlyNoclip = val
        SaveConfig()
    end
}, "GhostFlyNoclip")

sections.PlayerDefense:Toggle({
    Name = "Godmode",
    Description = "Continuous health protection & anti-ragdoll",
    Default = getgenv().GodmodeEnabled,
    Callback = function(val)
        toggleGodmode(val)
        SaveConfig()
    end
}, "GodmodeEnabled")

sections.PlayerDefense:Toggle({
    Name = "Anti Fall Damage",
    Description = "Prevents damage and knockdown from falling",
    Default = getgenv().AntiFallDamage,
    Callback = function(val)
        getgenv().AntiFallDamage = val
        SaveConfig()
    end
}, "AntiFallDamage")

sections.PlayerDefense:Toggle({
    Name = "Auto Armor",
    Description = "Auto warp to get armor (0s cooldown) and return when missing",
    Default = getgenv().AutoArmor,
    Callback = function(val)
        getgenv().AutoArmor = val
        SaveConfig()
        if val then
            getArmor(false)
        end
    end
}, "AutoArmor")

sections.PlayerDefense:Button({
    Name = "Get Armor Now",
    Description = "Warp to Belt Giver, press E (0s cooldown) & warp back to origin",
    Callback = function()
        getArmor(false)
    end
})

sections.PlayerDefense:Slider({
    Name = "Auto Armor Interval",
    Description = "How often to check and re-equip armor (seconds)",
    Minimum = 5,
    Maximum = 60,
    Precision = 0,
    DisplayMethod = "Value",
    Default = getgenv().AutoArmorInterval or 10,
    Callback = function(val)
        getgenv().AutoArmorInterval = val
        SaveConfig()
    end
}, "AutoArmorInterval")

-- ============================================
-- ESP TAB CONTROLS
-- ============================================
sections.ESPMain:Toggle({ 
    Name = "Bank ESP", 
    Description = "Show bank locations, distance, and robbery status",
    Default = getgenv().BankESP, 
    Callback = function(val) 
        getgenv().BankESP = val 
        SaveConfig()
    end 
}, "BankESP")

sections.ESPMain:Toggle({
    Name = "Player ESP Master",
    Description = "Master toggle for all player ESP highlights",
    Default = getgenv().PlayerESP,
    Callback = function(val)
        getgenv().PlayerESP = val
        SaveConfig()
    end
}, "PlayerESP")

sections.ESPElements:Toggle({
    Name = "Name ESP",
    Description = "Show player display name and username",
    Default = getgenv().NameESP,
    Callback = function(val)
        getgenv().NameESP = val
        SaveConfig()
    end
}, "NameESP")

sections.ESPElements:Toggle({
    Name = "Health Bar & Numbers",
    Description = "Shows health bar and numeric HP",
    Default = getgenv().HealthESP,
    Callback = function(val)
        getgenv().HealthESP = val
        SaveConfig()
    end
}, "HealthESP")

sections.ESPElements:Toggle({
    Name = "Inventory / Tool Icons ESP",
    Description = "Shows equipped gun & backpack items as icons",
    Default = getgenv().ToolESP,
    Callback = function(val)
        getgenv().ToolESP = val
        SaveConfig()
    end
}, "ToolESP")

sections.ESPElements:Toggle({
    Name = "Distance ESP",
    Description = "Displays distance in studs to target",
    Default = getgenv().DistESP,
    Callback = function(val)
        getgenv().DistESP = val
        SaveConfig()
    end
}, "DistESP")

sections.ESPElements:Toggle({
    Name = "2D Box ESP",
    Description = "Draws 2D bounding boxes around players",
    Default = getgenv().BoxESP,
    Callback = function(val)
        getgenv().BoxESP = val
        SaveConfig()
    end
}, "BoxESP")

sections.ESPElements:Toggle({
    Name = "Tracer Lines ESP",
    Description = "Draws tracer line from bottom of screen to target",
    Default = getgenv().TracerESP,
    Callback = function(val)
        getgenv().TracerESP = val
        SaveConfig()
    end
}, "TracerESP")

sections.ESPCustom:Dropdown({
    Name = "ESP Style",
    Description = "Select visual style for player highlights",
    Options = {"2D", "3D"},
    Default = getgenv().ESPStyle or "2D",
    Callback = function(val)
        getgenv().ESPStyle = val
        SaveConfig()
    end
}, "ESPStyle")

sections.ESPCustom:Dropdown({
    Name = "ESP Color",
    Description = "Select color theme for ESP boxes and highlights",
    Options = {"Red", "Green", "Blue", "Yellow", "Orange", "Purple", "Cyan", "White"},
    Default = getgenv().ESPColorName or "Red",
    Callback = function(val)
        getgenv().ESPColorName = val
        if val == "Red" then getgenv().ESPColor = Color3.fromRGB(255, 60, 60)
        elseif val == "Green" then getgenv().ESPColor = Color3.fromRGB(40, 240, 80)
        elseif val == "Blue" then getgenv().ESPColor = Color3.fromRGB(60, 160, 255)
        elseif val == "Yellow" then getgenv().ESPColor = Color3.fromRGB(255, 230, 40)
        elseif val == "Orange" then getgenv().ESPColor = Color3.fromRGB(255, 140, 30)
        elseif val == "Purple" then getgenv().ESPColor = Color3.fromRGB(180, 80, 255)
        elseif val == "Cyan" then getgenv().ESPColor = Color3.fromRGB(40, 240, 240)
        elseif val == "White" then getgenv().ESPColor = Color3.fromRGB(255, 255, 255)
        end
        SaveConfig()
    end
}, "ESPColor")

-- ============================================
-- TELEPORT TAB
-- ============================================
local tpDropdownList = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(tpDropdownList, p.Name)
    end
end
if #tpDropdownList == 0 then
    tpDropdownList = {"(No Players)"}
end

local tpSelectedPlayer = tpDropdownList[1]

local tpDropdown = sections.TeleportPlayers:Dropdown({
    Name = "Select Player",
    Description = "Select from online players",
    Options = tpDropdownList,
    Default = 1,
    Callback = function(choice)
        tpSelectedPlayer = choice
    end
}, "TeleportSelectPlayer")

sections.TeleportPlayers:Button({
    Name = "Teleport To Player",
    Description = "Teleport directly behind selected player",
    Callback = function()
        if tpSelectedPlayer == "(No Players)" or not tpSelectedPlayer then return end
        local p = Players:FindFirstChild(tpSelectedPlayer)
        if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local targetCFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                hrp.CFrame = targetCFrame
                Window:Notify({ Title = "Teleport", Description = "Teleported to " .. tpSelectedPlayer, Lifetime = 3 })
            end
        else
            Window:Notify({ Title = "Teleport", Description = "Target character not found", Lifetime = 3 })
        end
    end
})

sections.TeleportPlayers:Button({
    Name = "Teleport To Armor Giver",
    Description = "Teleport directly to armor belt giver machine",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = armorCFrame
            Window:Notify({ Title = "Teleport", Description = "Teleported to Armor Giver", Lifetime = 3 })
        end
    end
})

sections.TeleportPlayers:Button({
    Name = "Refresh Players",
    Description = "Refresh online players list in dropdown",
    Callback = function()
        local newList = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(newList, p.Name)
            end
        end
        if #newList == 0 then newList = {"(No Players)"} end
        tpDropdown:ClearOptions()
        tpDropdown:InsertOptions(newList)
        tpDropdown:UpdateSelection(newList[1])
        tpSelectedPlayer = newList[1]
        Window:Notify({ Title = "Teleport", Description = "Player list updated", Lifetime = 3 })
    end
})

getgenv().OrbitAttack = false
getgenv().OrbitDistance = 15
getgenv().OrbitSpeed = 3
getgenv().OrbitHeight = 5

sections.TeleportOrbit:Toggle({
    Name = "Orbit & Attack",
    Description = "Orbit selected player and auto-attack",
    Default = getgenv().OrbitAttack,
    Callback = function(val)
        getgenv().OrbitAttack = val
        SaveConfig()
    end
}, "OrbitAttack")

sections.TeleportOrbit:Slider({
    Name = "Orbit Distance",
    Description = "Distance from target player",
    Minimum = 5,
    Maximum = 50,
    Precision = 0,
    DisplayMethod = "Value",
    Default = getgenv().OrbitDistance or 15,
    Callback = function(val)
        getgenv().OrbitDistance = val
        SaveConfig()
    end
}, "OrbitDistance")

sections.TeleportOrbit:Slider({
    Name = "Orbit Speed",
    Description = "Orbiting rotation speed",
    Minimum = 1,
    Maximum = 15,
    Precision = 0,
    DisplayMethod = "Value",
    Default = getgenv().OrbitSpeed or 3,
    Callback = function(val)
        getgenv().OrbitSpeed = val
        SaveConfig()
    end
}, "OrbitSpeed")

-- ============================================
-- UI SETTINGS TAB
-- ============================================
sections.SettingsMain:Dropdown({
    Name = "Closed UI Style",
    Description = "Select the style of the minimized UI.",
    Options = { "Hidden", "Breadcrumb" },
    Default = 1,
    Callback = function(style)
        if Window.SetClosedUIStyle then
            Window:SetClosedUIStyle(style)
        end
    end
}, "ClosedUIStyle")

sections.SettingsMain:Keybind({
    Name = "Toggle Keybind",
    Description = "Key used to open and close the interface.",
    Default = Enum.KeyCode.RightControl,
    onBinded = function(key)
        if Window and Window.SetKeybind then
            Window:SetKeybind(key)
        end
    end,
    Callback = function(key)
        if Window and Window.SetKeybind then
            Window:SetKeybind(key)
        end
    end
}, "MenuKeybind")

sections.SettingsMain:Colorpicker({
    Name = "Accent Color",
    Description = "Change the UI theme and sidebar icon color.",
    Default = Color3.fromRGB(29, 235, 169),
    Callback = function(color)
        if Window and Window.SetAccentColor then
            Window:SetAccentColor(color)
        end
    end
}, "AccentColor")

sections.SettingsMain:Slider({
    Name = "UI Scale",
    Description = "Adjust the overall size of the interface.",
    Default = 100,
    Minimum = 75,
    Maximum = 130,
    DisplayMethod = "%",
    Precision = 0,
    Callback = function(v)
        if Window and Window.SetScale then
            Window:SetScale(v / 100)
        end
    end
}, "UIScale")

sections.SettingsMain:Slider({
    Name = "UI Transparency",
    Description = "Adjust the transparency level of the interface.",
    Default = 20,
    Minimum = 0,
    Maximum = 80,
    DisplayMethod = "%",
    Precision = 0,
    Callback = function(v)
        if Window and Window.SetTransparency then
            Window:SetTransparency(v / 100)
        end
    end
}, "UITransparency")

sections.SettingsMain:Button({
    Name = "คืนค่าเริ่มต้น (Reset UI Settings)",
    Description = "รีเซ็ตการตั้งค่า UI ทั้งหมดกลับเป็นค่าเริ่มต้น",
    Callback = function()
        if MacLib.Options.MenuKeybind then MacLib.Options.MenuKeybind:SetKey(Enum.KeyCode.RightControl) end
        if MacLib.Options.AccentColor then MacLib.Options.AccentColor:SetColor(Color3.fromRGB(29, 235, 169)) end
        if MacLib.Options.UIScale then MacLib.Options.UIScale:SetValue(100) end
        if MacLib.Options.UITransparency then MacLib.Options.UITransparency:SetValue(20) end
        if Window and Window.SetAcrylicBlurState then Window:SetAcrylicBlurState(false) end
        if Window and Window.SetNotificationsState then Window:SetNotificationsState(true) end
        Window:Notify({ Title = "Settings", Description = "คืนค่าการตั้งค่า UI เป็นค่าเริ่มต้นแล้ว", Lifetime = 3 })
    end
})

sections.SettingsConfig:Button({
    Name = "Save Config Now",
    Description = "Manually save all current script settings to disk",
    Callback = function()
        SaveConfig()
        Window:Notify({ Title = "Config Saved", Description = "Settings saved to " .. CONFIG_FILE, Lifetime = 3 })
    end
})

sections.SettingsConfig:Button({
    Name = "Reload Config",
    Description = "Reload saved settings from disk",
    Callback = function()
        LoadConfig()
        Window:Notify({ Title = "Config Reloaded", Description = "Settings reloaded from disk", Lifetime = 3 })
    end
})

sections.SettingsConfig:Button({
    Name = "Reset Config to Defaults",
    Description = "Reset all script gameplay settings to initial defaults",
    Callback = function()
        pcall(function()
            if delfile and isfile(CONFIG_FILE) then
                delfile(CONFIG_FILE)
            end
        end)
        for k, v in pairs(DefaultConfig) do
            ConfigState[k] = v
        end
        Window:Notify({ Title = "Config Reset", Description = "Settings reset to defaults", Lifetime = 3 })
    end
})

sections.SettingsConfig:Toggle({
    Name = "Auto Save Changes",
    Description = "Automatically save settings to disk whenever modified",
    Default = ConfigState.AutoSave == nil and true or ConfigState.AutoSave,
    Callback = function(val)
        ConfigState.AutoSave = val
        if val then SaveConfig() end
    end
}, "AutoSaveChanges")

MacLib:SetFolder("Maclib_CaliShootout")
tabs.UISettings:InsertConfigSection("Right")

tabs.Home:Select()
MacLib:LoadAutoLoadConfig()

local orbitAngle = 0
RunService.Stepped:Connect(function(time, deltaTime)
    if getgenv().OrbitAttack and tpSelectedPlayer and tpSelectedPlayer ~= "(No Players)" then
        local targetPlayer = Players:FindFirstChild(tpSelectedPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if targetHum and targetHum.Health > 0 then
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar:FindFirstChild("Humanoid") then
                    local myHrp = myChar.HumanoidRootPart
                    local targetHrp = targetPlayer.Character.HumanoidRootPart
                    
                    orbitAngle = orbitAngle + (getgenv().OrbitSpeed * deltaTime)
                    local offset = Vector3.new(math.cos(orbitAngle) * getgenv().OrbitDistance, getgenv().OrbitHeight or 5, math.sin(orbitAngle) * getgenv().OrbitDistance)
                    local targetPos = targetHrp.Position + offset
                    
                    myChar.Humanoid.PlatformStand = true
                    myHrp.CFrame = CFrame.new(targetPos, targetHrp.Position)
                    myHrp.Velocity = Vector3.zero
                    myHrp.RotVelocity = Vector3.zero
                    
                    local tool = myChar:FindFirstChildOfClass("Tool")
                    if tool then
                        tool:Activate()
                    end
                end
            end
        end
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if not LocalPlayer.Character.HumanoidRootPart:FindFirstChild("GhostFlyVelocity") and getgenv().OrbitAttack == false then
                -- Only disable if not using AutoRob fly
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if getgenv().BankESP then
            for _, bank in ipairs(workspace:GetChildren()) do
                if bank.Name == "Bank" then
                    local laserDisabler = bank:FindFirstChild("LaserDisabler")
                    local main = laserDisabler and laserDisabler:FindFirstChild("Main")
                    if main then
                        local esp = main:FindFirstChild("BankESP")
                        if not esp then
                            esp = Instance.new("BillboardGui")
                            esp.Name = "BankESP"
                            esp.Adornee = main
                            esp.Size = UDim2.new(0, 150, 0, 50)
                            esp.StudsOffset = Vector3.new(0, 5, 0)
                            esp.AlwaysOnTop = true
                            
                            local textLabel = Instance.new("TextLabel")
                            textLabel.Parent = esp
                            textLabel.BackgroundTransparency = 1
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.TextScaled = true
                            textLabel.Font = Enum.Font.GothamBold
                            textLabel.TextStrokeTransparency = 0
                            
                            esp.Parent = main
                        end
                        
                        local textLabel = esp:FindFirstChildWhichIsA("TextLabel")
                        if textLabel then
                            local color = main.Color
                            local r = math.round(color.R * 255)
                            local g = math.round(color.G * 255)
                            local b = math.round(color.B * 255)
                            
                            if r == 255 and g == 0 and b == 0 then
                                textLabel.Text = "READY [RED]"
                                textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                            elseif r == 0 and g == 170 and b == 0 then
                                textLabel.Text = "ROBBABLE [GREEN]"
                                textLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
                            else
                                textLabel.Text = "COOLDOWN [YELLOW]"
                                textLabel.TextColor3 = Color3.fromRGB(255, 255, 50)
                            end
                        end
                    end
                end
            end
        else
            for _, bank in ipairs(workspace:GetChildren()) do
                if bank.Name == "Bank" then
                    local laserDisabler = bank:FindFirstChild("LaserDisabler")
                    local main = laserDisabler and laserDisabler:FindFirstChild("Main")
                    if main and main:FindFirstChild("BankESP") then
                        main.BankESP:Destroy()
                    end
                end
            end
        end
    end
end)

local function getPromptPart(prompt)
    if not prompt then return nil end
    local parent = prompt.Parent
    if not parent then return nil end
    
    if parent:IsA("BasePart") then
        return parent
    elseif parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
    elseif parent.Parent and parent.Parent:IsA("Model") then
        return parent.Parent.PrimaryPart or parent.Parent:FindFirstChildWhichIsA("BasePart", true)
    end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function triggerPrompt(prompt)
    if not prompt or not prompt.Enabled then return end
    
    local part = getPromptPart(prompt)
    if part then
        flyTo(part.CFrame)
        task.wait(0.15)
    end
    
    if getgenv().FastCollect == nil or getgenv().FastCollect == true then
        if fireproximityprompt then
            local oldHold = prompt.HoldDuration
            prompt.HoldDuration = 0
            fireproximityprompt(prompt, 0)
            task.wait(0.15)
            prompt.HoldDuration = oldHold
        end
    else
        -- Normal Hold E
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.1)
        prompt:InputHoldEnd()
        task.wait(0.15)
    end
end

local function getBankPrompts(bank)
    local laserPrompt = nil
    local vaultPrompt = nil
    local lootList = {}
    
    for _, desc in ipairs(bank:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local pName = string.lower(desc.Parent and desc.Parent.Name or "")
            local oName = string.lower(desc.Name or "")
            local grandName = string.lower(desc.Parent and desc.Parent.Parent and desc.Parent.Parent.Name or "")
            local actionText = string.lower(desc.ActionText or "")
            local objectText = string.lower(desc.ObjectText or "")
            
            -- Filter out purchase prompts
            if string.find(actionText, "buy") or string.find(objectText, "buy") or 
               string.find(pName, "robbery tools") or string.find(oName, "robbery tools") or 
               string.find(objectText, "robbery tools") then
                continue
            end
            
            if string.find(pName, "laser") or string.find(grandName, "laser") then
                laserPrompt = desc
            elseif string.find(pName, "vault") or string.find(grandName, "vault") or string.find(pName, "door") then
                vaultPrompt = desc
            elseif not string.find(pName, "document") and not string.find(oName, "document") then
                local part = getPromptPart(desc)
                if part then
                    table.insert(lootList, {
                        prompt = desc,
                        part = part
                    })
                end
            end
        end
    end
    
    -- Also search folders named Loot, Cash, Money for any parts/prompts
    local lootFolder = bank:FindFirstChild("Loot", true) or bank:FindFirstChild("Cash", true) or bank:FindFirstChild("Money", true)
    if lootFolder then
        for _, item in ipairs(lootFolder:GetChildren()) do
            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
            local part = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))
            
            if prompt and prompt.Enabled and part then
                local pName = string.lower(prompt.Parent and prompt.Parent.Name or "")
                local oName = string.lower(prompt.Name or "")
                local actionText = string.lower(prompt.ActionText or "")
                local objectText = string.lower(prompt.ObjectText or "")
                
                -- Filter out purchase prompts
                if string.find(actionText, "buy") or string.find(objectText, "buy") or 
                   string.find(pName, "robbery tools") or string.find(oName, "robbery tools") or 
                   string.find(objectText, "robbery tools") then
                    continue
                end
                
                local alreadyAdded = false
                for _, lp in ipairs(lootList) do
                    if lp.prompt == prompt then
                        alreadyAdded = true
                        break
                    end
                end
                if not alreadyAdded then
                    table.insert(lootList, {
                        prompt = prompt,
                        part = part
                    })
                end
            end
        end
    end
    
    return laserPrompt, vaultPrompt, lootList
end

task.spawn(function()
    while task.wait(1) do
        if not getgenv().AutoRobBank then continue end
        local banks = getBanks()
        local targetBank = nil
        local targetMain = nil
        local bankState = "NONE"
        
        local priorityLevel = 0 -- 0=none, 1=COOLDOWN, 2=ROBBABLE, 3=READY
        
        for _, bank in ipairs(banks) do
            local state, mainPart = getBankState(bank)
            if mainPart and not robbedBanks[bank] then
                if state == "READY" and priorityLevel < 3 then
                    targetBank = bank
                    targetMain = mainPart
                    bankState = state
                    priorityLevel = 3
                elseif state == "ROBBABLE" and priorityLevel < 2 then
                    targetBank = bank
                    targetMain = mainPart
                    bankState = state
                    priorityLevel = 2
                end
            end
        end
        
        if targetBank and targetMain then
            
            print("Target found! Flying to rob...")
            flyTo(targetMain.CFrame)
            
            local emptyCounter = 0
            while task.wait(0.3) do
                if not getgenv().AutoRobBank then break end
                
                -- Check if bag is full
                local isBagFull = false
                pcall(function()
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("BankRobberyGUI")
                    if gui and gui:FindFirstChild("MainRobbery") and gui.MainRobbery:FindFirstChild("MoneyCollectedLabel") then
                        local text = gui.MainRobbery.MoneyCollectedLabel.Text
                        local cleanText = string.gsub(text, "[$,]", "") 
                        local current, max = string.match(cleanText, "(%d+)%s*/%s*(%d+)")
                        if current and max and tonumber(current) >= tonumber(max) then
                            isBagFull = true
                        end
                    end
                end)
                
                if isBagFull then
                    print("Bag full! (From GUI) Going to cashout...")
                    break
                end
                
                local laserPrompt, vaultPrompt, lootList = getBankPrompts(targetBank)
                
                -- Step 1: Laser Disabler
                if laserPrompt and laserPrompt.Enabled then
                    print("Disabling laser...")
                    triggerPrompt(laserPrompt)
                    emptyCounter = 0
                    task.wait(0.3)
                -- Step 2: Vault Door
                elseif vaultPrompt and vaultPrompt.Enabled then
                    print("Opening vault door...")
                    triggerPrompt(vaultPrompt)
                    emptyCounter = 0
                    task.wait(0.5)
                -- Step 3: Collect Loot Items
                elseif #lootList > 0 then
                    emptyCounter = 0
                    print("Found " .. #lootList .. " valuable items. Collecting...")
                    for _, lootItem in ipairs(lootList) do
                        if not getgenv().AutoRobBank then break end
                        
                        -- Check bag before each loot
                        local fullNow = false
                        pcall(function()
                            local gui = LocalPlayer.PlayerGui:FindFirstChild("BankRobberyGUI")
                            if gui and gui:FindFirstChild("MainRobbery") and gui.MainRobbery:FindFirstChild("MoneyCollectedLabel") then
                                local text = gui.MainRobbery.MoneyCollectedLabel.Text
                                local cleanText = string.gsub(text, "[$,]", "") 
                                local current, max = string.match(cleanText, "(%d+)%s*/%s*(%d+)")
                                if current and max and tonumber(current) >= tonumber(max) then
                                    fullNow = true
                                end
                            end
                        end)
                        
                        if fullNow then
                            isBagFull = true
                            break
                        end
                        
                        if lootItem.prompt and lootItem.prompt.Enabled and lootItem.part then
                            triggerPrompt(lootItem.prompt)
                            task.wait(0.2)
                        end
                    end
                    
                    if isBagFull then
                        print("Bag full! Going to cashout...")
                        break
                    end
                else
                    emptyCounter = emptyCounter + 1
                    if emptyCounter <= 20 then
                        -- Wait a moment for door animation or loot spawn (up to ~10 seconds)
                        task.wait(0.5)
                    else
                        print("No more loot. Cashing out and changing bank.")
                        break
                    end
                end
            end
            
            print("Searching for valid CashoutPoint...")
            pcall(function()
                local destination = nil
                
                for _, desc in ipairs(workspace:GetDescendants()) do
                    if desc:IsA("BillboardGui") and desc.Enabled and desc.Parent and desc.Parent.Name == "Marker" then
                        destination = desc.Parent.Parent
                        if destination then break end
                    end
                end
                
                if not destination then
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local n = string.lower(obj.Parent and obj.Parent.Name or "")
                            if string.find(n, "cashout") or string.find(n, "dealer") or string.find(n, "dropoff") or string.find(n, "sell") then
                                destination = obj.Parent
                                break
                            end
                        end
                    end
                end
                
                if destination then
                    local destCFrame = destination:IsA("Model") and (destination.PrimaryPart and destination.PrimaryPart.CFrame or destination:GetModelCFrame()) or destination:IsA("BasePart") and destination.CFrame
                    
                    if not destCFrame then
                        local part = destination:FindFirstChildWhichIsA("BasePart", true)
                        if part then destCFrame = part.CFrame end
                    end
                    
                    if destCFrame then
                        flyTo(destCFrame)
                        task.wait(0.5)
                        
                        for _, obj in ipairs(destination:GetDescendants()) do
                            if obj:IsA("ProximityPrompt") and obj.Enabled then
                                local pName = string.lower(obj.Parent.Name)
                                local oName = string.lower(obj.Name)
                                if not string.find(pName, "document") and not string.find(oName, "document") then
                                    local oldHold = obj.HoldDuration
                                    obj.HoldDuration = 0
                                    fireproximityprompt(obj, 0)
                                    task.wait(0.1)
                                    obj.HoldDuration = oldHold
                                end
                            end
                        end
                        task.wait(1.5)
                    end
                else
                    print("Could not find active CashoutPoint")
                end
            end)
            robbedBanks[targetBank] = true
            
            -- Check if all robbable banks in this server are now completed
            local hasRobbableLeft = false
            for _, b in ipairs(getBanks()) do
                local st, _ = getBankState(b)
                if (st == "READY" or st == "ROBBABLE") and not robbedBanks[b] then
                    hasRobbableLeft = true
                    break
                end
            end
            
            if not hasRobbableLeft and getgenv().AutoServerHop and getgenv().AutoRobBank then
                print("[Singularity] All banks in server completed! Triggering Server Hop in 3s...")
                pcall(function()
                    Window:Notify({
                        Title = "Auto Server Hop",
                        Desc = "All banks completed! Switching server in 3s...",
                        Time = 4
                    })
                end)
                task.wait(3)
                serverHop()
                task.wait(10)
            end
        else
            -- No robbable banks currently found in server
            if getgenv().AutoServerHop and getgenv().AutoRobBank then
                print("[Singularity] No robbable banks in current server. Triggering Server Hop...")
                pcall(function()
                    Window:Notify({
                        Title = "Auto Server Hop",
                        Desc = "No robbable banks available. Hopping to another server in 3s...",
                        Time = 4
                    })
                end)
                task.wait(3)
                serverHop()
                task.wait(10)
            end
        end
    end
end)

-- ============================================
-- PLAYER ESP LOGIC (HEALTH, NAME, WEAPON ICONS)
-- ============================================
local espObjects = {}
local camera = workspace.CurrentCamera

local function getToolCategoryIcon(toolName)
    local n = string.lower(toolName or "")
    if string.find(n, "gun") or string.find(n, "ak") or string.find(n, "m4") or string.find(n, "rifle") or string.find(n, "shotgun") or string.find(n, "glock") or string.find(n, "pistol") or string.find(n, "deagle") or string.find(n, "sniper") or string.find(n, "revolver") or string.find(n, "smg") or string.find(n, "uzi") or string.find(n, "weapon") then
        return "rbxassetid://6031086178" -- Gun / Weapon Icon
    elseif string.find(n, "knife") or string.find(n, "blade") or string.find(n, "sword") or string.find(n, "bat") or string.find(n, "axe") or string.find(n, "katana") or string.find(n, "melee") or string.find(n, "fist") then
        return "rbxassetid://6034684937" -- Melee / Knife Icon
    elseif string.find(n, "med") or string.find(n, "heal") or string.find(n, "bandage") or string.find(n, "potion") or string.find(n, "food") or string.find(n, "apple") or string.find(n, "drink") then
        return "rbxassetid://6031094667" -- Health / Medkit Icon
    else
        return "rbxassetid://6031068426" -- General Inventory Icon
    end
end

local function getActiveESPColor()
    local c = getgenv().ESPColor
    if typeof(c) == "Color3" then
        return c
    elseif typeof(c) == "table" and c.R and c.G and c.B then
        return Color3.new(c.R, c.G, c.B)
    elseif typeof(c) == "string" then
        if c == "Red" then return Color3.fromRGB(255, 60, 60)
        elseif c == "Green" then return Color3.fromRGB(40, 240, 80)
        elseif c == "Blue" then return Color3.fromRGB(60, 160, 255)
        elseif c == "Yellow" then return Color3.fromRGB(255, 230, 40)
        elseif c == "Orange" then return Color3.fromRGB(255, 140, 30)
        elseif c == "Purple" then return Color3.fromRGB(180, 80, 255)
        elseif c == "Cyan" then return Color3.fromRGB(40, 240, 240)
        elseif c == "White" then return Color3.fromRGB(255, 255, 255)
        end
    end
    return Color3.fromRGB(255, 60, 60)
end

local function createPlayerESP(player)
    if espObjects[player] then return end
    
    local objects = {}
    local activeColor = getActiveESPColor()

    pcall(function()
        objects.Tracer = Drawing.new("Line")
        objects.Tracer.Visible = false
        objects.Tracer.Color = activeColor
        objects.Tracer.Thickness = 1
        objects.Tracer.Transparency = 1
        
        objects.Box = Drawing.new("Square")
        objects.Box.Visible = false
        objects.Box.Color = activeColor
        objects.Box.Thickness = 1
        objects.Box.Transparency = 1
        objects.Box.Filled = false
    end)
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.FillColor = activeColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    objects.Highlight = highlight
    
    local espGui = Instance.new("BillboardGui")
    espGui.Name = "PlayerESP"
    espGui.Size = UDim2.new(5, 0, 6, 0)
    espGui.AlwaysOnTop = true
    espGui.MaxDistance = 6000
    espGui.ExtentsOffset = Vector3.new(0, 3, 0)
    
    -- Name Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.Position = UDim2.new(0, 0, 0, -28)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.Parent = espGui
    
    -- Health Text Label
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(1, 0, 0, 14)
    healthText.Position = UDim2.new(0, 0, 0, -12)
    healthText.BackgroundTransparency = 1
    healthText.TextColor3 = Color3.fromRGB(0, 255, 120)
    healthText.TextStrokeTransparency = 0.3
    healthText.Font = Enum.Font.GothamMedium
    healthText.TextSize = 11
    healthText.Parent = espGui
    
    -- Distance Label
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 1, 6)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLabel.TextStrokeTransparency = 0.4
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 11
    distLabel.Parent = espGui
    
    -- Health Bar Container
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBg"
    healthBarBg.Size = UDim2.new(0, 4, 1, 0)
    healthBarBg.Position = UDim2.new(0, -8, 0, 0)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = espGui
    
    local hbCorner = Instance.new("UICorner")
    hbCorner.CornerRadius = UDim.new(0, 2)
    hbCorner.Parent = healthBarBg
    
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
    healthBar.BorderSizePixel = 0
    healthBar.AnchorPoint = Vector2.new(0, 1)
    healthBar.Position = UDim2.new(0, 0, 1, 0)
    healthBar.Parent = healthBarBg
    
    local hbFillCorner = Instance.new("UICorner")
    hbFillCorner.CornerRadius = UDim.new(0, 2)
    hbFillCorner.Parent = healthBar
    
    -- Inventory / Tools Frame
    local invContainer = Instance.new("Frame")
    invContainer.Name = "InvContainer"
    invContainer.Size = UDim2.new(0, 110, 1, 0)
    invContainer.Position = UDim2.new(1, 8, 0, 0)
    invContainer.BackgroundTransparency = 1
    invContainer.Parent = espGui
    
    local invLayout = Instance.new("UIListLayout")
    invLayout.FillDirection = Enum.FillDirection.Vertical
    invLayout.SortOrder = Enum.SortOrder.LayoutOrder
    invLayout.Padding = UDim.new(0, 3)
    invLayout.Parent = invContainer
    
    objects.Gui = espGui
    objects.ToolBadges = {}
    espObjects[player] = objects
end

local function removePlayerESP(player)
    if espObjects[player] then
        if espObjects[player].Tracer then pcall(function() espObjects[player].Tracer:Remove() end) end
        if espObjects[player].Box then pcall(function() espObjects[player].Box:Remove() end) end
        if espObjects[player].Highlight then pcall(function() espObjects[player].Highlight:Destroy() end) end
        if espObjects[player].Gui then pcall(function() espObjects[player].Gui:Destroy() end) end
        espObjects[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if FOVring and aimbotCamera then
        FOVring.Position = Vector2.new(aimbotCamera.ViewportSize.X / 2, aimbotCamera.ViewportSize.Y / 2)
    end
    if updateAimbot then
        updateAimbot()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local objects = espObjects[player]
        if not objects then continue end
        
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if getgenv().PlayerESP and char and hrp and hum and hum.Health > 0 then
            if objects.Gui.Parent ~= hrp then
                objects.Gui.Parent = hrp
                objects.Gui.Adornee = hrp
            end
            
            local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = myHrp and (hrp.Position - myHrp.Position).Magnitude or 0
            
            -- Distance
            objects.Gui.DistLabel.Text = "[ " .. math.floor(dist) .. " studs ]"
            objects.Gui.DistLabel.Visible = getgenv().DistESP
            
            -- Name
            objects.Gui.NameLabel.Text = (player.DisplayName or player.Name) .. " (@" .. player.Name .. ")"
            objects.Gui.NameLabel.Visible = getgenv().NameESP
            
            -- Health
            local hp = math.max(0, math.floor(hum.Health))
            local maxHp = math.max(1, math.floor(hum.MaxHealth))
            local healthPct = math.clamp(hp / maxHp, 0, 1)
            local hpColor = Color3.fromRGB(math.floor((1 - healthPct) * 255), math.floor(healthPct * 255), 40)
            
            objects.Gui.HealthBarBg.HealthBar.Size = UDim2.new(1, 0, healthPct, 0)
            objects.Gui.HealthBarBg.HealthBar.BackgroundColor3 = hpColor
            objects.Gui.HealthBarBg.Visible = getgenv().HealthESP
            
            objects.Gui.HealthText.Text = hp .. " / " .. maxHp .. " HP"
            objects.Gui.HealthText.TextColor3 = hpColor
            objects.Gui.HealthText.Visible = getgenv().HealthESP
            
            -- Inventory / Tool Icons
            if getgenv().ToolESP then
                objects.Gui.InvContainer.Visible = true
                local tools = {}
                
                -- Equipped Tool
                local equipped = char:FindFirstChildOfClass("Tool")
                if equipped then
                    table.insert(tools, {Tool = equipped, Equipped = true})
                end
                
                -- Backpack Tools
                local bp = player:FindFirstChild("Backpack")
                if bp then
                    for _, t in ipairs(bp:GetChildren()) do
                        if t:IsA("Tool") then
                            table.insert(tools, {Tool = t, Equipped = false})
                        end
                    end
                end
                
                -- Update tool badges
                for i = 1, math.max(#tools, #objects.ToolBadges) do
                    local item = tools[i]
                    local badge = objects.ToolBadges[i]
                    
                    if item and i <= 4 then
                        if not badge then
                            badge = Instance.new("Frame")
                            badge.Name = "ItemBadge_" .. tostring(i)
                            badge.Size = UDim2.new(1, 0, 0, 18)
                            badge.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                            badge.BackgroundTransparency = 0.3
                            badge.BorderSizePixel = 0
                            badge.Parent = objects.Gui.InvContainer
                            
                            local bCorner = Instance.new("UICorner")
                            bCorner.CornerRadius = UDim.new(0, 4)
                            bCorner.Parent = badge
                            
                            local bStroke = Instance.new("UIStroke")
                            bStroke.Name = "BadgeStroke"
                            bStroke.Thickness = 1
                            bStroke.Transparency = 0.4
                            bStroke.Parent = badge
                            
                            local icon = Instance.new("ImageLabel")
                            icon.Name = "ItemIcon"
                            icon.AnchorPoint = Vector2.new(0, 0.5)
                            icon.Position = UDim2.new(0, 3, 0.5, 0)
                            icon.Size = UDim2.new(0, 13, 0, 13)
                            icon.BackgroundTransparency = 1
                            icon.Parent = badge
                            
                            local label = Instance.new("TextLabel")
                            label.Name = "ItemName"
                            label.AnchorPoint = Vector2.new(0, 0.5)
                            label.Position = UDim2.new(0, 19, 0.5, 0)
                            label.Size = UDim2.new(1, -21, 1, 0)
                            label.BackgroundTransparency = 1
                            label.Font = Enum.Font.GothamMedium
                            label.TextSize = 10
                            label.TextColor3 = Color3.fromRGB(240, 240, 245)
                            label.TextXAlignment = Enum.TextXAlignment.Left
                            label.TextTruncate = Enum.TextTruncate.AtEnd
                            label.Parent = badge
                            
                            objects.ToolBadges[i] = badge
                        end
                        
                        local toolObj = item.Tool
                        local toolName = toolObj.Name or "Item"
                        local textureId = (toolObj.TextureId and toolObj.TextureId ~= "") and toolObj.TextureId or getToolCategoryIcon(toolName)
                        
                        badge.ItemIcon.Image = textureId
                        badge.ItemName.Text = toolName
                        
                        local bStroke = badge:FindFirstChild("BadgeStroke")
                        if item.Equipped then
                            if bStroke then bStroke.Color = Color3.fromRGB(255, 180, 40) end
                            badge.BackgroundColor3 = Color3.fromRGB(35, 30, 18)
                        else
                            if bStroke then bStroke.Color = Color3.fromRGB(60, 60, 80) end
                            badge.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                        end
                        badge.Visible = true
                    elseif badge then
                        badge.Visible = false
                    end
                end
            else
                objects.Gui.InvContainer.Visible = false
            end
            
            local activeColor = getActiveESPColor()
            
            if objects.Tracer then objects.Tracer.Color = activeColor end
            if objects.Box then objects.Box.Color = activeColor end
            if objects.Highlight then objects.Highlight.FillColor = activeColor end
            
            if getgenv().ESPStyle == "2D" then
                if objects.Highlight.Parent then
                    objects.Highlight.Parent = nil
                    objects.Highlight.Enabled = false
                end
                
                if objects.Tracer and objects.Box then
                    local hrpPos, hrpOnScreen = camera:WorldToViewportPoint(hrp.Position)
                    if hrpOnScreen then
                        local head = char:FindFirstChild("Head")
                        local headPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2, 0))
                        local legPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2
                        
                        if getgenv().BoxESP then
                            objects.Box.Size = Vector2.new(width, height)
                            objects.Box.Position = Vector2.new(hrpPos.X - width / 2, headPos.Y)
                            objects.Box.Visible = true
                        else
                            objects.Box.Visible = false
                        end
                        
                        if getgenv().TracerESP then
                            objects.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                            objects.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y)
                            objects.Tracer.Visible = true
                        else
                            objects.Tracer.Visible = false
                        end
                    else
                        objects.Box.Visible = false
                        objects.Tracer.Visible = false
                    end
                end
            else
                if objects.Box then objects.Box.Visible = false end
                if objects.Tracer then objects.Tracer.Visible = false end
                
                if objects.Highlight.Parent ~= char then
                    objects.Highlight.Parent = char
                end
                objects.Highlight.Enabled = true
            end
        else
            if objects.Gui.Parent then objects.Gui.Parent = nil end
            if objects.Tracer then objects.Tracer.Visible = false end
            if objects.Box then objects.Box.Visible = false end
            if objects.Highlight then 
                objects.Highlight.Parent = nil
                objects.Highlight.Enabled = false 
            end
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createPlayerESP(p) end
end
Players.PlayerAdded:Connect(createPlayerESP)
Players.PlayerRemoving:Connect(removePlayerESP)

