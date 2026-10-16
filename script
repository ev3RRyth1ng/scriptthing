-- kill previous instance
if _G.__FlightController and _G.__FlightController.stop then
	pcall(_G.__FlightController.stop)
	_G.__FlightController = nil
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local player           = Players.LocalPlayer

-- flight path
local COORDS = {
	Vector3.new(-56, 60, 1131),
	Vector3.new(-56, 60,  1797),
	Vector3.new(-56, 60,  2611),
	Vector3.new(-56, 60,  3310),
	Vector3.new(-56, 60,  4183),
	Vector3.new(-56, 30,  4880),
	Vector3.new(-56, 60,  5737),
	Vector3.new(-56, 60,  7206),
	Vector3.new(-56, 60,  8061),
	Vector3.new(-56, 60,  8616),
	Vector3.new(-56, -358, 9493),
}

local MIN_SPEED, MAX_SPEED = 100, 500
local speed       = 350
local active      = false
local stopped     = false
local connections = {}
local currentBF, currentHumanoid = nil, nil

local function track(conn)
	table.insert(connections, conn)
	return conn
end

-- ================= auto rejoin =================
local rejoinInProgress = false

local function attemptRejoin()
	if rejoinInProgress then return end
	rejoinInProgress = true
	task.wait(2)
	local placeId = game.PlaceId
	local jobId   = game.JobId
	pcall(function()
		if jobId and jobId ~= "" then
			TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
		else
			TeleportService:Teleport(placeId, player)
		end
	end)
end

if queue_on_teleport then
	pcall(function()
		queue_on_teleport([[
			loadstring(game:HttpGet("https://raw.githubusercontent.com/ev3RRyth1ng/scriptthing/refs/heads/main/script"))()
		]])
	end)
end

-- watch for the disconnect popup
task.spawn(function()
	local CoreGui = game:GetService("CoreGui")
	local ok, promptGui = pcall(function()
		return CoreGui:WaitForChild("RobloxPromptGui", 20)
	end)
	if not ok or not promptGui then return end
	local ok2, overlay = pcall(function()
		return promptGui:WaitForChild("promptOverlay", 20)
	end)
	if not ok2 or not overlay then return end

	overlay.DescendantAdded:Connect(function(d)
		if d:IsA("TextLabel") then
			local txt = d.Text
			if txt:find("Disconnected")
			or txt:find("Lost connection")
			or txt:find("kicked")
			or txt:find("shutdown")
			or txt:find("connection") then
				attemptRejoin()
			end
		end
	end)
end)

track(Players.PlayerRemoving:Connect(function(p)
	if p == player then attemptRejoin() end
end))

-- ================= anti-afk =================
local antiAfkEnabled = false

local function pressKey(kc)
	if keypress and keyrelease then
		pcall(function()
			keypress(kc)
			task.wait(0.05)
			keyrelease(kc)
		end)
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:TypeKey(kc, true)
		task.wait(0.05)
		VirtualUser:TypeKey(kc, false)
	end)
end

local function clickMouse(btn)
	if btn == 1 and mouse1click then
		pcall(mouse1click)
		return
	end
	if btn == 2 and mouse2click then
		pcall(mouse2click)
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		if btn == 1 then
			VirtualUser:ClickButton1(Vector2.new(0, 0))
		else
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end
	end)
end

local function antiAfkTick()
	local choice = math.random(1, 6)
	if choice == 1 then pressKey(Enum.KeyCode.W)
	elseif choice == 2 then pressKey(Enum.KeyCode.A)
	elseif choice == 3 then pressKey(Enum.KeyCode.S)
	elseif choice == 4 then pressKey(Enum.KeyCode.D)
	elseif choice == 5 then clickMouse(1)
	else clickMouse(2)
	end
end

local function runAntiAfkLoop()
	while antiAfkEnabled and not stopped do
		antiAfkTick()
		task.wait(10)
	end
end

local function setAntiAfk(state)
	antiAfkEnabled = state
	if state then
		task.spawn(runAntiAfkLoop)
	end
end

