local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Events = require(ReplicatedStorage.Shared.Events)
local WeaponConfig = require(ReplicatedStorage.Shared.Modules.WeaponConfig)
local Gears = require(ServerScriptService.Server.Gears)
local MapGenerator = require(ServerScriptService.Server.MapGenerator)

-- Sounds Prefabs
local slashSoundPrefab = ReplicatedStorage.Prefabs.Slash
local critSoundPrefab = ReplicatedStorage.Prefabs.CriticalSlash
local unsheathSoundPrefab = ReplicatedStorage.Prefabs.Unsheath
local buildingHitSoundPrefab = ReplicatedStorage.Prefabs.BuildingHit

--Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

-- Players
local expectingAttack = {}

-- Weapon
local weaponHitParam = OverlapParams.new()
weaponHitParam.FilterType = Enum.RaycastFilterType.Include
weaponHitParam.FilterDescendantsInstances = { workspace.WeaponHit }
weaponHitParam.MaxParts = 100

-- Buildings
local buildingsHealth = {}

function FindHumanoidFromPart(part)
	local character = part.Parent

	if character then
		return character:FindFirstChild("Humanoid")
	end

	return nil
end

-- Weapon Attack

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
	-- Add Building HP
	if not buildingsHealth[building] then
		local healthMod = Gears.FloatRandom(1, 2)
		local baseHealth = 0 -- Update for more Materials
		-- print(building.Name .. " Health Mod : " .. healthMod)

		if building.Parent and building.Parent:HasTag("WoodMaterial") then
			baseHealth = 100 * healthMod
		else
			baseHealth = 180 * healthMod
		end

		buildingsHealth[building] = baseHealth
	end

	buildingsHealth[building] -= finalDamage

	if buildingsHealth[building] > 0 then
		return
	end

	-- Building Destroyed
	building:Destroy()
	buildingsHealth[building] = nil
	playerStat.destruction.Value += 1
	MapGenerator.StageProgress()

	-- Enemy Spawn
	local enemyRoll = math.random(0, 100)
	if enemyRoll < 33 then -- 1 / 3
		Gears.SpawnEnemyCircle(player.Character.PrimaryPart.Position)
	end

	-- Banana / Stick Loot
	local roll = math.random(0, 100)

	if roll < 30 then
		-- Bananas
		for _ = 1, math.random(1, 2) do
			task.spawn(function()
				Gears.SpawnBanana(building.Position)
			end)
		end
	elseif roll > 95 then
		Gears.SpawnStick(building.Position)
	end

	return

	-- if roll < 70 then
	-- 	if roll < 10 then
	-- 		Gears.SpawnStick(building.Position)
	-- 	end
	-- 	return
	-- end

	-- for _ = 1, math.random(1, 2) do
	-- 	task.spawn(function()
	-- 		Gears.SpawnBanana(building.Position)
	-- 	end)
	-- end
end

local function HitDetection(player, playerStat, weaponInfo, finalDamage, isCrit)
	local attackPosition = weaponInfo.attackPoint.WorldCFrame
	local hits = workspace:GetPartBoundsInRadius(attackPosition.Position, weaponInfo.finalAoe, weaponHitParam)
	local humanoidsHit = {}
	local isBuilding = false

	-- DEBUG
	-- Gears.ExecuteFor(0.5, function()
	-- 	Gears.DrawSphere(attackPosition.Position, weaponInfo.finalAoe)
	-- end)

	-- VFX
	weaponInfo.attackVFX:Emit(5)

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
			isBuilding = true
			HitBuilding(hit, finalDamage, player, playerStat)
		end
	end

	-- Attack SFX
	if isCrit then
		Gears.safePlaySound(weaponInfo.sounds.crit)
		return
	elseif isBuilding then
		Gears.safePlaySound(weaponInfo.sounds.buildingHit)
		return
	end

	Gears.safePlaySound(weaponInfo.sounds.slash)
end

-- After Animation
local function AttackCallback(player)
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
	local isCrit = false
	-- print("Crit roll : " .. critRoll .. " Crit Chance : " .. playerStat.critChance)

	if critRoll <= playerStat.critChance then
		finalDamage *= Gears.IncreaseToMultiplier(playerStat.critMultiplier)
		-- print("Crit " .. finalDamage)
		weaponInfo.sounds.crit:Play()
		isCrit = true
		-- else
		-- 	weaponInfo.sounds.slash:Play()
	end

	HitDetection(player, playerStat, weaponInfo, finalDamage, isCrit)
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

