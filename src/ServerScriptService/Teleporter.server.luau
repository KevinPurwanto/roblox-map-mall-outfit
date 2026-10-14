--!strict
-- Teleporter (server)
-- Kios dekat spawn buat lompat cepat ke podium manapun -- map ini ~421x331
-- studs, jalan kaki ke podium jauh (mis. #110) makan waktu lama.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Portal = require(ServerScriptService:WaitForChild("TeleporterPortal"))

local MANNEQUIN_FOLDER = "Mannequins"

-- Portal berdiri di tepi TIMUR area spawn, menghadap ke dalam (-X) supaya
-- terlihat dari tempat pemain muncul. Area spawn ternyata 29 x 29.5 stud
-- (x -127..-98), jadi posisi lama (x -106) sebenarnya di tengah-tengahnya.
-- Di sisi +X dari sini hanya dinding dekorasi -- tepi map.
-- Y tidak ditulis di sini: tinggi lantai dibaca lewat raycast saat dibangun.
local PORTAL_XZ = Vector2.new(-101.5, -203)
local PORTAL_FACING = Vector3.new(-1, 0, 0)
local FALLBACK_FLOOR_Y = 6.62 -- tinggi lantai spawn hasil raycast di Edit mode

------------------------------------------------------------------
-- Remote
------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

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

local TeleportToPodium = ensure("RemoteFunction", "TeleportToPodium") :: RemoteFunction

------------------------------------------------------------------
-- Portal fisik dekat spawn (desainnya di TeleporterPortal.luau)
------------------------------------------------------------------
local function floorY(): number
	-- Mulai dari ketinggian sedang, BUKAN dari langit: tepat di atas area ini
	-- ada dekorasi raksasa (puncaknya di Y ~57) yang akan kena duluan.
	local origin = Vector3.new(PORTAL_XZ.X, FALLBACK_FLOOR_Y + 20, PORTAL_XZ.Y)
	local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0))
	return hit and hit.Position.Y or FALLBACK_FLOOR_Y
end

-- POSISI DIATUR DARI STUDIO, bukan dari kode.
-- Kalau di Workspace ada Part bernama "TeleporterSpot" (panel tembus pandang
-- seukuran portal), portal dibangun di posisinya dan menghadap ke sisi Front-nya
-- (LookVector). Pemilik map cukup menggeser/memutar penanda itu di Studio lalu
-- menyimpan place -- tidak perlu mengubah angka di file ini. PORTAL_XZ /
-- PORTAL_FACING di atas cuma cadangan kalau penandanya tidak ada.
-- Penanda dihancurkan saat game jalan (cuma alat bantu di Studio).
local SPOT_NAME = "TeleporterSpot"

local function placement(): (Vector3, Vector3)
	local spot = workspace:FindFirstChild(SPOT_NAME)
	if spot and spot:IsA("BasePart") then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { spot }
		local origin = spot.Position
		-- dari pusat penanda ke bawah: penandanya berdiri DI lantai, jadi
		-- lantai pasti di bawah pusatnya, dan dekorasi tinggi di atas tidak kena
		local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), params)
		local floor = hit and hit.Position.Y or (origin.Y - spot.Size.Y / 2)
		local facing = spot.CFrame.LookVector
		spot:Destroy()
		return Vector3.new(origin.X, floor, origin.Z), facing
	end
	return Vector3.new(PORTAL_XZ.X, floorY(), PORTAL_XZ.Y), PORTAL_FACING
end

-- Kios lama (sebuah Part kotak) dibuang kalau masih ada, misalnya pernah
-- tersimpan di file place -- jangan sampai ada dua teleporter.
local existing = workspace:FindFirstChild("TeleporterKiosk")
if existing then
	existing:Destroy()
end

local basePosition, facing = placement()
local portal = Portal.build(basePosition, facing)
portal.Parent = workspace
print(string.format("[Teleporter] Portal dibuat @ (%.1f, %.1f, %.1f) menghadap %s", basePosition.X, basePosition.Y,
	basePosition.Z, tostring(facing)))

-- Balikin KODE STATUS (bukan kalimat siap-pakai) -- client yang menerjemahkan
-- ke bahasa pemain lewat ReplicatedStorage/Localization.luau, supaya pesan
-- error/sukses ikut multi-bahasa juga.
TeleportToPodium.OnServerInvoke = function(player: Player, podiumIndex: any): (boolean, string, number?)
	if typeof(podiumIndex) ~= "number" or podiumIndex % 1 ~= 0 then
		return false, "invalid_number", nil
	end

	local folder = workspace:FindFirstChild(MANNEQUIN_FOLDER)
	if not folder then
		return false, "no_mannequins", nil
	end

	local target: Model? = nil
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("PodiumIndex") == podiumIndex then
			target = child
			break
		end
	end
	if not target then
		return false, "not_found", podiumIndex
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false, "no_character", nil
	end

	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = targetRoot and targetRoot.Position or target:GetPivot().Position
	local landing = pos + Vector3.new(0, 0, 5) -- geser dikit biar tidak nyangkut di dalam mannequin

	character:PivotTo(CFrame.new(landing, pos))
	return true, "ok", podiumIndex
end
