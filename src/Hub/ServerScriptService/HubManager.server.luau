local ReplicatedStorage = game.ReplicatedStorage
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")
local BananasData = DataStoreService:GetDataStore("Bananas")
local UpgradeTreeData = DataStoreService:GetDataStore("UpgradeTree")

local Events = require(ReplicatedStorage.Shared.Events)
local SafeTeleport = require(ReplicatedStorage.Shared.SafeTeleport)
local UpgradeTree = require(ReplicatedStorage.Shared.Modules.UpgradeTreeData)

local UPGRADE_DELTA_TIME = 1

-- Place TP
local placeId = 126527146316982

-- local gameInstances = {}
local platforms = { workspace.Game1Platform.Platform } -- TODO : Add Platform2 = workspace.Game2Platform.Platform
local teleportedPlayers = {}

local playersData = {}

-- Marketplace
local productFunctions = {}
local hundredDonationId = 3563342388
local thousandDonationId = 3563893138

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

local function SafeIncrement(dataStore, userId, amount)
	local success, newValue = pcall(function()
		return dataStore:UpdateAsync(userId, function(oldValue)
			local current = oldValue or 0
			local nextValue = current + amount
			return math.clamp(nextValue, 0, UpgradeTreeData.MAX_BANANAS)
		end)
	end)

	if success then
		return newValue
	end

	return nil
end

-- Store
productFunctions[hundredDonationId] = function(receipt, player)
	return true
end

productFunctions[thousandDonationId] = function(receipt, player)
	return true
end

local function processReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(userId)

	if player then
		local handler = productFunctions[productId]

		local success, result = pcall(handler, receiptInfo, player)
		if success then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			error(receiptInfo)
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt

-- TP Place
local function onPlatformTouched(hit, index)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)

	if not player or table.find(teleportedPlayers, player) then
		return
	end

	-- print("Player Touched Platform")
	table.insert(teleportedPlayers, player)
	Events.platformTouched:FireClient(player) -- Feedback

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
-- TODO : Move in UpgradeTree Module
local function CalcCost(lvl) -- type
	local totalMultiplier = math.pow(UpgradeTree.COST_MULTIPLIER, lvl)
	return math.floor(UpgradeTree.BASE_COST * totalMultiplier)
end

local function CalcStat(upgradeType, lvl)
	return UpgradeTree[upgradeType].Increment * lvl
end

local function CreatePlayerData(player)
	-- Create New Player Data
	playersData[player.UserId] = {}

	-- Display Bananas
	local uiData = Instance.new("Folder")
	uiData.Parent = player
	uiData.Name = "UIData"

	local bananasUi = Instance.new("IntValue")
	bananasUi.Parent = uiData
	bananasUi.Name = "BananasUi"

	-- Get bananas from DataStore
	local success, value = pcall(function()
		return BananasData:GetAsync(player.UserId)
	end)

	local bananasCount = value
	bananasUi.Value = bananasCount
	-- print(player.Name .. " Has " .. bananasCount .. " Bananas")

	table.insert(playersData[player.UserId], bananasCount)

	-- Add UpgradeTree Data
	table.insert(playersData[player.UserId], {}) -- UpgradeTree Array = Index2

	for _, upgradeType in ipairs(UpgradeTree.augmentType) do
		-- local upgradeLvl = 3 -- Get From DataStore
		local upgradeLvl = UpgradeTreeData:GetAsync(upgradeType .. "_" .. player.UserId) or 0

		table.insert(playersData[player.UserId][2], { -- Client access by index
			lvl = upgradeLvl,
			statValue = CalcStat(upgradeType, upgradeLvl),
			cost = CalcCost(upgradeLvl),
			displayText = UpgradeTree.displayText[upgradeType],
		})
	end

	-- Add Rate Limit
	table.insert(playersData[player.UserId], false)

	-- Store BananasUi TODO : Refactor
	table.insert(playersData[player.UserId], bananasUi)

	Events.GetFullStageData:FireClient(player, UpgradeTree.MAX_INCREMENTS, playersData[player.UserId])
end

local function LvlUpUpgrade(player, index)
	local playerData = playersData[player.UserId]

	-- Rate Limit
	if playerData[3] then
		Events.UpgradeTree:FireClient(player, false)
		return
	end
	playerData[3] = true

	local bananasCount = playerData[1]
	local upgradeData = playerData[2][index]

	-- Check Conditions
	if bananasCount < upgradeData.cost or upgradeData.lvl >= 10 then
		Events.UpgradeTree:FireClient(player, false)
		return
	end

	local upgradeType = UpgradeTree.augmentType[index]
	local newLvl = upgradeData.lvl + 1

	-- Datastore -> Increment Lvl
	local success, err = pcall(function()
		UpgradeTreeData:SetAsync(upgradeType .. "_" .. player.UserId, newLvl) -- TODO : UpgradeTreeService Function
	end)

	bananasCount = math.max(0, bananasCount - upgradeData.cost)

	-- Datastore -> Remove Bananas
	local bSuccess, bErr = pcall(function()
		BananasData:SetAsync(player.UserId, bananasCount)
	end)
	task.wait(UPGRADE_DELTA_TIME)

	playerData[3] = false

	-- Finish
	upgradeData.lvl = newLvl
	upgradeData.statValue = CalcStat(upgradeType, upgradeData.lvl)
	upgradeData.cost = CalcCost(upgradeData.lvl)
	playerData[4].Value = bananasCount

	Events.UpgradeTree:FireClient(player, true, index, upgradeData)
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
	playersData[leavingPlayer.UserId] = nil
end)

Events.UpgradeTree.OnServerEvent:Connect(function(player, index)
	LvlUpUpgrade(player, index)
end)

-- Do
SetupPlatforms()
