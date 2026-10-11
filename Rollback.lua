
-- Rollback Ride a Pet UI V2
-- GUI visibility fix

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer

if not Player then
    warn("[Rollback UI] LocalPlayer not found")
    return
end

local PlayerGui = Player:WaitForChild("PlayerGui")

-- Remove old GUI
local old = PlayerGui:FindFirstChild("RollbackRideAPet")
if old then
    old:Destroy()
end

-- Screen GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RollbackRideAPet"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true
ScreenGui.Parent = PlayerGui

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(250, 180)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(27, 31, 44)
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = true
Main.ZIndex = 10
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(65, 130, 255)
MainStroke.Thickness = 2
MainStroke.Parent = Main

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Rollback Ride a Pet"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.ZIndex = 11
Title.Active = true
Title.Parent = Main

-- Button creator
local function CreateButton(name, text, y, color)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Size = UDim2.new(1, -26, 0, 43)
    Button.Position = UDim2.fromOffset(13, y)
    Button.BackgroundColor3 = color
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 14
    Button.AutoButtonColor = true
    Button.ZIndex = 12
    Button.Parent = Main

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    return Button
end

-- Rollback Button
local RollbackButton = CreateButton(
    "RollbackButton",
    "Rollback: OFF",
    48,
    Color3.fromRGB(185, 55, 55)
)

-- Rejoin Button
local RejoinButton = CreateButton(
    "RejoinButton",
    "Rejoin Server",
    109,
    Color3.fromRGB(45, 125, 235)
)

-- Toggle State
local RollbackEnabled = false

local function UpdateButton()
    if RollbackEnabled then
        RollbackButton.Text = "Rollback: ON"
        RollbackButton.BackgroundColor3 =
            Color3.fromRGB(28, 190, 85)
    else
        RollbackButton.Text = "Rollback: OFF"
        RollbackButton.BackgroundColor3 =
            Color3.fromRGB(185, 55, 55)
    end
end

RollbackButton.MouseButton1Click:Connect(function()
    RollbackEnabled = not RollbackEnabled
    UpdateButton()

    print(
        "[Rollback UI] State:",
        RollbackEnabled
    )
end)

-- Rejoin System
local Rejoining = false

local function ResetRejoin()
    Rejoining = false
    RejoinButton.Text = "Rejoin Server"
end

TeleportService.TeleportInitFailed:Connect(
    function(player, result, message)
        if player == Player and Rejoining then
            warn("[Rollback UI] Teleport failed:", message)
            ResetRejoin()
        end
    end
)

RejoinButton.MouseButton1Click:Connect(function()
    if Rejoining then
        return
    end

    if game.PlaceId <= 0 then
        warn("[Rollback UI] Invalid PlaceId")
        return
    end

    Rejoining = true
    RejoinButton.Text = "Rejoining..."

    local success, err = pcall(function()
        TeleportService:Teleport(
            game.PlaceId,
            Player
        )
    end)

    if not success then
        warn("[Rollback UI] Rejoin error:", err)
        ResetRejoin()
    end
end)

-- Dragging System
local Dragging = false
local DragStart
local StartPos

Title.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.MouseButton1
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        Dragging = true
        DragStart = input.Position
        StartPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState ==
                Enum.UserInputState.End then

                Dragging = false
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if not Dragging then
        return
    end

    if input.UserInputType ==
        Enum.UserInputType.MouseMovement
        or input.UserInputType ==
        Enum.UserInputType.Touch then

        local delta = input.Position - DragStart

        Main.Position = UDim2.new(
            StartPos.X.Scale,
            StartPos.X.Offset + delta.X,
            StartPos.Y.Scale,
            StartPos.Y.Offset + delta.Y
        )
    end
end)

-- Initial State
UpdateButton()

-- Debug
print("[Rollback UI V2] Loaded successfully")
print("[Rollback UI V2] Parent:", ScreenGui.Parent)
print("[Rollback UI V2] Visible:", Main.Visible)
