-- Services
local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins") -- TODO : Use Scopes
local BananasData = DataStoreService:GetDataStore("Bananas")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- local TeleportService = game:GetService("TeleportService")
-- local SafeTeleport = require(game.ReplicatedStorage:WaitForChild("SafeTeleport"))
local SafeTeleport = ReplicatedStorage.Shared.SafeTeleport

local hubPlaceId = 92891776561997

local PlayersStats = require(ServerScriptService.Server.PlayersStats)
local Gears = require(ServerScriptService.Server.Gears)
local MapGenerator = require(ServerScriptService.Server.MapGenerator)
local ServerEvents = ServerScriptService.Server
local Events = ReplicatedStorage.Shared

-- Players
local FULL_STAGE_DATA_CD = 10 -- sec
local fullStageDataCD = {}

Players.CharacterAutoLoads = false -- Prevent Auto Respawn
local deadPlayers = {}

-- local MAX_SPEED = 100
local MAX_DISTANCE = 250

local bananaCount = 0
local globalEnemiesLevel = 1

local XP_FRAME = 5 -- Gather xp Every X Frame
local frameCount = 0

-- XpGrabRange Parameters
local xpPickupParam = OverlapParams.new()
xpPickupParam.FilterType = Enum.RaycastFilterType.Include
xpPickupParam.FilterDescendantsInstances = { workspace.XP_Orbs }
xpPickupParam.MaxParts = 50

local function EquipDefaultWeapon(player)
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	local defaultTool = backpack:FindFirstChild("WoodenClub")
	if defaultTool then
		humanoid:EquipTool(defaultTool)
	end
end

local function GameOver()
	print("Game Over -> Going back to Hub")
	Gears.SaveData()
	local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
		return SafeTeleport(hubPlaceId, { Players:GetPlayers() })
	end)
end

local function OnPlayerDeath(player)
	print(player.Name .. " died! Waiting Next Stage to respawn...")
	table.insert(deadPlayers, player)
	Events.PlayerDied:FireClient(player)

	if #deadPlayers >= #Players:GetPlayers() then
		GameOver()
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
end

local function GetXp(xpOrb, player)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	elseif xpOrb.Name == "Banana" then
		bananaCount += 1
		Events.BananaPickup:FireAllClients(bananaCount)
	end

	Events.XpPickup:FireClient(player)
	xpOrb:Destroy()
end

local function GrabXp(character, xpOrb, player)
	-- print("xpOrb Found")
	if not xpOrb.Parent then
		return
	end

	if xpOrb.Parent ~= workspace.XP_Orbs then
		return
	end

	xpOrb.Parent = game.Workspace
	xpOrb.CanCollide = false

	-- Lerp XP
	local startPos = xpOrb.CFrame

	local steps = 30
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		xpOrb.CFrame = startPos:Lerp(character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	GetXp(xpOrb, player)
end

local function XpGrabRange()
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

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position, range, xpPickupParam)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXp(character, xpOrb, player)
		end
	end
end

-- Events

-- TODO : Refactor
ServerEvents.EnemiesLevel.Event:Connect(function()
	globalEnemiesLevel += 1
	Events.EnemyLevelUp:FireAllClients(globalEnemiesLevel)
end)

-- Respawn on new Stage
ServerEvents.StageChanged.Event:Connect(function()
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
		bananaCount,
		globalEnemiesLevel
	)
end)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game")
	SetupPlayer(player)

	task.wait(player:LoadCharacterAsync())

	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")

	EquipDefaultWeapon(player)

	character.Humanoid.Died:Connect(function()
		OnPlayerDeath(player)
	end)

	-- Send Current Stage Infos
	Events.StageData:FireClient(player, MapGenerator.stageEventsNbr)

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

RunService.Heartbeat:Connect(XpGrabRange)

MapGenerator.StartStage()
