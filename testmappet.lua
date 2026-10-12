
--========================================
-- CANDY COLLECTOR V16
-- ALL IN ONE / DELTA
--========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- SETTINGS
local SCAN_WAIT = 0.20
local DELIVERY_WAIT = 8
local NEAR_DISTANCE = 25
local PICKUP_TIMEOUT = 2.5
local SEND_POSITION = Vector3.new(
    -45837, 40374, -20116
)

local PRIORITY = {
    Unknown = 6,
    Legendary = 5,
    Epic = 4,
    Rare = 3,
    Uncommon = 2,
    Common = 1
}

local ENV = (
    type(getgenv) == "function"
    and getgenv()
) or _G

-- Stop previous version
if type(ENV.CandyV15Stop) == "function" then
    pcall(ENV.CandyV15Stop)
end

if type(ENV.CandyV16Stop) == "function" then
    pcall(ENV.CandyV16Stop)
end

local Alive = true
local Running = false
local DeliveryAttempts = 0
local Connections = {}
local Prompts = {}
local FailedUntil = {}

local oldGui = PlayerGui:FindFirstChild(
    "CandyCollectorV16"
)

if oldGui then
    oldGui:Destroy()
end

--========================================
-- UI
--========================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "CandyCollectorV16"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 99999
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(310, 252)
Main.Position = UDim2.fromScale(0.5, 0.37)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(23, 26, 36)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 130, 255)
stroke.Thickness = 2
stroke.Parent = Main

