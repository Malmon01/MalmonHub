--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

print("MALMON HUB OPTIMIZED START");
local Players = game:GetService("Players");
local UIS = game:GetService("UserInputService");
local RS = game:GetService("ReplicatedStorage");
local VIM = game:GetService("VirtualInputManager");
local P = Players.LocalPlayer;
local PG = P:WaitForChild("PlayerGui");
local Main = PG:WaitForChild("Main");
local TRACK_CYCLE = 420;
local LOGO_ID = "rbxassetid://138119483653451";
local ENV = _G;
if getgenv then
	local FlatIdent_76979 = 0;
	local ok;
	local e;
	while true do
		if (FlatIdent_76979 == 0) then
			ok, e = pcall(getgenv);
			if (ok and (type(e) == "table")) then
				ENV = e;
			end
			break;
		end
	end
end
ENV.MalmonRunId = (ENV.MalmonRunId or 0) + 1;
local RUN_ID = ENV.MalmonRunId;
local function disconnect(name)
	if ENV[name] then
		local FlatIdent_69270 = 0;
		while true do
			if (FlatIdent_69270 == 0) then
				pcall(function()
					ENV[name]:Disconnect();
				end);
				ENV[name] = nil;
				break;
			end
		end
	end
end
for _, n in ipairs({"MalmonKeyConn","MalmonEggAddConn","MalmonEggRemoveConn","MalmonWorkspaceAddConn","MalmonDialogueConn"}) do
	disconnect(n);
end
for _, name in ipairs({"MalmonHub","EggFinder"}) do
	local old = PG:FindFirstChild(name);
	if old then
		old:Destroy();
	end
end
local function getEggFolder()
	return workspace:FindFirstChild("RenderedEggs");
end
local EggFolder = workspace:WaitForChild("RenderedEggs");
local EggHolder = Main:WaitForChild("Index"):WaitForChild("Holders"):WaitForChild("EggsHolder");
local Character = P.Character or P.CharacterAdded:Wait();
local Root = Character:WaitForChild("HumanoidRootPart");
local BaseCF = Root.CFrame;
local I = Instance.new;
local U = UDim2.fromOffset;
local D = UDim2.new;
local C = Color3.fromRGB;
local W = Color3.new(1, 1, 1);
local function round(obj, r)
	local x = I("UICorner");
	x.CornerRadius = UDim.new(0, r or 6);
	x.Parent = obj;
end
local function getCF(v)
	if not v then
		return nil;
	end
	if v:IsA("BasePart") then
		return v.CFrame;
	end
	if v:IsA("Model") then
		local ok, result = pcall(function()
			return v:GetPivot();
		end);
		if ok then
			return result;
		end
	end
	local part = v:FindFirstChildWhichIsA("BasePart", true);
	if part then
		return part.CFrame;
	end
end
local Images = {};
local Rank = {};
local function rebuildEggData()
	table.clear(Images);
	table.clear(Rank);
	for i, v in ipairs(EggHolder:GetChildren()) do
		local FlatIdent_6D4CB = 0;
		local img;
		while true do
			if (FlatIdent_6D4CB == 0) then
				img = v:FindFirstChild("ImageLabel");
				if img then
					local FlatIdent_10BCC = 0;
					while true do
						if (0 == FlatIdent_10BCC) then
							Images[v.Name] = img.Image;
							Rank[v.Name] = i;
							break;
						end
					end
				end
				break;
			end
		end
	end
end
rebuildEggData();
local function sortEgg(a, b)
	local FlatIdent_47A9C = 0;
	local ra;
	local rb;
	local ca;
	local cb;
	while true do
		if (FlatIdent_47A9C == 0) then
			ra = Rank[a.Name] or 0;
			rb = Rank[b.Name] or 0;
			FlatIdent_47A9C = 1;
		end
		if (FlatIdent_47A9C == 3) then
			if (ca and cb) then
				local FlatIdent_43862 = 0;
				local A;
				local B;
				while true do
					if (FlatIdent_43862 == 1) then
						if (A.X ~= B.X) then
							return A.X < B.X;
						end
						if (A.Z ~= B.Z) then
							return A.Z < B.Z;
						end
						FlatIdent_43862 = 2;
					end
					if (0 == FlatIdent_43862) then
						A = ca.Position;
						B = cb.Position;
						FlatIdent_43862 = 1;
					end
					if (FlatIdent_43862 == 2) then
						return A.Y < B.Y;
					end
				end
			end
			return false;
		end
		if (FlatIdent_47A9C == 1) then
			if (ra ~= rb) then
				return ra > rb;
			end
			if (a.Name ~= b.Name) then
				return a.Name:lower() < b.Name:lower();
			end
			FlatIdent_47A9C = 2;
		end
		if (FlatIdent_47A9C == 2) then
			ca = getCF(a);
			cb = getCF(b);
			FlatIdent_47A9C = 3;
		end
	end
