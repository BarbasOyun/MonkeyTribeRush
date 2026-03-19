local ServerScriptService = game:GetService("ServerScriptService")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Gears = require(ServerScriptService.Server.Gears)
local PlayersStats = require(ServerScriptService.Server.PlayersStats)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)
-- local Events = ReplicatedStorage.Shared

-- Enemies Spawn
local streamSpawnDeltaTime = 8
local streamSpawnDeltaTimeRange = 2
local streamSpawnNbr = 1
local streamSpawnNbrRange = 1

local swarmWaves = 4
local swarmNbr = 4
local swarmNbrRange = 2

-- Enemies
local ENEMY_FOLDER = workspace.WeaponHit.Enemies
local MAX_ENEMIES = 200

local enemies = {}
local moveToTasks = {}

-- Scaling
-- local globalEnemiesLevel = 1
local enemyDeathCount = 0
local HP_INCREMENT = 1
local ATTACK_DAMAGE_INCREMENT = 0.1
local MOVEMENT_SPEED_INCREMENT = 0.1

-- TODO : Move Enemy stats in File
-- UTILS
local MOVEMENT_SPEED_CAP = 16
local movementSpeed = 8

-- DEFENSE
local hp = 50

-- OFFENSE
local FRAME_CHECK_DELTA = 5 -- Frames between every Distance Check
local ATTACK_RANGE = 4
local ATTACK_COOLDOWN = 1 -- Seconds

local attackFrameCount = 0
local attackDmg = 1
local attackCooldowns = {}

local params = OverlapParams.new()
params.FilterDescendantsInstances = { ENEMY_FOLDER }
params.FilterType = Enum.RaycastFilterType.Include

-- Utils

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

local function ApplyStats(enemy)
	-- UTILS
	enemy.Humanoid.WalkSpeed = movementSpeed

	-- DEFENSE
	local hpDelta = hp - enemy.Humanoid.MaxHealth -- Frustrating?
	enemy.Humanoid.Health += hpDelta
	enemy.Humanoid.MaxHealth = hp
end

local function ScaleEnemies()
	-- Change Init Stats
	movementSpeed = math.clamp(movementSpeed + MOVEMENT_SPEED_INCREMENT, 8, MOVEMENT_SPEED_CAP)

	hp += HP_INCREMENT

	attackDmg += ATTACK_DAMAGE_INCREMENT

	-- Update All In Game Enemies
	for _, enemy in ipairs(enemies) do
		ApplyStats(enemy)
		-- enemy.Humanoid.WalkSpeed = movementSpeed
	end

	-- globalEnemiesLevel += 1
	-- Events.EnemyLevelUp:FireAllClients(globalEnemiesLevel)

	ServerEvents.EnemiesLevel:Fire()
end

local function SetupEnemy(enemy)
	table.insert(enemies, enemy)

	ApplyStats(enemy)

	enemy.Parent = ENEMY_FOLDER
	enemy.Humanoid.Died:Connect(function()
		Gears.SpawnXP(enemy.PrimaryPart.Position)
		-- task.wait(2)
		local index = table.find(enemies, enemy)
		table.remove(enemies, index)
		attackCooldowns[enemy] = nil
		enemy:Destroy()

		enemyDeathCount += 1
		if enemyDeathCount >= 30 then
			ScaleEnemies()
			enemyDeathCount = 0
		end
	end)
end

-- Behaviour

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

local function AttacksCooldown()
	for enemy, time in pairs(attackCooldowns) do
		local attackDelta = tick() - time
		-- print("Attack Delta = " .. attackDelta)

		if attackDelta > ATTACK_COOLDOWN then
			attackCooldowns[enemy] = nil
		end
	end
end

local function Attacks()
	if attackFrameCount < FRAME_CHECK_DELTA then
		attackFrameCount += 1
		return
	end

	attackFrameCount = 0

	AttacksCooldown()

	local humanoidsHit = {}

	-- Hit Detection
	-- Draw Sphere around each Players
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character or PlayersStats[player.UserId].pickingAugment then -- Prevents attacks when picking augments
			continue
		end

		local root = player.Character.HumanoidRootPart
		local hitEnemies = workspace:GetPartBoundsInRadius(root.Position, ATTACK_RANGE, params)
		-- DEBUG
		-- Gears.ExecuteFor(0.3, function()
		-- 	Gears.DrawCircle(root.Position, Gears.CirclePoints(ATTACK_RANGE, 20))
		-- end)

		for _, part in ipairs(hitEnemies) do
			local enemyModel = part.Parent

			if
				table.find(humanoidsHit, enemyModel)
				or attackCooldowns[enemyModel]
				or enemyModel.Humanoid.Health <= 0
			then
				continue
			end

			-- Attack
			table.insert(humanoidsHit, enemyModel)
			attackCooldowns[enemyModel] = tick()

			enemyModel.Humanoid:MoveTo(enemyModel.HumanoidRootPart.Position) -- Stop movement
			player.Character.Humanoid:TakeDamage(attackDmg)
		end
	end
end

-- Spawn

local function StreamSpawn() -- Spawn Enemies constantly
	if #enemies >= MAX_ENEMIES then
		return
	end

	local spawnDelta = math.random(streamSpawnDeltaTime, streamSpawnDeltaTime + streamSpawnDeltaTimeRange)
	task.wait(spawnDelta)

	for _, player in ipairs(Players:GetPlayers()) do
		local enemyNbr = math.random(streamSpawnNbr, streamSpawnNbr + streamSpawnNbrRange)

		for _ = 1, enemyNbr, 1 do
			Gears.SpawnEnemyCircle(player.Character.PrimaryPart.Position)
		end
	end

	StreamSpawn()
end

local function SwarmSpawn() -- Spawn Big wave of Enemies
	if #enemies >= MAX_ENEMIES then
		return
	end

	for _ = 0, swarmWaves, 1 do
		for _, player in ipairs(Players:GetPlayers()) do
			local enemyNbr = math.random(swarmNbr, swarmNbr + swarmNbrRange)
			local radius = math.random(60, 120)
			local progress = Gears.FloatRandom(0, math.pi * 2) -- math.rad(360)
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
	-- MapGenerator Called ClearMap
	table.clear(enemies)
end)

-- Do
task.spawn(function()
	StreamSpawn()
end)

-- task.spawn(function()
-- 	ScaleEnemies()
-- end)

RunService.Heartbeat:Connect(function()
	Attacks()
end)

--RunAtPlayer()
MoveToPlayer()
