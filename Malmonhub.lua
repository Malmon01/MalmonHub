--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

print("MALMON HUB START");
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
	local FlatIdent_7F3C8 = 0;
	local ok;
	local e;
	while true do
		if (FlatIdent_7F3C8 == 0) then
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
		local FlatIdent_95CAC = 0;
		while true do
			if (FlatIdent_95CAC == 0) then
				pcall(function()
					ENV[name]:Disconnect();
				end);
				ENV[name] = nil;
				break;
			end
		end
	end
end
disconnect("MalmonKeyConn");
disconnect("MalmonEggAddConn");
disconnect("MalmonEggRemoveConn");
disconnect("MalmonDialogueConn");
for _, name in ipairs({"MalmonHub","EggFinder"}) do
	local FlatIdent_76979 = 0;
	local old;
	while true do
		if (FlatIdent_76979 == 0) then
			old = PG:FindFirstChild(name);
			if old then
				old:Destroy();
			end
			break;
		end
	end
end
local function getEggFolder()
	return workspace:FindFirstChild("RenderedEggs");
end
local EggFolder = workspace:WaitForChild("RenderedEggs");
local Index = Main:WaitForChild("Index");
local Holders = Index:WaitForChild("Holders");
local EggHolder = Holders:WaitForChild("EggsHolder");
local Char = P.Character or P.CharacterAdded:Wait();
local Root = Char:WaitForChild("HumanoidRootPart");
local BaseCF = Root.CFrame;
local I = Instance.new;
local U = UDim2.fromOffset;
local D = UDim2.new;
local C = Color3.fromRGB;
local W = Color3.new(1, 1, 1);
local function round(obj, r)
	local FlatIdent_5D802 = 0;
	local corner;
	while true do
		if (FlatIdent_5D802 == 1) then
			corner.Parent = obj;
			return corner;
		end
		if (FlatIdent_5D802 == 0) then
			corner = I("UICorner");
			corner.CornerRadius = UDim.new(0, r or 6);
			FlatIdent_5D802 = 1;
		end
	end
end
local Images = {};
local Rank = {};
local function rebuildEggData()
	local FlatIdent_43337 = 0;
	while true do
		if (FlatIdent_43337 == 1) then
			for i, v in ipairs(EggHolder:GetChildren()) do
				local FlatIdent_69270 = 0;
				local img;
				while true do
					if (FlatIdent_69270 == 0) then
						img = v:FindFirstChild("ImageLabel");
						if img then
							local FlatIdent_44100 = 0;
							while true do
								if (FlatIdent_44100 == 0) then
									Images[v.Name] = img.Image;
									if (v:IsA("GuiObject") and (v.LayoutOrder ~= 0)) then
										Rank[v.Name] = v.LayoutOrder;
									else
										Rank[v.Name] = i;
									end
									break;
								end
							end
						end
						break;
					end
				end
			end
			break;
		end
		if (FlatIdent_43337 == 0) then
			Images = {};
			Rank = {};
			FlatIdent_43337 = 1;
		end
	end
end
rebuildEggData();
local function getCF(v)
	local FlatIdent_4D83A = 0;
	local part;
	while true do
		if (1 == FlatIdent_4D83A) then
			if v:IsA("Model") then
				local FlatIdent_10550 = 0;
				local ok;
				local result;
				while true do
					if (0 == FlatIdent_10550) then
						ok, result = pcall(function()
							return v:GetPivot();
						end);
						if ok then
							return result;
						end
						break;
					end
				end
			end
			part = v:FindFirstChildWhichIsA("BasePart", true);
			FlatIdent_4D83A = 2;
		end
		if (FlatIdent_4D83A == 0) then
			if not v then
				return nil;
			end
			if v:IsA("BasePart") then
				return v.CFrame;
			end
			FlatIdent_4D83A = 1;
		end
		if (FlatIdent_4D83A == 2) then
			if part then
				return part.CFrame;
			end
			return nil;
		end
	end
