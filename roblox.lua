-- Brainrot Stealer GUI [UPD 11/9/25] - Fly, Speed Boost, TP/Fly to Base, Insta Steal
-- Features: Orbit-style Fly (manual control), Speed/WalkSpeed Boost, Good UI (OrionLib)
-- TP/Fly to Base (Own/Random/Richest), Insta Raid Richest, Auto Steal (little boost)
-- Updated for Brainrot Dealer Update - Works on all executors (Syn, Krnl, etc.)
-- Load in executor and enjoy!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Wait for essentials
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StealRemote = Remotes:WaitForChild("Steal")
local Bases = workspace:WaitForChild("Bases")

-- OrionLib for nice UI
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

local Window = OrionLib:MakeWindow({
    Name = "🧠 Brainrot Stealer [UPD 11/9/25]",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "BrainrotStealer",
    IntroEnabled = false
})

-- Variables
local flying = false
local flySpeed = 50
local keys = {w = false, a = false, s = false, d = false, q = false, e = false}
local bodyVelocity = nil
local bodyGyro = nil
local noclipConn = nil
local flyConn = nil
local targetPos = nil
local richBase = nil
local autoStealConn = nil
local autoStealEnabled = false

-- Functions
local function getRichest()
    local richest = nil
    local maxCash = 0
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr:FindFirstChild("leaderstats") then
            local cashStat = plr.leaderstats:FindFirstChild("Cash") or plr.leaderstats:FindFirstChild("Money")
            if cashStat and cashStat.Value > maxCash then
                maxCash = cashStat.Value
                richest = plr.Name
            end
        end
    end
    return richest
end

local function tpToBase(plrName)
    local base = Bases:FindFirstChild(plrName)
    if base and base.PrimaryPart then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = base.PrimaryPart.CFrame + Vector3.new(0, 10, 0)
        end
    end
end

local function getStealable(base)
    local steals = {}
    if base then
        for _, desc in pairs(base:GetDescendants()) do
            if desc:IsA("Model") and string.find(string.lower(desc.Name), "brainrot") and desc:FindFirstChild("Owner") and desc.Owner.Value ~= player then
                table.insert(steals, desc)
            end
        end
    end
    return steals
end

local function instaSteal(base)
    local steals = getStealable(base)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in pairs(steals) do
        if obj.PrimaryPart then
            hrp.CFrame = obj.PrimaryPart.CFrame * CFrame.new(0, 0, -5)
            task.wait(0.05)
            StealRemote:FireServer(obj)
        end
    end
    OrionLib:MakeNotification({
        Name = "Steal Boost",
        Content = "Insta stole " .. #steals .. " brainrots!",
        Image = "rbxassetid://4483345998",
        Time = 3
    })
end

local function startFly()
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyAngularVelocity")
    bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
    bodyGyro.AngularVelocity = Vector3.new(0, 0, 0)
    bodyGyro.Parent = hrp

    flyConn = RunService.Heartbeat:Connect(function()
        local cam = workspace.CurrentCamera
        local moveVector = Vector3.new(0, 0, 0)

        if keys.w then moveVector = moveVector + cam.CFrame.LookVector end
        if keys.s then moveVector = moveVector - cam.CFrame.LookVector end
        if keys.a then moveVector = moveVector - cam.RightVector end
        if keys.d then moveVector = moveVector + cam.RightVector end
        if keys.q then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if keys.e then moveVector = moveVector + Vector3.new(0, -1, 0) end

        bodyVelocity.Velocity = moveVector * flySpeed

        -- Auto fly to target
        if targetPos then
            local dir = (targetPos - hrp.Position)
            local dist = dir.Magnitude
            local autoVel = dir.Unit * flySpeed * 0.7
            bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(autoVel, 0.3)
            if dist < 50 then
                instaSteal(richBase)
                targetPos = nil
                richBase = nil
            end
        end

        bodyGyro.CFrame = cam.CFrame
    end)
end

local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    if flyConn then flyConn:Disconnect() end
end

