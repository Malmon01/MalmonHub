
--========================================
-- SMART CANDY COLLECTOR V13
-- SCAN FIRST / PRIORITY / WAIT 7 SECONDS
-- ONE LOCALSCRIPT
--========================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local char = player.Character or player.CharacterAdded:Wait()
char:WaitForChild("HumanoidRootPart")

local HOME = char:GetPivot()

-- SETTINGS
local WAIT_AFTER_E = 7
local SCAN_WAIT = 0.45
local PROMPT_TIMEOUT = 2
local HOLD_EXTRA = 0.2
local HOME_PAUSE = 0.4
local MAX_ATTEMPTS = 2

local PRIORITY = {
    Unknown = 5,
    Legendary = 4,
    Epic = 3,
    Rare = 2,
    Common = 1
}

local running = false
local runId = 0
local currentPrompt = nil

local visiblePrompts = {}
local rarityMap = {}
local scanned = {}
local attempts = {}

local totalAttempts = 0

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

local old = pg:FindFirstChild("CandyV13")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV13"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(290, 245)
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
status.Size = UDim2.new(1, -20, 0, 105)
status.Position = UDim2.fromOffset(10, 132)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "READY | HOME SAVED"
status.Parent = frame

local function setStatus(text)
    status.Text = text
    print("[CANDY V13]", text)
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

        task.wait(0.05)
    end

    return active(id)
end

--========================================
-- CANDY LIST
--========================================

local function getCandies()
    local result = {}

    for _, candy in ipairs(folder:GetChildren()) do
        if candy.Name:match("^Candy_")
            and (
                candy:IsA("BasePart")
                or candy:IsA("Model")
            ) then

            table.insert(result, candy)
        end
    end

    return result
end

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
end

--========================================
-- READ RARITY
--========================================

local function readText(value)
    if value == nil then return nil end

    local text = string.lower(tostring(value))

    if text:find("%f[%a]legendary%f[%A]") then
        return "Legendary"
    elseif text:find("%f[%a]epic%f[%A]") then
        return "Epic"
    elseif text:find("%f[%a]rare%f[%A]") then
        return "Rare"
    elseif text:find("%f[%a]common%f[%A]") then
        return "Common"
    end

    return nil
end

local function readObject(candy)
    local objects = {candy}

    for _, obj in ipairs(candy:GetDescendants()) do
        table.insert(objects, obj)
    end

    for _, obj in ipairs(objects) do
        for key, value in pairs(obj:GetAttributes()) do
            local rarity = readText(value)

            if rarity then
                return rarity
            end

            -- Some games encode rarity in keys
            if value == true then
                rarity = readText(key)
                if rarity then return rarity end
            end
        end

        if obj:IsA("StringValue") then
            local rarity = readText(obj.Value)
            if rarity then return rarity end
        end

        if obj:IsA("ProximityPrompt") then
            local rarity = readText(
                obj.ObjectText .. " " .. obj.ActionText
            )

            if rarity then return rarity end
        end

        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local rarity = readText(obj.Text)
            if rarity then return rarity end
        end
    end

    return nil
end

-- Find rarity text near candy on screen
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

            local rarity = readText(obj.Text)

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

                    nearest = distance
                    result = rarity
                end
            end
        end
    end

    return result
end

--========================================
-- FIND PROMPT
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

                if distance < nearest and distance <= 6 then
                    nearest = distance
                    best = prompt
                end
            end
        end
    end

    return best
end

