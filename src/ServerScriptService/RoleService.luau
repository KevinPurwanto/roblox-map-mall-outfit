--!strict
-- RoleService
-- Taruh sebagai ModuleScript di ServerScriptService (JANGAN di ReplicatedStorage,
-- daftar superadmin tidak boleh terbaca client).
--
-- Pakai: local Roles = require(game.ServerScriptService.RoleService)
--        if Roles.atLeast(player, "ADMIN") then ... end

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

------------------------------------------------------------------
-- KONFIGURASI
------------------------------------------------------------------
-- UserId, bukan username. Cek di URL profil: roblox.com/users/<UserId>/profile
local SUPERADMINS: { [number]: boolean } = {
	[0] = true, -- ganti dengan UserId kamu
}

local GROUP_ID = 0 -- 0 = tidak pakai grup
local GROUP_RANK_ADMIN = 200 -- rank minimum yang dianggap admin
------------------------------------------------------------------

local RANK = {
	GUEST = 0,
	PLAYER = 1,
	ADMIN = 2,
	SUPERADMIN = 3,
}

local adminStore = DataStoreService:GetDataStore("Roles_Admins_v1")
local cache: { [number]: string } = {}

local RoleService = {}
RoleService.RANK = RANK

------------------------------------------------------------------
-- Pembacaan role
------------------------------------------------------------------
local function computeRole(player: Player): string
	if SUPERADMINS[player.UserId] then
		return "SUPERADMIN"
	end

	if GROUP_ID > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(GROUP_ID)
		end)
		if ok and rank >= GROUP_RANK_ADMIN then
			return "ADMIN"
		end
	end

	local ok, stored = pcall(function()
		return adminStore:GetAsync(tostring(player.UserId))
	end)
	if ok and stored == true then
		return "ADMIN"
	end

	return "PLAYER"
end

function RoleService.get(player: Player): string
	local cached = cache[player.UserId]
	if cached then
		return cached
	end
	local role = computeRole(player)
	cache[player.UserId] = role
	return role
end

function RoleService.atLeast(player: Player, minRole: string): boolean
	if not player or not player.Parent then
		return false
	end
	return RANK[RoleService.get(player)] >= (RANK[minRole] or math.huge)
end

function RoleService.refresh(player: Player)
	cache[player.UserId] = nil
end

------------------------------------------------------------------
-- Kelola admin (hanya superadmin)
------------------------------------------------------------------
function RoleService.grantAdmin(actor: Player, targetUserId: number): (boolean, string)
	if not RoleService.atLeast(actor, "SUPERADMIN") then
		return false, "Butuh hak superadmin"
	end
	if SUPERADMINS[targetUserId] then
		return false, "Target sudah superadmin"
	end

	local ok, err = pcall(function()
		adminStore:SetAsync(tostring(targetUserId), true)
	end)
	if not ok then
		return false, "DataStore gagal: " .. tostring(err)
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		RoleService.refresh(target)
	end
	return true, "Berhasil diangkat jadi admin"
end

function RoleService.revokeAdmin(actor: Player, targetUserId: number): (boolean, string)
	if not RoleService.atLeast(actor, "SUPERADMIN") then
		return false, "Butuh hak superadmin"
	end

	local ok, err = pcall(function()
		adminStore:RemoveAsync(tostring(targetUserId))
	end)
	if not ok then
		return false, "DataStore gagal: " .. tostring(err)
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		RoleService.refresh(target)
	end
	return true, "Hak admin dicabut"
end

------------------------------------------------------------------
-- Status pembeli: bukan role, tapi kepemilikan per item
------------------------------------------------------------------
function RoleService.owns(player: Player, assetId: number, assetType: Enum.InfoType?): boolean
	if assetId <= 0 then
		return false
	end
	local ok, result = pcall(function()
		if assetType == Enum.InfoType.GamePass then
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, assetId)
		end
		return MarketplaceService:PlayerOwnsAsset(player, assetId)
	end)
	return ok and result == true
end

------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	cache[player.UserId] = nil
end)

if RunService:IsStudio() then
	warn("[RoleService] Di Studio, pastikan Game Settings > Security > "
		.. "Enable Studio Access to API Services aktif, kalau tidak DataStore akan gagal.")
end

return RoleService
