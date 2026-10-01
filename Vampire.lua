--============================================================
-- AUTO HUNTER FARM - STANDALONE / GITHUB LOADSTRING
-- Version: optimized full build
--
-- Features
--   • Hunter level presets: 100-300 / 400-900 / 1000-3000
--   • Auto equip Fists immediately when Auto Hunter is enabled
--   • Re-equip Fists automatically after respawn / if unequipped
--   • Teleport under nearest matching Hunter
--   • Auto M1: Tool:Activate + fistremote("lmb") + CombatEvent("M1", timestamp)
--   • Adjustable Hunter hitbox
--   • Auto collect Workspace.DroppedMoney.KillMoneyBag
--   • Auto Blood:
--       Blood <= 25%
--       -> stop farming
--       -> remember farm position
--       -> teleport to Vampire Merchant (ShopKeeper2)
--       -> buy "Vampire Blood" with ShopRemote
--       -> equip potion
--       -> drink with DrinkPotionRemote
--       -> wait for blood to refill
--       -> stop emote sound
--       -> return to farm position
--       -> re-equip Fists
--       -> continue farming
--   • Draggable GUI
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
-- ENVIRONMENT / CLEAN PREVIOUS VERSION
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

local OldGui = PlayerGui:FindFirstChild("AutoHunterFarmGUI")
if OldGui then
	OldGui:Destroy()
end

--------------------------------------------------------------
-- GAME OBJECTS
--------------------------------------------------------------

local NPCS = workspace:WaitForChild("NPCS")
local HUNTERS = NPCS:WaitForChild("HUNTERS")
local DROPPED_MONEY = workspace:WaitForChild("DroppedMoney")

local ArczisCombat =
	ReplicatedStorage
	:WaitForChild("ArczisCombat")

local CombatEvent =
	ArczisCombat
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
local FOLLOW_INTERVAL = 0.035
local EQUIP_CHECK_INTERVAL = 0.20

-- Position below Hunter.HumanoidRootPart.
local UNDER_DISTANCE = 3.5

--------------------------------------------------------------
-- HITBOX SETTINGS
--------------------------------------------------------------

local HITBOX_SIZE = 20
local MIN_HITBOX = 6
local MAX_HITBOX = 60
local HITBOX_STEP = 2

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

-- Go refill at 25% or below.
local BLOOD_TRIGGER = 0.25

-- Vampire Blood should fill the bar; return once it reaches this.
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

-- Default highlighted option.
local SelectedPreset = 1

--------------------------------------------------------------
-- RUNTIME STATE
--------------------------------------------------------------

local Enabled = false
local Running = true
local RefillingBlood = false

local CurrentTarget = nil

local LastAttack = 0
local LastEquipCheck = 0
local LastMoneyScan = 0
local LastBloodCheck = 0
local LastBloodRefillAttempt = 0

local LastKnownBlood = nil

local OriginalHitboxes = {}
local MoneyAttempt = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------
-- CHARACTER HELPERS
--------------------------------------------------------------

local function GetCharacter()
	local Character = Player.Character

	if not Character then
		Character = Player.CharacterAdded:Wait()
	end

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
		Character:WaitForChild("Humanoid", 10)

	local Root =
		Character:WaitForChild("HumanoidRootPart", 10)

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
	-- Overhead text, e.g. "Hunter Lv 643"
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

	-- Hunter only; HunterBow is ignored.
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

local function FindNearestHunter(PlayerRoot)
	if not PlayerRoot then
		return nil
	end

	local BestTarget = nil
	local BestDistance = math.huge

	for _, Hunter in ipairs(HUNTERS:GetChildren()) do
		if IsValidHunter(Hunter) then
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
					BestTarget = Hunter
				end
			end
		end
	end

	return BestTarget, BestDistance
end

--------------------------------------------------------------
-- HITBOX SYSTEM
--------------------------------------------------------------

local function SaveOriginalHitbox(Root)
	if OriginalHitboxes[Root] then
		return
	end

	OriginalHitboxes[Root] = {
		Size = Root.Size,
		Transparency = Root.Transparency,
		CanCollide = Root.CanCollide,
		CanTouch = Root.CanTouch,
		CanQuery = Root.CanQuery
	}
end

