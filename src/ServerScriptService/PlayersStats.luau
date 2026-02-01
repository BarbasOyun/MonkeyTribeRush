local playersStats = {}

local defaultStats = {
	level = 1,
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
	currentXP = 0,
	xpGrabRange = 10,
	increaseXPGrabRange = 0,
	weaponInfo = nil,
}

function playersStats.CreatePlayer(player)
	playersStats[player] = defaultStats
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

return playersStats
