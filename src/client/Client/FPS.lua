--!strict
---@diagnostic disable: redefined-local

--[[
	This would be difficult if not impossible without the following references:
	https://devforum.roblox.com/t/making-an-fps-framework-2020-edition/503318
	https://devforum.roblox.com/t/making-an-fps-framework-2020-edition-part-2/581791
	https://devforum.roblox.com/t/the-first-person-element-of-a-first-person-shooter/160434/
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local shared_modules = ReplicatedStorage:WaitForChild("Shared")

local Spring = require(shared_modules:WaitForChild("Spring"))
local random_vector_offset = require(shared_modules:WaitForChild("random_vector_offset"))
local PlayerMouse2 = require(script.Parent:WaitForChild("PlayerMouse2"))
local FastCast = require(shared_modules:WaitForChild("FastCast"))
local Descend = require(shared_modules:WaitForChild("Descend"))
local Fusion = require(script.Parent:WaitForChild("Fusion"))
local fps_config = require(shared_modules:WaitForChild("fps_config"))

local client = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local remotes = Descend(ReplicatedStorage, "Remotes")
local remote_events = Descend(remotes, "RemoteEvents")

local MOVEMENT_SPEED = 1
local MODIFIER = 0.05

local function lerp(start: number, goal: number, alpha: number): number
	return start + (goal - start) * alpha
end

local function get_bobbing(addition: number, speed: number, modifier: number): number
	return math.sin(os.clock() * addition * speed) * modifier
end

local function create_ui(fps: FPS): ScreenGui
	return Fusion.New "ScreenGui" {
		Name = "FpsGui",
		Parent = Descend(client, "PlayerGui"),

		[Fusion.Children] = {
			Fusion.New "Frame" {
				Name = "Container",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.75, 0.75),
				Size = UDim2.fromScale(0.2, 0.15),

				[Fusion.Children] = {
					Fusion.New "TextLabel" {
						Name = "WeaponName",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.25),
						Text = fps.weapon.Name,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0
					},

					Fusion.New "Frame" {
						Name = "Divider",
						Position = UDim2.fromScale(0, 0.25),
						Size = UDim2.fromScale(1, 0.025)
					},

					Fusion.New "TextLabel" {
						Name = "AmmoDisplay",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.25),
						Size = UDim2.fromScale(1, 0.5),
						Text = fps.weapons[fps.weapon.Name].fusion.computed,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0
					}
				}
			}
		}
	}
end

local function set_weapons(fps: FPS, weapon: Model)
	local data = { }
	data.attributes = weapon:GetAttributes()
	data.fusion = { }
	data.fusion.value = Fusion.Value(weapon:GetAttribute("Ammo"))
	data.fusion.computed = Fusion.Computed(function()
		return string.format("%d / %d", data.fusion.value:get(), weapon:GetAttribute("ReserveAmmo"))
	end)

	fps.weapons[weapon.Name] = data
end

local FPS = { }
FPS.__index = FPS

function FPS.new(view_model: Model): FPS
	local self = setmetatable({ }, FPS)

	self.view_model = view_model:Clone()
	self.is_aiming = false
	self.is_equipped = false
	self.is_reloading = false
	self.is_running = false
	self.is_admiring = false
	self.aim_count = 0

	self.bobbing = Spring.new(Vector3.new())
	self.bobbing.Damper = 0.8
	self.bobbing.Speed = 8

	self.sway = Spring.new(Vector3.new())
	self.sway.Damper = 0.8
	self.sway.Speed = 8

	self.recoil = Spring.new(Vector3.new())
	self.recoil.Damper = 0.8
	self.recoil.Speed = 8

	self.gun_info = {
		caster = FastCast.new(),
		behavior = FastCast.newBehavior(),
		connections = { }
	}
	self.weapons = { }

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {
		client.Character,
		self.view_model,
		Workspace:WaitForChild("FpsBullets")
	}

	self.gun_info.behavior.RaycastParams = params
	self.gun_info.behavior.Acceleration = Vector3.new(0, -Workspace.Gravity, 0)
	self.gun_info.behavior.CosmeticBulletContainer = Workspace:WaitForChild("FpsBullets")
	self.gun_info.behavior.CosmeticBulletTemplate = Descend(
		ReplicatedStorage, "FpsSystemAssets"
	):WaitForChild("BulletTemplate")

	self.view_model.Parent = camera
	table.insert(PlayerMouse2.TargetFilter, self.view_model)

	Descend(self.view_model, "Humanoid"):WaitForChild("Animator").AnimationPlayed:Connect(function(animation)
		animation.KeyframeReached:Connect(function(keyframe)
			local descendant = self.weapon:FindFirstChild(keyframe, true)

			if descendant and descendant:IsA("Sound") then
				SoundService:PlayLocalSound(descendant)
			end
		end)
	end)

	return self
