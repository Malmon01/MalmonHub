
--====================================
-- CANDY COLLECTOR V9
-- TELEPORT + HOLD E + WAIT 5 SECONDS
-- SINGLE LOCALSCRIPT
--====================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local playerGui = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- SETTINGS
local WAIT_BEFORE_HOME = 5
local PROMPT_TIMEOUT = 2
local HOLD_EXTRA = 0.2
local MAX_ATTEMPTS = 2
local ARRIVAL_HEIGHT = 2

-- SAVE HOME ON FIRST RUN
local HOME = character:GetPivot()

local running = false
local generation = 0
local visiblePrompts = {}
local currentPrompt = nil

PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

-- REMOVE OLD UI
local old = playerGui:FindFirstChild("CandyV9")
if old then old:Destroy() end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "CandyV9"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 230)
frame.Position = UDim2.new(0.5, -140, 0.35, 0)
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
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Text = text
    b.Parent = frame

    Instance.new("UICorner", b).CornerRadius =
        UDim.new(0, 9)

    return b
end

local homeBtn = makeButton(
    "HOME", 12, Color3.fromRGB(45, 110, 220)
)

local startBtn = makeButton(
    "START COLLECT", 65, Color3.fromRGB(30, 175, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 95)
status.Position = UDim2.fromOffset(10, 125)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(message)
    status.Text = message
    print("[CANDY V9]", message)
end

-- TELEPORT
local function teleport(cf)
    local char = player.Character
    if not char then return false end

    char:PivotTo(cf)

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    return true
end

local function active(id)
    return running and generation == id
end

-- FIND CANDIES
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
    elseif parent:IsA("BasePart") then
        return parent.Position
    elseif parent:IsA("Model") then
        return parent:GetPivot().Position
    end

    return nil
end

-- FIND NEARBY E PROMPT
local function findPrompt(candy)
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    local best = nil
    local bestDistance = math.huge

    for prompt in pairs(visiblePrompts) do
        if prompt.Parent
            and prompt.Enabled
            and prompt.KeyboardKeyCode == Enum.KeyCode.E then

            local pos = promptPosition(prompt)

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

-- INTERRUPTIBLE DELAY
local function waitActive(seconds, id)
    local deadline = os.clock() + seconds

    while os.clock() < deadline do
        if not active(id) then
            return false
        end

        task.wait(0.05)
    end

    return active(id)
end

-- COLLECT ONE CANDY
local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    -- TELEPORT DIRECTLY TO CANDY
    setStatus("TELEPORTING\n" .. candy.Name)

    teleport(CFrame.new(
        candy.Position + Vector3.new(
            0, ARRIVAL_HEIGHT, 0
        )
    ))

    if not waitActive(0.3, id) then
        return "cancelled"
    end

    -- FIND PROMPT
    local prompt = nil
    local deadline = os.clock() + PROMPT_TIMEOUT

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

    currentPrompt = prompt

    local holdTime =
        math.max(0, prompt.HoldDuration) + HOLD_EXTRA

    setStatus(
        "HOLDING E\n"
        .. candy.Name
        .. "\nDuration: "
        .. string.format("%.2f", holdTime)
        .. "s"
    )

    prompt:InputHoldBegin()

    local completed = waitActive(holdTime, id)

    prompt:InputHoldEnd()
    currentPrompt = nil

    if not completed then
        connection:Disconnect()
        return "cancelled"
    end

    -- WAIT 5 SECONDS AT CANDY
    local waitStart = os.clock()

    while os.clock() - waitStart < WAIT_BEFORE_HOME do
        if not active(id) then
            connection:Disconnect()
            return "cancelled"
        end

        local remaining = math.max(
            0,
            math.ceil(
                WAIT_BEFORE_HOME -
                (os.clock() - waitStart)
            )
        )

        setStatus(
            "WAITING BEFORE HOME\n"
            .. candy.Name
            .. "\n" .. remaining .. " seconds"
        )

        task.wait(0.1)
    end

    connection:Disconnect()

    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    if triggered then
        return "triggered"
    end

    return "failed"
end

-- STOP
local function stop()
    running = false
    generation += 1

    if currentPrompt then
        currentPrompt:InputHoldEnd()
        currentPrompt = nil
    end

    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(30, 175, 90)
end

-- HOME BUTTON
homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    setStatus("RETURNED HOME")
end)

-- START / STOP BUTTON
startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    running = true
    generation += 1

    local id = generation
    local attempts = {}
    local round = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        while active(id) do
            round += 1

            local candies = getCandies()
            local attempted = 0

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED")
                break
            end

            for _, candy in ipairs(candies) do
                if not active(id) then
                    break
                end

                if (attempts[candy] or 0) < MAX_ATTEMPTS then
                    attempts[candy] =
                        (attempts[candy] or 0) + 1

                    attempted += 1

                    setStatus(
                        "ROUND: " .. round
                        .. "\nTARGET: " .. candy.Name
                    )

                    local result = collectCandy(candy, id)

                    if not active(id) then
                        break
                    end

                    setStatus(
                        "RESULT: " .. result
                        .. "\nRETURNING HOME"
                    )

                    -- TELEPORT HOME AFTER 5s WAIT
                    teleport(HOME)

                    if not waitActive(0.2, id) then
                        break
                    end
                end
            end

            if not active(id) then
                break
            end

            if #getCandies() == 0 then
                setStatus("FINISHED | ALL REMOVED")
                break
            end

            if attempted == 0 then
                setStatus(
                    "TEST COMPLETE\n"
                    .. "Remaining: " .. #getCandies()
                )
                break
            end

            task.wait(0.3)
        end

        if active(id) then
            teleport(HOME)
            stop()
        end
    end)
end)

setStatus(
    "READY | HOME SAVED\n"
    .. "CANDIES FOUND: " .. #getCandies()
    .. "\nWAIT BEFORE HOME: 5s"
)
