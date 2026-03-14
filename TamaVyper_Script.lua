--[[
╔══════════════════════════════════════════════════╗
║           🌾 TamaVyper — AUTO SCRIPT 🌾          ║
║         Wind UI • Aquatic Purple Theme           ║
║         Farm • Shop • Sell • Safety • Visual     ║
╚══════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════
--               SERVICES
-- ════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Workspace         = game:GetService("Workspace")

-- ════════════════════════════════════════
--              PLAYER REFS
-- ════════════════════════════════════════
local player    = Players.LocalPlayer
local backpack  = player:WaitForChild("Backpack")

local function getChar()
    return player.Character
end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ════════════════════════════════════════
--               UTILITIES
-- ════════════════════════════════════════
local function safeTeleport(pos)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
        task.wait(0.25)
    end
end

local function equipTool(name)
    local c = getChar()
    if not c then return false end
    local tool = backpack:FindFirstChild(name) or c:FindFirstChild(name)
    if tool and tool:IsA("Tool") then
        local hum = getHumanoid()
        if hum then
            hum:EquipTool(tool)
            task.wait(0.3)
            return true
        end
    end
    return false
end

local function unequipAll()
    local hum = getHumanoid()
    if hum then
        hum:UnequipTools()
        task.wait(0.15)
    end
end

local function activateEquipped()
    local c = getChar()
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Tool") then
            task.spawn(function() v:Activate() end)
            break
        end
    end
end

local function fireRemote(container, remoteName, ...)
    local remote = container:FindFirstChild(remoteName, true)
    if remote then
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
            return true
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    end
    return false
end

local function clickDetector(obj)
    local det = obj:FindFirstChildWhichIsA("ClickDetector", true)
    if det then
        local ok, _ = pcall(function() fireclickdetector(det) end)
        return ok
    end
    return false
end

-- ════════════════════════════════════════
--           STATE & CONFIG
-- ════════════════════════════════════════
local S = {
    AutoPlant      = false,
    AutoHarvest    = false,
    AutoSiram      = false,
    AutoFeedAyam   = false,
    AutoCollectEgg = false,
    AutoBuyBibit   = false,
    AutoBuyTool    = false,
    AutoSell       = false,
    AutoPayung     = false,
    AutoHygiene    = false,
    AntiAFK        = false,
    FPSUnlocker    = false,
    NoShadow       = false,
    NoParticle     = false,
    NoOverhead     = false,
    NoFog          = false,
    LowQuality     = false,
}

local Config = {
    BibitList        = {"Bibit Padi","Bibit Jagung","Bibit Kangkung","Bibit Bayam",
                        "Bibit Tomat","Bibit Cabai","Bibit Sawit","Bibit Durian"},
    BibitSelected    = {},
    ToolList         = {"Cangkul","Penyiram Tembaga","Sabit","Payung","Gunting"},
    ToolSelected     = {},
    BibitMinStock    = 5,
    ShopDelay        = 2,
    PanenItems       = {"Padi","Jagung","Kangkung","Bayam","Tomat","Cabai","Sawit","Durian"},
    EggRarities      = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Celestial"},
    SellBlacklist    = {},
    AntiAFKInterval  = 30,
    TargetFPS        = 60,
}

local Stats = {
    TotalPanen = 0,
}

-- ════════════════════════════════════════
--            STATS READER
-- ════════════════════════════════════════
local function getLeaderStats()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return {Coins=0, Level=0, XP=0} end
    local function val(...)
        for _, name in ipairs({...}) do
            local v = ls:FindFirstChild(name)
            if v then return v.Value end
        end
        return 0
    end
    return {
        Coins = val("Coins","Gold","Money","Rupiah","Uang"),
        Level = val("Level","Lvl","Rank"),
        XP    = val("XP","Exp","Pengalaman"),
    }
end

-- ════════════════════════════════════════
--          HELPER: SCAN PLOTS
-- ════════════════════════════════════════
local function isOwnedByPlayer(obj)
    local o = obj:FindFirstChild("Owner") or obj:FindFirstChild("PlayerName") or obj:FindFirstChild("OwnerName")
    if o then
        return o.Value == player.Name or o.Value == tostring(player.UserId)
    end
    -- Coba cek via UserId value
    local uid = obj:FindFirstChild("OwnerID") or obj:FindFirstChild("UserId")
    if uid then return uid.Value == player.UserId end
    return false
end

local function getStateValue(obj)
    local s = obj:FindFirstChild("State") or obj:FindFirstChild("Status")
            or obj:FindFirstChild("GrowState") or obj:FindFirstChild("Stage")
    if s then return s.Value end
    return nil
end

local function isReadyState(v)
    return v == "Ready" or v == "Mature" or v == "Harvest" or v == "Done"
        or v == "READY" or v == 3 or v == 4
end

local function isEmptyState(v)
    return v == nil or v == "" or v == "Empty" or v == "None" or v == 0
end

local function isHungryState(v)
    return v == "HUNGRY" or v == "Hungry" or v == 1
end

-- ════════════════════════════════════════
--           FARM — AUTO PLANT
-- ════════════════════════════════════════
local function doAutoPlant()
    while S.AutoPlant do
        local c = getChar()
        if not c then task.wait(1); continue end

        -- Kumpulkan semua bibit
        local bibits = {}
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("bibit") then
                table.insert(bibits, tool)
            end
        end

        if #bibits == 0 then
            task.wait(2)
            continue
        end

        -- Cari folder plot/lahan
        local plotRoot = Workspace:FindFirstChild("Plots")
                      or Workspace:FindFirstChild("Lahan")
                      or Workspace:FindFirstChild("Farms")
                      or Workspace:FindFirstChild("Farm")
                      or Workspace

        local bibitIdx = 1
        for _, obj in ipairs(plotRoot:GetDescendants()) do
            if not S.AutoPlant then break end
            if not (obj:IsA("BasePart") or obj:IsA("Model")) then continue end
            if not isOwnedByPlayer(obj) then continue end

            local sv = getStateValue(obj)
            if not isEmptyState(sv) then continue end

            -- Plot kosong & milik player
            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or obj
            if not part then continue end

            safeTeleport(part.Position)
            if not S.AutoPlant then break end

            -- Equip bibit bergantian
            local bibit = bibits[bibitIdx]
            bibitIdx = (bibitIdx % #bibits) + 1

            if bibit and bibit.Parent then
                local hum = getHumanoid()
                if hum then
                    hum:EquipTool(bibit)
                    task.wait(0.3)
                    activateEquipped()
                    task.wait(0.6)
                end
            end
        end
        task.wait(1)
    end
end

-- ════════════════════════════════════════
--          FARM — AUTO HARVEST
-- ════════════════════════════════════════
local function doAutoHarvest()
    while S.AutoHarvest do
        local c = getChar()
        if not c then task.wait(1); continue end

        local function scanHarvest(parent)
            for _, obj in ipairs(parent:GetChildren()) do
                if not S.AutoHarvest then return end
                if not isOwnedByPlayer(obj) then
                    if obj:IsA("Folder") or obj:IsA("Model") then
                        scanHarvest(obj)
                    end
                    continue
                end

                local sv = getStateValue(obj)
                if isReadyState(sv) then
                    local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")) or (obj:IsA("BasePart") and obj)
                    if part then
                        safeTeleport(part.Position)
                        if not S.AutoHarvest then return end

                        -- Coba equip sabit
                        equipTool("Sabit")
                        task.wait(0.2)
                        -- Coba click detector
                        if not clickDetector(obj) then
                            -- Coba remote
                            if not fireRemote(ReplicatedStorage, "Harvest", obj) then
                                fireRemote(ReplicatedStorage, "HarvestCrop", obj)
                            end
                        end
                        Stats.TotalPanen = Stats.TotalPanen + 1
                        task.wait(0.5)
                    end
                end

                if obj:IsA("Folder") or obj:IsA("Model") then
                    scanHarvest(obj)
                end
            end
        end

        scanHarvest(Workspace)
        task.wait(2)
    end
end

-- ════════════════════════════════════════
--       FARM — AUTO SIRAM (Sawit&Durian)
-- ════════════════════════════════════════
local function doAutoSiram()
    while S.AutoSiram do
        local c = getChar()
        if not c then task.wait(1); continue end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not S.AutoSiram then break end
            if not obj:IsA("Model") then continue end

            local nameL = obj.Name:lower()
            local isSawitDurian = nameL:find("sawit") or nameL:find("durian")
            if not isSawitDurian then continue end
            if not isOwnedByPlayer(obj) then continue end

            -- Cek apakah perlu disiram
            local waterVal = obj:FindFirstChild("Water") or obj:FindFirstChild("WaterLevel")
                          or obj:FindFirstChild("NeedsWater") or obj:FindFirstChild("Thirsty")
            local needsWater = not waterVal or waterVal.Value == false or waterVal.Value == 0

            if needsWater then
                local part = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if part then
                    safeTeleport(part.Position)
                    if not S.AutoSiram then break end

                    if equipTool("Penyiram Tembaga") then
                        task.wait(0.2)
                        activateEquipped()
                        task.wait(0.7)
                    end
                end
            end
        end
        task.wait(2)
    end
end

-- ════════════════════════════════════════
--         FARM — AUTO FEED AYAM
-- ════════════════════════════════════════
local function doAutoFeedAyam()
    while S.AutoFeedAyam do
        local c = getChar()
        if not c then task.wait(1); continue end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not S.AutoFeedAyam then break end
            if not obj:IsA("Model") then continue end

            local nameL = obj.Name:lower()
            if not (nameL:find("ayam") or nameL:find("chicken")) then continue end
            if not isOwnedByPlayer(obj) then continue end

            local sv = getStateValue(obj)
            if not isHungryState(sv) then continue end

            local part = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if part then
                safeTeleport(part.Position)
                if not S.AutoFeedAyam then break end

                local fed = false
                -- Coba pakai tool pakan
                for _, toolName in ipairs({"Pakan Ayam","Pakan","Makanan Ayam","Biji"}) do
                    if equipTool(toolName) then
                        task.wait(0.2)
                        activateEquipped()
                        task.wait(0.5)
                        fed = true
                        break
                    end
                end
                -- Fallback remote
                if not fed then
                    if not fireRemote(ReplicatedStorage, "FeedChicken", obj) then
                        fireRemote(ReplicatedStorage, "Feed", obj)
                    end
                    task.wait(0.5)
                end
            end
        end
        task.wait(2)
    end
end

-- ════════════════════════════════════════
--        FARM — AUTO COLLECT EGG
-- ════════════════════════════════════════
local function doAutoCollectEgg()
    while S.AutoCollectEgg do
        local c = getChar()
        if not c then task.wait(1); continue end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not S.AutoCollectEgg then break end
            if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end

            local nameL = obj.Name:lower()
            if not (nameL:find("telur") or nameL:find("egg")) then continue end
            if not isOwnedByPlayer(obj) then continue end

            local sv = getStateValue(obj)
            if sv ~= "READY" and sv ~= "Ready" and sv ~= true and sv ~= 1 then continue end

            local part = (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))) or (obj:IsA("BasePart") and obj)
            if part then
                safeTeleport(part.Position)
                if not S.AutoCollectEgg then break end

                if not clickDetector(obj) then
                    if not fireRemote(ReplicatedStorage, "CollectEgg", obj) then
                        fireRemote(ReplicatedStorage, "Collect", obj)
                    end
                end
                Stats.TotalPanen = Stats.TotalPanen + 1
                task.wait(0.4)
            end
        end
        task.wait(2)
    end
end

-- ════════════════════════════════════════
--          SHOP — AUTO BUY BIBIT
-- ════════════════════════════════════════
local function doAutoBuyBibit()
    while S.AutoBuyBibit do
        for _, bibitName in ipairs(Config.BibitSelected) do
            if not S.AutoBuyBibit then break end

            -- Hitung stok saat ini
            local stock = 0
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool.Name == bibitName then stock += 1 end
            end

            if stock < Config.BibitMinStock then
                local need = Config.BibitMinStock - stock
                -- Coba berbagai remote name
                local bought = false
                for _, name in ipairs({"BuyItem","BuySeed","Buy","PurchaseSeed","Purchase"}) do
                    if fireRemote(ReplicatedStorage, name, bibitName, need) then
                        bought = true; break
                    end
                end
                task.wait(0.5)
            end
        end
        task.wait(Config.ShopDelay)
    end
end

-- ════════════════════════════════════════
--          SHOP — AUTO BUY TOOL
-- ════════════════════════════════════════
local function doAutoBuyTool()
    while S.AutoBuyTool do
        for _, toolName in ipairs(Config.ToolSelected) do
            if not S.AutoBuyTool then break end

            local c = getChar()
            local owned = backpack:FindFirstChild(toolName) or (c and c:FindFirstChild(toolName))
            if not owned then
                for _, name in ipairs({"BuyTool","Buy","Purchase","PurchaseTool"}) do
                    if fireRemote(ReplicatedStorage, name, toolName) then break end
                end
                task.wait(0.5)
            end
        end
        task.wait(Config.ShopDelay)
    end
end

-- ════════════════════════════════════════
--           SELL — AUTO SELL
-- ════════════════════════════════════════
local function isBlacklisted(name)
    for _, bl in ipairs(Config.SellBlacklist) do
        if name == bl or name:find(bl) then return true end
    end
    return false
end

local function doAutoSell()
    while S.AutoSell do
        local c = getChar()
        if not c then task.wait(1); continue end

        -- Coba cari NPC Toko / Market untuk teleport
        local market = Workspace:FindFirstChild("Market", true)
                    or Workspace:FindFirstChild("Toko", true)
                    or Workspace:FindFirstChild("Pasar", true)

        -- Jual via remote
        for _, item in ipairs(backpack:GetChildren()) do
            if not S.AutoSell then break end
            if not item:IsA("Tool") then continue end
            if isBlacklisted(item.Name) then continue end

            for _, rname in ipairs({"SellItem","Sell","SellAll","SellHarvest"}) do
                if fireRemote(ReplicatedStorage, rname, item.Name) then break end
            end
            task.wait(0.1)
        end

        task.wait(1.5)
    end
end

-- ════════════════════════════════════════
--         SAFETY — AUTO PAYUNG
-- ════════════════════════════════════════
local payungEquipped = false
local function checkIsRaining()
    -- Cek Rain object di Lighting/Workspace
    local rainParts = {
        Lighting:FindFirstChild("Rain"),
        Workspace:FindFirstChild("Rain"),
        Workspace:FindFirstChild("RainFolder"),
        Workspace:FindFirstChild("Weather"),
    }
    for _, v in ipairs(rainParts) do
        if v then
            if v:IsA("ParticleEmitter") and v.Enabled then return true end
            if v:IsA("BoolValue") and v.Value == true then return true end
            if v:IsA("Folder") or v:IsA("Model") then return true end
        end
    end
    -- Cek via player value
    local rv = player:FindFirstChild("IsRaining") or Workspace:FindFirstChild("IsRaining")
    if rv and rv.Value == true then return true end
    return false
end

local function doAutoPayung()
    payungEquipped = false
    while S.AutoPayung do
        local raining = checkIsRaining()
        if raining and not payungEquipped then
            payungEquipped = true
            equipTool("Payung")
        elseif not raining and payungEquipped then
            payungEquipped = false
            unequipAll()
        end
        task.wait(1.5)
    end
    if payungEquipped then unequipAll() end
    payungEquipped = false
end

-- ════════════════════════════════════════
--        SAFETY — AUTO HYGIENE
-- ════════════════════════════════════════
local function getHygieneValue()
    -- Cari di berbagai lokasi umum
    local paths = {
        player:FindFirstChild("Hygiene"),
        player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Hygiene"),
        player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Hygiene"),
        player.Character and player.Character:FindFirstChild("Hygiene"),
    }
    for _, v in ipairs(paths) do
        if v and v:IsA("NumberValue") or (v and v:IsA("IntValue")) then
            return v.Value
        end
    end
    return 100 -- Default aman
end

local function doAutoHygiene()
    while S.AutoHygiene do
        local hygiene = getHygieneValue()
        if hygiene <= 40 then
            -- Cari shower
            local showerPart = Workspace:FindFirstChild("Shower", true)
                            or Workspace:FindFirstChild("Bathroom", true)
                            or Workspace:FindFirstChild("KamarMandi", true)
                            or Workspace:FindFirstChild("Kamar Mandi", true)

            if showerPart then
                local part = showerPart:IsA("BasePart") and showerPart
                          or (showerPart:IsA("Model") and (showerPart.PrimaryPart or showerPart:FindFirstChildOfClass("BasePart")))
                if part then
                    safeTeleport(part.Position)
                    task.wait(0.5)
                    -- Coba remote mandi
                    for _, n in ipairs({"Shower","Mandi","CleanUp","Hygiene"}) do
                        if fireRemote(ReplicatedStorage, n) then break end
                    end
                    task.wait(3)
                end
            end
        end
        task.wait(2)
    end
end

-- ════════════════════════════════════════
--           SAFETY — ANTI AFK
-- ════════════════════════════════════════
local function doAntiAFK()
    while S.AntiAFK do
        task.wait(Config.AntiAFKInterval)
        if not S.AntiAFK then break end
        local hrp = getHRP()
        local hum = getHumanoid()
        if hrp and hum then
            -- Gerak kecil tak terlihat
            local ori = hrp.CFrame
            hrp.CFrame = ori * CFrame.new(0.05, 0, 0)
            task.wait(0.05)
            hrp.CFrame = ori
            -- Virtual jump
            hum.Jump = true
            task.wait(0.05)
            hum.Jump = false
        end
    end
end

-- ════════════════════════════════════════
--          SAFETY — FPS UNLOCKER
-- ════════════════════════════════════════
local fpsConn
local function applyFPS(target)
    if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
    if setfpscap then
        pcall(setfpscap, target)
    end
end

-- ════════════════════════════════════════
--            VISUAL FUNCTIONS
-- ════════════════════════════════════════
local function applyNoShadow(on)
    Lighting.GlobalShadows = not on
end

local function applyNoParticle(on)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            pcall(function() v.Enabled = not on end)
        end
    end
end

local function applyNoOverhead(on)
    local function process(char)
        if not char then return end
        local head = char:FindFirstChild("Head")
        if not head then return end
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("BillboardGui") then
                pcall(function() v.Enabled = not on end)
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        process(plr.Character)
    end
end

local function applyNoFog(on)
    if on then
        Lighting.FogEnd   = 1e8
        Lighting.FogStart = 1e8 - 1
    else
        Lighting.FogEnd   = 100000
        Lighting.FogStart = 0
    end
end

local function applyLowQuality(on)
    pcall(function()
        settings().Rendering.QualityLevel = on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

local function applyMapRingan()
    applyNoShadow(true)
    applyNoParticle(true)
    applyNoFog(true)
    applyLowQuality(true)
    S.NoShadow    = true
    S.NoParticle  = true
    S.NoFog       = true
    S.LowQuality  = true
end

-- ════════════════════════════════════════════════
--                 WIND UI SETUP
-- ════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    'https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/main_example.lua'
))()

