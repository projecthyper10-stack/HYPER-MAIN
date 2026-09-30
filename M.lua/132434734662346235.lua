-- ==============================================================================
--  HYPER HUB / MACLIB - Laundry Simulator Auto Farm
-- ==============================================================================

if getgenv().KT_LaundrySimulator_Loaded and getgenv().LaundryFarmRunning then
    warn("Laundry Simulator Auto Farm is already running! Restarting session...")
    getgenv().LaundryFarmRunning = false
    task.wait(0.5)
end
getgenv().KT_LaundrySimulator_Loaded = true

-- Initial state & globals
getgenv().AutoGrab = false
getgenv().AutoWash = false
getgenv().AutoSell = false
getgenv().AutoSpin = false
getgenv().AutoBuyMachine = false
getgenv().AutoEquipMachine = false
getgenv().AutoBuyBasket = false
getgenv().AutoChallenge = false
getgenv().IsSelling = false
getgenv().IsWashing = false
getgenv().Noclip = true
getgenv().CameraNoclip = true
getgenv().FlySpeed = 60
getgenv().AntiAFK = true
getgenv().ClothESP = false
getgenv().ESPNormal = true
getgenv().ESPRare = true
getgenv().FilterNormal = true
getgenv().FilterGold = true
getgenv().FilterPurple = true
getgenv().FilterRed = true
getgenv().FilterBlue = true
getgenv().FilterGreen = true
getgenv().FilterOther = true
getgenv().FilterMitten = true
getgenv().FilterSock = true
getgenv().FilterShirt = true
getgenv().FilterShorts = true
getgenv().FilterSweater = true
getgenv().FilterTowel = true
getgenv().FilterUnderpants = true
getgenv().DebugFarm = false

local function DebugLog(msg)
    if getgenv().DebugFarm then
        print("[AutoFarm Debug] " .. tostring(msg))
    end
end

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

-- ==============================================================================
--  Window
-- ==============================================================================

local SCRIPT_VERSION = "v1.0"

