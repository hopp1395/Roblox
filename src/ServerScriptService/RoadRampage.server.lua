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
		name = "Crate",
		size = Vector3.new(6, 6, 6),
		color = Color3.fromRGB(173, 117, 62),
		material = Enum.Material.WoodPlanks,
		shape = Enum.PartType.Block,
	},
	{
		name = "Barrel",
		size = Vector3.new(5, 7, 5),
		color = Color3.fromRGB(185, 63, 48),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, 90),
	},
	{
		name = "BalloonBox",
		size = Vector3.new(5, 5, 5),
		color = Color3.fromRGB(255, 196, 61),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
	},
}

local lanes = {}
local playerStates = {}
local nextLaneIndex = 0
local nextObstacleId = 0

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
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
	part.Shape = template.shape
	part.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5,
		obstacleZ
	)

	if template.rotation then
		part.CFrame *= CFrame.Angles(
			math.rad(template.rotation.X),
			math.rad(template.rotation.Y),
			math.rad(template.rotation.Z)
		)
	end

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

local function ensureObstaclesAhead(lane, carZ)
	local obstacleLimit = math.min(carZ + GameConfig.OBSTACLE_LOOKAHEAD, GameConfig.FINISH_LINE_Z - GameConfig.FINISH_OBSTACLE_BUFFER)

	while lane.nextObstacleZ < obstacleLimit do
		local spacing = math.random(GameConfig.OBSTACLE_SPACING_MIN, GameConfig.OBSTACLE_SPACING_MAX)
		lane.nextObstacleZ += spacing
		createObstaclePart(lane, lane.nextObstacleZ)
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

	local lane = {
		index = laneIndex,
		xOffset = xOffset,
		folder = laneFolder,
		obstaclesFolder = obstaclesFolder,
		obstacles = {},
		nextObstacleZ = GameConfig.OBSTACLE_START_Z,
		lastSegmentIndex = -1,
	}

	lanes[laneIndex] = lane

	createCheckpointLine(lane, "StartLine", GameConfig.START_LINE_Z, Color3.fromRGB(77, 255, 125), "START")
	createCheckpointLine(lane, "FinishLine", GameConfig.FINISH_LINE_Z, Color3.fromRGB(255, 92, 92), "ZIEL")
	createRoadEndBarrier(lane)
	buildRoadSegment(lane, -1)
	lane.lastSegmentIndex = -1
	ensureRoadAhead(lane, 0)
	ensureObstaclesAhead(lane, 0)

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

	return model, positionCar
end

local function createLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local hits = Instance.new("IntValue")
	hits.Name = "Hits"
	hits.Value = 0
	hits.Parent = leaderstats

	return hits
end

local function registerPlayer(player)
	nextLaneIndex += 1
	local lane = ensureLane(nextLaneIndex)
	local hits = createLeaderstats(player)
	local carModel, positionCar = createCar(player, lane)

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
		finished = false,
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

local function updatePlayerState(state, dt)
	if state.finished then
		state.speed = 0
		state.body:SetAttribute("Speed", 0)
		state.positionCar(state.localX, state.z, 0)
		return
	end

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
		state.finished = true
		state.speed = 0
	end

	state.z = nextZ

	local steerAngle = steer * GameConfig.MAX_STEER_ANGLE
	state.positionCar(state.localX, state.z, steerAngle)
	state.body:SetAttribute("Speed", math.floor(state.speed + 0.5))
	state.body:SetAttribute("Score", state.score)

	ensureRoadAhead(state.lane, state.z)
	ensureObstaclesAhead(state.lane, state.z)

	for obstacleId, obstacle in pairs(state.lane.obstacles) do
		if obstacle.z < state.z - GameConfig.OBSTACLE_CULL_DISTANCE then
			destroyObstacle(state.lane, obstacleId)
		else
			local dx = math.abs((state.lane.xOffset + state.localX) - obstacle.worldX)
			local dz = math.abs(state.z - obstacle.z)
			local hitWidth = GameConfig.CAR_HALF_WIDTH + obstacle.halfWidth * 0.75
			local hitLength = GameConfig.CAR_HALF_LENGTH + obstacle.halfLength * 0.75

			if dx <= hitWidth and dz <= hitLength then
				state.score += 1
				state.hits.Value = state.score
				state.body:SetAttribute("Score", state.score)
				destroyObstacle(state.lane, obstacleId)
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
