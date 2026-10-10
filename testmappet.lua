
-- Candy Collector V4
-- Teleport + Interaction Diagnostics

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local playerGui = player:WaitForChild("PlayerGui")

local root = (player.Character or player.CharacterAdded:Wait())
    :WaitForChild("HumanoidRootPart")

local HOME = root.CFrame
local running = false
local runId = 0

local old = playerGui:FindFirstChild("CandyV4")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV4"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(270, 210)
frame.Position = UDim2.new(0.5, -135, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeButton(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 45)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local homeBtn = makeButton(
    "HOME", 12, Color3.fromRGB(45, 110, 220)
)

local startBtn = makeButton(
    "START COLLECT", 65, Color3.fromRGB(35, 175, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 75)
status.Position = UDim2.fromOffset(10, 120)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.TextSize = 13
status.Text = "Ready | Home Saved"
status.Parent = frame

local function teleport(cf)
    local char = player.Character
    if char then
        char:PivotTo(cf)
    end
end

local function getCandyPart(obj)
    if obj:IsA("BasePart") then
        return obj
    end

    if obj:IsA("Model") then
        return obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function getCandies()
    local list = {}

    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name:match("^Candy_") then
            local part = getCandyPart(obj)

            if part then
                table.insert(list, {
                    object = obj,
                    part = part
                })
            end
        end
    end

    return list
end

local function stop()
    running = false
    runId += 1
    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(35, 175, 90)
end

local function inspectCandy(info)
    local candy = info.object

    local prompt = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if prompt then
        print("Candy:", candy.Name)
        print("Prompt:", prompt:GetFullName())
        print("HoldDuration:", prompt.HoldDuration)
        print("Enabled:", prompt.Enabled)
        return prompt
    end

    print("Candy:", candy.Name)
    print("No ProximityPrompt inside candy")
    return nil
end

homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    status.Text = "Returned Home"
end)

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        status.Text = "Stopped"
        return
    end

    running = true
    runId += 1
    local id = runId

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        local candies = getCandies()

        status.Text = "Found candies: " .. #candies
        print("Found candies:", #candies)

        if #candies == 0 then
            status.Text = "No Candy Parts found"
        end

        for i, info in ipairs(candies) do
            if not running or id ~= runId then
                break
            end

            if info.object:IsDescendantOf(folder) then
                local part = info.part

                status.Text = "Teleporting: "
                    .. i .. "/" .. #candies

                teleport(
                    part.CFrame * CFrame.new(0, 3, 0)
                )

                task.wait(0.6)

                local prompt = inspectCandy(info)

                if prompt and prompt.Enabled then
                    status.Text = "Holding E: " .. info.object.Name

                    local holdTime = prompt.HoldDuration
                    prompt:InputHoldBegin()

                    local elapsed = 0

                    while elapsed < holdTime + 0.2 do
                        if not running or id ~= runId then
                            break
                        end
                        elapsed += task.wait(0.05)
                    end

                    prompt:InputHoldEnd()
                else
                    status.Text = "No E prompt: "
                        .. info.object.Name
                end

                task.wait(0.4)
            end
        end

        if running and id == runId then
            teleport(HOME)
            status.Text = "Test complete | Returned Home"
            stop()
        end
    end)
end)