-- ================= flight =================
local function flyLoop()
	while active and not stopped do

		-- wait for a fresh alive character
		local character
		while active and not stopped do
			character = player.Character
			if character and character.Parent then
				local hum = character:FindFirstChildOfClass("Humanoid")
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 then break end
			end
			task.wait(0.1)
		end
		if not active or stopped then break end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp      = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then
			task.wait(0.1)
			continue
		end

		currentHumanoid = humanoid
		humanoid.PlatformStand = true

		local bf = Instance.new("BodyForce")
		bf.Name   = "__GravityCancel"
		bf.Force  = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass, 0)
		bf.Parent = hrp
		currentBF = bf

		pcall(function() character:PivotTo(CFrame.new(COORDS[1])) end)
		hrp.AssemblyLinearVelocity = Vector3.zero

		-- death check
		local function isDead()
			if player.Character ~= character then return true end
			if not character.Parent then return true end
			if not hrp.Parent then return true end
			local h = character:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then return true end
			return false
		end

		for i = 2, #COORDS do
			if not active or stopped or isDead() then break end
			local target = COORDS[i]
			while active and not stopped and not isDead() do
				local diff = target - hrp.Position
				if diff.Magnitude < 3 then break end
				hrp.AssemblyLinearVelocity = diff.Unit * speed
				RunService.Heartbeat:Wait()
			end
		end

		-- hold on the last point
		if active and not stopped and not isDead() then
			local finalPos = COORDS[#COORDS]
			while active and not stopped and not isDead() do
				hrp.AssemblyLinearVelocity = (finalPos - hrp.Position) * 10
				RunService.Heartbeat:Wait()
			end
		end

		if bf and bf.Parent then bf:Destroy() end
		if currentBF == bf then currentBF = nil end
		if humanoid and humanoid.Parent then
			pcall(function() humanoid.PlatformStand = false end)
		end
		if hrp and hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end

		task.wait(0.3)
	end
end

-- ================= gui =================
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name           = "FlightGui"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 100
gui.Parent         = pg

local PANEL_W, PANEL_H = 240, 210

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position         = UDim2.new(0, 20, 0.75, -PANEL_H / 2)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
panel.BorderSizePixel  = 0
panel.Parent           = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 54)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 26)),
})
panelGrad.Rotation = 90
panelGrad.Parent   = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color        = Color3.fromRGB(120, 120, 150)
panelStroke.Transparency = 0.75
panelStroke.Thickness    = 1
panelStroke.Parent       = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position               = UDim2.new(0, 16, 0, 10)
title.Size                   = UDim2.new(1, -100, 0, 16)
title.Font                   = Enum.Font.GothamBold
title.Text                   = "AUTO-FLY"
title.TextColor3             = Color3.fromRGB(230, 230, 240)
title.TextSize               = 13
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = panel

local speedValue = Instance.new("TextLabel")
speedValue.BackgroundTransparency = 1
speedValue.Position               = UDim2.new(1, -84, 0, 10)
speedValue.Size                   = UDim2.new(0, 68, 0, 16)
speedValue.Font                   = Enum.Font.GothamBold
speedValue.Text                   = tostring(speed)
speedValue.TextColor3             = Color3.fromRGB(34, 211, 238)
speedValue.TextSize               = 13
speedValue.TextXAlignment         = Enum.TextXAlignment.Right
speedValue.Parent                 = panel

local toggle = Instance.new("TextButton")
toggle.Position         = UDim2.new(0, 16, 0, 34)
toggle.Size             = UDim2.new(1, -32, 0, 44)
toggle.BackgroundColor3 = Color3.fromRGB(38, 38, 54)
toggle.Text             = "START"
toggle.TextColor3       = Color3.fromRGB(230, 230, 240)
toggle.Font             = Enum.Font.GothamBold
toggle.TextSize         = 16
toggle.BorderSizePixel  = 0
toggle.AutoButtonColor  = false
toggle.Parent           = panel

Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 10)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color        = Color3.fromRGB(120, 120, 150)
toggleStroke.Transparency = 0.75
toggleStroke.Thickness    = 1
toggleStroke.Parent       = toggle

local speedLabel = Instance.new("TextLabel")
speedLabel.BackgroundTransparency = 1
speedLabel.Position               = UDim2.new(0, 16, 0, 90)
speedLabel.Size                   = UDim2.new(0, 120, 0, 14)
speedLabel.Font                   = Enum.Font.GothamMedium
speedLabel.Text                   = "SPEED"
speedLabel.TextColor3             = Color3.fromRGB(140, 140, 160)
speedLabel.TextSize               = 11
speedLabel.TextXAlignment         = Enum.TextXAlignment.Left
speedLabel.Parent                 = panel

local slider = Instance.new("Frame")
slider.Name                   = "Slider"
slider.BackgroundTransparency = 1
slider.Position               = UDim2.new(0, 16, 0, 114)
slider.Size                   = UDim2.new(1, -32, 0, 20)
slider.Parent                 = panel

local trackBar = Instance.new("Frame")
trackBar.Name             = "Track"
trackBar.AnchorPoint      = Vector2.new(0, 0.5)
trackBar.Position         = UDim2.new(0, 0, 0.5, 0)
trackBar.Size             = UDim2.new(1, 0, 0, 6)
trackBar.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
trackBar.BorderSizePixel  = 0
trackBar.Parent           = slider

