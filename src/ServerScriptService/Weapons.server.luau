--Weapon Server -> Dmg + Sounds
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Events = require(ReplicatedStorage.Shared.Events)
local WeaponConfig = require(ReplicatedStorage.Shared.Modules.WeaponConfig)
local Gears = require(ServerScriptService.Server.Gears)

--Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

-- Players
local expectingAttack = {}
local weaponHitParam = OverlapParams.new()
weaponHitParam.FilterType = Enum.RaycastFilterType.Include
weaponHitParam.FilterDescendantsInstances = { workspace.WeaponHit }
weaponHitParam.MaxParts = 50

-- Buildings
local buildingsHealth = {}

function FindHumanoidFromPart(part)
	local character = part.Parent

	if character then
		return character:FindFirstChild("Humanoid")
	end

	return nil
end

local function IncrementCombo(playerStat)
	playerStat.comboCount += 1

	if playerStat.comboCount > 1 then
		playerStat.comboCount = 0
	end

	-- Reset Combo Count after 2 sec of not Attacking
	if playerStat.comboReset then
		task.cancel(playerStat.comboReset)
	end

	playerStat.comboReset = task.delay(2, function()
		playerStat.comboCount = 0
	end)
end

local function HitBuilding(building, finalDamage, player, playerStat)
	if not buildingsHealth[building] then
		local healthMod = Gears.FloatRandom(1, 2)
		-- print(building.Name .. " Health Mod : " .. healthMod)
		local baseHealth = 0 -- Update for more Materials

		if building.Parent and building.Parent:HasTag("WoodMaterial") then
			baseHealth = 100 * healthMod
		else
			baseHealth = 180 * healthMod
		end

		buildingsHealth[building] = baseHealth
	end

	buildingsHealth[building] -= finalDamage

	-- Building Destroyed
	if buildingsHealth[building] <= 0 then
		building:Destroy()
		buildingsHealth[building] = nil
		playerStat.destruction.Value += 1
		Gears.IncrementBuilding()

		-- Enemy Spawn
		local enemyRoll = math.random(0, 100)
		if enemyRoll < 33 then -- 1 / 3
			Gears.SpawnEnemyCircle(player.Character.PrimaryPart.Position)
		end

		-- Banana Loot
		local roll = math.random(0, 100)
		if roll < 80 then
			return
		end

		for _ = 1, math.random(1, 3) do
			task.spawn(function()
				Gears.SpawnBanana(building.Position)
			end)
		end
	end
end

local function HitDetection(player, playerStat, weaponInfo, finalDamage)
	local attackPosition = weaponInfo.attackPoint.WorldCFrame
	Gears.DisplayHitBox(attackPosition, weaponInfo.range, 0.3)
	local hits = workspace:GetPartBoundsInRadius(attackPosition.Position, weaponInfo.range, weaponHitParam)
	local humanoidsHit = {}

	for _, hit in ipairs(hits) do
		-- print("Hit Part: " .. hit.Name)
		local humanoid = FindHumanoidFromPart(hit)
		if humanoid then
			-- Enemy Hit
			if humanoid.Parent ~= player.Character and humanoidsHit[humanoid] == nil then
				humanoidsHit[humanoid] = true
				humanoid:TakeDamage(finalDamage)
				-- print(player.name .. " Dealt " .. weaponInfo.Damage .. " damage to " .. humanoid.Parent.Name)
				if humanoid.Health <= 0 then
					playerStat.kills.Value += 1
				end
			end
		else
			HitBuilding(hit, finalDamage, player, playerStat)
		end
	end
end

-- Attack Callback
local function WeaponDamage(player)
	-- Check if The Call is Legit
	if not expectingAttack[player.UserId] then
		print("Unexpected AttackHit from player: " .. player.Name)
		return
	end

	local playerStat = PlayersStats[player.UserId]
	player.Character.Humanoid.WalkSpeed = playerStat.mobility -- Reset WalkSpeed
	expectingAttack[player.UserId] = nil

	local weaponInfo = playerStat.weaponInfo

	if not weaponInfo then
		return
	end

	-- Get Damage & Crit
	local finalDamage = weaponInfo.finalAttackDamage
	local critRoll = math.random(0, 100)
	-- print("Crit roll : " .. critRoll .. " Crit Chance : " .. playerStat.critChance)

	if critRoll <= playerStat.critChance then
		finalDamage *= Gears.IncreaseToMultiplier(playerStat.critMultiplier)
		-- print("Crit " .. finalDamage)
		weaponInfo.sounds.crit:Play()
	else
		weaponInfo.sounds.slash:Play()
	end

	HitDetection(player, playerStat, weaponInfo, finalDamage)
	IncrementCombo(playerStat)