local function toggleNoclip(enabled)
    local char = player.Character
    if not char then return end
    if enabled then
        noclipConn = RunService.Stepped:Connect(function()
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() end
    end
end

local function toggleAutoSteal(enabled)
    if enabled then
        autoStealConn = RunService.Heartbeat:Connect(function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local closest = nil
            local minDist = math.huge
            for _, base in pairs(Bases:GetChildren()) do
                if base.Name ~= player.Name then
                    for _, desc in pairs(base:GetDescendants()) do
                        if desc:IsA("Model") and string.find(string.lower(desc.Name), "brainrot") and desc:FindFirstChild("Owner") and desc.Owner.Value ~= player then
                            local dist = (hrp.Position - (desc.PrimaryPart and desc.PrimaryPart.Position or Vector3.new())).Magnitude
                            if dist < minDist then
                                minDist = dist
                                closest = desc
                            end
                        end
                    end
                end
            end
            if closest and minDist < 100 then -- Little boost: steal nearby only
                hrp.CFrame = closest.PrimaryPart.CFrame * CFrame.new(0, 0, -5)
                task.wait(0.1)
                StealRemote:FireServer(closest)
            end
        end)
    else
        if autoStealConn then autoStealConn:Disconnect() end
    end
end

-- Input Handling
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.W then keys.w = true
        elseif input.KeyCode == Enum.KeyCode.A then keys.a = true
        elseif input.KeyCode == Enum.KeyCode.S then keys.s = true
        elseif input.KeyCode == Enum.KeyCode.D then keys.d = true
        elseif input.KeyCode == Enum.KeyCode.Q then keys.q = true
        elseif input.KeyCode == Enum.KeyCode.E then keys.e = true end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.W then keys.w = false
        elseif input.KeyCode == Enum.KeyCode.A then keys.a = false
        elseif input.KeyCode == Enum.KeyCode.S then keys.s = false
        elseif input.KeyCode == Enum.KeyCode.D then keys.d = false
        elseif input.KeyCode == Enum.KeyCode.Q then keys.q = false
        elseif input.KeyCode == Enum.KeyCode.E then keys.e = false end
    end
end)

-- UI Tabs
local MoveTab = Window:MakeTab({
    Name = "✈️ Movement",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MoveTab:AddToggle({
    Name = "Fly (WASD + QE)",
    Default = false,
    Callback = function(v)
        flying = v
        if v then
            startFly()
        else
            stopFly()
        end
    end
})

MoveTab:AddSlider({
    Name = "Fly Speed",
    Min = 16,
    Max = 500,
    Default = 50,
    Color = Color3.fromRGB(0, 125, 255),
    Increment = 1,
    Callback = function(v)
        flySpeed = v
    end
})

MoveTab:AddToggle({
    Name = "Noclip",
    Default = false,
    Callback = function(v)
        toggleNoclip(v)
    end
})

local TeleTab = Window:MakeTab({
    Name = "🏠 Teleport",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TeleTab:AddButton({
    Name = "TP to Your Base",
    Callback = function()
        tpToBase(player.Name)
    end
})

TeleTab:AddButton({
    Name = "TP to Random Base",
    Callback = function()
        local pls = {}
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player then
                table.insert(pls, plr.Name)
            end
        end
        if #pls > 0 then
            tpToBase(pls[math.random(1, #pls)])
        end
    end
})

TeleTab:AddButton({
    Name = "TP to Richest Base",
    Callback = function()
        local rich = getRichest()
        if rich then
            tpToBase(rich)
        end
    end
})

local StealTab = Window:MakeTab({
    Name = "💀 Steal",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

StealTab:AddToggle({
    Name = "Auto Steal Nearby (Little Boost)",
    Default = false,
    Callback = function(v)
        autoStealEnabled = v
        toggleAutoSteal(v)
    end
})

StealTab:AddButton({
    Name = "Insta Steal Current Area",
    Callback = function()
        -- Steal all nearby (simulate current base)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            for _, base in pairs(Bases:GetChildren()) do
                if (base.PrimaryPart.Position - pos).Magnitude < 200 then
                    instaSteal(base)
                    break
                end
            end
        end
    end
})

StealTab:AddButton({
    Name = "Fly to Richest Base & Insta Raid",
    Callback = function()
        local rich = getRichest()
        if rich then
            local base = Bases:FindFirstChild(rich)
            if base and base.PrimaryPart then
                targetPos = base.PrimaryPart.Position + Vector3.new(0, 20, 0)
                richBase = base
                OrionLib:MakeNotification({
                    Name = "Raid Mode",
                    Content = "Flying to richest base... Hold fly!",
                    Time = 3
                })
            end
        end
    end
})

OrionLib:Init()

-- Cleanup on leave
Players.PlayerRemoving:Connect(function()
    stopFly()
    toggleNoclip(false)
    toggleAutoSteal(false)
end)

print("🧠 Brainrot Stealer loaded! Use Fly + Raid for max steals. Enjoy the update! 🚀")
