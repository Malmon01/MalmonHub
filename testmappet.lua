
--========================================
-- SMART CANDY COLLECTOR V16
-- PRIORITY FIX + NEVER AUTO STOP
--
-- SCAN: 0.20s
-- WAIT AFTER E: 7s
--
-- UNKNOWN > LEGENDARY > EPIC
-- > RARE > UNCOMMON > COMMON
--========================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local char = player.Character or player.CharacterAdded:Wait()
char:WaitForChild("HumanoidRootPart")

-- SETTINGS
local SCAN_WAIT = 0.20
local WAIT_AFTER_E = 7
local PROMPT_TIMEOUT = 2
local HOLD_EXTRA = 0.20
local HOME_PAUSE = 0.35
local RETRY_DELAY = 5
local ARRIVAL_HEIGHT = 2

-- PRIORITY: BIGGEST FIRST
local PRIORITY = {
    Unknown = 6,
    Legendary = 5,
    Epic = 4,
    Rare = 3,
    Uncommon = 2,
    Common = 1
}

local HOME = char:GetPivot()

local running = false
local runId = 0
local currentPrompt = nil

local visiblePrompts = {}
local rarityMap = {}
local scanned = {}
local retryAt = {}

local collected = 0
local attempted = 0

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

local old = pg:FindFirstChild("CandyV16")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV16"
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
status.Size = UDim2.new(1, -20, 0, 110)
status.Position = UDim2.fromOffset(10, 135)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "V16 READY"
status.Parent = frame

local function setStatus(message)
    status.Text = message
    print("[CANDY V16]", message)
end

--========================================
-- MOVEMENT
--========================================

local function teleport(cf)
    local c = player.Character
    if not c then return false end

    c:PivotTo(cf)

    local root = c:FindFirstChild("HumanoidRootPart")

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
-- CANDY OBJECTS
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
    local list = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and getPart(candy) then
            table.insert(list, candy)
        end
    end

    return list
end

--========================================
-- RARITY READER
--========================================

local function readRarity(value)
    if value == nil then return nil end

    local s = string.lower(tostring(value))

    local function has(word)
        return s:find(
            "%f[%a]" .. word .. "%f[%A]"
        ) ~= nil
    end

    if has("legendary") then
        return "Legendary"
    elseif has("epic") then
        return "Epic"
    elseif has("rare") then
        return "Rare"
    elseif has("uncommon") then
        return "Uncommon"
    elseif has("common") then
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

        for key, value in pairs(obj:GetAttributes()) do
            local rarity = readRarity(value)

            if rarity then return rarity end

            if value == true then
                rarity = readRarity(key)
                if rarity then return rarity end
            end
        end

        if obj:IsA("StringValue") then
            local rarity = readRarity(obj.Value)
            if rarity then return rarity end
        end

        if obj:IsA("ProximityPrompt") then
            local rarity = readRarity(
                obj.ObjectText .. " " .. obj.ActionText
            )

            if rarity then return rarity end
        end

        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local rarity = readRarity(obj.Text)
            if rarity then return rarity end
        end
    end

    return nil
end

--========================================
-- PROMPT POSITION
--========================================

local function objectPosition(obj)
    if not obj then return nil end

    if obj:IsA("Attachment") then
        return obj.WorldPosition
    elseif obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        return obj:GetPivot().Position
    end

    return nil
end

local function promptPosition(prompt)
    return objectPosition(prompt.Parent)
end

-- Search nearby prompts, not only
-- prompts parented under the candy.
local function findPrompt(candy)
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    local part = getPart(candy)
    if not part then return nil end

    local root = player.Character
        and player.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not root then return nil end

    local best = nil
    local nearest = math.huge

    local function consider(prompt)
        if not prompt.Enabled then return end

        if prompt.KeyboardKeyCode ~= Enum.KeyCode.E then
            return
        end

        local pos = promptPosition(prompt)
        if not pos then return end

        local candyDistance =
            (pos - part.Position).Magnitude

        local playerDistance =
            (pos - root.Position).Magnitude

        if candyDistance <= 8
            and playerDistance <=
                prompt.MaxActivationDistance + 2
            and candyDistance < nearest then

            nearest = candyDistance
            best = prompt
        end
    end

    -- First check prompts currently shown
    for prompt in pairs(visiblePrompts) do
        if prompt.Parent then
            consider(prompt)
        end
    end

    if best then return best end

    -- Fallback: search the actual workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            consider(obj)
        end
    end

    return best
end

--========================================
-- READ VISIBLE CANDY UI
--========================================