end
local function findEgg(name, num)
	local FlatIdent_C460 = 0;
	local folder;
	local found;
	while true do
		if (FlatIdent_C460 == 0) then
			folder = getEggFolder();
			if not folder then
				return;
			end
			FlatIdent_C460 = 1;
		end
		if (FlatIdent_C460 == 1) then
			found = {};
			for _, v in ipairs(folder:GetChildren()) do
				if (v.Name == name) then
					table.insert(found, v);
				end
			end
			FlatIdent_C460 = 2;
		end
		if (FlatIdent_C460 == 2) then
			table.sort(found, sortEgg);
			return found[num];
		end
	end
end
local function collisionScore(position, target, ch)
	local FlatIdent_7FAC9 = 0;
	local params;
	local parts;
	local score;
	while true do
		if (0 == FlatIdent_7FAC9) then
			params = OverlapParams.new();
			params.FilterType = Enum.RaycastFilterType.Exclude;
			FlatIdent_7FAC9 = 1;
		end
		if (FlatIdent_7FAC9 == 3) then
			return score;
		end
		if (FlatIdent_7FAC9 == 2) then
			score = 0;
			for _, part in ipairs(parts) do
				if (part:IsA("BasePart") and part.CanCollide and (part.Transparency < 0.95)) then
					score += 1
				end
			end
			FlatIdent_7FAC9 = 3;
		end
		if (FlatIdent_7FAC9 == 1) then
			params.FilterDescendantsInstances = {ch,target};
			parts = workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(3, 4.5, 3), params);
			FlatIdent_7FAC9 = 2;
		end
	end
end
local function getSafeEggPosition(target)
	local c = getCF(target);
	if not c then
		return;
	end
	local p = c.Position;
	local ch = P.Character;
	if not ch then
		return p + Vector3.new(0, 3, 0);
	end
	local candidates = {(p + Vector3.new(0, 3.2, 0)),(p + Vector3.new(3.5, 2.8, 0)),(p + Vector3.new(-3.5, 2.8, 0)),(p + Vector3.new(0, 2.8, 3.5)),(p + Vector3.new(0, 2.8, -3.5)),(p + Vector3.new(4, 3, 4)),(p + Vector3.new(-4, 3, 4)),(p + Vector3.new(4, 3, -4)),(p + Vector3.new(-4, 3, -4)),(p + Vector3.new(0, 6, 0))};
	local best = candidates[1];
	local bestScore = math.huge;
	for _, candidate in ipairs(candidates) do
		local score = collisionScore(candidate, target, ch);
		if (score < bestScore) then
			local FlatIdent_2D2B8 = 0;
			while true do
				if (FlatIdent_2D2B8 == 0) then
					bestScore = score;
					best = candidate;
					break;
				end
			end
		end
		if (score == 0) then
			break;
		end
	end
	return best;
end
local function fastTeleport(target)
	local FlatIdent_E0D0 = 0;
	local ch;
	local hrp;
	local pos;
	local hum;
	local _;
	local yaw;
	while true do
		if (FlatIdent_E0D0 == 1) then
			if not hrp then
				return;
			end
			pos = getSafeEggPosition(target);
			if not pos then
				return;
			end
			FlatIdent_E0D0 = 2;
		end
		if (FlatIdent_E0D0 == 2) then
			task.spawn(function()
				pcall(function()
					P:RequestStreamAroundAsync(pos);
				end);
			end);
			hum = ch:FindFirstChildOfClass("Humanoid");
			if hum then
				local FlatIdent_6B983 = 0;
				while true do
					if (FlatIdent_6B983 == 1) then
						hum.AutoRotate = true;
						break;
					end
					if (FlatIdent_6B983 == 0) then
						hum.Sit = false;
						hum.PlatformStand = false;
						FlatIdent_6B983 = 1;
					end
				end
			end
			FlatIdent_E0D0 = 3;
		end
		if (FlatIdent_E0D0 == 0) then
			ch = P.Character;
			if not ch then
				return;
			end
			hrp = ch:FindFirstChild("HumanoidRootPart");
			FlatIdent_E0D0 = 1;
		end
		if (FlatIdent_E0D0 == 3) then
			_, yaw, _ = hrp.CFrame:ToOrientation();
			ch:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0));
			hrp = ch:FindFirstChild("HumanoidRootPart");
			FlatIdent_E0D0 = 4;
		end
		if (FlatIdent_E0D0 == 4) then
			if hrp then
				local FlatIdent_287B5 = 0;
				while true do
					if (FlatIdent_287B5 == 0) then
						hrp.AssemblyLinearVelocity = Vector3.zero;
						hrp.AssemblyAngularVelocity = Vector3.zero;
						break;
					end
				end
			end
			break;
		end
	end