local Window = MacLib:Window({
    Title = "HYPER HUB",
    Subtitle = "Laundry Simulator",
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

-- ==============================================================================
--  Tab Groups (Sidebar Categories)
-- ==============================================================================

local tabGroups = {
    General       = Window:TabGroup("General"),
    Farming       = Window:TabGroup("Farming"),
    Visuals       = Window:TabGroup("Visuals"),
    Character     = Window:TabGroup("Character"),
    SettingsGroup = Window:TabGroup("Settings"),
}

-- ==============================================================================
--  Tabs
-- ==============================================================================

local tabs = {
    Home       = tabGroups.General:Tab({ Name = "Home",         Icon = "lucide-home" }),
    Farm       = tabGroups.Farming:Tab({ Name = "Auto Farm",    Icon = "lucide-zap" }),
    Filter     = tabGroups.Farming:Tab({ Name = "Cloth Filter", Icon = "lucide-filter" }),
    ESP        = tabGroups.Visuals:Tab({ Name = "ESP",          Icon = "lucide-eye" }),
    Player     = tabGroups.Character:Tab({ Name = "Player",     Icon = "lucide-user" }),
    Teleports  = tabGroups.Character:Tab({ Name = "Teleports",  Icon = "lucide-map-pin" }),
    UISettings = tabGroups.SettingsGroup:Tab({ Name = "UI Settings", Icon = "lucide-settings" }),
}

-- ==============================================================================
--  Sections
-- ==============================================================================

local sections = {
    HomeWelcome   = tabs.Home:Section({ Name = "Welcome", Side = "Left" }),
    HomeStats     = tabs.Home:Section({ Name = "System Information", Side = "Right" }),
    FarmAuto      = tabs.Farm:Section({ Name = "Auto Farming", Side = "Left" }),
    FarmShop      = tabs.Farm:Section({ Name = "Shop & Upgrades", Side = "Right" }),
    FilterRarity  = tabs.Filter:Section({ Name = "Rarity & Colors", Side = "Left" }),
    FilterTypes   = tabs.Filter:Section({ Name = "Clothing Types", Side = "Right" }),
    ESPMain       = tabs.ESP:Section({ Name = "Visual ESP", Side = "Left" }),
    PlayerMain    = tabs.Player:Section({ Name = "Player Modifications", Side = "Left" }),
    TeleportMain  = tabs.Teleports:Section({ Name = "Quick Teleport", Side = "Left" }),
    SettingsMain  = tabs.UISettings:Section({ Name = "Appearance & Controls", Side = "Left" }),
}

-- ==============================================================================
--  Home Tab
-- ==============================================================================

local plr = game:GetService("Players").LocalPlayer

sections.HomeWelcome:Label({ Text = "Welcome, " .. (plr and plr.DisplayName or "User") .. "!" })
sections.HomeWelcome:SubLabel({ Text = "Thanks for using HYPER HUB - Laundry Simulator" })

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
        if not getgenv().LaundryFarmRunning then break end
        if timeSub and timeSub.SetText then
            pcall(function() timeSub:SetText(os.date("%X")) end)
        elseif timeSub and timeSub.SetDesc then
            pcall(function() timeSub:SetDesc(os.date("%X")) end)
        end
    end
end)

-- ==============================================================================
--  Auto Farm Tab
-- ==============================================================================

sections.FarmAuto:Toggle({
    Name = "Auto Grab Clothes",
    Description = "Automatically grab clothes from the conveyor belt.",
    Default = getgenv().AutoGrab,
    Callback = function(val)
        getgenv().AutoGrab = val
    end
}, "AutoGrab")

sections.FarmAuto:Toggle({
    Name = "Auto Wash",
    Description = "Automatically wash full basket clothes in machines.",
    Default = getgenv().AutoWash,
    Callback = function(val)
        getgenv().AutoWash = val
    end
}, "AutoWash")

sections.FarmAuto:Toggle({
    Name = "Auto Sell",
    Description = "Automatically sell clean clothes at the unload area.",
    Default = getgenv().AutoSell,
    Callback = function(val)
        getgenv().AutoSell = val
    end
}, "AutoSell")

sections.FarmAuto:Toggle({
    Name = "Auto Spin Wheel",
    Description = "Automatically claim and spin the free wheel.",
    Default = getgenv().AutoSpin,
    Callback = function(val)
        getgenv().AutoSpin = val
    end
}, "AutoSpin")

sections.FarmShop:Toggle({
    Name = "Auto Buy Machine",
    Description = "Automatically buy new washing machines when affordable.",
    Default = getgenv().AutoBuyMachine,
    Callback = function(val)
        getgenv().AutoBuyMachine = val
    end
}, "AutoBuyMachine")

sections.FarmShop:Toggle({
    Name = "Auto Equip Best Machine",
    Description = "Automatically equip the best available washing machine.",
    Default = getgenv().AutoEquipMachine,
    Callback = function(val)
        getgenv().AutoEquipMachine = val
    end
}, "AutoEquipMachine")

sections.FarmShop:Toggle({
    Name = "Auto Buy Basket",
    Description = "Automatically upgrade baskets when coins are sufficient.",
    Default = getgenv().AutoBuyBasket,
    Callback = function(val)
        getgenv().AutoBuyBasket = val
    end
}, "AutoBuyBasket")

sections.FarmShop:Toggle({
    Name = "Auto Claim Challenges",
    Description = "Automatically claim completed challenges for rewards.",
    Default = getgenv().AutoChallenge,
    Callback = function(val)
        getgenv().AutoChallenge = val
    end
}, "AutoChallenge")

-- ==============================================================================
--  Cloth Filter Tab
-- ==============================================================================

sections.FilterRarity:Toggle({ Name = "Normal Clothes", Description = "Allow collecting normal clothes.", Default = getgenv().FilterNormal, Callback = function(v) getgenv().FilterNormal = v end }, "FilterNormal")
sections.FilterRarity:Toggle({ Name = "Gold / Yellow", Description = "Allow collecting gold/yellow clothes.", Default = getgenv().FilterGold, Callback = function(v) getgenv().FilterGold = v end }, "FilterGold")
sections.FilterRarity:Toggle({ Name = "Purple / Pink", Description = "Allow collecting purple/pink clothes.", Default = getgenv().FilterPurple, Callback = function(v) getgenv().FilterPurple = v end }, "FilterPurple")
sections.FilterRarity:Toggle({ Name = "Red", Description = "Allow collecting red clothes.", Default = getgenv().FilterRed, Callback = function(v) getgenv().FilterRed = v end }, "FilterRed")
sections.FilterRarity:Toggle({ Name = "Blue", Description = "Allow collecting blue clothes.", Default = getgenv().FilterBlue, Callback = function(v) getgenv().FilterBlue = v end }, "FilterBlue")
sections.FilterRarity:Toggle({ Name = "Green", Description = "Allow collecting green clothes.", Default = getgenv().FilterGreen, Callback = function(v) getgenv().FilterGreen = v end }, "FilterGreen")
sections.FilterRarity:Toggle({ Name = "Other Effects", Description = "Allow collecting clothes with other special effects.", Default = getgenv().FilterOther, Callback = function(v) getgenv().FilterOther = v end }, "FilterOther")

sections.FilterTypes:Toggle({ Name = "Mitten", Description = "Allow collecting mitten.", Default = getgenv().FilterMitten, Callback = function(v) getgenv().FilterMitten = v end }, "FilterMitten")
sections.FilterTypes:Toggle({ Name = "Sock", Description = "Allow collecting sock.", Default = getgenv().FilterSock, Callback = function(v) getgenv().FilterSock = v end }, "FilterSock")
sections.FilterTypes:Toggle({ Name = "Shirt", Description = "Allow collecting shirt.", Default = getgenv().FilterShirt, Callback = function(v) getgenv().FilterShirt = v end }, "FilterShirt")
sections.FilterTypes:Toggle({ Name = "Shorts", Description = "Allow collecting shorts.", Default = getgenv().FilterShorts, Callback = function(v) getgenv().FilterShorts = v end }, "FilterShorts")
sections.FilterTypes:Toggle({ Name = "Sweater", Description = "Allow collecting sweater.", Default = getgenv().FilterSweater, Callback = function(v) getgenv().FilterSweater = v end }, "FilterSweater")
sections.FilterTypes:Toggle({ Name = "Towel", Description = "Allow collecting towel.", Default = getgenv().FilterTowel, Callback = function(v) getgenv().FilterTowel = v end }, "FilterTowel")
sections.FilterTypes:Toggle({ Name = "Underpants", Description = "Allow collecting underpants.", Default = getgenv().FilterUnderpants, Callback = function(v) getgenv().FilterUnderpants = v end }, "FilterUnderpants")

-- ==============================================================================
--  ESP Tab
-- ==============================================================================

sections.ESPMain:Toggle({
    Name = "ESP Clothes",
    Description = "Highlight and draw BillboardGui on all spawned clothes.",
    Default = getgenv().ClothESP,
    Callback = function(val)
        getgenv().ClothESP = val
        if not val then
            pcall(function()
                for _, v in ipairs(workspace.Debris.Clothing:GetChildren()) do
                    if v:FindFirstChild("LaundryESP") then
                        v.LaundryESP:Destroy()
                    end
                end
            end)
        end
    end
}, "ClothESP")

sections.ESPMain:Toggle({
    Name = "Show Normal",
    Description = "Show ESP labels for normal rarity clothes.",
    Default = getgenv().ESPNormal,
    Callback = function(val)
        getgenv().ESPNormal = val
    end
}, "ESPNormal")

sections.ESPMain:Toggle({
    Name = "Show Rare",
    Description = "Show ESP labels for rare / particle clothes.",
    Default = getgenv().ESPRare,
    Callback = function(val)
        getgenv().ESPRare = val
    end
}, "ESPRare")

-- ==============================================================================
--  Player Tab
-- ==============================================================================

sections.PlayerMain:Toggle({
    Name = "Noclip",
    Description = "Walk through objects and barriers without collision.",
    Default = getgenv().Noclip,
    Callback = function(val)
        getgenv().Noclip = val
    end
}, "Noclip")

sections.PlayerMain:Toggle({
    Name = "Anti AFK",
    Description = "Prevents Roblox from disconnecting after 20 minutes of inactivity.",
    Default = getgenv().AntiAFK,
    Callback = function(val)
        getgenv().AntiAFK = val
    end
}, "AntiAFK")

sections.PlayerMain:Toggle({
    Name = "Camera Noclip",
    Description = "Allows camera to zoom through obstacles.",
    Default = getgenv().CameraNoclip,
    Callback = function(val)
        getgenv().CameraNoclip = val
        if val then
            game.Players.LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        else
            game.Players.LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        end
    end
}, "CameraNoclip")

sections.PlayerMain:Slider({
    Name = "Fly Speed",
    Description = "Adjust flying speed when moving between farm spots (Default: 60).",
    Default = getgenv().FlySpeed,
    Minimum = 10,
    Maximum = 300,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        getgenv().FlySpeed = val
    end
}, "FlySpeed")

-- ==============================================================================
--  Teleports Tab
-- ==============================================================================

sections.TeleportMain:Button({
    Name = "Teleport to Shop",
    Description = "Instantly teleport to Archy's Shop entrance.",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        local shop = workspace:FindFirstChild("ArchysShopEntrance")
        if char and char:FindFirstChild("HumanoidRootPart") and shop and shop:FindFirstChild("Open") then
            char.HumanoidRootPart.CFrame = shop.Open.CFrame * CFrame.new(0, 3, 0)
            Window:Notify({
                Title = "Teleport",
                Description = "Teleported to Archy's Shop!",
                Lifetime = 3
            })
        end
    end
})

-- ==============================================================================
--  UI Settings Tab
-- ==============================================================================

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
    Name = "คืนค่าเริ่มต้น (Reset to Defaults)",
    Description = "รีเซ็ตการตั้งค่า UI ทั้งหมดกลับเป็นค่าเริ่มต้น",
    Callback = function()
        if MacLib.Options.MenuKeybind then MacLib.Options.MenuKeybind:SetKey(Enum.KeyCode.RightControl) end
        if MacLib.Options.AccentColor then MacLib.Options.AccentColor:SetColor(Color3.fromRGB(29, 235, 169)) end
        if MacLib.Options.UIScale then MacLib.Options.UIScale:SetValue(100) end
        if MacLib.Options.UITransparency then MacLib.Options.UITransparency:SetValue(20) end
        if Window and Window.SetAcrylicBlurState then Window:SetAcrylicBlurState(false) end
        if Window and Window.SetNotificationsState then Window:SetNotificationsState(true) end
        Window:Notify({
            Title = "Settings",
            Description = "คืนค่าการตั้งค่า UI เป็นค่าเริ่มต้นแล้ว",
            Lifetime = 3
        })
    end
})

