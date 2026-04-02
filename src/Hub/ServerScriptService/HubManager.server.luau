local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game.ReplicatedStorage

local Events = require(ReplicatedStorage.Shared.Events)
local UpgradeTree = require(ReplicatedStorage.Shared.Modules.UpgradeTreeData)

-- DataStores
local BananasData = DataStoreService:GetDataStore("Bananas")
local UpgradeTreeData = DataStoreService:GetDataStore("UpgradeTree")

-- Place TP
local SessionMap = MemoryStoreService:GetSortedMap("GameInstances")
local PLACE_ID = 126527146316982

local platforms = { workspace.Game1Platform.Platform, workspace.Game2Platform.Platform }
local playersLoadingTp = {}

-- Upgrade Tree
local playersData = {}
local UPGRADE_DELTA_TIME = 1

-- Store
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

-- Upgrade Tree

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
	local success, bananas = pcall(function()
		return BananasData:GetAsync(player.UserId)
	end)

	local bananasCount = bananas
	bananasUi.Value = bananasCount
	-- print(player.Name .. " Has " .. bananasCount .. " Bananas")

	-- Bananas -> index 1
	table.insert(playersData[player.UserId], bananasCount)

	-- UpgradeTree Data -> index  2
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

	-- Add Rate Limit -> index 3
	table.insert(playersData[player.UserId], false)

	-- Store BananasUi TODO : Refactor -> index 4
	table.insert(playersData[player.UserId], bananasUi)

	Events.GetFullStageData:FireClient(player, UpgradeTree.MAX_INCREMENTS, playersData[player.UserId])
end

local function LvlUpUpgrade(player, index)
	-- Callback State : 0 = false, 1 = true, 2 = loading
	local playerData = playersData[player.UserId]

	-- Rate Limiting
	if playerData[3] then
		Events.UpgradeTree:FireClient(player, 2)
		return
	end
	playerData[3] = true

	task.wait(UPGRADE_DELTA_TIME)

	local bananasCount = playerData[1]
	local upgradeData = playerData[2][index]

	-- Check Conditions
	if bananasCount < upgradeData.cost or upgradeData.lvl >= 10 then
		playerData[3] = false
		Events.UpgradeTree:FireClient(player, 0)
		return
	end

	local upgradeType = UpgradeTree.augmentType[index]
	local newLvl = upgradeData.lvl + 1

	-- Datastore -> Increment Lvl
	pcall(function()
		UpgradeTreeData:SetAsync(upgradeType .. "_" .. player.UserId, newLvl) -- TODO : UpgradeTreeService Function
	end)

	bananasCount = math.max(0, bananasCount - upgradeData.cost)

	-- Datastore -> Remove Bananas
	pcall(function()
		BananasData:SetAsync(player.UserId, bananasCount)
	end)

	-- Finish
	upgradeData.lvl = newLvl
	upgradeData.statValue = CalcStat(upgradeType, upgradeData.lvl)
	upgradeData.cost = CalcCost(upgradeData.lvl)
	playerData[1] = bananasCount
	playerData[4].Value = bananasCount

	playerData[3] = false
	Events.UpgradeTree:FireClient(player, 1, index, upgradeData)
end

-- TP Place
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

local function joinOrCreateInstance(player, instanceIndex)
	local success, accessCode = pcall(function()
		-- Check Existing Instance
		return SessionMap:GetAsync(tostring(instanceIndex))
	end)

	local options = Instance.new("TeleportOptions")

	-- Instance Exists -> Join
	if success and accessCode then
		print(player.Name .. "Joining existing instance: " .. instanceIndex)
		options.ReservedServerAccessCode = accessCode
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
		return
	end

	-- Instance doesn't exist -> Create
	print("Creating new instance for index: " .. instanceIndex)

	-- Reserve new server
	local newCode = TeleportService:ReserveServerAsync(PLACE_ID)

	print("Reserved new server with code: " .. newCode)

	-- Save to MemoryStore for 1 hour
	pcall(function()
		SessionMap:SetAsync(tostring(instanceIndex), newCode, 3600)
	end)

	-- Teleport the creator
	options.ReservedServerAccessCode = newCode
	TeleportService:TeleportAsync(PLACE_ID, { player }, options)
end

local function SetupPlatforms()
	for i, platform in ipairs(platforms) do
		local isReady = true

		platform.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)

			if not player or not isReady or table.find(playersLoadingTp, player) then
				return
			end

			table.insert(playersLoadingTp, player)
			isReady = false
			Events.PlatformTouched:FireClient(player) -- Feedback
			joinOrCreateInstance(player, i)

			-- local playerIndex = table.find(playersLoadingTp, player)
			-- if playerIndex then
			-- 	playersLoadingTp[playerIndex] = nil
			-- end

			task.wait(1) -- Prevent multiple triggers
			isReady = true
		end)
	end
end

-- Events

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
