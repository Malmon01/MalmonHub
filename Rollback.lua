-- โค้ดที่แก้ไขแล้ว (รันได้ปกติ)
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ลบ UI เก่าทิ้งก่อนสร้างใหม่ (ป้องกันซ้ำซ้อน)
if LocalPlayer.PlayerGui:FindFirstChild("RollbackScriptUI") then
    LocalPlayer.PlayerGui.RollbackScriptUI:Destroy()
end

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RollbackScriptUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 150)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- ทำให้หน้าต่างลากขยับได้ (เพิ่มความสะดวก)
mainFrame.Active = true
mainFrame.Draggable = true

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Text = "Rollback Ride a Pet"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = mainFrame

-- สถานะของ Rollback
local rollbackEnabled = false

-- ปุ่ม Rollback Toggle
local rollbackButton = Instance.new("TextButton")
rollbackButton.Size = UDim2.new(0.9, 0, 0, 35)
rollbackButton.Position = UDim2.new(0.05, 0, 0.3, 0)
rollbackButton.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
rollbackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollbackButton.Text = "Rollback: OFF"
rollbackButton.Font = Enum.Font.SourceSansBold
rollbackButton.TextSize = 14
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

-- ฟังก์ชันกดสลับเปิด/ปิด
rollbackButton.MouseButton1Click:Connect(function()
    rollbackEnabled = not rollbackEnabled
    if rollbackEnabled then
        rollbackButton.Text = "Rollback: ON"
        rollbackButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    else
        rollbackButton.Text = "Rollback: OFF"
        rollbackButton.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
    end
end)

-- ฟังก์ชันกดรีจอย
rejoinButton.MouseButton1Click:Connect(function()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end)

print("โหลด UI สำเร็จแล้ว!")
