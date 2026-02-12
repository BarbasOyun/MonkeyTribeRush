local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Events = require(ReplicatedStorage.Shared.Events)
local Gears = require(ReplicatedStorage.Shared.Gears)
local Augments = require(ReplicatedStorage.Shared.Modules.AugmentsConfig)

local levelUpEvent = Events.LevelUp
local rerollEvent = Events.Reroll
local augmentPick = Events.AugmentPick

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
	lifeRegen = 0,
	lifeRegenUpdate = nil,
	damageReduction = 0,
	mobility = 15,
	luck = 0,
	increasedXp = 0,
	levelUpXp = nil,
	currentXp = nil,
	pickupRange = 10,
	increasedPickupRange = 0,
	critChance = 5,
	critMultiplier = 50,
	weaponInfo = nil,
	bananas = nil,
}

function playersStats.CreatePlayer(player, leaderstats, uiInfos)
	playersStats[player] = defaultStats
	local playerStat = playersStats[player]

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

	local kills = Instance.new("IntValue")
	kills.Parent = leaderstats
	kills.Name = "Kills"
	kills.Value = 0
	playerStat.kills = kills

	local destruction = Instance.new("IntValue")
	destruction.Parent = leaderstats
	destruction.Name = "Destruction"
	destruction.Value = 0

	playersStats.ApplyStats(player)
end

function playersStats.CalculateAttackSpeed(playerStat)
	if not playerStat.weaponInfo then
		return
	end

	playerStat.weaponInfo.finalAttackSpeed = playerStat.weaponInfo.attackSpeed
		* Gears.IncreaseToMultiplier(playerStat.attackSpeed)
	playerStat.animationTime = 1 / playerStat.weaponInfo.finalAttackSpeed

	-- print(" Final Attack Speed: " .. (playerStat.WeaponInfo and playerStat.WeaponInfo.finalAttackSpeed or 0))
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
	local playerStat = playersStats[player]
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.MaxHealth = playerStat.maxHealth
	humanoid.WalkSpeed = playerStat.mobility
	humanoid.JumpPower = 40 + playerStat.mobility / 2
	-- playerStat.currentXp.Value = playerStat.currentXp.Value -- Update XP Bar

	-- Life Regen
	if playerStat.lifeRegenUpdate then
		playerStat.lifeRegenUpdate:Disconnect()
		playerStat.lifeRegenUpdate = nil
	end

	if playerStat.lifeRegen > 0 then
		playerStat.lifeRegenUpdate = RunService.Heartbeat:Connect(function()
			humanoid.Health += playerStat.lifeRegen / 60 -- 60 FPS
		end)
	end

	playersStats.CalculateAttackSpeed(playerStat)
	playersStats.CalculateAttackDamage(playerStat)
	playersStats.CalculateAoe(playerStat)
end

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
			local totalWeight = Gears.sumTable(weights)
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
			local augmentRoll = math.random(1, #Augments.augmentType - 1)
			local augmentType = Augments.augmentType[augmentRoll]
			local augmentValue = Augments[augmentType][rarity] -- augmentType

			if not augmentValue then
				-- print(augmentType .. " Doesn't have : " .. rarity .. " Version")
				return FindAugment()
			end

			return { augmentType, rarity, augmentValue }
		end

		return FindAugment()
	end

	local augmentsChoice = { GetAugment(), GetAugment(), GetAugment() }

	return augmentsChoice
end

function playersStats.SendAugment(player, playerStat)
	local augments = playersStats.RollAugments(playerStat.luck)
	currentAugments[player] = augments
	rerollEvent:FireClient(player, augments)
end

function playersStats.AddXpToLvl(player, xp)
	-- print(player.Name .. " Gained : " .. xp .. " XP")
	local playerStat = playersStats[player]
	playerStat.currentXp.Value += xp * Gears.IncreaseToMultiplier(playerStat.increasedXp)

	if playerStat.currentXp.Value >= playerStat.levelUpXp.Value then
		playersStats.LevelUp(player)
	end
end

function playersStats.LevelUp(player)
	local playerStat = playersStats[player]

	-- Manage XP
	local overXp = playerStat.currentXp.Value - playerStat.levelUpXp.Value
	playerStat.waitingLevel += 1
	playerStat.currentXp.Value = 0
	playerStat.levelUpXp.Value *= 1.1
	print(player.Name .. " Leveled Up")

	playersStats.SendAugment(player, playerStat)
	levelUpEvent:FireClient(player, playerStat.level, playerStat.waitingLevel)

	playersStats.AddXpToLvl(player, overXp)
end

function playersStats.AddXp(xpValue)
	for _, player in pairs(Players:GetPlayers()) do
		playersStats.AddXpToLvl(player, xpValue)
	end
end

-- Start Augment Choice
augmentPick.OnServerEvent:Connect(function(player)
	if not currentAugments[player] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	print(player.Name .. "Is Picking Augment")
	playersStats[player].pickingAugment = true
	positionStart[player.UserId] = player.Character.HumanoidRootPart.CFrame.Position
	-- Make Player Immune
end)

-- Augment Choice Made
levelUpEvent.OnServerEvent:Connect(function(player, choiceNbr)
	if not currentAugments[player] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- print(player.Name .. " Choosed : " .. choiceNbr)
	local playerStat = playersStats[player]
	playerStat.level += 1
	playerStat.waitingLevel -= 1
	levelUpEvent:FireClient(player, playerStat.level, playerStat.waitingLevel)

	--Add Augment Stats
	local augment = currentAugments[player][choiceNbr]
	playerStat[augment[1]] += augment[3] -- augmentType and augmentValue
	currentAugments[player] = nil
	playersStats.ApplyStats(player)

	-- Additional Levels
	if playerStat.waitingLevel > 0 then
		playersStats.SendAugment(player, playerStat)
		return
	end

	player.Character:MoveTo(positionStart[player.UserId])
	positionStart[player.UserId] = nil
	playersStats[player].pickingAugment = false
end)

rerollEvent.OnServerEvent:Connect(function(player)
	if not currentAugments[player] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- Pay 10 Sticks to Reroll

	playersStats.SendAugment(player, playersStats[player])
end)

return playersStats