local Window = WindUI:CreateWindow({
    Title       = "🌾 TamaVyper",
    SubTitle    = "Auto Script v1.0",
    Width       = 480,
    Height      = 380,
    Resizable   = true,
    MinSize     = Vector2.new(320, 260),
    MaxSize     = Vector2.new(480, 380),
    Theme       = "Dark",
    Color       = Color3.fromRGB(110, 45, 210),
    Blur        = 6,
    Transparency = 0.08,
    Minimizable  = true,
    Closable     = true,
    DisableX     = false,
})

-- ════════════════════════════════════════
--              TAB: 🌾 FARM
-- ════════════════════════════════════════
local TabFarm    = Window:AddTab({ Name = "Farm", Icon = "🌾" })
local SecFarm    = TabFarm:AddSection({ Name = "Auto Farm" })

SecFarm:AddToggle({
    Name        = "Auto Plant",
    Description = "Scan semua Bibit di backpack & tanam bergantian",
    Default     = false,
    Callback    = function(v)
        S.AutoPlant = v
        if v then task.spawn(doAutoPlant) end
    end,
})

SecFarm:AddToggle({
    Name        = "Auto Harvest",
    Description = "Panen semua tanaman matang milik kamu",
    Default     = false,
    Callback    = function(v)
        S.AutoHarvest = v
        if v then task.spawn(doAutoHarvest) end
    end,
})

