local PlayersStats = {}

local DefaultStats = {
	Health = 100,
	Mobility = 15,
	AttackSpeed = 0,
	AttackDamage = 0,
	AOE = 0,
	LifeRegen = 1,
	DamageReduction = 0,
	Luck = 0,
	XP = 0,
	WeaponInfo = nil,
}

function PlayersStats.createPlayer(player)
	PlayersStats[player] = DefaultStats
end

return PlayersStats
