local ReplicatedStorage = game.ReplicatedStorage
local TeleportService = game:GetService("TeleportService")
local SafeTeleport = require(ReplicatedStorage.Shared.SafeTeleport)
local Events = require(ReplicatedStorage.Shared.Events)
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")
local BananasData = DataStoreService:GetDataStore("Bananas")

local UpgradeTreeData = require(ReplicatedStorage.Shared.Modules.UpgradeTreeData)

local UPGRADE_DELTA_TIME = 1

-- Place TP
local placeId = 126527146316982

-- local gameInstances = {}
local platforms = { workspace.Game1Platform.Platform }
local teleportedPlayers = {}

local playerData = {}

-- Music
local music = workspace.Music
music:Play()

-- TODO : Move Gears to ReplicatedStorage + Move to Gears
local function FindWhere(table, condition)
	for _, item in pairs(table) do
		if condition(item) then
			return item
		end
	end
	return nil
end

local function onPlatformTouched(hit, index)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)

	if not player or table.find(teleportedPlayers, player) then
		return
	end

	-- print("Player Touched Platform")
	table.insert(teleportedPlayers, player)
	Events.platformTouched:FireClient(player)

	local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
		return SafeTeleport(placeId, { player })
	end)

	-- gameInstances[index] = jobId
	local playerIndex = table.find(teleportedPlayers, player)
	if playerIndex then
		teleportedPlayers[playerIndex] = nil
	end
end

local function SetupPlatforms()
	for i, platform in ipairs(platforms) do
		platform.Touched:Connect(function(hit)
			onPlatformTouched(hit, i + 1)
		end)
	end
end

local function createRoomAndTeleport(players)
	local success, reservedCode = pcall(function()
		return TeleportService:ReserveServerAsync(placeId)
	end)

	if success then
		TeleportService:TeleportToPrivateServer(placeId, reservedCode, players)
	else
		warn("Failed to reserve server!")
	end
end

local function FollowedPlayer(player)
	local followPlayerId = player.FollowUserId

	if followPlayerId and followPlayerId ~= 0 then
		local success, errorMsg, currentInstance, placeId, jobId = pcall(function()
			return TeleportService:GetPlayerPlaceInstanceAsync(followPlayerId)
		end)

		if success then
			TeleportService.TeleportToPlaceInstance(placeId, jobId, player)
		else
			warn(errorMsg)
		end
	end
end

-- Upgrade Tree Logic
-- TODO : Move in different File
local function CalcCost(lvl) -- type
	local totalMultiplier = math.pow(UpgradeTreeData.COST_MULTIPLIER, lvl)
	return math.floor(UpgradeTreeData.BASE_COST * totalMultiplier)
end

local function CalcStat(upgradeType, lvl)
	return UpgradeTreeData[upgradeType].Increment * lvl
end

local function CreatePlayerData(player)
	-- Create New Player Data
	playerData[player.UserId] = {}

	-- Display Bananas
	local uiData = Instance.new("Folder")
	uiData.Parent = player
	uiData.Name = "UIData"

	local bananas = Instance.new("IntValue")
	bananas.Parent = uiData
	bananas.Name = "Bananas"

	local bananasCount = BananasData:GetAsync(player.UserId)
	bananas.Value = bananasCount
	-- print(player.Name .. " Has " .. bananasCount .. " Bananas")

	-- UpgradeTree
	table.insert(playerData[player.UserId], bananas)

	-- Build UpgradeTree Data
	table.insert(playerData[player.UserId], {}) -- UpgradeTree Array = Index2

	for _, upgradeType in ipairs(UpgradeTreeData.augmentType) do
		local upgradeLvl = 3 -- Get From DataStore

		table.insert(playerData[player.UserId][2], { -- Client access by index
			lvl = upgradeLvl,
			statValue = CalcStat(upgradeType, upgradeLvl),
			cost = CalcCost(upgradeLvl),
			displayText = UpgradeTreeData.displayText[upgradeType],
		})
	end

	table.insert(playerData[player.UserId], false)

	Events.GetFullStageData:FireClient(player, UpgradeTreeData.MAX_INCREMENTS, playerData[player.UserId])
end

-- Player Added
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " Joined")
	FollowedPlayer(player)
	CreatePlayerData(player)
end)

-- Player Leave
Players.PlayerRemoving:Connect(function(leavingPlayer)
	-- CleanUp PlayerData
	playerData[leavingPlayer.UserId] = nil
end)

Events.UpgradeTree.OnServerEvent:Connect(function(player, index)
	-- Rate Limit
	if playerData[player.UserId][3] then
		Events.UpgradeTree:FireClient(player, false)
		return
	end

	local bananasCount = playerData[player.UserId][1]
	local upgradeData = playerData[player.UserId][2][index]

	-- Check Max Increment
	if bananasCount.Value < upgradeData.cost or upgradeData.lvl >= 10 then
		Events.UpgradeTree:FireClient(player, false)
		return
	end

	-- lvlUp Upgrade
	local upgradeType = UpgradeTreeData.augmentType[index]
	bananasCount.Value = math.max(0, bananasCount.Value - upgradeData.cost)

	playerData[player.UserId][3] = true
	local succ, err = pcall(function()
		BananasData:SetAsync(player.UserId, bananasCount.Value)
	end)
	task.wait(UPGRADE_DELTA_TIME)
	playerData[player.UserId][3] = false

	upgradeData.lvl += 1
	upgradeData.statValue = CalcStat(upgradeType, upgradeData.lvl)
	upgradeData.cost = CalcCost(upgradeData.lvl)

	-- TODO : Return Success
	Events.UpgradeTree:FireClient(player, true, index, upgradeData)
end)

-- Do
SetupPlatforms()
