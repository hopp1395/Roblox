local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local existingRemotes = ReplicatedStorage:FindFirstChild("RoadRampageRemotes")
if existingRemotes then
	existingRemotes:Destroy()
end

local existingWorld = workspace:FindFirstChild("RoadRampageWorld")
if existingWorld then
	existingWorld:Destroy()
end

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "RoadRampageRemotes"
remotesFolder.Parent = ReplicatedStorage

local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name = "InputChanged"
inputRemote.Parent = remotesFolder

local worldFolder = Instance.new("Folder")
worldFolder.Name = "RoadRampageWorld"
worldFolder.Parent = workspace

local lanesFolder = Instance.new("Folder")
lanesFolder.Name = "Lanes"
lanesFolder.Parent = worldFolder

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = worldFolder

local stagingPad = Instance.new("Part")
stagingPad.Name = "CharacterPad"
stagingPad.Anchored = true
stagingPad.CanCollide = true
stagingPad.Transparency = 1
stagingPad.Size = Vector3.new(128, 1, 128)
stagingPad.Position = Vector3.new(0, -40, 0)
stagingPad.Parent = worldFolder

local skyPlate = Instance.new("Part")
skyPlate.Name = "Backdrop"
skyPlate.Anchored = true
skyPlate.CanCollide = false
skyPlate.Material = Enum.Material.Grass
skyPlate.Color = Color3.fromRGB(79, 168, 74)
skyPlate.Size = Vector3.new(4096, 1, 8192)
skyPlate.Position = Vector3.new(0, GameConfig.WORLD_FLOOR_Y - 1, 2048)
skyPlate.Parent = worldFolder

local obstacleTemplates = {
	{
		name = "ConcreteWall",
		size = Vector3.new(12, 8, 3),
		color = Color3.fromRGB(132, 132, 138),
		material = Enum.Material.Concrete,
	},
	{
		name = "BrickWall",
		size = Vector3.new(14, 9, 3),
		color = Color3.fromRGB(150, 77, 62),
		material = Enum.Material.Brick,
	},
	{
		name = "RoadBarrier",
		size = Vector3.new(10, 7, 3),
		color = Color3.fromRGB(218, 118, 44),
		material = Enum.Material.Metal,
	},
}

local bonusTemplates = {
	{
		name = "Fuel",
		points = 3,
		color = Color3.fromRGB(220, 50, 50),
		size = Vector3.new(3, 5, 3),
		material = Enum.Material.Metal,
		label = "+3 Benzin",
	},
	{
		name = "Wrench",
		points = 5,
		color = Color3.fromRGB(180, 180, 60),
		size = Vector3.new(4, 2, 1),
		material = Enum.Material.Metal,
		label = "+5 Schlüssel",
	},
}

local lanes = {}
local playerStates = {}
local nextLaneIndex = 0
local nextObstacleId = 0
local nextBonusId = 0

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function formatTime(seconds)
	local mm = math.floor(seconds / 60)
	local ss = math.floor(seconds % 60)
	local mi = math.floor((seconds % 1) * 100)
	return string.format("%02d:%02d:%02d", mm, ss, mi)
end

local function createPart(properties)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(properties) do
		part[key] = value
	end

	return part
end

local function createSound(parent, name, soundId, volume, looped)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = looped
	sound.RollOffMaxDistance = 150
	sound.RollOffMinDistance = 15
	sound.Parent = parent
	return sound
end

local function hideCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	if rootPart then
		rootPart.CFrame = stagingPad.CFrame + Vector3.new(0, 5, 0)
	end
end