local function CreateLabel(text, y, height, size)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, height)
    label.Position = UDim2.fromOffset(10, y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = size or 13
    label.Font = Enum.Font.GothamBold
    label.TextWrapped = true
    label.Parent = Main
    return label
end

local Title = CreateLabel(
    "CANDY COLLECTOR V16", 7, 30, 17
)

local Status = CreateLabel(
    "Status: Ready", 43, 27
)

local TargetText = CreateLabel(
    "Target: None", 72, 26
)

local ScanText = CreateLabel(
    "Candy found: 0", 101, 25
)

local DistanceText = CreateLabel(
    "Delivery distance: -", 130, 25
)

local CountText = CreateLabel(
    "Delivery attempts: 0", 158, 25
)

local function Button(text, x, color)
    local obj = Instance.new("TextButton")
    obj.Size = UDim2.fromOffset(132, 42)
    obj.Position = UDim2.fromOffset(x, 195)
    obj.BackgroundColor3 = color
    obj.Text = text
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = 13
    obj.Parent = Main

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = obj

    return obj
end

local StartButton = Button(
    "START COLLECT", 12,
    Color3.fromRGB(35, 180, 85)
)

local CloseButton = Button(
    "CLOSE", 166,
    Color3.fromRGB(190, 60, 65)
)

local function SetStatus(text)
    if Alive and Status.Parent then
        Status.Text = "Status: " .. text
    end
end

--========================================
-- CHARACTER
--========================================

local function GetRoot()
    local character = Player.Character

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

local function Teleport(position)
    local root = GetRoot()

    if not root then
        return false
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(position)

    return true
end

--========================================
-- RARITY
--========================================

local function DetectRarity(text)
    if type(text) ~= "string" then
        return nil
    end

    local lower = text:lower()

    for word in lower:gmatch("%a+") do
        for rarity in pairs(PRIORITY) do
            if word == rarity:lower() then
                return rarity
            end
        end
    end

    return nil
end

--========================================
-- UNIVERSAL CANDY DETECTION
--========================================

local function RegisterPrompt(obj)
    if obj:IsA("ProximityPrompt") then
        Prompts[obj] = true
    end
end

local function InitialScan()
    local descendants = Workspace:GetDescendants()

    for i, obj in ipairs(descendants) do
        RegisterPrompt(obj)

        if i % 500 == 0 then
            task.wait()
        end
    end
end

table.insert(
    Connections,
    Workspace.DescendantAdded:Connect(
        RegisterPrompt
    )
)

local function GetPromptPosition(prompt)
    local obj = prompt.Parent

    if not obj then
        return nil
    end

    if obj:IsA("Attachment") then
        return obj.WorldPosition
    end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    local part = prompt:FindFirstAncestorWhichIsA(
        "BasePart"
    )

    if part then
        return part.Position
    end

    return nil
end

local function GetCandyInfo(prompt)
    if not prompt.Enabled then
        return nil
    end

    local words = {
        prompt.ObjectText,
        prompt.ActionText
    }

    local node = prompt.Parent

    -- Inspect nearby hierarchy
    for i = 1, 6 do
        if not node or node == Workspace then
            break
        end

        table.insert(words, node.Name)

        for _, key in ipairs({
            "Rarity",
            "CandyRarity",
            "Tier"
        }) do
            local value = node:GetAttribute(key)

            if value ~= nil then
                table.insert(words, tostring(value))
            end
        end

        -- Look at labels close to the prompt
        if i <= 3 then
            for _, child in ipairs(node:GetChildren()) do
                if child:IsA("TextLabel") then
                    table.insert(words, child.Text)
                end

                if child:IsA("BillboardGui") then
                    for _, label in ipairs(
                        child:GetDescendants()
                    ) do
                        if label:IsA("TextLabel") then
                            table.insert(
                                words,
                                label.Text
                            )
                        end
                    end
                end
            end
        end

        node = node.Parent
    end

    local combined = table.concat(words, " ")
    local lower = combined:lower()

    -- Must be associated with candy
    if not lower:find("candy", 1, true) then
        return nil
    end

    local rarity = DetectRarity(combined)

    if not rarity then
        rarity = "Unknown"
    end

    local position = GetPromptPosition(prompt)

    if not position then
        return nil
    end

    return {
        Prompt = prompt,
        Position = position,
        Rarity = rarity,
        Priority = PRIORITY[rarity],
        Name = prompt.ObjectText
    }
end

--========================================
-- TARGET SELECTION
--========================================

local function FindBestCandy()
    local root = GetRoot()

    if not root then
        return nil, 0
    end

    local best = nil
    local count = 0

    for prompt in pairs(Prompts) do
        if not prompt.Parent
            or not prompt:IsDescendantOf(Workspace) then

            Prompts[prompt] = nil

        elseif os.clock() >=
            (FailedUntil[prompt] or 0) then

            local info = GetCandyInfo(prompt)

            if info then
                count += 1

                info.Distance = (
                    root.Position - info.Position
                ).Magnitude

                if not best
                    or info.Priority > best.Priority
                    or (
                        info.Priority == best.Priority
                        and info.Distance < best.Distance
                    ) then

                    best = info
                end
            end
        end
    end

    return best, count
end

--========================================
-- WAIT
--========================================

local function WaitActive(seconds)
    local finish = os.clock() + seconds

    while os.clock() < finish do
        if not Running or not Alive then
            return false
        end

        task.wait(0.05)
    end

    return Running and Alive
end

--========================================
-- PICKUP
--========================================

local function PickupCandy(target)
    local prompt = target.Prompt

    if not prompt or not prompt.Parent then
        return false
    end

    SetStatus("Moving to candy")

    local success = Teleport(
        target.Position + Vector3.new(0, 2, 0)
    )

    if not success then
        return false
    end

    if not WaitActive(0.25) then
        return false
    end

    local triggered = false

    local connection = prompt.Triggered:Connect(
        function()
            triggered = true
        end
    )

    SetStatus("Holding E")

    local holdDuration = math.max(
        prompt.HoldDuration,
        0.10
    )

    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(holdDuration + 0.20)
        prompt:InputHoldEnd()
    end)

    -- Executor fallback
    if (not ok or not triggered)
        and prompt.Parent
        and type(fireproximityprompt) == "function" then

        pcall(function()
            fireproximityprompt(prompt)
        end)
    end

    local start = os.clock()
    local detected = false

    while Running and Alive
        and os.clock() - start < PICKUP_TIMEOUT do

        if triggered then
            detected = true
            break
        end

        if not prompt.Parent
            or not prompt:IsDescendantOf(Workspace)
            or not prompt.Enabled then

            detected = true
            break
        end

        task.wait(0.10)
    end

    connection:Disconnect()

    return detected
