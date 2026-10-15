-- Hunter Auto Farm v2 | Roblox Lua / client-side
-- Target: workspace.NPCS.HUNTERS -> Model named "Hunter"
-- NOTE: Only confirms skill E animation if the real E AnimationId is provided.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
if not player then return end

local environment = (type(getgenv) == "function" and getgenv()) or _G
if type(environment.HunterAutoFarm_Close) == "function" then
    pcall(environment.HunterAutoFarm_Close)
end

local SAVE_FILE = "HunterAutoFarm_Settings.json"
local RANGES = {
    { min = 100, max = 399 },
    { min = 400, max = 999 },
    { min = 1000, max = 6000 }
}

local settings = {
    enabled = false,
    rangeIndex = 1,
    tweenSpeed = 100,  -- adjustable 10..500 studs/second
    underOffset = 5,   -- studs beneath the Hunter root
    mode = "tween",    -- tween or stationary (no movement)
    antiKnockback = true, -- reduce locally simulated fling; NOT server immunity
    antiIdle = true,   -- attempt to prevent the standard idle disconnect
    eAnimationId = "" -- exact AnimationId is needed to VERIFY E
}

local canSave = type(writefile) == "function" and type(readfile) == "function"
if canSave then
    pcall(function()
        if type(isfile) == "function" and not isfile(SAVE_FILE) then return end
        local loaded = HttpService:JSONDecode(readfile(SAVE_FILE))
        if type(loaded) ~= "table" then return end
        if type(loaded.enabled) == "boolean" then settings.enabled = loaded.enabled end
        if type(loaded.rangeIndex) == "number" then
            settings.rangeIndex = math.clamp(math.floor(loaded.rangeIndex), 1, #RANGES)
        end
        if type(loaded.tweenSpeed) == "number" then
            settings.tweenSpeed = math.clamp(math.floor(loaded.tweenSpeed), 10, 500)
        end
        if type(loaded.underOffset) == "number" then
            settings.underOffset = math.clamp(loaded.underOffset, 2, 12)
        end
        if loaded.mode == "tween" or loaded.mode == "stationary" then
            settings.mode = loaded.mode
        end
        if type(loaded.antiKnockback) == "boolean" then
            settings.antiKnockback = loaded.antiKnockback
        end
        if type(loaded.antiIdle) == "boolean" then
            settings.antiIdle = loaded.antiIdle
        end
        if type(loaded.eAnimationId) == "string" then
            settings.eAnimationId = loaded.eAnimationId:match("(%d+)") or ""
        end
    end)
end

local function saveSettings()
    if not canSave then return end
    pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(settings))
    end)
end

local state = {
    alive = true,
    tween = nil,
    goal = nil,
    target = nil,
    lastClick = 0,
    lastE = -math.huge,
    eBusy = false,
    info = "กำลังเริ่มระบบ",
    eInfo = "ยังไม่ได้กด E",
    connections = {},
    gui = nil
}

local function cancelTween()
    if state.tween then
        pcall(function() state.tween:Cancel() end)
    end
    state.tween = nil
    state.goal = nil
end

local function close()
    state.alive = false
    settings.enabled = false
    saveSettings()
    cancelTween()
    for _, connection in ipairs(state.connections) do
        pcall(function() connection:Disconnect() end)
    end
    if state.gui then
        pcall(function() state.gui:Destroy() end)
    end
end

environment.HunterAutoFarm_Close = close

local function alone()
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then return false end
    end
    return true
end

local function kickSelf()
    settings.enabled = false
    saveSettings()
    close()
    pcall(function()
        player:Kick("Hunter Auto Farm: มีผู้เล่นคนอื่นอยู่ในเซิร์ฟเวอร์")
    end)
end

-- Do not start the farm (or even display UI) in a server with other players.
if not alone() then
    kickSelf()
    return
end

table.insert(state.connections, Players.PlayerAdded:Connect(function(other)
    if other ~= player then kickSelf() end
end))

