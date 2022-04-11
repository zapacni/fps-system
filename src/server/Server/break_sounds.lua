local CollectionService = game:GetService("CollectionService")

local break_sounds; break_sounds = {
	get_sound_for_part = function(part: BasePart): string?
		local sound_id

		for name, id in pairs(break_sounds.materials) do
			if CollectionService:HasTag(part, name) then
				sound_id = id
			end
		end
		return sound_id
	end,

	materials = {
		Glass = "rbxassetid://2596202821",
		Wood = "rbxassetid://4988580646",
		WoodPlanks = "rbxassetid://4988580646"
	},
}

return break_sounds
