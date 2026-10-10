
-- Candy Collector V3 | Test Version
-- Single LocalScript

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")

local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local HOME = root.CFrame

local running = false
local token = 0
local successes = 0
local shownPrompts = {}

-- Detect actual visible prompts
PPS.PromptShown:Connect(function(prompt)
    shownPrompts[prompt] = true
end)

PPS.PromptHidden:Connect(function(prompt)
    shownPrompts[prompt] = nil
end)

-- UI
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("CandyCollectorV3")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CandyCollectorV3"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(250, 205)
frame.Position = UDim2.new(0.5, -125, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeButton(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 45)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local homeBtn = makeButton(
    "HOME", 12, Color3.fromRGB(50, 110, 220)
)

local startBtn = makeButton(
    "START COLLECT", 67, Color3.fromRGB(35, 170, 90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 65)
status.Position = UDim2.fromOffset(10, 125)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.TextSize = 13
status.Text = "Ready | Home Saved"
status.Parent = frame

local function getRoot()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf)
    local r = getRoot()
    if r then
        r.CFrame = cf
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end
end

local function getPromptPosition(prompt)
    local parent = prompt.Parent

    if parent:IsA("Attachment") then
        return parent.WorldPosition
    elseif parent:IsA("BasePart") then
        return parent.Position
    end

    return nil
end

local function getCandies()
    local list = {}

    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            table.insert(list, obj)
        end
    end

    return list
end

local function stop()
    running = false
    token += 1
    startBtn.Text = "START COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(35, 170, 90)
end

local function attemptCollect(prompt, id)
    if not prompt:IsDescendantOf(folder) then
        return false
    end

    local pos = getPromptPosition(prompt)
    if not pos then
        status.Text = "Invalid prompt position"
        return false
    end

    -- Move within prompt range
    local distance = math.min(
        2,
        math.max(0.5, prompt.MaxActivationDistance * 0.5)
    )

    teleport(CFrame.new(
        pos + Vector3.new(0, 0, distance),
        pos
    ))

    status.Text = "Waiting for E prompt..."

    -- Wait until prompt is visible
    local deadline = os.clock() + 3

    while not shownPrompts[prompt] do
        if not running or id ~= token then
            return false
        end

        if os.clock() >= deadline then
            status.Text = "E prompt not visible"
            return false
        end

        task.wait(0.05)
    end

    if not running or id ~= token then
        return false
    end

    local triggered = false
    local conn = prompt.Triggered:Connect(function()
        triggered = true
    end)

    status.Text = "Holding E..."

    -- Begin hold
    prompt:InputHoldBegin()

    local elapsed = 0
    local holdTime = prompt.HoldDuration + 0.2

    while elapsed < holdTime do
        if not running or id ~= token then
            prompt:InputHoldEnd()
            conn:Disconnect()
            return false
        end

        if triggered then break end
        elapsed += task.wait(0.03)
    end

    -- Release after hold
    prompt:InputHoldEnd()

    local waitUntil = os.clock() + 1

    while not triggered and os.clock() < waitUntil do
        if not running or id ~= token then break end
        task.wait(0.05)
    end

    conn:Disconnect()

    return triggered
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
    token += 1
    local id = token

    startBtn.Text = "STOP COLLECT"
    startBtn.BackgroundColor3 = Color3.fromRGB(215, 55, 65)

    task.spawn(function()
        local failed = {}
        local round = 0

        while running and id == token do
            round += 1
            local prompts = getCandies()
            local attempted = 0

            if #prompts == 0 then
                status.Text = "No prompts remaining"
                break
            end

            for _, prompt in ipairs(prompts) do
                if not running or id ~= token then
                    break
                end

                if not failed[prompt] then
                    attempted += 1

                    local success = attemptCollect(prompt, id)

                    if success then
                        successes += 1
                        status.Text = "E triggered: " .. successes
                    else
                        failed[prompt] = true
                    end

                    task.wait(0.15)
                end
            end

            if not running or id ~= token then
                break
            end

            teleport(HOME)
            task.wait(0.5)

            if #getCandies() == 0 then
                status.Text = "Finished | E triggered: " .. successes
                break
            end

            if attempted == 0 then
                status.Text = "Test finished | E triggered: "
                    .. successes .. " | Some prompts remain"
                break
            end
        end

        if id == token then
            stop()
        end
    end)
end)
