local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local server_modules = script.Parent:WaitForChild("Server")
local shared_modules = ReplicatedStorage:WaitForChild("Shared")

local explode_object = require(server_modules:WaitForChild("explode_object"))
local fracture_part = require(server_modules:WaitForChild("fracture_part"))
local FastCast = require(shared_modules:WaitForChild("FastCast"))
local Descend = require(shared_modules:WaitForChild("Descend"))

local weapons = Descend(ReplicatedStorage, "Weapons")
local remotes = Descend(ReplicatedStorage, "Remotes")
local remote_events = Descend(remotes, "RemoteEvents")
local real_weapons = Descend(weapons, "Real")

local bullet_template = Descend(ReplicatedStorage, "FpsSystemAssets"):WaitForChild("BulletTemplate")

local neck_c0 = CFrame.new(0, 0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local waist_c0 = CFrame.new(0, 0.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local right_shoulder_c0 = CFrame.new(1, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local left_shoulder_c0 = CFrame.new(-1, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

Descend(remote_events, "UpdateCharacter").OnServerEvent:Connect(function(player, theta)
	if typeof(theta) ~= "number" then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()

	local neck = Descend(character, "Head"):WaitForChild("Neck") :: Motor6D
	local waist = Descend(character, "UpperTorso"):WaitForChild("Waist") :: Motor6D
	local right_shoulder = Descend(character, "RightUpperArm"):WaitForChild("RightShoulder") :: Motor6D
	local left_shoulder = Descend(character, "LeftUpperArm"):WaitForChild("LeftShoulder") :: Motor6D

	neck.C0 = neck_c0 * CFrame.fromEulerAnglesYXZ(theta * 0.5, 0, 0)
	waist.C0 = waist_c0 * CFrame.fromEulerAnglesYXZ(theta * 0.5, 0, 0)
	right_shoulder.C0 = right_shoulder_c0 * CFrame.fromEulerAnglesYXZ(theta * 0.5, 0, 0)
	left_shoulder.C0 = left_shoulder_c0 * CFrame.fromEulerAnglesYXZ(theta * 0.5, 0, 0)
end)

Descend(remote_events, "Aim").OnServerEvent:Connect(function(player, is_aiming)
	local character = player.Character
	local weapon = character:FindFirstChildOfClass("Model")
	local humanoid = Descend(character, "Humanoid")
	local animator = Descend(humanoid, "Animator") :: Animator

	if weapon then
		if is_aiming then
			animator:LoadAnimation(Descend(weapon, "Animations"):WaitForChild("Aim")):Play()
		else
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Name == "Aim" then
					track:Stop()
					track:Destroy()
				end
			end
		end
	end
end)

local guns = { }

Descend(remote_events, "Equip").OnServerEvent:Connect(function(player, weapon_name)
	weapon_name = tostring(weapon_name)

	local character = player.Character

	if not character then
		return
	end

	local motor = Instance.new("Motor6D")

	motor.Name = "Weapon"
	motor.Part0 = Descend(character, "RightHand")
	motor.Parent = motor.Part0

	local weapon = real_weapons:FindFirstChild(weapon_name)

	if weapon then
		weapon = weapon:Clone()
		weapon.Parent = character
		motor.Part1 = weapon.PrimaryPart
		Descend(
			character, "Humanoid"
		):WaitForChild("Animator"):LoadAnimation(Descend(weapon, "Animations"):WaitForChild("Idle")):Play()
		Descend(weapon, "Shoot"):WaitForChild("Flash").PlayerToHideFrom = player
	end

	local caster = FastCast.new()
	local behavior = FastCast.newBehavior()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { character, Descend(Workspace, "FpsBullets") }

	behavior.RaycastParams = params
	behavior.Acceleration = Vector3.new(0, -Workspace.Gravity, 0)
	behavior.MaxDistance = weapon:GetAttribute("Distance")

	local damage = weapon:GetAttribute("Damage")

	guns[player] = {
		caster = caster,
		behavior = behavior,
		connections = {
			caster.RayHit:Connect(function(_, result: RaycastResult)
				local part = result.Instance
				local hit_humanoid = part.Parent:FindFirstChildOfClass("Humanoid")

				if hit_humanoid then
					local multiplier = if part.Name == "Head" then weapon:GetAttribute("HeadshotMultiplier") else 1
					hit_humanoid:TakeDamage(damage * multiplier)
				end

				if part:GetAttribute("Breakable") then
					fracture_part(part, result.Position, character:GetPivot().LookVector * 50, 5)
				end

				if part.Parent and (part:GetAttribute("Explosive") or part.Parent:GetAttribute("Explosive")) then
					explode_object(part)
				end
			end),

			caster.LengthChanged:Connect(function(_, origin: Vector3, direction: Vector3, length: number)
				local offset = length - bullet_template.Size.Z / 2

				for _, other_player in ipairs(Players:GetPlayers()) do
					if player == other_player then
						continue
					end

					Descend(remote_events, "Shoot"):FireClient(
						other_player,
						{
							cf = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -offset),
							bullet_id = HttpService:GenerateGUID(),
							sound_id = Descend(weapon, "Shoot", "Fire").SoundId,
							weapon = weapon
						}
					)
				end
			end),

			caster.CastTerminating:Connect(function(cast)
				local bullet = cast.RayInfo.CosmeticBulletObject

				if bullet then
					bullet:Destroy()
				end
			end)
		}
	}
end)

Descend(remote_events, "Unequip").OnServerEvent:Connect(function(player)
	local character = player.Character
	local motor = Descend(character, "RightHand"):WaitForChild("Weapon")

	if motor then
		motor:Destroy()
	end

	local weapon = character:FindFirstChildOfClass("Model")

	if weapon then
		local animator = Descend(character, "Humanoid"):WaitForChild("Animator") :: Animator

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if Descend(weapon, "Animations"):FindFirstChild(track.Name) then
				track:Stop()
				track:Destroy()
			end
		end

		weapon:Destroy()
	end

	if guns[player] then
		for _, connection in ipairs(guns[player].connections :: { RBXScriptConnection }) do
			connection:Disconnect()
		end

		guns[player] = nil
	end

	-- Descend(character, "Humanoid").WalkSpeed = 16
end)

Descend(remote_events, "Shoot").OnServerEvent:Connect(function(player, position)
	if typeof(position) ~= "Vector3" then
		return
	end

	local character = player.Character

	if not character then
		return
	end

	local weapon = character:FindFirstChildOfClass("Model")

	if not weapon then
		return
	end

	local origin = Descend(weapon, "Shoot").Position
	local unscaled_direction = (position - origin).Unit
	local direction =  unscaled_direction * weapon:GetAttribute("Distance")
	local gun = guns[player]

	gun.caster:Fire(origin, direction, weapon:GetAttribute("Speed"), gun.behavior)

	coroutine.wrap(function()
		local flash = Descend(weapon, "Shoot"):WaitForChild("Flash") :: BillboardGui
		local shoot_track = Descend(character, "Humanoid"):WaitForChild("Animator"):LoadAnimation(
			Descend(weapon, "Animations"):WaitForChild("Shoot")
		)

		shoot_track:Play()
		flash.Enabled = true
		task.wait(0.05)
		flash.Enabled = false
		shoot_track:Stop()
	end)()
end)

Descend(remote_events, "Reload").OnServerEvent:Connect(function(player)
	local character = player.Character

	if not character then
		return
	end

	local weapon = character:FindFirstChildOfClass("Model")

	if not weapon then
		return
	end

	if weapon:GetAttribute("Ammo") then
		local needed_ammo = weapon:GetAttribute("MaxAmmo") - weapon:GetAttribute("Ammo")
		weapon:SetAttribute("ClipAmmo", needed_ammo)
		weapon:SetAttribute("Ammo", weapon:GetAttribute("MaxAmmo"))

		if weapon:GetAttribute("ClipAmmo") < 0 then
			-- without this check the clip/reserve ammo could go negative,
			-- so this just adds it back to the ammo and then sets it back to 0
			weapon:SetAttribute("Ammo", weapon:GetAttribute("Ammo") + weapon:GetAttribute("ClipAmmo"))
			weapon:SetAttribute("ClipAmmo", 0)
		end
	end
end)