local function readNearbyGUI(candy)
    local part = getPart(candy)
    local camera = workspace.CurrentCamera

    if not part or not camera then
        return nil
    end

    local screenPos, onScreen =
        camera:WorldToViewportPoint(part.Position)

    local result = nil
    local nearest = math.huge

    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel")
            or obj:IsA("TextButton"))
            and obj.Visible
            and not obj:IsDescendantOf(gui) then

            local rarity = readRarity(obj.Text)

            if rarity then
                local matched = false
                local distance = math.huge

                local billboard =
                    obj:FindFirstAncestorWhichIsA(
                        "BillboardGui"
                    )

                if billboard then
                    local anchor = billboard.Adornee
                        or billboard.Parent

                    local pos = objectPosition(anchor)

                    if pos then
                        distance =
                            (pos - part.Position).Magnitude

                        matched = distance <= 8
                    end
                elseif onScreen then
                    local center =
                        obj.AbsolutePosition
                        + obj.AbsoluteSize / 2

                    distance = (
                        center - Vector2.new(
                            screenPos.X,
                            screenPos.Y
                        )
                    ).Magnitude

                    matched = distance <= 180
                end

                if matched and distance < nearest then
                    nearest = distance
                    result = rarity
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
-- FAST SCANNING
--========================================

local function scanNewCandies(id)
    local candies = getCandies()
    local moved = false

    for i, candy in ipairs(candies) do
        if not active(id) then
            return false
        end

        if not scanned[candy] then
            local part = getPart(candy)

            if part then
                local rarity = readObjectRarity(candy)

                if not rarity then
                    moved = true

                    setStatus(
                        "SCANNING " .. i
                        .. "/" .. #candies
                        .. "\nWAIT: 0.20s"
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
                    "[V16 RARITY]",
                    candy.Name,
                    rarityMap[candy]
                )
            end
        end
    end

    if moved then
        teleport(HOME)
        return waitActive(0.15, id)
    end

    return active(id)
end

--========================================
-- PRIORITY SORT
--========================================