-- ==============================================================================
--  Config & Init
-- ==============================================================================

MacLib:SetFolder("x2hyper_LaundrySimulator")
tabs.UISettings:InsertConfigSection("Right")

Window.onUnloaded(function()
    getgenv().LaundryFarmRunning = false
    getgenv().KT_LaundrySimulator_Loaded = false
    print("[Laundry Simulator] Unloaded!")
end)

tabs.Home:Select()
MacLib:LoadAutoLoadConfig()

if getgenv().LaundryFarmRunning then
    getgenv().LaundryFarmRunning = false
    task.wait(0.5)
end
getgenv().LaundryFarmRunning = true

-- // Services & Variables
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local LocalPlayer = game.Players.LocalPlayer
local WashingMachinesInfo = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("WashingMachines"))

-- // Anti AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if getgenv().AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

local function IsClothAllowed(cloth)
    -- Check clothes type
    local clothName = cloth.Name
    if clothName == "Mitten" and not getgenv().FilterMitten then return false end
    if clothName == "Sock" and not getgenv().FilterSock then return false end
    if clothName == "Shirt" and not getgenv().FilterShirt then return false end
    if clothName == "Shorts" and not getgenv().FilterShorts then return false end
    if clothName == "Sweater" and not getgenv().FilterSweater then return false end
    if clothName == "Towel" and not getgenv().FilterTowel then return false end
    if clothName == "Underpants" and not getgenv().FilterUnderpants then return false end

    -- Check rarity (Color)
    local hasEffect = false
    local cType = "Normal"
    for _, desc in ipairs(cloth:GetDescendants()) do
        if desc:IsA("ParticleEmitter") then
            hasEffect = true
            local color = desc.Color.Keypoints[1].Value
            local r, g, b = color.R, color.G, color.B
            if r > 0.8 and g > 0.8 and b > 0.8 then cType = "Other" 
            elseif r > 0.7 and g > 0.7 and b < 0.4 then cType = "Gold"
            elseif r > 0.7 and b > 0.7 and g < 0.4 then cType = "Purple"
            elseif r > 0.6 and g < 0.4 and b < 0.4 then cType = "Red"
            elseif g > 0.6 and r < 0.4 and b < 0.4 then cType = "Green"
            elseif b > 0.6 and r < 0.4 and g < 0.4 then cType = "Blue"
            else cType = "Other" end
            break
        end
    end
    
    if not hasEffect then return getgenv().FilterNormal end
    if cType == "Gold" then return getgenv().FilterGold end
    if cType == "Purple" then return getgenv().FilterPurple end
    if cType == "Red" then return getgenv().FilterRed end
    if cType == "Blue" then return getgenv().FilterBlue end
    if cType == "Green" then return getgenv().FilterGreen end
    return getgenv().FilterOther
