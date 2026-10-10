print("MALMON HUB FINAL START")

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local VIM=game:GetService("VirtualInputManager")

local P=Players.LocalPlayer
local PG=P:WaitForChild("PlayerGui")
local Main=PG:WaitForChild("Main")

local TRACK_CYCLE=420 -- 7:00
local LOGO_ID="rbxassetid://138119483653451"

--==================================================
-- VOLCANIC CAVE ENTRANCE
--==================================================

local CAVE_ENTRANCE=CFrame.new(
	-5042.28467,
	41254.6289,
	-3520.89404,

	-0.463618547,
	-6.87868607e-08,
	-0.886034906,

	-9.84791981e-08,
	1,
	-2.61051518e-08,

	0.886034906,
	7.51531744e-08,
	-0.463618547
)

--==================================================
-- RUN CONTROL
--==================================================

local ENV=_G

if getgenv then
	local ok,e=pcall(getgenv)

	if ok and type(e)=="table" then
		ENV=e
	end
end

ENV.MalmonRunId=(ENV.MalmonRunId or 0)+1
local RUN_ID=ENV.MalmonRunId

local function disconnect(name)

	if ENV[name] then

		pcall(function()
			ENV[name]:Disconnect()
		end)

		ENV[name]=nil
	end
end

for _,name in ipairs({
	"MalmonKeyConn",
	"MalmonEggAddConn",
	"MalmonEggRemoveConn",
	"MalmonWorkspaceAddConn",
	"MalmonDialogueConn"
}) do
	disconnect(name)
end

--==================================================
-- DELETE OLD GUI
--==================================================

for _,name in ipairs({
	"MalmonHub",
	"EggFinder"
}) do

	local old=PG:FindFirstChild(name)

	if old then
		old:Destroy()
	end
end

--==================================================
-- GAME PATHS
--==================================================

local function getEggFolder()
	return workspace:FindFirstChild("RenderedEggs")
end

local EggFolder=
	workspace:WaitForChild("RenderedEggs")

local EggHolder=
	Main:WaitForChild("Index")
	:WaitForChild("Holders")
	:WaitForChild("EggsHolder")

local Character=
	P.Character or P.CharacterAdded:Wait()

local Root=
	Character:WaitForChild("HumanoidRootPart")

-- จุดบ้านตอนรันครั้งแรก
local BaseCF=Root.CFrame

--==================================================
-- UI HELPERS
--==================================================

local I=Instance.new
local U=UDim2.fromOffset
local D=UDim2.new
local C=Color3.fromRGB
local W=Color3.new(1,1,1)

local function round(obj,r)

	local corner=I("UICorner")

	corner.CornerRadius=
		UDim.new(0,r or 6)

	corner.Parent=obj

	return corner
end

--==================================================
-- EGG DATA
--==================================================

local Images={}
local Rank={}

local function rebuildEggData()

	table.clear(Images)
	table.clear(Rank)

	for i,v in ipairs(
		EggHolder:GetChildren()
	) do

		local image=
			v:FindFirstChild("ImageLabel")

		if image then

			Images[v.Name]=image.Image

			local order=i

			if v:IsA("GuiObject")
			and v.LayoutOrder~=0
			then
				order=v.LayoutOrder
			end

			Rank[v.Name]=order
		end
	end
end

rebuildEggData()

--==================================================
-- INSTANCE CFRAME
--==================================================

local function getCF(v)

	if not v then
		return nil
	end

	if v:IsA("BasePart") then
		return v.CFrame
	end

	if v:IsA("Model") then

		local ok,result=pcall(function()
			return v:GetPivot()
		end)

		if ok then
			return result
		end
	end

	local part=
		v:FindFirstChildWhichIsA(
			"BasePart",
			true
		)

	if part then
		return part.CFrame
	end

	return nil
end

--==================================================
-- RARE FIRST
--==================================================

local function sortEgg(a,b)

	local ra=Rank[a.Name] or 0
	local rb=Rank[b.Name] or 0

	if ra~=rb then
		return ra>rb
	end

	if a.Name~=b.Name then
		return
			a.Name:lower()
			<
			b.Name:lower()
	end

	local ca=getCF(a)
	local cb=getCF(b)

	if ca and cb then

		local A=ca.Position
		local B=cb.Position

		if A.X~=B.X then
			return A.X<B.X
		end

		if A.Z~=B.Z then
			return A.Z<B.Z
		end

		return A.Y<B.Y
	end

	return false
end

