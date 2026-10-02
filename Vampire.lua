--============================================================
-- AUTO HUNTER REAR REACH FARM
-- Standalone GitHub / loadstring version
--
-- New approach:
--   • NO freeze
--   • NO moving NPCs
--   • NO blink in/out for every punch
--   • Player stays behind the real Hunter continuously
--   • Combat uses the NEW Game15Fists CombatRemote:
--       CombatRemote:FireServer("Attack")
--   • AUTO RANGE learns the farthest distance that still damages
--     the target, then keeps the player there.
--   • Auto Money remains available.
--   • Auto Blood removed completely.
--
-- Hunter levels:
--   100-300
--   400-900
--   1000-3000
--============================================================

--------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------------------
-- CLEAN OLD VERSION
--------------------------------------------------------------

local ENV = _G

pcall(function()
	if getgenv then
		ENV = getgenv()
	end
end)

if ENV.AutoHunterFarmStop then
	pcall(ENV.AutoHunterFarmStop)
end

local OldGUI = PlayerGui:FindFirstChild("AutoHunterFarmGUI")
if OldGUI then
	OldGUI:Destroy()
end

--------------------------------------------------------------
-- GAME OBJECTS
--------------------------------------------------------------

local NPCS = workspace:FindFirstChild("NPCS")
local HUNTERS = NPCS and NPCS:FindFirstChild("HUNTERS")
local DROPPED_MONEY = workspace:FindFirstChild("DroppedMoney")

--------------------------------------------------------------
-- NEW COMBAT REMOTE
--------------------------------------------------------------

local CombatRemote = nil

local function ResolveCombatRemote()
	local Funcoes =
		ReplicatedStorage:FindFirstChild(
			"Fun\195\167\195\181es"
		)

	if not Funcoes then
		CombatRemote = nil
		return nil
	end

	local Game15Fists =
		Funcoes:FindFirstChild("Game15Fists")

	if not Game15Fists then
		CombatRemote = nil
		return nil
	end

	local Remote =
		Game15Fists:FindFirstChild("CombatRemote")

	if Remote and Remote:IsA("RemoteEvent") then
		CombatRemote = Remote
		return Remote
	end

	CombatRemote = nil
	return nil
end

ResolveCombatRemote()

--------------------------------------------------------------
-- LEVEL PRESETS
--------------------------------------------------------------

local LEVEL_PRESETS = {
	{
		Name = "100-300",
		Min = 100,
		Max = 300
	},
	{
		Name = "400-900",
		Min = 400,
		Max = 900
	},
	{
		Name = "1000-3000",
		Min = 1000,
		Max = 3000
	}
}

local SelectedPreset = 1

--------------------------------------------------------------
-- REAR FARM SETTINGS
--------------------------------------------------------------

-- Start here. Auto Range can move this farther/closer.
local ATTACK_DISTANCE = 3.80

-- Never go closer/farther than these values.
local MIN_ATTACK_DISTANCE = 2.55
local MAX_ATTACK_DISTANCE = 5.50

-- Manual +/- adjustment.
local MANUAL_DISTANCE_STEP = 0.15

-- Auto Range adjustments.
local AUTO_RANGE = true
local AUTO_RANGE_UP_STEP = 0.10
local AUTO_RANGE_DOWN_STEP = 0.20

-- Number of confirmed hits before testing a slightly farther distance.
local HITS_BEFORE_RANGE_UP = 5

-- Number of attack attempts with no HP decrease before moving closer.
local MISSES_BEFORE_RANGE_DOWN = 3

-- New combat reports M1 duration around 0.42 sec.
local ATTACK_INTERVAL = 0.44

-- How quickly player keeps itself behind the moving Hunter.
local FOLLOW_INTERVAL = 0.018

-- Re-evaluate target.
local TARGET_RECHECK_INTERVAL = 0.40

-- Keep Fists equipped.
local EQUIP_CHECK_INTERVAL = 0.18

--------------------------------------------------------------
-- SAFETY SETTINGS
--------------------------------------------------------------

-- Prefer Hunter with fewer other Hunters nearby.
local DANGER_RADIUS = 10.0

-- Target switch only when current target is crowded.
local DANGER_SWITCH_THRESHOLD = 3

-- If player takes damage, briefly move a little farther away.
local DAMAGE_EVADE_TIME = 0.30
local DAMAGE_DISTANCE_BONUS = 0.80

--------------------------------------------------------------
-- MONEY SETTINGS
--------------------------------------------------------------

local AUTO_MONEY = true
local MONEY_SCAN_INTERVAL = 0.35
local MONEY_TOUCH_COOLDOWN = 0.40

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------

local Enabled = false
local Running = true

local CurrentTarget = nil

local LastAttack = 0
local LastTargetRecheck = 0
local LastEquipCheck = 0
local LastMoneyScan = 0
local LastCombatResolve = 0

local EvadeUntil = 0
local LastPlayerHealth = nil

local LastTargetHealth = nil
local AttackAttemptsWithoutDamage = 0
local ConfirmedHitStreak = 0

local MoneyAttempt =
	setmetatable(
		{},
		{
			__mode = "k"
		}
	)

--------------------------------------------------------------
-- CHARACTER HELPERS
--------------------------------------------------------------

local function GetCharacter()
	local Character =
		Player.Character
		or Player.CharacterAdded:Wait()

	local Humanoid =
		Character:FindFirstChildOfClass("Humanoid")

	local Root =
		Character:FindFirstChild("HumanoidRootPart")

	return Character, Humanoid, Root