end
local function sortEgg(a, b)
	local FlatIdent_6EEC8 = 0;
	local ra;
	local rb;
	local ca;
	local cb;
	while true do
		if (FlatIdent_6EEC8 == 1) then
			if (ra ~= rb) then
				return ra > rb;
			end
			if (a.Name ~= b.Name) then
				return a.Name:lower() < b.Name:lower();
			end
			FlatIdent_6EEC8 = 2;
		end
		if (FlatIdent_6EEC8 == 3) then
			if (ca and cb) then
				local FlatIdent_6D4CB = 0;
				local A;
				local B;
				while true do
					if (FlatIdent_6D4CB == 1) then
						if (A.X ~= B.X) then
							return A.X < B.X;
						end
						if (A.Z ~= B.Z) then
							return A.Z < B.Z;
						end
						FlatIdent_6D4CB = 2;
					end
					if (2 == FlatIdent_6D4CB) then
						return A.Y < B.Y;
					end
					if (FlatIdent_6D4CB == 0) then
						A = ca.Position;
						B = cb.Position;
						FlatIdent_6D4CB = 1;
					end
				end
			end
			return false;
		end
		if (FlatIdent_6EEC8 == 2) then
			ca = getCF(a);
			cb = getCF(b);
			FlatIdent_6EEC8 = 3;
		end
		if (0 == FlatIdent_6EEC8) then
			ra = Rank[a.Name] or 0;
			rb = Rank[b.Name] or 0;
			FlatIdent_6EEC8 = 1;
		end
	end
end
local function findEgg(name, num)
	local FlatIdent_6D884 = 0;
	local folder;
	local found;
	while true do
		if (0 == FlatIdent_6D884) then
			folder = getEggFolder();
			if not folder then
				return nil;
			end
			FlatIdent_6D884 = 1;
		end
		if (FlatIdent_6D884 == 2) then
			table.sort(found, sortEgg);
			return found[num];
		end
		if (FlatIdent_6D884 == 1) then
			found = {};
			for _, v in ipairs(folder:GetChildren()) do
				if (v.Name == name) then
					table.insert(found, v);
				end
			end
			FlatIdent_6D884 = 2;
		end
	end
end
local function moveTo(pos)
	local ch = P.Character;
	if not ch then
		return;
	end
	local hrp = ch:FindFirstChild("HumanoidRootPart");
	local hum = ch:FindFirstChildOfClass("Humanoid");
	if not hrp then
		return;
	end
	pcall(function()
		P:RequestStreamAroundAsync(pos);
	end);
	if hum then
		local FlatIdent_2661B = 0;
		while true do
			if (FlatIdent_2661B == 1) then
				hum.AutoRotate = true;
				break;
			end
			if (FlatIdent_2661B == 0) then
				hum.Sit = false;
				hum.PlatformStand = false;
				FlatIdent_2661B = 1;
			end
		end
	end
	local collision = {};
	for _, v in ipairs(ch:GetDescendants()) do
		if v:IsA("BasePart") then
			collision[v] = v.CanCollide;
			v.CanCollide = false;
		end
	end
	hrp.AssemblyLinearVelocity = Vector3.zero;
	hrp.AssemblyAngularVelocity = Vector3.zero;
	local _, yaw, _ = hrp.CFrame:ToOrientation();
	local function upright(p)
		return CFrame.new(p) * CFrame.Angles(0, yaw, 0);
	end
	if ((hrp.Position - pos).Magnitude > 120) then
		local FlatIdent_7366E = 0;
		while true do
			if (0 == FlatIdent_7366E) then
				ch:PivotTo(upright(pos + Vector3.new(0, 15, 0)));
				task.wait(0.3);
				break;
			end
		end
	end
	ch:PivotTo(upright(pos + Vector3.new(0, 5, 0)));
	task.wait(0.15);
	hrp = ch:FindFirstChild("HumanoidRootPart");
	if hrp then
		local FlatIdent_1DFAF = 0;
		while true do
			if (FlatIdent_1DFAF == 0) then
				hrp.AssemblyLinearVelocity = Vector3.zero;
				hrp.AssemblyAngularVelocity = Vector3.zero;
				break;
			end
		end
	end
	if hum then
		local FlatIdent_43862 = 0;
		while true do
			if (FlatIdent_43862 == 1) then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp);
				task.wait(0.05);
				FlatIdent_43862 = 2;
			end
			if (0 == FlatIdent_43862) then
				hum.Sit = false;
				hum.PlatformStand = false;
				FlatIdent_43862 = 1;
			end
			if (FlatIdent_43862 == 2) then
				hum:ChangeState(Enum.HumanoidStateType.Running);
				break;
			end
		end
	end
	task.wait(0.25);
	for part, state in pairs(collision) do
		if (part and part.Parent) then
			part.CanCollide = state;
		end
	end