local function findEgg(name,num)

	local folder=getEggFolder()

	if not folder then
		return nil
	end

	local found={}

	for _,v in ipairs(
		folder:GetChildren()
	) do

		if v.Name==name then
			table.insert(found,v)
		end
	end

	table.sort(
		found,
		sortEgg
	)

	return found[num]
end

--==================================================
-- CHARACTER
--==================================================

local function stabilizeCharacter(ch)

	if not ch then
		return
	end

	local hrp=
		ch:FindFirstChild(
			"HumanoidRootPart"
		)

	local hum=
		ch:FindFirstChildOfClass(
			"Humanoid"
		)

	if hum then

		hum.Sit=false
		hum.PlatformStand=false
		hum.AutoRotate=true
	end

	if hrp then

		hrp.AssemblyLinearVelocity=
			Vector3.zero

		hrp.AssemblyAngularVelocity=
			Vector3.zero
	end
end

local function pivotCharacter(cf)

	local ch=P.Character

	if not ch then
		return false
	end

	ch:PivotTo(cf)

	stabilizeCharacter(ch)

	return true
end

--==================================================
-- FAST NORMAL EGG TELEPORT
--==================================================

local function fastTeleport(target)

	local ch=P.Character

	if not ch then
		return
	end

	local eggCF=getCF(target)

	if not eggCF then
		return
	end

	local hrp=
		ch:FindFirstChild(
			"HumanoidRootPart"
		)

	if not hrp then
		return
	end

	local targetPos=
		eggCF.Position+
		Vector3.new(0,3.5,0)

	-- โหลดพื้นที่แบบ background
	-- ไม่รอ จึงกดแล้ว TP ทันที
	task.spawn(function()

		pcall(function()

			P:RequestStreamAroundAsync(
				eggCF.Position
			)

		end)

	end)

	local _,yaw,_=
		hrp.CFrame:ToOrientation()

	ch:PivotTo(
		CFrame.new(targetPos)
		*
		CFrame.Angles(
			0,
			yaw,
			0
		)
	)

	stabilizeCharacter(ch)
end

--==================================================
-- VOLCANIC TELEPORT
--==================================================

local function volcanicTeleport(target)

	local ch=P.Character

	if not ch then
		return
	end

	local eggCF=getCF(target)

	if not eggCF then
		return
	end

	local eggPos=
		eggCF.Position

	local entrancePos=
		CAVE_ENTRANCE.Position

	-- โหลดปากถ้ำ
	task.spawn(function()

		pcall(function()

			P:RequestStreamAroundAsync(
				entrancePos
			)

		end)

	end)

	-- โหลดบริเวณไข่
	task.spawn(function()

		pcall(function()

			P:RequestStreamAroundAsync(
				eggPos
			)

		end)

	end)

	-- ทิศจากปากถ้ำไปไข่
	local direction=
		eggPos-entrancePos

	if direction.Magnitude>.1 then
		direction=direction.Unit
	else
		direction=CAVE_ENTRANCE.LookVector
	end

	--==================================================
	-- PASS 1
	--==================================================

	pivotCharacter(
		CAVE_ENTRANCE
	)

	task.wait(.12)

	pivotCharacter(
		CFrame.lookAt(
			entrancePos+
			direction*6,
			eggPos
		)
	)

	task.wait(.10)

	pivotCharacter(
		CFrame.lookAt(
			entrancePos+
			direction*12,
			eggPos
		)
	)

	task.wait(.12)

	pivotCharacter(
		CFrame.new(
			eggPos+
			Vector3.new(
				0,
				3.5,
				0
			)
		)
	)

	task.wait(.15)

	local hrp=
		ch:FindFirstChild(
			"HumanoidRootPart"
		)

	-- ถึงไข่แล้ว
	if hrp
	and
		(
			hrp.Position
			-
			eggPos
		).Magnitude
		<=18
	then

		stabilizeCharacter(ch)

		return
	end

	--==================================================
	-- PASS 2
	-- ถ้าเกมเด้งออกจากถ้ำ
	--==================================================

	print("VOLCANIC RETRY")

	pivotCharacter(
		CAVE_ENTRANCE
	)

	task.wait(.25)

	pcall(function()

		P:RequestStreamAroundAsync(
			eggPos
		)

	end)

	pivotCharacter(
		CFrame.lookAt(
			entrancePos+
			direction*5,
			eggPos
		)
	)

	task.wait(.15)

	pivotCharacter(
		CFrame.lookAt(
			entrancePos+
			direction*10,
			eggPos
		)
	)

	task.wait(.15)

	pivotCharacter(
		CFrame.lookAt(
			entrancePos+
			direction*16,
			eggPos
		)
	)

	task.wait(.18)

	pivotCharacter(
		CFrame.new(
			eggPos+
			Vector3.new(
				0,
				3.5,
				0
			)
		)
	)

	stabilizeCharacter(ch)
