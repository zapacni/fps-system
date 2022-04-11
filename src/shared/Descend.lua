local function Descend(instance: Instance, ...: string): Instance
	local names = { ... }
	local current = instance

	for _, name in ipairs(names) do
		current = assert(
			instance:FindFirstChild(name),
			string.format("%s is not a valid member of %s", name, current:GetFullName())
		)
	end
	return current
end

return Descend