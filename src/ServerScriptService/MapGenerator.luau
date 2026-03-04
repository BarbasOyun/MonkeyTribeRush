local ServerScriptService = game:GetService("ServerScriptService")
local Gears = require(ServerScriptService.Server.Gears)

local mapGenerator = {}
local buildings = {}

-- Stage
local weaponHitFolder = workspace.WeaponHit
local totalBuildings = 0
local buildingCount = 0

local maxStage = 1 -- TODO : Roll
local currentStage = 0
local eventsEnum = { SWARM = "SWARM" } -- TODO Add More Events
local maxEvents = 0
local currentEvent = 0
local stageEvents = {}

function mapGenerator.FindOverlappingNodes(nodesPos, nodesRadius, startPos, radius)
	local overlappingNodes = {}

	for i = 1, #nodesPos - 1, 1 do
		local distance = Gears.PointsDistance(startPos, nodesPos[i])
		local minDistance = radius + nodesRadius[i]

		if distance < minDistance then
			-- table.insert(overlappingNodes, distance)
			local node = {
				distance = distance,
				radius = radius,
				position = nodesPos[i],
			}

			overlappingNodes[#overlappingNodes + 1] = node
		end
	end

	return overlappingNodes
end

function mapGenerator.AdjustNodePos(startPos, overlappingNodes, radius)
	local adjustDirection = Vector2.new(0, 0)
	local adjustDistance = 0

	for i in overlappingNodes do
		local node = overlappingNodes[i]
		local distance = node.distance
		local min_distance = node.radius + radius

		if distance < min_distance then
			adjustDirection += startPos - node.position
			adjustDistance += min_distance - distance
		end
	end

	return startPos + Gears.NormalizeOrZero(adjustDirection) * adjustDistance
end

function mapGenerator.CreateNode(nodesPos, nodesRadius, nodePos)
	local adjustedPos = nodePos
	local radius = math.random(60, 120) -- TODO : Building Based

	local overlappingNodes = mapGenerator.FindOverlappingNodes(nodesPos, nodesRadius, adjustedPos, radius)
	local count = 0

	while count < 3 and #overlappingNodes > 0 do
		adjustedPos = mapGenerator.AdjustNodePos(adjustedPos, overlappingNodes, radius)
		overlappingNodes = mapGenerator.FindOverlappingNodes(nodesPos, nodesRadius, adjustedPos, radius)
		count += 1
	end

	return adjustedPos, radius
end

function mapGenerator.GenerateMapData(nodeNbr, stageRadiusSize)
	local nodesPos = {}
	local nodesRadius = {}

	for _ = 0, nodeNbr, 1 do
		local rngRadius = Gears.FloatRandom(0, stageRadiusSize)
		local rngProgress = Gears.FloatRandom(0, math.pi * 2)
		local nodePos = Gears.CirclePos(rngRadius, rngProgress)

		local adjustedPos, radius = mapGenerator.CreateNode(nodesPos, nodesRadius, nodePos)
		table.insert(nodesPos, adjustedPos)
		table.insert(nodesRadius, radius)
	end

	return nodesPos
end

function mapGenerator.GenerateMap(nodeNbr, stageRadiusSize)
	local nodesPos = mapGenerator.GenerateMapData(nodeNbr, stageRadiusSize)

	for i in nodesPos do
		local building = Instance.new("Part")
		building.Parent = workspace
		building.Position = nodesPos[i]
	end
end

function mapGenerator.IncrementBuilding()
	buildingCount += 1
	local stageProgress = buildingCount / totalBuildings
	-- print("Current Stage Progress : " .. stageProgress)

	-- Check Stage Events
	if currentEvent / maxEvents >= stageProgress then
		print("Trigger : " .. currentEvent)
		currentEvent += 1
		print(stageEvents[currentEvent])
	end

	if stageProgress >= 0.9 then
		print("Stage Finished")
		currentStage += 1

		task.spawn(function()
			Gears.SaveData()
		end)

		if currentStage >= maxStage then
			print("Level Finished")
			-- Go Back to Hub
			return
		end

		print("15 sec until New Stage")
	end
end

function mapGenerator.StartStage()
	mapGenerator.GenerateMap(5, 100)

	-- Stage Events
	maxEvents = math.random(2, 5)

	for i = 0, maxEvents do
		table.insert(stageEvents, eventsEnum.SWARM)
		-- print("Stage Event " .. i .. " : " .. eventsEnum.SWARM)
	end

	-- Calculate Max Building
	for _, object in ipairs(weaponHitFolder:GetDescendants()) do
		if object:IsA("BasePart") then
			-- This code runs for every part, even in sub-models
			-- print(object.Name)
			totalBuildings += 1
		end
	end
end

return mapGenerator
