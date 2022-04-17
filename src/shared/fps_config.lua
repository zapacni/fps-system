local fps_config = {
	sounds = {
		explosion = "rbxasseid://9114362251",
		default_break = "rbxassetid://6700552345",
	},

	keybinds = {
		reload = Enum.KeyCode.R,
		admire = Enum.KeyCode.H,
		second_aim = Enum.KeyCode.Q,
	},

	bullets = {
		impact_lifetime = 2,
		leave_impact = true,
	},

	explosions = {
		radius_multiplier = 2,
		time_between = 0.2,
	},
}

return fps_config