local function updateRarity(candy, prompt)
    local rarity = readObject(candy)

    if not rarity and prompt then
        rarity = readText(
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
-- SCAN BEFORE FARMING
--========================================

local function scanCandy(candy, id)
    local part = getPart(candy)
    if not part then return end

    local rarity = readObject(candy)

    if rarity then
        rarityMap[candy] = rarity
        scanned[candy] = true
        return
    end

    setStatus("SCANNING CANDY\n" .. candy.Name)

    teleport(CFrame.new(
        part.Position + Vector3.new(0, 2, 0)
    ))

    if not waitActive(SCAN_WAIT, id) then
        return
    end

    -- Read currently visible pickup UI
    local prompt = findPrompt(candy)

    rarityMap[candy] = updateRarity(candy, prompt)
    scanned[candy] = true

    print(
        "[SCAN]",
        candy:GetFullName(),
        "RARITY:", rarityMap[candy]
    )
end

local function scanUnscanned(id)
    local candies = getCandies()

    for index, candy in ipairs(candies) do
        if not active(id) then
            return false
        end

        if not scanned[candy] then
            setStatus(
                "SCANNING: " .. index .. "/" .. #candies
                .. "\nCHECKING RARITY..."
            )

            scanCandy(candy, id)
        end
    end

    if not active(id) then return false end

    teleport(HOME)
    return waitActive(0.3, id)
end

--========================================
-- PRIORITY SORT
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
-- COLLECT
--========================================

local currentHold = nil

local function collectCandy(candy, id)
    local part = getPart(candy)

    if not part then return "invalid" end

    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    local rarity = rarityMap[candy] or "Unknown"

    setStatus(
        "TELEPORT TO CANDY\n"
        .. "RARITY: " .. rarity
    )

    teleport(CFrame.new(
        part.Position + Vector3.new(0, 2, 0)
    ))

    if not waitActive(0.3, id) then
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

    -- Update rarity using current interaction
    rarity = updateRarity(candy, prompt)

    if not prompt then
        return "no_prompt"
    end

    -- If a lower rarity was discovered, let
    -- the priority sorter choose a better candy.
    local nextRarity = rarityMap[candy] or "Unknown"

    if PRIORITY[nextRarity] < PRIORITY.Unknown then
        local list = getSortedCandies()

        for _, other in ipairs(list) do
            if other ~= candy
                and (attempts[other] or 0) < MAX_ATTEMPTS
                and (PRIORITY[
                    rarityMap[other] or "Unknown"
                ] or 5) > PRIORITY[nextRarity] then

                return "reprioritize"
            end
        end
    end

    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    currentHold = prompt

    local duration =
        math.max(0, prompt.HoldDuration) + HOLD_EXTRA

    setStatus(
        "HOLDING E\n"
        .. rarity
        .. "\n"
        .. string.format("%.2f", duration) .. "s"
    )

    prompt:InputHoldBegin()

    local held = waitActive(duration, id)

    prompt:InputHoldEnd()
    currentHold = nil

    if not held then
        connection:Disconnect()
        return "cancelled"
    end

    -- WAIT EXACTLY 7 SECONDS AFTER E
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

    connection:Disconnect()

    if not active(id) then
        return "cancelled"
    end

    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    if triggered then
        return "triggered"
    end

    return "unconfirmed"
end

--========================================
-- STOP / HOME
--========================================

local function stop()
    running = false
    runId += 1

    if currentHold then
        currentHold:InputHoldEnd()
        currentHold = nil
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
-- START / PRIORITY LOOP
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
    attempts = {}
    totalAttempts = 0

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(215, 55, 65)

    task.spawn(function()

        -- Discover rarities before collecting
        if not scanUnscanned(id) then
            return
        end

        while active(id) do

            -- Scan new candies after respawns
            if not scanUnscanned(id) then
                break
            end

            local candies = getSortedCandies()

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED")
                break
            end

            local target = nil

            for _, candy in ipairs(candies) do
                if (attempts[candy] or 0) < MAX_ATTEMPTS then
                    target = candy
                    break
                end
            end

            if not target then
                setStatus(
                    "TEST COMPLETE\n"
                    .. "Some candies remain"
                    .. "\nCheck pickup results"
                )
                break
            end

            local rarity = rarityMap[target] or "Unknown"

            setStatus(
                "NEXT PRIORITY: " .. rarity
                .. "\nTARGET: " .. target.Name
            )

            local result = collectCandy(target, id)

            if not active(id) then
                break
            end

            -- Recheck priority if this candy
            -- was found to be lower rarity.
            if result ~= "reprioritize" then
                attempts[target] =
                    (attempts[target] or 0) + 1

                totalAttempts += 1
            end

            setStatus(
                "RESULT: " .. result
                .. "\nRETURNING HOME"
            )

            -- Back to HOME after the 7s wait
            teleport(HOME)

            if not waitActive(HOME_PAUSE, id) then
                break
            end

            -- Loop and select highest priority again
        end

        if active(id) then
            teleport(HOME)
            stop()
        end
    end)
end)

setStatus(
    "V13 READY | HOME SAVED"
    .. "\nWAIT AFTER E: 7s"
    .. "\nCANDIES: " .. #getCandies()
)
