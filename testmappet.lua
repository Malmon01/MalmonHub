
--========================================
-- CANDY COLLECTOR V8
-- TWEEN SPEED: 1000 STUDS/SECOND
-- SINGLE LOCALSCRIPT
--========================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local playerGui = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- SETTINGS
local MOVE_SPEED = 1000
local MAX_ATTEMPTS = 2
local PROMPT_TIMEOUT = 0.8
local COLLECT_TIMEOUT = 0.6
local HOLD_EXTRA = 0.15
local ARRIVAL_OFFSET = Vector3.new(0, 2, 0)
local RETURN_DELAY = 0.05

-- SAVE HOME
local HOME = root.CFrame

local running = false
local generation = 0
local currentTween = nil
local visiblePrompts = {}

local removedCount = 0
local triggeredCount = 0

PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

--========================================
-- UI
--========================================

local old = playerGui:FindFirstChild("CandyV8")

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV8"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 230)
frame.Position = UDim2.new(0.5, -140, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local function createButton(text, y, color)
    local button = Instance.new("TextButton")

    button.Size = UDim2.new(1, -20, 0, 45)
    button.Position = UDim2.fromOffset(10, y)

    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)

    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.Text = text

    button.Parent = frame

    Instance.new("UICorner", button).CornerRadius =
        UDim.new(0, 9)

    return button
end

local homeBtn = createButton(
    "HOME",
    12,
    Color3.fromRGB(45, 110, 220)
)

local startBtn = createButton(
    "START COLLECT",
    65,
    Color3.fromRGB(30, 175, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 95)
status.Position = UDim2.fromOffset(10, 125)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 13
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.Text = "READY | SPEED 1000"
status.Parent = frame

local function setStatus(text)
    status.Text = text
    print("[CANDY V8]", text)
end

--========================================
-- MOVEMENT
--========================================

local function getRoot()
    local c = player.Character

    if not c then
        return nil
    end

    return c:FindFirstChild("HumanoidRootPart")
end

local function cancelTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function valid(id)
    return generation == id
end

local function moveTo(position, id)
    if not valid(id) then
        return false
    end

    local hrp = getRoot()

    if not hrp then
        return false
    end

    cancelTween()

    local distance = (hrp.Position - position).Magnitude

    if distance < 0.5 then
        return true
    end

    -- Speed = 1000 studs/second
    local duration = math.max(
        distance / MOVE_SPEED,
        0.01
    )

    local direction = position - hrp.Position
    local flat = Vector3.new(
        direction.X,
        0,
        direction.Z
    )

    local targetCF

    if flat.Magnitude > 0.01 then
        targetCF = CFrame.lookAt(
            position,
            position + flat.Unit
        )
    else
        targetCF = CFrame.new(position)
    end

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear
        ),
        {
            CFrame = targetCF
        }
    )

    currentTween = tween
    tween:Play()

    local result = tween.Completed:Wait()

    if currentTween == tween then
        currentTween = nil
    end

    if not valid(id) then
        return false
    end

    return result == Enum.PlaybackState.Completed
end

local function returnHome(id)
    setStatus("RETURNING HOME...")
    return moveTo(HOME.Position, id)
end

--========================================
-- FIND CANDIES
--========================================

local function getCandies()
    local candies = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and candy:IsA("BasePart") then

            table.insert(candies, candy)
        end
    end

    return candies
end

--========================================
-- FIND PROMPT
--========================================

local function getPromptPosition(prompt)
    local parent = prompt.Parent

    if not parent then
        return nil
    end

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end

    if parent:IsA("BasePart") then
        return parent.Position
    end

    if parent:IsA("Model") then
        return parent:GetPivot().Position
    end

    return nil
end

local function findPrompt(candy)
    -- Prefer a prompt inside this candy
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt",
        true
    )

    if own and own.Enabled then
        return own
    end

    -- Otherwise find a visible nearby E prompt
    local best = nil
    local bestDistance = math.huge

    for prompt in pairs(visiblePrompts) do
        if prompt.Parent
            and prompt.Enabled
            and prompt.KeyboardKeyCode == Enum.KeyCode.E then

            local pos = getPromptPosition(prompt)

            if pos then
                local distance =
                    (pos - candy.Position).Magnitude

                if distance < bestDistance
                    and distance <= 5 then

                    best = prompt
                    bestDistance = distance
                end
            end
        end
    end

    return best
end