SecFarm:AddToggle({
    Name        = "Auto Siram Lahan (Sawit & Durian)",
    Description = "Teleport & siram dengan Penyiram Tembaga",
    Default     = false,
    Callback    = function(v)
        S.AutoSiram = v
        if v then task.spawn(doAutoSiram) end
    end,
})

SecFarm:AddToggle({
    Name        = "Auto Feed Ayam",
    Description = "Beri makan ayam HUNGRY otomatis",
    Default     = false,
    Callback    = function(v)
        S.AutoFeedAyam = v
        if v then task.spawn(doAutoFeedAyam) end
    end,
})

SecFarm:AddToggle({
    Name        = "Auto Collect Egg",
    Description = "Ambil telur yang sudah READY",
    Default     = false,
    Callback    = function(v)
        S.AutoCollectEgg = v
        if v then task.spawn(doAutoCollectEgg) end
    end,
})

-- ════════════════════════════════════════
--              TAB: 🛒 SHOP
-- ════════════════════════════════════════
local TabShop   = Window:AddTab({ Name = "Shop", Icon = "🛒" })
local SecBibit  = TabShop:AddSection({ Name = "Auto Buy Bibit" })

SecBibit:AddDropdown({
    Name        = "Pilih Bibit",
    Description = "Multi-select bibit yang ingin dibeli",
    Options     = Config.BibitList,
    Default     = {},
    MultiSelect = true,
    Callback    = function(v)
        Config.BibitSelected = v
    end,
})