end

local function SetCharacterCFrame(Root, CFrameValue)
	if not Root
		or not Root.Parent then
		return
	end

	Root.CFrame = CFrameValue
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
end

local function HorizontalUnit(Vector)
	local Flat =
		Vector3.new(
			Vector.X,
			0,
			Vector.Z
		)

	if Flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return Flat.Unit
end

--------------------------------------------------------------
-- MODEL / HUNTER HELPERS
--------------------------------------------------------------

local function GetModelRoot(Model)
	if not Model then
		return nil
	end

	return
		Model:FindFirstChild("HumanoidRootPart")
		or Model:FindFirstChild("UpperTorso")
		or Model:FindFirstChild("Torso")
		or Model.PrimaryPart
end

local function GetHunterRoot(Hunter)
	return GetModelRoot(Hunter)
end

--------------------------------------------------------------
-- HUNTER LEVEL
--------------------------------------------------------------

local function GetHunterLevel(Hunter)
	if not Hunter then
		return nil
	end

	----------------------------------------------------------
	-- Attributes
	----------------------------------------------------------

	for _, Name in ipairs({
		"Level",
		"Lvl",
		"level",
		"lvl"
	}) do
		local Value = Hunter:GetAttribute(Name)

		if typeof(Value) == "number" then
			return math.floor(Value)

		elseif typeof(Value) == "string" then
			local Number = tonumber(Value)

			if Number then
				return math.floor(Number)
			end
		end
	end

	----------------------------------------------------------
	-- Value objects
	----------------------------------------------------------

	for _, Object in ipairs(Hunter:GetDescendants()) do
		if Object:IsA("IntValue")
			or Object:IsA("NumberValue")
			or Object:IsA("StringValue") then

			local Name = string.lower(Object.Name)

			if Name == "level"
				or Name == "lvl" then

				local Number =
					tonumber(Object.Value)

				if Number then
					return math.floor(Number)
				end
			end
		end
	end

	----------------------------------------------------------
	-- Text above head
	----------------------------------------------------------

	for _, Object in ipairs(Hunter:GetDescendants()) do
		if Object:IsA("TextLabel")
			or Object:IsA("TextButton") then

			local Text = tostring(Object.Text)

			local Level =
				string.match(
					Text,
					"[Ll][Vv]%s*%.?%s*(%d+)"
				)

			if not Level then
				Level =
					string.match(
						Text,
						"[Ll]evel%s*(%d+)"
					)
			end

			if Level then
				return tonumber(Level)
			end
		end
	end

	return nil
end

--------------------------------------------------------------
-- TARGET FILTER
--------------------------------------------------------------

local function IsCorrectLevel(Hunter)
	local Preset =
		LEVEL_PRESETS[SelectedPreset]

	local Level =
		GetHunterLevel(Hunter)

	if not Level then
		return false
	end

	return
		Level >= Preset.Min
		and Level <= Preset.Max
end

local function IsValidHunter(Hunter)
	if not Hunter
		or not Hunter:IsA("Model") then
		return false
	end

	-- Hunter only; HunterBow ignored.
	if Hunter.Name ~= "Hunter" then
		return false
	end

	local Humanoid =
		Hunter:FindFirstChildOfClass("Humanoid")

	local Root =
		GetHunterRoot(Hunter)

	if not Humanoid
		or Humanoid.Health <= 0
		or not Root then
		return false
	end

	return IsCorrectLevel(Hunter)
end

--------------------------------------------------------------
-- THREAT COUNT
--------------------------------------------------------------

local function CountNearbyHunters(
	Position,
	ExcludeHunter,
	Radius
)
	if not HUNTERS then
		return 0, math.huge
	end

	local Count = 0
	local Nearest = math.huge

	for _, Hunter in ipairs(HUNTERS:GetChildren()) do
		if Hunter ~= ExcludeHunter
			and Hunter:IsA("Model")
			and (
				Hunter.Name == "Hunter"
				or Hunter.Name == "HunterBow"
			) then

			local Humanoid =
				Hunter:FindFirstChildOfClass("Humanoid")

			local Root =
				GetHunterRoot(Hunter)

			if Humanoid
				and Humanoid.Health > 0
				and Root then

				local Distance =
					(
						Root.Position
						- Position
					).Magnitude

				if Distance < Nearest then
					Nearest = Distance
				end

				if Distance <= Radius then
					Count += 1
				end
			end
		end
	end

	return Count, Nearest
end

--------------------------------------------------------------
-- SAFEST TARGET
--------------------------------------------------------------

local function GetTargetSafetyScore(
	Hunter,
	PlayerRoot
)
	local Root =
		GetHunterRoot(Hunter)

	if not Root then
		return math.huge, 999
	end

	local ThreatCount,
		NearestThreat =
		CountNearbyHunters(
			Root.Position,
			Hunter,
			DANGER_RADIUS
		)

	local TravelDistance =
		(
			Root.Position
			- PlayerRoot.Position
		).Magnitude

	-- Lower is safer.
	local Score =
		ThreatCount * 100

	if NearestThreat < DANGER_RADIUS then
		Score +=
			(
				DANGER_RADIUS
				- NearestThreat
			)
			* 5
	end

	-- Distance is a small tie breaker only.
	Score +=
		TravelDistance * 0.02

	return Score, ThreatCount
