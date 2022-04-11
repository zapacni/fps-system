--!nocheck
-- https://github.com/zapacni/PlayerMouse2

local PlayerMouse2 = { }
PlayerMouse2.TargetFilter = { }

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local client = Players.LocalPlayer
local camera = Workspace.CurrentCamera

coroutine.wrap(function()
	table.insert(PlayerMouse2.TargetFilter, client.Character or client.CharacterAdded:Wait())
end)()

local event_names = {
	"LeftPressed", "LeftClicked", "LeftReleased",
	"RightPressed", "RightClicked", "RightReleased",
	"Moved", "WheelScrolled", "WheelReleased",
	"WheelPressed", "WheelClicked"
}

local real_events = { }
local writable_properties = {
	IconEnabled = function(value: boolean)
		UserInputService.MouseIconEnabled = value
	end,

	Sensitivity = function(value: number)
		UserInputService.MouseDeltaSensitivity = value
	end
}

for _, name in ipairs(event_names) do
	real_events[name] = Instance.new("BindableEvent")
	PlayerMouse2[name] = real_events[name].Event
end

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Blacklist

local function raycast(): (Ray, RaycastResult?)
	raycast_params.FilterDescendantsInstances = PlayerMouse2.TargetFilter
	local mouse_location = UserInputService:GetMouseLocation()
	local unscaled_ray = camera:ViewportPointToRay(mouse_location.X, mouse_location.Y)
	local scaled_ray = Ray.new(unscaled_ray.Origin, unscaled_ray.Direction*1000)

	return unscaled_ray, Workspace:Raycast(scaled_ray.Origin, scaled_ray.Direction, raycast_params)
end

local properties = {
	Target = function(): BasePart?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = PlayerMouse2.TargetFilter

		local mouse_location = UserInputService:GetMouseLocation()
		local unscaled_ray = camera:ViewportPointToRay(mouse_location.X, mouse_location.Y)
		local scaled_ray = Ray.new(unscaled_ray.Origin, unscaled_ray.Direction*1000)
		local raycast_result = Workspace:Raycast(scaled_ray.Origin, scaled_ray.Direction, params)
		return raycast_result and raycast_result.Instance
	end,

	Hit = function(): CFrame
		local ray, raycast_result = raycast()
		local intersection = raycast_result and raycast_result.Position or ray.Origin + ray.Direction*1000

		return CFrame.new(intersection, camera.CFrame.Position)
	end,

	Position = function(): Vector2
		return UserInputService:GetMouseLocation()
	end,

	Delta = function(): Vector2
		return UserInputService:GetMouseDelta()
	end,

	Origin = function(): CFrame
		local camera_position = camera.CFrame.Position
		local mouse_position = PlayerMouse2.Hit.Position
		local forward = (camera_position - mouse_position).Unit
		local up = Vector3.new(0, 1, 0)
		local right = forward:Cross(up)
		up = right:Cross(forward)

		return CFrame.fromMatrix(camera_position, -right, up, forward)
	end,

	UnitRay = function(): Ray
		return Ray.new(camera.CFrame.Position, (PlayerMouse2.Hit.Position - camera.CFrame.Position).Unit)
	end,

	Normal = function(): Vector3
		local raycast_result = select(2, raycast())
		return raycast_result and raycast_result.Normal or Vector3.new()
	end
}

UserInputService.InputBegan:Connect(function(input: InputObject, engine_processed: boolean)
	if engine_processed then
		return
	end

	if input.UserInputState == Enum.UserInputState.Begin then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			real_events.LeftPressed:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			real_events.RightPressed:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			real_events.WheelPressed:Fire()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, engine_processed: boolean)
	if engine_processed then
		return
	end

	if input.UserInputState == Enum.UserInputState.End then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			real_events.LeftClicked:Fire()
			real_events.LeftReleased:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			real_events.RightClicked:Fire()
			real_events.RightReleased:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			real_events.WheelClicked:Fire()
			real_events.WheelReleased:Fire()
		end
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject, engine_processed: boolean)
	if engine_processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement then
		real_events.Moved:Fire(properties.Delta())
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		real_events.WheelScrolled:Fire(input.Position.Z)
	end
end)

setmetatable(PlayerMouse2, {
	__index = function(_, key: string): any
		local f = properties[key]

		if f then
			return f()
		end

		error(string.format("%s is invalid", key))
	end,

	__newindex = function(_, key: string, value: any)
		local f = writable_properties[key]

		if f then
			f(value)
		else
			error(string.format("%s is invalid/readonly", key))
		end
	end
})

return PlayerMouse2 :: {
	LeftPressed: RBXScriptSignal,
	LeftClicked: RBXScriptSignal,
	LeftReleased: RBXScriptSignal,
	RightPressed: RBXScriptSignal,
	RightClicked: RBXScriptSignal,
	RightReleased: RBXScriptSignal,
	Moved: RBXScriptSignal,
	WheelScrolled: RBXScriptSignal,
	WheelReleased: RBXScriptSignal,
	WheelPressed: RBXScriptSignal,
	WheelClicked: RBXScriptSignal,

	IconEnabled: boolean,
	Sensitivity: number,
	Target: BasePart?,
	Hit: CFrame,
	Position: Vector2,
	Delta: Vector2,
	Origin: CFrame,
	UnitRay: Ray,
	Normal: Vector3,
	TargetFilter: { Instance? }
}