local function getSortedCandies()
    local candies = getCandies()

    table.sort(candies, function(a, b)
        local ra = rarityMap[a] or "Unknown"
        local rb = rarityMap[b] or "Unknown"

        local pa = PRIORITY[ra] or 6
        local pb = PRIORITY[rb] or 6

        -- ALWAYS PRIORITIZE RARITY
        if pa ~= pb then
            return pa > pb
        end

        -- Distance matters ONLY
        -- for candies of equal priority
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

local function findHigherPriority(candy)
    local rarity = rarityMap[candy] or "Unknown"
    local currentPriority = PRIORITY[rarity] or 6

    for _, other in ipairs(getSortedCandies()) do
        if other ~= candy
            and (retryAt[other] or 0) <= os.clock() then

            local otherRarity =
                rarityMap[other] or "Unknown"

            local otherPriority =
                PRIORITY[otherRarity] or 6

            if otherPriority > currentPriority then
                return other
            end
        end
    end

    return nil
end

--========================================
-- COLLECT CANDY
--========================================

local function collectCandy(candy, id)
    local part = getPart(candy)

    if not part then
        return "invalid"
    end

    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    local rarity = rarityMap[candy] or "Unknown"

    setStatus(
        "TARGET: " .. candy.Name
        .. "\nRARITY: " .. rarity
        .. "\nTELEPORTING..."
    )

    teleport(CFrame.new(
        part.Position
        + Vector3.new(0, ARRIVAL_HEIGHT, 0)
    ))

    if not waitActive(0.25, id) then
        return "cancelled"
    end

    local prompt = nil
    local deadline = os.clock() + PROMPT_TIMEOUT

    while os.clock() < deadline do
        if not active(id) then
            return "cancelled"
        end

        prompt = findPrompt(candy)

        if prompt then break end

        task.wait(0.05)
    end

    -- Update rarity at actual location
    rarity = updateRarity(candy, prompt)

    -- If this was Unknown but is now
    -- known to be lower rarity, choose
    -- another higher-priority target.
    local higher = findHigherPriority(candy)

    if higher then
        setStatus(
            "FOUND: " .. rarity
            .. "\nSWITCHING TO HIGHER PRIORITY"
        )

        return "switch_target"
    end

    if not prompt then
        return "no_prompt"
    end

    -- HOLD E USING PROXIMITY PROMPT
    local triggered = false

    local conn = prompt.Triggered:Connect(function()
        triggered = true
    end)

    currentPrompt = prompt

    local holdTime =
        math.max(0, prompt.HoldDuration) + HOLD_EXTRA

    setStatus(
        "HOLDING E"
        .. "\nRARITY: " .. rarity
        .. "\n" ..
        string.format("%.2f", holdTime) .. "s"
    )

    prompt:InputHoldBegin()

    local held = waitActive(holdTime, id)

    prompt:InputHoldEnd()

    if currentPrompt == prompt then
        currentPrompt = nil
    end

    if not held then
        conn:Disconnect()
        return "cancelled"
    end

    local confirmDeadline = os.clock() + 0.6

    while os.clock() < confirmDeadline do
        if not active(id) then
            conn:Disconnect()
            return "cancelled"
        end

        if triggered
            or not candy:IsDescendantOf(folder) then
            break
        end

        task.wait(0.03)
    end

    conn:Disconnect()

    if not triggered
        and candy:IsDescendantOf(folder) then
        return "unconfirmed"
    end

    -- WAIT 7 SECONDS AT CANDY
    local startTime = os.clock()

    while active(id) do
        local remaining =
            WAIT_AFTER_E - (os.clock() - startTime)

        if remaining <= 0 then
            break
        end

        setStatus(
            "CANDY: " .. rarity
            .. "\nWAITING AT CANDY"
            .. "\nHOME IN "
            .. math.ceil(remaining) .. "s"
        )

        task.wait(0.1)
    end

    if not active(id) then
        return "cancelled"
    end

    return "triggered"
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
        setStatus("STOPPED BY USER")
        return
    end

    running = true
    runId += 1

    local id = runId
    collected = 0
    attempted = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        while active(id) do

            -- Scan only new candies
            if not scanNewCandies(id) then
                break
            end

            local candies = getSortedCandies()

            -- Do not auto-stop when folder empty
            if #candies == 0 then
                setStatus(
                    "NO CANDIES"
                    .. "\nWAITING FOR RESPAWN"
                )

                if not waitActive(1, id) then
                    break
                end

                continue
            end

            local target = nil

            for _, candy in ipairs(candies) do
                if (retryAt[candy] or 0) <= os.clock() then
                    target = candy
                    break
                end
            end

            -- All targets temporarily unavailable
            if not target then
                setStatus(
                    "ALL TARGETS ON COOLDOWN"
                    .. "\nRETRYING..."
                    .. "\nE ACTIVATIONS: " .. collected
                )

                if not waitActive(0.5, id) then
                    break
                end

                continue
            end

            local rarity = rarityMap[target] or "Unknown"

            setStatus(
                "PRIORITY: " .. rarity
                .. "\nTARGET: " .. target.Name
            )

            local result = collectCandy(target, id)

            if not active(id) then
                break
            end

            -- Switch targets without stopping
            if result == "switch_target" then
                if not waitActive(0.1, id) then
                    break
                end

                continue
            end

            attempted += 1

            if result == "triggered"
                or result == "removed" then

                collected += 1

                setStatus(
                    "E ACTIVATED: " .. collected
                    .. "\nRETURNING HOME"
                )

                teleport(HOME)

                if not waitActive(HOME_PAUSE, id) then
                    break
                end

                -- Prevent immediately retrying
                -- the same object if it remains.
                retryAt[target] = os.clock() + RETRY_DELAY

            elseif result == "no_prompt" then

                retryAt[target] =
                    os.clock() + RETRY_DELAY

                setStatus(
                    "NO PROXIMITY PROMPT"
                    .. "\nSKIPPING TEMPORARILY"
                    .. "\nSTART REMAINS ACTIVE"
                )

                -- No automatic STOP
                if not waitActive(0.2, id) then
                    break
                end

            elseif result == "unconfirmed" then

                retryAt[target] =
                    os.clock() + RETRY_DELAY

                setStatus(
                    "E NOT CONFIRMED"
                    .. "\nRETRYING LATER"
                    .. "\nSTART REMAINS ACTIVE"
                )

                if not waitActive(0.2, id) then
                    break
                end

            else

                retryAt[target] =
                    os.clock() + RETRY_DELAY

                setStatus(
                    "RESULT: " .. result
                    .. "\nTRYING NEXT TARGET"
                )

                if not waitActive(0.2, id) then
                    break
                end
            end
        end
    end)
end)

setStatus(
    "V16 READY | HOME SAVED"
    .. "\nSCAN: 0.20s"
    .. "\nWAIT AFTER E: 7s"
    .. "\nCANDIES: " .. #getCandies()
)