SecBibit:AddSlider({
    Name        = "Stok Minimum",
    Description = "Beli otomatis jika stok di bawah angka ini",
    Min         = 1,
    Max         = 50,
    Default     = 5,
    Suffix      = " pcs",
    Callback    = function(v)
        Config.BibitMinStock = v
    end,
})

SecBibit:AddSlider({
    Name        = "Delay Antar Sesi Beli (detik)",
    Min         = 1,
    Max         = 30,
    Default     = 2,
    Suffix      = "s",
    Callback    = function(v)
        Config.ShopDelay = v
    end,
})

SecBibit:AddToggle({
    Name        = "Auto Buy Bibit",
    Default     = false,
    Callback    = function(v)
        S.AutoBuyBibit = v
        if v then task.spawn(doAutoBuyBibit) end
    end,
})

local SecTool = TabShop:AddSection({ Name = "Auto Buy Tool" })

SecTool:AddDropdown({
    Name        = "Pilih Tool",
    Description = "Multi-select tool yang ingin dibeli",
    Options     = Config.ToolList,
    Default     = {},
    MultiSelect = true,
    Callback    = function(v)
        Config.ToolSelected = v
    end,
})

SecTool:AddToggle({
    Name        = "Auto Buy Tool",
    Description = "Skip jika sudah owned atau level tidak cukup",
    Default     = false,
    Callback    = function(v)
        S.AutoBuyTool = v
        if v then task.spawn(doAutoBuyTool) end
    end,
})