end

local function FindSafestHunter(PlayerRoot)
	if not HUNTERS then
		return nil, 0
	end

	local BestHunter = nil
	local BestScore = math.huge
	local BestThreatCount = 0

	for _, Hunter in ipairs(HUNTERS:GetChildren()) do
		if IsValidHunter(Hunter) then
			local Score,
				ThreatCount =
				GetTargetSafetyScore(
					Hunter,
					PlayerRoot
				)

			if Score < BestScore then
				BestScore = Score
				BestHunter = Hunter
				BestThreatCount = ThreatCount
			end
		end
	end

	return BestHunter, BestThreatCount
end

--------------------------------------------------------------
-- GROUND ADJUSTMENT
--------------------------------------------------------------

local function GetGroundAdjustedPosition(
	Position,
	Character,
	PlayerRoot,
	Humanoid
)
	local Params =
		RaycastParams.new()

	Params.FilterType =
		Enum.RaycastFilterType.Exclude

	Params.FilterDescendantsInstances = {
		Character
	}

	local Result =
		workspace:Raycast(
			Position
			+ Vector3.new(0, 6, 0),

			Vector3.new(0, -20, 0),

			Params
		)

	if Result then
		local Y =
			Result.Position.Y
			+ Humanoid.HipHeight
			+ PlayerRoot.Size.Y * 0.5

		return
			Vector3.new(
				Position.X,
				Y,
				Position.Z
			)
	end

	return Position
end

--------------------------------------------------------------
-- CONSTANT REAR POSITION
--------------------------------------------------------------

local function GetRearCFrame(
	Hunter,
	Character,
	Humanoid,
	PlayerRoot
)
	local HunterRoot =
		GetHunterRoot(Hunter)

	if not HunterRoot
		or not Character
		or not Humanoid
		or not PlayerRoot then

		return nil
	end

	local Forward =
		HorizontalUnit(
			HunterRoot.CFrame.LookVector
		)

	-- Behind Hunter.
	local Back =
		-Forward

	local Distance =
		ATTACK_DISTANCE

	-- Temporary safety boost after taking damage.
	if os.clock() < EvadeUntil then
		Distance =
			math.min(
				MAX_ATTACK_DISTANCE,
				ATTACK_DISTANCE
					+ DAMAGE_DISTANCE_BONUS
			)
	end

	local Position =
		HunterRoot.Position
		+ Back * Distance

	Position =
		GetGroundAdjustedPosition(
			Position,
			Character,
			PlayerRoot,
			Humanoid
		)

	return
		CFrame.lookAt(
			Position,
			HunterRoot.Position
		)
end

--------------------------------------------------------------
-- FISTS
--------------------------------------------------------------

local function EquipFists(
	Character,
	Humanoid
)
	if not Character
		or not Humanoid
		or Humanoid.Health <= 0 then
		return nil
	end

	local Fists =
		Character:FindFirstChild("Fists")

	if Fists
		and Fists:IsA("Tool") then
		return Fists
	end

	local Backpack =
		Player:FindFirstChild("Backpack")

	if not Backpack then
		return nil
	end

	Fists =
		Backpack:FindFirstChild("Fists")

	if not Fists
		or not Fists:IsA("Tool") then
		return nil
	end

	pcall(function()
		Humanoid:EquipTool(Fists)
	end)

	task.wait(0.025)

	return
		Character:FindFirstChild("Fists")
end

local function ForceEquipFists()
	local Character,
		Humanoid =
		GetCharacter()

	return
		EquipFists(
			Character,
			Humanoid
		)
end

--------------------------------------------------------------
-- ATTACK
--------------------------------------------------------------

local function FireAttack()
	local Remote =
		CombatRemote

	if not Remote
		or not Remote.Parent then

		Remote =
			ResolveCombatRemote()
	end

	if not Remote then
		return false
	end

	local Success =
		pcall(function()
			Remote:FireServer("Attack")
		end)

	return Success
end

--------------------------------------------------------------
-- AUTO RANGE
--------------------------------------------------------------

local function ResetRangeLearning(
	TargetHumanoid
)
	AttackAttemptsWithoutDamage = 0
	ConfirmedHitStreak = 0

	if TargetHumanoid then
		LastTargetHealth =
			TargetHumanoid.Health
	else
		LastTargetHealth = nil
	end
end

local function ObserveTargetDamage(
	TargetHumanoid
)
	if not TargetHumanoid then
		return
	end

	local CurrentHealth =
		TargetHumanoid.Health

	if not LastTargetHealth then
		LastTargetHealth =
			CurrentHealth

		return
	end

	----------------------------------------------------------
	-- HP decreased = attack distance is working.
	----------------------------------------------------------

	if CurrentHealth
		< LastTargetHealth then

		AttackAttemptsWithoutDamage = 0
		ConfirmedHitStreak += 1

		------------------------------------------------------
		-- Slowly probe for a farther working range.
		------------------------------------------------------

		if AUTO_RANGE
			and ConfirmedHitStreak
				>= HITS_BEFORE_RANGE_UP then

			ConfirmedHitStreak = 0

			ATTACK_DISTANCE =
				math.clamp(
					ATTACK_DISTANCE
						+ AUTO_RANGE_UP_STEP,

					MIN_ATTACK_DISTANCE,

					MAX_ATTACK_DISTANCE
				)
		end
	end

	LastTargetHealth =
		CurrentHealth
end

