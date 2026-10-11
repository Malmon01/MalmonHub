-- ตัวอย่างสคริปต์จำลองการทำระบบ Rollback Toggle & Rejoin สำหรับ Executor (Luau)
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- สถานะของ Rollback
local rollbackEnabled = false

-- สร้าง ScreenGui สำหรับจำลอง UI ตามภาพ
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RollbackScriptUI"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 150)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Text = "Rollback Ride a Pet"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = mainFrame

-- ปุ่ม Rollback Toggle
local rollbackButton = Instance.new("TextButton")
rollbackButton.Size = UDim2.new(0.9, 0, 0, 35)
rollbackButton.Position = UDim2.new(0.05, 0, 0.3, 0)
rollbackButton.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
rollbackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollbackButton.Text = "Rollback: OFF"
rollbackButton.Font = Enum.Font.SourceSansBold
rollbackButton.TextSize:eq?.TextSize = 14 or 14
rollbackButton.Parent = mainFrame

-- ปุ่ม Rejoin Server
local rejoinButton = Instance.new("TextButton")
rejoinButton.Size = UDim2.new(0.9, 0, 0, 35)
rejoinButton.Position = UDim2.new(0.05, 0, 0.65, 0)
rejoinButton.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
rejoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinButton.Text = "Rejoin Server"
rejoinButton.Font = Enum.Font.SourceSansBold
rejoinButton.TextSize = 14
rejoinButton.Parent = mainFrame

-- ฟังก์ชันสลับสถานะ Rollback
rollbackButton.MouseButton1Click:Connect(function()
    rollbackEnabled = not rollbackEnabled
    if rollbackEnabled then
        rollbackButton.Text = "Rollback: ON"
        rollbackButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        print("[System] Rollback Mode Activated: ดักจับและหน่วงเวลาการส่งแพ็กเกจเซฟข้อมูล")
    else
        rollbackButton.Text = "Rollback: OFF"
        rollbackButton.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        print("[System] Rollback Mode Deactivated")
    end
end)

-- ฟังก์ชันกด Rejoin เพื่อรีเซิร์ฟเวอร์หนีการบันทึกสถานะฝั่งเซิร์ฟเวอร์
rejoinButton.MouseButton1Click:Connect(function()
    print("[System] กำลังรีจอยเข้าเซิร์ฟเวอร์ใหม่...")
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not success then
        -- ถ้าเข้าเซิร์ฟเวอร์เดิมไม่ได้ ให้สุ่มเข้าเซิร์ฟเวอร์ใหม่แทน
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end)