end

function FPS:update(dt: number)
	if not (self.is_equipped and client.Character and client.Character.PrimaryPart) then
		return
	end

	local character = client.Character
	local humanoid = Descend(character, "Humanoid") :: Humanoid
	local move_vector = character.PrimaryPart.AssemblyLinearVelocity
	local velocity = if move_vector.Magnitude > 0.1 then
		move_vector
	else
		Vector3.new(math.random(), math.random(), math.random()) / 5
	local movement_sway = Vector3.new(
		get_bobbing(10 * (humanoid.WalkSpeed / 16), MOVEMENT_SPEED, MODIFIER),
		get_bobbing(5 * (humanoid.WalkSpeed / 16), MOVEMENT_SPEED, MODIFIER),
		get_bobbing(5 * (humanoid.WalkSpeed / 16), MOVEMENT_SPEED, MODIFIER)
	) * (if self.is_aiming then 0.5 else 1)

	local delta = PlayerMouse2.Delta * dt * 60

	if self.is_aiming then
		delta *= 0.1
	end

	self.sway:Impulse(Vector3.new(delta.X * 0.0025, delta.Y * 0.005, 0))
	self.bobbing:Impulse((movement_sway / 25) * dt * 60 * velocity.Magnitude)

	camera.CFrame *= CFrame.Angles(self.recoil.Position.X, self.recoil.Position.Y, self.recoil.Position.Z)
	camera.CFrame *= CFrame.Angles(self.bobbing.Position.X * 0.05, self.bobbing.Position.Y * 0.05, 0)

	self.view_model:PivotTo(camera.CFrame * CFrame.new(self.weapon:GetAttribute("Offset")))
	self.view_model:PivotTo(
		self.view_model:GetPivot() * CFrame.Angles(
			self.bobbing.Position.X,
			self.bobbing.Position.Y,
			0
		)
	)

	self.view_model:PivotTo(self.view_model:GetPivot() * CFrame.Angles(0, -self.sway.Position.X, self.sway.Position.Y))
	self.view_model:PivotTo(
		self.view_model:GetPivot() * CFrame.Angles(
			0,
			self.bobbing.Position.Y / 2,
			self.bobbing.Position.X / 2
		)
	)

	self.view_model.PrimaryPart.CFrame *= CFrame.new(-self.sway.Position.X, self.sway.Position.Y, 0)
end

function FPS:update_server()
	if self.is_equipped then
		Descend(remote_events, "UpdateCharacter"):FireServer(math.asin(camera.CFrame.LookVector.Y))
	end
end

function FPS:aim_down_sights(state: "start" | "stop")
	if self.is_admiring or self.is_reloading or not self.weapon or not self.weapon.PrimaryPart then
		return
	end

	local is_aiming = state == "start"
	self.is_aiming = is_aiming

	local start = self.weapon:GetAttribute("Offset") :: Vector3
	local start_fov = camera.FieldOfView
	local goal = (if is_aiming then
		self.weapon:GetAttribute("AimOffset")
	else
		self.weapon:GetAttribute("DefaultOffset")
	) :: Vector3

	local goal_fov = if is_aiming then self.weapon:GetAttribute("ZoomDistance") else 70

	self.aim_count += 1
	local current = self.aim_count

	Descend(remote_events, "Aim"):FireServer(is_aiming)
	PlayerMouse2.Sensitivity = if is_aiming then 0.1 else 1

	for i = 0, 101, 5 do
		if current ~= self.aim_count then
			break
		end

		self.bobbing:TimeSkip(RunService.RenderStepped:Wait())
		self.weapon:SetAttribute("Offset", start:Lerp(goal, i / 100))
		camera.FieldOfView = lerp(start_fov, goal_fov, i / 100)
	end

	self.bobbing.Damper = if is_aiming then 2 else 0.8
end