end

--==================================================
-- TELEPORT ROUTER
--==================================================

local function teleportEgg(target)

	if not target then
		return
	end

	if target.Name=="Volcanic Egg" then

		volcanicTeleport(target)

		return
	end

	fastTeleport(target)
end

--==================================================
-- TRACK TIMER
--==================================================

local TrackInitial=nil
local TrackClock=nil
local TrackState="SYNC"

-- สำคัญ:
-- ตอนจับ Track ห้ามกด TP ไข่
local TeleportLocked=true

local function parseTimer(text)

	if type(text)~="string" then
		return nil
	end

	local m,s=
		text:match(
			"(%d+):(%d+)"
		)

	if not m
	or not s
	then
		return nil
	end

	return
		tonumber(m)*60
		+
		tonumber(s)
end

local function setTrack(seconds,clock)

	if not seconds then
		return
	end

	TrackInitial=seconds

	TrackClock=
		clock or os.clock()

	TrackState="READY"
end

local function currentTrackSeconds()

	if not TrackInitial
	or not TrackClock
	then
		return nil
	end

	local elapsed=
		math.floor(
			os.clock()
			-
			TrackClock
		)

	-- รอบแรก
	if elapsed<TrackInitial then

		return
			TrackInitial
			-
			elapsed
	end

	-- รอบถัดไปวน 7 นาที
	local after=
		elapsed
		-
		TrackInitial

	return
		TRACK_CYCLE
		-
		(
			after
			%
			TRACK_CYCLE
		)
end

local function getTrackText()

	if TrackState=="SYNC" then
		return "..."
	end

	local seconds=
		currentTrackSeconds()

	if not seconds then
		return "--"
	end

	return string.format(
		"%d:%02d",
		math.floor(
			seconds/60
		),
		seconds%60
	)
end

--==================================================
-- CLOSE EGG TRACKER
-- ใช้ X ของเกมก่อน
--==================================================

local function closeEggTracker(tracker)

	for _,v in ipairs(
		tracker:GetDescendants()
	) do

		if v:IsA("GuiButton") then

			local name=
				v.Name:lower()

			local isClose=false

			if name=="close"
			or name=="closebutton"
			or name=="x"
			or name:find("close")
			then
				isClose=true
			end

			if v:IsA("TextButton") then

				local text=
					v.Text:gsub(
						"%s+",
						""
					)

				if text=="X"
				or text=="×"
				then
					isClose=true
				end
			end

			if isClose
			and
			type(firesignal)=="function"
			then

				pcall(function()

					firesignal(
						v.MouseButton1Click
					)

				end)

				task.wait(.04)

				if not tracker.Visible then
					return
				end

				pcall(function()

					firesignal(
						v.Activated
					)

				end)

				task.wait(.04)

				if not tracker.Visible then
					return
				end
			end
		end
	end

	-- fallback
	if tracker.Visible then
		tracker.Visible=false
	end
end

--==================================================
-- TRACK CAPTURE
--==================================================