end
local TrackInitial = nil;
local TrackClock = nil;
local TrackState = "SYNC";
local function parseTimer(text)
	local FlatIdent_4CC24 = 0;
	local m;
	local s;
	while true do
		if (FlatIdent_4CC24 == 0) then
			if (type(text) ~= "string") then
				return;
			end
			m, s = text:match("(%d+):(%d+)");
			FlatIdent_4CC24 = 1;
		end
		if (FlatIdent_4CC24 == 1) then
			if (not m or not s) then
				return;
			end
			return (tonumber(m) * 60) + tonumber(s);
		end
	end
end
local function setTrack(seconds, clock)
	TrackInitial = seconds;
	TrackClock = clock or os.clock();
	TrackState = "READY";
end
local function currentTrackSeconds()
	local FlatIdent_40B41 = 0;
	local elapsed;
	local after;
	while true do
		if (FlatIdent_40B41 == 0) then
			if (not TrackInitial or not TrackClock) then
				return;
			end
			elapsed = math.floor(os.clock() - TrackClock);
			FlatIdent_40B41 = 1;
		end
		if (1 == FlatIdent_40B41) then
			if (elapsed < TrackInitial) then
				return TrackInitial - elapsed;
			end
			after = elapsed - TrackInitial;
			FlatIdent_40B41 = 2;
		end
		if (FlatIdent_40B41 == 2) then
			return TRACK_CYCLE - (after % TRACK_CYCLE);
		end
	end
end
local function getTrackText()
	local FlatIdent_5477B = 0;
	local s;
	while true do
		if (1 == FlatIdent_5477B) then
			if not s then
				return "--";
			end
			return string.format("%d:%02d", math.floor(s / 60), s % 60);
		end
		if (FlatIdent_5477B == 0) then
			if (TrackState == "SYNC") then
				return "...";
			end
			s = currentTrackSeconds();
			FlatIdent_5477B = 1;
		end
	end
end
local function closeTracker(tracker)
	for _, v in ipairs(tracker:GetDescendants()) do
		if v:IsA("GuiButton") then
			local FlatIdent_7F121 = 0;
			local name;
			local isClose;
			while true do
				if (FlatIdent_7F121 == 0) then
					name = v.Name:lower();
					isClose = (name == "close") or (name == "closebutton") or (name == "x");
					FlatIdent_7F121 = 1;
				end
				if (FlatIdent_7F121 == 1) then
					if v:IsA("TextButton") then
						local t = v.Text:gsub("%s+", "");
						if ((t == "X") or (t == "×")) then
							isClose = true;
						end
					end
					if (isClose and (type(firesignal) == "function")) then
						local FlatIdent_29E69 = 0;
						while true do
							if (FlatIdent_29E69 == 1) then
								if not tracker.Visible then
									return;
								end
								break;
							end
							if (FlatIdent_29E69 == 0) then
								pcall(function()
									firesignal(v.MouseButton1Click);
								end);
								task.wait(0.05);
								FlatIdent_29E69 = 1;
							end
						end
					end
					break;
				end
			end
		end
	end
	if tracker.Visible then
		tracker.Visible = false;
	end
