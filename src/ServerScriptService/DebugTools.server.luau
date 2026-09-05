--!strict
-- DebugTools (server)
-- Alat testing khusus Studio: ganti role sendiri (Player/Admin/Superadmin) dan
-- WalkSpeed cepat, tanpa perlu akun asli buat tiap role.
--
-- TIDAK PERNAH aktif di server live beneran -- gerbangnya RunService:IsStudio()
-- di baris paling atas (early return), bukan cuma disembunyikan di client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Roles = require(ServerScriptService:WaitForChild("RoleService"))

local NORMAL_SPEED = 16
local FAST_SPEED = 50

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function ensure(className: string, name: string): Instance
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local obj = Instance.new(className)
	obj.Name = name
	obj.Parent = remotes
	return obj
end

local DebugSetRole = ensure("RemoteEvent", "DebugSetRole") :: RemoteEvent
local DebugSetSpeed = ensure("RemoteEvent", "DebugSetSpeed") :: RemoteEvent

DebugSetRole.OnServerEvent:Connect(function(player: Player, role: any)
	if role ~= nil and typeof(role) ~= "string" then
		return
	end
	Roles.setDebugRole(player.UserId, role)
	Roles.refresh(player)
end)

DebugSetSpeed.OnServerEvent:Connect(function(player: Player, fast: any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = fast == true and FAST_SPEED or NORMAL_SPEED
end)

print("[DebugTools] Aktif (Studio only) -- role & speed switcher tersedia buat testing.")
