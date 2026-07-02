local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("RoadRampageRemotes")
local inputRemote = remotes:WaitForChild("InputChanged")

local worldFolder = workspace:WaitForChild("RoadRampageWorld")
local carsFolder = worldFolder:WaitForChild("Cars")

local currentCarBody = nil
local hud = nil
local titleLabel = nil
local statusLabel = nil
local pointsLabel = nil
local speedLabel = nil
local progressLabel = nil
local progressFill = nil

local keyState = {
	forward = false,
	backward = false,
	left = false,
	right = false,
}

local lastPayload = {
	throttle = 99,
	steer = 99,
}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function buildHud()
	if hud then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoadRampageHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local statsPanel = Instance.new("Frame")
	statsPanel.Name = "StatsPanel"
	statsPanel.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	statsPanel.BackgroundTransparency = 0.18
	statsPanel.Position = UDim2.fromOffset(18, 18)
	statsPanel.Size = UDim2.fromOffset(360, 188)
	statsPanel.Parent = screenGui

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 18)
	statsCorner.Parent = statsPanel

	local statsStroke = Instance.new("UIStroke")
	statsStroke.Color = Color3.fromRGB(95, 205, 255)
	statsStroke.Transparency = 0.25
	statsStroke.Thickness = 1.5
	statsStroke.Parent = statsPanel

	local statsGradient = Instance.new("UIGradient")
	statsGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 36, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 22)),
	})
	statsGradient.Rotation = 90
	statsGradient.Parent = statsPanel

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(18, 14)
	titleLabel.Size = UDim2.fromOffset(260, 34)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = GameConfig.GAME_NAME
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 28
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = statsPanel

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(18, 48)
	subtitleLabel.Size = UDim2.fromOffset(300, 20)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = GameConfig.HUD_SUBTITLE
	subtitleLabel.TextColor3 = Color3.fromRGB(154, 201, 255)
	subtitleLabel.TextSize = 14
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = statsPanel

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(18, 78)
	statusLabel.Size = UDim2.fromOffset(324, 24)
	statusLabel.Font = Enum.Font.GothamSemibold
	statusLabel.Text = "Status: " .. GameConfig.STATUS_DEFAULT
	statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
	statusLabel.TextSize = 20
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = statsPanel

	pointsLabel = Instance.new("TextLabel")
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Position = UDim2.fromOffset(18, 112)
	pointsLabel.Size = UDim2.fromOffset(170, 24)
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.Text = "Punkte: 0"
	pointsLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
	pointsLabel.TextSize = 18
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.Parent = statsPanel

	speedLabel = Instance.new("TextLabel")
	speedLabel.BackgroundTransparency = 1
	speedLabel.Position = UDim2.fromOffset(188, 112)
	speedLabel.Size = UDim2.fromOffset(150, 24)
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.Text = "Tempo: 0"
	speedLabel.TextColor3 = Color3.fromRGB(223, 240, 255)
	speedLabel.TextSize = 18
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = statsPanel

	progressLabel = Instance.new("TextLabel")
	progressLabel.BackgroundTransparency = 1
	progressLabel.Position = UDim2.fromOffset(18, 144)
	progressLabel.Size = UDim2.fromOffset(220, 20)
	progressLabel.Font = Enum.Font.GothamMedium
	progressLabel.Text = "Strecke: 0%"
	progressLabel.TextColor3 = Color3.fromRGB(180, 225, 255)
	progressLabel.TextSize = 16
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = statsPanel

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.BackgroundColor3 = Color3.fromRGB(38, 44, 58)
	progressTrack.Position = UDim2.fromOffset(18, 168)
	progressTrack.Size = UDim2.fromOffset(324, 10)
	progressTrack.Parent = statsPanel

	local progressTrackCorner = Instance.new("UICorner")
	progressTrackCorner.CornerRadius = UDim.new(1, 0)
	progressTrackCorner.Parent = progressTrack

	progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.BackgroundColor3 = Color3.fromRGB(91, 232, 255)
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.Parent = progressTrack

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(1, 0)
	progressFillCorner.Parent = progressFill

	local progressGradient = Instance.new("UIGradient")
	progressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(82, 234, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 178, 81)),
	})
	progressGradient.Parent = progressFill

	local instructionsPanel = Instance.new("Frame")
	instructionsPanel.Name = "InstructionsPanel"
	instructionsPanel.BackgroundColor3 = Color3.fromRGB(17, 20, 27)
	instructionsPanel.BackgroundTransparency = 0.2
	instructionsPanel.Position = UDim2.new(1, -300, 0, 20)
	instructionsPanel.Size = UDim2.fromOffset(272, 116)
	instructionsPanel.Parent = screenGui

	local instructionsCorner = Instance.new("UICorner")
	instructionsCorner.CornerRadius = UDim.new(0, 18)
	instructionsCorner.Parent = instructionsPanel

	local instructionsStroke = Instance.new("UIStroke")
	instructionsStroke.Color = Color3.fromRGB(255, 174, 86)
	instructionsStroke.Transparency = 0.25
	instructionsStroke.Thickness = 1.5
	instructionsStroke.Parent = instructionsPanel

	local instructionsTitle = Instance.new("TextLabel")
	instructionsTitle.BackgroundTransparency = 1
	instructionsTitle.Position = UDim2.fromOffset(16, 14)
	instructionsTitle.Size = UDim2.fromOffset(220, 24)
	instructionsTitle.Font = Enum.Font.GothamBold
	instructionsTitle.Text = GameConfig.HUD_BRIEFING_TITLE
	instructionsTitle.TextColor3 = Color3.fromRGB(255, 228, 165)
	instructionsTitle.TextSize = 20
	instructionsTitle.TextXAlignment = Enum.TextXAlignment.Left
	instructionsTitle.Parent = instructionsPanel

	local instructions = Instance.new("TextLabel")
	instructions.BackgroundTransparency = 1
	instructions.Position = UDim2.fromOffset(16, 44)
	instructions.Size = UDim2.fromOffset(240, 58)
	instructions.Font = Enum.Font.Gotham
	instructions.Text = GameConfig.HUD_INSTRUCTIONS
	instructions.TextColor3 = Color3.fromRGB(230, 234, 241)
	instructions.TextSize = 16
	instructions.TextWrapped = true
	instructions.TextXAlignment = Enum.TextXAlignment.Left
	instructions.TextYAlignment = Enum.TextYAlignment.Top
	instructions.Parent = instructionsPanel

	hud = screenGui