end
local function captureTrackOnce()
	local Tracker = Main:WaitForChild("EggTracker");
	local Timer = Tracker:WaitForChild("Timer");
	local Remotes = RS:WaitForChild("Dialogue"):WaitForChild("Remotes");
	local Send = Remotes:WaitForChild("DialogueSend");
	local Select = Remotes:WaitForChild("DialogueSelect");
	local Eggo = workspace:WaitForChild("Stalls"):WaitForChild("EggTracker"):WaitForChild("Eggo");
	local EggoRoot = Eggo:WaitForChild("HumanoidRootPart");
	local Prompt = EggoRoot:WaitForChild("ProximityPrompt");
	local ch = P.Character;
	if not ch then
		return false;
	end
	local hrp = ch:FindFirstChild("HumanoidRootPart");
	if not hrp then
		return false;
	end
	local returnCF = hrp.CFrame;
	local gotDialogue = false;
	disconnect("MalmonDialogueConn");
	ENV.MalmonDialogueConn = Send.OnClientEvent:Connect(function(data)
		if ((type(data) == "table") and (data.Model == Eggo)) then
			gotDialogue = true;
		end
	end);
	ch:PivotTo(EggoRoot.CFrame * CFrame.new(0, 0, -4));
	hrp = ch:FindFirstChild("HumanoidRootPart");
	if hrp then
		local FlatIdent_19F98 = 0;
		while true do
			if (FlatIdent_19F98 == 0) then
				hrp.AssemblyLinearVelocity = Vector3.zero;
				hrp.AssemblyAngularVelocity = Vector3.zero;
				break;
			end
		end
	end
	task.wait(0.15);
	if (type(fireproximityprompt) == "function") then
		fireproximityprompt(Prompt);
	else
		local FlatIdent_75224 = 0;
		while true do
			if (FlatIdent_75224 == 0) then
				VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game);
				task.wait(0.05);
				FlatIdent_75224 = 1;
			end
			if (FlatIdent_75224 == 1) then
				VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game);
				break;
			end
		end
	end
	local deadline = os.clock() + 2;
	while not gotDialogue and (os.clock() < deadline) do
		task.wait(0.02);
	end
	if not gotDialogue then
		disconnect("MalmonDialogueConn");
		ch:PivotTo(returnCF);
		TrackState = "FAILED";
		return false;
	end
	task.wait(0.08);
	Select:FireServer(Eggo, "Yeah");
	deadline = os.clock() + 2;
	while not Tracker.Visible and (os.clock() < deadline) do
		task.wait(0.02);
	end
	disconnect("MalmonDialogueConn");
	if not Tracker.Visible then
		ch:PivotTo(returnCF);
		TrackState = "FAILED";
		return false;
	end
	local captured = nil;
	local capturedClock = nil;
	deadline = os.clock() + 0.6;
	while os.clock() < deadline do
		captured = parseTimer(Timer.Text);
		if captured then
			capturedClock = os.clock();
			break;
		end
		task.wait(0.02);
	end
	closeTracker(Tracker);
	ch:PivotTo(returnCF);
	hrp = ch:FindFirstChild("HumanoidRootPart");
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero;
		hrp.AssemblyAngularVelocity = Vector3.zero;
	end
	if captured then
		local FlatIdent_DFF4 = 0;
		while true do
			if (FlatIdent_DFF4 == 0) then
				setTrack(captured, capturedClock);
				print("TRACK READY", getTrackText());
				FlatIdent_DFF4 = 1;
			end
			if (FlatIdent_DFF4 == 1) then
				return true;
			end
		end
	end
	TrackState = "FAILED";
	return false;