local function ExpandHunterHitbox(Hunter)
	local Root = GetHunterRoot(Hunter)

	if not Root
		or not Root:IsA("BasePart") then
		return
	end

	SaveOriginalHitbox(Root)

	Root.Size =
		Vector3.new(
			HITBOX_SIZE,
			HITBOX_SIZE,
			HITBOX_SIZE
		)

	Root.Transparency = 0.75
	Root.CanCollide = false
	Root.CanTouch = true
	Root.CanQuery = true
end

local function RestoreHitboxes()
	for Root, Data in pairs(OriginalHitboxes) do
		if Root and Root.Parent then
			pcall(function()
				Root.Size = Data.Size
				Root.Transparency = Data.Transparency
				Root.CanCollide = Data.CanCollide
				Root.CanTouch = Data.CanTouch
				Root.CanQuery = Data.CanQuery
			end)
		end
	end

	table.clear(OriginalHitboxes)
end

local function UpdateHitboxes()
	RestoreHitboxes()

	if not Enabled then
		return
	end

	for _, Hunter in ipairs(HUNTERS:GetChildren()) do
		if IsValidHunter(Hunter) then
			ExpandHunterHitbox(Hunter)
		end
	end
end

--------------------------------------------------------------
-- FISTS / ATTACK SYSTEM
--------------------------------------------------------------

local function EquipFists(Character, Humanoid)
	if not Character
		or not Humanoid
		or Humanoid.Health <= 0 then
		return nil
	end

	----------------------------------------------------------
	-- Already equipped
	----------------------------------------------------------

	local Fists =
		Character:FindFirstChild("Fists")

	if Fists
		and Fists:IsA("Tool") then
		return Fists
	end

	----------------------------------------------------------
	-- Backpack
	----------------------------------------------------------

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
	local Character, Humanoid =
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

local function TeleportUnderHunter(
	Hunter,
	PlayerRoot
)
	local HunterRoot =
		GetHunterRoot(Hunter)

	if not HunterRoot
		or not PlayerRoot then
		return
	end

	local Position =
		HunterRoot.Position
		- Vector3.new(
			0,
			UNDER_DISTANCE,
			0
		)

	SetCharacterCFrame(
		PlayerRoot,
		CFrame.lookAt(
			Position,
			HunterRoot.Position
		)
	)
end

local function Attack(Character, Fists)
	if not Fists
		or Fists.Parent ~= Character then
		return
	end

	----------------------------------------------------------
	-- Tool activation / animation
	----------------------------------------------------------

	pcall(function()
		Fists:Activate()
	end)

	----------------------------------------------------------
	-- Fists remote captured earlier
	----------------------------------------------------------

	local FistRemote =
		Fists:FindFirstChild("fistremote")

	if FistRemote
		and FistRemote:IsA("RemoteEvent") then

		pcall(function()
			FistRemote:FireServer("lmb")
		end)
	end

	----------------------------------------------------------
	-- Arczis Combat M1 captured from CombatEvent
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

local function NameMatches(Name, List)
	Name = string.lower(Name)

	for _, Target in ipairs(List) do
		if Name == Target then
			return true
		end
	end

	return false
end

local function BloodFromAttributes(Object)
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

local function BloodFromValues(Root)
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

local function IsRedGui(Object)
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
							tonumber(Percent) / 100,
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
						Height / ParentHeight

					if Ratio > 0
						and Ratio <= 1.05 then

						Ratio =
							math.clamp(
								Ratio,
								0,
								1
							)

						local Score = 0

						if NamedBlood then
							Score += 100
						end

						Score += Height

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
	local Character, Humanoid =
		GetCharacter()

	----------------------------------------------------------
	-- Attributes first
	----------------------------------------------------------

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

	----------------------------------------------------------
	-- Values second
	----------------------------------------------------------

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
	-- Known path from the map
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

local function GetMerchantRoot(Merchant)
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
			Character:FindFirstChild("Vampire Blood")

		if Potion then
			return Potion
		end
	end

	local Backpack =
		Player:FindFirstChild("Backpack")

	if Backpack then
		local Potion =
			Backpack:FindFirstChild("Vampire Blood")

		if Potion then
			return Potion
		end
	end

	return nil
end

local function WaitForVampireBlood(Timeout)
	local Start = os.clock()

	repeat
		local Potion =
			FindVampireBlood()

		if Potion then
			return Potion
		end

		task.wait(0.05)
	until
		os.clock() - Start >= Timeout

	return nil
end

local function StopDrinkEmote()
	pcall(function()
		PlayEmoteSound:FireServer("Stop")
	end)
end

