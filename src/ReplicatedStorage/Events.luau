local function createRemoteEvent(name)
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = script.Parent
	return remoteEvent
end

-- Load Once
--print("Events module loaded")

return {
	ToolAttack = createRemoteEvent("ToolAttack"),
	ToolEquip = createRemoteEvent("ToolEquip"),
	AttackHit = createRemoteEvent("AttackHit"),
	LevelUp = createRemoteEvent("LevelUp"),
	Reroll = createRemoteEvent("Reroll"),
	AugmentPick = createRemoteEvent("AugmentPick"),
	XpPickup = createRemoteEvent("XpPickup"),
	StageProgress = createRemoteEvent("StageProgress"),
	CurrentStageChanged = createRemoteEvent("CurrentStageChanged"),
	NextStageTimerTick = createRemoteEvent("NextStageTimerTick"),
	EnemyLevelUp = createRemoteEvent("EnemyLevelUp"),
	StageData = createRemoteEvent("StageData"),
	GetFullStageData = createRemoteEvent("GetFullStageData"),
	PlayerDied = createRemoteEvent("PlayerDied"),
}
