local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared_modules = ReplicatedStorage:WaitForChild("Shared")

local fracture_part = require(script.Parent:WaitForChild("fracture_part"))
local fps_config = require(shared_modules:WaitForChild("fps_config"))

local function explode_object(part: BasePart)
	if not part.Parent then
		return
	end

	local destructiveness = part:GetAttribute("Destructiveness")
	local explosion = Instance.new("Explosion")
	explosion.BlastRadius = fps_config.explosions.radius_multiplier * part.Size.Magnitude
	explosion.DestroyJointRadiusPercent = destructiveness
	explosion.Position = part.Position

	explosion.Hit:Connect(function(hit_part, distance)
		if not (hit_part and hit_part.Parent) then
			return
		end

		if hit_part:GetAttribute("Breakable") then
			fracture_part(hit_part, nil, hit_part.CFrame.LookVector * distance)
		end

		if hit_part:GetAttribute("Explosive") then
			task.wait(fps_config.explosions.time_between)
			explode_object(hit_part)
		end
	end)

	explosion.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = fps_config.sounds.explosion
	sound.PlayOnRemove = true
	sound.Parent = part
	part:Destroy()
end

return explode_object