local function RegisterAttackAttempt()
	AttackAttemptsWithoutDamage += 1

	if AUTO_RANGE
		and AttackAttemptsWithoutDamage
			>= MISSES_BEFORE_RANGE_DOWN then

		AttackAttemptsWithoutDamage = 0
		ConfirmedHitStreak = 0

		ATTACK_DISTANCE =
			math.clamp(
				ATTACK_DISTANCE
					- AUTO_RANGE_DOWN_STEP,

				MIN_ATTACK_DISTANCE,

				MAX_ATTACK_DISTANCE
			)
	end
end

--------------------------------------------------------------
-- MONEY
--------------------------------------------------------------

local function GetMoneyPart(Bag)
	if Bag:IsA("BasePart") then
		return Bag
	end

	if Bag:IsA("Model") then
		if Bag.PrimaryPart then
			return Bag.PrimaryPart
		end

		return
			Bag:FindFirstChildWhichIsA(
				"BasePart",
				true
			)
	end

	return
		Bag:FindFirstChildWhichIsA(
			"BasePart",
			true
		)
end

local function CollectBag(
	Bag,
	PlayerRoot
)
	local Part =
		GetMoneyPart(Bag)

	if not Part
		or not PlayerRoot then
		return false
	end

	local Now = os.clock()

	if MoneyAttempt[Bag]
		and Now
			- MoneyAttempt[Bag]
			< MONEY_TOUCH_COOLDOWN then

		return false
	end

	MoneyAttempt[Bag] = Now

	-- Keep the player behind Hunter; do not teleport away for money.
	if type(firetouchinterest) == "function" then
		pcall(function()
			firetouchinterest(
				PlayerRoot,
				Part,
				0
			)

			task.wait()

			firetouchinterest(
				PlayerRoot,
				Part,
				1
			)
		end)

		return true
	end

	return false
end

local function CollectMoney()
	if not AUTO_MONEY
		or not DROPPED_MONEY
		or not DROPPED_MONEY.Parent then

		return 0
	end

	local Character,
		Humanoid,
		PlayerRoot =
		GetCharacter()

	if not PlayerRoot
		or not Humanoid
		or Humanoid.Health <= 0 then

		return 0
	end

	local Count = 0

	for _, Object in ipairs(
		DROPPED_MONEY:GetChildren()
	) do
		if Object.Name == "KillMoneyBag" then
			if CollectBag(
				Object,
				PlayerRoot
			) then

				Count += 1
			end
		end
	end

	return Count
end

--==============================================================
-- GUI
--==============================================================

local GUI =
	Instance.new("ScreenGui")

GUI.Name = "AutoHunterFarmGUI"
GUI.ResetOnSpawn = false
GUI.Parent = PlayerGui

--------------------------------------------------------------
-- OPEN
--------------------------------------------------------------

local Open =
	Instance.new("TextButton")

Open.Size =
	UDim2.fromOffset(
		150,
		44
	)

Open.Position =
	UDim2.new(
		0,
		15,
		0.5,
		-22
	)

Open.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		30
	)

Open.Text =
	"HUNTER REAR FARM"

Open.TextColor3 =
	Color3.new(1, 1, 1)

Open.Font =
	Enum.Font.GothamBold

Open.TextSize = 13
Open.Parent = GUI

Instance.new(
	"UICorner",
	Open
).CornerRadius =
	UDim.new(0, 10)

--------------------------------------------------------------
-- FRAME
--------------------------------------------------------------

local Frame =
	Instance.new("Frame")

Frame.Size =
	UDim2.fromOffset(
		420,
		500
	)

Frame.Position =
	UDim2.new(
		0.5,
		-210,
		0.5,
		-250
	)

Frame.BackgroundColor3 =
	Color3.fromRGB(
		18,
		18,
		24
	)

Frame.Visible = false
Frame.Parent = GUI

Instance.new(
	"UICorner",
	Frame
).CornerRadius =
	UDim.new(0, 16)

--------------------------------------------------------------
-- TITLE
--------------------------------------------------------------

local Title =
	Instance.new("TextLabel")

Title.Size =
	UDim2.new(
		1,
		-60,
		0,
		50
	)

Title.Position =
	UDim2.fromOffset(
		18,
		2
	)

Title.BackgroundTransparency = 1
Title.Text = "Auto Hunter Rear Reach"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

--------------------------------------------------------------
-- CLOSE
--------------------------------------------------------------

local Close =
	Instance.new("TextButton")

Close.Size =
	UDim2.fromOffset(
		40,
		40
	)

Close.Position =
	UDim2.new(
		1,
		-48,
		0,
		7
	)

Close.BackgroundColor3 =
	Color3.fromRGB(
		180,
		55,
		55
	)

Close.Text = "×"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 27
Close.Parent = Frame

Instance.new(
	"UICorner",
	Close
).CornerRadius =
	UDim.new(0, 10)

--------------------------------------------------------------
-- AUTO HUNTER
--------------------------------------------------------------

local Toggle =
	Instance.new("TextButton")

Toggle.Size =
	UDim2.new(
		1,
		-36,
		0,
		46
	)

Toggle.Position =
	UDim2.fromOffset(
		18,
		58
	)

Toggle.TextColor3 = Color3.new(1, 1, 1)
Toggle.Font = Enum.Font.GothamBold
Toggle.TextSize = 16
Toggle.Parent = Frame

Instance.new(
	"UICorner",
	Toggle
).CornerRadius =
	UDim.new(0, 10)

