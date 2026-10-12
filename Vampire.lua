local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local BOSS_NAME = "Housewife Mosquito"
local HITBOX_MULTIPLIER = 5
local DISTANCE = 3

local function FindBoss()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model")
            and string.find(
                string.lower(obj.Name),
                string.lower(BOSS_NAME),
                1,
                true
            ) then

            local root =
                obj:FindFirstChild("HumanoidRootPart", true)
                or obj.PrimaryPart
                or obj:FindFirstChildWhichIsA("BasePart", true)

            if root then
                return obj, root
            end
        end
    end

    return nil, nil
end

local OriginalSizes = {}

local function ExpandBoss()
    local boss, root = FindBoss()

    if not boss then
        warn("Boss not found!")
        return
    end

    if not OriginalSizes[root] then
        OriginalSizes[root] = root.Size
    end

    local original = OriginalSizes[root]

    root.Size = Vector3.new(
        original.X * HITBOX_MULTIPLIER,
        original.Y,
        original.Z * HITBOX_MULTIPLIER
    )

    root.CanCollide = false
    root.Transparency = 0.6

    print("Boss Hitbox Expanded!")
end

local function MoveNearBoss()
    local character = LocalPlayer.Character
    if not character then return end

    local playerRoot =
        character:FindFirstChild("HumanoidRootPart")

    local boss, bossRoot = FindBoss()

    if not playerRoot or not bossRoot then
        warn("Boss or player not found!")
        return
    end

    local direction = Vector3.new(
        playerRoot.Position.X - bossRoot.Position.X,
        0,
        playerRoot.Position.Z - bossRoot.Position.Z
    )

    if direction.Magnitude < 0.01 then
        direction = Vector3.new(1, 0, 0)
    end

    local position =
        bossRoot.Position
        + direction.Unit * DISTANCE
        + Vector3.new(0, -1, 0)

    playerRoot.CFrame =
        CFrame.lookAt(position, bossRoot.Position)
end

-- Expand hitbox
ExpandBoss()

-- Press V to move near boss
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.V then
        MoveNearBoss()
    end
end)