end 

-- // Auto Standby at ConveyorEdge
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoGrab and not getgenv().IsSelling and not getgenv().IsWashing and getgenv().ActionState == "Grabbing" then
            pcall(function()
                if LocalPlayer.NonSaveVars.BackpackAmount.Value < LocalPlayer.NonSaveVars.BasketSize.Value then
                    local conveyor = workspace:FindFirstChild("ConveyorEdge")
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local targetPos
                        if conveyor then
                            if conveyor:FindFirstChild("MeshPart") and conveyor.MeshPart:IsA("BasePart") then
                                targetPos = conveyor.MeshPart.Position
                            elseif conveyor:IsA("Model") or conveyor:IsA("BasePart") then
                                targetPos = conveyor:GetPivot().Position
                            end
                        end
                        
                        if not targetPos then
                            for _, v in ipairs(workspace:GetDescendants()) do
                                if v.Name == "ConveyorEdge" then
                                    targetPos = v:GetPivot().Position
                                    break
                                end
                            end
                        end

                        if targetPos then
                            local dist = (char.HumanoidRootPart.Position - targetPos).Magnitude
                            if dist > 10 then
                                FlyToTarget(targetPos + Vector3.new(0, 3, 0))
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- // Auto Grab
-- Client-only: it reads LocalPlayer state and sends only GrabClothing requests.

local clothingFolder = workspace:WaitForChild("Debris"):WaitForChild("Clothing")
local queuedClothes = setmetatable({}, { __mode = "k" })
local pickupQueue = {}
local queueHead = 1
local queueTail = 0

-- Preserve the original pickup throughput for new clothes while avoiding spam.
local REQUEST_INTERVAL = 0.05
local RETRY_DELAY = 0.45
local IDLE_INTERVAL = 0.10

local function enqueueCloth(cloth)
    if not getgenv().AutoGrab or not cloth or cloth.Parent ~= clothingFolder or queuedClothes[cloth] then
        return
    end

    queuedClothes[cloth] = true
    queueTail = queueTail + 1
    pickupQueue[queueTail] = cloth
end

local function getNextCloth()
    while queueHead <= queueTail do
        local cloth = pickupQueue[queueHead]
        pickupQueue[queueHead] = nil
        queueHead = queueHead + 1
        if cloth then
            queuedClothes[cloth] = nil
        end

        if cloth and cloth.Parent == clothingFolder then
            return cloth
        end
    end

    -- Release processed entries instead of letting the queue grow during long sessions.
    pickupQueue = {}
    queueHead = 1
    queueTail = 0
    return nil
end

local childAddedConnection = clothingFolder.ChildAdded:Connect(enqueueCloth)

task.spawn(function()
    local wasAutoGrabEnabled = false

    while getgenv().LaundryFarmRunning do
        if not getgenv().AutoGrab then
            wasAutoGrabEnabled = false
            task.wait(IDLE_INTERVAL)
            continue
        end

        -- Scan existing clothes only once when Auto Grab is enabled.
        if not wasAutoGrabEnabled then
            wasAutoGrabEnabled = true
            for _, cloth in ipairs(clothingFolder:GetChildren()) do
                enqueueCloth(cloth)
            end
        end

        local ok, clothOrError = pcall(function()
            if LocalPlayer.NonSaveVars.BackpackAmount.Value >= LocalPlayer.NonSaveVars.BasketSize.Value then
                return nil
            end
            return getNextCloth()
        end)

        if not ok then
            if DebugLog then DebugLog("AutoGrab queue error: " .. tostring(clothOrError)) else warn("AutoGrab queue error: " .. tostring(clothOrError)) end
            task.wait(0.25)
            continue
        end

        local cloth = clothOrError
        if not cloth then
            task.wait(IDLE_INTERVAL)
            continue
        end

        local sent, sendError = pcall(function()
            Events.GrabClothing:FireServer(cloth)
        end)

        if not sent then
            if DebugLog then DebugLog("AutoGrab request error: " .. tostring(sendError)) else warn("AutoGrab request error: " .. tostring(sendError)) end
        end

        -- Requeue only after the server/replication has had time to remove the cloth.
        task.delay(sent and RETRY_DELAY or 0.25, function()
            if getgenv().LaundryFarmRunning and getgenv().AutoGrab and cloth.Parent == clothingFolder then
                enqueueCloth(cloth)
            end
        end)

        task.wait(REQUEST_INTERVAL)
    end

    childAddedConnection:Disconnect()
end)

local TweenService = game:GetService("TweenService")

local function GetMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for i = 1, 8 do
            local plot = plots:FindFirstChild("Plot" .. i)
            if plot then
                local sign = plot:FindFirstChild("Furniture") and plot.Furniture:FindFirstChild("Sign")
                if sign and sign:FindFirstChild("Main") and sign.Main:FindFirstChild("SurfaceGui") and sign.Main.SurfaceGui:FindFirstChild("TextLabel") then
                    if sign.Main.SurfaceGui.TextLabel.Text == LocalPlayer.Name .. "'s Plot" then
                        return plot
                    end
                end
            end
        end
    end
    return LocalPlayer.NonSaveVars.OwnsPlot.Value
end

local currentFlightId = 0
local function FlyToTarget(targetPosition)
    currentFlightId = currentFlightId + 1
    local myFlightId = currentFlightId
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
        humanoid.Sit = false
    end
    
    local flyVelocity = hrp:FindFirstChild("AutoFarmFly") or Instance.new("BodyVelocity")
    flyVelocity.Name = "AutoFarmFly"
    flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyVelocity.Parent = hrp
    
    local flyGyro = hrp:FindFirstChild("AutoFarmGyro") or Instance.new("BodyGyro")
    flyGyro.Name = "AutoFarmGyro"
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.P = 3000
    flyGyro.D = 500
    flyGyro.Parent = hrp
    
    local steppedConn
    steppedConn = game:GetService("RunService").Stepped:Connect(function()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
        if humanoid and humanoid.Sit then
            humanoid.Sit = false
        end
    end)
    
    while char and hrp.Parent and (hrp.Position - targetPosition).Magnitude > 5 and currentFlightId == myFlightId do
        local dir = (targetPosition - hrp.Position).Unit
        flyVelocity.Velocity = dir * (getgenv().FlySpeed or 60)
        flyGyro.CFrame = CFrame.new(hrp.Position, targetPosition)
        task.wait()
    end
    
    if currentFlightId == myFlightId then
        if steppedConn then steppedConn:Disconnect() end
        flyVelocity:Destroy()
        flyGyro:Destroy()
        if humanoid then
            humanoid.PlatformStand = false
        end
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    else
        if steppedConn then steppedConn:Disconnect() end
    end
end

local function GetRequiredClothes()
    local required = 0
    pcall(function()
        local plot = GetMyPlot()
        if plot and plot:FindFirstChild("WashingMachines") then
            local machines = plot.WashingMachines:GetChildren()
            local hasPartial = false
            
            -- Find machines that are not full but have clothes
            for _, machine in ipairs(machines) do
                if machine:FindFirstChild("Config") then
                    local maxCap = WashingMachinesInfo[machine.Name].Capacity
                    local currentCap = machine.Config.Capacity.Value
                    local cycleFinished = machine.Config.CycleFinished.Value
                    if not cycleFinished and currentCap > 0 and currentCap < maxCap then
                        hasPartial = true
                        required = required + (maxCap - currentCap)
                    end
                end
            end
            
            -- If no partially full machines, gather total quota of all empty machines
            if not hasPartial then
                for _, machine in ipairs(machines) do
                    if machine:FindFirstChild("Config") then
                        local maxCap = WashingMachinesInfo[machine.Name].Capacity
                        local currentCap = machine.Config.Capacity.Value
                        local cycleFinished = machine.Config.CycleFinished.Value
                        
                        if cycleFinished or currentCap == 0 then
                            required = required + maxCap
                        end
                    end
                end
            end
        end
    end)
    return required
end

local function GetBackpackStatus()
    local currentAmount = LocalPlayer.NonSaveVars.BackpackAmount.Value
    local maxAmount = LocalPlayer.NonSaveVars.BasketSize.Value
    local status = LocalPlayer.NonSaveVars.BasketStatus.Value

    pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if gui and gui:FindFirstChild("Info") and gui.Info:FindFirstChild("Frame") and gui.Info.Frame:FindFirstChild("Backpack") then
            local backpack = gui.Info.Frame.Backpack
            
            if backpack:FindFirstChild("Label") then
                local currentStr, maxStr = string.match(backpack.Label.Text, "(%d+)/(%d+)")
                if currentStr and maxStr then
                    currentAmount = tonumber(currentStr)
                    maxAmount = tonumber(maxStr)
                end
            end
            
            if backpack:FindFirstChild("Clean") and backpack.Clean.Visible then
                status = "Clean"
            elseif backpack:FindFirstChild("Dirty") and backpack.Dirty.Visible then
                status = "Dirty"
            elseif backpack:FindFirstChild("Empty") and backpack.Empty.Visible then
                status = "Empty"
            end
        end
    end)
    
    local requiredClothes = GetRequiredClothes()
    
    if currentAmount == 0 then
        getgenv().ActionState = "Grabbing"
        getgenv().LastGrabAmount = 0
        getgenv().LastGrabTime = tick()
    else
        if not getgenv().LastGrabAmount or currentAmount ~= getgenv().LastGrabAmount then
            getgenv().LastGrabAmount = currentAmount
            getgenv().LastGrabTime = tick()
        end
    end
    
    local timeSinceLastGrab = tick() - (getgenv().LastGrabTime or tick())
    local isStuckGrabbing = (timeSinceLastGrab > 5)

    if currentAmount == 0 then
        getgenv().ActionState = "Grabbing"
    elseif currentAmount >= maxAmount or (requiredClothes > 0 and currentAmount >= requiredClothes) or (not getgenv().AutoGrab and currentAmount > 0) or (isStuckGrabbing and currentAmount > 0) then
        getgenv().ActionState = "Emptying"
    end
    if not getgenv().ActionState then getgenv().ActionState = "Grabbing" end
    
    return currentAmount, maxAmount, status