--------------------------------------------------------------
-- LEVEL TITLE
--------------------------------------------------------------

local LevelTitle =
	Instance.new("TextLabel")

LevelTitle.Size =
	UDim2.new(
		1,
		0,
		0,
		28
	)

LevelTitle.Position =
	UDim2.fromOffset(
		0,
		112
	)

LevelTitle.BackgroundTransparency = 1
LevelTitle.Text = "Hunter Level"
LevelTitle.TextColor3 = Color3.new(1, 1, 1)
LevelTitle.Font = Enum.Font.GothamBold
LevelTitle.TextSize = 15
LevelTitle.Parent = Frame

--------------------------------------------------------------
-- LEVEL BUTTONS
--------------------------------------------------------------

local LevelButtons = {}

for Index, Preset in ipairs(
	LEVEL_PRESETS
) do
	local Button =
		Instance.new("TextButton")

	Button.Size =
		UDim2.new(
			0,
			118,
			0,
			38
		)

	Button.Position =
		UDim2.fromOffset(
			20
				+ ((Index - 1) * 128),
			143
		)

	Button.Text = Preset.Name
	Button.TextColor3 = Color3.new(1, 1, 1)
	Button.Font = Enum.Font.GothamBold
	Button.TextSize = 13
	Button.Parent = Frame

	Instance.new(
		"UICorner",
		Button
	).CornerRadius =
		UDim.new(0, 8)

	LevelButtons[Index] = Button
end

--------------------------------------------------------------
-- ATTACK DISTANCE
--------------------------------------------------------------

local DistanceTitle =
	Instance.new("TextLabel")

DistanceTitle.Size =
	UDim2.new(
		1,
		0,
		0,
		28
	)

DistanceTitle.Position =
	UDim2.fromOffset(
		0,
		194
	)

DistanceTitle.BackgroundTransparency = 1
DistanceTitle.Text = "Rear Attack Distance"
DistanceTitle.TextColor3 = Color3.new(1, 1, 1)
DistanceTitle.Font = Enum.Font.GothamBold
DistanceTitle.TextSize = 15
DistanceTitle.Parent = Frame

local DistanceMinus =
	Instance.new("TextButton")

DistanceMinus.Size =
	UDim2.fromOffset(
		62,
		42
	)

DistanceMinus.Position =
	UDim2.fromOffset(
		70,
		224
	)

DistanceMinus.Text = "−"
DistanceMinus.TextColor3 = Color3.new(1, 1, 1)
DistanceMinus.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
DistanceMinus.Font = Enum.Font.GothamBold
DistanceMinus.TextSize = 26
DistanceMinus.Parent = Frame

Instance.new(
	"UICorner",
	DistanceMinus
).CornerRadius =
	UDim.new(0, 8)

local DistanceValue =
	Instance.new("TextLabel")

DistanceValue.Size =
	UDim2.fromOffset(
		110,
		42
	)

DistanceValue.Position =
	UDim2.new(
		0.5,
		-55,
		0,
		224
	)

DistanceValue.BackgroundTransparency = 1
DistanceValue.TextColor3 = Color3.new(1, 1, 1)
DistanceValue.Font = Enum.Font.GothamBold
DistanceValue.TextSize = 22
DistanceValue.Parent = Frame

local DistancePlus =
	Instance.new("TextButton")

DistancePlus.Size =
	UDim2.fromOffset(
		62,
		42
	)

DistancePlus.Position =
	UDim2.new(
		1,
		-132,
		0,
		224
	)

DistancePlus.Text = "+"
DistancePlus.TextColor3 = Color3.new(1, 1, 1)
DistancePlus.BackgroundColor3 = Color3.fromRGB(45, 155, 80)
DistancePlus.Font = Enum.Font.GothamBold
DistancePlus.TextSize = 26
DistancePlus.Parent = Frame

Instance.new(
	"UICorner",
	DistancePlus
).CornerRadius =
	UDim.new(0, 8)

--------------------------------------------------------------
-- AUTO RANGE / MONEY
--------------------------------------------------------------

local RangeButton =
	Instance.new("TextButton")

RangeButton.Size =
	UDim2.new(
		0.5,
		-24,
		0,
		42
	)

RangeButton.Position =
	UDim2.fromOffset(
		18,
		286
	)

RangeButton.TextColor3 = Color3.new(1, 1, 1)
RangeButton.Font = Enum.Font.GothamBold
RangeButton.TextSize = 14
RangeButton.Parent = Frame

Instance.new(
	"UICorner",
	RangeButton
).CornerRadius =
	UDim.new(0, 9)

local MoneyButton =
	Instance.new("TextButton")

MoneyButton.Size =
	UDim2.new(
		0.5,
		-24,
		0,
		42
	)

MoneyButton.Position =
	UDim2.new(
		0.5,
		6,
		0,
		286
	)

MoneyButton.TextColor3 = Color3.new(1, 1, 1)
MoneyButton.Font = Enum.Font.GothamBold
MoneyButton.TextSize = 14
MoneyButton.Parent = Frame

Instance.new(
	"UICorner",
	MoneyButton
).CornerRadius =
	UDim.new(0, 9)

--------------------------------------------------------------
-- COMBAT STATUS
--------------------------------------------------------------

local CombatStatus =
	Instance.new("TextLabel")

CombatStatus.Size =
	UDim2.new(
		1,
		-20,
		0,
		27
	)