function FPS:equip(weapon: Model)
	if self.weapon then
		self:aim_down_sights("stop")
		self:unequip()
	end

	weapon = weapon:Clone()

	local data = self.weapons[weapon.Name]

	if data then
		local attributes = data.attributes

		for name, value in pairs(attributes) do
			weapon:SetAttribute(name, value)
		end
	end

	self.weapon = weapon
	self.weapon.Parent = self.view_model
	self.gun_info.connections = {
		self.gun_info.caster.RayHit:Connect(function(_, result: RaycastResult)
			local part = result.Instance
			if not part.Parent:FindFirstChildOfClass("Humanoid") and fps_config.bullets.leave_impact then
				local impact_part = Descend(ReplicatedStorage, "FpsSystemAssets"):WaitForChild("BulletHole"):Clone()
				local offset = Vector3.new(0, -impact_part.Size.Y / 2, 0)

				impact_part.CFrame = CFrame.lookAt(result.Position, result.Position + result.Normal + offset)
				impact_part.Color = part.Color
				impact_part.Parent = Descend(Workspace, "FpsBullets")

				Descend(impact_part, "Decal").Color3 = part.Color
				Descend(impact_part, "WeldConstraint").Part1 = part

				local particle = Descend(impact_part, "Debris") :: ParticleEmitter
				particle.Color = ColorSequence.new(part.Color)
				particle.Acceleration = result.Normal * 10 + Vector3.new(0, -50, 0)
				particle:Emit(particle.Rate)

				local params = self.gun_info.behavior.RaycastParams
				local filter = params.FilterDescendantsInstances

				table.insert(filter, impact_part)
				params.FilterDescendantsInstances = filter

				coroutine.wrap(function()
					task.wait(fps_config.bullets.impact_lifetime)
					impact_part:Destroy()

					local _filter = params.FilterDescendantsInstances
					table.remove(_filter, table.find(_filter, impact_part) or 0)
					params.FilterDescendantsInstances = _filter
				end)()
			end
		end),

		self.gun_info.caster.LengthChanged:Connect(function(
			_, origin: Vector3, direction: Vector3, length: number, _, bullet: BasePart
		)
			if not bullet then
				return
			end

			local offset = length - bullet.Size.Z / 2
			bullet.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -offset)
		end),

		self.gun_info.caster.CastTerminating:Connect(function(cast)
			local bullet = cast.RayInfo.CosmeticBulletObject

			if bullet and bullet.Parent then
				bullet:Destroy()
			end
		end)
	}

	Descend(remote_events, "Equip"):FireServer(weapon.Name)
	Descend(self.view_model.PrimaryPart, "Weapon").Part1 = self.weapon.PrimaryPart
	Descend(self.view_model, "Humanoid"):WaitForChild("Animator"):LoadAnimation(
		Descend(self.weapon, "Animations"):WaitForChild("Idle")
	):Play(0)

	weapon:SetAttribute("Offset", weapon:GetAttribute("DefaultOffset"))
	set_weapons(self, weapon)
	create_ui(self)
	self.is_equipped = true
end

function FPS:unequip()
	if self.is_aiming then
		self:aim_down_sights("stop")
	end

	local ui = Descend(client, "PlayerGui"):FindFirstChild("FpsGui")

	if ui then
		ui:Destroy()
	end

	Descend(remote_events, "Unequip"):FireServer()

	local weapon = self.weapon

	if weapon then
		weapon:SetAttribute("Offset", weapon:GetAttribute("DefaultOffset"))
		set_weapons(self, weapon)
		weapon:Destroy()
		Descend(self.view_model.PrimaryPart, "Weapon").Part1 = nil
		self.weapon = nil
	end

	local tracks = Descend(
		self.view_model, "Humanoid"
	):WaitForChild("Animator"):GetPlayingAnimationTracks() :: { AnimationTrack }

	for _, track in ipairs(tracks) do
		if track.Name == "Idle" then
			track:Stop(0)
			track:Destroy()
		end
	end

	for _, connection in ipairs(self.gun_info.connections) do
		connection:Disconnect()
	end

	table.clear(self.gun_info.connections)

	self.is_equipped = false
end

function FPS:line_of_sight_blocked(): boolean
	-- player should not be able to shoot the gun if they can't see the barrel
	local origin = camera.CFrame.Position
	local direction = (Descend(self.weapon, "Shoot").Position - origin).Unit * 10

	local ignore = { client.Character }

	for _, child in pairs(self.view_model:GetDescendants()) do
		if child:IsA("BasePart") and child.Name ~= "Shoot" then
			table.insert(ignore, child)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignore

	local result = Workspace:Raycast(origin, direction, params)

	return if result then result.Instance.Name ~= "Shoot" else true
end

