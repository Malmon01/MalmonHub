
--========================================
-- SMART CANDY COLLECTOR V15
-- FAST SCAN: 0.20 SECONDS
-- HOLD E -> WAIT 7s -> HOME
-- PRIORITY FARMING
-- SINGLE LOCALSCRIPT
--========================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local character = player.Character
    or player.CharacterAdded:Wait()

character:WaitForChild("HumanoidRootPart")

-- SETTINGS
local SCAN_WAIT = 0.20
local WAIT_AFTER_E = 7
local PROMPT_TIMEOUT = 3
local HOLD_EXTRA = 0.2
local HOME_PAUSE = 0.4
local ROUND_PAUSE = 1
local E_RETRIES = 2
local ARRIVAL_HEIGHT = 2

-- PRIORITY
local PRIORITY = {
    Unknown = 5,
    Legendary = 4,
    Epic = 3,
    Rare = 2,
    Common = 1
}

local HOME = character:GetPivot()

local running = false
local runId = 0
local currentPrompt = nil

local visiblePrompts = {}
local rarityMap = {}
local scanned = {}
local attempts = {}

local round = 0
local collected = 0

--========================================
-- PROMPT TRACKING
--========================================

PPS.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
end)

--========================================
-- UI
--========================================

local old = pg:FindFirstChild("CandyV15")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV15"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(290, 255)
frame.Position = UDim2.new(0.5, -145, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 36)
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
status.Size = UDim2.new(1, -20, 0, 110)
status.Position = UDim2.fromOffset(10, 135)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "V15 READY"
status.Parent = frame

local function setStatus(message)
    status.Text = message
    print("[CANDY V15]", message)
end

--========================================
-- MOVEMENT
--========================================

local function teleport(cf)
    local char = player.Character
    if not char then return false end

    char:PivotTo(cf)

    local root = char:FindFirstChild("HumanoidRootPart")

    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
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

        task.wait(0.03)
    end

    return active(id)
end

--========================================
-- FIND CANDIES
--========================================

local function getPart(candy)
    if candy:IsA("BasePart") then
        return candy
    end

    if candy:IsA("Model") then
        return candy.PrimaryPart
            or candy:FindFirstChildWhichIsA(
                "BasePart", true
            )
    end

    return nil
end

local function getCandies()
    local result = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and getPart(candy) then

            table.insert(result, candy)
        end
    end

    return result
end

--========================================
-- RARITY DETECTION
--========================================

local function readRarity(value)
    if value == nil then return nil end

    local s = string.lower(tostring(value))

    if s:find("legendary", 1, true) then
        return "Legendary"
    elseif s:find("epic", 1, true) then
        return "Epic"
    elseif s:find("rare", 1, true) then
        return "Rare"
    elseif s:find("common", 1, true) then
        return "Common"
    end

    return nil
end

local function readObjectRarity(candy)
    local objects = {candy}

    for _, obj in ipairs(candy:GetDescendants()) do
        table.insert(objects, obj)
    end

    for _, obj in ipairs(objects) do

        -- Attributes
        for key, value in pairs(obj:GetAttributes()) do
            local rarity = readRarity(value)

            if rarity then return rarity end

            if value == true then
                rarity = readRarity(key)
                if rarity then return rarity end
            end
        end

        -- StringValue
        if obj:IsA("StringValue") then
            local rarity = readRarity(obj.Value)
            if rarity then return rarity end
        end

        -- ProximityPrompt
        if obj:IsA("ProximityPrompt") then
            local rarity = readRarity(
                obj.ObjectText .. " " .. obj.ActionText
            )

            if rarity then return rarity end
        end

        -- TextLabels attached to candy
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local rarity = readRarity(obj.Text)

            if rarity then return rarity end
        end
    end

    return nil
end

--========================================
-- FIND E PROMPT
--========================================

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

local function findPrompt(candy)
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    local part = getPart(candy)
    if not part then return nil end

    local best = nil
    local nearest = math.huge

    for prompt in pairs(visiblePrompts) do
        if prompt.Parent
            and prompt.Enabled
            and prompt.KeyboardKeyCode == Enum.KeyCode.E then

            local pos = promptPosition(prompt)

            if pos then
                local distance =
                    (pos - part.Position).Magnitude

                if distance <= 6
                    and distance < nearest then

                    best = prompt
                    nearest = distance
                end
            end
        end
    end

    return best