local function captureTrackOnce()

	print("TRACK CAPTURE START")

	TeleportLocked=true
	TrackState="SYNC"

	local Tracker=
		Main:WaitForChild(
			"EggTracker"
		)

	local Timer=
		Tracker:WaitForChild(
			"Timer"
		)

	local Remotes=
		RS:WaitForChild(
			"Dialogue"
		)
		:WaitForChild(
			"Remotes"
		)

	local DialogueSend=
		Remotes:WaitForChild(
			"DialogueSend"
		)

	local DialogueSelect=
		Remotes:WaitForChild(
			"DialogueSelect"
		)

	local Eggo=
		workspace:
		WaitForChild("Stalls")
		:WaitForChild("EggTracker")
		:WaitForChild("Eggo")

	local EggoRoot=
		Eggo:WaitForChild(
			"HumanoidRootPart"
		)

	local Prompt=
		EggoRoot:WaitForChild(
			"ProximityPrompt"
		)

	local ch=
		P.Character
		or
		P.CharacterAdded:Wait()

	local hrp=
		ch:WaitForChild(
			"HumanoidRootPart"
		)

	-- จุดก่อนวาร์ปไป Track
	local ReturnCF=
		hrp.CFrame

	--==================================================
	-- ถ้าร้านเปิดอยู่แล้ว
	--==================================================

	if Tracker.Visible then

		local value=
			parseTimer(
				Timer.Text
			)

		if value then

			local capturedClock=
				os.clock()

			closeEggTracker(
				Tracker
			)

			setTrack(
				value,
				capturedClock
			)

			TeleportLocked=false

			print(
				"TRACK READY:",
				getTrackText()
			)

			return true
		end
	end

	local gotDialogue=false

	disconnect(
		"MalmonDialogueConn"
	)

	ENV.MalmonDialogueConn=
		DialogueSend.OnClientEvent:
		Connect(function(data)

			if type(data)=="table"
			and data.Model==Eggo
			then

				gotDialogue=true

				print(
					"TRACK SERVER DIALOGUE OK"
				)
			end
		end)

	--==================================================
	-- 1. วาร์ปหน้า Eggo
	--==================================================

	ch:PivotTo(
		EggoRoot.CFrame
		*
		CFrame.new(
			0,
			0,
			-4
		)
	)

	stabilizeCharacter(ch)

	-- ให้ Server เห็นตำแหน่งก่อน
	task.wait(.35)

	if ENV.MalmonRunId~=RUN_ID then

		TeleportLocked=false

		return false
	end

	--==================================================
	-- 2. Trigger Prompt
	--==================================================

	local function triggerPrompt()

		if
			type(fireproximityprompt)
			==
			"function"
		then

			fireproximityprompt(
				Prompt
			)

		else

			VIM:SendKeyEvent(
				true,
				Enum.KeyCode.E,
				false,
				game
			)

			task.wait(.05)

			VIM:SendKeyEvent(
				false,
				Enum.KeyCode.E,
				false,
				game
			)
		end
	end

	triggerPrompt()

	--==================================================
	-- 3. รอ Dialogue จาก Server
	--==================================================

	local deadline=
		os.clock()+2

	while
		not gotDialogue
		and
		os.clock()<deadline
	do
		task.wait(.02)
	end

	-- retry prompt 1 ครั้ง
	if not gotDialogue then

		print(
			"TRACK PROMPT RETRY"
		)

		triggerPrompt()

		deadline=
			os.clock()+2

		while
			not gotDialogue
			and
			os.clock()<deadline
		do
			task.wait(.02)
		end
	end

	if not gotDialogue then

		disconnect(
			"MalmonDialogueConn"
		)

		if ch.Parent then

			ch:PivotTo(
				ReturnCF
			)

			stabilizeCharacter(
				ch
			)
		end

		TrackState="FAILED"
		TeleportLocked=false

		warn(
			"MALMON TRACK DIALOGUE FAILED"
		)

		return false
	end

	-- หน้า Yeah/Nah พร้อม
	task.wait(.18)

	--==================================================
	-- 4. กด Yeah
	--==================================================

	DialogueSelect:FireServer(
		Eggo,
		"Yeah"
	)

	print(
		"TRACK SELECT YEAH"
	)

	--==================================================
	-- 5. รอหน้า Track
	--==================================================

	deadline=
		os.clock()+3

	while
		not Tracker.Visible
		and
		os.clock()<deadline
	do
		task.wait(.02)
	end

	disconnect(
		"MalmonDialogueConn"
	)

	if not Tracker.Visible then

		if ch.Parent then

			ch:PivotTo(
				ReturnCF
			)

			stabilizeCharacter(
				ch
			)
		end

		TrackState="FAILED"
		TeleportLocked=false

		warn(
			"MALMON TRACK WINDOW FAILED"
		)

		return false
	end

	print(
		"TRACK WINDOW:",
		Timer.Text
	)

	--==================================================
	-- 6. อ่าน Timer
	--==================================================

	local captured=nil
	local capturedClock=nil

	deadline=
		os.clock()+1

	while
		os.clock()<deadline
	do

		local value=
			parseTimer(
				Timer.Text
			)

		if value then

			captured=value
			capturedClock=os.clock()

			break
		end

		task.wait(.02)
	end

	--==================================================
	-- 7. ปิด Track
	--==================================================

	closeEggTracker(
		Tracker
	)

	--==================================================
	-- 8. กลับจุดเดิม
	--==================================================

	if ch.Parent then

		ch:PivotTo(
			ReturnCF
		)

		stabilizeCharacter(
			ch
		)
	end

	--==================================================
	-- 9. เริ่ม Local Timer
	--==================================================

	if captured then

		setTrack(
			captured,
			capturedClock
		)

		TeleportLocked=false

		print(
			"TRACK READY:",
			getTrackText()
		)

		return true
	end

	TrackState="FAILED"
	TeleportLocked=false

	warn(
		"MALMON TIMER READ FAILED"
	)

	return false
