local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local Gears = require(ReplicatedStorage.Shared.Gears)
local Augments = require(ReplicatedStorage.Shared.Modules.AugmentsConfig)

local levelUpEvent = Events.LevelUp

print("Player Stats Test")

local playersStats = {}
local currentAugments = {}

local defaultStats = {
	level = nil,
	waitingLevel = 0,
	maxHealth = 100,
	mobility = 15,
	attackSpeed = 0,
	animationTime = 1,
	lastAttack = 0,
	comboCount = 0,
	comboReset = nil,
	attackDamage = 0,
	aoe = 0,
	lifeRegen = 1,
	damageReduction = 0,
	luck = 0,
	increasedXp = 0,
	levelXp = 50,
	currentXp = 0,
	xpGrabRange = 10,
	increaseXPGrabRange = 0,
	weaponInfo = nil,
}

function playersStats.CreatePlayer(player, leaderstats)
	local level = Instance.new("IntValue")
	level.Parent = leaderstats
	level.Name = "Level"
	level.Value = 1

	playersStats[player] = defaultStats
	playersStats[player].level = level
	playersStats.ApplyStats(player)
end

function playersStats.CalculateAttackSpeed(player)
	local PlayerStat = playersStats[player]

	if PlayerStat.WeaponInfo then
		PlayerStat.WeaponInfo.FinalAttackSpeed = PlayerStat.WeaponInfo.AttackSpeed * (1 + PlayerStat.AttackSpeed / 100)
		PlayerStat.AnimationTime = 1 / PlayerStat.WeaponInfo.FinalAttackSpeed
	end

	-- print(
	-- 	"Player: "
	-- 		.. player.Name
	-- 		.. " Final Attack Speed: "
	-- 		.. (PlayerStat.WeaponInfo and PlayerStat.WeaponInfo.FinalAttackSpeed or 0)
	-- )
end

function playersStats.ApplyStats(player)
	local playerStat = playersStats[player]
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.MaxHealth = playerStat.maxHealth
	humanoid.WalkSpeed = playerStat.mobility

	playersStats.CalculateAttackSpeed(player)
end

function playersStats.RollAugments(luck)
	-- print("Rolling Augments with : " .. luck .. " Luck")
	local weights = Augments.weights
	local luckPoints = { 0, 20, 40, 60, 85 } -- Distance = difference with luck -> +Distance = Less Chance

	local function GetAugment()
		local totalWeight = Gears.sumTable(weights)
		local roll = math.random(0, totalWeight)

		-- Find Rarity
		local function FindRarity()
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
				print(augmentType .. " Doesn't have : " .. rarity .. " Version")
				return FindAugment()
			end

			return { augmentType, rarity, augmentValue }
		end

		return FindAugment()
	end

	local augmentsChoice = { GetAugment(), GetAugment(), GetAugment() }

	return augmentsChoice
end

function playersStats.AddXpToLvl(player, xp)
	-- print(player.Name .. " Gained : " .. xp .. " XP")
	local playerStat = playersStats[player]
	playerStat.currentXp += xp * (1 + playerStat.increasedXp / 100)

	if playerStat.currentXp >= playerStat.levelXp then
		playersStats.LevelUp(player)
	end
end

function playersStats.LevelUp(player)
	local playerStat = playersStats[player]
	local overXp = playerStat.currentXp - playerStat.levelXp
	playerStat.waitingLevel += 1
	playerStat.currentXp = 0
	playerStat.levelXp *= 1.1
	print(player.Name .. " Leveled Up")

	local augments = playersStats.RollAugments(playerStat.luck)
	currentAugments[player] = augments
	levelUpEvent:FireClient(player, augments)

	playersStats.AddXpToLvl(player, overXp)
end

levelUpEvent.OnServerEvent:Connect(function(player, choiceNbr)
	if not currentAugments[player] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	print(player.Name .. " Choosed : " .. choiceNbr)
	local playerStat = playersStats[player]
	playerStat.level.Value += 1
	--Add Augment Stats
	print(currentAugments[player][choiceNbr])
end)

function playersStats.AddXp(xpValue)
	for _, player in pairs(Players:GetPlayers()) do
		playersStats.AddXpToLvl(player, xpValue)
	end
end

return playersStats