end

--========================================
-- READ NEARBY PICKUP GUI
--========================================

local function readNearbyGUI(candy)
    local part = getPart(candy)
    local camera = workspace.CurrentCamera

    if not part or not camera then
        return nil
    end

    local screenPos, onScreen =
        camera:WorldToViewportPoint(part.Position)

    if not onScreen then
        return nil
    end

    local nearest = math.huge
    local result = nil

    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel")
            or obj:IsA("TextButton"))
            and obj.Visible
            and not obj:IsDescendantOf(gui) then

            local rarity = readRarity(obj.Text)

            if rarity then
                local center =
                    obj.AbsolutePosition
                    + obj.AbsoluteSize / 2

                local distance = (
                    center - Vector2.new(
                        screenPos.X, screenPos.Y
                    )
                ).Magnitude

                if distance < 160
                    and distance < nearest then

                    result = rarity
                    nearest = distance
                end
            end
        end
    end

    return result
end

local function updateRarity(candy, prompt)
    local rarity = readObjectRarity(candy)

    if not rarity and prompt then
        rarity = readRarity(
            prompt.ObjectText .. " " .. prompt.ActionText
        )
    end

    if not rarity then
        rarity = readNearbyGUI(candy)
    end

    if rarity then
        rarityMap[candy] = rarity
    end

    return rarityMap[candy] or "Unknown"
end

--========================================
-- FAST SCAN 0.20s
--========================================

local function scanNewCandies(id)
    local candies = getCandies()
    local count = #candies

    for i, candy in ipairs(candies) do
        if not active(id) then
            return false
        end

        if not scanned[candy] then
            local part = getPart(candy)

            if part then
                local rarity = readObjectRarity(candy)

                if not rarity then
                    setStatus(
                        "FAST SCANNING"
                        .. "\n" .. i .. "/" .. count
                        .. "\nSCAN WAIT: 0.20s"
                    )

                    teleport(CFrame.new(
                        part.Position
                        + Vector3.new(0, 2, 0)
                    ))

                    if not waitActive(SCAN_WAIT, id) then
                        return false
                    end

                    local prompt = findPrompt(candy)
                    rarity = updateRarity(candy, prompt)
                end

                rarityMap[candy] = rarity or "Unknown"
                scanned[candy] = true

                print(
                    "[V15 SCAN]",
                    candy.Name,
                    rarityMap[candy]
                )
            end
        end
    end

    if not active(id) then
        return false
    end

    teleport(HOME)
    return waitActive(0.1, id)
end

--========================================
-- SORT BY RARITY
--========================================

local function getSortedCandies()
    local candies = getCandies()

    table.sort(candies, function(a, b)
        local ra = rarityMap[a] or "Unknown"
        local rb = rarityMap[b] or "Unknown"

        local pa = PRIORITY[ra] or 5
        local pb = PRIORITY[rb] or 5

        if pa ~= pb then
            return pa > pb
        end

        local partA = getPart(a)
        local partB = getPart(b)

        if partA and partB then
            local da =
                (partA.Position - HOME.Position).Magnitude

            local db =
                (partB.Position - HOME.Position).Magnitude

            if math.abs(da - db) > 0.01 then
                return da < db
            end
        end

        return a.Name < b.Name
    end)

    return candies
end

--========================================
-- HOLD E
--========================================

local function holdCandyE(candy, id)
    local prompt = nil
    local deadline = os.clock() + PROMPT_TIMEOUT

    while os.clock() < deadline do
        if not active(id) then
            return false, "cancelled"
        end

        prompt = findPrompt(candy)

        if prompt then break end
        task.wait(0.03)
    end

    if not prompt then
        return false, "no_prompt"
    end

    local rarity = updateRarity(candy, prompt)

    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    currentPrompt = prompt

    local holdTime =
        math.max(0, prompt.HoldDuration) + HOLD_EXTRA

    setStatus(
        "HOLDING E"
        .. "\nRARITY: " .. rarity
        .. "\nDURATION: "
        .. string.format("%.2f", holdTime)
    )

    prompt:InputHoldBegin()

    local completed = waitActive(holdTime, id)

    prompt:InputHoldEnd()
    currentPrompt = nil

    if not completed then
        connection:Disconnect()
        return false, "cancelled"
    end

    local deadline2 = os.clock() + 0.6

    while not triggered
        and candy:IsDescendantOf(folder)
        and os.clock() < deadline2 do

        if not active(id) then
            connection:Disconnect()
            return false, "cancelled"
        end

        task.wait(0.03)
    end

    connection:Disconnect()

    if triggered then
        return true, "triggered"
    end

    if not candy:IsDescendantOf(folder) then
        return true, "removed"
    end

    return false, "e_not_triggered"