end

-- // Auto Wash
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoWash and not getgenv().IsSelling then
            pcall(function()
                local plot = GetMyPlot()
                if plot and plot:FindFirstChild("WashingMachines") then
                    local machines = plot.WashingMachines:GetChildren()
                    
                    -- Priority: Fill partially full machines first
                    table.sort(machines, function(a, b)
                        local aCap = a:FindFirstChild("Config") and a.Config.Capacity.Value or 0
                        local bCap = b:FindFirstChild("Config") and b.Config.Capacity.Value or 0
                        local aMax = a:FindFirstChild("Config") and WashingMachinesInfo[a.Name] and WashingMachinesInfo[a.Name].Capacity or 0
                        local bMax = b:FindFirstChild("Config") and WashingMachinesInfo[b.Name] and WashingMachinesInfo[b.Name].Capacity or 0
                        
                        local aPartial = (aCap > 0 and aCap < aMax and not a.Config.CycleFinished.Value)
                        local bPartial = (bCap > 0 and bCap < bMax and not b.Config.CycleFinished.Value)
                        
                        if aPartial and not bPartial then return true end
                        if bPartial and not aPartial then return false end
                        return false
                    end)
                    
                    for _, machine in ipairs(machines) do
                        if machine:FindFirstChild("Config") then
                            local cycleFinished = machine.Config.CycleFinished.Value
                            local amount, maxAmount, basketStatus = GetBackpackStatus()
                            local isBasketFull = (amount >= maxAmount)
                            
                            local currentCap = machine.Config.Capacity.Value
                            local maxCap = WashingMachinesInfo[machine.Name].Capacity
                            local isFull = currentCap >= maxCap
                            
                            local needUnload = cycleFinished and (basketStatus == "Clean" or amount == 0) and amount < maxAmount
                            -- Wait for emptying state
                            local needLoad = (not isFull) and (not cycleFinished) and (basketStatus ~= "Clean") and getgenv().ActionState == "Emptying" and amount > 0
                            
                            if needUnload or needLoad then
                                DebugLog("AutoWash: Machine " .. machine.Name .. (needUnload and " unload" or "") .. (needLoad and " load" or ""))
                                getgenv().IsWashing = true
                                local char = LocalPlayer.Character
                                if char and char:FindFirstChild("HumanoidRootPart") and machine:FindFirstChild("MAIN") then
                                    local hrp = char.HumanoidRootPart
                                    local targetCFrame = machine.MAIN.CFrame * CFrame.new(0, 3, 10)
                                    local dist = (hrp.Position - targetCFrame.Position).Magnitude
                                    
                                    if dist > 5 then
                                        FlyToTarget(targetCFrame.Position)
                                        task.wait(0.2)
                                    end
                                    
                                    if needUnload or needLoad then
                                        if firetouchinterest then
                                            firetouchinterest(hrp, machine.MAIN, 0)
                                            firetouchinterest(hrp, machine.MAIN, 1)
                                        end
                                    end

                                    if needUnload then
                                        Events.UnloadWashingMachine:FireServer(machine)
                                        task.wait(0.2)
                                    elseif needLoad then
                                        Events.LoadWashingMachine:FireServer(machine)
                                        task.wait(0.2)
                                    end
                                end
                                getgenv().IsWashing = false
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- // Auto Sell (Drop Clothes In Chute)
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoSell then
            pcall(function()
                local amount, maxAmount, basketStatus = GetBackpackStatus()
                if amount > 0 then
                    local isClean = (basketStatus == "Clean")
                    local shouldSell = false
                    
                    if isClean then
                        if getgenv().ActionState == "Emptying" then
                            shouldSell = true
                        else
                            local plot = GetMyPlot()
                            local moreToUnload = false
                            if plot and plot:FindFirstChild("WashingMachines") then
                                for _, machine in ipairs(plot.WashingMachines:GetChildren()) do
                                    if machine:FindFirstChild("Config") and machine.Config.CycleFinished.Value then
                                        moreToUnload = true
                                        break
                                    end
                                end
                            end
                            if not moreToUnload then
                                shouldSell = true
                            end
                        end
                    else
                        DebugLog("AutoSell: Dirty clothes in bag, waiting for wash")
                    end
                    
                    if isClean and shouldSell then
                        DebugLog("AutoSell: Flying to sell")
                        getgenv().IsSelling = true
                        local char = LocalPlayer.Character
                        local chute = workspace:FindFirstChild("_FinishChute")
                        if char and char:FindFirstChild("HumanoidRootPart") and chute then
                            local targetPart = chute:IsA("BasePart") and chute or chute:FindFirstChildWhichIsA("BasePart")
                            if targetPart then
                                local hrp = char.HumanoidRootPart
                                local targetCFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
                                
                                -- Teleport (Ghost Fly)
                                FlyToTarget(targetCFrame.Position)
                                task.wait(0.2)
                                
                                if firetouchinterest then
                                    firetouchinterest(hrp, targetPart, 0)
                                    firetouchinterest(hrp, targetPart, 1)
                                end
                                
                                local dropEvent = Events:FindFirstChild("DropClothesInChute")
                                if dropEvent then
                                    dropEvent:FireServer()
                                    task.wait(0.5)
                                end
                            end
                        end
                        getgenv().IsSelling = false
                    end
                end
            end)
        end
    end
end)