end

--==================================================
-- GUI
--==================================================

local G=I("ScreenGui")

G.Name="MalmonHub"
G.ResetOnSpawn=false
G.DisplayOrder=999999

G.ZIndexBehavior=
	Enum.ZIndexBehavior.Sibling

G.Parent=PG

local Window=I("Frame")

Window.Name="Main"

Window.Size=
	U(350,450)

Window.Position=
	U(20,65)

Window.BackgroundColor3=
	C(22,22,22)

Window.BorderSizePixel=0

Window.Active=true
Window.Draggable=true

Window.Parent=G

round(Window,8)

--==================================================
-- HEADER
--==================================================

local Title=I("TextLabel")

Title.Size=
	D(1,-155,0,40)

Title.Position=
	U(10,0)

Title.BackgroundTransparency=1

Title.Text=
	"MALMON HUB"

Title.TextColor3=W
Title.TextSize=21

Title.TextXAlignment=
	Enum.TextXAlignment.Left

Title.Parent=
	Window

-- SETTINGS
local SettingsButton=
	I("TextButton")

SettingsButton.Size=
	U(34,30)

SettingsButton.Position=
	D(1,-140,0,5)

SettingsButton.Text="⚙"

SettingsButton.TextColor3=W
SettingsButton.TextSize=18

SettingsButton.BackgroundColor3=
	C(55,55,55)

SettingsButton.BorderSizePixel=0

SettingsButton.Parent=
	Window

round(SettingsButton,5)

-- HOME
local Home=I("TextButton")

Home.Size=
	U(58,30)

Home.Position=
	D(1,-101,0,5)

Home.Text=
	"บ้าน"

Home.TextColor3=W

Home.BackgroundColor3=
	C(42,105,70)

Home.BorderSizePixel=0

Home.Parent=
	Window

round(Home,5)

-- CLOSE
local Close=I("TextButton")

Close.Size=
	U(34,30)

Close.Position=
	D(1,-38,0,5)

Close.Text="X"

Close.TextColor3=W

Close.BackgroundColor3=
	C(125,48,48)

Close.BorderSizePixel=0

Close.Parent=
	Window

round(Close,5)

--==================================================
-- EGG PAGE
--==================================================

local EggPage=
	I("Frame")

EggPage.Name=
	"EggPage"

EggPage.Size=
	D(1,0,1,-40)

EggPage.Position=
	U(0,40)

EggPage.BackgroundTransparency=1

EggPage.Parent=
	Window

-- SEARCH
local Search=
	I("TextBox")

Search.Size=
	D(1,-20,0,36)

Search.Position=
	U(10,2)

Search.Text=""

Search.PlaceholderText=
	"Search egg..."

Search.PlaceholderColor3=
	C(145,145,145)

Search.TextColor3=W

Search.BackgroundColor3=
	C(38,38,38)

Search.BorderSizePixel=0

Search.ClearTextOnFocus=false
Search.TextSize=15

Search.Parent=
	EggPage

round(Search,6)

-- STATUS
local Status=
	I("TextLabel")

Status.Size=
	D(1,-20,0,22)

Status.Position=
	U(12,40)

Status.BackgroundTransparency=1

Status.TextColor3=
	C(170,170,170)

Status.TextSize=11

Status.TextXAlignment=
	Enum.TextXAlignment.Left

Status.Parent=
	EggPage

-- LIST
local List=
	I("ScrollingFrame")

List.Size=
	D(1,-20,1,-70)

List.Position=
	U(10,62)

List.BackgroundColor3=
	C(30,30,30)

List.BorderSizePixel=0
List.ScrollBarThickness=5

List.AutomaticCanvasSize=
	Enum.AutomaticSize.Y

List.CanvasSize=
	U(0,0)

List.Parent=
	EggPage

round(List,6)

local Layout=
	I("UIListLayout")

Layout.Padding=
	UDim.new(0,4)

Layout.Parent=
	List

--==================================================
-- SETTINGS PAGE
--==================================================

local SettingsPage=
	I("Frame")