end

--========================================
-- COLLECT CANDY
--========================================

local function collectCandy(candy, id)
    local part = getPart(candy)

    if not part then
        return false, "invalid"
    end

    if not candy:IsDescendantOf(folder) then
        return true, "already_removed"
    end

    local rarity = rarityMap[candy] or "Unknown"

    setStatus(
        "TELEPORT TO CANDY"
        .. "\nRARITY: " .. rarity
    )

    teleport(CFrame.new(
        part.Position
        + Vector3.new(0, ARRIVAL_HEIGHT, 0)
    ))

    if not waitActive(0.3, id) then
        return false, "cancelled"
    end

    -- IMPORTANT:
    -- No reprioritize skip.
    -- Always attempt E on selected candy.

    local success = false
    local result = "not_attempted"

    for attempt = 1, E_RETRIES do
        if not active(id) then
            return false, "cancelled"
        end

        success, result = holdCandyE(candy, id)

        if success then
            break
        end

        if attempt < E_RETRIES then
            setStatus(
                "RETRY E"
                .. "\n" .. attempt .. "/" .. E_RETRIES
                .. "\n" .. result
            )

            if not waitActive(0.3, id) then
                return false, "cancelled"
            end
        end
    end

    if not success then
        return false, result
    end

    -- WAIT 7 SECONDS AFTER E
    -- STAY AT CANDY

    local startTime = os.clock()

    while active(id) do
        local remaining =
            WAIT_AFTER_E - (os.clock() - startTime)

        if remaining <= 0 then
            break
        end

        setStatus(
            "WAITING AT CANDY"
            .. "\nRARITY: "
            .. (rarityMap[candy] or "Unknown")
            .. "\nHOME IN "
            .. math.ceil(remaining) .. "s"
        )

        task.wait(0.1)
    end

    if not active(id) then
        return false, "cancelled"
    end

    return true, result
end

--========================================
-- STOP / HOME
--========================================

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

homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    setStatus("RETURNED HOME")
end)

--========================================
-- MAIN LOOP
--========================================

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        setStatus("STOPPED")
        return
    end

    running = true
    runId += 1

    local id = runId

    collected = 0
    round = 0
    attempts = {}

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        -- Initial fast scan
        if not scanNewCandies(id) then
            return
        end

        while active(id) do
            round += 1

            -- Scan newly spawned candies
            if not scanNewCandies(id) then
                break
            end

            local candies = getSortedCandies()

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED")
                break
            end

            local target = nil

            for _, candy in ipairs(candies) do
                if (attempts[candy] or 0) < 2 then
                    target = candy
                    break
                end
            end

            if not target then
                setStatus(
                    "TEST COMPLETE"
                    .. "\nSOME CANDIES REMAIN"
                )
                break
            end

            local rarity =
                rarityMap[target] or "Unknown"

            setStatus(
                "ROUND: " .. round
                .. "\nPRIORITY: " .. rarity
                .. "\nTARGET: " .. target.Name
            )

            local success, result =
                collectCandy(target, id)

            if not active(id) then
                break
            end

            attempts[target] =
                (attempts[target] or 0) + 1

            if not success then
                setStatus(
                    "COLLECT FAILED"
                    .. "\n" .. result
                    .. "\nSTOPPED AT CANDY"
                )
                stop()
                return
            end

            if result ~= "already_removed" then
                collected += 1
            end

            -- After 7 seconds, return HOME
            setStatus(
                "RETURNING HOME"
                .. "\nE ACTIVATIONS: " .. collected
            )

            teleport(HOME)

            if not waitActive(HOME_PAUSE, id) then
                break
            end

            -- Next loop will select the
            -- highest remaining priority.
        end

        if active(id) then
            teleport(HOME)
            stop()
        end
    end)
end)

--========================================
-- READY
--========================================

setStatus(
    "V15 READY | HOME SAVED"
    .. "\nSCAN WAIT: 0.20s"
    .. "\nWAIT AFTER E: 7s"
    .. "\nCANDIES: " .. #getCandies()
)
