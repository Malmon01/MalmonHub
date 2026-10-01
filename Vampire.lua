--============================================================
-- AUTO HUNTER FARM - FREEZE GROUP BUILD
-- Standalone GitHub / loadstring version
--
-- Flow
--   1) Choose Hunter level range
--   2) AUTO HUNTER ON
--   3) Find every matching "Hunter" in Workspace.NPCS.HUNTERS
--   4) Pull them into one compact group
--   5) Freeze/lock the group in place
--   6) Stand behind the group
--   7) Auto-equip Fists and M1 continuously
--   8) Auto-collect KillMoneyBag drops
--   9) Blood <= 25%:
--        pause player attacking
--        keep Hunter group locked
--        teleport to ShopKeeper2
--        buy Vampire Blood by remote
--        equip + drink by remote
--        wait for blood refill
--        teleport back behind the frozen group
--        re-equip Fists and continue
--
-- Level presets
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
-- ENV / CLEAN PREVIOUS VERSION
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
	ReplicatedStorage[
		"Fun\195\167\195\181es"
	]

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
-- FARM SETTINGS
--------------------------------------------------------------

local ATTACK_INTERVAL = 0.20
local PLAYER_FOLLOW_INTERVAL = 0.035
local GROUP_LOCK_INTERVAL = 0.045
local EQUIP_CHECK_INTERVAL = 0.20

-- Player stands behind the frozen Hunter group.
local BEHIND_DISTANCE = 4.25
local MIN_BEHIND_DISTANCE = 2.75
local MAX_BEHIND_DISTANCE = 6.50
local BEHIND_STEP = 0.25

-- Hunters are packed in a small ring around the group center.
local GROUP_BASE_RADIUS = 0.75
local GROUP_RING_GROWTH = 0.30
local HUNTERS_PER_RING = 8

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

-- Refill only at 25% or below.
local BLOOD_TRIGGER = 0.25

-- Vampire Blood fills the bar; resume when detection reaches 90%.
local BLOOD_RESUME = 0.90

local BLOOD_CHECK_INTERVAL = 0.15
local BLOOD_RETRY_DELAY = 2.5
local POTION_WAIT_TIMEOUT = 5.0
local BLOOD_FILL_TIMEOUT = 8.0
local SHOP_SETTLE_TIME = 0.25

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
-- STATE
--------------------------------------------------------------

local Enabled = false
local Running = true
local RefillingBlood = false

local GroupAnchorPosition = nil
local GroupFacing = nil

local LastAttack = 0
local LastEquipCheck = 0
local LastMoneyScan = 0
local LastBloodCheck = 0
local LastBloodRefillAttempt = 0

local LastKnownBlood = nil
local LastFrozenCount = 0

-- Hunter -> saved state
local FrozenStates = {}

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
			local Number = tonumber(Value)

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
	-- Overhead text, e.g. "Hunter Lv 2536"
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
-- LEVEL / TARGET FILTER
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

	-- Exact Hunter only. HunterBow is ignored.
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

