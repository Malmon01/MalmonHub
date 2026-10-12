
--========================================
-- CANDY COLLECTOR V15
-- Delta Executor / Roblox Luau
--========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local PromptService =
    game:GetService("ProximityPromptService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- SETTINGS
local SCAN_WAIT = 0.20
local SEND_WAIT = 8
local NEAR_DISTANCE = 25
local PROMPT_TIMEOUT = 3
local HOLD_EXTRA = 0.20
local MAX_RETRIES = 2

local SEND_POINT = Vector3.new(
    -45837,
    40374,
    -20116
)

local PRIORITY = {
    Unknown = 6,
    Legendary = 5,
    Epic = 4,
    Rare = 3,
    Uncommon = 2,
    Common = 1,
    Unclassified = 0
}

-- STOP PREVIOUS V15
local ENV = (
    type(getgenv) == "function"
    and getgenv()
) or _G

if type(ENV.CandyV15Stop) == "function" then
    pcall(ENV.CandyV15Stop)
end

local Alive = true
local Running = false
local SentCount = 0
local FailedUntil = {}
local Connections = {}

local OldGui =
    PlayerGui:FindFirstChild("CandyV15")

if OldGui then
    OldGui:Destroy()
end

--========================================
-- UI
--========================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "CandyV15"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 99999
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(285, 220)
Main.Position = UDim2.fromScale(0.5, 0.4)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(24, 27, 37)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(86, 135, 255)
Stroke.Thickness = 2
Stroke.Parent = Main

local function Label(text, y, height, size)
    local obj = Instance.new("TextLabel")
    obj.Size = UDim2.new(1, -20, 0, height)
    obj.Position = UDim2.fromOffset(10, y)
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = size
    obj.TextWrapped = true
    obj.Parent = Main
    return obj
end

local Title = Label(
    "CANDY COLLECTOR V15", 8, 28, 17
)

local Status = Label(
    "Status: Ready", 43, 27, 12
)

local TargetLabel = Label(
    "Target: None", 72, 25, 12
)

local CountLabel = Label(
    "Delivery attempts: 0", 101, 25, 12
)

local DistanceLabel = Label(
    "Distance: -", 130, 22, 12
)

local function MakeButton(text, x, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(122, 38)
    button.Position = UDim2.fromOffset(x, 170)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Parent = Main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

local StartButton = MakeButton(
    "START COLLECT",
    12,
    Color3.fromRGB(30, 180, 85)
)

local CloseButton = MakeButton(
    "CLOSE",
    151,
    Color3.fromRGB(190, 60, 65)
)

local function SetStatus(message)
    if Alive and Status.Parent then
        Status.Text = "Status: " .. message
    end
end

--========================================
-- CHARACTER
--========================================

local function GetRoot()
    local character = Player.Character
    if not character then return nil end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

local function TeleportTo(position)
    local root = GetRoot()
    if not root then return false end

    root.AssemblyLinearVelocity = Vector3.zero

    root.CFrame = CFrame.new(position)

    return true
end

--========================================
-- ANTI-IDLE
--========================================

local IdleConnection = Player.Idled:Connect(function()
    if not Alive then return end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)

    print("[ANTI-IDLE] Activity sent")
end)

table.insert(Connections, IdleConnection)

--========================================
-- RARITY DETECTION
--========================================

local RarityWords = {
    "Unknown",
    "Legendary",
    "Epic",
    "Rare",
    "Uncommon",
    "Common"
}

local function ParseRarity(text)
    if type(text) ~= "string" then
        return nil
    end

    local lower = text:lower()

    for word in lower:gmatch("%a+") do
        for _, rarity in ipairs(RarityWords) do
            if word == rarity:lower() then
                return rarity
            end
        end
    end

    return nil
end

local function CheckRarity(obj)
    if not obj then return nil end

    local attributes = {
        "Rarity",
        "CandyRarity",
        "Tier",
        "Grade",
        "Quality"
    }

    for _, name in ipairs(attributes) do
        local value = obj:GetAttribute(name)

        if value ~= nil then
            local result =
                ParseRarity(tostring(value))

            if result then return result end
        end
    end

    for _, child in ipairs(obj:GetDescendants()) do

        if child:IsA("StringValue") then
            if ParseRarity(child.Name) or
                child.Name:lower():find("rarity") then

                local result =
                    ParseRarity(child.Value)

                if result then return result end
            end
        end

        if child:IsA("TextLabel") then
            local result = ParseRarity(child.Text)

            if result then return result end
        end
    end

    return ParseRarity(obj.Name)
end

--========================================
-- CANDY SCANNER
--========================================

local function GetCandyFolder()
    return Workspace:FindFirstChild(
        "HalloweenCandy"
    )
end

local function GetPromptPosition(prompt)
    local parent = prompt.Parent

    if not parent then return nil end

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end

    if parent:IsA("BasePart") then
        return parent.Position
    end

    local part = prompt:FindFirstAncestorWhichIsA(
        "BasePart"
    )

    if part then
        return part.Position
    end

    return nil
end

local function GetCandyRarity(prompt, folder)
    local current = prompt.Parent

    while current and current ~= folder do
        local rarity = nil

        if current:IsA("Model") then
            rarity = CheckRarity(current)
        else
            rarity = ParseRarity(current.Name)

            for _, name in ipairs({
                "Rarity",
                "CandyRarity"
            }) do
                local value = current:GetAttribute(name)

                if value then
                    rarity = rarity
                        or ParseRarity(tostring(value))
                end
            end
        end

        if rarity then return rarity end

        current = current.Parent
    end

    return ParseRarity(prompt.ObjectText)
        or ParseRarity(prompt.ActionText)
        or "Unclassified"
end

local function ScanCandies()
    local folder = GetCandyFolder()
    local root = GetRoot()

    if not folder or not root then
        return nil
    end

    local candidates = {}

    for _, obj in ipairs(folder:GetDescendants()) do

        if obj:IsA("ProximityPrompt") then

            local blocked =
                FailedUntil[obj] or 0

            if os.clock() >= blocked then
                local position =
                    GetPromptPosition(obj)

                if position then
                    local rarity =
                        GetCandyRarity(obj, folder)

                    table.insert(candidates, {
                        Prompt = obj,
                        Position = position,
                        Rarity = rarity,
                        Priority =
                            PRIORITY[rarity] or 0,

                        Distance = (
                            root.Position - position
                        ).Magnitude
                    })
                end
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    -- Highest rarity ALWAYS wins.
    -- Distance is used only for equal rarity.
    table.sort(candidates, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority > b.Priority
        end

        return a.Distance < b.Distance
    end)

    return candidates[1]
end

--========================================
-- PICKUP CONFIRMATION
--========================================

local function IsPickedUp(prompt, folder)
    if not prompt or not prompt.Parent then
        return true
    end

    if not prompt:IsDescendantOf(folder) then
        return true
    end

    return false
end

local function TryPickup(target, folder)
    local prompt = target.Prompt

    if not prompt or not prompt.Parent then
        return false
    end

    local position = target.Position

    SetStatus("Teleporting to candy")

    if not TeleportTo(
        position + Vector3.new(0, 2.5, 0)
    ) then
        return false
    end

    task.wait(0.20)

    if not Running or not Alive then
        return false
    end

    local triggered = false

    local conn = PromptService.PromptTriggered:Connect(
        function(activePrompt, player)
            if activePrompt == prompt
                and player == Player then

                triggered = true
            end
        end
    )

    local ok = pcall(function()
        prompt:InputHoldBegin()

        task.wait(
            math.max(
                0.15,
                prompt.HoldDuration + HOLD_EXTRA
            )
        )

        prompt:InputHoldEnd()
    end)

    -- Executor fallback
    if (not ok or not triggered)
        and type(fireproximityprompt) == "function"
        and prompt.Parent then

        pcall(function()
            fireproximityprompt(prompt)
        end)
    end

    local startTime = os.clock()
    local confirmed = false

    while os.clock() - startTime < PROMPT_TIMEOUT do

        if not Alive or not Running then
            break
        end

        if IsPickedUp(prompt, folder) then
            confirmed = true
            break
        end

        task.wait(0.10)
    end

    conn:Disconnect()

    return confirmed
end

--========================================
-- DISTANCE + DELIVERY
--========================================

local function GetSendDistance(position)
    return (position - SEND_POINT).Magnitude
end

local function WaitWhileRunning(seconds)
    local deadline = os.clock() + seconds

    while os.clock() < deadline do
        if not Running or not Alive then
            return false
        end

        task.wait(0.05)
    end

    return Running and Alive
end

local function DeliverCandy(target)
    local distance =
        GetSendDistance(target.Position)

    DistanceLabel.Text = string.format(
        "Distance: %.0f studs",
        distance
    )

    local waitTime = SEND_WAIT

    if distance <= NEAR_DISTANCE then
        waitTime = 0
        SetStatus("Near delivery - sending")
    else
        SetStatus("Waiting 8 seconds")
    end

    if not WaitWhileRunning(waitTime) then
        return false
    end

    SetStatus("Teleporting to delivery")

    if not TeleportTo(SEND_POINT) then
        return false
    end

    -- Allow the game to process delivery
    if not WaitWhileRunning(0.8) then
        return false
    end

    SentCount += 1

    CountLabel.Text =
        "Delivery attempts: " .. SentCount

    print(
        "[CANDY] Delivery attempted:",
        target.Rarity,
        "Distance:",
        math.floor(distance)
    )

    return true
end

--========================================
-- COLLECTION LOOP
--========================================

local function CollectCycle()
    local folder = GetCandyFolder()

    if not folder then
        SetStatus("Waiting for HalloweenCandy")
        task.wait(1)
        return
    end

    SetStatus("Scanning candies")

    local target = ScanCandies()

    if not target then
        TargetLabel.Text = "Target: None"
        SetStatus("Waiting for candy")
        task.wait(SCAN_WAIT)
        return
    end

    TargetLabel.Text =
        "Target: " .. target.Rarity

    print(
        "[CANDY] Selected rarity:",
        target.Rarity
    )

    local success = false

    for attempt = 1, MAX_RETRIES do
        if not Alive or not Running then
            return
        end

        success = TryPickup(target, folder)

        if success then break end

        print(
            "[CANDY] Pickup attempt failed:",
            attempt
        )

        task.wait(0.15)
    end

    if not success then
        FailedUntil[target.Prompt] =
            os.clock() + 4

        SetStatus("Pickup not confirmed")
        task.wait(SCAN_WAIT)
        return
    end

    SetStatus("Candy pickup detected")

    print(
        "[CANDY] Pickup detected:",
        target.Rarity
    )

    DeliverCandy(target)

    task.wait(SCAN_WAIT)
end

--========================================
-- START / STOP
--========================================

StartButton.MouseButton1Click:Connect(function()
    Running = not Running

    if Running then
        StartButton.Text = "STOP COLLECT"
        StartButton.BackgroundColor3 =
            Color3.fromRGB(200, 65, 60)

        SetStatus("Starting collection")
    else
        StartButton.Text = "START COLLECT"
        StartButton.BackgroundColor3 =
            Color3.fromRGB(30, 180, 85)

        SetStatus("Stopped")
    end
end)

ENV.CandyV15Stop = function()
    Alive = false
    Running = false

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if Gui then
        Gui:Destroy()
    end
end

CloseButton.MouseButton1Click:Connect(function()
    ENV.CandyV15Stop()
end)

--========================================
-- DRAG UI
--========================================

local Dragging = false
local DragStart
local StartPosition

Title.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPosition = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState ==
                Enum.UserInputState.End then

                Dragging = false
            end
        end)
    end
end)

local DragConnection = UIS.InputChanged:Connect(
    function(input)
        if not Dragging then return end

        if input.UserInputType ==
            Enum.UserInputType.MouseMovement
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            local delta =
                input.Position - DragStart

            Main.Position = UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + delta.Y
            )
        end
    end
)

table.insert(Connections, DragConnection)

--========================================
-- MAIN WORKER
--========================================

task.spawn(function()
    while Alive do
        if Running then
            local ok, err = pcall(CollectCycle)

            if not ok then
                warn("[CANDY V15 ERROR]", err)
                SetStatus("Error - retrying")
                task.wait(0.5)
            end
        else
            task.wait(0.15)
        end
    end
end)

print("================================")
print("CANDY COLLECTOR V15 LOADED")
print("Scan delay:", SCAN_WAIT)
print("Delivery wait:", SEND_WAIT)
print("Near distance:", NEAR_DISTANCE)
print("Anti-Idle: Enabled")
print("================================")
