
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local candyFolder = workspace:WaitForChild("HalloweenCandy")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- บันทึก Home ตอนเริ่มรัน
local homeCFrame = root.CFrame
local collecting = false
local runId = 0

-- สร้าง UI
local gui = Instance.new("ScreenGui")
gui.Name = "CandyCollectorUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 165)
frame.Position = UDim2.new(0.5, -110, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeButton(text, y, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 40)
    button.Position = UDim2.fromOffset(10, y)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 17
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    return button
end

local homeBtn = makeButton("HOME", 12, Color3.fromRGB(50, 120, 220))
local collectBtn = makeButton("START COLLECT", 60, Color3.fromRGB(40, 170, 90))

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 35)
status.Position = UDim2.fromOffset(10, 110)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 13
status.Text = "Ready | Home Saved"
status.Parent = frame

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf)
    local hrp = getRoot()
    if hrp then
        hrp.CFrame = cf
    end
end

local function getCandyPart(candy)
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return candy.PrimaryPart
            or candy:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function stopCollect()
    collecting = false
    runId += 1
    collectBtn.Text = "START COLLECT"
    collectBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
end

homeBtn.MouseButton1Click:Connect(function()
    stopCollect()
    teleport(homeCFrame)
    status.Text = "Returned Home"
end)

collectBtn.MouseButton1Click:Connect(function()
    if collecting then
        stopCollect()
        status.Text = "Stopped"
        return
    end

    collecting = true
    runId += 1
    local currentRun = runId

    collectBtn.Text = "STOP COLLECT"
    collectBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)

    task.spawn(function()
        local candies = candyFolder:GetDescendants()
        local count = 0

        for _, candy in ipairs(candies) do
            if not collecting or currentRun ~= runId then
                break
            end

            if candy.Name:match("^Candy_") then
                local part = getCandyPart(candy)

                if part then
                    teleport(part.CFrame)
                    count += 1
                    status.Text = "Visiting Candy: " .. count

                    task.wait(0.35)
                end
            end
        end

        if currentRun == runId then
            stopCollect()
            status.Text = "Finished! Visited: " .. count
        end
    end)
end)
