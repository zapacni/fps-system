local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared_modules = ReplicatedStorage:WaitForChild("Shared")

local Descend = require(shared_modules:WaitForChild("Descend"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote_events = remotes:WaitForChild("RemoteEvents")

local bullet_template = Descend(ReplicatedStorage, "FpsSystemAssets"):WaitForChild("BulletTemplate")
local bullets_folder = Workspace:WaitForChild("FpsBullets")

Descend(remote_events, "Shoot").OnClientEvent:Connect(function(
	info: { cf: CFrame, bullet_id: string, weapon: Model }
)

	coroutine.wrap(function()
		local sound = Instance.new("Sound")
		sound.SoundId = Descend(info.weapon, "Shoot").SoundId
		sound.PlayOnRemove = true
		sound.Parent = Descend(info.weapon, "Shoot")

		sound:Destroy()
	end)()

	local part, clone = bullets_folder:FindFirstChild(info.id)

	if part then
		part.CFrame = info.cf
		task.delay(2, part.Destroy, part)
	else
		clone = bullet_template:Clone()
		clone.Name = info.id
		clone.Parent = bullets_folder
		clone.CFrame = info.cf
	end

	if clone then
		task.delay(2, clone.Destroy, clone)
	end
end)