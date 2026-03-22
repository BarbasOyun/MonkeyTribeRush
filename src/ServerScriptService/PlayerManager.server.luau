-- Services
local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins") -- TODO : Use Scopes
local BananasData = DataStoreService:GetDataStore("Bananas")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayersStats = require(ServerScriptService.Server.PlayersStats)
local MapGenerator = require(ServerScriptService.Server.MapGenerator)
local ServerEvents = ServerScriptService.Server
local Events = ReplicatedStorage.Shared

local SafeTeleport = ReplicatedStorage.Shared.SafeTeleport
local hubPlaceId = 92891776561997

local globalEnemiesLevel = 1 -- TODO : Refactor

-- Players
local FULL_STAGE_DATA_CD = 10 -- sec
local fullStageDataCD = {}

Players.CharacterAutoLoads = false -- Prevent Auto Respawn
local deadPlayers = {}

-- local MAX_SPEED = 100
local MAX_DISTANCE = 250

local XP_FRAME = 5 -- Gather xp Every X Frame
local frameCount = 0

-- XpGrabRange Parameters
local xpPickupParam = OverlapParams.new()
xpPickupParam.FilterType = Enum.RaycastFilterType.Include
xpPickupParam.FilterDescendantsInstances = { workspace.XP_Orbs }
xpPickupParam.MaxParts = 50

local function SaveData()
	-- Save Data : Kills, Destruction, Bananas -> use pcall
	-- Cap Data to max

	for _, player in ipairs(Players:GetPlayers()) do
		print("Save Data for : " .. player.Name)

		local playerStats = PlayersStats[player.UserId]

		local bananasDelta = playerStats.bananas.Value - playerStats.storedBananas
		local kills = player.leaderstats.Kills
		-- local destruction = player.leaderstats.Destruction -- TODO : Save Destruction

		BananasData:IncrementAsync(player.UserId, bananasDelta)
		playerStats.storedBananas = bananasDelta
		print("Bananas Added : " .. bananasDelta)

		if kills > playerStats.highestKills then
			print("Save Kills Value")
			playerStats.highestKills = kills
			KillsData:SetAsync(player.UserId, kills)
		end
	end
end

local function ResetData()
	for _, player in ipairs(Players:GetPlayers()) do
		KillsData:SetAsync(player.UserId, 0)
		BananasData:SetAsync(player.UserId, 0)
	end
end

local function SetupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	local uiInfos = Instance.new("Folder")
	uiInfos.Parent = player
	uiInfos.Name = "UIInfos"

	PlayersStats.CreatePlayer(player, leaderstats, uiInfos)

	local playerStat = PlayersStats[player.UserId]
	local kills = KillsData:GetAsync(player.UserId)
	playerStat.highestKills = kills

	-- Get Player's UpgradeTree
	-- PlayersStats.AddStat(player, PlayersStats[player.UserId], type, value)
end

local function EquipDefaultWeapon(player)
	local humanoid = player.Character:FindFirstChild("Humanoid")
	local backpack = player:FindFirstChild("Backpack")

	if not humanoid or not backpack then
		return
	end

	local defaultTool = backpack:FindFirstChild("WoodenClub")
	-- print("Equip Default tool : " .. defaultTool)
	if defaultTool then
		humanoid:EquipTool(defaultTool)
	end
end

local function GameOver()
	print("Game Over -> Going back to Hub")
	SaveData()
	local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
		return SafeTeleport(hubPlaceId, { Players:GetPlayers() })
	end)

	print("Hub TP success : " .. success)
end

local function OnPlayerDeath(player)
	print(player.Name .. " died! Waiting Next Stage to respawn...")
	table.insert(deadPlayers, player)
	Events.PlayerDied:FireClient(player)

	if #deadPlayers >= #Players:GetPlayers() then
		GameOver()
	end
end

local function GetOrb(orb, player)
	if orb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	elseif orb.Name == "Banana" then
		PlayersStats.AddBananas(1)
	elseif orb.Name == "Stick" then
		local playerStats = PlayersStats[player.UserId]
		playerStats.sticks.Value += 1
	end

	Events.XpPickup:FireClient(player)
	orb:Destroy()
end

local function GrabOrb(character, orb, player)
	-- print("xpOrb Found")
	if not orb.Parent then
		return
	end

	if orb.Parent ~= workspace.XP_Orbs then
		return
	end

	orb.Parent = game.Workspace
	orb.CanCollide = false

	-- Lerp Orb
	local startPos = orb.CFrame

	local steps = 30
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		orb.CFrame = startPos:Lerp(character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	GetOrb(orb, player)
end

local function PickupRange()
	if frameCount < XP_FRAME then
		frameCount += 1
		return
	end

	frameCount = 0

	for _, player in pairs(game.Players:GetChildren()) do
		-- print(player.Name)
		local playerStats = PlayersStats[player.UserId]
		local character = player.Character or player.CharacterAdded:Wait()

		if not character then
			return
		end

		local position = character.HumanoidRootPart.CFrame.Position
		local range = playerStats.finalPickupRange

		-- DEBUG
		-- Gears.DisplayHitBox(position, range, 0.1)

		local orbs = workspace:GetPartBoundsInRadius(position, range, xpPickupParam)
		for _, orb in ipairs(orbs) do
			GrabOrb(character, orb, player)
		end
	end
end

-- Events

-- TODO : Refactor
ServerEvents.EnemiesLevel.Event:Connect(function()
	globalEnemiesLevel += 1
	Events.EnemyLevelUp:FireAllClients(globalEnemiesLevel)
end)

-- Save + Respawn on new Stage
ServerEvents.StageChanged.Event:Connect(function()
	SaveData()
	for _, player in ipairs(deadPlayers) do
		player:LoadCharacter()
	end
end)

Events.GetFullStageData.OnServerEvent:Connect(function(player)
	if fullStageDataCD[player] and tick() - fullStageDataCD[player] < FULL_STAGE_DATA_CD then
		return
	end

	fullStageDataCD[player] = tick()

	Events.GetFullStageData:FireClient(
		player,
		MapGenerator.stageEventsNbr,
		MapGenerator.stageProgress,
		globalEnemiesLevel
	)
end)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game")

	task.spawn(function()
		SetupPlayer(player)
	end)

	player:LoadCharacterAsync()
	-- Gears.waitUntil(function()
	-- 	return player.Character
	-- end)

	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")

	EquipDefaultWeapon(player)

	-- On Death
	character.Humanoid.Died:Connect(function()
		OnPlayerDeath(player)
	end)

	-- Send Current Stage Data -> Players joining mid game
	Events.GetFullStageData:FireClient(
		player,
		MapGenerator.stageEventsNbr,
		MapGenerator.stageProgress,
		globalEnemiesLevel
	)

	RunService.Heartbeat:Connect(function()
		-- Limit Velocity
		-- if root then
		-- 	local velocity = root.AssemblyLinearVelocity
		-- 	if velocity.Magnitude > MAX_SPEED then
		-- 		root.AssemblyLinearVelocity = velocity.Unit * MAX_SPEED
		-- 	end
		-- end

		-- Limit Distance
		local pos = root.Position
		local flatPos = Vector2.new(pos.X, pos.Z) -- Check 2D distance

		if flatPos.Magnitude > MAX_DISTANCE then -- TODO : Squared Magnitude
			character:PivotTo(CFrame.new(Vector3.zero))
			root.AssemblyLinearVelocity = Vector3.zero -- Reset momentum
		end
	end)
end)

-- DO

RunService.Heartbeat:Connect(PickupRange)

MapGenerator.StartStage()
