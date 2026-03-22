local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local Gears = require(ServerScriptService.Server.Gears)
local Augments = require(ReplicatedStorage.Shared.Modules.AugmentsConfig)

local levelUpEvent = Events.LevelUp -- Server = Augment Choice Made / Client = Display LvlUp Button
local rerollEvent = Events.Reroll
local augmentPick = Events.AugmentPick -- Server = Augment Pick State / Client = Update Levels Display

local playersStats = {}

-- Augment Info
local currentAugments = {}
local positionStart = {}

local defaultStats = {
	level = 1,
	waitingLevel = 0,
	pickingAugment = false,
	attackDamage = 0,
	attackSpeed = 0,
	animationTime = 1,
	lastAttack = 0,
	comboCount = 0,
	comboReset = nil,
	aoe = 0,
	maxHealth = 100,
	lifeRegen = 1,
	lifeRegenUpdate = nil,
	damageReduction = 0,
	mobility = 15,
	luck = 0,
	increasedXp = 0,
	levelUpXp = nil,
	currentXp = nil,
	pickupRange = 10,
	increasedPickupRange = 0,
	finalPickupRange = 10,
	critChance = 5,
	critMultiplier = 50,
	weaponInfo = nil,
	sticks = nil,
	kills = nil,
	highestKills = 0,
	bananas = nil,
	storedBananas = 0, -- Amount of bananas sent to DataStore
}

-- TODO : Implement
-- local augmentStats = {
-- 	attackDamage = 0,
-- 	attackSpeed = 0,
-- 	aoe = 0,
-- 	maxHealth = 100,
-- 	lifeRegen = 0,
-- 	damageReduction = 0,
-- 	mobility = 15,
-- 	luck = 0,
-- 	increasedXp = 0,
-- 	increasedPickupRange = 0,
-- 	critChance = 5,
-- 	critMultiplier = 50,
-- }

function playersStats.CreatePlayer(player, leaderstats, uiInfos)
	playersStats[player.UserId] = defaultStats
	local playerStat = playersStats[player.UserId]

	-- Leader Stats
	local kills = Instance.new("IntValue")
	kills.Parent = leaderstats
	kills.Name = "Kills"
	playerStat.kills = kills

	local destruction = Instance.new("IntValue")
	destruction.Parent = leaderstats
	destruction.Name = "Destruction"
	playerStat.destruction = destruction

	-- UI Info
	local xpBarCurrent = Instance.new("IntValue")
	xpBarCurrent.Parent = uiInfos
	xpBarCurrent.Name = "XpBarCurrent"
	playerStat.currentXp = xpBarCurrent

	local xpBarMax = Instance.new("IntValue")
	xpBarMax.Parent = uiInfos
	xpBarMax.Name = "XpBarMax"
	xpBarMax.Value = 50
	playerStat.levelUpXp = xpBarMax

	local bananas = Instance.new("IntValue")
	bananas.Parent = uiInfos
	bananas.Name = "Bananas"
	playerStat.bananas = bananas

	local sticks = Instance.new("IntValue")
	bananas.Parent = uiInfos
	bananas.Name = "Sticks"
	playerStat.sticks = sticks

	playersStats.ApplyStats(player)
end

function playersStats.CalculateAttackSpeed(playerStat)
	if not playerStat.weaponInfo then
		return
	end

	playerStat.weaponInfo.finalAttackSpeed = playerStat.weaponInfo.attackSpeed
		* Gears.IncreaseToMultiplier(playerStat.attackSpeed)
	playerStat.animationTime = 1 / playerStat.weaponInfo.finalAttackSpeed

	-- print("Final Attack Speed: " .. (playerStat.weaponInfo and playerStat.weaponInfo.finalAttackSpeed or 0))
end

function playersStats.CalculateAttackDamage(playerStat)
	if not playerStat.weaponInfo then
		return
	end

	playerStat.weaponInfo.finalAttackDamage = playerStat.weaponInfo.damage
		* Gears.IncreaseToMultiplier(playerStat.attackDamage)

	-- print(" Final Attack Damage: " .. (playerStat.WeaponInfo and playerStat.WeaponInfo.finalAttackDamage or 0))
end

function playersStats.CalculateAoe(playerStat)
	if not playerStat.weaponInfo then
		return
	end

	playerStat.weaponInfo.finalAoe = playerStat.weaponInfo.range * Gears.IncreaseToMultiplier(playerStat.aoe)
end

function playersStats.ApplyStats(player)
	-- Calculate each stat on this stat changed
	local playerStat = playersStats[player.UserId]
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character.Humanoid

	-- UTILS
	humanoid.WalkSpeed = playerStat.mobility
	humanoid.JumpPower = 40 + playerStat.mobility / 2
	-- playerStat.currentXp.Value = playerStat.currentXp.Value -- Update XP Bar

	playerStat.finalPickupRange = playerStat.pickupRange * Gears.IncreaseToMultiplier(playerStat.increasedPickupRange)

	-- DEFENCE
	local hpDelta = playerStat.maxHealth - humanoid.MaxHealth
	humanoid.MaxHealth = playerStat.maxHealth
	humanoid.Health += hpDelta

	-- HP Regen
	if playerStat.lifeRegenUpdate then
		playerStat.lifeRegenUpdate:Disconnect()
		playerStat.lifeRegenUpdate = nil
	end

	if playerStat.lifeRegen > 0 then
		playerStat.lifeRegenUpdate = RunService.Heartbeat:Connect(function()
			humanoid.Health += playerStat.lifeRegen / 60 -- 60 FPS
		end)
	end

	playerStat.damageReduction = math.clamp(playerStat.damageReduction, 0, 90) -- Cap DR to 90%

	-- OFFENSE
	playersStats.CalculateAttackSpeed(playerStat)
	playersStats.CalculateAttackDamage(playerStat)
	playersStats.CalculateAoe(playerStat)

	local weaponInfo = playerStat.weaponInfo

	-- Weapon Size
	if not weaponInfo then
		return
	end

	local weapon = weaponInfo.weapon
	weapon:ScaleTo(weaponInfo.weaponSize * Gears.IncreaseToMultiplier(playerStat.aoe))