local function ReturnToFarm(ReturnCFrame)
	local Character,
		Humanoid,
		Root =
		WaitForCharacterReady()

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

	CurrentTarget = nil
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

	----------------------------------------------------------
	-- Save the farm position.
	----------------------------------------------------------

	local ReturnCFrame =
		Root.CFrame

	----------------------------------------------------------
	-- Stop attacking / unequip Fists.
	----------------------------------------------------------

	CurrentTarget = nil

	pcall(function()
		Humanoid:UnequipTools()
	end)

	----------------------------------------------------------
	-- Find merchant.
	----------------------------------------------------------

	local Merchant =
		GetVampireMerchant()

	local MerchantRoot =
		GetMerchantRoot(Merchant)

	if not MerchantRoot then
		warn("[AUTO BLOOD] ShopKeeper2 not found")

		ReturnToFarm(ReturnCFrame)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- Teleport to the Vampire Merchant and stand still.
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
	-- If a bottle already exists, reuse it.
	----------------------------------------------------------

	local Potion =
		FindVampireBlood()

	if not Potion then
		------------------------------------------------------
		-- Purchase directly without opening the shop.
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
		warn("[AUTO BLOOD] Vampire Blood purchase failed")

		ReturnToFarm(ReturnCFrame)

		RefillingBlood = false
		return false
	end

	----------------------------------------------------------
	-- Equip Vampire Blood.
	----------------------------------------------------------

	pcall(function()
		Humanoid:EquipTool(Potion)
	end)

	task.wait(0.10)

	Potion =
		FindVampireBlood()
		or Potion

	----------------------------------------------------------
	-- Drink directly using the captured remote.
	-- The live potion instance is supplied; no DebugId is hardcoded.
	----------------------------------------------------------

	pcall(function()
		DrinkPotionRemote:FireServer(
			Potion
		)
	end)

	----------------------------------------------------------
	-- Wait for blood to refill.
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
	-- Stop drink/emote sound then return to farm.
	----------------------------------------------------------

	StopDrinkEmote()

	task.wait(0.08)

	ReturnToFarm(ReturnCFrame)

	RefillingBlood = false
	return true
end

--==============================================================
-- MONEY SYSTEM
--==============================================================

local function GetMoneyPart(Bag)
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
	-- Prefer touch simulation so farming position is not disturbed.
	----------------------------------------------------------

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

		return
	end

	----------------------------------------------------------
	-- Fallback: touch the bag briefly and return.
	----------------------------------------------------------

	local OldCFrame =
		PlayerRoot.CFrame

	pcall(function()
		SetCharacterCFrame(
			PlayerRoot,
			Part.CFrame
			+ Vector3.new(
				0,
				1.5,
				0
			)
		)
	end)

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
		if Object.Name == "KillMoneyBag" then
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
-- OPEN BUTTON
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
-- MAIN FRAME
--------------------------------------------------------------

local Frame =
	Instance.new("Frame")

Frame.Size =
	UDim2.fromOffset(
		390,
		430
	)

