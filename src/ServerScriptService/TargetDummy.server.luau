--Target Dummy by LegoMasterMaker
--Updated by RedRocStudio

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local dummyParent = workspace.WeaponHit

local function setupDummy(dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local clone = dummy:Clone()

	if not humanoid then
		warn("TargetDummy missing Humanoid:", dummy.Name)
		return
	end

	local function OnDeath()
		print(dummy.Name .. " Died")
		Gears.SpawnXP(dummy:GetPivot().Position)
		task.wait(1)
		-- Respawn
		clone.Parent = dummyParent
		dummy:Destroy()
	end

	humanoid.Died:Connect(OnDeath)

	-- humanoid.HealthChanged:Connect(function(health)
	-- 	print(dummy.Name .. " health: " .. health)
	-- end)

	local anchor = script:GetAttribute("Anchor")

	if anchor and dummy:FindFirstChild("HumanoidRootPart") then
		dummy.HumanoidRootPart.Anchored = true
	end
end

for _, dummy in pairs(CollectionService:GetTagged("TargetDummy")) do
	setupDummy(dummy)
end

-- New dummies
CollectionService:GetInstanceAddedSignal("TargetDummy"):Connect(setupDummy)