CombatStatus.Position =
	UDim2.fromOffset(
		10,
		342
	)

CombatStatus.BackgroundTransparency = 1
CombatStatus.TextColor3 = Color3.fromRGB(135, 190, 230)
CombatStatus.Font = Enum.Font.GothamBold
CombatStatus.TextSize = 12
CombatStatus.Parent = Frame

--------------------------------------------------------------
-- SAFETY STATUS
--------------------------------------------------------------

local SafetyStatus =
	Instance.new("TextLabel")

SafetyStatus.Size =
	UDim2.new(
		1,
		-20,
		0,
		27
	)

SafetyStatus.Position =
	UDim2.fromOffset(
		10,
		369
	)

SafetyStatus.BackgroundTransparency = 1
SafetyStatus.Text = "Nearby Hunters: 0"
SafetyStatus.TextColor3 = Color3.fromRGB(195, 165, 110)
SafetyStatus.Font = Enum.Font.GothamBold
SafetyStatus.TextSize = 12
SafetyStatus.Parent = Frame

--------------------------------------------------------------
-- RANGE STATUS
--------------------------------------------------------------

local RangeStatus =
	Instance.new("TextLabel")

RangeStatus.Size =
	UDim2.new(
		1,
		-20,
		0,
		27
	)

RangeStatus.Position =
	UDim2.fromOffset(
		10,
		396
	)

RangeStatus.BackgroundTransparency = 1
RangeStatus.Text = "Range learning: ready"
RangeStatus.TextColor3 = Color3.fromRGB(170, 200, 145)
RangeStatus.Font = Enum.Font.GothamBold
RangeStatus.TextSize = 12
RangeStatus.Parent = Frame

--------------------------------------------------------------
-- MAIN STATUS
--------------------------------------------------------------

local Status =
	Instance.new("TextLabel")

Status.Size =
	UDim2.new(
		1,
		-20,
		0,
		62
	)

Status.Position =
	UDim2.new(
		0,
		10,
		1,
		-68
	)

Status.BackgroundTransparency = 1
Status.Text = "Ready"
Status.TextColor3 = Color3.fromRGB(160, 215, 165)
Status.Font = Enum.Font.Gotham
Status.TextSize = 13
Status.TextWrapped = true
Status.Parent = Frame

--------------------------------------------------------------
-- UPDATE GUI
--------------------------------------------------------------

local function UpdateGUI()
	if Enabled then
		Toggle.Text = "AUTO HUNTER : ON"
		Toggle.BackgroundColor3 = Color3.fromRGB(45, 155, 80)
	else
		Toggle.Text = "AUTO HUNTER : OFF"
		Toggle.BackgroundColor3 = Color3.fromRGB(170, 55, 55)
	end

	for Index, Button in ipairs(LevelButtons) do
		if Index == SelectedPreset then
			Button.BackgroundColor3 = Color3.fromRGB(45, 145, 80)
		else
			Button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end
	end

	DistanceValue.Text =
		string.format(
			"%.2f",
			ATTACK_DISTANCE
		)

	if AUTO_RANGE then
		RangeButton.Text = "AUTO RANGE : ON"
		RangeButton.BackgroundColor3 = Color3.fromRGB(55, 125, 180)
	else
		RangeButton.Text = "AUTO RANGE : OFF"
		RangeButton.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	end

	if AUTO_MONEY then
		MoneyButton.Text = "AUTO MONEY : ON"
		MoneyButton.BackgroundColor3 = Color3.fromRGB(180, 135, 45)
	else
		MoneyButton.Text = "AUTO MONEY : OFF"
		MoneyButton.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	end

	if CombatRemote and CombatRemote.Parent then
		CombatStatus.Text =
			"CombatRemote: READY | Attack cooldown 0.44s"
	else
		CombatStatus.Text =
			"CombatRemote: NOT FOUND"
	end
end

--------------------------------------------------------------
-- GUI EVENTS
--------------------------------------------------------------

for Index, Button in ipairs(LevelButtons) do
	Button.MouseButton1Click:Connect(
		function()
			SelectedPreset = Index
			CurrentTarget = nil
			LastTargetRecheck = 0
			ResetRangeLearning(nil)

			UpdateGUI()
		end
	)
end

Toggle.MouseButton1Click:Connect(
	function()
		Enabled = not Enabled

		CurrentTarget = nil
		LastTargetRecheck = 0
		ResetRangeLearning(nil)

		if Enabled then
			ResolveCombatRemote()
			ForceEquipFists()

			Status.Text =
				"Searching safest Hunter..."
		else
			Status.Text = "Stopped"
		end

		UpdateGUI()
	end
)

DistanceMinus.MouseButton1Click:Connect(
	function()
		ATTACK_DISTANCE =
			math.clamp(
				ATTACK_DISTANCE
					- MANUAL_DISTANCE_STEP,

				MIN_ATTACK_DISTANCE,

				MAX_ATTACK_DISTANCE
			)

		ResetRangeLearning(
			CurrentTarget
			and CurrentTarget:FindFirstChildOfClass("Humanoid")
			or nil
		)

		UpdateGUI()
	end
)

DistancePlus.MouseButton1Click:Connect(
	function()
		ATTACK_DISTANCE =
			math.clamp(
				ATTACK_DISTANCE
					+ MANUAL_DISTANCE_STEP,

				MIN_ATTACK_DISTANCE,

				MAX_ATTACK_DISTANCE
			)

		ResetRangeLearning(
			CurrentTarget
			and CurrentTarget:FindFirstChildOfClass("Humanoid")
			or nil
		)

		UpdateGUI()
	end
)