-- // Auto Spin Wheel
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoSpin then
            pcall(function()
                local wheel = workspace.Debris.NPCVehicles:FindFirstChild("SpinTheWheel")
                if wheel and wheel:FindFirstChild("_ClickToSpin") then
                    if wheel.Timer.Value <= 0 and not wheel._ClickToSpin.Spun.Value then
                        Events.SpinTheWheel:InvokeServer()
                        task.wait(1.5)
                        Events.ClaimWheelAward:InvokeServer()
                    end
                end
            end)
        end
    end
end)

-- // Auto Buy Washing Machine
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoBuyMachine then
            pcall(function()
                local maxID = 1
                -- Check inventory tier
                for _, v in pairs(LocalPlayer.SaveVars.Inventory:GetChildren()) do
                    local num = tonumber(v.Name)
                    if num and num > maxID then
                        maxID = num
                    end
                end
                -- Check Plot machines
                local plot = LocalPlayer.NonSaveVars.OwnsPlot.Value
                if plot and plot:FindFirstChild("WashingMachines") then
                    for _, machine in ipairs(plot.WashingMachines:GetChildren()) do
                        local num = tonumber(machine.Name)
                        if num and num > maxID then
                            maxID = num
                        end
                    end
                end
                -- Spam buy until empty funds
                local nextID = maxID + 1
                while nextID <= 100 do
                    local success = game:GetService("ReplicatedStorage").Events.BuyWashingMachine:InvokeServer(tostring(nextID))
                    if success then
                        nextID = nextID + 1
                        task.wait(0.1)
                    else
                        break
                    end
                end
            end)
        end
    end
