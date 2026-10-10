
-- Candy Auto Collector | Single LocalScript

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- Save first position
local HOME = root.CFrame
local running = false
local runId = 0
local collected = 0

-- Remove previous UI
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("CandyAutoUI")
if old then old:Destroy() end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "CandyAutoUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(245, 195)
frame.Position = UDim2.new(0.5, -122, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeButton(name, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 43)
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

local homeBtn = makeButton("HOME", 12, Color3.fromRGB(45, 110, 220))
local startBtn = makeButton("START COLLECT", 65, Color3.fromRGB(30, 175, 90))

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 55)
status.Position = UDim2.fromOffset(10, 120)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 13
status.TextWrapped = true
status.Text = "Ready | Home Saved"
status.Parent = frame

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf)
    local r = getRoot()
    if r then
        r.CFrame = cf
        r.AssemblyLinearVelocity = Vector3.zero
    end
end

local function getCandyList()
    local list = {}

    for _, candy in ipairs(folder:GetChildren()) do
        local prompt = candy:FindFirstChildWhichIsA(
            "ProximityPrompt", true
        )

        if prompt and prompt.Enabled then
            local part

            if candy:IsA("BasePart") then
                part = candy
            elseif candy:IsA("Model") then
                part = candy.PrimaryPart
                    or candy:FindFirstChildWhichIsA("BasePart", true)
            end

            if part then
                table.insert(list, {
                    candy = candy,
                    part = part,
                    prompt = prompt
                })
            end
        end
    end

    return list
end

local function stop()
    running = false
    runId += 1
    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(30, 175, 90)
end


local function collect(info, id)
    local candy = info.candy
    local prompt = info.prompt

    if not candy.Parent or not prompt.Parent then
        return false
    end

    local promptPosition

    if prompt.Parent:IsA("Attachment") then
        promptPosition = prompt.Parent.WorldPosition
    elseif prompt.Parent:IsA("BasePart") then
        promptPosition = prompt.Parent.Position
    else
        promptPosition = info.part.Position
    end

    -- วาร์ปเข้าใกล้จุดกด E
    teleport(CFrame.new(
        promptPosition + Vector3.new(0, 2, 0)
    ))

    task.wait(0.3)

    if not running or id ~= runId then
        return false
    end

    -- ตรวจสอบว่ากด E ได้
    if not prompt.Enabled then
        return false
    end

    local triggered = false

    local connection = prompt.Triggered:Connect(function()
        triggered = true
    end)

    -- เริ่มกด E ค้าง
    prompt:InputHoldBegin()

    -- ค้างตาม HoldDuration ของแคนดี้
    local holdTime = math.max(prompt.HoldDuration, 0)
    local elapsed = 0

    while elapsed < holdTime + 0.15 do
        if not running or id ~= runId then
            prompt:InputHoldEnd()
            connection:Disconnect()
            return false
        end

        elapsed += task.wait(0.03)
    end

    -- ปล่อย E หลังค้างครบเวลา
    prompt:InputHoldEnd()

    -- รอให้ระบบเกมประมวลผล
    task.wait(0.25)

    connection:Disconnect()

    return triggered
        or not candy:IsDescendantOf(folder)
end


    -- Teleport close to E prompt
    local promptPosition

    if prompt.Parent:IsA("BasePart") then
        promptPosition = prompt.Parent.Position
    elseif prompt.Parent:IsA("Attachment") then
        promptPosition = prompt.Parent.WorldPosition
    else
        promptPosition = info.part.Position
    end

    teleport(CFrame.new(promptPosition + Vector3.new(0, 2, 0)))
    task.wait(0.2)

    if not running or id ~= runId then
        return false
    end

    -- Hold E via ProximityPrompt
    local holdTime = prompt.HoldDuration

    local completed = false
    local connection = prompt.Triggered:Connect(function()
        completed = true
    end)

    prompt:InputHoldBegin()

    local elapsed = 0
    while elapsed < holdTime + 0.1 do
        if not running or id ~= runId then
            prompt:InputHoldEnd()
            connection:Disconnect()
            return false
        end

        if completed then break end
        elapsed += task.wait(0.03)
    end

    prompt:InputHoldEnd()

    -- Wait for candy to disappear or prompt to disable
    local deadline = os.clock() + 1.5

    while os.clock() < deadline do
        if not running or id ~= runId then break end

        if not candy:IsDescendantOf(folder)
            or not prompt.Enabled then
            completed = true
            break
        end

        task.wait(0.05)
    end

    connection:Disconnect()
    return completed
end

homeBtn.MouseButton1Click:Connect(function()
    stop()
    teleport(HOME)
    status.Text = "Returned Home"
end)

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        status.Text = "Stopped"
        return
    end

    running = true
    runId += 1
    local id = runId

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        local round = 0
        local failures = {}

        while running and id == runId do
            round += 1
            local list = getCandyList()
            local attempted = 0

            if #list == 0 then
                status.Text = "No candy remaining!"
                break
            end

            for _, info in ipairs(list) do
                if not running or id ~= runId then
                    break
                end

                if not failures[info.candy] then
                    attempted += 1

                    status.Text = "Round: " .. round
                        .. " | Collected: " .. collected

                    local success = collect(info, id)

                    if success then
                        collected += 1
                        failures[info.candy] = nil
                    else
                        failures[info.candy] = true
                    end

                    task.wait(0.1)
                end
            end

            if not running or id ~= runId then
                break
            end

            -- Return home after every round
            teleport(HOME)
            task.wait(0.5)

            if #getCandyList() == 0 then
                status.Text = "Finished! Collected: " .. collected
                break
            end

            -- Avoid infinite retries on failed prompts
            if attempted == 0 then
                status.Text = "Some candies could not be collected"
                break
            end
        end

        if id == runId then
            stop()
        end
    end)
end)