-- ════════════════════════════════════════
--              TAB: 💰 SELL
-- ════════════════════════════════════════
local TabSell  = Window:AddTab({ Name = "Sell", Icon = "💰" })
local SecSell  = TabSell:AddSection({ Name = "Auto Sell" })

SecSell:AddToggle({
    Name        = "Auto Sell Panen & Telur",
    Description = "Jual hasil panen dan telur otomatis setiap loop",
    Default     = false,
    Callback    = function(v)
        S.AutoSell = v
        if v then task.spawn(doAutoSell) end
    end,
})

-- Build blacklist options
local blacklistOptions = {}
for _, v in ipairs(Config.PanenItems) do
    table.insert(blacklistOptions, v)
end
for _, v in ipairs(Config.EggRarities) do
    table.insert(blacklistOptions, "Telur " .. v)
end

SecSell:AddDropdown({
    Name        = "Blacklist (Tidak Dijual)",
    Description = "Pilih item / rarity telur yang TIDAK mau dijual",
    Options     = blacklistOptions,
    Default     = {},
    MultiSelect = true,
    Callback    = function(v)
        Config.SellBlacklist = v
    end,
})

-- ════════════════════════════════════════
--             TAB: 🛡️ SAFETY
-- ════════════════════════════════════════
local TabSafety  = Window:AddTab({ Name = "Safety", Icon = "🛡️" })
local SecSafe    = TabSafety:AddSection({ Name = "Auto Protection" })

