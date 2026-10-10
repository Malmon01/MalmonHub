
-- CANDY COLLECTOR V6
-- SINGLE LOCALSCRIPT
-- HOME / START / STOP / DEBUG

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local HOME = root.CFrame

-- Settings
local MAX_ATTEMPTS = 2
local HOLD_EXTRA = 0.2
local COLLECT_WAIT = 1.2
local HOME_WAIT = 0.35
local TELEPORT_OFFSET = Vector3.new(0, 2, 0)

local running = false
local runId = 0
local removedCount = 0
local triggeredCount = 0

local visiblePrompts = {}

PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

-- UI
local old = pg:FindFirstChild("CandyCollectorV6")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyCollectorV6"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 230)
frame.Position = UDim2.new(0.5, -140, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 26, 36)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeButton(name, y, color)
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
status.TextSize = 13
status.TextWrapped = true
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(message)
    status.Text = message
    print("[CANDY V6]", message)
end

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf)
    local char = player.Character
    if not char then return false end

    char:PivotTo(cf)

    local r = getRoot()
    if r then
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end

    return true
end

local function active(id)
    return running and runId == id
end

local function stop()
    running = false
    runId += 1
    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(30, 175, 90)
end

-- Find candy MeshParts
local function getCandies()
    local list = {}

    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name:match("^Candy_")
            and obj:IsA("BasePart") then
            table.insert(list, obj)
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

    if parent:IsA("Model") then
        return parent:GetPivot().Position
    end

    return nil
end

-- Find prompt associated with candy
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
        if prompt.Parent and prompt.Enabled then
            local pos = promptPosition(prompt)

            if pos then
                local distance = (pos - candy.Position).Magnitude

                if distance < bestDistance
                    and distance <= 5 then
                    bestDistance = distance
                    best = prompt
                end
            end
        end
    end

    return best
end

local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    -- Teleport directly to candy
    teleport(CFrame.new(
        candy.Position + TELEPORT_OFFSET
    ))

    setStatus("TELEPORTED\n" .. candy.Name)

    task.wait(0.5)

    if not active(id) then
        return "cancelled"
    end

    -- Wait for E prompt
    local prompt = nil
    local deadline = os.clock() + 3

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

    setStatus(
        "HOLDING E\n"
        .. candy.Name
        .. "\nHold: "
        .. string.format("%.2f", prompt.HoldDuration)
        .. "s"
    )

    local triggered = false

    local conn = prompt.Triggered:Connect(function()
        triggered = true
    end)

    -- Begin holding E interaction
    prompt:InputHoldBegin()

    local holdDuration = math.max(
        0.1,
        prompt.HoldDuration + HOLD_EXTRA
    )

    local holdStart = os.clock()

    while os.clock() - holdStart < holdDuration do
        if not active(id) then
            prompt:InputHoldEnd()
            conn:Disconnect()
            return "cancelled"
        end

        task.wait(0.03)
    end

    -- Release after hold
    prompt:InputHoldEnd()

    -- Wait for confirmation
    local waitStart = os.clock()

    while os.clock() - waitStart < COLLECT_WAIT do
        if not active(id) then
            conn:Disconnect()
            return "cancelled"
        end

        if not candy:IsDescendantOf(folder) then
            conn:Disconnect()
            return "removed"
        end

        task.wait(0.05)
    end

    conn:Disconnect()

    if triggered then
        return "triggered"
    end

    return "failed"
end

homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    setStatus("RETURNED HOME")
end)

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    running = true
    runId += 1
    local id = runId

    removedCount = 0
    triggeredCount = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        local attempts = {}
        local round = 0

        while active(id) do
            round += 1

            local candies = getCandies()
            local processed = 0

            if #candies == 0 then
                setStatus("ALL CANDY OBJECTS REMOVED")
                break
            end

            for _, candy in ipairs(candies) do
                if not active(id) then
                    break
                end

                local used = attempts[candy] or 0

                if used < MAX_ATTEMPTS then
                    attempts[candy] = used + 1
                    processed += 1

                    setStatus(
                        "ROUND: " .. round
                        .. "\nCANDY: " .. candy.Name
                        .. "\nATTEMPT: " .. attempts[candy]
                    )

                    local result = collectCandy(candy, id)

                    if not active(id) then
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
                            .. "Item not confirmed"
                        )

                    elseif result == "no_prompt" then
                        setStatus(
                            "NO E PROMPT\n"
                            .. candy.Name
                        )

                    else
                        setStatus(
                            "COLLECT FAILED\n"
                            .. candy.Name
                        )
                    end

                    -- Return HOME after each attempt
                    teleport(HOME)
                    task.wait(HOME_WAIT)
                end
            end

            if not active(id) then break end

            if #getCandies() == 0 then
                setStatus(
                    "FINISHED\n"
                    .. "Removed: " .. removedCount
                )
                break
            end

            if processed == 0 then
                setStatus(
                    "TEST COMPLETE\n"
                    .. "Removed: " .. removedCount
                    .. " | E triggered: " .. triggeredCount
                    .. "\nSome candy remains"
                )
                break
            end

            task.wait(0.5)
        end

        if active(id) then
            teleport(HOME)
            stop()
        end
    end)
end)

setStatus(
    "READY | HOME SAVED\n"
    .. "Candy found: " .. #getCandies()
)
