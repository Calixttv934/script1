-- Brainrot Stealer Simple GUI [UPD 11/9/25] - Fly, Speed Boost, TP/Fly to Base, Insta Steal
-- Features: Orbit-style Fly, Noclip, TP to Bases, Auto Steal (little boost), Insta Raid
-- No external libraries - Fully self-contained with basic Roblox GUI
-- Updated for Brainrot Dealer Update - Works on Solara and other executors
-- Upload to GitHub as roblox.lua and load with: loadstring(game:HttpGet("https://raw.githubusercontent.com/Calixttv934/script1/main/roblox.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Wait for essentials
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StealRemote = Remotes:WaitForChild("Steal")
local Bases = workspace:WaitForChild("Bases")

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

-- Simple GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BrainrotStealerGUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 300)
Frame.Position = UDim2.new(0.5, -100, 0.5, -150)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.Text = "Brainrot Stealer"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Parent = Frame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 5)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = Frame

-- Helper to create buttons
local function createButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Parent = Frame
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Fly Speed TextBox
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 30)
speedLabel.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
speedLabel.Text = "Fly Speed:"
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextSize = 14
speedLabel.Parent = Frame

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0.5, 0, 0, 30)
speedBox.Position = UDim2.new(0.5, 0, 0, 0) -- Relative to speedLabel, but since list, adjust
speedBox.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
speedBox.Text = "50"
speedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBox.TextSize = 14
speedBox.Parent = speedLabel  -- Nest for simplicity

-- Fly Toggle
local flyBtn = createButton("Fly (WASD QE): Off", function()
    flying = not flying
    flySpeed = tonumber(speedBox.Text) or 50
    if flying then
        startFly()
        flyBtn.Text = "Fly (WASD QE): On"
        flyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    else
        stopFly()
        flyBtn.Text = "Fly (WASD QE): Off"
        flyBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

-- Noclip Toggle
local noclipBtn = createButton("Noclip: Off", function()
    local enabled = noclipConn == nil
    toggleNoclip(enabled)
    if enabled then
        noclipBtn.Text = "Noclip: On"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    else
        noclipBtn.Text = "Noclip: Off"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

-- TP Buttons
createButton("TP to Your Base", function() tpToBase(player.Name) end)
createButton("TP to Random Base", function()
    local pls = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then table.insert(pls, plr.Name) end
    end
    if #pls > 0 then tpToBase(pls[math.random(1, #pls)]) end
end)
createButton("TP to Richest Base", function()
    local rich = getRichest()
    if rich then tpToBase(rich) end
end)

-- Steal Toggles/Buttons
local autoStealBtn = createButton("Auto Steal Nearby: Off", function()
    autoStealEnabled = not autoStealEnabled
    toggleAutoSteal(autoStealEnabled)
    if autoStealEnabled then
        autoStealBtn.Text = "Auto Steal Nearby: On"
        autoStealBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    else
        autoStealBtn.Text = "Auto Steal Nearby: Off"
        autoStealBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

createButton("Insta Steal Current Area", function()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        for _, base in pairs(Bases:GetChildren()) do
            if base.PrimaryPart and (base.PrimaryPart.Position - pos).Magnitude < 200 then
                instaSteal(base)
                break
            end
        end
    end
end)

createButton("Fly to Richest & Insta Raid", function()
    local rich = getRichest()
    if rich then
        local base = Bases:FindFirstChild(rich)
        if base and base.PrimaryPart then
            targetPos = base.PrimaryPart.Position + Vector3.new(0, 20, 0)
            richBase = base
            print("Flying to richest base... Enable Fly!")
        end
    end
end)

-- Functions (same as before)
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
    local count = 0
    for _, obj in pairs(steals) do
        if obj.PrimaryPart then
            hrp.CFrame = obj.PrimaryPart.CFrame * CFrame.new(0, 0, -5)
            task.wait(0.05)
            StealRemote:FireServer(obj)
            count = count + 1
        end
    end
    print("Insta stole " .. count .. " brainrots!")
end

local function startFly()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    bodyVelocity = Instance.new("BodyVelocity", hrp)
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)

    bodyGyro = Instance.new("BodyGyro", hrp)
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 20000

    flyConn = RunService.Heartbeat:Connect(function()
        local cam = workspace.CurrentCamera
        local moveVector = Vector3.new(0, 0, 0)

        if keys.w then moveVector = moveVector + cam.CFrame.LookVector end
        if keys.s then moveVector = moveVector - cam.CFrame.LookVector end
        if keys.a then moveVector = moveVector - cam.CFrame.LookVector:Cross(Vector3.new(0,1,0)) end
        if keys.d then moveVector = moveVector + cam.CFrame.LookVector:Cross(Vector3.new(0,1,0)) end
        if keys.q then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if keys.e then moveVector = moveVector + Vector3.new(0, -1, 0) end

        if moveVector.Magnitude > 0 then moveVector = moveVector.Unit end
        bodyVelocity.Velocity = moveVector * flySpeed

        if targetPos then
            local dir = (targetPos - hrp.Position).Unit
            local dist = (targetPos - hrp.Position).Magnitude
            bodyVelocity.Velocity = dir * flySpeed
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
                if part:IsA("BasePart") then part.CanCollide = false end
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
                            local pos = desc.PrimaryPart and desc.PrimaryPart.Position or desc.Position
                            local dist = (hrp.Position - pos).Magnitude
                            if dist < minDist then
                                minDist = dist
                                closest = desc
                            end
                        end
                    end
                end
            end
            if closest and minDist < 100 then
                local pos = closest.PrimaryPart and closest.PrimaryPart.Position or closest.Position
                hrp.CFrame = CFrame.new(pos) * CFrame.new(0, 0, -5)
                task.wait(0.1)
                StealRemote:FireServer(closest)
            end
        end)
    else
        if autoStealConn then autoStealConn:Disconnect() end
    end
end

-- Input for Fly
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local code = input.KeyCode
        if code == Enum.KeyCode.W then keys.w = true
        elseif code == Enum.KeyCode.A then keys.a = true
        elseif code == Enum.KeyCode.S then keys.s = true
        elseif code == Enum.KeyCode.D then keys.d = true
        elseif code == Enum.KeyCode.Q then keys.q = true
        elseif code == Enum.KeyCode.E then keys.e = true end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local code = input.KeyCode
        if code == Enum.KeyCode.W then keys.w = false
        elseif code == Enum.KeyCode.A then keys.a = false
        elseif code == Enum.KeyCode.S then keys.s = false
        elseif code == Enum.KeyCode.D then keys.d = false
        elseif code == Enum.KeyCode.Q then keys.q = false
        elseif code == Enum.KeyCode.E then keys.e = false end
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(plr)
    if plr == player then
        stopFly()
        toggleNoclip(false)
        toggleAutoSteal(false)
    end
end)

print("🧠 Simple Brainrot Stealer loaded! GUI should appear. Use buttons for features.")