Frame.Position =
	UDim2.new(
		0.5,
		-195,
		0.5,
		-215
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
Title.Text = "Auto Hunter Farm"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 21
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
		30
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
			110,
			0,
			38
		)

	Button.Position =
		UDim2.fromOffset(
			20 + ((Index - 1) * 120),
			145
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
-- HITBOX LABEL
--------------------------------------------------------------

local HitboxLabel =
	Instance.new("TextLabel")

HitboxLabel.Size =
	UDim2.new(
		1,
		0,
		0,
		30
	)

HitboxLabel.Position =
	UDim2.fromOffset(
		0,
		190
	)

HitboxLabel.BackgroundTransparency = 1
HitboxLabel.Text = "Hunter Hitbox Size"
HitboxLabel.TextColor3 = Color3.new(1, 1, 1)
HitboxLabel.Font = Enum.Font.GothamBold
HitboxLabel.TextSize = 15
HitboxLabel.Parent = Frame

--------------------------------------------------------------
-- HITBOX -
--------------------------------------------------------------

local HMinus =
	Instance.new("TextButton")

HMinus.Size =
	UDim2.fromOffset(
		60,
		42
	)

HMinus.Position =
	UDim2.fromOffset(
		65,
		220
	)

HMinus.Text = "−"
HMinus.TextColor3 = Color3.new(1, 1, 1)
HMinus.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
HMinus.Font = Enum.Font.GothamBold
HMinus.TextSize = 26
HMinus.Parent = Frame

Instance.new(
	"UICorner",
	HMinus
).CornerRadius =
	UDim.new(0, 8)

--------------------------------------------------------------
-- HITBOX VALUE
--------------------------------------------------------------

local HValue =
	Instance.new("TextLabel")

HValue.Size =
	UDim2.fromOffset(
		80,
		42
	)

HValue.Position =
	UDim2.new(
		0.5,
		-40,
		0,
		220
	)

HValue.BackgroundTransparency = 1
HValue.TextColor3 = Color3.new(1, 1, 1)
HValue.Font = Enum.Font.GothamBold
HValue.TextSize = 23
HValue.Parent = Frame

--------------------------------------------------------------
-- HITBOX +
--------------------------------------------------------------

local HPlus =
	Instance.new("TextButton")

HPlus.Size =
	UDim2.fromOffset(
		60,
		42
	)

HPlus.Position =
	UDim2.new(
		1,
		-125,
		0,
		220
	)

HPlus.Text = "+"
HPlus.TextColor3 = Color3.new(1, 1, 1)
HPlus.BackgroundColor3 = Color3.fromRGB(45, 155, 80)
HPlus.Font = Enum.Font.GothamBold
HPlus.TextSize = 26
HPlus.Parent = Frame

Instance.new(
	"UICorner",
	HPlus
).CornerRadius =
	UDim.new(0, 8)

--------------------------------------------------------------
-- AUTO BLOOD
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
		277
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

--------------------------------------------------------------
-- AUTO MONEY
--------------------------------------------------------------

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
		277
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
		30
	)

BloodStatus.Position =
	UDim2.fromOffset(
		10,
		329
	)

BloodStatus.BackgroundTransparency = 1
BloodStatus.Text = "Blood: detecting..."
BloodStatus.TextColor3 = Color3.fromRGB(220, 120, 120)
BloodStatus.Font = Enum.Font.GothamBold
BloodStatus.TextSize = 13
BloodStatus.Parent = Frame

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
		-67
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

	HValue.Text =
		tostring(HITBOX_SIZE)

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

			UpdateHitboxes()
			UpdateGUI()
		end
	)
end

Toggle.MouseButton1Click:Connect(
	function()
		Enabled = not Enabled
		CurrentTarget = nil

		if Enabled then
			--------------------------------------------------
			-- Equip Fists immediately when Auto Hunter turns ON.
			--------------------------------------------------

			Status.Text = "Equipping Fists..."

			ForceEquipFists()

			UpdateHitboxes()

			Status.Text = "Searching Hunter..."
		else
			RestoreHitboxes()
			Status.Text = "Stopped"
		end

		UpdateGUI()
	end
)

HPlus.MouseButton1Click:Connect(
	function()
		HITBOX_SIZE += HITBOX_STEP

		HITBOX_SIZE =
			math.clamp(
				HITBOX_SIZE,
				MIN_HITBOX,
				MAX_HITBOX
			)

		UpdateHitboxes()
		UpdateGUI()
	end
)

HMinus.MouseButton1Click:Connect(
	function()
		HITBOX_SIZE -= HITBOX_STEP

		HITBOX_SIZE =
			math.clamp(
				HITBOX_SIZE,
				MIN_HITBOX,
				MAX_HITBOX
			)

		UpdateHitboxes()
		UpdateGUI()
	end
)