end
local G = I("ScreenGui");
G.Name = "MalmonHub";
G.ResetOnSpawn = false;
G.DisplayOrder = 999999;
G.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
G.Parent = PG;
local Window = I("Frame");
Window.Size = U(350, 450);
Window.Position = U(20, 65);
Window.BackgroundColor3 = C(22, 22, 22);
Window.BorderSizePixel = 0;
Window.Active = true;
Window.Draggable = true;
Window.Parent = G;
round(Window, 8);
local Title = I("TextLabel");
Title.Size = D(1, -155, 0, 40);
Title.Position = U(10, 0);
Title.BackgroundTransparency = 1;
Title.Text = "MALMON HUB";
Title.TextColor3 = W;
Title.TextSize = 21;
Title.TextXAlignment = Enum.TextXAlignment.Left;
Title.Parent = Window;
local SettingsButton = I("TextButton");
SettingsButton.Size = U(34, 30);
SettingsButton.Position = D(1, -140, 0, 5);
SettingsButton.Text = "⚙";
SettingsButton.TextColor3 = W;
SettingsButton.TextSize = 18;
SettingsButton.BackgroundColor3 = C(55, 55, 55);
SettingsButton.BorderSizePixel = 0;
SettingsButton.Parent = Window;
round(SettingsButton, 5);
local Home = I("TextButton");
Home.Size = U(58, 30);
Home.Position = D(1, -101, 0, 5);
Home.Text = "บ้าน";
Home.TextColor3 = W;
Home.BackgroundColor3 = C(42, 105, 70);
Home.BorderSizePixel = 0;
Home.Parent = Window;
round(Home, 5);
local Close = I("TextButton");
Close.Size = U(34, 30);
Close.Position = D(1, -38, 0, 5);
Close.Text = "X";
Close.TextColor3 = W;
Close.BackgroundColor3 = C(125, 48, 48);
Close.BorderSizePixel = 0;
Close.Parent = Window;
round(Close, 5);
local EggPage = I("Frame");
EggPage.Size = D(1, 0, 1, -40);
EggPage.Position = U(0, 40);
EggPage.BackgroundTransparency = 1;
EggPage.Parent = Window;
local Search = I("TextBox");
Search.Size = D(1, -20, 0, 36);
Search.Position = U(10, 2);
Search.Text = "";
Search.PlaceholderText = "Search egg...";
Search.PlaceholderColor3 = C(145, 145, 145);
Search.TextColor3 = W;
Search.BackgroundColor3 = C(38, 38, 38);
Search.BorderSizePixel = 0;
Search.ClearTextOnFocus = false;
Search.TextSize = 15;
Search.Parent = EggPage;
round(Search, 6);
local Status = I("TextLabel");
Status.Size = D(1, -20, 0, 22);
Status.Position = U(12, 40);
Status.BackgroundTransparency = 1;
Status.TextColor3 = C(170, 170, 170);
Status.TextSize = 11;
Status.TextXAlignment = Enum.TextXAlignment.Left;
Status.Parent = EggPage;
local List = I("ScrollingFrame");
List.Size = D(1, -20, 1, -70);
List.Position = U(10, 62);
List.BackgroundColor3 = C(30, 30, 30);
List.BorderSizePixel = 0;
List.ScrollBarThickness = 5;
List.AutomaticCanvasSize = Enum.AutomaticSize.Y;
List.CanvasSize = U(0, 0);
List.Parent = EggPage;
round(List, 6);
local Layout = I("UIListLayout");
Layout.Padding = UDim.new(0, 4);
Layout.Parent = List;
local SettingsPage = I("Frame");
SettingsPage.Size = D(1, 0, 1, -40);
SettingsPage.Position = U(0, 40);
SettingsPage.BackgroundTransparency = 1;
SettingsPage.Visible = false;
SettingsPage.Parent = Window;
local ST = I("TextLabel");
ST.Size = D(1, -110, 0, 40);
ST.Position = U(12, 10);
ST.BackgroundTransparency = 1;
ST.Text = "การตั้งค่า";
ST.TextColor3 = W;
ST.TextSize = 22;
ST.TextXAlignment = Enum.TextXAlignment.Left;
ST.Parent = SettingsPage;
local Back = I("TextButton");
Back.Size = U(75, 30);
Back.Position = D(1, -87, 0, 12);
Back.Text = "< กลับ";
Back.TextColor3 = W;
Back.BackgroundColor3 = C(55, 55, 55);
Back.BorderSizePixel = 0;
Back.Parent = SettingsPage;
round(Back, 5);
local KeyTitle = I("TextLabel");
KeyTitle.Size = D(1, -30, 0, 26);
KeyTitle.Position = U(15, 65);
KeyTitle.BackgroundTransparency = 1;
KeyTitle.Text = "ปุ่มลัดสำหรับ PC";
KeyTitle.TextColor3 = C(185, 185, 185);
KeyTitle.TextSize = 14;
KeyTitle.TextXAlignment = Enum.TextXAlignment.Left;
KeyTitle.Parent = SettingsPage;
local Bind = I("TextButton");
Bind.Size = D(1, -30, 0, 44);
Bind.Position = U(15, 95);
Bind.BackgroundColor3 = C(40, 40, 40);
Bind.BorderSizePixel = 0;
Bind.TextColor3 = W;
Bind.TextSize = 16;
Bind.Parent = SettingsPage;
round(Bind, 6);
local Reset = I("TextButton");
Reset.Size = U(110, 32);
Reset.Position = U(15, 150);
Reset.BackgroundColor3 = C(65, 65, 65);
Reset.BorderSizePixel = 0;
Reset.Text = "รีเซ็ตปุ่ม";
Reset.TextColor3 = W;
Reset.TextSize = 13;
Reset.Parent = SettingsPage;
round(Reset, 5);
local HomeInfo = I("TextLabel");
HomeInfo.Size = D(1, -30, 0, 75);
HomeInfo.Position = U(15, 210);
HomeInfo.BackgroundTransparency = 1;
HomeInfo.Text = "ปุ่มบ้าน\n" .. "จุดกลับบ้านคือจุดที่คุณยืนตอนรัน MALMON HUB";
HomeInfo.TextColor3 = C(165, 165, 165);
HomeInfo.TextSize = 13;
HomeInfo.TextWrapped = true;
HomeInfo.TextXAlignment = Enum.TextXAlignment.Left;
HomeInfo.TextYAlignment = Enum.TextYAlignment.Top;
HomeInfo.Parent = SettingsPage;
local TrackInfo = I("TextLabel");
TrackInfo.Size = D(1, -30, 0, 90);
TrackInfo.Position = U(15, 300);
TrackInfo.BackgroundTransparency = 1;
TrackInfo.Text = "เวลา Track\n" .. "จับเวลาร้าน 1 ครั้งตอนรัน แล้วนับรอบละ 7 นาที";
TrackInfo.TextColor3 = C(165, 165, 165);
TrackInfo.TextSize = 12;
TrackInfo.TextWrapped = true;
TrackInfo.TextXAlignment = Enum.TextXAlignment.Left;
TrackInfo.TextYAlignment = Enum.TextYAlignment.Top;
TrackInfo.Parent = SettingsPage;
SettingsButton.MouseButton1Click:Connect(function()
	local FlatIdent_1B881 = 0;
	while true do
		if (FlatIdent_1B881 == 0) then
			SettingsPage.Visible = not SettingsPage.Visible;
			EggPage.Visible = not SettingsPage.Visible;
			break;
		end
	end
end);
Back.MouseButton1Click:Connect(function()
	local FlatIdent_25A9F = 0;
	while true do
		if (FlatIdent_25A9F == 0) then
			SettingsPage.Visible = false;
			EggPage.Visible = true;
			break;
		end
	end
end);
local Toggle = I("ImageButton");
Toggle.Size = U(54, 54);
Toggle.Position = D(0, 10, 0, 8);
Toggle.BackgroundColor3 = C(12, 12, 12);
Toggle.BorderSizePixel = 0;
Toggle.Image = LOGO_ID;
Toggle.ScaleType = Enum.ScaleType.Crop;
Toggle.AutoButtonColor = false;
Toggle.Active = true;
Toggle.Draggable = true;
Toggle.ClipsDescendants = true;
Toggle.Parent = G;
local TC = I("UICorner");
TC.CornerRadius = UDim.new(1, 0);
TC.Parent = Toggle;
local TS = I("UIStroke");
TS.Thickness = 1.5;
TS.Color = C(90, 25, 25);
TS.Transparency = 0.15;
TS.Parent = Toggle;
local function toggleHub()
	Window.Visible = not Window.Visible;
