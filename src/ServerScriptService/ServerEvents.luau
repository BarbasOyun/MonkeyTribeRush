local function createServerEvent(name)
	local serverEvent = Instance.new("BindableEvent")
	serverEvent.Name = name
	serverEvent.Parent = script.Parent
	return serverEvent
end

-- Load Once
--print("Server Events module loaded")

return {
	EnemySpawned = createServerEvent("EnemySpawned"),
	StageChanged = createServerEvent("StageChanged"),
	SwarmEvent = createServerEvent("SwarmEvent"),
}