SecSafe:AddToggle({
    Name        = "Auto Payung",
    Description = "Equip payung saat hujan, swap otomatis saat mau tanam",
    Default     = false,
    Callback    = function(v)
        S.AutoPayung = v
        if v then task.spawn(doAutoPayung) end
    end,
})

SecSafe:AddToggle({
    Name        = "Auto Hygiene",
    Description = "Shower otomatis saat hygiene turun ke ≤ 40",
    Default     = false,
    Callback    = function(v)
        S.AutoHygiene = v
        if v then task.spawn(doAutoHygiene) end
    end,
})

local SecAFK = TabSafety:AddSection({ Name = "Anti AFK" })

SecAFK:AddSlider({
    Name        = "Interval Anti AFK",
    Description = "Gerakan kecil dikirim setiap N detik",
    Min         = 10,
    Max         = 120,
    Default     = 30,
    Suffix      = "s",
    Callback    = function(v)
        Config.AntiAFKInterval = v
    end,
})

SecAFK:AddToggle({
    Name        = "Anti AFK",
    Description = "Cegah kick karena idle",
    Default     = false,
    Callback    = function(v)
        S.AntiAFK = v
        if v then task.spawn(doAntiAFK) end
    end,
})

local SecFPS = TabSafety:AddSection({ Name = "FPS Unlocker" })

