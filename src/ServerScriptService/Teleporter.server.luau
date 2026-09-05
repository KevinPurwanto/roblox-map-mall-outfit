--!strict
-- Teleporter (server)
-- Kios dekat spawn buat lompat cepat ke podium manapun -- map ini ~421x331
-- studs, jalan kaki ke podium jauh (mis. #110) makan waktu lama.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MANNEQUIN_FOLDER = "Mannequins"
-- dekat SpawnLocation (-112, 6, -203), digeser 6 stud biar tidak nimpa titik spawn
local KIOSK_POSITION = Vector3.new(-106, 6.5, -203)

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
-- Kios fisik dekat spawn
------------------------------------------------------------------
local existingKiosk = workspace:FindFirstChild("TeleporterKiosk")
if not existingKiosk then
	local kiosk = Instance.new("Part")
	kiosk.Name = "TeleporterKiosk"
	kiosk.Size = Vector3.new(4, 5, 1)
	kiosk.Anchored = true
	kiosk.CanCollide = true
	kiosk.Material = Enum.Material.Neon
	kiosk.Color = Color3.fromRGB(255, 158, 203)
	kiosk.CFrame = CFrame.new(KIOSK_POSITION)
	kiosk.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeleporterPrompt"
	prompt.ActionText = "Buka Teleporter"
	prompt.ObjectText = "Teleporter Podium"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk

	print("[Teleporter] Kios dibuat dekat spawn @ " .. tostring(KIOSK_POSITION)
		.. " -- posisi mungkin perlu disesuaikan manual di Studio kalau nimpa objek lain.")
end

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