SettingsPage.Name=
	"SettingsPage"

SettingsPage.Size=
	D(1,0,1,-40)

SettingsPage.Position=
	U(0,40)

SettingsPage.BackgroundTransparency=1

SettingsPage.Visible=false

SettingsPage.Parent=
	Window

local SettingsTitle=
	I("TextLabel")

SettingsTitle.Size=
	D(1,-110,0,40)

SettingsTitle.Position=
	U(12,10)

SettingsTitle.BackgroundTransparency=1

SettingsTitle.Text=
	"การตั้งค่า"

SettingsTitle.TextColor3=W
SettingsTitle.TextSize=22

SettingsTitle.TextXAlignment=
	Enum.TextXAlignment.Left

SettingsTitle.Parent=
	SettingsPage

-- BACK
local Back=I("TextButton")

Back.Size=
	U(75,30)

Back.Position=
	D(1,-87,0,12)

Back.Text=
	"< กลับ"

Back.TextColor3=W

Back.BackgroundColor3=
	C(55,55,55)

Back.BorderSizePixel=0

Back.Parent=
	SettingsPage

round(Back,5)

-- PC KEY
local KeyTitle=
	I("TextLabel")

KeyTitle.Size=
	D(1,-30,0,26)

KeyTitle.Position=
	U(15,65)

KeyTitle.BackgroundTransparency=1

KeyTitle.Text=
	"ปุ่มลัดสำหรับ PC"

KeyTitle.TextColor3=
	C(185,185,185)

KeyTitle.TextSize=14

KeyTitle.TextXAlignment=
	Enum.TextXAlignment.Left

KeyTitle.Parent=
	SettingsPage

local Bind=
	I("TextButton")

Bind.Size=
	D(1,-30,0,44)

Bind.Position=
	U(15,95)

Bind.BackgroundColor3=
	C(40,40,40)

Bind.BorderSizePixel=0

Bind.TextColor3=W
Bind.TextSize=16

Bind.Parent=
	SettingsPage

round(Bind,6)

local ResetKey=
	I("TextButton")

ResetKey.Size=
	U(110,32)

ResetKey.Position=
	U(15,150)

ResetKey.BackgroundColor3=
	C(65,65,65)

ResetKey.BorderSizePixel=0

ResetKey.Text=
	"รีเซ็ตปุ่ม"

ResetKey.TextColor3=W
ResetKey.TextSize=13

ResetKey.Parent=
	SettingsPage

round(ResetKey,5)

-- HOME INFO
local HomeInfo=
	I("TextLabel")

HomeInfo.Size=
	D(1,-30,0,80)

HomeInfo.Position=
	U(15,210)

HomeInfo.BackgroundTransparency=1

HomeInfo.Text=
	"ปุ่มบ้าน\n"..
	"จุดกลับบ้านคือจุดที่คุณยืนตอนรัน MALMON HUB"

HomeInfo.TextColor3=
	C(165,165,165)

HomeInfo.TextSize=13
HomeInfo.TextWrapped=true

HomeInfo.TextXAlignment=
	Enum.TextXAlignment.Left

HomeInfo.TextYAlignment=
	Enum.TextYAlignment.Top

HomeInfo.Parent=
	SettingsPage

-- TRACK INFO
local TrackInfo=
	I("TextLabel")

TrackInfo.Size=
	D(1,-30,0,95)

TrackInfo.Position=
	U(15,300)

TrackInfo.BackgroundTransparency=1

TrackInfo.Text=
	"เวลา Track\n"..
	"จับเวลาร้าน 1 ครั้งตอนรัน\n"..
	"จากนั้นนับรอบละ 7 นาทีอัตโนมัติ"

TrackInfo.TextColor3=
	C(165,165,165)

TrackInfo.TextSize=12
TrackInfo.TextWrapped=true

TrackInfo.TextXAlignment=
	Enum.TextXAlignment.Left

TrackInfo.TextYAlignment=
	Enum.TextYAlignment.Top

TrackInfo.Parent=
	SettingsPage

--==================================================
-- PAGE SWITCH
--==================================================

SettingsButton.MouseButton1Click:
Connect(function()

	SettingsPage.Visible=
		not SettingsPage.Visible

	EggPage.Visible=
		not SettingsPage.Visible

end)

Back.MouseButton1Click:
Connect(function()

	SettingsPage.Visible=false

	EggPage.Visible=true

end)

--==================================================
-- MOBILE LOGO
--==================================================

