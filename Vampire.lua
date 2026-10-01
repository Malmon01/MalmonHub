--============================================================
-- AUTO HUNTER SAFE FARM - STANDALONE
-- GitHub / loadstring version
--
-- Main idea:
--   • DO NOT freeze or move NPCs.
--   • Always attack Hunter at its real server position.
--   • Pick the safest Hunter in the selected level range.
--   • Stay behind the target and constantly re-position.
--   • If the player takes damage, briefly stop attacking and
--     move to the safest rear position before continuing.
--   • Auto Blood at <= 25%:
--       pause farm -> ShopKeeper2 -> buy Vampire Blood
--       -> equip -> DrinkPotionRemote -> wait -> return
--   • Auto Money from Workspace.DroppedMoney.KillMoneyBag
--
-- Hunter level presets:
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
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------------------
-- CLEAN PREVIOUS VERSION
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

local NPCS = workspace:WaitForChild("NPCS")
local HUNTERS = NPCS:WaitForChild("HUNTERS")
local DROPPED_MONEY = workspace:WaitForChild("DroppedMoney")

local CombatEvent =
	ReplicatedStorage
	:WaitForChild("ArczisCombat")
	:WaitForChild("Remotes")
	:WaitForChild("CombatEvent")

local Funcoes =
	ReplicatedStorage["Fun\195\167\195\181es"]

local Eventos =
	Funcoes:WaitForChild("Eventos")

local ShopRemote =
	Eventos:WaitForChild("ShopRemote")

local DrinkPotionRemote =
	Eventos:WaitForChild("DrinkPotionRemote")

local PlayEmoteSound =
	ReplicatedStorage
	:WaitForChild("EmoteSystemRemotes")
	:WaitForChild("PlayEmoteSound")

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
-- SAFE FARM SETTINGS
--------------------------------------------------------------

-- Stay close enough for the game's real M1 distance check.
local BEHIND_DISTANCE = 3.65
local MIN_BEHIND_DISTANCE = 2.80
local MAX_BEHIND_DISTANCE = 4.40
local BEHIND_STEP = 0.15

-- Search for a safer rear point around the Hunter.
local REAR_ANGLE_OPTIONS = {
	-28,
	-18,
	-9,
	0,
	9,
	18,
	28
}

local REAR_DISTANCE_OPTIONS = {
	-0.30,
	0,
	0.30
}

-- Other NPCs inside this radius make a Hunter less desirable.
local DANGER_RADIUS = 10
local DANGER_SWITCH_THRESHOLD = 3

-- If player is hit, pause attacks briefly.
local DAMAGE_EVADE_TIME = 0.28

-- After taking damage, favor the farthest safe rear point briefly.
local DAMAGE_RETREAT_BONUS = 0.35

-- M1 timing.
local ATTACK_INTERVAL = 0.20

-- Follow target / reposition speed.
local FOLLOW_INTERVAL = 0.03

-- How often we reconsider the safest Hunter.
local TARGET_RECHECK_INTERVAL = 0.45

-- Threat cache refresh.
local THREAT_REFRESH_INTERVAL = 0.40

-- Keep Fists equipped.
local EQUIP_CHECK_INTERVAL = 0.18

--------------------------------------------------------------
-- MONEY SETTINGS
--------------------------------------------------------------

local AUTO_MONEY = true
local MONEY_SCAN_INTERVAL = 0.35
local MONEY_TOUCH_COOLDOWN = 0.40

--------------------------------------------------------------
-- BLOOD SETTINGS
--------------------------------------------------------------

local AUTO_BLOOD = true

-- EXACT user-requested threshold.
local BLOOD_TRIGGER = 0.25

-- Vampire Blood normally fills the bar.
local BLOOD_RESUME = 0.90

local BLOOD_CHECK_INTERVAL = 0.15
local BLOOD_RETRY_DELAY = 2.5

local POTION_WAIT_TIMEOUT = 5.0
local BLOOD_FILL_TIMEOUT = 8.0
local SHOP_SETTLE_TIME = 0.25

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------

local Enabled = false
local Running = true
local RefillingBlood = false

local CurrentTarget = nil

local LastAttack = 0
local LastTargetRecheck = 0
local LastThreatRefresh = 0
local LastEquipCheck = 0
local LastMoneyScan = 0
local LastBloodCheck = 0
local LastBloodRefillAttempt = 0

local LastKnownBlood = nil

local LastPlayerHealth = nil
local EvadeUntil = 0

local ThreatCache = {}
local CurrentThreatCount = 0

local MoneyAttempt =
	setmetatable(
		{},
		{
			__mode = "k"
		}
	)

local FarmGUI = nil

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

local function WaitForCharacterReady()
	local Character =
		Player.Character
		or Player.CharacterAdded:Wait()

	local Humanoid =
		Character:WaitForChild(
			"Humanoid",
			10
		)

	local Root =
		Character:WaitForChild(
			"HumanoidRootPart",
			10
		)

	return Character, Humanoid, Root
end

local function SetCharacterCFrame(
	Root,
	CFrameValue
)
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
		return Vector3.new(
			0,
			0,
			-1
		)
	end

	return Flat.Unit
end

--------------------------------------------------------------
-- HUNTER HELPERS
--------------------------------------------------------------