end
Toggle.MouseButton1Click:Connect(toggleHub);
local Keybind = Enum.KeyCode.RightShift;
if (type(ENV.MalmonKeybind) == "string") then
	local FlatIdent_72421 = 0;
	local ok;
	local key;
	while true do
		if (FlatIdent_72421 == 0) then
			ok, key = pcall(function()
				return Enum.KeyCode[ENV.MalmonKeybind];
			end);
			if (ok and key) then
				Keybind = key;
			end
			break;
		end
	end
end
local Listening = false;
local function updateKey()
	Bind.Text = "เปิด / ปิด Hub :  " .. Keybind.Name;
end
updateKey();
Bind.MouseButton1Click:Connect(function()
	local FlatIdent_4508F = 0;
	while true do
		if (FlatIdent_4508F == 0) then
			Listening = true;
			Bind.Text = "กดปุ่มที่ต้องการ...";
			break;
		end
	end
end);
Reset.MouseButton1Click:Connect(function()
	Keybind = Enum.KeyCode.RightShift;
	ENV.MalmonKeybind = Keybind.Name;
	Listening = false;
	updateKey();
end);
ENV.MalmonKeyConn = UIS.InputBegan:Connect(function(input, typing)
	local FlatIdent_284EA = 0;
	while true do
		if (FlatIdent_284EA == 0) then
			if Listening then
				if ((input.UserInputType == Enum.UserInputType.Keyboard) and (input.KeyCode ~= Enum.KeyCode.Unknown)) then
					local FlatIdent_67517 = 0;
					while true do
						if (FlatIdent_67517 == 1) then
							Listening = false;
							updateKey();
							break;
						end
						if (FlatIdent_67517 == 0) then
							Keybind = input.KeyCode;
							ENV.MalmonKeybind = Keybind.Name;
							FlatIdent_67517 = 1;
						end
					end
				end
				return;
			end
			if (not typing and (input.KeyCode == Keybind)) then
				toggleHub();
			end
			break;
		end
	end
end);
Home.MouseButton1Click:Connect(function()
	local FlatIdent_521D6 = 0;
	local ch;
	while true do
		if (0 == FlatIdent_521D6) then
			ch = P.Character;
			if ch then
				ch:PivotTo(BaseCF);
			end
			break;
		end
	end
end);
Close.MouseButton1Click:Connect(function()
	Window.Visible = false;
end);
local Shown = 0;
local Total = 0;
local function updateStatus()
	Status.Text = "Rare first  |  " .. Shown .. " / " .. Total .. " eggs  |  Track " .. getTrackText();
