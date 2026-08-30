--!strict
-- Showroom (server)
-- Titik masuk utama. Membuat remote, memakaikan baju ke mannequin,
-- memasang ProximityPrompt, dan menangani semua aksi dari client.
--
-- Aturan yang tidak boleh dilanggar: setiap handler remote memeriksa ulang
-- role pemanggil di sini. UI client hanya menyembunyikan tombol, bukan mengamankan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Roles = require(ServerScriptService:WaitForChild("RoleService"))
local Catalog = require(ReplicatedStorage:WaitForChild("MannequinCatalog"))

local MANNEQUIN_FOLDER = "Mannequins"
local PROMPT_DISTANCE = 12
local ACTION_COOLDOWN = 0.5 -- detik, per pemain

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

local TryOn = ensure("RemoteEvent", "TryOn") :: RemoteEvent
local ResetAvatar = ensure("RemoteEvent", "ResetAvatar") :: RemoteEvent
local BuyOutfit = ensure("RemoteEvent", "BuyOutfit") :: RemoteEvent
local SetOutfit = ensure("RemoteEvent", "SetOutfit") :: RemoteEvent
local ManageAdmin = ensure("RemoteEvent", "ManageAdmin") :: RemoteEvent
local GetMyRole = ensure("RemoteFunction", "GetMyRole") :: RemoteFunction
local GetMannequin = ensure("RemoteFunction", "GetMannequinInfo") :: RemoteFunction

------------------------------------------------------------------
-- Util
------------------------------------------------------------------
local lastAction: { [Player]: number } = {}

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < ACTION_COOLDOWN then
		return true
	end
	lastAction[player] = now
	return false
end

local function folderRef(): Folder?
	return workspace:FindFirstChild(MANNEQUIN_FOLDER) :: Folder?
end

-- validasi bahwa instance yang dikirim client benar-benar mannequin kita
local function validMannequin(inst: any): Model?
	local folder = folderRef()
	if not folder then
		return nil
	end
	if typeof(inst) ~= "Instance" or not inst:IsA("Model") then
		return nil
	end
	if inst.Parent ~= folder then
		return nil
	end
	if inst:GetAttribute("PodiumIndex") == nil or inst:GetAttribute("Gender") == nil then
		return nil
	end
	return inst
end

-- gabungan attribute + catalog, attribute menang
local function outfitOf(mannequin: Model): { shirt: number, pants: number, price: number }
	local index = mannequin:GetAttribute("PodiumIndex") :: number
	local gender = mannequin:GetAttribute("Gender") :: string
	local fromCatalog = Catalog.get(index, gender)

	local shirt = (mannequin:GetAttribute("ShirtId") :: number?)
		or (fromCatalog and fromCatalog.shirt)
		or 0
	local pants = (mannequin:GetAttribute("PantsId") :: number?)
		or (fromCatalog and fromCatalog.pants)
		or 0
	local price = (mannequin:GetAttribute("Price") :: number?)
		or (fromCatalog and fromCatalog.price)
		or 0

	return { shirt = shirt, pants = pants, price = price }
end

------------------------------------------------------------------
-- Pakaikan baju ke semua mannequin
------------------------------------------------------------------
local function applyTo(mannequin: Model)
	local outfit = outfitOf(mannequin)

	if outfit.shirt > 0 then
		local shirt = mannequin:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
		shirt.ShirtTemplate = "rbxassetid://" .. outfit.shirt
		shirt.Parent = mannequin
	end
	if outfit.pants > 0 then
		local pants = mannequin:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		pants.PantsTemplate = "rbxassetid://" .. outfit.pants
		pants.Parent = mannequin
	end
end