local function buildRoadSegment(lane, segmentIndex)
	local segmentLength = GameConfig.ROAD_SEGMENT_LENGTH
	local centerZ = segmentIndex * segmentLength + segmentLength * 0.5

	local road = createPart({
		Name = string.format("Road_%d", segmentIndex),
		Size = Vector3.new(GameConfig.ROAD_WIDTH, 1, segmentLength),
		Material = Enum.Material.Asphalt,
		Color = Color3.fromRGB(38, 38, 44),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y, centerZ),
		Parent = lane.folder,
	})

	local shoulderWidth = 4
	local shoulderOffset = GameConfig.ROAD_WIDTH * 0.5 + shoulderWidth * 0.5
	local shoulderColor = Color3.fromRGB(245, 218, 75)

	for _, direction in ipairs({ -1, 1 }) do
		createPart({
			Name = string.format("Shoulder_%d_%d", segmentIndex, direction),
			Size = Vector3.new(shoulderWidth, 1.05, segmentLength),
			Material = Enum.Material.Neon,
			Color = shoulderColor,
			Position = Vector3.new(lane.xOffset + direction * shoulderOffset, GameConfig.WORLD_FLOOR_Y + 0.03, centerZ),
			Parent = lane.folder,
		})
	end

	local dashLength = 18
	local dashGap = 18
	local dashCount = math.floor(segmentLength / (dashLength + dashGap))
	local startZ = centerZ - segmentLength * 0.5 + 22

	for dashIndex = 0, dashCount do
		createPart({
			Name = string.format("Dash_%d_%d", segmentIndex, dashIndex),
			Size = Vector3.new(1, 1.08, dashLength),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 255, 255),
			Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.05, startZ + dashIndex * (dashLength + dashGap)),
			Parent = lane.folder,
		})
	end

	road.Parent = lane.folder
end

local function createCheckpointLine(lane, name, lineZ, color, text)
	local checkpointFolder = Instance.new("Folder")
	checkpointFolder.Name = name
	checkpointFolder.Parent = lane.folder

	local isFinishLine = name == "FinishLine"

	local line = createPart({
		Name = name .. "_Line",
		Size = Vector3.new(GameConfig.ROAD_WIDTH, 1.15, 6),
		Material = isFinishLine and Enum.Material.SmoothPlastic or Enum.Material.Neon,
		Color = color,
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.08, lineZ),
		Parent = checkpointFolder,
	})

	local postOffset = GameConfig.ROAD_WIDTH * 0.5 + 2
	for _, direction in ipairs({ -1, 1 }) do
		createPart({
			Name = string.format("%s_Post_%d", name, direction),
			Size = Vector3.new(2, isFinishLine and 24 or 14, 2),
			Material = isFinishLine and Enum.Material.Neon or Enum.Material.Metal,
			Color = isFinishLine and color or Color3.fromRGB(230, 230, 230),
			Position = Vector3.new(lane.xOffset + direction * postOffset, GameConfig.WORLD_FLOOR_Y + (isFinishLine and 12 or 7), lineZ),
			Parent = checkpointFolder,
		})
	end

	local banner = createPart({
		Name = name .. "_Banner",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 8, isFinishLine and 6 or 3, 1),
		Material = isFinishLine and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(25, 25, 25),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + (isFinishLine and 22 or 13), lineZ),
		Parent = checkpointFolder,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 24
	surfaceGui.Parent = banner

	local backSurfaceGui = Instance.new("SurfaceGui")
	backSurfaceGui.Face = Enum.NormalId.Back
	backSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	backSurfaceGui.PixelsPerStud = 24
	backSurfaceGui.Parent = banner

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = surfaceGui

	local backLabel = label:Clone()
	backLabel.Parent = backSurfaceGui

	if isFinishLine then
		lane.finishBannerLabels = { label, backLabel }
	end

	if isFinishLine then
		local stripeCount = 12
		local stripeWidth = GameConfig.ROAD_WIDTH / stripeCount

		for stripeIndex = 0, stripeCount - 1 do
			createPart({
				Name = string.format("%s_Stripe_%d", name, stripeIndex),
				Size = Vector3.new(stripeWidth, 1.2, 6),
				Material = Enum.Material.SmoothPlastic,
				Color = stripeIndex % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(35, 35, 35),
				Position = Vector3.new(
					lane.xOffset - GameConfig.ROAD_WIDTH * 0.5 + stripeWidth * 0.5 + stripeIndex * stripeWidth,
					GameConfig.WORLD_FLOOR_Y + 0.12,
					lineZ
				),
				Parent = checkpointFolder,
			})
		end

		createPart({
			Name = "FinishMarker",
			Size = Vector3.new(GameConfig.ROAD_WIDTH + 18, 1, 18),
			Material = Enum.Material.Neon,
			Color = color,
			Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.18, lineZ),
			Parent = checkpointFolder,
		})
	end

	line.Parent = checkpointFolder
end

local function setFinishBannerText(lane, text)
	if not lane.finishBannerLabels then
		return
	end

	for _, label in ipairs(lane.finishBannerLabels) do
		if label and label.Parent then
			label.Text = text
		end
	end
end

