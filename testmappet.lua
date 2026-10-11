
--========================================
-- SMART CANDY COLLECTOR V12
-- PRIORITY FARMING
--
-- UNKNOWN > LEGENDARY > EPIC
--         > RARE > COMMON
--
-- TELEPORT -> HOLD E -> WAIT 8s
-- -> HOME -> NEXT CANDY -> LOOP
--========================================

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local pg = player:WaitForChild("PlayerGui")

local character =
    player.Character or player.CharacterAdded:Wait()

local root = character:WaitForChild("HumanoidRootPart")

--========================================
-- SETTINGS
--========================================

local WAIT_AFTER_E = 8
local PROMPT_TIMEOUT = 2.5
local HOLD_EXTRA = 0.2

local ARRIVAL_HEIGHT = 2
local HOME_PAUSE = 0.5
local ROUND_PAUSE = 2

-- Prevent endless failed attempts
local MAX_ATTEMPTS = 3

-- Saved when script first runs
local HOME = character:GetPivot()

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

local rarityCache = {}
local attempts = {}

local round = 0
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

local old = pg:FindFirstChild("CandyV12")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyV12"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(290, 260)
frame.Position = UDim2.new(0.5, -145, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 25, 35)
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
    b.TextSize = 16
    b.Font = Enum.Font.GothamBold
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
status.Size = UDim2.new(1, -20, 0, 120)
status.Position = UDim2.fromOffset(10, 132)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 13
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Text = "SMART COLLECTOR READY"
status.Parent = frame

local function setStatus(message)
    status.Text = message
    print("[CANDY V12]", message)
end

--========================================
-- MOVEMENT
--========================================

local function teleport(cf)
    local c = player.Character
    if not c then return false end

    c:PivotTo(cf)

    local hrp = c:FindFirstChild("HumanoidRootPart")

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

--========================================
-- GET CANDIES
--========================================

local function getCandies()
    local list = {}

    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name:match("^Candy_") then
            if obj:IsA("BasePart") then
                table.insert(list, obj)
            elseif obj:IsA("Model") then
                table.insert(list, obj)
            end
        end
    end

    return list
end

local function getCandyPart(candy)
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

--========================================
-- DETECT RARITY
--========================================

local function rarityFromText(value)
    if value == nil then
        return nil
    end

    local text = string.lower(tostring(value))

    -- Check known rarity labels
    if text:find("%f[%a]legendary%f[%A]") then
        return "Legendary"
    end

    if text:find("%f[%a]epic%f[%A]") then
        return "Epic"
    end

    if text:find("%f[%a]rare%f[%A]") then
        return "Rare"
    end

    if text:find("%f[%a]common%f[%A]") then
        return "Common"
    end

    return nil
end

local function readObjectRarity(candy)
    local objects = {candy}

    for _, descendant in ipairs(candy:GetDescendants()) do
        table.insert(objects, descendant)
    end

    for _, obj in ipairs(objects) do

        -- Attributes
        for key, value in pairs(obj:GetAttributes()) do
            local found = rarityFromText(value)

            if found then
                return found
            end

            -- Attribute names can contain rarity
            found = rarityFromText(key)

            if found then
                return found
            end
        end

        -- StringValues
        if obj:IsA("StringValue") then
            local found = rarityFromText(obj.Value)

            if found then
                return found
            end
        end

        -- ProximityPrompt texts
        if obj:IsA("ProximityPrompt") then
            local found = rarityFromText(
                obj.ObjectText .. " " .. obj.ActionText
            )

            if found then
                return found
            end
        end

        -- Text attached to candy
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local found = rarityFromText(obj.Text)

            if found then
                return found
            end
        end
    end

    return nil
end

-- Read visible UI near the candy.
-- This helps when rarity is displayed only
-- after approaching the object.

local function readNearbyUI(candy)
    local part = getCandyPart(candy)
    local camera = workspace.CurrentCamera

    if not part or not camera then
        return nil
    end

    local screenPos, onScreen =
        camera:WorldToViewportPoint(part.Position)

    if not onScreen then
        return nil
    end

    local bestRarity = nil
    local nearest = math.huge

    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local found = rarityFromText(obj.Text)

            if found then
                local visible = obj.Visible
                local ancestor = obj.Parent

                while visible and ancestor do
                    if ancestor:IsA("GuiObject")
                        and not ancestor.Visible then
                        visible = false
                    end

                    if ancestor:IsA("ScreenGui")
                        and not ancestor.Enabled then
                        visible = false
                    end

                    ancestor = ancestor.Parent
                end

                if visible then
                    local center = obj.AbsolutePosition
                        + obj.AbsoluteSize / 2

                    local dx = center.X - screenPos.X
                    local dy = center.Y - screenPos.Y

                    local distance =
                        math.sqrt(dx * dx + dy * dy)

                    if distance < 220
                        and distance < nearest then

                        nearest = distance
                        bestRarity = found
                    end
                end
            end
        end
    end

    return bestRarity
end

local function classifyCandy(candy, checkUI)
    local rarity = readObjectRarity(candy)

    if not rarity and checkUI then
        rarity = readNearbyUI(candy)
    end

    if rarity then
        rarityCache[candy] = rarity
    end

    return rarityCache[candy] or "Unknown"