local function GetHunterRoot(Hunter)
	if not Hunter then
		return nil
	end

	return
		Hunter:FindFirstChild("HumanoidRootPart")
		or Hunter:FindFirstChild("UpperTorso")
		or Hunter:FindFirstChild("Torso")
		or Hunter.PrimaryPart
end

--------------------------------------------------------------
-- READ HUNTER LEVEL
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
		local Value =
			Hunter:GetAttribute(Name)

		if typeof(Value) == "number" then
			return math.floor(Value)

		elseif typeof(Value) == "string" then
			local Number =
				tonumber(Value)

			if Number then
				return math.floor(Number)
			end
		end
	end

	----------------------------------------------------------
	-- Value objects
	----------------------------------------------------------

	for _, Object in ipairs(
		Hunter:GetDescendants()
	) do
		if Object:IsA("IntValue")
			or Object:IsA("NumberValue")
			or Object:IsA("StringValue") then

			local LowerName =
				string.lower(Object.Name)

			if LowerName == "level"
				or LowerName == "lvl" then

				local Number =
					tonumber(Object.Value)

				if Number then
					return math.floor(Number)
				end
			end
		end
	end

	----------------------------------------------------------
	-- Overhead text: Hunter Lv 165 / Hunter Lv 2536
	----------------------------------------------------------

	for _, Object in ipairs(
		Hunter:GetDescendants()
	) do
		if Object:IsA("TextLabel")
			or Object:IsA("TextButton") then

			local Text =
				tostring(Object.Text)

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
		LEVEL_PRESETS[
			SelectedPreset
		]

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

	-- Exact Hunter only. HunterBow is ignored.
	if Hunter.Name ~= "Hunter" then
		return false
	end

	local Humanoid =
		Hunter:FindFirstChildOfClass(
			"Humanoid"
		)

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
-- THREAT CACHE
--------------------------------------------------------------

local function RefreshThreatCache()
	local NewCache = {}

	-- A threat is any living NPC model under Workspace.NPCS.
	for _, Object in ipairs(
		NPCS:GetDescendants()
	) do
		if Object:IsA("Model") then
			local Humanoid =
				Object:FindFirstChildOfClass(
					"Humanoid"
				)

			local Root =
				GetHunterRoot(Object)

			if Humanoid
				and Humanoid.Health > 0
				and Root
				and Root:IsA("BasePart") then

				NewCache[#NewCache + 1] = {
					Model = Object,
					Humanoid = Humanoid,
					Root = Root
				}
			end
		end
	end

	ThreatCache = NewCache
end

