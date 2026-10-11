
-- Rollback Ride a Pet UI
-- Roblox Luau

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- GUI Parent
local GUIParent = PlayerGui

pcall(function()
    if typeof(gethui) == "function" then
        GUIParent = gethui()
    end
end)

-- Remove old UI
local old = GUIParent:FindFirstChild("RollbackRideAPetUI")
if old then
    old:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RollbackRideAPetUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = GUIParent

-- Main Window
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(240, 174)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(27, 33, 46)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(65, 122, 255)
Stroke.Thickness = 2.5
Stroke.Parent = Main

-- Header
local Header = Instance.new("TextLabel")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundTransparency = 1
Header.Text = "Rollback Ride a Pet"
Header.TextColor3 = Color3.new(1, 1, 1)
Header.TextSize = 15
Header.Font = Enum.Font.GothamBold
Header.Parent = Main

-- Rollback Button
local RollbackButton = Instance.new("TextButton")
RollbackButton.Name = "RollbackButton"
RollbackButton.Size = UDim2.new(1, -26, 0, 43)
RollbackButton.Position = UDim2.fromOffset(13, 49)
RollbackButton.BackgroundColor3 = Color3.fromRGB(35, 185, 90)
RollbackButton.BorderSizePixel = 0
RollbackButton.Text = "Rollback: OFF"
RollbackButton.TextColor3 = Color3.new(1, 1, 1)
RollbackButton.Font = Enum.Font.GothamBold
RollbackButton.TextSize = 14
RollbackButton.AutoButtonColor = true
RollbackButton.Parent = Main

local RollbackCorner = Instance.new("UICorner")
RollbackCorner.CornerRadius = UDim.new(0, 7)
RollbackCorner.Parent = RollbackButton

-- Rejoin Button
local RejoinButton = Instance.new("TextButton")
RejoinButton.Name = "RejoinButton"
RejoinButton.Size = UDim2.new(1, -26, 0, 43)
RejoinButton.Position = UDim2.fromOffset(13, 109)
RejoinButton.BackgroundColor3 = Color3.fromRGB(44, 127, 235)
RejoinButton.BorderSizePixel = 0
RejoinButton.Text = "Rejoin Server"
RejoinButton.TextColor3 = Color3.new(1, 1, 1)
RejoinButton.Font = Enum.Font.GothamBold
RejoinButton.TextSize = 14
RejoinButton.AutoButtonColor = true
RejoinButton.Parent = Main

local RejoinCorner = Instance.new("UICorner")
RejoinCorner.CornerRadius = UDim.new(0, 7)
RejoinCorner.Parent = RejoinButton

-- Rollback state
local RollbackEnabled = false

local function UpdateRollback()
    if RollbackEnabled then
        RollbackButton.Text = "Rollback: ON"
        RollbackButton.BackgroundColor3 =
            Color3.fromRGB(35, 185, 90)
    else
        RollbackButton.Text = "Rollback: OFF"
        RollbackButton.BackgroundColor3 =
            Color3.fromRGB(185, 55, 55)
    end
end

RollbackButton.MouseButton1Click:Connect(function()
    RollbackEnabled = not RollbackEnabled
    UpdateRollback()
end)

UpdateRollback()

-- Rejoin Game
local Rejoining = false

RejoinButton.MouseButton1Click:Connect(function()
    if Rejoining then return end
    Rejoining = true

    RejoinButton.Text = "Rejoining..."

    local success, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, Player)
    end)

    if not success then
        warn("Rejoin failed:", err)
        Rejoining = false
        RejoinButton.Text = "Rejoin Failed"

        task.delay(2, function()
            if RejoinButton.Parent then
                RejoinButton.Text = "Rejoin Server"
            end
        end)
    end
end)

-- Draggable UI
local Dragging = false
local DragStart
local StartPosition

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPosition = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                Dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not Dragging then return end

    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then

        local Delta = input.Position - DragStart

        Main.Position = UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + Delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + Delta.Y
        )
    end
end)

print("Rollback Ride a Pet UI Loaded")