RangeButton.MouseButton1Click:Connect(
	function()
		AUTO_RANGE = not AUTO_RANGE
		ResetRangeLearning(
			CurrentTarget
			and CurrentTarget:FindFirstChildOfClass("Humanoid")
			or nil
		)

		UpdateGUI()
	end
)

MoneyButton.MouseButton1Click:Connect(
	function()
		AUTO_MONEY = not AUTO_MONEY
		UpdateGUI()
	end
)

Open.MouseButton1Click:Connect(
	function()
		Frame.Visible =
			not Frame.Visible
	end
)

Close.MouseButton1Click:Connect(
	function()
		Frame.Visible = false
	end
)

--==============================================================
-- DAMAGE MONITOR
--==============================================================

local HealthConnection = nil

local function ConnectHealthMonitor(Character)
	if HealthConnection then
		pcall(function()
			HealthConnection:Disconnect()
		end)

		HealthConnection = nil
	end

	local Humanoid =
		Character:FindFirstChildOfClass("Humanoid")

	if not Humanoid then
		return
	end

	LastPlayerHealth =
		Humanoid.Health

	HealthConnection =
		Humanoid.HealthChanged:Connect(
			function(NewHealth)
				if LastPlayerHealth
					and NewHealth
						< LastPlayerHealth then

					EvadeUntil =
						os.clock()
						+ DAMAGE_EVADE_TIME

					LastTargetRecheck = 0
				end

				LastPlayerHealth =
					NewHealth
			end
		)
end

if Player.Character then
	ConnectHealthMonitor(Player.Character)
end

--------------------------------------------------------------
-- RESPAWN
--------------------------------------------------------------

Player.CharacterAdded:Connect(
	function(Character)
		CurrentTarget = nil
		LastTargetRecheck = 0
		ResetRangeLearning(nil)

		ConnectHealthMonitor(Character)

		if not Enabled then
			return
		end

		Character:WaitForChild(
			"Humanoid",
			10
		)

		Character:WaitForChild(
			"HumanoidRootPart",
			10
		)

		task.wait(0.65)

		if Enabled then
			ForceEquipFists()
		end
	end
)

--==============================================================
-- COMBAT REMOTE RECOVERY
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		local Now = os.clock()

		if (
			not CombatRemote
			or not CombatRemote.Parent
		)
			and Now
				- LastCombatResolve
				>= 1.0 then

			LastCombatResolve = Now
			ResolveCombatRemote()
			UpdateGUI()
		end

		task.wait(0.25)
	end
end)

--==============================================================
-- MONEY LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled
			and AUTO_MONEY then

			local Now = os.clock()

			if Now
				- LastMoneyScan
				>= MONEY_SCAN_INTERVAL then

				LastMoneyScan = Now
				CollectMoney()
			end
		end

		task.wait(0.08)
	end
end)

