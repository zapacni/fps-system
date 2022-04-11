local rng = Random.new()

local function random_vector_offset(vector: Vector3, max_angle: number): Vector3
	return (
		CFrame.lookAt(Vector3.zero, vector)
		* CFrame.Angles(0, 0, rng:NextNumber(0, 2 * max_angle))
		* CFrame.Angles(math.acos(rng:NextNumber(math.cos(max_angle), 1)), 0, 0)
	).LookVector
end

return random_vector_offset