local function getRoot(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function characterRoot()
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return getRoot(character)
end

local function huntersFolder()
    local npcs = workspace:FindFirstChild("NPCS")
    return npcs and npcs:FindFirstChild("HUNTERS") or nil
end

local LEVEL_NAMES = { level = true, lvl = true, npclevel = true, enemylevel = true }
local cachedLevels = setmetatable({}, { __mode = "k" })

local function parseLevelText(value)
    local text = tostring(value):lower()
    return tonumber(text:match("level%s*[:%-]?%s*(%d+)")
        or text:match("lv%.?%s*[:%-]?%s*(%d+)"))
end

local function hunterLevel(model)
    local cached = cachedLevels[model]
    if cached and os.clock() - cached.at < 4 then return cached.level end
    local value
    for _, name in ipairs({ "Level", "Lvl", "NPCLevel", "EnemyLevel" }) do
        local v = model:GetAttribute(name)
        if v ~= nil then value = tonumber(v) or parseLevelText(v) end
        if value then break end
    end
    if not value then value = parseLevelText(model.Name) end
    if not value then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then value = parseLevelText(humanoid.DisplayName) end
    end
    if not value then
        for _, desc in ipairs(model:GetDescendants()) do
            if (desc:IsA("IntValue") or desc:IsA("NumberValue") or desc:IsA("StringValue"))
                and LEVEL_NAMES[desc.Name:lower()] then
                value = tonumber(desc.Value) or parseLevelText(desc.Value)
            elseif desc:IsA("TextLabel") or desc:IsA("TextButton") then
                value = parseLevelText(desc.Text)
            end
            if value then break end
        end
    end
    cachedLevels[model] = { at = os.clock(), level = value }
    return value
end

local function validTarget(model)
    if not model or model.Parent ~= huntersFolder() then return false end
    if not model:IsA("Model") or model.Name:lower() ~= "hunter" then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or not getRoot(model) then return false end
    local lvl = hunterLevel(model)
    local range = RANGES[settings.rangeIndex]
    return lvl ~= nil and lvl >= range.min and lvl <= range.max
end

local function closestHunter(fromRoot)
    local folder = huntersFolder()
    if not folder then return nil, "ไม่พบ workspace.NPCS.HUNTERS" end
    local nearest, shortest = nil, math.huge
    local unknownLevels = 0
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model.Name:lower() == "hunter" then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = getRoot(model)
            if hum and hum.Health > 0 and root then
                local lvl = hunterLevel(model)
                if not lvl then unknownLevels = unknownLevels + 1 end
                local range = RANGES[settings.rangeIndex]
                if lvl and lvl >= range.min and lvl <= range.max then
                    local distance = (root.Position - fromRoot.Position).Magnitude
                    if distance < shortest then
                        nearest, shortest = model, distance
                    end
                end
            end
        end
    end
    if nearest then return nearest, nil end
    if unknownLevels > 0 then
        return nil, "พบ Hunter แต่ยังอ่าน Level ไม่ได้ (" .. unknownLevels .. " ตัว)"
    end
    return nil, "ไม่พบ Hunter ในช่วงเลเวลที่เลือก"
end

local function attackM1()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(800, 600)
    local x, y = math.floor(size.X / 2), math.floor(size.Y / 2)
    -- Send a click in the center, not over the Auto Farm button.
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.06)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    if ok then return true end
    if type(mouse1click) == "function" then
        if type(mousemoveabs) == "function" then pcall(mousemoveabs, x, y) end
        return pcall(mouse1click)
    end
    return false
end

local function pressE()
    if type(keypress) == "function" and type(keyrelease) == "function" then
        return pcall(function()
            keypress(0x45)
            task.wait(0.08)
            keyrelease(0x45)
        end)
    end
    return pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function currentAnimator()
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    return hum and hum:FindFirstChildOfClass("Animator") or nil
end

-- E is only VERIFIED if the exact expected AnimationId starts playing.
-- Any other new AnimationId is shown as a candidate, not as proof.
local function useEAndCheck()
    local animator = currentAnimator()
    local expected = settings.eAnimationId
    local observed = {}
    local verified = false
    local connection
    if animator then
        connection = animator.AnimationPlayed:Connect(function(track)
            if track and track.Animation then
                local id = tostring(track.Animation.AnimationId):match("(%d+)")
                if id then
                    observed[id] = true
                    if expected ~= "" and id == expected then verified = true end
                end
            end
        end)
    end

    local pressed = pressE()
    if not pressed then
        state.eInfo = "ส่งปุ่ม E ไม่สำเร็จ (Executor ไม่รองรับ?)"
    else
        for _ = 1, 16 do
            if not state.alive then break end
            if verified then break end
            task.wait(0.10)
        end
        if verified then
            state.eInfo = "ยืนยัน E: เล่น AnimationId " .. expected .. " แล้ว"
        elseif not animator then
            state.eInfo = "กด E แล้ว แต่ไม่พบ Animator ให้ตรวจสอบ"
        else
            local found = {}
            for id in pairs(observed) do table.insert(found, id) end
            table.sort(found)
            if expected == "" then
                state.eInfo = #found > 0
                    and ("E ยังไม่ยืนยัน | ID ที่พบ: " .. table.concat(found, ", "))
                    or "E ยังไม่ยืนยัน | ใส่ AnimationId ของสกิล"
            else
                state.eInfo = "E ไม่พบ AnimationId ที่กำหนด: " .. expected
            end
        end
    end
    if connection then connection:Disconnect() end
    state.eBusy = false