end
local function teleportEgg(v)
	local FlatIdent_C460 = 0;
	local c;
	while true do
		if (FlatIdent_C460 == 0) then
			c = getCF(v);
			if c then
				moveTo(c.Position);
			end
			break;
		end
	end
end
local TrackInitial = nil;
local TrackClock = nil;
local TrackState = "SYNC";
local function parseTimer(text)
	local FlatIdent_104D4 = 0;
	local m;
	local s;
	while true do
		if (FlatIdent_104D4 == 1) then
			if (not m or not s) then
				return nil;
			end
			return (tonumber(m) * 60) + tonumber(s);
		end
		if (FlatIdent_104D4 == 0) then
			if (type(text) ~= "string") then
				return nil;
			end
			m, s = text:match("(%d+):(%d+)");
			FlatIdent_104D4 = 1;
		end
	end
end
local function setTrack(seconds, clock)
	local FlatIdent_A9A3 = 0;
	while true do
		if (FlatIdent_A9A3 == 0) then
			if not seconds then
				return;
			end
			TrackInitial = seconds;
			FlatIdent_A9A3 = 1;
		end
		if (1 == FlatIdent_A9A3) then
			TrackClock = clock or os.clock();
			TrackState = "READY";
			break;
		end
	end
end
local function currentTrackSeconds()
	local FlatIdent_2FD19 = 0;
	local elapsed;
	local afterFirst;
	local inside;
	while true do
		if (FlatIdent_2FD19 == 0) then
			if (not TrackInitial or not TrackClock) then
				return nil;
			end
			elapsed = math.floor(os.clock() - TrackClock);
			FlatIdent_2FD19 = 1;
		end
		if (FlatIdent_2FD19 == 1) then
			if (elapsed < TrackInitial) then
				return TrackInitial - elapsed;
			end
			afterFirst = elapsed - TrackInitial;
			FlatIdent_2FD19 = 2;
		end
		if (FlatIdent_2FD19 == 2) then
			inside = afterFirst % TRACK_CYCLE;
			return TRACK_CYCLE - inside;
		end
	end
end
local function getTrackText()
	local FlatIdent_1B51D = 0;
	local seconds;
	while true do
		if (FlatIdent_1B51D == 1) then
			if not seconds then
				return "--";
			end
			return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60);
		end
		if (FlatIdent_1B51D == 0) then
			if (TrackState == "SYNC") then
				return "...";
			end
			seconds = currentTrackSeconds();
			FlatIdent_1B51D = 1;
		end
	end
end
local function closeEggTracker(tracker)
	local FlatIdent_14454 = 0;
	local best;
	local bestScore;
	while true do
		if (FlatIdent_14454 == 2) then
			if tracker.Visible then
				tracker.Visible = false;
			end
			break;
		end
		if (FlatIdent_14454 == 0) then
			best = nil;
			bestScore = -1;
			FlatIdent_14454 = 1;
		end
		if (FlatIdent_14454 == 1) then
			for _, v in ipairs(tracker:GetDescendants()) do
				if v:IsA("GuiButton") then
					local FlatIdent_5BCFC = 0;
					local score;
					local name;
					while true do
						if (0 == FlatIdent_5BCFC) then
							score = 0;
							name = v.Name:lower();
							FlatIdent_5BCFC = 1;
						end
						if (FlatIdent_5BCFC == 1) then
							if ((name == "close") or (name == "closebutton")) then
								score = 100;
							elseif name:find("close") then
								score = 90;
							elseif (name == "x") then
								score = 85;
							end
							if v:IsA("TextButton") then
								local FlatIdent_25DF3 = 0;
								local text;
								while true do
									if (FlatIdent_25DF3 == 0) then
										text = v.Text:gsub("%s+", "");
										if ((text == "X") or (text == "×")) then
											score = math.max(score, 95);
										end
										break;
									end
								end
							end
							FlatIdent_5BCFC = 2;
						end
						if (FlatIdent_5BCFC == 2) then
							if (score > bestScore) then
								local FlatIdent_5BA5E = 0;
								while true do
									if (FlatIdent_5BA5E == 0) then
										best = v;
										bestScore = score;
										break;
									end
								end
							end
							break;
						end
					end
				end
			end
			if (best and (bestScore > 0) and (type(firesignal) == "function")) then
				local FlatIdent_74348 = 0;
				while true do
					if (FlatIdent_74348 == 1) then
						if not tracker.Visible then
							return;
						end
						pcall(function()
							firesignal(best.Activated);
						end);
						FlatIdent_74348 = 2;
					end
					if (FlatIdent_74348 == 0) then
						pcall(function()
							firesignal(best.MouseButton1Click);
						end);
						task.wait(0.3);
						FlatIdent_74348 = 1;
					end
					if (2 == FlatIdent_74348) then
						task.wait(0.2);
						break;
					end
				end
			end
			FlatIdent_14454 = 2;
		end
	end
