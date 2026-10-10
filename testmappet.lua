
-- Candy Collector V5
-- Single LocalScript for Roblox Studio

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local playerGui = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()
local HOME = character:GetPivot()

local running = false
local generation = 0
local confirmed = 0
local activePrompts = {}

-- Track prompts shown near the player
PPS.PromptShown:Connect(function(prompt)
    activePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    activePrompts[prompt] = nil
end)

-- UI
local old = playerGui:FindFirstChild("CandyCollectorV5")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyCollectorV5"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 205)
frame.Position = UDim2.new(0.5, -130, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(27, 27, 37)
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
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Text = text
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local homeBtn = makeButton(
    "HOME", 12, Color3.fromRGB(50, 110, 220)
)

local startBtn = makeButton(
    "START COLLECT", 67, Color3.fromRGB(30, 170, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 65)
status.Position = UDim2.fromOffset(10, 125)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.TextSize = 13
status.Text = "Ready | Home saved"
status.Parent = frame

local function teleport(cf)
    local char = player.Character
    if char then
        char:PivotTo(cf)

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- Read MeshParts directly from HalloweenCandy
local function getCandies()
    local list = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and candy:IsA("BasePart") then
            table.insert(list, candy)
        end
    end

    return list
end

local function stop()
    running = false
    generation += 1
    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(30, 170, 90)
end

local function isActive(id)
    return running and id == generation
end

local function collect(candy, id)
    if not candy:IsDescendantOf(folder) then
        return true
    end

    -- Teleport close to the candy
    teleport(
        CFrame.new(candy.Position + Vector3.new(0, 2.5, 0))
    )

    status.Text = "At candy: " .. candy.Name

    -- Wait for the interaction to appear
    local deadline = os.clock() + 2.5
    local prompt = nil

    while os.clock() < deadline and isActive(id) do
        -- Prefer a prompt belonging to this candy
        local own = candy:FindFirstChildWhichIsA(
            "ProximityPrompt", true
        )

        if own and own.Enabled then
            prompt = own
            break
        end

        -- Otherwise look for a visible nearby prompt
        for candidate in pairs(activePrompts) do
            if candidate.Parent and candidate.Enabled then
                prompt = candidate
                break
            end
        end

        if prompt then break end
        task.wait(0.05)
    end

    if not isActive(id) then return false end

    if not prompt then
        status.Text = "No E interaction: " .. candy.Name
        return false
    end

    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    -- Hold the prompt interaction
    status.Text = "Holding E: " .. candy.Name

    prompt:InputHoldBegin()

    local holdStart = os.clock()
    local holdTime = math.max(prompt.HoldDuration, 0) + 0.2

    while os.clock() - holdStart < holdTime do
        if not isActive(id) then
            prompt:InputHoldEnd()
            connection:Disconnect()
            return false
        end

        task.wait(0.03)
    end

    prompt:InputHoldEnd()

    local waitUntil = os.clock() + 1

    while not triggered
        and candy:IsDescendantOf(folder)
        and os.clock() < waitUntil
        and isActive(id) do
        task.wait(0.05)
    end

    connection:Disconnect()

    return triggered or not candy:IsDescendantOf(folder)
end

homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    status.Text = "Returned HOME"
end)

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        status.Text = "Stopped"
        return
    end

    running = true
    generation += 1
    local id = generation

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        local attempted = {}

        while isActive(id) do
            local candies = getCandies()
            local nextCandy = nil

            for _, candy in ipairs(candies) do
                if not attempted[candy] then
                    nextCandy = candy
                    break
                end
            end

            if not nextCandy then
                if #candies == 0 then
                    status.Text = "All candy objects removed!"
                else
                    status.Text = "Round complete | E: " .. confirmed
                        .. " | Remaining: " .. #candies
                end
                break
            end

            attempted[nextCandy] = true

            local success = collect(nextCandy, id)

            if not isActive(id) then break end

            if success then
                confirmed += 1
                status.Text = "E triggered: " .. confirmed
            else
                status.Text = "Could not collect: "
                    .. nextCandy.Name
            end

            -- Return HOME after each candy
            teleport(HOME)
            task.wait(0.35)
        end

        if isActive(id) then
            teleport(HOME)
            stop()
        end
    end)
end)
