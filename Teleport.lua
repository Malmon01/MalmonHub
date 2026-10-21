-- Folder Auto Warp | LocalScript / Executor
-- Default folder name is taken from the supplied Explorer screenshot.
-- The target folder must exist under Workspace for teleports to have a real location.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
    FolderName = "f2db5001-262",
    WarpHeight = 4,     -- studs above each target
    WarpDelay = 5.0,    -- seconds between targets
    RoundDelay = 2.0,   -- seconds after finishing a whole folder
    Repeat = true,     -- true = repeat forever while ON
}

local GUI_NAME = "FolderAutoWarpUI"
local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local running = false
local generation = 0
local minimized = false

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local gui = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local frame = make("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(316, 199),
    Position = UDim2.new(0.5, -158, 0.30, 0),
    BackgroundColor3 = Color3.fromRGB(24, 27, 36),
    BorderSizePixel = 0,
    Active = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, frame)
make("UIStroke", {Color = Color3.fromRGB(74, 83, 104), Thickness = 1}, frame)

local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    Active = true,
}, frame)
make("TextLabel", {
    Size = UDim2.new(1, -54, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "FOLDER AUTO WARP",
    TextColor3 = Color3.fromRGB(241, 244, 251),
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local minimizeBtn = make("TextButton", {
    Size = UDim2.fromOffset(34, 30),
    Position = UDim2.new(1, -42, 0, 7),
    BackgroundColor3 = Color3.fromRGB(48, 54, 69),
    Text = "−",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 21,
    Font = Enum.Font.GothamBold,
}, header)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, minimizeBtn)

local body = make("Frame", {
    Position = UDim2.fromOffset(12, 49),
    Size = UDim2.new(1, -24, 1, -59),
    BackgroundTransparency = 1,
}, frame)

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 19),
    BackgroundTransparency = 1,
    Text = "ชื่อโฟลเดอร์ใน Workspace",
    TextColor3 = Color3.fromRGB(180, 191, 209),
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, body)

local folderBox = make("TextBox", {
    Position = UDim2.fromOffset(0, 23),
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = Color3.fromRGB(40, 46, 60),
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Text = CONFIG.FolderName,
    PlaceholderText = "วางชื่อโฟลเดอร์...",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    PlaceholderColor3 = Color3.fromRGB(143, 152, 170),
    TextSize = 14,
    Font = Enum.Font.Code,
}, body)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, folderBox)

local toggle = make("TextButton", {
    Position = UDim2.fromOffset(0, 64),
    Size = UDim2.new(1, 0, 0, 37),
    BackgroundColor3 = Color3.fromRGB(37, 126, 84),
    BorderSizePixel = 0,
    Text = "▶  START AUTO WARP",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
}, body)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, toggle)

local status = make("TextLabel", {
    Position = UDim2.fromOffset(0, 106),
    Size = UDim2.new(1, 0, 0, 29),
    BackgroundTransparency = 1,
    Text = "พร้อมใช้งาน • รอเปิดระบบ",
    TextColor3 = Color3.fromRGB(179, 189, 207),
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
}, body)

local function setStatus(message)
    if status.Parent then status.Text = message end
end

local function updateToggle()
    toggle.Text = running and "■  STOP AUTO WARP" or "▶  START AUTO WARP"
    toggle.BackgroundColor3 = running and Color3.fromRGB(165, 61, 65) or Color3.fromRGB(37, 126, 84)
end

local lastFolder, lastFolderName
local function findFolder(name)
    if name == "" then return nil end
    if lastFolder and lastFolderName == name and lastFolder:IsDescendantOf(workspace) then
        return lastFolder
    end
    -- Search recursively because the Explorer screenshot does not show its parent path.
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Folder") and obj.Name == name then
            lastFolder, lastFolderName = obj, name
            return obj
        end
    end
    return nil
end

local function getTargetPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Attachment") then
        return obj.WorldPosition
    elseif obj:IsA("Model") then
        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if not part then return nil end
        local success, cf = pcall(function() return obj:GetPivot() end)
        return success and cf.Position or part.Position
    elseif obj:IsA("Tool") then
        local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end
    return nil
end

local function collectTargets(container, output)
    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Folder") then
            collectTargets(item, output)
        else
            local pos = getTargetPosition(item)
            if pos then
                table.insert(output, {instance = item, position = pos})
            end
        end
    end
end

local function warpTo(target)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return false, "รอตัวละครพร้อม"
    end
    local pos = getTargetPosition(target)
    if not pos then return false, "เป้าหมายหายไป" end
    character:PivotTo(CFrame.new(pos + Vector3.new(0, CONFIG.WarpHeight, 0)))
    root.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function waitCancelable(duration, token)
    local elapsed = 0
    while elapsed < duration do
        if not running or token ~= generation or not gui.Parent then return false end
        elapsed += task.wait(math.min(0.1, duration - elapsed))
    end
    return running and token == generation and gui.Parent ~= nil
end

local function runLoop(token, folderName)
    repeat
        if not running or token ~= generation then break end
        local folder = findFolder(folderName)
        if not folder then
            setStatus("ไม่พบโฟลเดอร์: " .. folderName)
            break
        end
        local targets = {}
        collectTargets(folder, targets)
        if #targets == 0 then
            setStatus("โฟลเดอร์ไม่มี Model/Part ที่วาร์ปได้")
            break
        end
        for index, entry in ipairs(targets) do
            if not running or token ~= generation then break end
            if entry.instance:IsDescendantOf(workspace) then
                local ok, err = warpTo(entry.instance)
                if ok then
                    setStatus(string.format("วาร์ป %d/%d : %s", index, #targets, entry.instance.Name))
                else
                    setStatus(err or "วาร์ปไม่สำเร็จ")
                end
            end
            if not waitCancelable(CONFIG.WarpDelay, token) then break end
        end
        if not CONFIG.Repeat or not running or token ~= generation then break end
    until not waitCancelable(CONFIG.RoundDelay, token)

    if token == generation then
        running = false
        updateToggle()
        if CONFIG.Repeat then
            -- Keep the error/status if a missing folder or an empty folder stopped the run.
        else
            setStatus("ครบทุกเป้าหมายแล้ว")
        end
    end
end

toggle.MouseButton1Click:Connect(function()
    if running then
        running = false
        generation += 1
        updateToggle()
        setStatus("หยุดวาร์ปแล้ว")
        return
    end
    local name = folderBox.Text:match("^%s*(.-)%s*$")
    if name == "" then
        setStatus("กรุณากรอกชื่อโฟลเดอร์")
        return
    end
    running = true
    generation += 1
    local token = generation
    updateToggle()
    setStatus("กำลังค้นหาโฟลเดอร์...")
    task.spawn(runLoop, token, name)
end)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = minimized and UDim2.fromOffset(316, 44) or UDim2.fromOffset(316, 199)
    minimizeBtn.Text = minimized and "+" or "−"
end)

-- Drag with mouse or touch.
local dragging = false
local dragStart, startPosition
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
local inputConnection = UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end)

gui.Destroying:Connect(function()
    running = false
    generation += 1
    inputConnection:Disconnect()
end)