end

local function changeTarget(target)
    if state.target ~= target then
        cancelTween()
        state.target = target
    end
end

local function moveBelow(root, npcRoot)
    local goal = npcRoot.CFrame * CFrame.new(0, -settings.underOffset, 0)
    local distance = (root.Position - goal.Position).Magnitude
    if distance <= 2.3 then
        if state.tween then cancelTween() end
        return true
    end
    if not state.goal or (state.goal.Position - goal.Position).Magnitude > 2.5 or not state.tween
        or state.tween.PlaybackState ~= Enum.PlaybackState.Playing then
        cancelTween()
        local duration = math.clamp(distance / settings.tweenSpeed, 0.08, 30)
        state.goal = goal
        state.tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = goal
        })
        state.tween:Play()
    end
    return false
end

local function makeGui(className, props, parent)
    local instance = Instance.new(className)
    for k, v in pairs(props) do instance[k] = v end
    instance.Parent = parent
    return instance
end

local guiParent = (type(gethui) == "function" and gethui()) or player:WaitForChild("PlayerGui")
local gui = makeGui("ScreenGui", {
    Name = "HunterAutoFarm_UI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, guiParent)
state.gui = gui

local panel = makeGui("Frame", {
    Size = UDim2.fromOffset(338, 449),
    Position = UDim2.fromOffset(20, 90),
    BackgroundColor3 = Color3.fromRGB(29, 32, 42),
    BorderSizePixel = 0
}, gui)
makeGui("UICorner", { CornerRadius = UDim.new(0, 9) }, panel)

local heading = makeGui("TextLabel", {
    Text = "HUNTER AUTO FARM", TextSize = 17, Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(240, 243, 250), BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(285, 32),
    TextXAlignment = Enum.TextXAlignment.Left
}, panel)

local closeButton = makeGui("TextButton", {
    Text = "X", TextSize = 16, Font = Enum.Font.GothamBold,
    BackgroundColor3 = Color3.fromRGB(95, 40, 49),
    TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    Position = UDim2.fromOffset(300, 9), Size = UDim2.fromOffset(26, 28)
}, panel)
makeGui("UICorner", { CornerRadius = UDim.new(0, 5) }, closeButton)

local function uiButton(y, height)
    local button = makeGui("TextButton", {
        Text = "", TextSize = 14, Font = Enum.Font.GothamSemibold,
        BackgroundColor3 = Color3.fromRGB(51, 60, 79),
        TextColor3 = Color3.fromRGB(245, 245, 245), BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(314, height)
    }, panel)
    makeGui("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
    return button
end

local rangeButton = uiButton(48, 37)
local farmButton = uiButton(92, 37)
local modeButton = uiButton(136, 35)

local speedLabel = makeGui("TextLabel", {
    Text = "ความเร็ว Tween (10 - 500)", TextSize = 13, Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(225, 231, 242), BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 178), Size = UDim2.fromOffset(226, 28),
    TextXAlignment = Enum.TextXAlignment.Left
}, panel)

local speedBox = makeGui("TextBox", {
    Text = tostring(settings.tweenSpeed), ClearTextOnFocus = false,
    TextSize = 14, Font = Enum.Font.GothamSemibold,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(51, 60, 79),
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(249, 179), Size = UDim2.fromOffset(77, 27)
}, panel)
makeGui("UICorner", { CornerRadius = UDim.new(0, 5) }, speedBox)

local speedTrack = makeGui("Frame", {
    Name = "SpeedTrack", Size = UDim2.fromOffset(310, 8),
    Position = UDim2.fromOffset(14, 218), BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(76, 84, 102)
}, panel)
makeGui("UICorner", { CornerRadius = UDim.new(1, 0) }, speedTrack)
local speedFill = makeGui("Frame", {
    Name = "SpeedFill", Size = UDim2.fromScale(0, 1),
    BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(65, 163, 242)
}, speedTrack)
makeGui("UICorner", { CornerRadius = UDim.new(1, 0) }, speedFill)
local speedThumb = makeGui("Frame", {
    Name = "Thumb", Size = UDim2.fromOffset(16, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0, 0.5), BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(230, 239, 248)
}, speedTrack)
makeGui("UICorner", { CornerRadius = UDim.new(1, 0) }, speedThumb)

local antiKnockbackButton = uiButton(244, 35)
local antiIdleButton = uiButton(286, 35)

local animBox = makeGui("TextBox", {
    Text = settings.eAnimationId,
    PlaceholderText = "AnimationId สกิล E (เพื่อยืนยันว่าเล่นจริง)",
    ClearTextOnFocus = false, TextSize = 13,
    Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(255, 255, 255),
    PlaceholderColor3 = Color3.fromRGB(165, 169, 177),
    BackgroundColor3 = Color3.fromRGB(51, 60, 79),
    BorderSizePixel = 0, Position = UDim2.fromOffset(12, 332),
    Size = UDim2.fromOffset(314, 34)
}, panel)
makeGui("UICorner", { CornerRadius = UDim.new(0, 6) }, animBox)

local statusLabel = makeGui("TextLabel", {
    Text = "", TextSize = 12, Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(220, 225, 238),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 378),
    Size = UDim2.fromOffset(314, 62)
}, panel)

local function repaint()
    if not state.alive then return end
    local range = RANGES[settings.rangeIndex]
    rangeButton.Text = ("Hunter Level: %d - %d  (คลิกเปลี่ยน)"):format(range.min, range.max)
    farmButton.Text = settings.enabled and "AUTO FARM: ON" or "AUTO FARM: OFF"
    farmButton.BackgroundColor3 = settings.enabled
        and Color3.fromRGB(38, 132, 86) or Color3.fromRGB(143, 56, 62)
    modeButton.Text = settings.mode == "tween"
        and "โหมด: Tween ไปใต้ Hunter" or "โหมด: อยู่กับที่ + กดหมัดอัตโนมัติ"
    antiKnockbackButton.Text = "ลดแรงกระเด็น: " .. (settings.antiKnockback and "ON" or "OFF")
    antiIdleButton.Text = "กัน AFK: " .. (settings.antiIdle and "ON" or "OFF")
    local ratio = (settings.tweenSpeed - 10) / 490
    speedFill.Size = UDim2.fromScale(ratio, 1)
    speedThumb.Position = UDim2.fromScale(ratio, 0.5)
    if not speedBox:IsFocused() then speedBox.Text = tostring(settings.tweenSpeed) end
    statusLabel.Text = ("%s\n%s\nตั้งค่า: %s | %d studs/s"):
        format(state.info, state.eInfo, canSave and "บันทึกได้" or "ไม่รองรับ", settings.tweenSpeed)
end

local function setTweenSpeed(value, save)
    local number = tonumber(value)
    if not number or number ~= number then return end
    settings.tweenSpeed = math.clamp(math.floor(number + 0.5), 10, 500)
    cancelTween() -- reroute at the new speed on the next farm tick
    if save then saveSettings() end
    repaint()
end

rangeButton.MouseButton1Click:Connect(function()
    settings.rangeIndex = settings.rangeIndex % #RANGES + 1
    changeTarget(nil)
    saveSettings()
    repaint()
end)

farmButton.MouseButton1Click:Connect(function()
    if not alone() then kickSelf() return end
    settings.enabled = not settings.enabled
    if settings.enabled then
        state.lastE = -math.huge
        state.info = "เริ่มค้นหา Hunter..."
    else
        state.info = "หยุด Auto Farm"
        changeTarget(nil)
    end
    saveSettings()
    repaint()
end)

modeButton.MouseButton1Click:Connect(function()
    settings.mode = settings.mode == "tween" and "stationary" or "tween"
    cancelTween()
    saveSettings()
    repaint()
end)

antiKnockbackButton.MouseButton1Click:Connect(function()
    settings.antiKnockback = not settings.antiKnockback
    saveSettings()
    repaint()
end)

antiIdleButton.MouseButton1Click:Connect(function()
    settings.antiIdle = not settings.antiIdle
    saveSettings()
    repaint()
end)

speedBox.FocusLost:Connect(function()
    setTweenSpeed(speedBox.Text, true)
    speedBox.Text = tostring(settings.tweenSpeed)
end)

local draggingSpeed = false
local function speedFromX(x, save)
    if speedTrack.AbsoluteSize.X <= 0 then return end
    local ratio = math.clamp((x - speedTrack.AbsolutePosition.X) / speedTrack.AbsoluteSize.X, 0, 1)
    setTweenSpeed(10 + ratio * 490, save)
end

local function speedBegin(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSpeed = true
        speedFromX(input.Position.X, false)
    end
end

table.insert(state.connections, speedTrack.InputBegan:Connect(speedBegin))
table.insert(state.connections, speedThumb.InputBegan:Connect(speedBegin))
table.insert(state.connections, UserInputService.InputChanged:Connect(function(input)
    if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        speedFromX(input.Position.X, false)
    end
end))
table.insert(state.connections, UserInputService.InputEnded:Connect(function(input)
    if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
        draggingSpeed = false
        saveSettings()
        repaint()
    end
end))

animBox.FocusLost:Connect(function()
    settings.eAnimationId = animBox.Text:match("(%d+)") or ""
    animBox.Text = settings.eAnimationId
    state.eInfo = settings.eAnimationId ~= ""
        and "พร้อมตรวจสอบ E AnimationId: " .. settings.eAnimationId
        or "ยังไม่ได้กำหนด AnimationId ของ E"
    saveSettings()
    repaint()
end)

closeButton.MouseButton1Click:Connect(close)

-- GUI drag from title bar only.
do
    local dragging, startMouse, startPanel
    table.insert(state.connections, heading.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startMouse = input.Position
            startPanel = panel.Position
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    c:Disconnect()
                end
            end)
        end
    end))
    table.insert(state.connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - startMouse
            panel.Position = UDim2.new(startPanel.X.Scale, startPanel.X.Offset + delta.X,
                startPanel.Y.Scale, startPanel.Y.Offset + delta.Y)
        end
    end))
