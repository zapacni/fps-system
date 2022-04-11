-- adapted from https://devforum.roblox.com/t/simple-break-glass-system/1415593

local wedge = Instance.new("WedgePart")
wedge.Anchored = true
wedge.TopSurface = Enum.SurfaceType.Smooth
wedge.BottomSurface = Enum.SurfaceType.Smooth

local Workspace = game:GetService("Workspace")
local break_sounds = require(script.Parent:WaitForChild("break_sounds"))

local function draw_triangle(a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)

	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end

	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit

	local height = math.abs(ab:Dot(up))

	local w1 = wedge:Clone()
	w1.Size = Vector3.new(0, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b)/2, right, up, back)

	local w2 = wedge:Clone()
	w2.Size = Vector3.new(0, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c)/2, -right, up, -back)

	return w1, w2
end

local function fracture_part(part: BasePart, center: Vector3, impulse: Vector3, lifetime: number)
	local cs, cf = part.Size, part.CFrame
	local transparency = part.Transparency
	local material = part.Material
	local reflectance = part.Reflectance
	local points = {}

	if cs.Z > cs.X then
		points = {
			cf * CFrame.new(0, cs.Y * .5, cs.Z * .5);
			cf * CFrame.new(0, cs.Y * .5, 0);
			cf * CFrame.new(0, cs.Y * .5, -cs.Z * .5);
			cf * CFrame.new(0, 0, -cs.Z * .5);
			cf * CFrame.new(0, -cs.Y * .5, -cs.Z * .5);
			cf * CFrame.new(0, -cs.Y * .5, 0);
			cf * CFrame.new(0, -cs.Y * .5, cs.Z * .5);
			cf * CFrame.new(0, 0, cs.Z * .5);
		}
	else
		points = {
			cf * CFrame.new(cs.X * .5, cs.Y * .5, 0);
			cf * CFrame.new(0, cs.Y * .5, 0);
			cf * CFrame.new(-cs.X * .5, cs.Y * .5, 0);
			cf * CFrame.new(-cs.X * .5, 0, 0);
			cf * CFrame.new(-cs.X * .5, -cs.Y * .5, 0);
			cf * CFrame.new(0, -cs.Y * .5, 0);
			cf * CFrame.new(cs.X * .5, -cs.Y * .5, 0);
			cf * CFrame.new(cs.X * .5, 0, 0);
		}
	end

	local sound = Instance.new("Sound")
	sound.SoundId = break_sounds.get_sound_for_part(part) or "rbxassetid://6700552345"
	sound.Volume = 1
	sound.PlayOnRemove = true
	sound.Parent = part

	part:Destroy()

	for i, v in pairs(points) do
		local nxt = points[i + 1]

		if nxt == nil then
			nxt = points[1]
		end

		local w0, w1 = draw_triangle(v.p, nxt.p, center)
		w0.Anchored = false
		w1.Anchored = false

		w0.Transparency = transparency
		w1.Transparency = transparency

		w0.Color = part.Color
		w1.Color = part.Color

		w0.Material = material
		w0.Reflectance = reflectance

		w1.Material = material
		w1.Reflectance = reflectance

		w0:ApplyImpulse(impulse)
		w1:ApplyImpulse(impulse)

		w0.Parent = Workspace
		w1.Parent = Workspace

		task.delay(lifetime, function()
			w0:Destroy()
			w1:Destroy()
		end)
	end
end

return fracture_part