BloodButton.MouseButton1Click:Connect(
	function()
		AUTO_BLOOD = not AUTO_BLOOD

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

--------------------------------------------------------------
-- NEW HUNTER SPAWN
--------------------------------------------------------------

HUNTERS.ChildAdded:Connect(
	function(Hunter)
		task.wait(0.25)

		if Enabled
			and IsValidHunter(Hunter) then

			ExpandHunterHitbox(Hunter)
		end
	end
)

--------------------------------------------------------------
-- AUTO RE-EQUIP AFTER RESPAWN
--------------------------------------------------------------

Player.CharacterAdded:Connect(
	function(Character)
		CurrentTarget = nil

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
-- MAIN LOOP
--==============================================================

task.spawn(function()
	while Running
		and GUI.Parent do

		local Character,
			Humanoid,
			PlayerRoot =
			GetCharacter()

		if Humanoid
			and PlayerRoot
			and Humanoid.Health > 0 then

			local Now = os.clock()

			--------------------------------------------------
			-- BLOOD CHECK
			--------------------------------------------------

			if AUTO_BLOOD
				and not RefillingBlood
				and Now - LastBloodCheck
					>= BLOOD_CHECK_INTERVAL then

				LastBloodCheck = Now

				local BloodPercent =
					GetBloodPercent()

				if BloodPercent then
					BloodStatus.Text =
						string.format(
							"Blood: %.0f%%",
							BloodPercent * 100
						)

					--------------------------------------------------
					-- At or below 25% -> stop farm and refill.
					--------------------------------------------------

					if BloodPercent <= BLOOD_TRIGGER
						and Now - LastBloodRefillAttempt
							>= BLOOD_RETRY_DELAY then

						LastBloodRefillAttempt = Now

						Status.Text =
							"Blood low - buying Vampire Blood..."

						------------------------------------------------
						-- Run refill as the current action.
						-- Farming remains paused while RefillingBlood=true.
						------------------------------------------------

						RefillVampireBlood()

						------------------------------------------------
						-- Re-read blood after refill.
						------------------------------------------------

						local NewBlood =
							GetBloodPercent()

						if NewBlood then
							BloodStatus.Text =
								string.format(
									"Blood: %.0f%%",
									NewBlood * 100
								)
						end

						task.wait(0.05)
						continue
					end
				else
					BloodStatus.Text =
						"Blood: detecting..."
				end
			end

			--------------------------------------------------
			-- REFILL MODE BLOCKS FARM/MONEY
			--------------------------------------------------

			if RefillingBlood then
				task.wait(0.05)
				continue
			end

			--------------------------------------------------
			-- AUTO MONEY
			--------------------------------------------------

			if AUTO_MONEY
				and Now - LastMoneyScan
					>= MONEY_SCAN_INTERVAL then

				LastMoneyScan = Now

				local MoneyCount =
					CollectMoney()

				if MoneyCount > 0
					and not Enabled then

					Status.Text =
						"Collecting money: "
						.. MoneyCount
				end
			end

			--------------------------------------------------
			-- FARM
			--------------------------------------------------

			if Enabled then
				------------------------------------------------
				-- Keep Fists equipped at all times.
				------------------------------------------------

				if Now - LastEquipCheck
					>= EQUIP_CHECK_INTERVAL then

					LastEquipCheck = Now

					local Equipped =
						Character:FindFirstChild("Fists")

					if not Equipped
						or not Equipped:IsA("Tool") then

						EquipFists(
							Character,
							Humanoid
						)
					end
				end

				------------------------------------------------
				-- Find / refresh target.
				------------------------------------------------

				if not IsValidHunter(
					CurrentTarget
				) then

					CurrentTarget =
						FindNearestHunter(
							PlayerRoot
						)
				end

				if CurrentTarget then
					local HunterLevel =
						GetHunterLevel(
							CurrentTarget
						)

					local HunterHumanoid =
						CurrentTarget
						:FindFirstChildOfClass(
							"Humanoid"
						)

					------------------------------------------------
					-- Hitbox
					------------------------------------------------

					ExpandHunterHitbox(
						CurrentTarget
					)

					------------------------------------------------
					-- Fists
					------------------------------------------------

					local Fists =
						EquipFists(
							Character,
							Humanoid
						)

					------------------------------------------------
					-- TP under Hunter
					------------------------------------------------

					TeleportUnderHunter(
						CurrentTarget,
						PlayerRoot
					)

					------------------------------------------------
					-- Status
					------------------------------------------------

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
	RefillingBlood = false

	RestoreHitboxes()

	if GUI then
		GUI:Destroy()
	end

	print("[Auto Hunter Farm] stopped")
end

ENV.AutoHunterFarmStop = Stop

--------------------------------------------------------------
-- START
--------------------------------------------------------------

UpdateGUI()

print("")
print("================================================")
print(" AUTO HUNTER FARM READY")
print("================================================")
print("Hunter levels:")
print(" 100 - 300")
print(" 400 - 900")
print(" 1000 - 3000")
print("")
print("Auto equip Fists: ON when Auto Hunter is enabled")
print("Auto Money: ON")
print("Auto Blood trigger: <= 25%")
print("Auto Blood action:")
print(" ShopKeeper2 -> Purchase Vampire Blood -> Equip -> Drink -> Return")
print("Hunter Hitbox:", HITBOX_SIZE)
print("Under Hunter:", UNDER_DISTANCE)
print("================================================")