end

-- This reduces local physics knockback, not server-authoritative knockback or anti-cheat kicks.
table.insert(state.connections, RunService.Heartbeat:Connect(function()
    if not state.alive or not settings.enabled or not settings.antiKnockback then return end
    local root = characterRoot()
    if not root then return end
    local vel = root.AssemblyLinearVelocity
    local angular = root.AssemblyAngularVelocity
    if vel.Magnitude > 75 then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if angular.Magnitude > 15 then
        root.AssemblyAngularVelocity = Vector3.zero
    end
end))

-- Prevent the standard Roblox idle timeout where supported; cannot override server kicks.
table.insert(state.connections, player.Idled:Connect(function()
    if not state.alive or not settings.antiIdle then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.12)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end))

repaint()

task.spawn(function()
    while state.alive do
        task.wait(0.15)
        if not state.alive then break end
        if not alone() then kickSelf() break end

        if not settings.enabled then
            state.info = "Auto Farm ปิดอยู่"
            repaint()
            continue
        end

        local root = characterRoot()
        if not root then
            state.info = "รอตัวละคร / Humanoid"
            cancelTween()
            repaint()
            continue
        end

        -- Stationary mode has no movement and doesn't require NPC level data.
        -- It only simulates M1/E; the game still decides attack range and damage.
        if settings.mode == "stationary" then
            changeTarget(nil)
            state.info = "ยืนต่อยอัตโนมัติ (โดนเฉพาะศัตรูในระยะจริง)"
            if not state.eBusy and os.clock() - state.lastClick >= 0.22 then
                state.lastClick = os.clock()
                attackM1()
            end
            if not state.eBusy and os.clock() - state.lastE >= 30 then
                state.lastE = os.clock()
                state.eBusy = true
                task.spawn(useEAndCheck)
            end
            repaint()
            continue
        end

        if not validTarget(state.target) then
            local target, reason = closestHunter(root)
            changeTarget(target)
            if not target then
                state.info = reason or "ไม่พบเป้าหมาย"
                repaint()
                continue
            end
        end

        local npcRoot = getRoot(state.target)
        if not npcRoot then
            changeTarget(nil)
            continue
        end

        local reached = moveBelow(root, npcRoot)
        if reached then
            state.info = "กำลังต่อย Hunter เลเวล " .. tostring(hunterLevel(state.target))
            if not state.eBusy and os.clock() - state.lastClick >= 0.22 then
                state.lastClick = os.clock()
                attackM1()
            end
            if not state.eBusy and os.clock() - state.lastE >= 30 then
                state.lastE = os.clock()
                state.eBusy = true
                task.spawn(useEAndCheck)
            end
        else
            state.info = "Tween ไปใต้ Hunter เลเวล " .. tostring(hunterLevel(state.target))
        end
        repaint()
    end
end)
