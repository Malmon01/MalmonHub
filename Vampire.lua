local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local BOSS_NAME = "Housewife Mosquito"
local ATTACK_DISTANCE = 2.5
local UPDATE_INTERVAL = 0.15

local Enabled = false
local CurrentBoss = nil
local Moving = false

local function GetCharacter()
    local character = LocalPlayer.Character
    if not character then return nil, nil end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    return root, humanoid
end

local function FindBoss()
    local playerRoot = GetCharacter()
    local nearest = nil
    local nearestDistance = math.huge

    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") then

            local humanoid =
                model:FindFirstChildOfClass("Humanoid")

            local nameMatch =
                string.find(
                    string.lower(model.Name),
                    string.lower(BOSS_NAME),
                    1,
                    true
                )

            local displayMatch = humanoid and
                string.find(
                    string.lower(humanoid.DisplayName),
                    string.lower(BOSS_NAME),
                    1,
                    true
                )

            if nameMatch or displayMatch then

                local root =
                    model:FindFirstChild("HumanoidRootPart", true)
                    or model.PrimaryPart

                if root and
                    (not humanoid or humanoid.Health > 0) then

                    local distance = playerRoot
                        and (root.Position - playerRoot.Position).Magnitude
                        or 0

                    if distance < nearestDistance then
                        nearest = root
                        nearestDistance = distance
                    end
                end
            end
        end
    end

    return nearest
end

local function StopMoving()
    local root, humanoid = GetCharacter()

    if root and humanoid then
        humanoid:MoveTo(root.Position)
    end

    Moving = false
end

local elapsed = 0
local searchElapsed = 1

RunService.Heartbeat:Connect(function(dt)
    if not Enabled then return end

    elapsed = elapsed + dt
    searchElapsed = searchElapsed + dt

    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0

    local root, humanoid = GetCharacter()
    if not root or not humanoid then return end
    if humanoid.Health <= 0 then return end

    if searchElapsed >= 1
        or not CurrentBoss
        or not CurrentBoss.Parent then

        CurrentBoss = FindBoss()
        searchElapsed = 0
    end

    if not CurrentBoss then
        if Moving then StopMoving() end
        return
    end

    local offset = Vector3.new(
        root.Position.X - CurrentBoss.Position.X,
        0,
        root.Position.Z - CurrentBoss.Position.Z
    )

    local distance = offset.Magnitude

    if distance > ATTACK_DISTANCE + 0.3 then

        local direction = distance > 0.01
            and offset.Unit
            or Vector3.new(1, 0, 0)

        local target =
            CurrentBoss.Position
            + direction * ATTACK_DISTANCE

        humanoid:MoveTo(Vector3.new(
            target.X,
            root.Position.Y,
            target.Z
        ))

        Moving = true

    elseif Moving then
        StopMoving()
    end
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.V then
        Enabled = not Enabled

        if Enabled then
            CurrentBoss = FindBoss()
            print("Boss Follow: ON")
        else
            StopMoving()
            print("Boss Follow: OFF")
        end
    end
end)

print("Loaded! Press V to toggle Boss Follow")