function FPS:shoot()
	local weapon = self.weapon

	if not weapon --[[or self:line_of_sight_blocked()]] then
		return
	end

	local ammo = weapon:GetAttribute("Ammo")
	local recoil = weapon:GetAttribute("Recoil")

	if self.is_admiring or self.is_reloading or ammo <= 0 then
		return
	end

	local origin = Descend(weapon, "Shoot").Position
	local direction = (PlayerMouse2.Hit.Position - origin).Unit * weapon:GetAttribute("Distance")

	local function fire_cast()
		self.gun_info.caster:Fire(
			origin,
			if weapon:GetAttribute("Spread") then
				random_vector_offset(direction, weapon:GetAttribute("SpreadAngle"))
			else
				direction,
			weapon:GetAttribute("Speed"),
			self.gun_info.behavior
		)
	end

	if weapon:GetAttribute("Spread") then
		for _ = 1, ammo do
			fire_cast()
		end
	else
		fire_cast()
	end

	local shoot_part = Descend(weapon, "Shoot")
	local fire = Descend(weapon.PrimaryPart, "Fire") :: Sound
	local flash = Descend(shoot_part, "Flash") :: ParticleEmitter

	local shoot_track = Descend(self.view_model, "Humanoid"):WaitForChild("Animator"):LoadAnimation(
		Descend(weapon, "Animations"):WaitForChild("Shoot")
	) :: AnimationTrack

	shoot_track:Play(0)
	Descend(remote_events, "Shoot"):FireServer(PlayerMouse2.Hit.Position)
	SoundService:PlayLocalSound(fire)

	flash:Emit(flash.Rate)

	task.spawn(function()
		self.recoil:Impulse(if self.is_aiming then recoil / 2 else recoil)
		task.wait(0.05)
		self.recoil:Impulse(-(if self.is_aiming then recoil / 2 else recoil))
	end)

	self.weapons[weapon.Name].fusion.value:set(self.weapons[weapon.Name].fusion.value:get() - 1)
	weapon:SetAttribute("Ammo", self.weapons[weapon.Name].fusion.value:get())
end

function FPS:reload()
	if not self.weapon or not self.weapon:GetAttribute("Ammo") or self.is_admiring or self.is_reloading then
		return
	end

	if self.is_aiming then
		self:aim_down_sights("stop")
	end

	local animation = Descend(self.view_model, "Humanoid"):WaitForChild("Animator"):LoadAnimation(
		Descend(
			self.weapon, "Animations"
		):WaitForChild("Reload" .. (if self.weapon:GetAttribute("Ammo") > 0 then "" else "Empty"))
	) :: AnimationTrack

	self.is_reloading = true
	animation:Play(0)
	animation.Stopped:Wait()
	Descend(remote_events, "Reload"):FireServer()

	local needed_ammo = self.weapon:GetAttribute("MaxAmmo") - self.weapon:GetAttribute("Ammo")
	self.weapon:SetAttribute("ReserveAmmo", self.weapon:GetAttribute("ReserveAmmo") - needed_ammo)
	self.weapon:SetAttribute("Ammo", self.weapon:GetAttribute("MaxAmmo"))

	if self.weapon:GetAttribute("ReserveAmmo") < 0 then
		-- without this check the clip/reserve ammo could go negative,
		-- so this just adds it back to the ammo and then sets it back to 0
		self.weapon:SetAttribute("Ammo", self.weapon:GetAttribute("Ammo") + self.weapon:GetAttribute("ReserveAmmo"))
		self.weapon:SetAttribute("ReserveAmmo", 0)
	end

	self.weapons[self.weapon.Name].fusion.value:set(self.weapon:GetAttribute("Ammo"))
	self.is_reloading = false
end

function FPS:admire_weapon()
	local view_model, weapon = self.view_model, self.weapon

	if self.is_admiring or not (view_model or weapon) then
		return
	end

	self.is_admiring = true
	local admire_track = Descend(self.view_model, "Humanoid"):WaitForChild("Animator"):LoadAnimation(
		Descend(weapon, "Animations"):WaitForChild("Admire")
	) :: AnimationTrack

	admire_track:Play(0)
	admire_track.Stopped:Wait()
	self.is_admiring = false
end

type FPS = {
	view_model: Model,
	weapon: Model,
	aim_count: number,
	is_aiming: boolean,
	is_equipped: boolean,
	is_reloading: boolean,
	is_running: boolean,
	is_admiring: boolean,
	sway: Spring.Spring,
	bobbing: Spring.Spring,
	recoil: Spring.Spring,
	gun_info: {
		caster: FastCast.Caster,
		behavior: FastCast.FastCastBehavior,
		connections: { RBXScriptConnection }
	},
	weapons: { [string]: { [string]: any } },

	update: (self: FPS, dt: number) -> (),
	update_server: (self: FPS, dt: number) -> (),
	aim_down_sights: (self: FPS, state: "start" | "stop") -> (),
	equip: (self: FPS, weapon: Model) -> (),
	unequip: (self: FPS) -> (),
	shoot: (self: FPS) -> (),
	reload: (self: FPS) -> (),
	admire_weapon: (self: FPS) -> (),
	line_of_sight_blocked: (self: FPS) -> (boolean),
}

return FPS