end
local function captureTrackOnce()
	local FlatIdent_817B0 = 0;
	local Tracker;
	local Timer;
	local Dialogue;
	local Remotes;
	local DialogueSend;
	local DialogueSelect;
	local Eggo;
	local EggoRoot;
	local Prompt;
	local ch;
	local hrp;
	local ReturnCF;
	local gotDialogue;
	local dialogueDeadline;
	local openDeadline;
	local captured;
	local capturedAt;
	local previous;
	local timerDeadline;
	while true do
		if (FlatIdent_817B0 == 5) then
			openDeadline = os.clock() + 5;
			while not Tracker.Visible and (os.clock() < openDeadline) do
				task.wait(0.05);
			end
			disconnect("MalmonDialogueConn");
			if not Tracker.Visible then
				local FlatIdent_1A54 = 0;
				while true do
					if (0 == FlatIdent_1A54) then
						warn("MALMON: EGG TRACKER DID NOT OPEN");
						if ch.Parent then
							ch:PivotTo(ReturnCF);
						end
						FlatIdent_1A54 = 1;
					end
					if (FlatIdent_1A54 == 1) then
						TrackState = "FAILED";
						return false;
					end
				end
			end
			print("TRACK OPEN:", Timer.Text);
			captured = parseTimer(Timer.Text);
			FlatIdent_817B0 = 6;
		end
		if (6 == FlatIdent_817B0) then
			capturedAt = os.clock();
			previous = captured;
			timerDeadline = os.clock() + 2.5;
			while os.clock() < timerDeadline do
				task.wait(0.1);
				local current = parseTimer(Timer.Text);
				if current then
					captured = current;
					capturedAt = os.clock();
					if (previous and (current < previous) and ((previous - current) <= 3)) then
						break;
					end
					previous = current;
				end
			end
			print("TRACK TIMER:", Timer.Text);
			closeEggTracker(Tracker);
			FlatIdent_817B0 = 7;
		end
		if (FlatIdent_817B0 == 3) then
			if hrp then
				local FlatIdent_28F3E = 0;
				while true do
					if (FlatIdent_28F3E == 0) then
						hrp.AssemblyLinearVelocity = Vector3.zero;
						hrp.AssemblyAngularVelocity = Vector3.zero;
						break;
					end
				end
			end
			task.wait(1);
			if (ENV.MalmonRunId ~= RUN_ID) then
				return false;
			end
			if (type(fireproximityprompt) == "function") then
				local FlatIdent_17AE1 = 0;
				while true do
					if (0 == FlatIdent_17AE1) then
						print("TRY PROMPT");
						fireproximityprompt(Prompt);
						break;
					end
				end
			else
				local FlatIdent_2F37F = 0;
				while true do
					if (FlatIdent_2F37F == 1) then
						task.wait(0.1);
						VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game);
						break;
					end
					if (FlatIdent_2F37F == 0) then
						print("TRY E KEY");
						VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game);
						FlatIdent_2F37F = 1;
					end
				end
			end
			dialogueDeadline = os.clock() + 4;
			while not gotDialogue and (os.clock() < dialogueDeadline) do
				task.wait(0.05);
			end
			FlatIdent_817B0 = 4;
		end
		if (FlatIdent_817B0 == 0) then
			print("TRACK CAPTURE START");
			Tracker = Main:WaitForChild("EggTracker");
			Timer = Tracker:WaitForChild("Timer");
			Dialogue = RS:WaitForChild("Dialogue");
			Remotes = Dialogue:WaitForChild("Remotes");
			DialogueSend = Remotes:WaitForChild("DialogueSend");
			FlatIdent_817B0 = 1;
		end
		if (FlatIdent_817B0 == 1) then
			DialogueSelect = Remotes:WaitForChild("DialogueSelect");
			Eggo = workspace:WaitForChild("Stalls"):WaitForChild("EggTracker"):WaitForChild("Eggo");
			EggoRoot = Eggo:WaitForChild("HumanoidRootPart");
			Prompt = EggoRoot:WaitForChild("ProximityPrompt");
			ch = P.Character or P.CharacterAdded:Wait();
			hrp = ch:WaitForChild("HumanoidRootPart");
			FlatIdent_817B0 = 2;
		end
		if (7 == FlatIdent_817B0) then
			task.wait(0.15);
			if (ch and ch.Parent) then
				ch:PivotTo(ReturnCF);
				task.wait(0.1);
				local currentRoot = ch:FindFirstChild("HumanoidRootPart");
				if currentRoot then
					local FlatIdent_882F4 = 0;
					while true do
						if (FlatIdent_882F4 == 0) then
							currentRoot.AssemblyLinearVelocity = Vector3.zero;
							currentRoot.AssemblyAngularVelocity = Vector3.zero;
							break;
						end
					end
				end
				local hum = ch:FindFirstChildOfClass("Humanoid");
				if hum then
					hum.Sit = false;
					hum.PlatformStand = false;
					hum.AutoRotate = true;
					hum:ChangeState(Enum.HumanoidStateType.Running);
				end
			end
			if captured then
				local FlatIdent_86634 = 0;
				while true do
					if (FlatIdent_86634 == 0) then
						setTrack(captured, capturedAt);
						print("TRACK CAPTURED:", getTrackText());
						FlatIdent_86634 = 1;
					end
					if (FlatIdent_86634 == 1) then
						print("TRACK WILL NOW RUN LOCALLY");
						return true;
					end
				end
			end
			TrackState = "FAILED";
			warn("MALMON: COULD NOT READ TIMER");
			return false;
		end
		if (FlatIdent_817B0 == 2) then
			ReturnCF = hrp.CFrame;
			gotDialogue = false;
			disconnect("MalmonDialogueConn");
			ENV.MalmonDialogueConn = DialogueSend.OnClientEvent:Connect(function(data)
				if ((type(data) == "table") and (data.Model == Eggo)) then
					local FlatIdent_8A742 = 0;
					while true do
						if (0 == FlatIdent_8A742) then
							gotDialogue = true;
							print("SERVER DIALOGUE RECEIVED");
							break;
						end
					end
				end
			end);
			ch:PivotTo(EggoRoot.CFrame * CFrame.new(0, 0, -4));
			hrp = ch:FindFirstChild("HumanoidRootPart");
			FlatIdent_817B0 = 3;
		end
		if (FlatIdent_817B0 == 4) then
			if not gotDialogue then
				local FlatIdent_5F1CB = 0;
				while true do
					if (FlatIdent_5F1CB == 0) then
						warn("MALMON: SERVER DIALOGUE NOT RECEIVED");
						disconnect("MalmonDialogueConn");
						FlatIdent_5F1CB = 1;
					end
					if (FlatIdent_5F1CB == 2) then
						return false;
					end
					if (FlatIdent_5F1CB == 1) then
						if ch.Parent then
							ch:PivotTo(ReturnCF);
						end
						TrackState = "FAILED";
						FlatIdent_5F1CB = 2;
					end
				end
			end
			print("REAL DIALOGUE READY");
			task.wait(0.7);
			if (ENV.MalmonRunId ~= RUN_ID) then
				return false;
			end
			print("SELECT YEAH");
			DialogueSelect:FireServer(Eggo, "Yeah");
			FlatIdent_817B0 = 5;
		end
	end
