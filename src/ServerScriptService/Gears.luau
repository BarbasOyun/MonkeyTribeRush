local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins")
local BananasData = DataStoreService:GetDataStore("Bananas")

local Gizmo = require(ReplicatedStorage.Shared.gizmo)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)

local gears = {}

local weaponHitFolder = workspace.WeaponHit
local totalBuildings = 0
local buildingCount = 0

-- Prefabs
local smallXpOrb = ReplicatedStorage.Prefabs.SmallXpOrb
local banana = ReplicatedStorage.Prefabs.Banana
local enemy = ReplicatedStorage.Prefabs.Robot

-- Stage
local maxStage = 1 -- TODO : Roll
local currentStage = 0
local eventsEnum = { SWARM = "SWARM" } -- TODO Add More Events
local maxEvents = 0
local currentEvent = 0
local stageEvents = {}

function gears.DisplayHitBox(cFrame, range, transparency)
	local drawSphere = RunService.Heartbeat:Connect(function()
		--print("Draw Sphere Gizmo")
		Gizmo.setColor("Bright red")
		Gizmo.setTransparency(transparency)
		Gizmo.drawSphere(cFrame, range)
		Gizmo.reset()
	end)

	task.delay(0.5, function()
		drawSphere:Disconnect()
	end)
end

function gears.DrawRay(startPos, endPos)
	Gizmo.drawRay(startPos, endPos)

	local drawRay = RunService.Heartbeat:Connect(function()
		Gizmo.setColor("Bright red")
		Gizmo.setTransparency(0.5)
		Gizmo.drawRay(startPos, endPos)
		Gizmo.reset()
	end)

	task.delay(0.5, function()
		drawRay:Disconnect()
	end)
end

function gears.FloatRandom(minNbr, maxNbr)
	return math.random(minNbr, maxNbr - 1) + math.random(1, 10) / 10
end

function gears.ParabolaPos(startPos, endPos, height, progress)
	local lerpPos = startPos + (endPos - startPos) * progress
	local y = startPos.Y + (height * 4 * progress * (1 - progress))
	return Vector3.new(lerpPos.X, y, lerpPos.Z)
end

function gears.CirclePos(radius, progress)
	-- progress = (progress + 0.01) % (math.pi * 2)
	local x = math.cos(progress) * radius
	local y = math.sin(progress) * radius
	return Vector2.new(x, y) -- Add to a position
end

function gears.SpherePos(latitude, longitude, radius)
	-- progress = (progress + 0.01) % (math.pi * 2)
	local x = math.sin(latitude) * math.cos(longitude) * radius
	local y = math.sin(latitude) * math.sin(longitude) * radius
	local z = math.cos(latitude) * radius
	return Vector3.new(x, y, z) -- Add to a position
end

function gears.LootMovement(item, startPos)
	item.Position = startPos
	item.Parent = workspace

	local targetPos = startPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	local finalTargetPos = targetPos
	local result = workspace:Raycast(targetPos, Vector3.new(0, -10, 0))

	if result then
		finalTargetPos = result.Position
	end

	local steps = 60
	local height = math.random(2, 5)

	for i = 1, steps do
		local progress = i / steps
		item.CFrame = CFrame.new(gears.ParabolaPos(startPos, finalTargetPos, height, progress))
		RunService.Heartbeat:Wait()
	end

	item.Parent = workspace.XP_Orbs -- Enable Pickup
end

function gears.SpawnXP(spawnPosition)
	-- print("Spawn XP Orb")
	local newOrb = smallXpOrb:Clone()

	gears.LootMovement(newOrb, spawnPosition)
end

function gears.SpawnBanana(spawnPosition)
	-- print("Spawn Banana")
	local newBanana = banana:Clone()

	gears.LootMovement(newBanana, spawnPosition)
end

function gears.SpawnEnemyCircle(basePosition)
	local radius = math.random(60, 120)
	local progress = math.random(0, math.pi * 2)
	local circlePos = gears.CirclePos(radius, progress)
	gears.SpawnEnemy(basePosition + Vector3.new(circlePos.X, 0, circlePos.Y))
end

function gears.SpawnEnemy(spawnPosition)
	local newEnemy = enemy:Clone()
	newEnemy.Parent = weaponHitFolder
	newEnemy.PrimaryPart.CFrame = CFrame.new(spawnPosition)
	ServerEvents.EnemySpawned:Fire(newEnemy)
end

function gears.StartStage()
	-- Generate Map

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

function gears.SaveData()
	-- Save Data : Kills, Destruction, Bananas -> use pcall
	-- Cap Data to max

	for _, player in ipairs(Players:GetPlayers()) do
		print("Save Data for : " .. player.Name)
		print(player.leaderstats)
		-- BananasData:IncrementAsync(player.UserId, 1)
	end
end

function gears.IncrementBuilding()
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
			gears.SaveData()
		end)

		if currentStage >= maxStage then
			print("Level Finished")
			-- Go Back to Hub
			return
		end

		print("15 sec until New Stage")
	end
end

function gears.sumTable(t)
	local total = 0
	for i = 1, #t do
		total += t[i]
	end
	return total
end

function gears.IncreaseToMultiplier(increaseValue)
	return 1 + increaseValue / 100
end

return gears
