return {
	MAX_BANANAS = 10_000,
	MAX_INCREMENTS = 10,
	BASE_COST = 100,
	COST_MULTIPLIER = 1.2,
	augmentType = { -- TODO : Unify with augments?
		"attackDamage",
		"attackSpeed",
		"aoe",
		"maxHealth",
		"lifeRegen",
		"damageReduction",
		"mobility",
		"luck",
		"increasedXp",
		"increasedPickupRange",
		"critChance",
		"critMultiplier",
	},
	displayText = {
		["attackDamage"] = "% Attack Damage ",
		["attackSpeed"] = "% Attack Speed ",
		["aoe"] = "% AOE ",
		["maxHealth"] = "Life ",
		["lifeRegen"] = "Life Regen ",
		["damageReduction"] = "% Damage Reduction ",
		["mobility"] = "Mobility ",
		["luck"] = "Luck ",
		["increasedXp"] = "% Increased XP ",
		["increasedPickupRange"] = "% Pickup Range ",
		["critChance"] = "% Crit Chance ",
		["critMultiplier"] = "% Crit Multiplier ",
	},
	["attackDamage"] = {
		Increment = 5,
		-- TODO :
		-- BaseCost = ,
		-- Cost Multiplier / Increment = ,
	},
	["attackSpeed"] = {
		Increment = 2,
	},
	["aoe"] = {
		Increment = 2,
	},
	["maxHealth"] = {
		Increment = 5,
	},
	["lifeRegen"] = {
		Increment = 1,
	},
	["damageReduction"] = {
		Increment = 2,
	},
	["mobility"] = {
		Increment = 0.5,
	},
	["luck"] = {
		Increment = 1,
	},
	["increasedXp"] = {
		Increment = 2,
	},
	["increasedPickupRange"] = {
		Increment = 2,
	},
	["critChance"] = {
		Increment = 2,
	},
	["critMultiplier"] = {
		Increment = 2,
	},
}