--==============================================================
-- MAIN FARM LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled then
			local Character,
				Humanoid,
				PlayerRoot =
				GetCharacter()

			if Humanoid
				and PlayerRoot
				and Humanoid.Health > 0 then

				local Now = os.clock()

				------------------------------------------------
				-- Keep Fists equipped
				------------------------------------------------

				if Now
					- LastEquipCheck
					>= EQUIP_CHECK_INTERVAL then

					LastEquipCheck = Now

					local Fists =
						Character:FindFirstChild("Fists")

					if not Fists
						or not Fists:IsA("Tool") then

						EquipFists(
							Character,
							Humanoid
						)
					end
				end

				------------------------------------------------
				-- Current target still valid?
				------------------------------------------------

				if not IsValidHunter(CurrentTarget) then
					CurrentTarget = nil
					ResetRangeLearning(nil)
				end

				------------------------------------------------
				-- Select/reconsider Hunter
				------------------------------------------------

				if Now
					- LastTargetRecheck
					>= TARGET_RECHECK_INTERVAL then

					LastTargetRecheck = Now

					if not CurrentTarget then
						local NewTarget =
							FindSafestHunter(
								PlayerRoot
							)

						CurrentTarget = NewTarget

						if CurrentTarget then
							ResetRangeLearning(
								CurrentTarget:FindFirstChildOfClass(
									"Humanoid"
								)
							)
						end

					else
						local _,
							CurrentDanger =
							GetTargetSafetyScore(
								CurrentTarget,
								PlayerRoot
							)

						if CurrentDanger
							>= DANGER_SWITCH_THRESHOLD then

							local BetterTarget,
								BetterDanger =
								FindSafestHunter(
									PlayerRoot
								)

							if BetterTarget
								and BetterTarget
									~= CurrentTarget
								and BetterDanger
									< CurrentDanger then

								CurrentTarget =
									BetterTarget

								ResetRangeLearning(
									CurrentTarget:FindFirstChildOfClass(
										"Humanoid"
									)
								)
							end
						end
					end
				end

				------------------------------------------------
				-- No target
				------------------------------------------------

				if not CurrentTarget then
					local Preset =
						LEVEL_PRESETS[
							SelectedPreset
						]

					Status.Text =
						"No Hunter Lv "
						.. Preset.Name

					SafetyStatus.Text =
						"Nearby Hunters: 0"

					task.wait(FOLLOW_INTERVAL)
					continue
				end

				------------------------------------------------
				-- Track target HP for Auto Range
				------------------------------------------------

				local HunterHumanoid =
					CurrentTarget
					:FindFirstChildOfClass("Humanoid")

				ObserveTargetDamage(
					HunterHumanoid
				)

				------------------------------------------------
				-- STAY BEHIND CONTINUOUSLY
				-- There is no blink in/out here.
				------------------------------------------------

				local RearCFrame =
					GetRearCFrame(
						CurrentTarget,
						Character,
						Humanoid,
						PlayerRoot
					)

				if RearCFrame then
					SetCharacterCFrame(
						PlayerRoot,
						RearCFrame
					)
				end

				------------------------------------------------
				-- Status
				------------------------------------------------

				local HunterLevel =
					GetHunterLevel(
						CurrentTarget
					)

				if HunterHumanoid then
					Status.Text =
						"Hunter Lv "
						.. tostring(
							HunterLevel or "?"
						)
						.. " | HP "
						.. tostring(
							math.floor(
								HunterHumanoid.Health
							)
						)
				end

				local HunterRoot =
					GetHunterRoot(
						CurrentTarget
					)

				if HunterRoot then
					local Nearby =
						select(
							1,
							CountNearbyHunters(
								HunterRoot.Position,
								CurrentTarget,
								DANGER_RADIUS
							)
						)

					SafetyStatus.Text =
						"Nearby Hunters: "
						.. tostring(Nearby)
				end

				RangeStatus.Text =
					string.format(
						"Range %.2f | Hit streak %d | Miss %d",
						ATTACK_DISTANCE,
						ConfirmedHitStreak,
						AttackAttemptsWithoutDamage
					)

				DistanceValue.Text =
					string.format(
						"%.2f",
						ATTACK_DISTANCE
					)

				------------------------------------------------
				-- During damage evade: stay farther behind,
				-- do not attack.
				------------------------------------------------

				if Now < EvadeUntil then
					Status.Text =
						"Evading damage..."

					task.wait(FOLLOW_INTERVAL)
					continue
				end

				------------------------------------------------
				-- Attack while remaining at the SAME rear range.
				------------------------------------------------

				if Now
					- LastAttack
					>= ATTACK_INTERVAL then

					LastAttack = Now

					if not CombatRemote
						or not CombatRemote.Parent then

						ResolveCombatRemote()

						if not CombatRemote then
							CombatStatus.Text =
								"CombatRemote: NOT FOUND"

							Status.Text =
								"Waiting for CombatRemote..."

							task.wait(FOLLOW_INTERVAL)
							continue
						end
					end

					-- Register this attempt BEFORE waiting for HP replication.
					RegisterAttackAttempt()

					FireAttack()
				end
			end
		end

		task.wait(FOLLOW_INTERVAL)
	end
end)

--==============================================================
-- DRAG GUI
--==============================================================

do
	local Dragging = false
	local DragStart
	local StartPosition

	Frame.InputBegan:Connect(
		function(Input)
			if Input.UserInputType
				== Enum.UserInputType.MouseButton1
				or Input.UserInputType
				== Enum.UserInputType.Touch then

				Dragging = true
				DragStart = Input.Position
				StartPosition = Frame.Position
			end
		end
	)

	UserInputService.InputChanged:Connect(
		function(Input)
			if not Dragging then
				return
			end

			if Input.UserInputType
				== Enum.UserInputType.MouseMovement
				or Input.UserInputType
				== Enum.UserInputType.Touch then

				local Delta =
					Input.Position
					- DragStart

				Frame.Position =
					UDim2.new(
						StartPosition.X.Scale,
						StartPosition.X.Offset
							+ Delta.X,

						StartPosition.Y.Scale,
						StartPosition.Y.Offset
							+ Delta.Y
					)
			end
		end
	)

	UserInputService.InputEnded:Connect(
		function(Input)
			if Input.UserInputType
				== Enum.UserInputType.MouseButton1
				or Input.UserInputType
				== Enum.UserInputType.Touch then

				Dragging = false
			end
		end
	)
end

--==============================================================
-- CLEANUP
--==============================================================

local function Stop()
	Running = false
	Enabled = false

	if HealthConnection then
		pcall(function()
			HealthConnection:Disconnect()
		end)

		HealthConnection = nil
	end

	if GUI then
		GUI:Destroy()
	end

	print("[Auto Hunter Rear Reach] stopped")
end

ENV.AutoHunterFarmStop = Stop

--------------------------------------------------------------
-- START
--------------------------------------------------------------

UpdateGUI()

print("")
print("================================================")
print(" AUTO HUNTER REAR REACH READY")
print("================================================")
print("NO Auto Blood")
print("NO Freeze")
print("NO NPC teleport")
print("NO attack blink")
print("")
print("Combat:")
print(" Funcoes.Game15Fists.CombatRemote")
print(' FireServer("Attack")')
print("")
print("Player stays behind Hunter continuously.")
print("Auto Range searches for the farthest working distance.")
print("")
print("Starting distance:", ATTACK_DISTANCE)
print("Min distance:", MIN_ATTACK_DISTANCE)
print("Max distance:", MAX_ATTACK_DISTANCE)
print("Attack interval:", ATTACK_INTERVAL)
print("Follow interval:", FOLLOW_INTERVAL)
print("Auto Money:", AUTO_MONEY)
print("================================================")