end
local G = I("ScreenGui");
G.Name = "MalmonHub";
G.ResetOnSpawn = false;
G.DisplayOrder = 999999;
G.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
G.Parent = PG;
local Window = I("Frame");
Window.Name = "Main";
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
EggPage.Name = "EggPage";
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
SettingsPage.Name = "SettingsPage";
SettingsPage.Size = D(1, 0, 1, -40);
SettingsPage.Position = U(0, 40);
SettingsPage.BackgroundTransparency = 1;
SettingsPage.Visible = false;
SettingsPage.Parent = Window;
local SettingsTitle = I("TextLabel");
SettingsTitle.Size = D(1, -110, 0, 40);
SettingsTitle.Position = U(12, 10);
SettingsTitle.BackgroundTransparency = 1;
SettingsTitle.Text = "การตั้งค่า";
SettingsTitle.TextColor3 = W;
SettingsTitle.TextSize = 22;
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left;
SettingsTitle.Parent = SettingsPage;
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
local ResetKey = I("TextButton");
ResetKey.Size = U(110, 32);
ResetKey.Position = U(15, 150);
ResetKey.BackgroundColor3 = C(65, 65, 65);
ResetKey.BorderSizePixel = 0;
ResetKey.Text = "รีเซ็ตปุ่ม";
ResetKey.TextColor3 = W;
ResetKey.TextSize = 13;
ResetKey.Parent = SettingsPage;
round(ResetKey, 5);
local HomeInfoTitle = I("TextLabel");
HomeInfoTitle.Size = D(1, -30, 0, 26);
HomeInfoTitle.Position = U(15, 205);
HomeInfoTitle.BackgroundTransparency = 1;
HomeInfoTitle.Text = "ปุ่มบ้าน";
HomeInfoTitle.TextColor3 = C(185, 185, 185);
HomeInfoTitle.TextSize = 14;
HomeInfoTitle.TextXAlignment = Enum.TextXAlignment.Left;
HomeInfoTitle.Parent = SettingsPage;
local HomeInfo = I("TextLabel");
HomeInfo.Size = D(1, -30, 0, 65);
HomeInfo.Position = U(15, 233);
HomeInfo.BackgroundTransparency = 1;
HomeInfo.Text = "จุดกลับบ้านคือจุดที่คุณยืน\n" .. "ตอนรัน MALMON HUB ครั้งแรก";
HomeInfo.TextColor3 = C(165, 165, 165);
HomeInfo.TextSize = 13;
HomeInfo.TextWrapped = true;
HomeInfo.TextXAlignment = Enum.TextXAlignment.Left;
HomeInfo.TextYAlignment = Enum.TextYAlignment.Top;
HomeInfo.Parent = SettingsPage;
local TrackInfo = I("TextLabel");
TrackInfo.Size = D(1, -30, 0, 95);
TrackInfo.Position = U(15, 300);
TrackInfo.BackgroundTransparency = 1;
TrackInfo.Text = "เวลา Track:\n" .. "จับเวลาจริงจากร้าน 1 ครั้งตอนรัน\n" .. "จากนั้นนับรอบใหม่ทุก 7 นาทีอัตโนมัติ";
TrackInfo.TextColor3 = C(165, 165, 165);
TrackInfo.TextSize = 12;
TrackInfo.TextWrapped = true;
TrackInfo.TextXAlignment = Enum.TextXAlignment.Left;
TrackInfo.TextYAlignment = Enum.TextYAlignment.Top;
TrackInfo.Parent = SettingsPage;
local MobileInfo = I("TextLabel");
MobileInfo.Size = D(1, -30, 0, 45);
MobileInfo.Position = U(15, 390);
MobileInfo.BackgroundTransparency = 1;
MobileInfo.Text = "มือถือ: กดโลโก้เพื่อเปิด / ซ่อน MALMON HUB";
MobileInfo.TextColor3 = C(165, 165, 165);
MobileInfo.TextSize = 12;
MobileInfo.TextWrapped = true;
MobileInfo.TextXAlignment = Enum.TextXAlignment.Left;
MobileInfo.Parent = SettingsPage;
local function showEggPage()
	local FlatIdent_2C195 = 0;
	while true do
		if (FlatIdent_2C195 == 0) then
			EggPage.Visible = true;
			SettingsPage.Visible = false;
			break;
		end
	end