end

local function updateHud()
	if not titleLabel or not statusLabel or not pointsLabel or not speedLabel or not progressLabel or not progressFill then
		return
	end

	if currentCarBody and currentCarBody.Parent then
		local title = currentCarBody:GetAttribute("GameTitle") or GameConfig.GAME_NAME
		local score = currentCarBody:GetAttribute("Score") or 0
		local speed = currentCarBody:GetAttribute("Speed") or 0
		local state = currentCarBody:GetAttribute("GameState") or "Running"
		local statusText = currentCarBody:GetAttribute("StatusText") or GameConfig.STATUS_DEFAULT
		local progress = clamp(currentCarBody:GetAttribute("Progress") or 0, 0, 1)
		titleLabel.Text = title
		pointsLabel.Text = string.format("Punkte: %d", score)
		speedLabel.Text = string.format("Tempo: %d", speed)
		progressLabel.Text = string.format("Strecke: %d%%", math.floor(progress * 100 + 0.5))
		progressFill.Size = UDim2.fromScale(progress, 1)

		if state == "Crashed" then
			statusLabel.Text = "Status: " .. statusText
			statusLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
		elseif state == "Finished" then
			statusLabel.Text = "Status: " .. statusText
			statusLabel.TextColor3 = Color3.fromRGB(122, 255, 145)
		else
			statusLabel.Text = "Status: " .. statusText
			statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
		end
	else
		titleLabel.Text = GameConfig.GAME_NAME
		statusLabel.Text = "Status: " .. GameConfig.STATUS_WAITING
		statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
		pointsLabel.Text = "Punkte: 0"
		speedLabel.Text = "Tempo: 0"
		progressLabel.Text = "Strecke: 0%"
		progressFill.Size = UDim2.fromScale(0, 1)
	end
end

local function setCurrentCarBody(body)
	currentCarBody = body

	if currentCarBody then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function refreshCurrentCar()
	for _, candidate in ipairs(carsFolder:GetChildren()) do
		if candidate:IsA("Model") then
			local modelOwnerUserId = candidate:GetAttribute("OwnerUserId")
			local body = candidate.PrimaryPart or candidate:FindFirstChild("Body")
			local bodyOwnerUserId = body and body:GetAttribute("OwnerUserId")

			if (modelOwnerUserId == player.UserId or bodyOwnerUserId == player.UserId) and body and body:IsA("BasePart") then
				setCurrentCarBody(body)
				return
			end
		end
	end

	setCurrentCarBody(nil)
end

local function sendInput()
	local payload = {
		throttle = (keyState.forward and 1 or 0) + (keyState.backward and -1 or 0),
		steer = (keyState.right and 1 or 0) + (keyState.left and -1 or 0),
	}

	if payload.throttle == lastPayload.throttle and payload.steer == lastPayload.steer then
		return
	end

	lastPayload = payload
	inputRemote:FireServer(payload)
end

local function updateKeyState(input, isPressed)
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
		keyState.forward = isPressed
	elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
		keyState.backward = isPressed
	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		keyState.left = isPressed
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		keyState.right = isPressed
	else
		return
	end

	sendInput()
end

buildHud()
refreshCurrentCar()

carsFolder.ChildAdded:Connect(function()
	task.defer(refreshCurrentCar)
end)

carsFolder.ChildRemoved:Connect(function()
	task.defer(refreshCurrentCar)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	updateKeyState(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
	updateKeyState(input, false)
end)

RunService.RenderStepped:Connect(function()
	if not currentCarBody or not currentCarBody.Parent then
		refreshCurrentCar()
	end

	if currentCarBody and currentCarBody.Parent then
		local carCFrame = currentCarBody.CFrame
		local cameraOffset = carCFrame:ToWorldSpace(CFrame.new(0, 10, 24)).Position
		local focusPoint = carCFrame.Position + carCFrame.LookVector * 20 + Vector3.new(0, 3, 0)
		camera.CFrame = CFrame.lookAt(cameraOffset, focusPoint)
	end

	updateHud()
end)