local function CountThreatsAroundPosition(
	Position,
	ExcludeModel,
	Radius
)
	local Count = 0
	local Nearest = math.huge

	for _, Threat in ipairs(
		ThreatCache
	) do
		if Threat.Model ~= ExcludeModel
			and Threat.Humanoid
			and Threat.Humanoid.Health > 0
			and Threat.Root
			and Threat.Root.Parent then

			local Distance =
				(
					Threat.Root.Position
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

	return Count, Nearest
end

--------------------------------------------------------------
-- SAFEST TARGET
--------------------------------------------------------------

local function GetHunterSafetyScore(
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
		CountThreatsAroundPosition(
			Root.Position,
			Hunter,
			DANGER_RADIUS
		)

	local PlayerDistance =
		(
			Root.Position
			- PlayerRoot.Position
		).Magnitude

	-- Lower = safer.
	-- Nearby threats matter far more than travel distance.
	local Score =
		ThreatCount * 100

	if NearestThreat < DANGER_RADIUS then
		Score +=
			(
				DANGER_RADIUS
				- NearestThreat
			)
			* 7
	end

	Score +=
		PlayerDistance
		* 0.025

	return Score, ThreatCount
end

local function FindSafestHunter(
	PlayerRoot
)
	if not PlayerRoot then
		return nil, 0
	end

	local BestTarget = nil
	local BestScore = math.huge
	local BestThreatCount = 0

	for _, Hunter in ipairs(
		HUNTERS:GetChildren()
	) do
		if IsValidHunter(Hunter) then
			local Score,
				ThreatCount =
				GetHunterSafetyScore(
					Hunter,
					PlayerRoot
				)

			if Score < BestScore then
				BestScore = Score
				BestTarget = Hunter
				BestThreatCount =
					ThreatCount
			end
		end
	end

	return
		BestTarget,
		BestThreatCount
end

--------------------------------------------------------------
-- GROUND-SAFE PLAYER POSITION
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

	local Origin =
		Position
		+ Vector3.new(
			0,
			5,
			0
		)

	local Result =
		workspace:Raycast(
			Origin,
			Vector3.new(
				0,
				-18,
				0
			),
			Params
		)

	if Result then
		local StandingY =
			Result.Position.Y
			+ Humanoid.HipHeight
			+ (
				PlayerRoot.Size.Y
				* 0.5
			)

		return Vector3.new(
			Position.X,
			StandingY,
			Position.Z
		)
	end

	return Position
end

--------------------------------------------------------------
-- SAFEST REAR POSITION
--------------------------------------------------------------

local function RotateFlatVector(
	Vector,
	Degrees
)
	local Angle =
		math.rad(Degrees)

	local Cos =
		math.cos(Angle)

	local Sin =
		math.sin(Angle)

	return Vector3.new(
		Vector.X * Cos
			- Vector.Z * Sin,

		0,

		Vector.X * Sin
			+ Vector.Z * Cos
	)
end

local function GetSafestRearCFrame(
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

		return nil, 0
	end

	local Forward =
		HorizontalUnit(
			HunterRoot.CFrame.LookVector
		)

	local Back =
		-Forward

	local BestPosition = nil
	local BestSafety = -math.huge
	local BestThreatCount = 0

	local DamageRetreat =
		os.clock() < EvadeUntil
		and DAMAGE_RETREAT_BONUS
		or 0

	for _, Angle in ipairs(
		REAR_ANGLE_OPTIONS
	) do
		local Direction =
			RotateFlatVector(
				Back,
				Angle
			)

		for _, Offset in ipairs(
			REAR_DISTANCE_OPTIONS
		) do
			local Distance =
				math.clamp(
					BEHIND_DISTANCE
						+ Offset
						+ DamageRetreat,

					MIN_BEHIND_DISTANCE,

					MAX_BEHIND_DISTANCE
				)

			local Candidate =
				HunterRoot.Position
				+ Direction
				* Distance

			Candidate =
				GetGroundAdjustedPosition(
					Candidate,
					Character,
					PlayerRoot,
					Humanoid
				)

			local ThreatCount,
				NearestThreat =
				CountThreatsAroundPosition(
					Candidate,
					Hunter,
					DANGER_RADIUS
				)

			-- Higher = safer.
			local Safety =
				NearestThreat

			Safety -=
				ThreatCount
				* 12

			-- Slight preference for directly behind Hunter.
			Safety -=
				math.abs(Angle)
				* 0.025

			-- Slight preference for user's chosen distance.
			Safety -=
				math.abs(Offset)
				* 0.10

			if Safety > BestSafety then
				BestSafety = Safety
				BestPosition = Candidate
				BestThreatCount =
					ThreatCount
			end
		end
	end

	if not BestPosition then
		return nil, 0
	end

	return
		CFrame.lookAt(
			BestPosition,
			HunterRoot.Position
		),
		BestThreatCount
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
		Character:FindFirstChild(
			"Fists"
		)

	if Fists
		and Fists:IsA("Tool") then

		return Fists
	end

	local Backpack =
		Player:FindFirstChild(
			"Backpack"
		)

	if not Backpack then
		return nil
	end

	Fists =
		Backpack:FindFirstChild(
			"Fists"
		)

	if not Fists
		or not Fists:IsA("Tool") then

		return nil
	end

	pcall(function()
		Humanoid:EquipTool(Fists)
	end)

	task.wait(0.03)

	return
		Character:FindFirstChild(
			"Fists"
		)
end

local function ForceEquipFists()
	local Character,
		Humanoid =
		GetCharacter()

	if not Character
		or not Humanoid
		or Humanoid.Health <= 0 then

		return nil
	end

	return
		EquipFists(
			Character,
			Humanoid
		)
end

--------------------------------------------------------------
-- ATTACK
--------------------------------------------------------------

local function Attack(
	Character,
	Fists
)
	if not Character
		or not Fists
		or Fists.Parent ~= Character then

		return
	end

	----------------------------------------------------------
	-- Tool animation / normal activation
	----------------------------------------------------------

	pcall(function()
		Fists:Activate()
	end)

	----------------------------------------------------------
	-- Original Fists remote
	----------------------------------------------------------

	local FistRemote =
		Fists:FindFirstChild(
			"fistremote"
		)

	if FistRemote
		and FistRemote:IsA(
			"RemoteEvent"
		) then

		pcall(function()
			FistRemote:FireServer(
				"lmb"
			)
		end)
	end

	----------------------------------------------------------
	-- ArczisCombat M1
	----------------------------------------------------------

	local Timestamp =
		workspace:GetServerTimeNow()

	pcall(function()
		CombatEvent:FireServer(
			"M1",
			Timestamp
		)
	end)
end

--==============================================================
-- BLOOD DETECTION
--==============================================================

local BLOOD_NAMES = {
	"blood",
	"bloodamount",
	"vampireblood",
	"bloodlevel",
	"thirst"
}

local MAX_BLOOD_NAMES = {
	"maxblood",
	"bloodmax",
	"maxbloodamount",
	"maxvampireblood",
	"maxthirst"
}

local function NameMatches(
	Name,
	List
)
	Name =
		string.lower(Name)

	for _, Target in ipairs(List) do
		if Name == Target then
			return true
		end
	end

	return false
end

local function BloodFromAttributes(
	Object
)
	if not Object then
		return nil
	end

	local Current = nil
	local Maximum = nil

	for Name, Value in pairs(
		Object:GetAttributes()
	) do
		if typeof(Value) == "number" then
			if NameMatches(
				Name,
				BLOOD_NAMES
			) then

				Current = Value

			elseif NameMatches(
				Name,
				MAX_BLOOD_NAMES
			) then

				Maximum = Value
			end
		end
	end

	if Current then
		if Maximum
			and Maximum > 0 then

			return math.clamp(
				Current / Maximum,
				0,
				1
			)
		end

		if Current >= 0
			and Current <= 100 then

			return Current / 100
		end
	end

	return nil
end

local function BloodFromValues(
	Root
)
	if not Root then
		return nil
	end

	local Current = nil
	local Maximum = nil

	for _, Object in ipairs(
		Root:GetDescendants()
	) do
		if Object:IsA("NumberValue")
			or Object:IsA("IntValue") then

			if NameMatches(
				Object.Name,
				BLOOD_NAMES
			) then

				Current = Object.Value

			elseif NameMatches(
				Object.Name,
				MAX_BLOOD_NAMES
			) then

				Maximum = Object.Value
			end
		end
	end

	if Current then
		if Maximum
			and Maximum > 0 then

			return math.clamp(
				Current / Maximum,
				0,
				1
			)
		end

		if Current >= 0
			and Current <= 100 then

			return Current / 100
		end
	end

	return nil
end

local function IsRedGui(
	Object
)
	local Color = nil

	pcall(function()
		if Object:IsA("ImageLabel")
			or Object:IsA("ImageButton") then

			Color =
				Object.ImageColor3
		else
			Color =
				Object.BackgroundColor3
		end
	end)

	if not Color then
		return false
	end

	return
		Color.R > 0.45
		and Color.R > Color.G * 1.5
		and Color.R > Color.B * 1.3
end

local function BloodFromGUI()
	local BestPercent = nil
	local BestScore = -math.huge

	for _, Object in ipairs(
		PlayerGui:GetDescendants()
	) do
		-- Ignore this script's own GUI.
		if FarmGUI
			and Object:IsDescendantOf(
				FarmGUI
			) then

			continue
		end

		if Object:IsA("GuiObject")
			and Object.Visible then

			local Name =
				string.lower(
					Object.Name
				)

			local Parent =
				Object.Parent

			local NamedBlood =
				string.find(
					Name,
					"blood",
					1,
					true
				) ~= nil

			if Parent then
				local ParentName =
					string.lower(
						Parent.Name
					)

				if string.find(
					ParentName,
					"blood",
					1,
					true
				) then

					NamedBlood = true
				end
			end

			--------------------------------------------------
			-- Text percentage / current-max
			--------------------------------------------------

			if NamedBlood
				and (
					Object:IsA("TextLabel")
					or Object:IsA("TextButton")
				) then

				local Text =
					tostring(Object.Text)

				local Percent =
					string.match(
						Text,
						"(%d+)%s*%%"
					)

				if Percent then
					return
						math.clamp(
							tonumber(Percent)
								/ 100,
							0,
							1
						)
				end

				local Current,
					Maximum =
					string.match(
						Text,
						"(%d+)%s*/%s*(%d+)"
					)

				if Current
					and Maximum
					and tonumber(Maximum) > 0 then

					return
						math.clamp(
							tonumber(Current)
								/ tonumber(Maximum),
							0,
							1
						)
				end
			end

			--------------------------------------------------
			-- Vertical red bar
			--------------------------------------------------

			if IsRedGui(Object)
				and Parent
				and Parent:IsA("GuiObject") then

				local Width =
					Object.AbsoluteSize.X

				local Height =
					Object.AbsoluteSize.Y

				local ParentHeight =
					Parent.AbsoluteSize.Y

				if Height > 5
					and ParentHeight > 10
					and Height > Width * 1.5 then

					local Ratio =
						Height
						/ ParentHeight

					if Ratio > 0
						and Ratio <= 1.05 then

						Ratio =
							math.clamp(
								Ratio,
								0,
								1
							)

						local Score =
							Height

						if NamedBlood then
							Score += 100
						end

						if Width < 80 then
							Score += 30
						end

						if Score > BestScore then
							BestScore = Score
							BestPercent = Ratio
						end
					end
				end
			end

			--------------------------------------------------
			-- Scale-based vertical fill
			--------------------------------------------------

			if IsRedGui(Object) then
				local YScale =
					Object.Size.Y.Scale

				if YScale > 0
					and YScale <= 1 then

					local Width =
						Object.AbsoluteSize.X

					local Height =
						Object.AbsoluteSize.Y

					if Height > Width * 1.5 then
						local Score =
							Height

						if NamedBlood then
							Score += 100
						end

						if Score > BestScore then
							BestScore = Score
							BestPercent = YScale
						end
					end
				end
			end
		end
	end

	return BestPercent
end

local function GetBloodPercent()
	local Character,
		Humanoid =
		GetCharacter()

	----------------------------------------------------------
	-- Attributes
	----------------------------------------------------------

	for _, Object in ipairs({
		Player,
		Character,
		Humanoid
	}) do
		local Percent =
			BloodFromAttributes(
				Object
			)

		if Percent then
			LastKnownBlood = Percent
			return Percent
		end
	end

	----------------------------------------------------------
	-- NumberValues
	----------------------------------------------------------

	for _, Object in ipairs({
		Player,
		Character
	}) do
		local Percent =
			BloodFromValues(
				Object
			)

		if Percent then
			LastKnownBlood = Percent
			return Percent
		end
	end

	----------------------------------------------------------
	-- GUI fallback
	----------------------------------------------------------

	local Percent =
		BloodFromGUI()

	if Percent then
		LastKnownBlood = Percent
		return Percent
	end

	return LastKnownBlood
end

--==============================================================
-- AUTO BLOOD REFILL
--==============================================================

local function GetVampireMerchant()
	----------------------------------------------------------
	-- Known map path
	----------------------------------------------------------

	local Mapa =
		workspace:FindFirstChild(
			"Mapa"
		)

	if Mapa then
		local Cidade =
			Mapa:FindFirstChild(
				"CIDADE"
			)

		if Cidade then
			local Merchant =
				Cidade:FindFirstChild(
					"ShopKeeper2"
				)

			if Merchant then
				return Merchant
			end
		end
	end

	----------------------------------------------------------
	-- Fallback
	----------------------------------------------------------

	for _, Object in ipairs(
		workspace:GetDescendants()
	) do
		if Object:IsA("Model")
			and Object.Name == "ShopKeeper2" then

			return Object
		end
	end

	return nil
end

local function GetMerchantRoot(
	Merchant
)
	if not Merchant then
		return nil
	end

	return
		Merchant:FindFirstChild("HumanoidRootPart")
		or Merchant:FindFirstChild("Torso")
		or Merchant:FindFirstChild("UpperTorso")
		or Merchant.PrimaryPart
end

local function FindVampireBlood()
	local Character =
		Player.Character

	if Character then
		local Potion =
			Character:FindFirstChild(
				"Vampire Blood"
			)

		if Potion then
			return Potion
		end
	end

	local Backpack =
		Player:FindFirstChild(
			"Backpack"
		)

	if Backpack then
		local Potion =
			Backpack:FindFirstChild(
				"Vampire Blood"
			)

		if Potion then
			return Potion
		end
	end

	return nil
end

local function WaitForVampireBlood(
	Timeout
)
	local Start =
		os.clock()

	repeat
		local Potion =
			FindVampireBlood()

		if Potion then
			return Potion
		end

		task.wait(0.05)

	until
		os.clock() - Start
		>= Timeout

	return nil
end

local function StopDrinkEmote()
	pcall(function()
		PlayEmoteSound:FireServer(
			"Stop"
		)
	end)
end

local function ReturnToFarm(
	FallbackCFrame
)
	local Character,
		Humanoid,
		Root =
		WaitForCharacterReady()

	local ReturnCFrame =
		nil

	if CurrentTarget
		and IsValidHunter(
			CurrentTarget
		) then

		ReturnCFrame =
			select(
				1,
				GetSafestRearCFrame(
					CurrentTarget,
					Character,
					Humanoid,
					Root
				)
			)
	end

	ReturnCFrame =
		ReturnCFrame
		or FallbackCFrame

	if Root
		and ReturnCFrame then

		SetCharacterCFrame(
			Root,
			ReturnCFrame
		)
	end

	task.wait(0.12)

	if Enabled then
		ForceEquipFists()
	end
end

local function RefillVampireBlood()
	if RefillingBlood then
		return false
	end

	RefillingBlood = true

	local Character,
		Humanoid,
		Root =
		WaitForCharacterReady()

	if not Character
		or not Humanoid
		or not Root
		or Humanoid.Health <= 0 then

		RefillingBlood = false
		return false
	end

	local FallbackReturnCFrame =
		Root.CFrame

	----------------------------------------------------------
	-- Stop fighting
	----------------------------------------------------------

	pcall(function()
		Humanoid:UnequipTools()
	end)

	----------------------------------------------------------
	-- Merchant
	----------------------------------------------------------

	local Merchant =
		GetVampireMerchant()

	local MerchantRoot =
		GetMerchantRoot(
			Merchant
		)

	if not MerchantRoot then
		warn(
			"[AUTO BLOOD] ShopKeeper2 not found"
		)

		ReturnToFarm(
			FallbackReturnCFrame
		)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- Teleport in front of merchant
	----------------------------------------------------------

	local ShopCFrame =
		MerchantRoot.CFrame
		* CFrame.new(
			0,
			0,
			-4
		)

	SetCharacterCFrame(
		Root,
		ShopCFrame
	)

	task.wait(
		SHOP_SETTLE_TIME
	)

	----------------------------------------------------------
	-- Existing potion?
	----------------------------------------------------------

	local Potion =
		FindVampireBlood()

	if not Potion then
		------------------------------------------------------
		-- Buy directly, no shop GUI.
		------------------------------------------------------

		pcall(function()
			ShopRemote:FireServer(
				"Purchase",
				"Vampire Blood"
			)
		end)

		Potion =
			WaitForVampireBlood(
				POTION_WAIT_TIMEOUT
			)
	end

	if not Potion then
		warn(
			"[AUTO BLOOD] Vampire Blood purchase failed"
		)

		ReturnToFarm(
			FallbackReturnCFrame
		)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- Equip potion
	----------------------------------------------------------

	pcall(function()
		Humanoid:EquipTool(
			Potion
		)
	end)

	task.wait(0.10)

	Potion =
		FindVampireBlood()
		or Potion

	----------------------------------------------------------
	-- Drink
	----------------------------------------------------------

	pcall(function()
		DrinkPotionRemote:FireServer(
			Potion
		)
	end)

	----------------------------------------------------------
	-- Wait for blood
	----------------------------------------------------------

	local FillStart =
		os.clock()

	repeat
		task.wait(0.10)

		local Blood =
			GetBloodPercent()

		if Blood
			and Blood >= BLOOD_RESUME then

			break
		end

	until
		os.clock() - FillStart
		>= BLOOD_FILL_TIMEOUT

	StopDrinkEmote()

	task.wait(0.08)

	ReturnToFarm(
		FallbackReturnCFrame
	)

	RefillingBlood = false

	return true
end

--==============================================================
-- AUTO MONEY
--==============================================================

local function GetMoneyPart(
	Bag
)
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

	local Now =
		os.clock()

	if MoneyAttempt[Bag]
		and Now - MoneyAttempt[Bag]
			< MONEY_TOUCH_COOLDOWN then

		return false
	end

	MoneyAttempt[Bag] = Now

	----------------------------------------------------------
	-- Safe option: touch without moving the player.
	----------------------------------------------------------

	if type(firetouchinterest)
		== "function" then

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

	-- To prioritize survival, do not teleport away from the target
	-- merely to pick up money if touch simulation is unavailable.
	return false
end

local function CollectMoney()
	if not AUTO_MONEY
		or RefillingBlood then

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
		if Object.Name
			== "KillMoneyBag" then

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

GUI.Name =
	"AutoHunterFarmGUI"

GUI.ResetOnSpawn = false
GUI.Parent = PlayerGui

FarmGUI = GUI

--------------------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------------------

local Open =
	Instance.new("TextButton")

Open.Size =
	UDim2.fromOffset(
		140,
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
	"HUNTER SAFE FARM"

Open.TextColor3 =
	Color3.new(
		1,
		1,
		1
	)

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
		410,
		475
	)

Frame.Position =
	UDim2.new(
		0.5,
		-205,
		0.5,
		-237
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
Title.Text = "Auto Hunter Safe Farm"
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
-- MAIN TOGGLE
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
			115,
			0,
			38
		)

	Button.Position =
		UDim2.fromOffset(
			21
				+ (
					(Index - 1)
					* 124
				),
			143
		)

	Button.Text =
		Preset.Name

	Button.TextColor3 =
		Color3.new(
			1,
			1,
			1
		)

	Button.Font =
		Enum.Font.GothamBold

	Button.TextSize = 13
	Button.Parent = Frame

	Instance.new(
		"UICorner",
		Button
	).CornerRadius =
		UDim.new(0, 8)

	LevelButtons[Index] =
		Button
end

--------------------------------------------------------------
-- BEHIND DISTANCE
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
		193
	)

DistanceTitle.BackgroundTransparency = 1
DistanceTitle.Text = "Safe Behind Distance"
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
		92,
		42
	)

DistanceValue.Position =
	UDim2.new(
		0.5,
		-46,
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
-- AUTO BLOOD / MONEY
--------------------------------------------------------------

local BloodButton =
	Instance.new("TextButton")

BloodButton.Size =
	UDim2.new(
		0.5,
		-24,
		0,
		42
	)

BloodButton.Position =
	UDim2.fromOffset(
		18,
		284
	)

BloodButton.TextColor3 = Color3.new(1, 1, 1)
BloodButton.Font = Enum.Font.GothamBold
BloodButton.TextSize = 14
BloodButton.Parent = Frame

Instance.new(
	"UICorner",
	BloodButton
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
		284
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
-- BLOOD STATUS
--------------------------------------------------------------

local BloodStatus =
	Instance.new("TextLabel")

BloodStatus.Size =
	UDim2.new(
		1,
		-20,
		0,
		27
	)

BloodStatus.Position =
	UDim2.fromOffset(
		10,
		338
	)

BloodStatus.BackgroundTransparency = 1
BloodStatus.Text = "Blood: detecting..."
BloodStatus.TextColor3 = Color3.fromRGB(220, 120, 120)
BloodStatus.Font = Enum.Font.GothamBold
BloodStatus.TextSize = 13
BloodStatus.Parent = Frame

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
		366
	)

SafetyStatus.BackgroundTransparency = 1
SafetyStatus.Text = "Nearby threats: 0"
SafetyStatus.TextColor3 = Color3.fromRGB(135, 190, 230)
SafetyStatus.Font = Enum.Font.GothamBold
SafetyStatus.TextSize = 13
SafetyStatus.Parent = Frame

--------------------------------------------------------------
-- STATUS
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
		-70
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
		Toggle.Text =
			"AUTO HUNTER : ON"

		Toggle.BackgroundColor3 =
			Color3.fromRGB(
				45,
				155,
				80
			)
	else
		Toggle.Text =
			"AUTO HUNTER : OFF"

		Toggle.BackgroundColor3 =
			Color3.fromRGB(
				170,
				55,
				55
			)
	end

	for Index, Button in ipairs(
		LevelButtons
	) do
		if Index == SelectedPreset then
			Button.BackgroundColor3 =
				Color3.fromRGB(
					45,
					145,
					80
				)
		else
			Button.BackgroundColor3 =
				Color3.fromRGB(
					60,
					60,
					70
				)
		end
	end

	DistanceValue.Text =
		string.format(
			"%.2f",
			BEHIND_DISTANCE
		)

	if AUTO_BLOOD then
		BloodButton.Text =
			"AUTO BLOOD : ON"

		BloodButton.BackgroundColor3 =
			Color3.fromRGB(
				150,
				45,
				55
			)
	else
		BloodButton.Text =
			"AUTO BLOOD : OFF"

		BloodButton.BackgroundColor3 =
			Color3.fromRGB(
				65,
				65,
				75
			)
	end

	if AUTO_MONEY then
		MoneyButton.Text =
			"AUTO MONEY : ON"

		MoneyButton.BackgroundColor3 =
			Color3.fromRGB(
				180,
				135,
				45
			)
	else
		MoneyButton.Text =
			"AUTO MONEY : OFF"

		MoneyButton.BackgroundColor3 =
			Color3.fromRGB(
				65,
				65,
				75
			)
	end
end

--------------------------------------------------------------
-- GUI EVENTS
--------------------------------------------------------------

for Index, Button in ipairs(
	LevelButtons
) do
	Button.MouseButton1Click:Connect(
		function()
			SelectedPreset = Index
			CurrentTarget = nil
			LastTargetRecheck = 0

			UpdateGUI()
		end
	)
end

Toggle.MouseButton1Click:Connect(
	function()
		Enabled = not Enabled

		CurrentTarget = nil
		LastTargetRecheck = 0

		if Enabled then
			Status.Text =
				"Equipping Fists..."

			ForceEquipFists()

			RefreshThreatCache()

			Status.Text =
				"Searching safest Hunter..."
		else
			Status.Text = "Stopped"
		end

		UpdateGUI()
	end
)

DistancePlus.MouseButton1Click:Connect(
	function()
		BEHIND_DISTANCE +=
			BEHIND_STEP

		BEHIND_DISTANCE =
			math.clamp(
				BEHIND_DISTANCE,
				MIN_BEHIND_DISTANCE,
				MAX_BEHIND_DISTANCE
			)

		UpdateGUI()
	end
)

DistanceMinus.MouseButton1Click:Connect(
	function()
		BEHIND_DISTANCE -=
			BEHIND_STEP

		BEHIND_DISTANCE =
			math.clamp(
				BEHIND_DISTANCE,
				MIN_BEHIND_DISTANCE,
				MAX_BEHIND_DISTANCE
			)

		UpdateGUI()
	end
)

BloodButton.MouseButton1Click:Connect(
	function()
		AUTO_BLOOD =
			not AUTO_BLOOD

		UpdateGUI()
	end
)

MoneyButton.MouseButton1Click:Connect(
	function()
		AUTO_MONEY =
			not AUTO_MONEY

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
-- DAMAGE DETECTION
--==============================================================

local HealthConnection = nil

local function ConnectHealthMonitor(
	Character
)
	if HealthConnection then
		pcall(function()
			HealthConnection:Disconnect()
		end)

		HealthConnection = nil
	end

	local Humanoid =
		Character:FindFirstChildOfClass(
			"Humanoid"
		)

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

					-- Reconsider target quickly if player gets hit.
					LastTargetRecheck = 0
				end

				LastPlayerHealth =
					NewHealth
			end
		)
end

if Player.Character then
	ConnectHealthMonitor(
		Player.Character
	)
end

--------------------------------------------------------------
-- RESPAWN
--------------------------------------------------------------

Player.CharacterAdded:Connect(
	function(Character)
		CurrentTarget = nil
		LastTargetRecheck = 0

		ConnectHealthMonitor(
			Character
		)

		if not Enabled then
			return
		end

		local Humanoid =
			Character:WaitForChild(
				"Humanoid",
				10
			)

		Character:WaitForChild(
			"HumanoidRootPart",
			10
		)

		task.wait(0.75)

		if Enabled
			and Humanoid
			and Humanoid.Health > 0 then

			ForceEquipFists()
		end
	end
)

--==============================================================
-- THREAT CACHE LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled then
			local Now =
				os.clock()

			if Now - LastThreatRefresh
				>= THREAT_REFRESH_INTERVAL then

				LastThreatRefresh = Now

				RefreshThreatCache()
			end
		end

		task.wait(0.10)
	end
end)

--==============================================================
-- BLOOD LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled
			and AUTO_BLOOD
			and not RefillingBlood then

			local Now =
				os.clock()

			if Now - LastBloodCheck
				>= BLOOD_CHECK_INTERVAL then

				LastBloodCheck = Now

				local Blood =
					GetBloodPercent()

				if Blood then
					BloodStatus.Text =
						string.format(
							"Blood: %.0f%%",
							Blood * 100
						)

					if Blood <= BLOOD_TRIGGER
						and Now
							- LastBloodRefillAttempt
							>= BLOOD_RETRY_DELAY then

						LastBloodRefillAttempt =
							Now

						Status.Text =
							"Blood low - buying Vampire Blood..."

						RefillVampireBlood()

						local NewBlood =
							GetBloodPercent()

						if NewBlood then
							BloodStatus.Text =
								string.format(
									"Blood: %.0f%%",
									NewBlood * 100
								)
						end

						Status.Text =
							"Blood refilled - resuming farm"
					end
				else
					BloodStatus.Text =
						"Blood: detecting..."
				end
			end
		end

		task.wait(0.05)
	end
end)

