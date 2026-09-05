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
	[9954653030] = true, -- concreabot, permanen
	[0] = true, -- TODO: ganti dengan UserId superadmin kedua (placeholder, aman karena tidak ada akun ber-UserId 0)
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

-- GetDataStore() sendiri bisa throw (bukan cuma GetAsync/SetAsync) kalau place
-- ini belum pernah di-publish ke Roblox -- dibungkus pcall biar tidak menjatuhkan
-- seisi RoleService (dan Showroom yang require ini) kalau itu terjadi.
local adminStore: any = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Roles_Admins_v1")
	end)
	if ok then
		adminStore = result
	else
		warn("[RoleService] DataStore tidak tersedia (place ini kemungkinan belum "
			.. "pernah di-publish ke Roblox). SUPERADMINS tetap jalan normal, tapi "
			.. "admin yang diangkat lewat ManageAdmin tidak akan tersimpan/terbaca.")
	end
end
local cache: { [number]: string } = {}

-- override role buat testing (ganti POV Player/Admin/Superadmin tanpa akun asli)
-- -- HANYA berlaku di Studio, dicek keras di server (bukan cuma disembunyikan di
-- client) supaya mustahil kepakai di server live beneran walau remote-nya dipanggil paksa
local debugRoleOverride: { [number]: string } = {}

local RoleService = {}
RoleService.RANK = RANK

function RoleService.setDebugRole(userId: number, role: string?)
	if not RunService:IsStudio() then
		return
	end
	if role ~= nil and not RANK[role] then
		return
	end
	debugRoleOverride[userId] = role
end

------------------------------------------------------------------
-- Pembacaan role
------------------------------------------------------------------
local function computeRole(player: Player): string
	if RunService:IsStudio() and debugRoleOverride[player.UserId] then
		return debugRoleOverride[player.UserId]
	end

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