-- Setup & Equip Weapons

local function AddSounds(weaponInfo, player)
	local playerGUi = player.PlayerGui

	-- Create Sounds -> Same Sounds for every weapon
	local unsheath = unsheathSoundPrefab:clone()
	unsheath.Parent = playerGUi

	local slash = slashSoundPrefab:clone()
	slash.Parent = playerGUi

	local crit = critSoundPrefab:clone()
	crit.Parent = playerGUi

	local buildingHit = buildingHitSoundPrefab:clone()
	buildingHit.Parent = playerGUi

	weaponInfo.sounds = {
		unsheath = playerGUi.Unsheath,
		slash = playerGUi.Slash,
		crit = playerGUi.CriticalSlash,
		buildingHit = playerGUi.BuildingHit,
	}
end

local function OnEquipped(weapon, weaponInfo)
	local character = weapon.Parent
	local player = Players:GetPlayerFromCharacter(character)
	-- print(weapon.Name .. " Equipped by player: " .. player.Name)

	AddSounds(weaponInfo, player)

	local playerStat = PlayersStats[player.UserId]
	playerStat.weaponInfo = weaponInfo
	PlayersStats.ApplyStats(player)

	weaponInfo.sounds.unsheath:Play()

	-- equipEvent:FireClient(
	-- 	player,
	-- 	true,
	-- 	{ weaponInfo.sounds.slash, weaponInfo.sounds.buildingHit, weaponInfo.sounds.crit }
	-- )
end

local function OnUnequipped(weapon)
	if not weapon or weapon.Parent == nil then
		return
	end

	local player = weapon.Parent.Parent

	if not player or Players:FindFirstChild(player.Name, false) == nil then
		return
	end

	-- print(weapon.Name .. " Unequipped by player: " .. player.Name)

	local playerStats = PlayersStats[player.UserId]

	-- Remove Sounds
	for _, sound in pairs(playerStats.weaponInfo.sounds) do
		sound:Destroy()
	end

	playerStats.weaponInfo = nil
	playerStats.comboCount = 0
	playerStats.comboReset = nil
	expectingAttack[player.UserId] = nil
	PlayersStats.ApplyStats(player)

	equipEvent:FireClient(player, false)
end

local function CreateWeaponInfo(weapon, weaponTag)
	local handle = weapon.Handle

	local weaponInfo = {
		weapon = weapon,
		weaponSize = weapon:GetScale(),
		handle = handle,
		attackPoint = handle.AttackPoint,
		weaponType = WeaponConfig[weaponTag].WeaponType,
		damage = WeaponConfig[weaponTag].BaseDamage,
		finalAttackDamage = WeaponConfig[weaponTag].BaseDamage,
		range = WeaponConfig[weaponTag].Range,
		finalAoe = WeaponConfig[weaponTag].Range,
		attackSpeed = WeaponConfig[weaponTag].AttackSpeed,
		finalAttackSpeed = WeaponConfig[weaponTag].AttackSpeed,
		attackVFX = handle.AttackPoint.AttackHitVFX,
	}

	return weaponInfo
end

local function setupWeapon(weapon, weaponTag)
	-- Create Weapon Info
	local weaponInfo = CreateWeaponInfo(weapon, weaponTag)

	weapon.Equipped:Connect(function()
		OnEquipped(weapon, weaponInfo)
	end)

	weapon.Unequipped:Connect(function()
		OnUnequipped(weapon)
	end)
end

-- TODO : Implement after Refactoring
-- local function InstantiateWeapon(position, weaponPrefab)
-- 	local weapon = weaponPrefab:Clone()
-- 	-- weapon:GetTa
-- end

local function SetupWeaponInstances(weaponTag)
	-- TODO : Fix Double Setup
	for _, weapon in pairs(CollectionService:GetTagged(weaponTag)) do
		setupWeapon(weapon, weaponTag)
	end

	CollectionService:GetInstanceAddedSignal(weaponTag):Connect(function(weapon)
		setupWeapon(weapon, weaponTag)
	end)
end

SetupWeaponInstances("WoodenClub")
SetupWeaponInstances("IronMace")
SetupWeaponInstances("IronAxe")

-- EVENTS SETUP
attackEvent.OnServerEvent:Connect(Attack)
attackHitEvent.OnServerEvent:Connect(AttackCallback)