end)

-- // Auto Equip Best Machine
local lastEquipConfig = ""
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoEquipMachine then
            pcall(function()
                local availableMachines = {}
                -- Combine inventory machines
                for _, v in pairs(LocalPlayer.SaveVars.Inventory:GetChildren()) do
                    local num = tonumber(v.Name)
                    if num and v.Value > 0 then
                        for i = 1, v.Value do table.insert(availableMachines, num) end
                    end
                end
                -- Combine Plot machines
                for _, v in pairs(LocalPlayer.SaveVars.Plot:GetChildren()) do
                    local num = tonumber(v.Name)
                    if num then
                        table.insert(availableMachines, num)
                    end
                end
                
                -- Sort highest to lowest
                table.sort(availableMachines, function(a, b) return a > b end)
                
                local currentConfig = ""
                for i = 1, 8 do
                    if availableMachines[i] then
                        currentConfig = currentConfig .. availableMachines[i] .. ","
                    end
                end
                
                -- Update if higher tier available
                if currentConfig ~= lastEquipConfig then
                    for i = 1, 8 do
                        if availableMachines[i] then
                            game:GetService("ReplicatedStorage").Events.PlaceWashingMachine:InvokeServer(tostring(availableMachines[i]), i)
                            task.wait(0.1)
                        end
                    end
                    lastEquipConfig = currentConfig
                end
            end)
        end
    end