end
local function showSettings()
	local FlatIdent_8770C = 0;
	while true do
		if (FlatIdent_8770C == 0) then
			EggPage.Visible = false;
			SettingsPage.Visible = true;
			break;
		end
	end
end
SettingsButton.MouseButton1Click:Connect(function()
	if SettingsPage.Visible then
		showEggPage();
	else
		showSettings();
	end
end);
Back.MouseButton1Click:Connect(showEggPage);
local Toggle = I("ImageButton");
Toggle.Name = "MobileToggle";
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
local ToggleCorner = I("UICorner");
ToggleCorner.CornerRadius = UDim.new(1, 0);
ToggleCorner.Parent = Toggle;
local ToggleStroke = I("UIStroke");
ToggleStroke.Thickness = 1.5;
ToggleStroke.Color = C(90, 25, 25);
ToggleStroke.Transparency = 0.15;
ToggleStroke.Parent = Toggle;
local function toggleHub()
	Window.Visible = not Window.Visible;
end
Toggle.MouseButton1Click:Connect(toggleHub);
local Keybind = Enum.KeyCode.RightShift;
if (type(ENV.MalmonKeybind) == "string") then
	local FlatIdent_3CF01 = 0;
	local ok;
	local key;
	while true do
		if (FlatIdent_3CF01 == 0) then
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
local function updateKeyText()
	Bind.Text = "เปิด / ปิด Hub :  " .. Keybind.Name;