SecFPS:AddSlider({
    Name        = "Target FPS",
    Description = "Set frame rate target",
    Min         = 60,
    Max         = 240,
    Default     = 60,
    Suffix      = " FPS",
    Callback    = function(v)
        Config.TargetFPS = v
        if S.FPSUnlocker then applyFPS(v) end
    end,
})

SecFPS:AddToggle({
    Name        = "FPS Unlocker",
    Default     = false,
    Callback    = function(v)
        S.FPSUnlocker = v
        if v then
            applyFPS(Config.TargetFPS)
        else
            applyFPS(60)
        end
    end,
})

-- ════════════════════════════════════════
--           TAB: 🎨 VISUAL
-- ════════════════════════════════════════
local TabVisual = Window:AddTab({ Name = "Visual", Icon = "🎨" })
local SecVis    = TabVisual:AddSection({ Name = "Map Ringan" })

SecVis:AddButton({
    Name     = "🗺️  Aktifkan Map Ringan (Semua Sekaligus)",
    Callback = function()
        applyMapRingan()
    end,
})

SecVis:AddToggle({
    Name        = "No Shadow",
    Description = "Hilangkan bayangan — dampak terbesar ke performa",
    Default     = false,
    Callback    = function(v)
        S.NoShadow = v
        applyNoShadow(v)
    end,
})

SecVis:AddToggle({
    Name        = "No Particle",
    Description = "Matikan partikel, api, asap, sparkle",
    Default     = false,
    Callback    = function(v)
        S.NoParticle = v
        applyNoParticle(v)
    end,
})

SecVis:AddToggle({
    Name        = "No Overhead",
    Description = "Sembunyikan label di atas kepala player",
    Default     = false,
    Callback    = function(v)
        S.NoOverhead = v
        applyNoOverhead(v)
    end,
})

SecVis:AddToggle({
    Name        = "No Fog",
    Description = "Hapus efek kabut",
    Default     = false,
    Callback    = function(v)
        S.NoFog = v
        applyNoFog(v)
    end,
})

SecVis:AddToggle({
    Name        = "Low Quality",
    Description = "Turunkan render quality ke Level01",
    Default     = false,
    Callback    = function(v)
        S.LowQuality = v
        applyLowQuality(v)
    end,
})