local function updateCarAudio(state)
	local sounds = state.sounds
	if not sounds then
		return
	end

	local speedRatio = clamp(state.speed / GameConfig.MAX_SPEED, 0, 1)
	local steerAmount = math.abs(state.input.steer)
	local isDriving = state.speed > 0.5 and not state.crashed

	if sounds.engine and not sounds.engine.IsPlaying then
		sounds.engine:Play()
	end

	if sounds.engine then
		sounds.engine.Volume = 0.18 + speedRatio * 0.42
		sounds.engine.PlaybackSpeed = 0.8 + speedRatio * 0.8
	end

	if sounds.tire then
		local shouldSqueal = isDriving and steerAmount > 0.35 and state.speed > GameConfig.MIN_SPEED
		if shouldSqueal then
			if not sounds.tire.IsPlaying then
				sounds.tire:Play()
			end
			sounds.tire.Volume = clamp((speedRatio * 0.55) + (steerAmount * 0.35), 0.08, 0.65)
			sounds.tire.PlaybackSpeed = 0.9 + speedRatio * 0.5
		else
			sounds.tire.Volume = 0
			if sounds.tire.IsPlaying then
				sounds.tire:Stop()
			end
		end
	end
end

local function createRoadEndBarrier(lane)
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "RoadEnd"
	barrierFolder.Parent = lane.folder

	createPart({
		Name = "Barrier",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 8, 10, 3),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 45, 45),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 5, GameConfig.TRACK_END_Z + 1.5),
		Parent = barrierFolder,
	})

	createPart({
		Name = "BarrierTop",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 10, 1, 4),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 235, 85),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 10.5, GameConfig.TRACK_END_Z + 1.5),
		Parent = barrierFolder,
	})
end

local function ensureRoadAhead(lane, carZ)
	local maxSegment = math.ceil(GameConfig.TRACK_END_Z / GameConfig.ROAD_SEGMENT_LENGTH) - 1
	local targetSegment = math.floor((carZ + GameConfig.ROAD_LOOKAHEAD) / GameConfig.ROAD_SEGMENT_LENGTH)
	targetSegment = math.min(targetSegment, maxSegment)

	while lane.lastSegmentIndex < targetSegment do
		lane.lastSegmentIndex += 1
		buildRoadSegment(lane, lane.lastSegmentIndex)
	end
end

