
--====================================
-- CANDY COLLECTOR V11
-- TELEPORT -> HOLD E -> WAIT 8S
-- -> HOME -> NEXT CANDY -> LOOP
-- SINGLE LOCALSCRIPT
--====================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

-- SETTINGS
local WAIT_AFTER_E = 8
local PROMPT_TIMEOUT = 2.5
local HOLD_EXTRA = 0.2
local ARRIVAL_HEIGHT = 2
local HOME_PAUSE = 0.5
local ROUND_PAUSE = 2

-- Save HOME when script starts
local HOME = char:GetPivot()

local running = false
local runId = 0
local currentPrompt = nil
local visiblePrompts = {}

local round = 0
local attempted = 0

-- Detect visible prompts
PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

-- UI
local old = pg:FindFirstChild("CandyV11")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV11"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 240)
frame.Position = UDim2.new(0.5, -140, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius =
    UDim.new(0, 12)

local function button(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 48)
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

local homeBtn = button(
    "HOME", 12, Color3.fromRGB(45, 110, 220)
)

local startBtn = button(
    "START COLLECT", 72, Color3.fromRGB(30, 175, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 100)
status.Position = UDim2.fromOffset(10, 132)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(msg)
    status.Text = msg
    print("[CANDY V11]", msg)
end

-- TELEPORT
local function teleport(cf)
    local character = player.Character
    if not character then return false end

    character:PivotTo(cf)

    local hrp = character:FindFirstChild("HumanoidRootPart")

    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    return true
end

local function active(id)
    return running and runId == id
end

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

-- FIND CANDIES
local function getCandies()
    local result = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and candy:IsA("BasePart") then
            table.insert(result, candy)
        end
    end

    return result
end

local function promptPosition(prompt)
    local p = prompt.Parent
    if not p then return nil end

    if p:IsA("Attachment") then
        return p.WorldPosition
    elseif p:IsA("BasePart") then
        return p.Position
    elseif p:IsA("Model") then
        return p:GetPivot().Position
    end

    return nil
end

local function findPrompt(candy)
    -- Prompt inside candy
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    -- Nearby visible E prompt
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

                if distance <= 6
                    and distance < bestDistance then

                    best = prompt
                    bestDistance = distance
                end
            end
        end
    end

    return best
end

-- COLLECT ONE CANDY
local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "already_removed"
    end

    -- 1. TELEPORT TO CANDY
    setStatus("TELEPORT TO\n" .. candy.Name)

    teleport(CFrame.new(
        candy.Position + Vector3.new(
            0, ARRIVAL_HEIGHT, 0
        )
    ))

    if not waitActive(0.3, id) then
        return "cancelled"
    end

    -- 2. FIND E PROMPT
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
        return "no_prompt"
    end

    -- 3. HOLD E
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

    -- 4. WAIT 8 SECONDS AT CANDY
    -- Do not teleport HOME yet

    local startTime = os.clock()

    while active(id) do
        local elapsed = os.clock() - startTime
        local remaining = WAIT_AFTER_E - elapsed

        if remaining <= 0 then
            break
        end

        setStatus(
            "WAITING AT CANDY\n"
            .. candy.Name
            .. "\nHOME IN "
            .. math.ceil(remaining)
            .. " SECONDS"
        )

        task.wait(0.1)
    end

    if not active(id) then
        connection:Disconnect()
        return "cancelled"
    end

    connection:Disconnect()

    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    if triggered then
        return "triggered"
    end

    return "not_confirmed"
end

-- STOP
local function stop()
    running = false
    runId += 1

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
    runId += 1

    local id = runId

    round = 0
    attempted = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        while active(id) do
            round += 1

            local candies = getCandies()

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED")
                break
            end

            setStatus(
                "ROUND: " .. round
                .. "\nCANDIES FOUND: "
                .. #candies
            )

            -- Visit every candy in this round
            for index, candy in ipairs(candies) do
                if not active(id) then
                    break
                end

                if candy:IsDescendantOf(folder) then
                    setStatus(
                        "ROUND: " .. round
                        .. "\nCANDY: "
                        .. index .. "/" .. #candies
                    )

                    local result = collectCandy(candy, id)

                    if not active(id) then
                        break
                    end

                    attempted += 1

                    setStatus(
                        "RESULT: " .. result
                        .. "\nRETURNING HOME"
                    )

                    -- 5. TELEPORT HOME AFTER
                    -- THE FULL 8-SECOND WAIT
                    teleport(HOME)

                    if not waitActive(HOME_PAUSE, id) then
                        break
                    end
                end
            end

            if not active(id) then
                break
            end

            -- 6. SCAN ALL CANDIES AGAIN
            local remaining = getCandies()

            if #remaining == 0 then
                setStatus("FINISHED | ALL REMOVED")
                break
            end

            setStatus(
                "ROUND COMPLETE: " .. round
                .. "\nREMAINING: " .. #remaining
                .. "\nRESTARTING LOOP..."
            )

            if not waitActive(ROUND_PAUSE, id) then
                break
            end
        end

        if active(id) then
            teleport(HOME)
            stop()
        end
    end)
end)

setStatus(
    "READY | HOME SAVED\n"
    .. "CANDIES: " .. #getCandies()
    .. "\nWAIT AFTER E: 8 SECONDS"
)