-- ════════════════════════════════════════
--             TAB: 📊 STATS
-- ════════════════════════════════════════
local TabStats = Window:AddTab({ Name = "Stats", Icon = "📊" })
local SecStats = TabStats:AddSection({ Name = "Live Tracking" })

-- Label helper agar kompatibel dengan berbagai Wind UI versi
local function makeLabel(section, defaultText)
    local lbl = section:AddLabel({ Name = defaultText, Text = defaultText })
    -- Buat wrapper update yang handle berbagai method
    local wrapper = { _obj = lbl, _text = defaultText }
    function wrapper:Update(text)
        self._text = text
        if self._obj then
            -- Coba berbagai method update
            if type(self._obj) == "table" then
                if self._obj.Set then
                    pcall(self._obj.Set, self._obj, text)
                elseif self._obj.UpdateText then
                    pcall(self._obj.UpdateText, self._obj, text)
                elseif self._obj.SetText then
                    pcall(self._obj.SetText, self._obj, text)
                elseif self._obj.Name then
                    pcall(function() self._obj.Name = text end)
                end
            end
        end
    end
    return wrapper
end

local lblCoins   = makeLabel(SecStats, "💰  Coins       : memuat...")
local lblPanen   = makeLabel(SecStats, "🌾  Total Panen : 0")
local lblLevel   = makeLabel(SecStats, "⭐  Level        : memuat...")
local lblXP      = makeLabel(SecStats, "✨  XP           : memuat...")
local lblStatus  = makeLabel(SecStats, "📡  Status       : Idle")

-- Live stats update loop
task.spawn(function()
    while true do
        task.wait(1)
        local ok, st = pcall(getLeaderStats)
        if ok then
            lblCoins:Update( "💰  Coins       : " .. tostring(st.Coins))
            lblLevel:Update( "⭐  Level        : " .. tostring(st.Level))
            lblXP:Update(    "✨  XP           : " .. tostring(st.XP))
        end
        lblPanen:Update("🌾  Total Panen : " .. tostring(Stats.TotalPanen))

        -- Status aktif
        local active = {}
        if S.AutoPlant      then table.insert(active, "Plant") end
        if S.AutoHarvest    then table.insert(active, "Harvest") end
        if S.AutoSiram      then table.insert(active, "Siram") end
        if S.AutoFeedAyam   then table.insert(active, "Feed") end
        if S.AutoCollectEgg then table.insert(active, "Egg") end
        if S.AutoBuyBibit   then table.insert(active, "BuyBibit") end
        if S.AutoBuyTool    then table.insert(active, "BuyTool") end
        if S.AutoSell       then table.insert(active, "Sell") end
        if S.AntiAFK        then table.insert(active, "AFK") end

        local txt = #active > 0
            and ("📡  Aktif: " .. table.concat(active, " • "))
            or  "📡  Status       : Idle"
        lblStatus:Update(txt)
    end
end)

-- ════════════════════════════════════════
--          CHARACTER RESPAWN HANDLER
-- ════════════════════════════════════════
player.CharacterAdded:Connect(function(newChar)
    -- Tunggu character load sempurna
    newChar:WaitForChild("HumanoidRootPart", 10)
    newChar:WaitForChild("Humanoid", 10)
    task.wait(1)
    -- Overhead fix untuk karakter baru
    if S.NoOverhead then
        task.delay(1, function() applyNoOverhead(true) end)
    end
    -- Particle fix
    if S.NoParticle then
        task.delay(1, function() applyNoParticle(true) end)
    end
end)

-- ════════════════════════════════════════
--       OVERHEAD FIX — PLAYER BARU
-- ════════════════════════════════════════
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if S.NoOverhead then
            task.delay(1.5, function() applyNoOverhead(true) end)
        end
    end)
end)

-- ════════════════════════════════════════
--          NOTIFICATION STARTUP
-- ════════════════════════════════════════
task.delay(1, function()
    pcall(function()
        WindUI:Notify({
            Title   = "🌾 TamaVyper Script",
            Content = "Script berhasil dimuat! Selamat bertani.",
            Duration = 4,
        })
    end)
end)

-- ════════════════════════════════════════
--   END — All features loaded cleanly.
-- ════════════════════════════════════════