end
local function refresh()
	local FlatIdent_634AF = 0;
	local scroll;
	local eggs;
	local totals;
	local numbers;
	local query;
	while true do
		if (FlatIdent_634AF == 1) then
			for _, v in ipairs(List:GetChildren()) do
				if v:IsA("TextButton") then
					v:Destroy();
				end
			end
			eggs = EggFolder:GetChildren();
			table.sort(eggs, sortEgg);
			FlatIdent_634AF = 2;
		end
		if (FlatIdent_634AF == 4) then
			for _, egg in ipairs(eggs) do
				numbers[egg.Name] = (numbers[egg.Name] or 0) + 1;
				if ((query == "") or egg.Name:lower():find(query, 1, true)) then
					local FlatIdent_15A17 = 0;
					local eggName;
					local eggNum;
					local display;
					local B;
					local Img;
					local Txt;
					while true do
						if (FlatIdent_15A17 == 8) then
							Txt.TextColor3 = W;
							Txt.TextSize = 16;
							Txt.TextXAlignment = Enum.TextXAlignment.Left;
							FlatIdent_15A17 = 9;
						end
						if (FlatIdent_15A17 == 2) then
							B.Size = D(1, -6, 0, 54);
							B.BackgroundColor3 = C(49, 49, 49);
							B.BorderSizePixel = 0;
							FlatIdent_15A17 = 3;
						end
						if (FlatIdent_15A17 == 6) then
							Img.Parent = B;
							Txt = I("TextLabel");
							Txt.Size = D(1, -65, 1, 0);
							FlatIdent_15A17 = 7;
						end
						if (FlatIdent_15A17 == 9) then
							Txt.Parent = B;
							B.MouseButton1Click:Connect(function()
								local FlatIdent_651C5 = 0;
								local target;
								while true do
									if (FlatIdent_651C5 == 0) then
										target = findEgg(eggName, eggNum);
										if target then
											fastTeleport(target);
										end
										break;
									end
								end
							end);
							break;
						end
						if (FlatIdent_15A17 == 4) then
							Img = I("ImageLabel");
							Img.Size = U(46, 46);
							Img.Position = U(5, 4);
							FlatIdent_15A17 = 5;
						end
						if (5 == FlatIdent_15A17) then
							Img.BackgroundTransparency = 1;
							Img.ScaleType = Enum.ScaleType.Fit;
							Img.Image = Images[eggName] or "";
							FlatIdent_15A17 = 6;
						end
						if (FlatIdent_15A17 == 1) then
							display = eggName;
							if (totals[eggName] > 1) then
								display = display .. " #" .. eggNum;
							end
							B = I("TextButton");
							FlatIdent_15A17 = 2;
						end
						if (FlatIdent_15A17 == 3) then
							B.Text = "";
							B.Parent = List;
							round(B, 6);
							FlatIdent_15A17 = 4;
						end
						if (FlatIdent_15A17 == 7) then
							Txt.Position = U(60, 0);
							Txt.BackgroundTransparency = 1;
							Txt.Text = display;
							FlatIdent_15A17 = 8;
						end
						if (FlatIdent_15A17 == 0) then
							Shown += 1
							eggName = egg.Name;
							eggNum = numbers[eggName];
							FlatIdent_15A17 = 1;
						end
					end
				end
			end
			updateStatus();
			task.defer(function()
				if List.Parent then
					List.CanvasPosition = scroll;
				end
			end);
			break;
		end
		if (FlatIdent_634AF == 0) then
			EggFolder = getEggFolder() or EggFolder;
			if not EggFolder then
				return;
			end
			scroll = List.CanvasPosition;
			FlatIdent_634AF = 1;
		end
		if (FlatIdent_634AF == 2) then
			totals = {};
			numbers = {};
			query = Search.Text:lower();
			FlatIdent_634AF = 3;
		end
		if (FlatIdent_634AF == 3) then
			Shown = 0;
			Total = #eggs;
			for _, egg in ipairs(eggs) do
				totals[egg.Name] = (totals[egg.Name] or 0) + 1;
			end
			FlatIdent_634AF = 4;
		end
	end
