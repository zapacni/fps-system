local Workspace = game:GetService("Workspace")

local fracture_part = require(script.Parent:WaitForChild("fracture_part"))

local function explode_object(part: BasePart)
	if not part.Parent then
		return
	end

	local destructiveness = part:GetAttribute("Destructiveness")
	local explosion = Instance.new("Explosion")
	explosion.BlastRadius = 2 * part.Size.Magnitude
	explosion.DestroyJointRadiusPercent = destructiveness
	explosion.Position = part.Position

	explosion.Hit:Connect(function(hit_part, distance)
		if not (hit_part and hit_part.Parent) then
			return
		end

		if hit_part:GetAttribute("Breakable") then
			fracture_part(hit_part, hit_part.Position, hit_part.CFrame.LookVector * (distance / 2), 5)
		end

		if hit_part:GetAttribute("Explosive") then
			task.wait(0.2)
			explode_object(hit_part)
		end
	end)

	explosion.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasseid://9114362251"
	sound.PlayOnRemove = true
	sound.Parent = part
	part:Destroy()
end

return explode_object