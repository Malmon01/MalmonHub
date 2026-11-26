-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ลบ UI เก่าออกก่อนหากมีการรันซ้ำ
if PlayerGui:FindFirstChild("TPWalkUI") then
    PlayerGui:FindFirstChild("TPWalkUI"):Destroy()
end

-- สร้าง ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPWalkUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- สร้างกรอบหลัก (Main Frame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 110)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -55)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- สร้างแถบหัวข้อ (Title Bar สำหรับจับลาก)
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -35, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "TPWalk (Speed: 10)"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 14
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- ปุ่มปิด UI (ปุ่ม X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -27, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- ปุ่มเปิด/ปิดการทำงาน (Toggle Button)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0.85, 0, 0, 45)
ToggleBtn.Position = UDim2.new(0.075, 0, 0.45, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleBtn.Text = "สถานะ: ปิด (OFF)"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 16
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

-- ระบบลากขยับ UI (รองรับทั้ง PC และ มือถือ)
local dragging = false
local dragInput, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ตัวแปรควบคุม TPWalk
local tpWalkEnabled = false
local tpSpeed = 10
local loopConnection = nil

-- ฟังก์ชันเปิด/ปิด Loop
local function toggleTPWalk()
    tpWalkEnabled = not tpWalkEnabled
    
    if tpWalkEnabled then
        ToggleBtn.Text = "สถานะ: เปิด (ON)"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        
        -- เริ่มลูปแบบต่อเนื่องตามเฟรมเรต (Heartbeat)
        loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local hrp = character:FindFirstChild("HumanoidRootPart")
                
                if humanoid and hrp and humanoid.MoveDirection.Magnitude > 0 then
                    -- คำนวณระยะทางที่ขยับตามทิศทางที่เดินคูณความเร็ว 10
                    hrp.CFrame = hrp.CFrame + (humanoid.MoveDirection * tpSpeed * deltaTime * 10)
                end
            end
        end)
    else
        ToggleBtn.Text = "สถานะ: ปิด (OFF)"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        
        -- หยุดลูปเมื่อกดปิด
        if loopConnection then
            loopConnection:Disconnect()
            loopConnection = nil
        end
    end
end

-- เชื่อมต่อปุ่มกด
ToggleBtn.MouseButton1Click:Connect(toggleTPWalk)

CloseBtn.MouseButton1Click:Connect(function()
    if loopConnection then
        loopConnection:Disconnect()
    end
    ScreenGui:Destroy()
end)