end
updateKeyText();
Bind.MouseButton1Click:Connect(function()
	local FlatIdent_95405 = 0;
	while true do
		if (FlatIdent_95405 == 0) then
			Listening = true;
			Bind.Text = "กดปุ่มที่ต้องการ...";
			break;
		end
	end
end);
ResetKey.MouseButton1Click:Connect(function()
	local FlatIdent_8BF78 = 0;
	while true do
		if (FlatIdent_8BF78 == 1) then
			Listening = false;
			updateKeyText();
			break;
		end
		if (0 == FlatIdent_8BF78) then
			Keybind = Enum.KeyCode.RightShift;
			ENV.MalmonKeybind = Keybind.Name;
			FlatIdent_8BF78 = 1;
		end
	end
end);
ENV.MalmonKeyConn = UIS.InputBegan:Connect(function(input, typing)
	if Listening then
		local FlatIdent_5EE26 = 0;
		while true do
			if (FlatIdent_5EE26 == 0) then
				if ((input.UserInputType == Enum.UserInputType.Keyboard) and (input.KeyCode ~= Enum.KeyCode.Unknown)) then
					local FlatIdent_32B97 = 0;
					while true do
						if (FlatIdent_32B97 == 0) then
							Keybind = input.KeyCode;
							ENV.MalmonKeybind = Keybind.Name;
							FlatIdent_32B97 = 1;
						end
						if (FlatIdent_32B97 == 1) then
							Listening = false;
							updateKeyText();
							break;
						end
					end
				end
				return;
			end
		end
	end
	if typing then
		return;
	end
	if (input.KeyCode == Keybind) then
		toggleHub();
	end
end);
Home.MouseButton1Click:Connect(function()
	moveTo(BaseCF.Position);
end);
Close.MouseButton1Click:Connect(function()
	Window.Visible = false;
end);
local ShownEggs = 0;
local TotalEggs = 0;
local function updateStatus()
	Status.Text = "Rare first  |  " .. ShownEggs .. " / " .. TotalEggs .. " eggs  |  Track " .. getTrackText();
end
local function refresh()
	EggFolder = getEggFolder() or EggFolder;
	if not EggFolder then
		return;
	end
	rebuildEggData();
	local scroll = List.CanvasPosition;
	for _, v in ipairs(List:GetChildren()) do
		if v:IsA("TextButton") then
			v:Destroy();
		end
	end
	local eggs = EggFolder:GetChildren();
	table.sort(eggs, sortEgg);
	local total = {};
	local num = {};
	local query = Search.Text:lower();
	local shown = 0;
	for _, egg in ipairs(eggs) do
		total[egg.Name] = (total[egg.Name] or 0) + 1;
	end
	for _, egg in ipairs(eggs) do
		num[egg.Name] = (num[egg.Name] or 0) + 1;
		if ((query == "") or egg.Name:lower():find(query, 1, true)) then
			shown = shown + 1;
			local eggName = egg.Name;
			local eggNum = num[eggName];
			local display = eggName;
			if (total[eggName] > 1) then
				display = display .. " #" .. eggNum;
			end
			local Button = I("TextButton");
			Button.Size = D(1, -6, 0, 54);
			Button.BackgroundColor3 = C(49, 49, 49);
			Button.BorderSizePixel = 0;
			Button.Text = "";
			Button.Parent = List;
			round(Button, 6);
			local Image = I("ImageLabel");
			Image.Size = U(46, 46);
			Image.Position = U(5, 4);
			Image.BackgroundTransparency = 1;
			Image.ScaleType = Enum.ScaleType.Fit;
			Image.Image = Images[eggName] or "";
			Image.Parent = Button;
			local Text = I("TextLabel");
			Text.Size = D(1, -65, 1, 0);
			Text.Position = U(60, 0);
			Text.BackgroundTransparency = 1;
			Text.Text = display;
			Text.TextColor3 = W;
			Text.TextSize = 16;
			Text.TextXAlignment = Enum.TextXAlignment.Left;
			Text.Parent = Button;
			Button.MouseButton1Click:Connect(function()
				local FlatIdent_8ABD6 = 0;
				local target;
				while true do
					if (FlatIdent_8ABD6 == 0) then
						target = findEgg(eggName, eggNum);
						if target then
							teleportEgg(target);
						end
						break;
					end
				end
			end);
		end
	end
	ShownEggs = shown;
	TotalEggs = #eggs;
	updateStatus();
	task.defer(function()
		if List.Parent then
			List.CanvasPosition = scroll;
		end
	end);