Instance.new("UICorner", trackBar).CornerRadius = UDim.new(1, 0)

local sliderInitScale = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)

local fill = Instance.new("Frame")
fill.Name             = "Fill"
fill.Size             = UDim2.new(sliderInitScale, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(34, 211, 238)
fill.BorderSizePixel  = 0
fill.Parent           = trackBar

Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local knob = Instance.new("Frame")
knob.Name             = "Knob"
knob.AnchorPoint      = Vector2.new(0.5, 0.5)
knob.Size             = UDim2.new(0, 14, 0, 14)
knob.Position         = UDim2.new(sliderInitScale, 0, 0.5, 0)
knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knob.BorderSizePixel  = 0
knob.Parent           = trackBar

Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

local knobStroke = Instance.new("UIStroke")
knobStroke.Color     = Color3.fromRGB(34, 211, 238)
knobStroke.Thickness = 2
knobStroke.Parent    = knob

local afkBtn = Instance.new("TextButton")
afkBtn.Name             = "AntiAfkBtn"
afkBtn.Position         = UDim2.new(0, 16, 0, 160)
afkBtn.Size             = UDim2.new(1, -32, 0, 36)
afkBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 54)
afkBtn.Text             = "ANTI-AFK: OFF"
afkBtn.TextColor3       = Color3.fromRGB(230, 230, 240)
afkBtn.Font             = Enum.Font.GothamBold
afkBtn.TextSize         = 13
afkBtn.BorderSizePixel  = 0
afkBtn.AutoButtonColor  = false
afkBtn.Parent           = panel

Instance.new("UICorner", afkBtn).CornerRadius = UDim.new(0, 8)

local afkStroke = Instance.new("UIStroke")
afkStroke.Color        = Color3.fromRGB(120, 120, 150)
afkStroke.Transparency = 0.75
afkStroke.Thickness    = 1
afkStroke.Parent       = afkBtn

-- ================= fade in =================
local fadeProps = {}
for _, obj in ipairs(gui:GetDescendants()) do
	local props = {}
	if obj:IsA("GuiObject") then
		props.BackgroundTransparency = obj.BackgroundTransparency
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		props.TextTransparency       = obj.TextTransparency
		props.TextStrokeTransparency = obj.TextStrokeTransparency
	end
	if obj:IsA("UIStroke") then
		props.Transparency = obj.Transparency
	end
	if next(props) then
		fadeProps[obj] = props
	end
end

local function fadeTo(alpha, duration)
	for obj, props in pairs(fadeProps) do
		if obj.Parent then
			local targetProps = {}
			for k, orig in pairs(props) do
				targetProps[k] = orig + (1 - orig) * alpha
			end
			TweenService:Create(
				obj,
				TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				targetProps
			):Play()
		end
	end
end

for obj, props in pairs(fadeProps) do
	for k, _ in pairs(props) do
		obj[k] = 1
	end
end

task.spawn(function()
	task.wait(0.05)
	fadeTo(0, 0.55)
end)

-- ================= panel drag =================
local dragging          = false
local dragTarget        = nil
local dragStartMouse    = nil
local dragStartFramePos = nil

local function isInteractive(obj)
	while obj and obj ~= panel do
		if obj:IsA("GuiButton") then return true end
		if obj.Name == "Slider" then return true end
		obj = obj.Parent
	end
	return false
end