--========================================
-- COLLECT CANDY
--========================================

local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    setStatus("MOVING TO\n" .. candy.Name)

    local target = candy.Position + ARRIVAL_OFFSET

    if not moveTo(target, id) then
        return "cancelled"
    end

    if not valid(id) or not running then
        return "cancelled"
    end

    -- Find nearby E prompt
    local prompt = nil
    local deadline = os.clock() + PROMPT_TIMEOUT

    while os.clock() < deadline do
        if not valid(id) or not running then
            return "cancelled"
        end

        prompt = findPrompt(candy)

        if prompt then
            break
        end

        task.wait(0.03)
    end

    if not prompt then
        return "no_prompt"
    end

    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    setStatus(
        "HOLDING E\n"
        .. candy.Name
        .. "\n"
        .. string.format("%.2f", prompt.HoldDuration)
        .. " seconds"
    )

    -- Start holding E interaction
    local holdTime = math.max(
        0,
        prompt.HoldDuration
    ) + HOLD_EXTRA

    prompt:InputHoldBegin()

    local startTime = os.clock()

    while os.clock() - startTime < holdTime do
        if not valid(id) or not running then
            prompt:InputHoldEnd()
            connection:Disconnect()
            return "cancelled"
        end

        task.wait(0.03)
    end

    -- Release E
    prompt:InputHoldEnd()

    -- Verify whether candy was removed
    local finishTime = os.clock() + COLLECT_TIMEOUT

    while os.clock() < finishTime do
        if not valid(id) or not running then
            connection:Disconnect()
            return "cancelled"
        end

        if not candy:IsDescendantOf(folder) then
            connection:Disconnect()
            return "removed"
        end

        task.wait(0.03)
    end

    connection:Disconnect()

    if triggered then
        return "triggered"
    end

    return "failed"
end

--========================================
-- CONTROL
--========================================

local function stop()
    running = false
    generation += 1

    cancelTween()

    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(30, 175, 90)
end

homeBtn.MouseButton1Click:Connect(function()
    stop()

    local id = generation

    task.spawn(function()
        if returnHome(id) then
            setStatus("HOME REACHED")
        end
    end)
end)

--========================================
-- AUTO COLLECT LOOP
--========================================

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    cancelTween()

    running = true
    generation += 1

    local id = generation
    local attempts = {}

    removedCount = 0
    triggeredCount = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        local round = 0

        while running and valid(id) do
            round += 1

            local candies = getCandies()
            local attempted = 0

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED!")
                break
            end

            for _, candy in ipairs(candies) do
                if not running or not valid(id) then
                    break
                end

                local count = attempts[candy] or 0

                if count < MAX_ATTEMPTS then
                    attempts[candy] = count + 1
                    attempted += 1

                    setStatus(
                        "ROUND " .. round
                        .. "\nTARGET: " .. candy.Name
                        .. "\nSPEED: 1000"
                    )

                    local result = collectCandy(candy, id)

                    if not running or not valid(id) then
                        break
                    end

                    if result == "removed" then
                        removedCount += 1

                        setStatus(
                            "CANDY REMOVED: " .. removedCount
                        )

                    elseif result == "triggered" then
                        triggeredCount += 1

                        setStatus(
                            "E TRIGGERED\n"
                            .. "ITEM NOT CONFIRMED"
                        )

                    elseif result == "no_prompt" then
                        setStatus(
                            "NO E PROMPT\n"
                            .. candy.Name
                        )

                    else
                        setStatus(
                            "FAILED: " .. result
                        )
                    end

                    -- Return HOME after each candy
                    if not returnHome(id) then
                        break
                    end

                    task.wait(RETURN_DELAY)
                end
            end

            if not running or not valid(id) then
                break
            end

            local remaining = getCandies()

            if #remaining == 0 then
                setStatus(
                    "FINISHED\nREMOVED: "
                    .. removedCount
                )
                break
            end

            if attempted == 0 then
                setStatus(
                    "TEST FINISHED\n"
                    .. "Removed: " .. removedCount
                    .. "\nRemaining: " .. #remaining
                    .. "\nE Triggered: " .. triggeredCount
                )
                break
            end

            task.wait(0.1)
        end

        if running and valid(id) then
            returnHome(id)
            stop()
        end
    end)
end)

setStatus(
    "READY | HOME SAVED\n"
    .. "SPEED: 1000 studs/s\n"
    .. "CANDIES: " .. #getCandies()
)