end
Search:GetPropertyChangedSignal("Text"):Connect(refresh);
local WatchedFolder = nil;
local function watchFolder()
	local FlatIdent_40070 = 0;
	local current;
	while true do
		if (3 == FlatIdent_40070) then
			ENV.MalmonEggAddConn = current.ChildAdded:Connect(function()
				task.delay(0.1, refresh);
			end);
			ENV.MalmonEggRemoveConn = current.ChildRemoved:Connect(function()
				task.delay(0.1, refresh);
			end);
			FlatIdent_40070 = 4;
		end
		if (1 == FlatIdent_40070) then
			disconnect("MalmonEggAddConn");
			disconnect("MalmonEggRemoveConn");
			FlatIdent_40070 = 2;
		end
		if (FlatIdent_40070 == 0) then
			current = getEggFolder();
			if (not current or (current == WatchedFolder)) then
				return;
			end
			FlatIdent_40070 = 1;
		end
		if (FlatIdent_40070 == 2) then
			WatchedFolder = current;
			EggFolder = current;
			FlatIdent_40070 = 3;
		end
		if (FlatIdent_40070 == 4) then
			refresh();
			break;
		end
	end
end
watchFolder();
refresh();
task.spawn(function()
	local FlatIdent_42BD8 = 0;
	local ok;
	local result;
	while true do
		if (FlatIdent_42BD8 == 1) then
			ok, result = pcall(captureTrackOnce);
			if not ok then
				TrackState = "FAILED";
				warn("MALMON TRACK ERROR:", result);
			elseif not result then
				warn("MALMON TRACK CAPTURE FAILED");
			end
			FlatIdent_42BD8 = 2;
		end
		if (FlatIdent_42BD8 == 0) then
			task.wait(0.8);
			if (ENV.MalmonRunId ~= RUN_ID) then
				return;
			end
			FlatIdent_42BD8 = 1;
		end
		if (FlatIdent_42BD8 == 2) then
			updateStatus();
			break;
		end
	end
end);
task.spawn(function()
	while G.Parent and (ENV.MalmonRunId == RUN_ID) do
		local FlatIdent_81DE9 = 0;
		while true do
			if (FlatIdent_81DE9 == 0) then
				task.wait(0.2);
				updateStatus();
				break;
			end
		end
	end
end);
task.spawn(function()
	while G.Parent and (ENV.MalmonRunId == RUN_ID) do
		local FlatIdent_31ECC = 0;
		while true do
			if (FlatIdent_31ECC == 0) then
				task.wait(1);
				watchFolder();
				break;
			end
		end
	end
end);
G.AncestryChanged:Connect(function(_, parent)
	local FlatIdent_810FF = 0;
	while true do
		if (FlatIdent_810FF == 0) then
			if parent then
				return;
			end
			disconnect("MalmonDialogueConn");
			FlatIdent_810FF = 1;
		end
		if (FlatIdent_810FF == 1) then
			disconnect("MalmonEggAddConn");
			disconnect("MalmonEggRemoveConn");
			break;
		end
	end
end);
print("MALMON HUB READY", #EggFolder:GetChildren());