end

--========================================
-- DELIVERY
--========================================

local function DeliverCandy(target)
    local distance = (
        target.Position - SEND_POSITION
    ).Magnitude

    DistanceText.Text = string.format(
        "Delivery distance: %.0f studs",
        distance
    )

    local waitTime = DELIVERY_WAIT

    if distance <= NEAR_DISTANCE then
        waitTime = 0
        SetStatus("Near - sending")
    else
        SetStatus("Waiting 8 seconds")
    end

    if not WaitActive(waitTime) then
        return false
    end

    SetStatus("Going to delivery")

    if not Teleport(SEND_POSITION) then
        return false
    end

    if not WaitActive(1) then
        return false
    end

    DeliveryAttempts += 1

    CountText.Text =
        "Delivery attempts: " .. DeliveryAttempts

    print(
        "[CANDY V16] Delivery attempted",
        target.Rarity,
        math.floor(distance)
    )

    return true
end

--========================================
-- COLLECT LOOP
--========================================

local function CollectCycle()
    local root = GetRoot()

    if not root then
        SetStatus("Waiting for character")
        task.wait(0.5)
        return
    end

    local target, count = FindBestCandy()

    ScanText.Text =
        "Candy found: " .. count

    if not target then
        TargetText.Text = "Target: None"
        SetStatus("Waiting for candy")
        task.wait(SCAN_WAIT)
        return
    end

    TargetText.Text =
        "Target: " .. target.Rarity

    SetStatus("Collecting " .. target.Rarity)

    local picked = PickupCandy(target)

    if not Running or not Alive then
        return
    end

    if not picked then
        FailedUntil[target.Prompt] =
            os.clock() + 3

        SetStatus("Pickup not detected")
        task.wait(SCAN_WAIT)
        return
    end

    -- Triggering a prompt does not prove
    -- the server accepted the pickup.
    SetStatus("Pickup signal detected")

    DeliverCandy(target)

    task.wait(SCAN_WAIT)
end

--========================================
-- ANTI IDLE
--========================================

table.insert(
    Connections,
    Player.Idled:Connect(function()
        if not Alive then return end

        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(
                Vector2.new(0, 0)
            )
        end)
    end)
)

--========================================
-- BUTTONS
--========================================

StartButton.MouseButton1Click:Connect(function()
    Running = not Running

    if Running then
        StartButton.Text = "STOP COLLECT"
        StartButton.BackgroundColor3 =
            Color3.fromRGB(195, 55, 55)

        SetStatus("Scanning")
    else
        StartButton.Text = "START COLLECT"
        StartButton.BackgroundColor3 =
            Color3.fromRGB(35, 180, 85)

        SetStatus("Stopped")
    end
end)

ENV.CandyV16Stop = function()
    Alive = false
    Running = false

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    Gui:Destroy()
end

CloseButton.MouseButton1Click:Connect(function()
    ENV.CandyV16Stop()
end)

--========================================
-- DRAGGABLE UI
--========================================

local dragging = false
local dragStart
local startPosition

Title.Active = true

Title.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState ==
                Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

table.insert(
    Connections,
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end

        if input.UserInputType ==
            Enum.UserInputType.MouseMovement
            or input.UserInputType ==
            Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
)

--========================================
-- STARTUP
--========================================

SetStatus("Indexing candy prompts")

task.spawn(function()
    InitialScan()

    print("[V16] Initial scan complete")

    while Alive do
        if Running then
            local ok, err = pcall(CollectCycle)

            if not ok then
                warn("[V16 ERROR]", err)
                SetStatus("Error - retrying")
                task.wait(0.5)
            end
        else
            task.wait(0.15)
        end
    end
end)

print("==============================")
print("CANDY COLLECTOR V16 LOADED")
print("Scan:", SCAN_WAIT)
print("Delivery wait:", DELIVERY_WAIT)
print("Near distance:", NEAR_DISTANCE)
print("Anti-Idle: ON")
print("==============================")
