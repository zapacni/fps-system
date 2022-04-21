local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local shared_modules = ReplicatedStorage:WaitForChild("Shared")

local Descend = require(shared_modules:WaitForChild("Descend"))
local FPS = require(script.Parent:WaitForChild("Client"):WaitForChild("FPS"))
local fps_config = require(shared_modules:WaitForChild("fps_config"))

local client = Players.LocalPlayer

local weapons_folder = Descend(ReplicatedStorage, "Weapons"):WaitForChild("Viewmodel")
local fps = FPS.new(Descend(ReplicatedStorage, "Viewmodel") :: Model)
local count = 0
local shooting = false
local aiming = false
local q_aiming = false
-- local ui = fps:create_character_ui(player_gui)

local function shoot()
	if fps.weapon:GetAttribute("Ammo") <= 0 then
		return
	end

	shooting = true
	Descend(client.Character, "Humanoid").WalkSpeed /= 2
	fps:shoot()
	task.wait(60 / fps.weapon:GetAttribute("FireRate"))
	Descend(client.Character, "Humanoid").WalkSpeed *= 2
	shooting = false
end

RunService.RenderStepped:Connect(function(dt)
	fps:update(dt)
end)

UserInputService.InputBegan:Connect(function(input, engine_processed)
	if engine_processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 and not q_aiming then
		aiming = true
		Descend(client.Character, "Humanoid").WalkSpeed /= 2
		fps:aim_down_sights("start")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local weapon = fps.weapon

		if not weapon then
			return
		end

		if not shooting then
			if fps.weapon:GetAttribute("Automatic") then
				while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
					shoot()
				end
			else
				shoot()
			end
		end
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		if
			input.KeyCode == fps_config.keybinds.second_aim and
			not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		then
			q_aiming = not q_aiming
			aiming = not aiming
			Descend(client.Character, "Humanoid").WalkSpeed /= if q_aiming then 2 else 0.5
			fps:aim_down_sights(if aiming then "start" else "stop")
		elseif input.KeyCode == fps_config.keybinds.reload then
			fps:reload()
		elseif input.KeyCode == fps_config.keybinds.admire then
			fps:admire_weapon()
		end

		local _count = tonumber(UserInputService:GetStringForKeyCode(input.KeyCode))

		if _count and _count <= #weapons_folder:GetChildren() then
			count = _count
			fps:equip(weapons_folder:GetChildren()[count])
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, engine_processed)
	if engine_processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if count >= #weapons_folder:GetChildren() or count < 0 then
			count = 0
		end

		fps:equip(weapons_folder:GetChildren()[count + 1])
		count -= input.Position.Z
	end
end)

UserInputService.InputEnded:Connect(function(input, engine_processed)
	if engine_processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 and not q_aiming then
		aiming = false
		Descend(client.Character, "Humanoid").WalkSpeed *= 2
		fps:aim_down_sights("stop")
	end
end)

RunService.Heartbeat:Connect(function()
	fps:update_server()
end)