local Toggle=
	I("ImageButton")

Toggle.Name=
	"MobileToggle"

Toggle.Size=
	U(54,54)

Toggle.Position=
	D(0,10,0,8)

Toggle.BackgroundColor3=
	C(12,12,12)

Toggle.BorderSizePixel=0

Toggle.Image=
	LOGO_ID

Toggle.ScaleType=
	Enum.ScaleType.Crop

Toggle.AutoButtonColor=false

Toggle.Active=true
Toggle.Draggable=true
Toggle.ClipsDescendants=true

Toggle.Parent=
	G

local ToggleCorner=
	I("UICorner")

ToggleCorner.CornerRadius=
	UDim.new(1,0)

ToggleCorner.Parent=
	Toggle

local ToggleStroke=
	I("UIStroke")

ToggleStroke.Thickness=1.5

ToggleStroke.Color=
	C(90,25,25)

ToggleStroke.Transparency=.15

ToggleStroke.Parent=
	Toggle

local function toggleHub()

	Window.Visible=
		not Window.Visible

end

Toggle.MouseButton1Click:
Connect(toggleHub)

--==================================================
-- PC KEYBIND
--==================================================

local Keybind=
	Enum.KeyCode.RightShift

if type(ENV.MalmonKeybind)=="string" then

	local ok,key=
		pcall(function()

			return Enum.KeyCode[
				ENV.MalmonKeybind
			]

		end)

	if ok and key then
		Keybind=key
	end
end

local Listening=false

local function updateKeyText()

	Bind.Text=
		"เปิด / ปิด Hub :  "
		..
		Keybind.Name

end

updateKeyText()

Bind.MouseButton1Click:
Connect(function()

	Listening=true

	Bind.Text=
		"กดปุ่มที่ต้องการ..."

end)

ResetKey.MouseButton1Click:
Connect(function()

	Keybind=
		Enum.KeyCode.RightShift

	ENV.MalmonKeybind=
		Keybind.Name

	Listening=false

	updateKeyText()

end)

ENV.MalmonKeyConn=
	UIS.InputBegan:
	Connect(function(input,typing)

		if Listening then

			if
				input.UserInputType
				==
				Enum.UserInputType.Keyboard
			and
				input.KeyCode
				~=
				Enum.KeyCode.Unknown
			then

				Keybind=
					input.KeyCode

				ENV.MalmonKeybind=
					Keybind.Name

				Listening=false

				updateKeyText()
			end

			return
		end

		if not typing
		and
		input.KeyCode==Keybind
		then

			toggleHub()
		end
	end)

--==================================================
-- HOME / CLOSE
--==================================================

Home.MouseButton1Click:
Connect(function()

	local ch=P.Character

	if ch then

		ch:PivotTo(
			BaseCF
		)

		stabilizeCharacter(
			ch
		)
	end
end)

Close.MouseButton1Click:
Connect(function()

	Window.Visible=false

end)

--==================================================
-- STATUS
--==================================================

local ShownEggs=0
local TotalEggs=0

local function updateStatus()

	local trackDisplay=
		getTrackText()

	if TeleportLocked then
		trackDisplay="Sync..."
	end

	Status.Text=
		"Rare first  |  "
		..
		ShownEggs
		..
		" / "
		..
		TotalEggs
		..
		" eggs  |  Track "
		..
		trackDisplay

end

--==================================================
-- EGG LIST
--==================================================