end)

-- // Auto Buy Basket
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoBuyBasket then
            pcall(function()
                local maxID = 1
                for _, v in pairs(LocalPlayer.SaveVars.Baskets:GetChildren()) do
                    local num = tonumber(v.Name)
                    if num and num > maxID then
                        maxID = num
                    end
                end
                
                -- Spam buy baskets until empty funds
                local nextID = maxID + 1
                while nextID <= 100 do
                    local success = game:GetService("ReplicatedStorage").Events.BuyBasket:InvokeServer(tostring(nextID))
                    if success then
                        nextID = nextID + 1
                        task.wait(0.1)
                    else
                        break
                    end
                end
            end)
        end
    end
end)

-- // Noclip
game:GetService("RunService").Stepped:Connect(function()
    if getgenv().Noclip then
        local char = game.Players.LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- // Auto Claim Challenges
task.spawn(function()
    while task.wait() do if not getgenv().LaundryFarmRunning then break end
        if getgenv().AutoChallenge then
            pcall(function()
                local ChallengesData = require(game:GetService("ReplicatedStorage").Modules.Challenges)
                local GetChallenges = game:GetService("ReplicatedStorage").Events.Challenges.GetChallenges
                local ClaimChallenge = game:GetService("ReplicatedStorage").Events.Challenges.ClaimChallenge
                
                local activeChallenges = GetChallenges:InvokeServer()
                if activeChallenges then
                    for _, v in pairs(activeChallenges) do
                        if not v.Claimed then
                            local goal = 1
                            if ChallengesData.Easy and ChallengesData.Easy[v.ID] then
                                goal = ChallengesData.Easy[v.ID].Goal
                            elseif ChallengesData.Medium and ChallengesData.Medium[v.ID] then
                                goal = ChallengesData.Medium[v.ID].Goal
                            elseif ChallengesData.Hard and ChallengesData.Hard[v.ID] then
                                goal = ChallengesData.Hard[v.ID].Goal
                            elseif ChallengesData[v.ID] then
                                goal = ChallengesData[v.ID].Goal
                            end
                            
                            if v.Progress >= goal then
                                ClaimChallenge:InvokeServer(v.ID)
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- // ESP Loop
task.spawn(function()
    while task.wait(0.5) do if not getgenv().LaundryFarmRunning then break end
        if getgenv().ClothESP then
            pcall(function()
                for _, cloth in ipairs(workspace.Debris.Clothing:GetChildren()) do
                    local specialTag = cloth:FindFirstChild("SpecialTag")
                    local isRare = specialTag ~= nil
                    
                    local shouldShow = true
                    if isRare and not getgenv().ESPRare then shouldShow = false end
                    if not isRare and not getgenv().ESPNormal then shouldShow = false end
                    
                    local existingESP = cloth:FindFirstChild("LaundryESP")
                    
                    if shouldShow then
                        if not existingESP then
                            local text = "Normal " .. cloth.Name
                            local color = Color3.fromRGB(255, 255, 255) -- White
                            
                            if isRare then
                                local lvl = specialTag.Value
                                text = "Rare " .. cloth.Name .. " (Lv." .. tostring(lvl) .. ")"
                                
                                local RarityColors = {
                                    Color3.fromRGB(150, 255, 150), -- 1 Green
                                    Color3.fromRGB(100, 200, 255), -- 2 Blue
                                    Color3.fromRGB(200, 100, 255), -- 3 Purple
                                    Color3.fromRGB(255, 100, 100), -- 4 Red
                                    Color3.fromRGB(255, 215, 0),   -- 5 Gold
                                    Color3.fromRGB(255, 150, 0),   -- 6 Orange
                                    Color3.fromRGB(255, 50, 200),  -- 7 Pink
                                }
                                local num = tonumber(lvl)
                                if num then
                                    local index = ((num - 1) % #RarityColors) + 1
                                    color = RarityColors[index]
                                else
                                    color = Color3.fromRGB(255, 215, 0)
                                end
                            end
                            
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "LaundryESP"
                            billboard.Adornee = cloth
                            billboard.Size = UDim2.new(0, 150, 0, 50)
                            billboard.StudsOffset = Vector3.new(0, 2, 0)
                            billboard.AlwaysOnTop = true
                            
                            local textLabel = Instance.new("TextLabel")
                            textLabel.Parent = billboard
                            textLabel.BackgroundTransparency = 1
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.Text = text
                            textLabel.TextColor3 = color
                            textLabel.TextStrokeTransparency = 0
                            textLabel.TextScaled = true
                            textLabel.Font = Enum.Font.GothamBold
                            
                            billboard.Parent = cloth
                        end
                    else
                        if existingESP then
                            existingESP:Destroy()
                        end
                    end
                end
            end)
        else
            -- Clear old esp when disabled
            for _, cloth in ipairs(workspace.Debris.Clothing:GetChildren()) do
                if cloth:FindFirstChild("LaundryESP") then
                    cloth.LaundryESP:Destroy()
                end
            end
        end
    end
end)
