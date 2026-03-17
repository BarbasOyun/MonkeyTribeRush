local ServerScriptService = game:GetService("ServerScriptService")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Gears = require(ServerScriptService.Server.Gears)
local PlayersStats = require(ServerScriptService.Server.PlayersStats)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)
-- local Events = ReplicatedStorage.Shared

-- Enemies
local ENEMY_FOLDER = workspace.WeaponHit.Enemies
local MAX_ENEMIES = 200

local enemies = {}
local moveToTasks = {}

local scaleSpeed = 1 -- How much stats does the Robots Get over time

-- Attack
-- TODO : Move Enemy stats in File
local ATTACK_RANGE = 4
-- local ATTACK_RANGE_SQ = ATTACK_RANGE ^ 2 -- 16
local ATTACK_COOLDOWN = 1 -- Seconds
local FRAME_CHECK_DELTA = 5 -- Frames between every Distance Check
local attackFrameCount = 1

local attackDmg = 1

local attacked = {}

local params = OverlapParams.new()
params.FilterDescendantsInstances = { ENEMY_FOLDER }
params.FilterType = Enum.RaycastFilterType.Include

local function CreatePlayerPath(enemyPos, playerPos)
	local path = PathfindingService:CreatePath()

	local success, errorMessage = pcall(function()
		path:ComputeAsync(enemyPos, playerPos)
	end)

	if success then
		return path
	else
		warn(errorMessage)
		return nil
	end
end

local function getNearestPlayer(enemyPosition)
	local closestPlayer = nil
	local shortestDistance = math.huge -- Start with infinity

	for _, player in ipairs(Players:GetPlayers()) do
		if PlayersStats[player.UserId].pickingAugment then
			return nil
		end

		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local enemyPlayerVector = (character.HumanoidRootPart.Position - enemyPosition)
			local distance = enemyPlayerVector:Dot(enemyPlayerVector)

			if distance < shortestDistance then
				shortestDistance = distance
				closestPlayer = character
			end
		end
	end

	return closestPlayer
end

-- Pathfinding
local function RunAtPlayer()
	for _, enemy in ipairs(enemies) do
		if not enemy then
			return
		end

		local humanoid = enemy.Humanoid -- enemiesHumanoids[enemy]

		if not humanoid then
			return
		end

		local target = getNearestPlayer(enemy.HumanoidRootPart.Position)

		if target then
			local path = CreatePlayerPath(enemy.PrimaryPart.Position, target.PrimaryPart.Position)

			local t = task.spawn(function()
				for _, wayPoint in pairs(path:GetWaypoints()) do
					humanoid:MoveTo(wayPoint.Position)
					humanoid.MoveToFinished:Wait()
				end
			end)
			table.insert(moveToTasks, t)
		end
	end

	task.wait(1)

	for _, t in ipairs(moveToTasks) do
		task.cancel(t)
	end

	table.clear(moveToTasks)

	RunAtPlayer()
end

local function MoveToPlayer()
	for _, enemy in ipairs(enemies) do
		pcall(function()
			if not enemy then
				return
			end

			local humanoid = enemy.Humanoid

			if not humanoid then
				return
			end

			local target = getNearestPlayer(enemy.HumanoidRootPart.Position)

			if target then
				humanoid:MoveTo(target.PrimaryPart.Position)
			else
				humanoid:MoveTo(enemy.HumanoidRootPart.Position) -- Stop if no target found
			end
		end)
	end

	task.wait(1)
	MoveToPlayer()
end

local function SetupEnemy(enemy)
	table.insert(enemies, enemy)
	enemy.Parent = ENEMY_FOLDER

	enemy.Humanoid.Died:Connect(function()
		Gears.SpawnXP(enemy.PrimaryPart.Position)
		-- task.wait(2)
		enemy:Destroy()
	end)
end

local function StreamSpawn() -- Spawn Enemies constantly
	if #enemies >= MAX_ENEMIES then
		return
	end

	local spawnDelta = math.random(7, 10)
	task.wait(spawnDelta)

	for _, player in ipairs(Players:GetPlayers()) do
		local enemyNbr = math.random(1, 2)

		for _ = 1, enemyNbr, 1 do
			Gears.SpawnEnemyCircle(player.Character.PrimaryPart.Position)
		end

		StreamSpawn()
	end
end

local function SwarmSpawn() -- Spawn Big wave of Enemies
	if #enemies >= MAX_ENEMIES then
		return
	end

	local innerWaves = 5

	for _ = 0, innerWaves, 1 do
		for _, player in ipairs(Players:GetPlayers()) do
			local enemyNbr = math.random(5, 7)
			local radius = math.random(60, 120)
			local progress = Gears.FloatRandom(0, math.rad(360)) -- math.pi * 2
			local circlePos = Gears.CirclePos(radius, progress)
			local finalPos = player.Character.PrimaryPart.Position + Vector3.new(circlePos.X, 0, circlePos.Y)

			for _ = 1, enemyNbr, 1 do
				Gears.SpawnEnemy(finalPos)
			end
		end

		task.wait(1) -- Time Delta between Inner Waves
	end
end

-- Events Setup
ServerEvents.EnemySpawned.Event:Connect(function(enemy)
	-- print("Enemy Spawned : " .. enemy.Name)
	SetupEnemy(enemy)
end)

ServerEvents.SwarmEvent.Event:Connect(function()
	SwarmSpawn()
end)

ServerEvents.StageChanged.Event:Connect(function()
	table.clear(enemies)
end)

-- Do
-- Enemies Attacks
RunService.Heartbeat:Connect(function()
	if attackFrameCount < FRAME_CHECK_DELTA then
		attackFrameCount += 1
		return
	end

	attackFrameCount = 0

	-- Attack Cooldown
	for enemy, time in ipairs(attacked) do
		local attackDelta = tick() - time
		print("Attack Delta = " .. attackDelta)

		if attackDelta > ATTACK_COOLDOWN then
			table.remove(attacked, enemy)
		end
	end

	local humanoidsHit = {}

	-- Hit Detection
	-- Draw Sphere around each Players
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character then
			continue
		end

		local root = player.Character.HumanoidRootPart
		local hitEnemies = workspace:GetPartBoundsInRadius(root.Position, ATTACK_RANGE, params)

		for _, part in ipairs(hitEnemies) do
			local enemyModel = part.Parent

			if table.find(humanoidsHit, enemyModel) or attacked[enemyModel] then
				continue
			end

			table.insert(humanoidsHit, enemyModel)
			attacked[enemyModel] = tick()

			-- DMG
			enemyModel.Humanoid:MoveTo(enemyModel.HumanoidRootPart.Position) -- Stop
			player.Character.Humanoid:TakeDamage(attackDmg)
		end
	end
end)

task.spawn(function()
	StreamSpawn()
end)
--RunAtPlayer()
MoveToPlayer()
