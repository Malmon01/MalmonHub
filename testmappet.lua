
-- Candy Collector V7
-- Tween Movement / Home / Start / Stop
-- Roblox Studio LocalScript

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

-- SETTINGS
local MOVE_SPEED = 1000000000
local MAX_ATTEMPTS = 2
local HOLD_EXTRA = 0.15
local ARRIVAL_DISTANCE = 3
local COLLECT_WAIT = 1.2

-- HOME CHECKPOINT
local HOME = root.CFrame

local running = false
local runId = 0
local currentTween = nil
local visiblePrompts = {}
local confirmed = 0

PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

-- REMOVE OLD UI
local old = pg:FindFirstChild("CandyTweenV7")
if old then old:Destroy() end

-- CREATE UI
local gui = Instance.new("ScreenGui")
gui.Name = "CandyTweenV7"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 205)
frame.Position = UDim2.new(0.5, -130, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function button(name, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 45)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Text = name
    b.Parent = frame

    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local homeBtn = button("HOME", 12, Color3.fromRGB(45, 110, 220))
local startBtn = button("START COLLECT", 65, Color3.fromRGB(30, 175, 90))

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 70)
status.Position = UDim2.fromOffset(10, 125)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.TextSize = 13
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(msg)
    status.Text = msg
    print("[CANDY V7]", msg)
end

local function getRoot()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function active(id)
    return running and runId == id
end

local function cancelTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

-- TWEEN MOVEMENT
local function moveTo(position, id)
    local hrp = getRoot()
    if not hrp then return false end

    if id and not active(id) then
        return false
    end

    cancelTween()

    local distance = (hrp.Position - position).Magnitude

    if distance < 0.3 then
        return true
    end

    -- Duration based on travel distance
    local duration = distance / MOVE_SPEED

    local direction = position - hrp.Position
    local facing = hrp.CFrame.LookVector

    if direction.Magnitude > 0.1 then
        local flat = Vector3.new(direction.X, 0, direction.Z)
        if flat.Magnitude > 0.01 then
            facing = flat.Unit
        end
    end

    local targetCF = CFrame.lookAt(
        position,
        position + facing
    )

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut
        ),
        {CFrame = targetCF}
    )

    currentTween = tween
    tween:Play()

    local playbackState = tween.Completed:Wait()

    if currentTween == tween then
        currentTween = nil
    end

    if id and not active(id) then
        return false
    end

    return playbackState == Enum.PlaybackState.Completed
end

local function returnHome(id)
    setStatus("MOVING HOME...")
    return moveTo(HOME.Position, id)
end

-- CANDIES FROM FOLDER
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

local function promptPosition(prompt)
    local parent = prompt.Parent
    if not parent then return nil end

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end

    if parent:IsA("BasePart") then
        return parent.Position
    end

    return nil
end

local function findPrompt(candy)
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    local closest = nil
    local bestDistance = math.huge

    for prompt in pairs(visiblePrompts) do
        if prompt.Parent and prompt.Enabled then
            local pos = promptPosition(prompt)

            if pos then
                local distance = (pos - candy.Position).Magnitude

                if distance < bestDistance and distance <= 5 then
                    bestDistance = distance
                    closest = prompt
                end
            end
        end
    end

    return closest
end

local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    setStatus("MOVING TO\n" .. candy.Name)

    local target = candy.Position + Vector3.new(
        0, ARRIVAL_DISTANCE, 0
    )

    if not moveTo(target, id) then
        return "cancelled"
    end

    if not active(id) then
        return "cancelled"
    end

    task.wait(0.3)

    -- FIND E PROMPT
    local prompt = nil
    local deadline = os.clock() + 2.5

    while os.clock() < deadline do
        if not active(id) then
            return "cancelled"
        end

        prompt = findPrompt(candy)

        if prompt then
            break
        end

        task.wait(0.05)
    end

    if not prompt then
        setStatus("NO E PROMPT\n" .. candy.Name)
        return "no_prompt"
    end

    -- HOLD E
    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    setStatus("HOLDING E\n" .. candy.Name)

    local duration = math.max(0, prompt.HoldDuration)
    local holdStart = os.clock()

    prompt:InputHoldBegin()

    while os.clock() - holdStart < duration + HOLD_EXTRA do
        if not active(id) then
            prompt:InputHoldEnd()
            connection:Disconnect()
            return "cancelled"
        end

        task.wait(0.03)
    end

    prompt:InputHoldEnd()

    local deadline2 = os.clock() + COLLECT_WAIT

    while os.clock() < deadline2 do
        if not active(id) then
            connection:Disconnect()
            return "cancelled"
        end

        if not candy:IsDescendantOf(folder) then
            connection:Disconnect()
            return "removed"
        end

        task.wait(0.05)
    end

    connection:Disconnect()

    if triggered then
        return "triggered"
    end

    return "failed"
end

local function stop()
    running = false
    runId += 1
    cancelTween()

    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(30, 175, 90)
end

-- HOME BUTTON
homeBtn.MouseButton1Click:Connect(function()
    stop()

    task.spawn(function()
        returnHome()
        setStatus("RETURNED HOME")
    end)
end)

-- START / STOP
startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    cancelTween()
    running = true
    runId += 1

    local id = runId
    local attempts = {}

    confirmed = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        local round = 0

        while active(id) do
            round += 1

            local candies = getCandies()
            local attemptedThisRound = 0

            if #candies == 0 then
                setStatus("ALL CANDY OBJECTS REMOVED")
                break
            end

            for _, candy in ipairs(candies) do
                if not active(id) then
                    break
                end

                if (attempts[candy] or 0) < MAX_ATTEMPTS then
                    attempts[candy] = (attempts[candy] or 0) + 1
                    attemptedThisRound += 1

                    local result = collectCandy(candy, id)

                    if not active(id) then
                        break
                    end

                    if result == "removed" then
                        confirmed += 1
                        setStatus("CANDY REMOVED: " .. confirmed)
                    elseif result == "triggered" then
                        setStatus("E TRIGGERED | NOT CONFIRMED")
                    else
                        setStatus("COLLECT: " .. result)
                    end

                    -- Move back to Home after each candy
                    if not returnHome(id) then
                        break
                    end

                    task.wait(0.25)
                end
            end

            if not active(id) then
                break
            end

            if #getCandies() == 0 then
                setStatus("FINISHED | REMOVED: " .. confirmed)
                break
            end

            if attemptedThisRound == 0 then
                setStatus(
                    "TEST COMPLETE\n"
                    .. "Removed: " .. confirmed
                    .. " | Remaining: " .. #getCandies()
                )
                break
            end

            task.wait(0.4)
        end

        if active(id) then
            stop()
        end
    end)
end)

setStatus(
    "READY | HOME SAVED\n"
    .. "Candy: " .. #getCandies()
)