--==============================================================
-- MONEY LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled
			and AUTO_MONEY
			and not RefillingBlood then

			local Now =
				os.clock()

			if Now - LastMoneyScan
				>= MONEY_SCAN_INTERVAL then

				LastMoneyScan = Now

				CollectMoney()
			end
		end

		task.wait(0.08)
	end
end)

--==============================================================
-- MAIN SAFE FARM LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled
			and not RefillingBlood then

			local Character,
				Humanoid,
				PlayerRoot =
				GetCharacter()

			if Humanoid
				and PlayerRoot
				and Humanoid.Health > 0 then

				local Now =
					os.clock()

				------------------------------------------------
				-- Fists must always be equipped.
				------------------------------------------------

				if Now - LastEquipCheck
					>= EQUIP_CHECK_INTERVAL then

					LastEquipCheck = Now

					local Fists =
						Character:FindFirstChild(
							"Fists"
						)

					if not Fists
						or not Fists:IsA("Tool") then

						EquipFists(
							Character,
							Humanoid
						)
					end
				end

				------------------------------------------------
				-- Re-evaluate safest Hunter.
				------------------------------------------------

				local NeedNewTarget =
					not IsValidHunter(
						CurrentTarget
					)

				if Now - LastTargetRecheck
					>= TARGET_RECHECK_INTERVAL then

					LastTargetRecheck = Now

					if NeedNewTarget then
						local NewTarget,
							ThreatCount =
							FindSafestHunter(
								PlayerRoot
							)

						CurrentTarget = NewTarget
						CurrentThreatCount =
							ThreatCount
					else
						local CurrentScore,
							CurrentDanger =
							GetHunterSafetyScore(
								CurrentTarget,
								PlayerRoot
							)

						CurrentThreatCount =
							CurrentDanger

						-- If current Hunter is surrounded, see if another
						-- Hunter is substantially safer.
						if CurrentDanger
							>= DANGER_SWITCH_THRESHOLD then

							local NewTarget,
								NewDanger =
								FindSafestHunter(
									PlayerRoot
								)

							if NewTarget
								and NewTarget
									~= CurrentTarget
								and NewDanger
									< CurrentDanger then

								CurrentTarget =
									NewTarget

								CurrentThreatCount =
									NewDanger
							end
						end
					end
				end

				------------------------------------------------
				-- No target
				------------------------------------------------

				if not IsValidHunter(
					CurrentTarget
				) then

					local Preset =
						LEVEL_PRESETS[
							SelectedPreset
						]

					Status.Text =
						"No Hunter Lv "
						.. Preset.Name

					SafetyStatus.Text =
						"Nearby threats: 0"

					task.wait(
						FOLLOW_INTERVAL
					)

					continue
				end

				------------------------------------------------
				-- Safe rear position
				------------------------------------------------

				local SafeCFrame,
					NearbyThreats =
					GetSafestRearCFrame(
						CurrentTarget,
						Character,
						Humanoid,
						PlayerRoot
					)

				CurrentThreatCount =
					NearbyThreats

				if SafeCFrame then
					SetCharacterCFrame(
						PlayerRoot,
						SafeCFrame
					)
				end

				------------------------------------------------
				-- Status
				------------------------------------------------

				local HunterHumanoid =
					CurrentTarget
					:FindFirstChildOfClass(
						"Humanoid"
					)

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

				SafetyStatus.Text =
					"Nearby threats: "
					.. tostring(
						NearbyThreats
					)

				------------------------------------------------
				-- Attack only when not in damage-evade window.
				------------------------------------------------

				if Now >= EvadeUntil then
					local Fists =
						EquipFists(
							Character,
							Humanoid
						)

					if Fists
						and Now - LastAttack
							>= ATTACK_INTERVAL then

						LastAttack = Now

						Attack(
							Character,
							Fists
						)
					end
				else
					Status.Text =
						"Evading damage..."
				end
			end
		end

		task.wait(
			FOLLOW_INTERVAL
		)
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
	RefillingBlood = false

	if HealthConnection then
		pcall(function()
			HealthConnection:Disconnect()
		end)

		HealthConnection = nil
	end

	if GUI then
		GUI:Destroy()
	end

	print(
		"[Auto Hunter Safe Farm] stopped"
	)
end

ENV.AutoHunterFarmStop =
	Stop

--------------------------------------------------------------
-- START
--------------------------------------------------------------

UpdateGUI()
RefreshThreatCache()

print("")
print("================================================")
print(" AUTO HUNTER SAFE FARM READY")
print("================================================")
print("NO Freeze / NO NPC teleport")
print("")
print("Hunter levels:")
print(" 100 - 300")
print(" 400 - 900")
print(" 1000 - 3000")
print("")
print("Safety:")
print(" - chooses safer Hunter")
print(" - stays behind target")
print(" - searches safest rear angle")
print(" - retreats briefly after taking damage")
print(" - switches away from crowded targets")
print("")
print("Auto Fists: ON with Auto Hunter")
print("Auto Blood trigger: <= 25%")
print("Auto Money: ON")
print("Behind Distance:", BEHIND_DISTANCE)
print("Danger Radius:", DANGER_RADIUS)
print("================================================")