local function setupPrompt(mannequin: Model)
	local root = mannequin:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or root:FindFirstChildOfClass("ProximityPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lihat outfit"
	prompt.ObjectText = Catalog.displayName(mannequin:GetAttribute("PodiumIndex") :: number)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
end

local function refreshAll()
	local folder = folderRef()
	if not folder then
		warn("[Showroom] Folder workspace." .. MANNEQUIN_FOLDER .. " belum ada. "
			.. "Jalankan tools/place_mannequins.luau di Command Bar dulu.")
		return 0
	end

	local n = 0
	for _, mannequin in ipairs(folder:GetChildren()) do
		if validMannequin(mannequin) then
			applyTo(mannequin :: Model)
			setupPrompt(mannequin :: Model)
			n += 1
		end
	end
	return n
end

------------------------------------------------------------------
-- Handler: pemain
------------------------------------------------------------------
GetMyRole.OnServerInvoke = function(player: Player)
	return Roles.get(player)
end

GetMannequin.OnServerInvoke = function(player: Player, inst: any)
	local mannequin = validMannequin(inst)
	if not mannequin then
		return nil
	end
	local outfit = outfitOf(mannequin)
	return {
		podiumIndex = mannequin:GetAttribute("PodiumIndex"),
		gender = mannequin:GetAttribute("Gender"),
		name = Catalog.displayName(mannequin:GetAttribute("PodiumIndex") :: number),
		shirt = outfit.shirt,
		pants = outfit.pants,
		price = outfit.price,
		owned = outfit.shirt > 0 and Roles.owns(player, outfit.shirt) or false,
	}
end

TryOn.OnServerEvent:Connect(function(player: Player, inst: any)
	if throttled(player) then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local outfit = outfitOf(mannequin)
	if outfit.shirt > 0 then
		local shirt = character:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
		shirt.ShirtTemplate = "rbxassetid://" .. outfit.shirt
		shirt.Parent = character
	end
	if outfit.pants > 0 then
		local pants = character:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		pants.PantsTemplate = "rbxassetid://" .. outfit.pants
		pants.Parent = character
	end
end)

ResetAvatar.OnServerEvent:Connect(function(player: Player)
	if throttled(player) then
		return
	end
	player:LoadCharacter()
end)

BuyOutfit.OnServerEvent:Connect(function(player: Player, inst: any)
	if throttled(player) then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end

	local outfit = outfitOf(mannequin)
	if outfit.shirt <= 0 then
		return
	end
	MarketplaceService:PromptPurchase(player, outfit.shirt)
end)

------------------------------------------------------------------
-- Handler: admin
------------------------------------------------------------------
SetOutfit.OnServerEvent:Connect(function(player: Player, inst: any, shirtId: any, pantsId: any)
	if not Roles.atLeast(player, "ADMIN") then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end
	if typeof(shirtId) ~= "number" or typeof(pantsId) ~= "number" then
		return
	end
	if shirtId < 0 or pantsId < 0 or shirtId % 1 ~= 0 or pantsId % 1 ~= 0 then
		return
	end

	mannequin:SetAttribute("ShirtId", shirtId)
	mannequin:SetAttribute("PantsId", pantsId)
	applyTo(mannequin)

	print(string.format("[Showroom] %s mengubah podium %s -> shirt %d, pants %d",
		player.Name, tostring(mannequin:GetAttribute("PodiumIndex")), shirtId, pantsId))
end)

ManageAdmin.OnServerEvent:Connect(function(player: Player, action: any, targetUserId: any)
	if not Roles.atLeast(player, "SUPERADMIN") then
		return
	end
	if typeof(targetUserId) ~= "number" or targetUserId <= 0 then
		return
	end

	local ok, message
	if action == "grant" then
		ok, message = Roles.grantAdmin(player, targetUserId)
	elseif action == "revoke" then
		ok, message = Roles.revokeAdmin(player, targetUserId)
	else
		return
	end
	print(string.format("[Showroom] %s -> %s %d: %s",
		player.Name, tostring(action), targetUserId, tostring(message)))
end)

------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	lastAction[player] = nil
end)

local count = refreshAll()
print(string.format("[Showroom] siap. %d mannequin aktif.", count))