local function refresh()

	EggFolder=
		getEggFolder()
		or
		EggFolder

	if not EggFolder then
		return
	end

	rebuildEggData()

	local scroll=
		List.CanvasPosition

	for _,v in ipairs(
		List:GetChildren()
	) do

		if v:IsA("TextButton") then
			v:Destroy()
		end
	end

	local eggs=
		EggFolder:GetChildren()

	table.sort(
		eggs,
		sortEgg
	)

	local total={}
	local numbers={}

	local query=
		Search.Text:lower()

	ShownEggs=0
	TotalEggs=#eggs

	for _,egg in ipairs(eggs) do

		total[egg.Name]=
			(total[egg.Name] or 0)+1
	end

	for _,egg in ipairs(eggs) do

		numbers[egg.Name]=
			(numbers[egg.Name] or 0)+1

		if query==""
		or
		egg.Name:lower():
		find(
			query,
			1,
			true
		)
		then

			ShownEggs=
				ShownEggs+1

			local eggName=
				egg.Name

			local eggNum=
				numbers[eggName]

			local display=
				eggName

			if total[eggName]>1 then

				display=
					display
					..
					" #"
					..
					eggNum
			end

			local Button=
				I("TextButton")

			Button.Size=
				D(1,-6,0,54)

			Button.BackgroundColor3=
				C(49,49,49)

			Button.BorderSizePixel=0
			Button.Text=""

			Button.Parent=
				List

			round(Button,6)

			-- IMAGE
			local Image=
				I("ImageLabel")

			Image.Size=
				U(46,46)

			Image.Position=
				U(5,4)

			Image.BackgroundTransparency=1

			Image.ScaleType=
				Enum.ScaleType.Fit

			Image.Image=
				Images[eggName]
				or
				""

			Image.Parent=
				Button

			-- TEXT
			local Text=
				I("TextLabel")

			Text.Size=
				D(1,-65,1,0)

			Text.Position=
				U(60,0)

			Text.BackgroundTransparency=1

			Text.Text=
				display

			Text.TextColor3=W
			Text.TextSize=16

			Text.TextXAlignment=
				Enum.TextXAlignment.Left

			Text.Parent=
				Button

			--==================================================
			-- TELEPORT BUTTON
			--==================================================

			Button.MouseButton1Click:
			Connect(function()

				-- กำลัง Sync Track
				-- ห้ามวาร์ปหนีจาก Eggo
				if TeleportLocked then
					return
				end

				local target=
					findEgg(
						eggName,
						eggNum
					)

				if target then

					teleportEgg(
						target
					)
				end
			end)
		end
	end

	updateStatus()

	task.defer(function()

		if List.Parent then

			List.CanvasPosition=
				scroll
		end
	end)
end

Search:GetPropertyChangedSignal(
	"Text"
):Connect(refresh)

--==================================================
-- DEBOUNCED EGG REFRESH
--==================================================

local RefreshToken=0
local WatchedFolder=nil

local function scheduleRefresh()

	RefreshToken=
		RefreshToken+1

	local token=
		RefreshToken

	task.delay(
		.20,
		function()

			if token~=RefreshToken then
				return
			end

			if ENV.MalmonRunId~=RUN_ID then
				return
			end

			refresh()
		end
	)
end

local function bindEggFolder(folder)

	if not folder
	or folder==WatchedFolder
	then
		return
	end

	disconnect(
		"MalmonEggAddConn"
	)

	disconnect(
		"MalmonEggRemoveConn"
	)

	WatchedFolder=folder
	EggFolder=folder

	ENV.MalmonEggAddConn=
		folder.ChildAdded:
		Connect(
			scheduleRefresh
		)

	ENV.MalmonEggRemoveConn=
		folder.ChildRemoved:
		Connect(
			scheduleRefresh
		)

	scheduleRefresh()
end

bindEggFolder(
	EggFolder
)

-- RenderedEggs ถูกสร้างใหม่
ENV.MalmonWorkspaceAddConn=
	workspace.ChildAdded:
	Connect(function(v)

		if v.Name=="RenderedEggs" then

			task.defer(function()

				bindEggFolder(
					v
				)

			end)
		end
	end)

refresh()

--==================================================
-- TRACK CAPTURE ONCE
--==================================================

task.spawn(function()

	task.wait(.2)

	if ENV.MalmonRunId~=RUN_ID then
		return
	end

	local ok,result=
		pcall(
			captureTrackOnce
		)

	if not ok
	or not result
	then

		TrackState="FAILED"
		TeleportLocked=false

		if not ok then

			warn(
				"MALMON TRACK ERROR:",
				result
			)
		end
	end

	updateStatus()
end)

--==================================================
-- LOW COST TIMER DISPLAY
--==================================================

task.spawn(function()

	local previous=""

	while
		G.Parent
		and
		ENV.MalmonRunId==RUN_ID
	do

		task.wait(.4)

		local current=
			getTrackText()

		if current~=previous
		or TeleportLocked
		then

			previous=current

			updateStatus()
		end
	end
end)

--==================================================
-- CLEANUP
--==================================================

G.AncestryChanged:
Connect(function(_,parent)

	if parent then
		return
	end

	disconnect(
		"MalmonDialogueConn"
	)

	disconnect(
		"MalmonEggAddConn"
	)

	disconnect(
		"MalmonEggRemoveConn"
	)

	disconnect(
		"MalmonWorkspaceAddConn"
	)

end)

print(
	"MALMON HUB FINAL READY",
	#EggFolder:GetChildren()
)