end

local function Attack(player)
	-- Try to Attack using Player's Weapon
	local playerStat = PlayersStats[player.UserId]
	local weaponInfo = playerStat.weaponInfo

	if not playerStat or playerStat.pickingAugment or not weaponInfo then
		return
	end

	-- IsAttackReady
	local currentTime = tick()
	local attackDelta = currentTime - playerStat.lastAttack
	local missingTime = playerStat.animationTime - attackDelta

	local function StartAttack()
		-- print("Attack By : " .. player.Name)
		playerStat.lastAttack = tick()
		expectingAttack[player.UserId] = true
		player.Character.Humanoid.WalkSpeed *= 0.5
		attackEvent:FireClient(player, playerStat.comboCount + 1, weaponInfo.finalAttackSpeed) -- Animation
	end

	if attackDelta < playerStat.animationTime then
		-- Input Buffer
		if missingTime <= 0.1 then
			-- print("Attack Buffer: " .. player.Name)
			playerStat.lastAttack = currentTime -- Lock Input Buffer
			task.delay(missingTime, function()
				StartAttack()
			end)
		end

		return
	end

	-- print("Attack non buffer: " .. player.Name)
	StartAttack()
end

-- EVENTS SETUP
attackEvent.OnServerEvent:Connect(Attack)
attackHitEvent.OnServerEvent:Connect(WeaponDamage)

local function OnEquipped(weapon, weaponInfo)
	local character = weapon.Parent
	local player = Players:GetPlayerFromCharacter(character)
	print(weapon.Name .. " Equipped by player: " .. player.Name)

	local playerStat = PlayersStats[player.UserId]
	playerStat.weaponInfo = weaponInfo
	PlayersStats.ApplyStats(player)

	playerStat.weaponInfo.sounds.unsheath:Play()
	equipEvent:FireClient(player, true)
end

local function OnUnequipped(weapon)
	if not weapon or weapon.Parent == nil then
		return
	end

	local player = weapon.Parent.Parent

	if not player or Players:FindFirstChild(player.Name, false) == nil then
		return
	end

	print(weapon.Name .. " Unequipped by player: " .. player.Name)

	local playerStats = PlayersStats[player.UserId]
	playerStats.weaponInfo = nil
	playerStats.comboCount = 0
	playerStats.comboReset = nil
	expectingAttack[player.UserId] = nil
	PlayersStats.ApplyStats(player)

	equipEvent:FireClient(player, false)
end

local function CreateWeaponInfo(weapon)
	-- local handle = weapon:WaitForChild("Handle")
	local handle = weapon.Handle

	local weaponInfo = {
		weapon = weapon,
		weaponSize = weapon:GetScale(),
		handle = handle,
		attackPoint = weapon.Handle.AttackPoint,
		weaponType = WeaponConfig[weapon.Name].WeaponType,
		damage = WeaponConfig[weapon.Name].BaseDamage,
		finalAttackDamage = WeaponConfig[weapon.Name].BaseDamage,
		range = WeaponConfig[weapon.Name].Range,
		finalAoe = WeaponConfig[weapon.Name].Range,
		attackSpeed = WeaponConfig[weapon.Name].AttackSpeed,
		finalAttackSpeed = WeaponConfig[weapon.Name].AttackSpeed,
		sounds = {
			unsheath = handle.Unsheath,
			slash = handle.Slash,
			crit = handle.CriticalSlash,
		},
	}

	return weaponInfo
end

local function setupWeapon(weapon)
	-- Create Weapon Info
	local weaponInfo = CreateWeaponInfo(weapon)

	weapon.Equipped:Connect(function()
		OnEquipped(weapon, weaponInfo)
	end)

	weapon.Unequipped:Connect(function()
		OnUnequipped(weapon)
	end)
end

local function SetupWeaponInstances(weaponTag)
	for _, weapon in pairs(CollectionService:GetTagged(weaponTag)) do
		setupWeapon(weapon)
	end

	CollectionService:GetInstanceAddedSignal(weaponTag):Connect(setupWeapon)
end

SetupWeaponInstances("WoodenClub")
SetupWeaponInstances("IronMace")
SetupWeaponInstances("IronAxe")