end

--========================================
-- SORT: HIGHEST PRIORITY FIRST
--========================================

local function getSortedCandies()
    local candies = getCandies()

    for _, candy in ipairs(candies) do
        classifyCandy(candy, false)
    end

    table.sort(candies, function(a, b)
        local ra = rarityCache[a] or "Unknown"
        local rb = rarityCache[b] or "Unknown"

        local pa = PRIORITY[ra] or 5
        local pb = PRIORITY[rb] or 5

        if pa ~= pb then
            return pa > pb
        end

        -- Deterministic order within a rarity
        local partA = getCandyPart(a)
        local partB = getCandyPart(b)

        if partA and partB then
            local da = (partA.Position - HOME.Position).Magnitude
            local db = (partB.Position - HOME.Position).Magnitude

            return da < db
        end

        return a.Name < b.Name
    end)

    return candies
end

--========================================
-- FIND E PROMPT
--========================================

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
    local own = candy:FindFirstChildWhichIsA(
        "ProximityPrompt", true
    )

    if own and own.Enabled then
        return own
    end

    local part = getCandyPart(candy)
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

                    nearest = distance
                    best = prompt
                end
            end
        end
    end

    return best
end

--========================================
-- COLLECT ONE CANDY
--========================================

local function collectCandy(candy, id)
    if not candy:IsDescendantOf(folder) then
        return "removed"
    end

    local part = getCandyPart(candy)

    if not part then
        return "invalid"
    end

    -- 1. TELEPORT TO CANDY
    setStatus("TELEPORTING\n" .. candy.Name)

    if not teleport(CFrame.new(
        part.Position + Vector3.new(
            0, ARRIVAL_HEIGHT, 0
        )
    )) then
        return "teleport_failed"
    end

    if not waitActive(0.35, id) then
        return "cancelled"
    end

    -- 2. DETECT RARITY AFTER ARRIVAL
    local rarity = classifyCandy(candy, true)

    setStatus(
        "FOUND: " .. rarity
        .. "\n" .. candy.Name
    )

    -- 3. FIND E PROMPT
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

    -- Try reading rarity from prompt
    local promptRarity = rarityFromText(
        prompt.ObjectText .. " " .. prompt.ActionText
    )

    if promptRarity then
        rarity = promptRarity
        rarityCache[candy] = rarity
    end

    -- 4. HOLD E
    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    currentPrompt = prompt

    local holdTime =
        math.max(0, prompt.HoldDuration) + HOLD_EXTRA

    setStatus(
        "COLLECTING: " .. rarity
        .. "\nHOLDING E"
        .. "\n" .. string.format("%.2f", holdTime) .. "s"
    )

    prompt:InputHoldBegin()

    local held = waitActive(holdTime, id)

    prompt:InputHoldEnd()
    currentPrompt = nil

    if not held then
        connection:Disconnect()
        return "cancelled"
    end

    -- 5. WAIT 8 SECONDS AT CANDY
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

    return "unconfirmed"
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
-- SMART PRIORITY LOOP
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

    round = 1
    totalAttempts = 0
    attempts = {}

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 =
        Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        local visitedRound = {}

        while active(id) do
            -- Rescan and reprioritize every time
            local candies = getSortedCandies()

            if #candies == 0 then
                setStatus("ALL CANDIES REMOVED")
                break
            end

            local target = nil

            for _, candy in ipairs(candies) do
                if not visitedRound[candy]
                    and (attempts[candy] or 0) < MAX_ATTEMPTS then

                    target = candy
                    break
                end
            end

            if not target then
                -- Check for candies still eligible
                local eligible = false

                for _, candy in ipairs(candies) do
                    if (attempts[candy] or 0) < MAX_ATTEMPTS then
                        eligible = true
                        break
                    end
                end

                if not eligible then
                    setStatus(
                        "TEST COMPLETE"
                        .. "\nSome candies remain"
                        .. "\nCheck prompts / rewards"
                    )
                    break
                end

                -- Start another round
                round += 1
                visitedRound = {}

                setStatus(
                    "ROUND COMPLETE"
                    .. "\nNEXT ROUND: " .. round
                    .. "\nRE-SCANNING PRIORITIES"
                )

                if not waitActive(ROUND_PAUSE, id) then
                    break
                end

            else
                visitedRound[target] = true

                attempts[target] =
                    (attempts[target] or 0) + 1

                local rarity =
                    rarityCache[target] or "Unknown"

                setStatus(
                    "ROUND: " .. round
                    .. "\nPRIORITY: " .. rarity
                    .. "\nTARGET: " .. target.Name
                )

                local result = collectCandy(target, id)

                if not active(id) then
                    break
                end

                totalAttempts += 1

                setStatus(
                    "RESULT: " .. result
                    .. "\nRETURNING HOME"
                    .. "\nATTEMPTS: " .. totalAttempts
                )

                -- Return Home after collection
                teleport(HOME)

                if not waitActive(HOME_PAUSE, id) then
                    break
                end

                -- Next loop selects highest priority again
            end
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
    "SMART COLLECTOR READY"
    .. "\nUNKNOWN > LEGENDARY > EPIC"
    .. "\nRARE > COMMON"
    .. "\nCANDIES FOUND: " .. #getCandies()
)