local function createObstaclePart(lane, obstacleZ)
	nextObstacleId += 1

	local template = obstacleTemplates[math.random(1, #obstacleTemplates)]
	local usableHalfWidth = GameConfig.ROAD_WIDTH * 0.5 - GameConfig.OBSTACLE_SIDE_MARGIN
	local localX = math.random(-usableHalfWidth * 10, usableHalfWidth * 10) / 10
	local part = Instance.new("Part")
	part.Name = string.format("%s_%d", template.name, nextObstacleId)
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = template.size
	part.Color = template.color
	part.Material = template.material
	part.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5,
		obstacleZ
	)

	part.Parent = lane.obstaclesFolder

	local obstacle = {
		id = nextObstacleId,
		lane = lane,
		localX = localX,
		worldX = lane.xOffset + localX,
		z = obstacleZ,
		part = part,
		halfWidth = template.size.X * 0.5,
		halfLength = template.size.Z * 0.5,
	}

	lane.obstacles[nextObstacleId] = obstacle
end

local function addPoint(state, amount)
	state.score += amount
	state.hits.Value = state.score
	state.body:SetAttribute("Score", state.score)
end

local function createBonusItem(lane, bonusZ)
	nextBonusId += 1

	local template = bonusTemplates[math.random(1, #bonusTemplates)]
	local usableHalfWidth = GameConfig.ROAD_WIDTH * 0.5 - GameConfig.OBSTACLE_SIDE_MARGIN - 2
	local localX = math.random(-usableHalfWidth * 10, usableHalfWidth * 10) / 10

	local model = Instance.new("Model")
	model.Name = string.format("%s_%d", template.name, nextBonusId)
	model:SetAttribute("IsBonus", true)
	model:SetAttribute("BonusId", nextBonusId)
	model.Parent = lane.bonusFolder

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Size = template.size
	body.Color = template.color
	body.Material = template.material
	body.Parent = model

	if template.name == "Fuel" then
		-- Kanister: roter Block + kleines Röhrchen oben
		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Anchored = true
		cap.CanCollide = false
		cap.Size = Vector3.new(1, 1.5, 1)
		cap.Color = Color3.fromRGB(40, 40, 40)
		cap.Material = Enum.Material.Metal
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth
		cap.Parent = model
		cap.CFrame = CFrame.new(
			lane.xOffset + localX,
			GameConfig.WORLD_FLOOR_Y + template.size.Y + 0.75,
			bonusZ
		)
	elseif template.name == "Wrench" then
		-- Schraubenschlüssel: flacher gelber Balken + zwei Enden
		local head1 = Instance.new("Part")
		head1.Name = "Head1"
		head1.Anchored = true
		head1.CanCollide = false
		head1.Size = Vector3.new(2.5, 2.5, 1)
		head1.Color = template.color
		head1.Material = Enum.Material.Metal
		head1.TopSurface = Enum.SurfaceType.Smooth
		head1.BottomSurface = Enum.SurfaceType.Smooth
		head1.Parent = model
		head1.CFrame = CFrame.new(
			lane.xOffset + localX + 2.8,
			GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
			bonusZ
		)

		local head2 = head1:Clone()
		head2.Name = "Head2"
		head2.CFrame = CFrame.new(
			lane.xOffset + localX - 2.8,
			GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
			bonusZ
		)
		head2.Parent = model
	end

	-- leuchtendes Neon-Glow-Ring unter dem Item
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = Vector3.new(template.size.X + 3, 0.3, template.size.X + 3)
	glow.Shape = Enum.PartType.Cylinder
	glow.Color = template.color
	glow.Material = Enum.Material.Neon
	glow.TopSurface = Enum.SurfaceType.Smooth
	glow.BottomSurface = Enum.SurfaceType.Smooth
	glow.Parent = model
	glow.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + 0.2,
		bonusZ
	) * CFrame.Angles(0, 0, math.rad(90))

	body.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
		bonusZ
	)

	model.PrimaryPart = body

	local bonus = {
		id = nextBonusId,
		lane = lane,
		worldX = lane.xOffset + localX,
		z = bonusZ,
		model = model,
		body = body,
		halfWidth = (template.size.X + 3) * 0.5,
		halfLength = (template.size.Z + 3) * 0.5,
		points = template.points,
		label = template.label,
	}

	lane.bonusItems[nextBonusId] = bonus
end

local function destroyBonus(lane, bonusId)
	local bonus = lane.bonusItems[bonusId]
	if not bonus then return end
	if bonus.model then bonus.model:Destroy() end
	lane.bonusItems[bonusId] = nil
end

local function ensureObstaclesAhead(lane, carZ)
	local obstacleLimit = math.min(carZ + GameConfig.OBSTACLE_LOOKAHEAD, GameConfig.FINISH_LINE_Z - GameConfig.FINISH_OBSTACLE_BUFFER)

	while lane.nextObstacleZ < obstacleLimit do
		local spacing = math.random(GameConfig.OBSTACLE_SPACING_MIN, GameConfig.OBSTACLE_SPACING_MAX)
		lane.nextObstacleZ += spacing
		createObstaclePart(lane, lane.nextObstacleZ)
	end
end

local function ensureBonusAhead(lane, carZ)
	local bonusLimit = math.min(carZ + GameConfig.OBSTACLE_LOOKAHEAD, GameConfig.FINISH_LINE_Z - GameConfig.FINISH_OBSTACLE_BUFFER)

	while lane.nextBonusZ < bonusLimit do
		local spacing = math.random(GameConfig.BONUS_SPACING_MIN, GameConfig.BONUS_SPACING_MAX)
		lane.nextBonusZ += spacing
		createBonusItem(lane, lane.nextBonusZ)
	end
end

local function ensureLane(laneIndex)
	if lanes[laneIndex] then
		return lanes[laneIndex]
	end

	local xOffset = (laneIndex - 1) * GameConfig.LANE_SPACING
	local laneFolder = Instance.new("Folder")
	laneFolder.Name = string.format("Lane_%d", laneIndex)
	laneFolder.Parent = lanesFolder

	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = laneFolder

	local bonusFolder = Instance.new("Folder")
	bonusFolder.Name = "Bonus"
	bonusFolder.Parent = laneFolder

	local lane = {
		index = laneIndex,
		xOffset = xOffset,
		folder = laneFolder,
		obstaclesFolder = obstaclesFolder,
		bonusFolder = bonusFolder,
		obstacles = {},
		bonusItems = {},
		nextObstacleZ = GameConfig.OBSTACLE_START_Z,
		nextBonusZ = GameConfig.BONUS_START_Z,
		lastSegmentIndex = -1,
		finishBannerLabels = nil,
	}

	lanes[laneIndex] = lane

	createCheckpointLine(lane, "StartLine", GameConfig.START_LINE_Z, Color3.fromRGB(77, 255, 125), "START")
	createCheckpointLine(lane, "FinishLine", GameConfig.FINISH_LINE_Z, Color3.fromRGB(255, 92, 92), "ZIEL")
	createRoadEndBarrier(lane)
	buildRoadSegment(lane, -1)
	lane.lastSegmentIndex = -1
	ensureRoadAhead(lane, 0)
	ensureObstaclesAhead(lane, 0)
	ensureBonusAhead(lane, 0)

	return lane
end

local function createCar(player, lane)
	local model = Instance.new("Model")
	model.Name = string.format("%s_Car", player.Name)
	model:SetAttribute("OwnerUserId", player.UserId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Size = Vector3.new(8, 2, 12)
	body.Color = Color3.fromRGB(225, 74, 57)
	body.Material = Enum.Material.SmoothPlastic
	body:SetAttribute("OwnerUserId", player.UserId)
	body.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Anchored = true
	cabin.CanCollide = false
	cabin.TopSurface = Enum.SurfaceType.Smooth
	cabin.BottomSurface = Enum.SurfaceType.Smooth
	cabin.Size = Vector3.new(6, 2.5, 5)
	cabin.Color = Color3.fromRGB(199, 235, 255)
	cabin.Material = Enum.Material.Glass
	cabin.Parent = model

	local bumper = Instance.new("Part")
	bumper.Name = "Bumper"
	bumper.Anchored = true
	bumper.CanCollide = false
	bumper.TopSurface = Enum.SurfaceType.Smooth
	bumper.BottomSurface = Enum.SurfaceType.Smooth
	bumper.Size = Vector3.new(8.4, 1, 1)
	bumper.Color = Color3.fromRGB(240, 240, 240)
	bumper.Material = Enum.Material.Metal
	bumper.Parent = model

	local engineSound = createSound(body, "EngineLoop", GameConfig.ENGINE_SOUND_ID, 0.25, true)
	engineSound.PlaybackSpeed = 1
	engineSound:Play()

	local tireSound = createSound(body, "TireSqueal", GameConfig.TIRE_SQUEAL_SOUND_ID, 0, true)
	tireSound.PlaybackSpeed = 1

	local crashSound = createSound(body, "CrashImpact", GameConfig.CRASH_SOUND_ID, 1, false)

	local wheelOffsets = {
		Vector3.new(-3.6, -1.1, -4.1),
		Vector3.new(3.6, -1.1, -4.1),
		Vector3.new(-3.6, -1.1, 4.1),
		Vector3.new(3.6, -1.1, 4.1),
	}

	for index, offset in ipairs(wheelOffsets) do
		local wheel = Instance.new("Part")
		wheel.Name = string.format("Wheel_%d", index)
		wheel.Anchored = true
		wheel.CanCollide = false
		wheel.TopSurface = Enum.SurfaceType.Smooth
		wheel.BottomSurface = Enum.SurfaceType.Smooth
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(2, 2.8, 2.8)
		wheel.Color = Color3.fromRGB(22, 22, 22)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.Parent = model
		wheel:SetAttribute("OffsetX", offset.X)
		wheel:SetAttribute("OffsetY", offset.Y)
		wheel:SetAttribute("OffsetZ", offset.Z)
	end

	model.PrimaryPart = body
	model.Parent = carsFolder

	local function positionCar(localX, z, steerAngle)
		local baseCFrame = CFrame.new(
			lane.xOffset + localX,
			GameConfig.WORLD_FLOOR_Y + GameConfig.CAR_HEIGHT,
			z
		) * CFrame.Angles(0, math.pi + math.rad(steerAngle), 0)

		body.CFrame = baseCFrame
		cabin.CFrame = baseCFrame * CFrame.new(0, 2.1, 0.5)
		bumper.CFrame = baseCFrame * CFrame.new(0, -0.4, -6.2)

		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Part") and child.Name:match("^Wheel_") then
				local offset = Vector3.new(
					child:GetAttribute("OffsetX"),
					child:GetAttribute("OffsetY"),
					child:GetAttribute("OffsetZ")
				)
				child.CFrame = baseCFrame
					* CFrame.new(offset)
					* CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end

	positionCar(0, 0, 0)
	body:SetAttribute("Speed", GameConfig.START_SPEED)
	body:SetAttribute("Score", 0)
	body:SetAttribute("GameTitle", GameConfig.GAME_NAME)
	body:SetAttribute("GameState", "Running")
	body:SetAttribute("StatusText", "Weiche den Hindernissen aus")

	return model, positionCar, {
		engine = engineSound,
		tire = tireSound,
		crash = crashSound,
	}
end

local function createLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local hits = Instance.new("IntValue")
	hits.Name = "Points"
	hits.Value = 0
	hits.Parent = leaderstats

	return hits
end

local function registerPlayer(player)
	nextLaneIndex += 1
	local lane = ensureLane(nextLaneIndex)
	local hits = createLeaderstats(player)
	local carModel, positionCar, sounds = createCar(player, lane)

	playerStates[player] = {
		player = player,
		lane = lane,
		car = carModel,
		body = carModel.PrimaryPart,
		positionCar = positionCar,
		localX = 0,
		z = 0,
		speed = GameConfig.START_SPEED,
		score = 0,
		hits = hits,
		sounds = sounds,
		finished = false,
		startTime = tick(),
		elapsedTime = 0,
		input = {
			throttle = 0,
			steer = 0,
		},
	}
end

local function cleanupPlayer(player)
	local state = playerStates[player]
	if not state then
		return
	end

	if state.car then
		state.car:Destroy()
	end

	playerStates[player] = nil
end

local function destroyObstacle(lane, obstacleId)
	local obstacle = lane.obstacles[obstacleId]
	if not obstacle then
		return
	end

	if obstacle.part then
		obstacle.part:Destroy()
	end

	lane.obstacles[obstacleId] = nil
end

local function crashPlayer(state, obstacle)
	state.crashed = true
	state.speed = 0
	state.input.throttle = 0
	state.input.steer = 0
	state.elapsedTime = tick() - state.startTime

	local crashStopZ = math.max(0, obstacle.z - (GameConfig.CAR_HALF_LENGTH + obstacle.halfLength * 0.5))
	state.z = math.min(state.z, crashStopZ)
	state.positionCar(state.localX, state.z, 0)
	state.body.Color = Color3.fromRGB(90, 25, 20)
	state.body.Material = Enum.Material.Metal
	state.body:SetAttribute("Speed", 0)
	state.body:SetAttribute("ElapsedTime", state.elapsedTime)
	state.body:SetAttribute("GameState", "Crashed")
	state.body:SetAttribute("StatusText", string.format("Crash! Zeit: %s | Punkte: %d", formatTime(state.elapsedTime), state.score))

	if state.sounds then
		if state.sounds.engine and state.sounds.engine.IsPlaying then
			state.sounds.engine:Stop()
		end
		if state.sounds.tire and state.sounds.tire.IsPlaying then
			state.sounds.tire:Stop()
		end
		if state.sounds.crash then
			state.sounds.crash:Play()
		end
	end

	if obstacle.part then
		local explosion = Instance.new("Explosion")
		explosion.Position = obstacle.part.Position
		explosion.BlastPressure = 0
		explosion.BlastRadius = 8
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = workspace
	end
end

local function updatePlayerState(state, dt)
	if state.crashed then
		state.speed = 0
		state.body:SetAttribute("Speed", 0)
		state.positionCar(state.localX, state.z, 0)
		return
	end

	if state.finished then
		state.speed = 0
		state.body:SetAttribute("Speed", 0)
		state.body:SetAttribute("ElapsedTime", state.elapsedTime)
		state.body:SetAttribute("GameState", "Finished")
		state.body:SetAttribute("StatusText", string.format("Ziel! Zeit: %s | Punkte: %d", formatTime(state.elapsedTime), state.score))
		setFinishBannerText(state.lane, string.format("ZIEL %s", formatTime(state.elapsedTime)))
		if state.sounds then
			if state.sounds.engine then
				state.sounds.engine.Volume = 0.12
				state.sounds.engine.PlaybackSpeed = 0.85
			end
			if state.sounds.tire and state.sounds.tire.IsPlaying then
				state.sounds.tire:Stop()
			end
		end
		state.positionCar(state.localX, state.z, 0)
		return
	end

	state.elapsedTime = tick() - state.startTime
	state.body:SetAttribute("ElapsedTime", state.elapsedTime)

	local throttle = state.input.throttle
	local steer = state.input.steer

	if throttle > 0 then
		state.speed = math.min(GameConfig.MAX_SPEED, state.speed + GameConfig.ACCELERATION * throttle * dt)
	elseif throttle < 0 then
		state.speed = math.max(GameConfig.MIN_SPEED, state.speed - GameConfig.BRAKE_STRENGTH * math.abs(throttle) * dt)
	else
		state.speed = math.max(GameConfig.MIN_SPEED, state.speed - GameConfig.DRAG * dt)
	end

	state.localX = clamp(
		state.localX - steer * GameConfig.STEER_SPEED * dt,
		-(GameConfig.ROAD_WIDTH * 0.5 - GameConfig.CAR_HALF_WIDTH),
		GameConfig.ROAD_WIDTH * 0.5 - GameConfig.CAR_HALF_WIDTH
	)

	local nextZ = state.z + state.speed * dt
	if nextZ >= GameConfig.FINISH_LINE_Z then
		nextZ = GameConfig.FINISH_LINE_Z
		state.elapsedTime = tick() - state.startTime
		state.body:SetAttribute("ElapsedTime", state.elapsedTime)
		state.finished = true
		state.speed = 0
		setFinishBannerText(state.lane, string.format("ZIEL %s", formatTime(state.elapsedTime)))
	end

	state.z = nextZ

	local steerAngle = steer * GameConfig.MAX_STEER_ANGLE
	state.positionCar(state.localX, state.z, steerAngle)
	state.body:SetAttribute("Speed", math.floor(state.speed + 0.5))
	state.body:SetAttribute("Score", state.score)
	updateCarAudio(state)

	ensureRoadAhead(state.lane, state.z)
	ensureObstaclesAhead(state.lane, state.z)
	ensureBonusAhead(state.lane, state.z)

	for obstacleId, obstacle in pairs(state.lane.obstacles) do
		if obstacle.z < state.z - GameConfig.OBSTACLE_CULL_DISTANCE then
			addPoint(state, 1)
			destroyObstacle(state.lane, obstacleId)
		else
			local dx = math.abs((state.lane.xOffset + state.localX) - obstacle.worldX)
			local dz = math.abs(state.z - obstacle.z)
			local hitWidth = GameConfig.CAR_HALF_WIDTH + obstacle.halfWidth * 0.75
			local hitLength = GameConfig.CAR_HALF_LENGTH + obstacle.halfLength * 0.75

			if dx <= hitWidth and dz <= hitLength then
				crashPlayer(state, obstacle)
				return
			end
		end
	end

	for bonusId, bonus in pairs(state.lane.bonusItems) do
		if bonus.z < state.z - GameConfig.OBSTACLE_CULL_DISTANCE then
			destroyBonus(state.lane, bonusId)
		else
			local dx = math.abs((state.lane.xOffset + state.localX) - bonus.worldX)
			local dz = math.abs(state.z - bonus.z)

			if dx <= bonus.halfWidth and dz <= bonus.halfLength then
				addPoint(state, bonus.points)
				state.body:SetAttribute("StatusText", string.format("%s gesammelt!", bonus.label))
				task.delay(1.5, function()
					if not state.crashed and not state.finished then
						state.body:SetAttribute("StatusText", "Weiche den Hindernissen aus")
					end
				end)
				destroyBonus(state.lane, bonusId)
			end
		end
	end
end

inputRemote.OnServerEvent:Connect(function(player, payload)
	local state = playerStates[player]
	if not state or type(payload) ~= "table" then
		return
	end

	local throttle = tonumber(payload.throttle) or 0
	local steer = tonumber(payload.steer) or 0

	state.input.throttle = clamp(throttle, -1, 1)
	state.input.steer = clamp(steer, -1, 1)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(hideCharacter)
	if player.Character then
		hideCharacter(player.Character)
	end

	registerPlayer(player)
end)

Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		if player.Character then
			hideCharacter(player.Character)
		end

		player.CharacterAdded:Connect(hideCharacter)
		registerPlayer(player)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, state in pairs(playerStates) do
		updatePlayerState(state, dt)
	end
end)