local function GetMatchingHunters()
	local Result = {}

	for _, Hunter in ipairs(
		HUNTERS:GetChildren()
	) do
		if IsValidHunter(Hunter) then
			Result[#Result + 1] =
				Hunter
		end
	end

	return Result
end

local function FindNearestMatchingHunter(
	PlayerRoot
)
	if not PlayerRoot then
		return nil
	end

	local BestHunter = nil
	local BestDistance = math.huge

	for _, Hunter in ipairs(
		GetMatchingHunters()
	) do
		local Root =
			GetHunterRoot(Hunter)

		if Root then
			local Distance =
				(
					Root.Position
					- PlayerRoot.Position
				).Magnitude

			if Distance < BestDistance then
				BestDistance = Distance
				BestHunter = Hunter
			end
		end
	end

	return BestHunter
end

--------------------------------------------------------------
-- GROUP ANCHOR
--------------------------------------------------------------

local function HorizontalUnit(Vector)
	local Flat =
		Vector3.new(
			Vector.X,
			0,
			Vector.Z
		)

	if Flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end

	return Flat.Unit
end

local function CaptureGroupAnchor()
	local Character,
		Humanoid,
		PlayerRoot =
		GetCharacter()

	if not PlayerRoot
		or not Humanoid
		or Humanoid.Health <= 0 then

		return false
	end

	local Nearest =
		FindNearestMatchingHunter(
			PlayerRoot
		)

	if not Nearest then
		GroupAnchorPosition = nil
		GroupFacing = nil

		return false
	end

	local HunterRoot =
		GetHunterRoot(Nearest)

	if not HunterRoot then
		return false
	end

	GroupAnchorPosition =
		HunterRoot.Position

	-- Use the Hunter's current facing so the player's position
	-- is genuinely behind the group.
	GroupFacing =
		HorizontalUnit(
			HunterRoot.CFrame.LookVector
		)

	return true
end

--------------------------------------------------------------
-- SAVE / RESTORE HUNTER STATE
--------------------------------------------------------------

local function SaveHunterState(Hunter)
	if FrozenStates[Hunter] then
		return FrozenStates[Hunter]
	end

	local Humanoid =
		Hunter:FindFirstChildOfClass("Humanoid")

	local Root =
		GetHunterRoot(Hunter)

	if not Humanoid or not Root then
		return nil
	end

	local State = {
		Humanoid = Humanoid,
		Root = Root,

		WalkSpeed = Humanoid.WalkSpeed,
		AutoRotate = Humanoid.AutoRotate,
		JumpPower = Humanoid.JumpPower,
		JumpHeight = Humanoid.JumpHeight,

		RootAnchored = Root.Anchored,

		Parts = {}
	}

	for _, Part in ipairs(
		Hunter:GetDescendants()
	) do
		if Part:IsA("BasePart") then
			State.Parts[Part] = {
				CanCollide =
					Part.CanCollide
			}
		end
	end

	FrozenStates[Hunter] = State

	return State
end

local function RestoreHunter(Hunter)
	local State =
		FrozenStates[Hunter]

	if not State then
		return
	end

	local Humanoid =
		State.Humanoid

	local Root =
		State.Root

	if Humanoid
		and Humanoid.Parent then

		pcall(function()
			Humanoid.WalkSpeed =
				State.WalkSpeed

			Humanoid.AutoRotate =
				State.AutoRotate

			Humanoid.JumpPower =
				State.JumpPower

			Humanoid.JumpHeight =
				State.JumpHeight
		end)
	end

	if Root
		and Root.Parent then

		pcall(function()
			Root.Anchored =
				State.RootAnchored
		end)
	end

	for Part, Data in pairs(
		State.Parts
	) do
		if Part
			and Part.Parent then

			pcall(function()
				Part.CanCollide =
					Data.CanCollide
			end)
		end
	end

	FrozenStates[Hunter] = nil
end

local function RestoreAllHunters()
	local List = {}

	for Hunter in pairs(
		FrozenStates
	) do
		List[#List + 1] =
			Hunter
	end

	for _, Hunter in ipairs(List) do
		RestoreHunter(Hunter)
	end

	LastFrozenCount = 0
end

--------------------------------------------------------------
-- FREEZE + POSITION GROUP
--------------------------------------------------------------

local function GetGroupSlot(
	Index,
	Count
)
	-- Compact circular rings around the anchor.
	local ZeroIndex =
		Index - 1

	local Ring =
		math.floor(
			ZeroIndex
			/ HUNTERS_PER_RING
		)

	local PositionInRing =
		ZeroIndex
		% HUNTERS_PER_RING

	local ItemsThisRing =
		math.min(
			HUNTERS_PER_RING,
			math.max(
				1,
				Count
				- Ring
				* HUNTERS_PER_RING
			)
		)

	local Radius =
		GROUP_BASE_RADIUS
		+ Ring
		* GROUP_RING_GROWTH

	if Count == 1 then
		Radius = 0
	end

	local Angle =
		(
			PositionInRing
			/ ItemsThisRing
		)
		* math.pi
		* 2

	local Right =
		Vector3.new(
			-GroupFacing.Z,
			0,
			GroupFacing.X
		)

	local Side =
		math.cos(Angle)
		* Radius

	local Forward =
		math.sin(Angle)
		* Radius

	return
		GroupAnchorPosition
		+ Right * Side
		+ GroupFacing * Forward
end

local function LockHunterAt(
	Hunter,
	Position
)
	local Humanoid =
		Hunter:FindFirstChildOfClass("Humanoid")

	local Root =
		GetHunterRoot(Hunter)

	if not Humanoid
		or not Root
		or Humanoid.Health <= 0 then

		return false
	end

	local State =
		SaveHunterState(Hunter)

	if not State then
		return false
	end

	----------------------------------------------------------
	-- Freeze
	----------------------------------------------------------

	pcall(function()
		Humanoid.WalkSpeed = 0
		Humanoid.AutoRotate = false
		Humanoid.JumpPower = 0
		Humanoid.JumpHeight = 0
	end)

	----------------------------------------------------------
	-- Disable collision inside the packed group
	----------------------------------------------------------

	for Part in pairs(
		State.Parts
	) do
		if Part
			and Part.Parent then

			pcall(function()
				Part.CanCollide = false
				Part.AssemblyLinearVelocity =
					Vector3.zero

				Part.AssemblyAngularVelocity =
					Vector3.zero
			end)
		end
	end

	----------------------------------------------------------
	-- Anchor root + lock orientation
	----------------------------------------------------------

	pcall(function()
		Root.Anchored = true

		local TargetCFrame =
			CFrame.lookAt(
				Position,
				Position + GroupFacing
			)

		Hunter:PivotTo(
			TargetCFrame
		)

		Root.AssemblyLinearVelocity =
			Vector3.zero

		Root.AssemblyAngularVelocity =
			Vector3.zero
	end)

	return true
end

local function LockHunterGroup()
	if not Enabled then
		return 0
	end

	if not GroupAnchorPosition
		or not GroupFacing then

		if not CaptureGroupAnchor() then
			return 0
		end
	end

	local Matching =
		GetMatchingHunters()

	----------------------------------------------------------
	-- Restore Hunters that are no longer in the selected group
	----------------------------------------------------------

	local CurrentSet = {}

	for _, Hunter in ipairs(Matching) do
		CurrentSet[Hunter] = true
	end

	local RestoreList = {}

	for Hunter in pairs(
		FrozenStates
	) do
		if not CurrentSet[Hunter]
			or not Hunter.Parent then

			RestoreList[#RestoreList + 1] =
				Hunter
		end
	end

	for _, Hunter in ipairs(
		RestoreList
	) do
		RestoreHunter(Hunter)
	end

	----------------------------------------------------------
	-- Freeze every matching Hunter
	----------------------------------------------------------

	local Count = 0

	for Index, Hunter in ipairs(
		Matching
	) do
		local Position =
			GetGroupSlot(
				Index,
				#Matching
			)

		if LockHunterAt(
			Hunter,
			Position
		) then

			Count += 1
		end
	end

	LastFrozenCount = Count

	return Count
end

--------------------------------------------------------------
-- PLAYER POSITION BEHIND GROUP
--------------------------------------------------------------

local function MovePlayerBehindGroup(
	PlayerRoot
)
	if not GroupAnchorPosition
		or not GroupFacing
		or not PlayerRoot then

		return
	end

	local Position =
		GroupAnchorPosition
		- GroupFacing
		* BEHIND_DISTANCE

	-- Slightly lower than root center so the character does not
	-- overlap the middle of the packed Hunters.
	Position +=
		Vector3.new(
			0,
			-0.35,
			0
		)

	SetCharacterCFrame(
		PlayerRoot,
		CFrame.lookAt(
			Position,
			GroupAnchorPosition
		)
	)
end

--------------------------------------------------------------
-- FISTS / ATTACK
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

	task.wait(0.03)

	return Character:FindFirstChild("Fists")
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

	return EquipFists(
		Character,
		Humanoid
	)
end

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
		Fists:FindFirstChild("fistremote")

	if FistRemote
		and FistRemote:IsA("RemoteEvent") then

		pcall(function()
			FistRemote:FireServer(
				"lmb"
			)
		end)
	end

	----------------------------------------------------------
	-- Arczis Combat M1
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
		if Object:IsA("GuiObject")
			and Object.Visible then

			local Name =
				string.lower(Object.Name)

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
			-- Text-based blood
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
			-- Vertical red fill
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

						local Score = Height

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
						local Score = Height

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

	for _, Object in ipairs({
		Player,
		Character,
		Humanoid
	}) do
		local Percent =
			BloodFromAttributes(Object)

		if Percent then
			LastKnownBlood = Percent
			return Percent
		end
	end

	for _, Object in ipairs({
		Player,
		Character
	}) do
		local Percent =
			BloodFromValues(Object)

		if Percent then
			LastKnownBlood = Percent
			return Percent
		end
	end

	local Percent =
		BloodFromGUI()

	if Percent then
		LastKnownBlood = Percent
		return Percent
	end

	return LastKnownBlood
end

--==============================================================
-- AUTO BLOOD
--==============================================================

local function GetVampireMerchant()
	----------------------------------------------------------
	-- Known map path
	----------------------------------------------------------

	local Mapa =
		workspace:FindFirstChild("Mapa")

	if Mapa then
		local Cidade =
			Mapa:FindFirstChild("CIDADE")

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
		Player:FindFirstChild("Backpack")

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
	local Start = os.clock()

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

local function GetBehindGroupCFrame()
	if not GroupAnchorPosition
		or not GroupFacing then

		return nil
	end

	local Position =
		GroupAnchorPosition
		- GroupFacing
		* BEHIND_DISTANCE

	Position +=
		Vector3.new(
			0,
			-0.35,
			0
		)

	return
		CFrame.lookAt(
			Position,
			GroupAnchorPosition
		)
end

local function ReturnFromBloodShop(
	FallbackCFrame
)
	local Character,
		Humanoid,
		Root =
		WaitForCharacterReady()

	local ReturnCFrame =
		GetBehindGroupCFrame()
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
	-- Stop attacking and unequip Fists.
	----------------------------------------------------------

	pcall(function()
		Humanoid:UnequipTools()
	end)

	----------------------------------------------------------
	-- Find merchant
	----------------------------------------------------------

	local Merchant =
		GetVampireMerchant()

	local MerchantRoot =
		GetMerchantRoot(Merchant)

	if not MerchantRoot then
		warn(
			"[AUTO BLOOD] ShopKeeper2 not found"
		)

		ReturnFromBloodShop(
			FallbackReturnCFrame
		)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- TP in front of merchant
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

	task.wait(SHOP_SETTLE_TIME)

	----------------------------------------------------------
	-- Reuse an existing bottle if one is already available.
	----------------------------------------------------------

	local Potion =
		FindVampireBlood()

	if not Potion then
		------------------------------------------------------
		-- Direct purchase remote
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

		ReturnFromBloodShop(
			FallbackReturnCFrame
		)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- Equip potion
	----------------------------------------------------------

	pcall(function()
		Humanoid:EquipTool(Potion)
	end)

	task.wait(0.10)

	Potion =
		FindVampireBlood()
		or Potion

	----------------------------------------------------------
	-- Drink remote
	----------------------------------------------------------

	pcall(function()
		DrinkPotionRemote:FireServer(
			Potion
		)
	end)

	----------------------------------------------------------
	-- Wait for full/near-full blood
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

	----------------------------------------------------------
	-- Stop drink emote/audio and return
	----------------------------------------------------------

	StopDrinkEmote()

	task.wait(0.08)

	ReturnFromBloodShop(
		FallbackReturnCFrame
	)

	RefillingBlood = false
	return true
end

--==============================================================
-- MONEY
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

		return Bag:FindFirstChildWhichIsA(
			"BasePart",
			true
		)
	end

	return Bag:FindFirstChildWhichIsA(
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

		return
	end

	local Now = os.clock()

	if MoneyAttempt[Bag]
		and Now - MoneyAttempt[Bag]
			< MONEY_TOUCH_COOLDOWN then

		return
	end

	MoneyAttempt[Bag] = Now

	----------------------------------------------------------
	-- Prefer touch simulation so player does not leave group.
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

		return
	end

	----------------------------------------------------------
	-- Fallback touch teleport
	----------------------------------------------------------

	local OldCFrame =
		PlayerRoot.CFrame

	SetCharacterCFrame(
		PlayerRoot,
		Part.CFrame
		+ Vector3.new(
			0,
			1.5,
			0
		)
	)

	task.wait(0.045)

	if PlayerRoot.Parent then
		SetCharacterCFrame(
			PlayerRoot,
			OldCFrame
		)
	end
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

			CollectBag(
				Object,
				PlayerRoot
			)

			Count += 1
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
		135,
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

Open.Text = "HUNTER FARM"
Open.TextColor3 = Color3.new(1, 1, 1)
Open.Font = Enum.Font.GothamBold
Open.TextSize = 14
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
		400,
		455
	)

Frame.Position =
	UDim2.new(
		0.5,
		-200,
		0.5,
		-227
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
Title.Text = "Auto Hunter Freeze Farm"
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
			112,
			0,
			38
		)

	Button.Position =
		UDim2.fromOffset(
			20
				+ ((Index - 1) * 122),
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

	LevelButtons[Index] =
		Button
end

--------------------------------------------------------------
-- BEHIND DISTANCE
--------------------------------------------------------------

local DistanceLabel =
	Instance.new("TextLabel")

DistanceLabel.Size =
	UDim2.new(
		1,
		0,
		0,
		30
	)

DistanceLabel.Position =
	UDim2.fromOffset(
		0,
		190
	)

DistanceLabel.BackgroundTransparency = 1
DistanceLabel.Text = "Distance Behind Group"
DistanceLabel.TextColor3 = Color3.new(1, 1, 1)
DistanceLabel.Font = Enum.Font.GothamBold
DistanceLabel.TextSize = 15
DistanceLabel.Parent = Frame

local DistanceMinus =
	Instance.new("TextButton")

DistanceMinus.Size =
	UDim2.fromOffset(
		60,
		42
	)

DistanceMinus.Position =
	UDim2.fromOffset(
		70,
		220
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
		90,
		42
	)

DistanceValue.Position =
	UDim2.new(
		0.5,
		-45,
		0,
		220
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
		60,
		42
	)

DistancePlus.Position =
	UDim2.new(
		1,
		-130,
		0,
		220
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
		278
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
		278
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
		28
	)

BloodStatus.Position =
	UDim2.fromOffset(
		10,
		332
	)

BloodStatus.BackgroundTransparency = 1
BloodStatus.Text = "Blood: detecting..."
BloodStatus.TextColor3 = Color3.fromRGB(220, 120, 120)
BloodStatus.Font = Enum.Font.GothamBold
BloodStatus.TextSize = 13
BloodStatus.Parent = Frame

--------------------------------------------------------------
-- GROUP STATUS
--------------------------------------------------------------

local GroupStatus =
	Instance.new("TextLabel")

GroupStatus.Size =
	UDim2.new(
		1,
		-20,
		0,
		28
	)

GroupStatus.Position =
	UDim2.fromOffset(
		10,
		360
	)

GroupStatus.BackgroundTransparency = 1
GroupStatus.Text = "Frozen Hunters: 0"
GroupStatus.TextColor3 = Color3.fromRGB(130, 190, 230)
GroupStatus.Font = Enum.Font.GothamBold
GroupStatus.TextSize = 13
GroupStatus.Parent = Frame

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
		55
	)

Status.Position =
	UDim2.new(
		0,
		10,
		1,
		-62
	)

Status.BackgroundTransparency = 1
Status.Text = "Ready"
Status.TextColor3 = Color3.fromRGB(160, 215, 165)
Status.Font = Enum.Font.Gotham
Status.TextSize = 13
Status.TextWrapped = true
Status.Parent = Frame

--------------------------------------------------------------
-- GUI UPDATE
--------------------------------------------------------------

local function UpdateGUI()
	if Enabled then
		Toggle.Text = "AUTO HUNTER : ON"
		Toggle.BackgroundColor3 = Color3.fromRGB(45, 155, 80)
	else
		Toggle.Text = "AUTO HUNTER : OFF"
		Toggle.BackgroundColor3 = Color3.fromRGB(170, 55, 55)
	end

	for Index, Button in ipairs(
		LevelButtons
	) do
		if Index == SelectedPreset then
			Button.BackgroundColor3 = Color3.fromRGB(45, 145, 80)
		else
			Button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end
	end

	DistanceValue.Text =
		string.format(
			"%.2f",
			BEHIND_DISTANCE
		)

	if AUTO_BLOOD then
		BloodButton.Text = "AUTO BLOOD : ON"
		BloodButton.BackgroundColor3 = Color3.fromRGB(150, 45, 55)
	else
		BloodButton.Text = "AUTO BLOOD : OFF"
		BloodButton.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	end

	if AUTO_MONEY then
		MoneyButton.Text = "AUTO MONEY : ON"
		MoneyButton.BackgroundColor3 = Color3.fromRGB(180, 135, 45)
	else
		MoneyButton.Text = "AUTO MONEY : OFF"
		MoneyButton.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	end

	GroupStatus.Text =
		"Frozen Hunters: "
		.. tostring(
			LastFrozenCount
		)
end

--------------------------------------------------------------
-- GUI EVENTS
--------------------------------------------------------------

for Index, Button in ipairs(
	LevelButtons
) do
	Button.MouseButton1Click:Connect(
		function()
			if SelectedPreset == Index then
				return
			end

			SelectedPreset = Index

			RestoreAllHunters()

			GroupAnchorPosition = nil
			GroupFacing = nil

			if Enabled then
				CaptureGroupAnchor()
				LockHunterGroup()
			end

			UpdateGUI()
		end
	)
end

Toggle.MouseButton1Click:Connect(
	function()
		Enabled = not Enabled

		if Enabled then
			Status.Text =
				"Gathering Hunters..."

			ForceEquipFists()

			GroupAnchorPosition = nil
			GroupFacing = nil

			CaptureGroupAnchor()
			LockHunterGroup()
		else
			Status.Text = "Stopped"

			RestoreAllHunters()

			GroupAnchorPosition = nil
			GroupFacing = nil
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
-- GROUP LOCK LOOP
-- Keeps Hunters frozen even while player is away buying blood.
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		if Enabled then
			local Count =
				LockHunterGroup()

			if Count ~= LastFrozenCount then
				LastFrozenCount = Count
			end

			GroupStatus.Text =
				"Frozen Hunters: "
				.. tostring(Count)
		end

		task.wait(
			GROUP_LOCK_INTERVAL
		)
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

			local Now = os.clock()

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
						and Now - LastBloodRefillAttempt
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
							"Returned to Hunter group"
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

			local Now = os.clock()

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
-- PLAYER FARM LOOP
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

				------------------------------------------------
				-- Ensure group exists
				------------------------------------------------

				if not GroupAnchorPosition
					or not GroupFacing then

					CaptureGroupAnchor()
				end

				if GroupAnchorPosition
					and GroupFacing then

					------------------------------------------------
					-- Keep Fists equipped
					------------------------------------------------

					local Now =
						os.clock()

					if Now - LastEquipCheck
						>= EQUIP_CHECK_INTERVAL then

						LastEquipCheck =
							Now

						local Fists =
							Character:FindFirstChild(
								"Fists"
							)

						if not Fists
							or not Fists:IsA(
								"Tool"
							) then

							EquipFists(
								Character,
								Humanoid
							)
						end
					end

					local Fists =
						EquipFists(
							Character,
							Humanoid
						)

					------------------------------------------------
					-- Stand behind frozen Hunter group
					------------------------------------------------

					MovePlayerBehindGroup(
						PlayerRoot
					)

					------------------------------------------------
					-- Attack
					------------------------------------------------

					if Now - LastAttack
						>= ATTACK_INTERVAL then

						LastAttack = Now

						Attack(
							Character,
							Fists
						)
					end

					local Preset =
						LEVEL_PRESETS[
							SelectedPreset
						]

					Status.Text =
						"Lv "
						.. Preset.Name
						.. " | Frozen "
						.. tostring(
							LastFrozenCount
						)
				else
					local Preset =
						LEVEL_PRESETS[
							SelectedPreset
						]

					Status.Text =
						"No Hunter Lv "
						.. Preset.Name
				end
			end
		end

		task.wait(
			PLAYER_FOLLOW_INTERVAL
		)
	end
end)

--==============================================================
-- RESPAWN
--==============================================================

Player.CharacterAdded:Connect(
	function(Character)
		if not Running then
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

			if GroupAnchorPosition
				and GroupFacing then

				local Root =
					Character:FindFirstChild(
						"HumanoidRootPart"
					)

				if Root then
					MovePlayerBehindGroup(
						Root
					)
				end
			end
		end
	end
)

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

	RestoreAllHunters()

	GroupAnchorPosition = nil
	GroupFacing = nil

	if GUI then
		GUI:Destroy()
	end

	print(
		"[Auto Hunter Freeze Farm] stopped"
	)
end

ENV.AutoHunterFarmStop =
	Stop

--------------------------------------------------------------
-- START
--------------------------------------------------------------

UpdateGUI()

print("")
print("================================================")
print(" AUTO HUNTER FREEZE FARM READY")
print("================================================")
print("Hunter levels:")
print(" 100 - 300")
print(" 400 - 900")
print(" 1000 - 3000")
print("")
print("Mode:")
print(" Gather ALL matching Hunters")
print(" Freeze/lock them in a compact group")
print(" Stand behind group")
print(" Auto equip Fists")
print(" Auto M1")
print("")
print("Auto Blood: <= 25%")
print("Auto Money: ON")
print("Behind Distance:", BEHIND_DISTANCE)
print("================================================")