track(panel.InputBegan:Connect(function(input)
	if stopped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		if not isInteractive(input.Target) then
			dragging          = true
			dragStartMouse    = Vector2.new(input.Position.X, input.Position.Y)
			local abs         = panel.AbsolutePosition
			dragStartFramePos = Vector2.new(abs.X, abs.Y)
		end
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if stopped then return end
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = Vector2.new(input.Position.X - dragStartMouse.X,
								  input.Position.Y - dragStartMouse.Y)
		dragTarget  = dragStartFramePos + delta
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

-- ================= slider =================
local sliderTargetScale  = sliderInitScale
local sliderCurrentScale = sliderInitScale
local sliderDragging     = false

local function handleSliderInput(input)
	local absTrack = trackBar.AbsolutePosition
	local size     = trackBar.AbsoluteSize
	if size.X <= 0 then return end
	local rel = (input.Position.X - absTrack.X) / size.X
	sliderTargetScale = math.clamp(rel, 0, 1)
end

track(slider.InputBegan:Connect(function(input)
	if stopped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = true
		handleSliderInput(input)
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if stopped then return end
	if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		handleSliderInput(input)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = false
	end
end))

track(RunService.RenderStepped:Connect(function(dt)
	if stopped then return end

	if dragTarget then
		local cx, cy = panel.Position.X.Offset, panel.Position.Y.Offset
		local vps    = workspace.CurrentCamera.ViewportSize
		local tx     = math.clamp(dragTarget.X, 0, vps.X - PANEL_W)
		local ty     = math.clamp(dragTarget.Y, 0, vps.Y - PANEL_H)
		local a      = math.min(dt * 20, 1)
		panel.Position = UDim2.new(0,
			cx + (tx - cx) * a, 0,
			cy + (ty - cy) * a)
	end

	local a = math.min(dt * 22, 1)
	sliderCurrentScale = sliderCurrentScale + (sliderTargetScale - sliderCurrentScale) * a
	if math.abs(sliderTargetScale - sliderCurrentScale) < 0.0003 then
		sliderCurrentScale = sliderTargetScale
	end
	knob.Position = UDim2.new(sliderCurrentScale, 0, 0.5, 0)
	fill.Size     = UDim2.new(sliderCurrentScale, 0, 1, 0)

	local newSpeed = math.floor(MIN_SPEED + sliderCurrentScale * (MAX_SPEED - MIN_SPEED) + 0.5)
	if newSpeed ~= speed then
		speed = newSpeed
		speedValue.Text = tostring(speed)
	end
end))

-- ================= start/stop toggle =================
local function setToggleState(isActive)
	active = isActive
	local bgColor     = isActive and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(38, 38, 54)
	local strokeColor = isActive and Color3.fromRGB(80, 230, 180) or Color3.fromRGB(120, 120, 150)
	local strokeTr    = isActive and 0.4 or 0.75

	TweenService:Create(toggle,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = bgColor }):Play()
	TweenService:Create(toggleStroke,
		TweenInfo.new(0.25),
		{ Color = strokeColor, Transparency = strokeTr }):Play()

	toggle.Text = isActive and "STOP" or "START"
	if isActive then
		task.spawn(flyLoop)
	end
end

track(toggle.MouseButton1Click:Connect(function()
	if stopped then return end
	setToggleState(not active)
end))

track(toggle.MouseEnter:Connect(function()
	if stopped or active then return end
	TweenService:Create(toggle, TweenInfo.new(0.15),
		{ BackgroundColor3 = Color3.fromRGB(52, 52, 72) }):Play()
end))

track(toggle.MouseLeave:Connect(function()
	if stopped or active then return end
	TweenService:Create(toggle, TweenInfo.new(0.15),
		{ BackgroundColor3 = Color3.fromRGB(38, 38, 54) }):Play()
end))

-- ================= anti-afk toggle =================
local function setAfkState(state)
	local bgColor     = state and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(38, 38, 54)
	local strokeColor = state and Color3.fromRGB(80, 230, 180) or Color3.fromRGB(120, 120, 150)
	local strokeTr    = state and 0.4 or 0.75

	TweenService:Create(afkBtn,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = bgColor }):Play()
	TweenService:Create(afkStroke,
		TweenInfo.new(0.25),
		{ Color = strokeColor, Transparency = strokeTr }):Play()

	afkBtn.Text = state and "ANTI-AFK: ON" or "ANTI-AFK: OFF"
	setAntiAfk(state)
end

track(afkBtn.MouseButton1Click:Connect(function()
	if stopped then return end
	setAfkState(not antiAfkEnabled)
end))

track(afkBtn.MouseEnter:Connect(function()
	if stopped or antiAfkEnabled then return end
	TweenService:Create(afkBtn, TweenInfo.new(0.15),
		{ BackgroundColor3 = Color3.fromRGB(52, 52, 72) }):Play()
end))

track(afkBtn.MouseLeave:Connect(function()
	if stopped or antiAfkEnabled then return end
	TweenService:Create(afkBtn, TweenInfo.new(0.15),
		{ BackgroundColor3 = Color3.fromRGB(38, 38, 54) }):Play()
end))

-- ================= shutdown =================
local function stop()
	if stopped then return end
	stopped        = true
	active         = false
	antiAfkEnabled = false

	fadeTo(1, 0.35)

	task.delay(0.4, function()
		for _, c in ipairs(connections) do
			if c and c.Connected then
				pcall(function() c:Disconnect() end)
			end
		end
		connections = {}

		if currentHumanoid and currentHumanoid.Parent then
			pcall(function() currentHumanoid.PlatformStand = false end)
		end
		if currentBF and currentBF.Parent then
			pcall(function() currentBF:Destroy() end)
		end
		if player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
			end
		end

		if gui and gui.Parent then
			pcall(function() gui:Destroy() end)
		end
	end)
end

_G.__FlightController = { stop = stop }

-- auto start
task.spawn(function()
	task.wait(0.35)
	if stopped then return end
	setToggleState(true)
end)