end
Search:GetPropertyChangedSignal("Text"):Connect(refresh);
local RefreshToken = 0;
local WatchedFolder = nil;
local function scheduleRefresh()
	local FlatIdent_3CDED = 0;
	local token;
	while true do
		if (0 == FlatIdent_3CDED) then
			RefreshToken += 1
			token = RefreshToken;
			FlatIdent_3CDED = 1;
		end
		if (FlatIdent_3CDED == 1) then
			task.delay(0.18, function()
				if (token ~= RefreshToken) then
					return;
				end
				if (ENV.MalmonRunId ~= RUN_ID) then
					return;
				end
				refresh();
			end);
			break;
		end
	end
end
local function bindEggFolder(folder)
	local FlatIdent_3B868 = 0;
	while true do
		if (FlatIdent_3B868 == 2) then
			EggFolder = folder;
			ENV.MalmonEggAddConn = folder.ChildAdded:Connect(scheduleRefresh);
			FlatIdent_3B868 = 3;
		end
		if (3 == FlatIdent_3B868) then
			ENV.MalmonEggRemoveConn = folder.ChildRemoved:Connect(scheduleRefresh);
			scheduleRefresh();
			break;
		end
		if (FlatIdent_3B868 == 0) then
			if (not folder or (folder == WatchedFolder)) then
				return;
			end
			disconnect("MalmonEggAddConn");
			FlatIdent_3B868 = 1;
		end
		if (1 == FlatIdent_3B868) then
			disconnect("MalmonEggRemoveConn");
			WatchedFolder = folder;
			FlatIdent_3B868 = 2;
		end
	end
end
bindEggFolder(EggFolder);
ENV.MalmonWorkspaceAddConn = workspace.ChildAdded:Connect(function(v)
	if (v.Name == "RenderedEggs") then
		task.defer(function()
			bindEggFolder(v);
		end);
	end
end);
refresh();
task.spawn(function()
	task.wait(0.25);
	if (ENV.MalmonRunId ~= RUN_ID) then
		return;
	end
	local ok, result = pcall(captureTrackOnce);
	if (not ok or not result) then
		local FlatIdent_2BE68 = 0;
		while true do
			if (FlatIdent_2BE68 == 0) then
				TrackState = "FAILED";
				if not ok then
					warn("MALMON TRACK:", result);
				end
				break;
			end
		end
	end
	updateStatus();
end);
task.spawn(function()
	local FlatIdent_31077 = 0;
	local previous;
	while true do
		if (FlatIdent_31077 == 0) then
			previous = "";
			while G.Parent and (ENV.MalmonRunId == RUN_ID) do
				local FlatIdent_835BC = 0;
				local current;
				while true do
					if (FlatIdent_835BC == 1) then
						if (current ~= previous) then
							previous = current;
							updateStatus();
						end
						break;
					end
					if (0 == FlatIdent_835BC) then
						task.wait(0.5);
						current = getTrackText();
						FlatIdent_835BC = 1;
					end
				end
			end
			break;
		end
	end
end);
print("MALMON HUB OPTIMIZED READY", #EggFolder:GetChildren());
