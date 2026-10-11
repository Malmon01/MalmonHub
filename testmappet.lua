
--========================================
-- CANDY COLLECTOR V10
-- TELEPORT + HOLD E + HOME DELIVERY
-- WAIT AT HOME: 8 SECONDS
-- SINGLE LOCALSCRIPT
--========================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- SETTINGS
local HOME_WAIT = 8
local PROMPT_TIMEOUT = 2
local HOLD_EXTRA = 0.2
local ARRIVAL_HEIGHT = 2
local HOME_TOLERANCE = 6

-- SAVE HOME ON SCRIPT START
local HOME = character:GetPivot()

local running = false
local runId = 0
local currentPrompt = nil
local visiblePrompts = {}
local visited = {}
local total = 0

-- PROMPT DETECTION
PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

-- UI
local old = pg:FindFirstChild("CandyV10")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV10"
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

local function makeButton(text, y, color)
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

local homeBtn = makeButton(
    "HOME", 12, Color3.fromRGB(45, 110, 220)
)

local startBtn = makeButton(
    "START COLLECT", 72, Color3.fromRGB(30, 175, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 95)
status.Position = UDim2.fromOffset(10, 132)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 14
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(msg)
    status.Text = msg
    print("[CANDY V10]", msg)
end

local function getRoot()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf)
    local c = player.Character
    if not c then return false end

    c:PivotTo(cf)

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
    local list = {}

    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name:match("^Candy_")
            and obj:IsA("BasePart") then
            table.insert(list, obj)
        end
    end

    return list
end

local function getPromptPosition(prompt)
    local p = prompt.Parent
    if not p then return nil end

    if p:IsA("Attachment") then
        return p.WorldPosition
    end

    if p:IsA("BasePart") then
        return p.Position
    end

    if p:IsA("Model") then
        return p:GetPivot().Position
    end

    return nil
end

-- FIND E PROMPT NEAR CANDY
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

            local pos = getPromptPosition(prompt)

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

-- COLLECT CANDY
local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return true
    end

    setStatus("TELEPORTING TO\n" .. candy.Name)

    teleport(CFrame.new(
        candy.Position + Vector3.new(
            0, ARRIVAL_HEIGHT, 0
        )
    ))

    if not waitActive(0.3, id) then
        return false
    end

    -- WAIT FOR E PROMPT
    local prompt = nil
    local deadline = os.clock() + PROMPT_TIMEOUT

    while os.clock() < deadline do
        if not active(id) then
            return false
        end

        prompt = findPrompt(candy)

        if prompt then
            break
        end

        task.wait(0.05)
    end

    if not prompt then
        setStatus("NO E PROMPT\n" .. candy.Name)
        return false
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
        .. "\n"
        .. string.format("%.2f", holdTime)
        .. " seconds"
    )

    prompt:InputHoldBegin()

    local completed = waitActive(holdTime, id)

    prompt:InputHoldEnd()
    currentPrompt = nil

    if not completed then
        connection:Disconnect()
        return false
    end

    -- WAIT BRIEFLY FOR THE TRIGGER EVENT
    local confirmDeadline = os.clock() + 0.6

    while os.clock() < confirmDeadline do
        if not active(id) then
            connection:Disconnect()
            return false
        end

        if triggered or not candy:IsDescendantOf(folder) then
            break
        end

        task.wait(0.05)
    end

    connection:Disconnect()

    return triggered or not candy:IsDescendantOf(folder)
end

-- GO HOME AND WAIT 8 SECONDS
local function deliverAtHome(id)
    if not active(id) then
        return false
    end

    setStatus("TELEPORTING HOME...")

    if not teleport(HOME) then
        return false
    end

    -- Allow character position to update
    if not waitActive(0.25, id) then
        return false
    end

    local r = getRoot()

    if not r then
        setStatus("HOME ERROR: NO CHARACTER")
        return false
    end

    -- Verify player arrived at Home
    local distance = (r.Position - HOME.Position).Magnitude

    if distance > HOME_TOLERANCE then
        setStatus("HOME POSITION NOT CONFIRMED")
        return false
    end

    -- Wait on the delivery pad
    local startTime = os.clock()

    while active(id) do
        local elapsed = os.clock() - startTime
        local remaining = HOME_WAIT - elapsed

        if remaining <= 0 then
            break
        end

        -- Make sure character stays near Home
        local hrp = getRoot()

        if not hrp or
            (hrp.Position - HOME.Position).Magnitude
                > HOME_TOLERANCE then
            setStatus("LEFT HOME PAD - STOPPED")
            return false
        end

        setStatus(
            "HOME DELIVERY\n"
            .. "Waiting: "
            .. math.ceil(remaining)
            .. " seconds\n"
            .. "Attempted: " .. total
        )

        task.wait(0.1)
    end

    if not active(id) then
        return false
    end

    setStatus("HOME WAIT COMPLETE | 8s")
    return true
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

-- START / STOP
startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    running = true
    runId += 1

    local id = runId

    visited = {}
    total = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(210, 55, 65)

    task.spawn(function()
        while active(id) do
            local candies = getCandies()
            local target = nil

            -- Find next unvisited candy
            for _, candy in ipairs(candies) do
                if not visited[candy] then
                    target = candy
                    break
                end
            end

            if not target then
                if #candies == 0 then
                    setStatus("ALL CANDY OBJECTS REMOVED")
                else
                    setStatus(
                        "ROUND COMPLETE\n"
                        .. "Attempted: " .. total
                        .. "\nRemaining objects: "
                        .. #candies
                    )
                end
                break
            end

            -- Mark candy as visited
            visited[target] = true

            local success = collectCandy(target, id)

            if not active(id) then
                break
            end

            -- Do not skip to another candy
            -- when the interaction fails
            if not success then
                setStatus(
                    "E NOT CONFIRMED\n"
                    .. target.Name
                    .. "\nReturning HOME"
                )

                teleport(HOME)
                break
            end

            total += 1

            -- IMPORTANT:
            -- Go HOME before starting the 8s timer
            if not deliverAtHome(id) then
                break
            end

            -- Only now proceed to next candy
            if not waitActive(0.2, id) then
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
    .. "\nHOME WAIT: 8 SECONDS"
)