end

-- Level & Augments
function playersStats.RollAugments(luck)
	local function GetWeights()
		-- local weights = Augments.weights
		local baseLuckValue = Augments.baseLuckValue
		local luckPoints = Augments.luckPoints
		local luckDistance = {
			math.abs(luckPoints[1] - luck), -- Deal with Negative Luck
			math.abs(luckPoints[2] - luck),
			math.abs(luckPoints[3] - luck),
			math.abs(luckPoints[4] - luck),
			math.abs(luckPoints[5] - luck),
		}
		local weights = {
			baseLuckValue - luckDistance[1],
			baseLuckValue - luckDistance[2],
			baseLuckValue - luckDistance[3],
			baseLuckValue - luckDistance[4],
			baseLuckValue - luckDistance[5],
		}

		return weights
	end

	-- print("Rolling Augments with : " .. luck .. " Luck")

	local weights = GetWeights()

	local function GetAugment()
		local function FindRarity()
			local totalWeight = Gears.SumTable(weights)
			local roll = math.random(0, totalWeight)
			local count = 1
			local currentCheck = weights[1]
			while roll > currentCheck do
				count += 1
				currentCheck += weights[count]
			end

			return Augments.rarity[count]
		end

		local rarity = FindRarity()

		local function FindAugment()
			local augmentRoll = math.random(1, #Augments.augmentType)
			local augmentType = Augments.augmentType[augmentRoll]
			local augmentValue = Augments[augmentType][rarity]

			-- TODO Find List of Possible Augments
			if not augmentValue then
				-- print(augmentType .. " Doesn't have : " .. rarity .. " Version")
				return FindAugment()
			end

			return { augmentType, rarity, augmentValue }
		end

		return FindAugment()
	end

	-- TODO : Luck Protection
	local augmentChoices = { GetAugment(), GetAugment(), GetAugment() }

	return augmentChoices
end

function playersStats.SendAugment(player, playerStat)
	local augments = playersStats.RollAugments(playerStat.luck)
	currentAugments[player.UserId] = augments
	rerollEvent:FireClient(player, augments)
end

function playersStats.AddXpToLvl(player, xp)
	-- print(player.Name .. " Gained : " .. xp .. " XP")
	local playerStat = playersStats[player.UserId]
	playerStat.currentXp.Value += xp * Gears.IncreaseToMultiplier(playerStat.increasedXp)

	if playerStat.currentXp.Value >= playerStat.levelUpXp.Value then
		playersStats.LevelUp(player)
	end
end

function playersStats.LevelUp(player)
	local playerStat = playersStats[player.UserId]

	-- Compute XP
	local overXp = playerStat.currentXp.Value - playerStat.levelUpXp.Value
	playerStat.waitingLevel += 1
	playerStat.currentXp.Value = 0
	playerStat.levelUpXp.Value *= 1.1
	print(player.Name .. " Leveled Up")

	playersStats.SendAugment(player, playerStat)
	levelUpEvent:FireClient(player, playerStat.level, playerStat.waitingLevel)

	playersStats.AddXpToLvl(player, overXp)
end

-- Add XP to All Player
function playersStats.AddXp(xpValue)
	for _, player in pairs(Players:GetPlayers()) do
		playersStats.AddXpToLvl(player, xpValue)
	end
end

function playersStats.AddBananas(bananas)
	for _, player in pairs(Players:GetPlayers()) do
		playersStats[player.UserId].bananas.Value += bananas
	end
end

local function StartAugmentPick(player)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- print(player.Name .. "Is Picking Augment")
	local playerStats = playersStats[player.UserId]
	playerStats.lifeRegenUpdate:Disconnect()
	playerStats.pickingAugment = true

	positionStart[player.UserId] = player.Character.HumanoidRootPart.CFrame.Position
end

function playersStats.AddStat(player, playerStat, type, value)
	playerStat[type] += value
	playersStats.ApplyStats(player)
end

local function AugmentPick(player, choiceNbr)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- Update Level
	-- print(player.Name .. " Choosed : " .. choiceNbr)
	local playerStat = playersStats[player.UserId]
	playerStat.level += 1
	playerStat.waitingLevel -= 1
	augmentPick:FireClient(player, playerStat.level, playerStat.waitingLevel)

	--Add Augment Stats
	local augment = currentAugments[player.UserId][choiceNbr]
	-- Check Augment Or Artifact -> #augment

	playersStats.AddStat(player, playerStat, augment[1], augment[3]) -- Augment Type & Value
	currentAugments[player.UserId] = nil

	-- Additional Levels
	if playerStat.waitingLevel > 0 then
		playersStats.SendAugment(player, playerStat)
		playerStat.lifeRegenUpdate:Disconnect() -- TODO : Refactor
		return
	end

	player.Character:MoveTo(positionStart[player.UserId])
	positionStart[player.UserId] = nil
	playersStats[player.UserId].pickingAugment = false
end

augmentPick.OnServerEvent:Connect(function(player)
	StartAugmentPick(player)
end)

levelUpEvent.OnServerEvent:Connect(function(player, choiceNbr)
	AugmentPick(player, choiceNbr)
end)

rerollEvent.OnServerEvent:Connect(function(player)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- TODO : Pay 10 Sticks to Reroll

	playersStats.SendAugment(player, playersStats[player.UserId])
end)

return playersStats
