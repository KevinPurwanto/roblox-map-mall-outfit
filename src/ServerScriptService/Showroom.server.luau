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
local InsertService = game:GetService("InsertService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Roles = require(ServerScriptService:WaitForChild("RoleService"))
local Likes = require(ServerScriptService:WaitForChild("LikeService"))
local Catalog = require(ReplicatedStorage:WaitForChild("MannequinCatalog"))

local MANNEQUIN_FOLDER = "Mannequins"
local MANNEQUIN_TAG = "Mannequin" -- dibaca MannequinFocus di client
local MANNEQUIN_CLICK_TAG = "MannequinClickBox" -- dibaca ShowroomClient di client
local PROMPT_DISTANCE = 12
local ACTION_COOLDOWN = 0.5 -- detik, per pemain

------------------------------------------------------------------
-- Persistensi outfit yang diubah admin (DataStore) -- satu key nampung semua
-- override sekaligus, supaya startup cuma butuh 1x GetAsync (bukan 1 per
-- mannequin, yang gampang kena rate limit DataStore).
------------------------------------------------------------------
local outfitStoreOk, outfitStore = pcall(function()
	return DataStoreService:GetDataStore("MannequinOutfits_v1")
end)
if not outfitStoreOk then
	warn("[Showroom] DataStore outfit tidak tersedia -- perubahan admin tidak akan tersimpan lintas restart.")
end

local OVERRIDES_KEY = "Overrides"
-- accessoryIds nil = pakai daftar accessory dari MannequinCatalog; non-nil = timpa
-- penuh (Attribute tidak bisa nyimpan list, jadi override accessory lewat sini)
type OutfitOverride = { shirtId: number, pantsId: number, accessoryIds: { number }? }
local overrides: { [string]: OutfitOverride } = {}

local function overrideKey(podiumIndex: number, gender: string): string
	return tostring(podiumIndex) .. "_" .. gender
end

local function loadOverrides()
	if not outfitStoreOk then
		return
	end
	local ok, saved = pcall(function()
		return (outfitStore :: any):GetAsync(OVERRIDES_KEY)
	end)
	if ok and typeof(saved) == "table" then
		overrides = saved
	elseif not ok then
		warn("[Showroom] Gagal baca outfit dari DataStore: " .. tostring(saved))
	end
end

local function saveOverrides()
	if not outfitStoreOk then
		return
	end
	local ok, err = pcall(function()
		(outfitStore :: any):SetAsync(OVERRIDES_KEY, overrides)
	end)
	if not ok then
		warn("[Showroom] Gagal simpan outfit ke DataStore: " .. tostring(err))
	end
end

local function setOverride(podiumIndex: number, gender: string, shirtId: number, pantsId: number)
	local key = overrideKey(podiumIndex, gender)
	local existingAccessories = overrides[key] and overrides[key].accessoryIds
	overrides[key] = { shirtId = shirtId, pantsId = pantsId, accessoryIds = existingAccessories }
	saveOverrides()
end

-- terapkan override tersimpan sebagai attribute, dipanggil sebelum applyTo()
-- supaya outfitOf() (attribute -> catalog -> 0) otomatis pakai nilai ini
local function applyStoredOverride(mannequin: Model)
	local index = mannequin:GetAttribute("PodiumIndex") :: number?
	local gender = mannequin:GetAttribute("Gender") :: string?
	if not index or not gender then
		return
	end
	local saved = overrides[overrideKey(index, gender)]
	if saved then
		mannequin:SetAttribute("ShirtId", saved.shirtId)
		mannequin:SetAttribute("PantsId", saved.pantsId)
	end
end

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
local BuyItem = ensure("RemoteEvent", "BuyItem") :: RemoteEvent
local SetOutfit = ensure("RemoteEvent", "SetOutfit") :: RemoteEvent
local ManageAdmin = ensure("RemoteEvent", "ManageAdmin") :: RemoteEvent
local GetMyRole = ensure("RemoteFunction", "GetMyRole") :: RemoteFunction
local GetMannequin = ensure("RemoteFunction", "GetMannequinInfo") :: RemoteFunction
local GetAllMannequins = ensure("RemoteFunction", "GetAllMannequins") :: RemoteFunction
local SetOutfitByIndex = ensure("RemoteEvent", "SetOutfitByIndex") :: RemoteEvent
local SetAccessories = ensure("RemoteEvent", "SetAccessories") :: RemoteEvent
local SearchCatalog = ensure("RemoteFunction", "SearchCatalog") :: RemoteFunction
local CartAdd = ensure("RemoteEvent", "CartAdd") :: RemoteEvent
local CartRemove = ensure("RemoteEvent", "CartRemove") :: RemoteEvent
local CartClear = ensure("RemoteEvent", "CartClear") :: RemoteEvent
local BuyCart = ensure("RemoteEvent", "BuyCart") :: RemoteEvent
local GetCart = ensure("RemoteFunction", "GetCart") :: RemoteFunction
local CartUpdated = ensure("RemoteEvent", "CartUpdated") :: RemoteEvent
local LikeMannequin = ensure("RemoteEvent", "LikeMannequin") :: RemoteEvent
local ResetLikes = ensure("RemoteEvent", "ResetLikes") :: RemoteEvent
local LikesChanged = ensure("RemoteEvent", "LikesChanged") :: RemoteEvent

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

-- kunci suka = podium + gender, jadi mannequin cowok & cewek di satu podium
-- punya hitungan sendiri-sendiri
local function likeKeyOf(mannequin: Model): string
	return Likes.key(
		mannequin:GetAttribute("PodiumIndex") :: number,
		mannequin:GetAttribute("Gender") :: string
	)
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

-- cache Accessory (rambut, topi, dll) yang sudah di-load, per assetId -- supaya
-- tidak InsertService:LoadAsset() berulang tiap refreshAll() jalan
local accessoryTemplateCache: { [number]: Accessory } = {}

local function getAccessoryTemplate(assetId: number): Accessory?
	local cached = accessoryTemplateCache[assetId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn(string.format("[Showroom] Gagal load accessory %d: %s", assetId, tostring(result)))
		return nil
	end
	local model = result :: Model
	local template = model:FindFirstChildOfClass("Accessory")
	if template then
		template.Parent = nil
		accessoryTemplateCache[assetId] = template
	else
		warn(string.format(
			"[Showroom] Asset %d bukan Accessory classic (Layered Clothing/item lain tidak didukung lewat Humanoid:AddAccessory)",
			assetId))
	end
	model:Destroy()
	return template
end

-- terima ID KATALOG (dari link roblox.com/catalog/<ID>/...) dan cari tahu itu
-- Shirt/Pants/Accessory apa, plus ID ShirtTemplate/PantsTemplate asli di dalamnya
-- -- admin tidak perlu tahu bedanya ID katalog vs ID template lagi
type ResolvedCatalogAsset = { kind: "Shirt" | "Pants" | "Accessory", templateId: number? }
local resolveCache: { [number]: ResolvedCatalogAsset } = {}

local function extractNumericId(text: string): number?
	local digits = text:match("%d+")
	return digits and tonumber(digits) or nil
end

local function resolveCatalogAsset(catalogId: number): ResolvedCatalogAsset?
	local cached = resolveCache[catalogId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(catalogId)
	end)
	if not ok then
		return nil
	end
	local model = result :: Model
	local resolved: ResolvedCatalogAsset? = nil

	local shirt = model:FindFirstChildOfClass("Shirt")
	local pants = model:FindFirstChildOfClass("Pants")
	local accessory = model:FindFirstChildOfClass("Accessory")

	if shirt then
		resolved = { kind = "Shirt", templateId = extractNumericId(shirt.ShirtTemplate) }
	elseif pants then
		resolved = { kind = "Pants", templateId = extractNumericId(pants.PantsTemplate) }
	elseif accessory then
		resolved = { kind = "Accessory", templateId = catalogId }
		accessory.Parent = nil
		accessoryTemplateCache[catalogId] = accessory -- sekalian isi cache accessory, hemat 1x LoadAsset lagi
	end

	model:Destroy()
	if resolved then
		resolveCache[catalogId] = resolved
	end
	return resolved
end

-- terima link/ID katalog ATAU ID ShirtTemplate/PantsTemplate yang sudah diresolve
-- (cara lama, tetap didukung) -- kalau resolveCatalogAsset gagal/beda jenis,
-- anggap input itu sendiri sudah ID template yang valid
local function resolveShirtOrPantsId(input: number, expectKind: "Shirt" | "Pants"): number
	if input <= 0 then
		return 0
	end
	local resolved = resolveCatalogAsset(input)
	if resolved and resolved.kind == expectKind and resolved.templateId then
		return resolved.templateId
	end
	return input
end

-- info live dari Roblox (nama asli + status jual + harga saat ini) -- dipakai
-- supaya panel tidak menampilkan "Beli" untuk barang yang sudah ditarik dari
-- penjualan (event berakhir dll), bukan cuma mengandalkan angka statis di katalog
-- assetTypeId dipakai buat mendeteksi kalau yang tersimpan ternyata ID tekstur
-- (AssetTypeId 1 = Image) dan bukan ID katalog Shirt(11)/Pants(12)
type ProductInfo = { name: string, price: number, forSale: boolean, assetTypeId: number }
local productInfoCache: { [number]: ProductInfo } = {}

local function getProductInfo(assetId: number): ProductInfo?
	if assetId <= 0 then
		return nil
	end
	local cached = productInfoCache[assetId]
	if cached then
		return cached
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	if not ok or not info then
		return nil
	end
	local result: ProductInfo = {
		name = info.Name or ("Item " .. assetId),
		price = info.PriceInRobux or 0,
		forSale = info.IsForSale == true,
		assetTypeId = info.AssetTypeId or 0,
	}
	productInfoCache[assetId] = result
	return result
end

-- gabungkan info live Roblox dengan fallback angka statis di katalog (dipakai
-- kalau GetProductInfo gagal, mis. rate limit atau asset sudah dihapus total)
local function resolveAvailability(assetId: number, catalogPrice: number): (boolean, number)
	local info = getProductInfo(assetId)
	if info then
		return info.forSale, info.forSale and info.price or 0
	end
	return catalogPrice > 0, catalogPrice
end

-- Kesalahan paling gampang terjadi: admin menyimpan ID TEKSTUR (AssetTypeId 1 =
-- Image, hasil resolve_shirt_id) padahal yang dibutuhkan ID KATALOG. Bajunya
-- tetap terpasang (ada fallback di resolveShirtOrPantsId), tapi thumbnail,
-- harga, dan tombol Beli semuanya salah tanpa error -- jadi diperingatkan
-- eksplisit di Output biar ketahuan.
local EXPECTED_ASSET_TYPE = { Shirt = 11, Pants = 12 }

local function warnIfNotCatalogId(assetId: number, expectKind: "Shirt" | "Pants")
	if assetId <= 0 then
		return
	end
	local info = getProductInfo(assetId)
	if not info then
		return
	end
	local expected = EXPECTED_ASSET_TYPE[expectKind]
	if info.assetTypeId ~= expected then
		warn(string.format(
			"[Showroom] %d itu AssetTypeId %d ('%s'), bukan %s (%d). Sepertinya yang dipakai ID TEKSTUR, "
				.. "bukan ID KATALOG dari URL roblox.com/catalog/<ID>/... -- bajunya tetap terpasang, "
				.. "tapi thumbnail/harga/tombol Beli tidak akan benar.",
			assetId, info.assetTypeId, info.name, expectKind, expected))
	end
end

------------------------------------------------------------------
-- Outfit gabungan attribute + catalog, attribute menang
------------------------------------------------------------------
type ResolvedAccessory = { assetId: number, price: number, label: string }
type ResolvedOutfit = {
	shirt: number,
	pants: number,
	price: number,
	pantsPrice: number,
	accessories: { ResolvedAccessory },
}

local function outfitOf(mannequin: Model): ResolvedOutfit
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
	local pantsPrice = (fromCatalog and fromCatalog.pantsPrice) or 0

	-- accessory tidak bisa lewat Attribute (Attribute tidak bisa nyimpan list) --
	-- override-nya dicek langsung dari tabel overrides (DataStore), bukan attribute
	local override = overrides[overrideKey(index, gender)]
	local accessories: { ResolvedAccessory } = {}
	if override and override.accessoryIds then
		for _, assetId in ipairs(override.accessoryIds) do
			local info = getProductInfo(assetId)
			table.insert(accessories, {
				assetId = assetId,
				price = (info and info.forSale and info.price) or 0,
				label = (info and info.name) or ("Aksesoris " .. tostring(assetId)),
			})
		end
	elseif fromCatalog and fromCatalog.accessories then
		for _, acc in ipairs(fromCatalog.accessories) do
			local info = getProductInfo(acc.assetId)
			table.insert(accessories, {
				assetId = acc.assetId,
				price = acc.price or 0,
				label = acc.label or (info and info.name) or ("Aksesoris " .. tostring(acc.assetId)),
			})
		end
	end

	return { shirt = shirt, pants = pants, price = price, pantsPrice = pantsPrice, accessories = accessories }
end

-- dipanggil terpisah dari setOverride() karena accessory diedit lewat field
-- sendiri di panel -- tetap pertahankan shirt/pants yang sedang berlaku sekarang
-- (dari catalog ataupun override sebelumnya) supaya tidak ke-reset jadi kosong
local function setAccessoryOverride(mannequin: Model, accessoryIds: { number })
	local index = mannequin:GetAttribute("PodiumIndex") :: number
	local gender = mannequin:GetAttribute("Gender") :: string
	local key = overrideKey(index, gender)
	local existing = overrides[key]
	if not existing then
		local current = outfitOf(mannequin)
		existing = { shirtId = current.shirt, pantsId = current.pants }
		overrides[key] = existing
	end
	existing.accessoryIds = accessoryIds
	saveOverrides()
end

-- daftar item siap-tampil (thumbnail + harga live + status jual) untuk panel
-- pembelian -- beda dari outfitOf() yang cuma dipakai internal (render/attribute)
local function buildItemList(outfit: ResolvedOutfit, player: Player)
	local items = {}

	local function addItem(assetId: number, kind: string, catalogPrice: number, catalogLabel: string?)
		if assetId <= 0 then
			return
		end
		local forSale, price = resolveAvailability(assetId, catalogPrice)
		local info = getProductInfo(assetId)
		table.insert(items, {
			assetId = assetId,
			kind = kind,
			price = price,
			forSale = forSale,
			label = catalogLabel or (info and info.name) or kind,
			owned = Roles.owns(player, assetId),
		})
	end

	addItem(outfit.shirt, "Shirt", outfit.price)
	addItem(outfit.pants, "Pants", outfit.pantsPrice)
	for _, acc in ipairs(outfit.accessories) do
		addItem(acc.assetId, "Accessory", acc.price, acc.label)
	end

	return items
end

------------------------------------------------------------------
-- Pakaikan baju ke semua mannequin
------------------------------------------------------------------
-- attribute penanda accessory yang kita pasang sendiri -- supaya bisa dibedakan
-- dari accessory bawaan rig (mis. "Kate Hair" di template Cewek) saat mengganti
local ACCESSORY_TAG = "FromCatalog"

local function applyAccessoriesTo(character: Model, accessories: { ResolvedAccessory })
	if #accessories == 0 then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute(ACCESSORY_TAG) then
			child:Destroy()
		end
	end
	for _, acc in ipairs(accessories) do
		local template = getAccessoryTemplate(acc.assetId)
		if template then
			local clone = template:Clone()
			clone:SetAttribute(ACCESSORY_TAG, true)
			hum:AddAccessory(clone)
		end
	end
end

local function applyTo(mannequin: Model)
	local outfit = outfitOf(mannequin)

	-- outfit.shirt/pants = ID KATALOG. Yang bisa dipasang ke ShirtTemplate itu
	-- ID tekstur di dalamnya, jadi dikonversi dulu di sini (hasilnya di-cache
	-- per ID, jadi 240 mannequin tidak berarti 240 kali LoadAsset).
	if outfit.shirt > 0 then
		local shirt = mannequin:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
		shirt.ShirtTemplate = "rbxassetid://" .. resolveShirtOrPantsId(outfit.shirt, "Shirt")
		shirt.Parent = mannequin
	end
	if outfit.pants > 0 then
		local pants = mannequin:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		pants.PantsTemplate = "rbxassetid://" .. resolveShirtOrPantsId(outfit.pants, "Pants")
		pants.Parent = mannequin
	end
	applyAccessoriesTo(mannequin, outfit.accessories)
end

local function setupPrompt(mannequin: Model)
	-- Ukur mannequin DULUAN, sebelum part bantu apa pun ditambahkan -- kalau
	-- diukur belakangan, OutfitPromptAnchor (2 stud di atas kepala) ikut terhitung
	-- dan kotak klik jadi kelewat tinggi.
	local bodyCFrame, bodySize = mannequin:GetBoundingBox()

	-- ProximityPrompt sepertinya butuh BasePart LANGSUNG sebagai parent supaya
	-- interaksinya jalan -- ditempel ke Attachment saja terbukti bikin prompt
	-- kelihatan tapi tidak bisa di-trigger. Jadi dipakai Part kecil tak-terlihat,
	-- diposisikan 2 stud di atas Head, dan mannequin ini statis (Anchored semua
	-- part-nya) jadi cukup di-posisikan sekali saat dibuat, tidak perlu weld.
	local anchorPart = mannequin:FindFirstChild("Head") :: BasePart?
		or mannequin:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not anchorPart then
		return
	end

	local existingAnchor = mannequin:FindFirstChild("OutfitPromptAnchor") :: BasePart?
	local promptAnchor: BasePart
	if existingAnchor then
		promptAnchor = existingAnchor
	else
		local part = Instance.new("Part")
		part.Name = "OutfitPromptAnchor"
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = anchorPart.CFrame + Vector3.new(0, 2, 0)
		part.Parent = mannequin
		promptAnchor = part
	end

	local prompt = promptAnchor:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	-- Sengaja TANPA teks: cuma lingkaran tombol "E" saja. ActionText/ObjectText
	-- yang panjang menutupi baju mannequin, dan itu justru barang yang mau
	-- dilihat pembeli. Nama koleksinya toh sudah jadi judul panel begitu dibuka.
	prompt.ActionText = ""
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	-- Kotak klik: badan mannequin sendiri di-set CanQuery = false (lihat
	-- place_mannequins.luau), dan part seperti itu TIDAK pernah kena raycast
	-- mouse -- ClickDetector yang ditempel di situ tidak akan pernah menyala.
	-- Jadi dipakai satu part tak-terlihat khusus yang CanQuery = true.
	-- Bonus: targetnya jadi satu kotak utuh, bukan lengan/kepala terpisah.
	-- ClickDetector.MouseClick juga jalan di HP (tap) walau namanya "Mouse".
	if not mannequin:FindFirstChild("OutfitClickBox") then
		local box = Instance.new("Part")
		box.Name = "OutfitClickBox"
		box.Size = bodySize
		box.CFrame = bodyCFrame
		box.Transparency = 1
		box.Anchored = true
		box.CanCollide = false
		box.CanTouch = false
		box.CanQuery = true
		box.Parent = mannequin

		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = PROMPT_DISTANCE
		detector.CursorIcon = "" -- pakai kursor default, jangan bikin ikon sendiri
		detector.Parent = box

		-- ditandai supaya client bisa menemukannya lewat CollectionService,
		-- tanpa perlu menebak nama atau menunggu WaitForChild
		CollectionService:AddTag(box, MANNEQUIN_CLICK_TAG)
	end
end

local function refreshAll()
	local folder = folderRef()
	if not folder then
		warn("[Showroom] Folder workspace." .. MANNEQUIN_FOLDER .. " belum ada. "
			.. "Jalankan tools/place_mannequins.luau di Command Bar dulu.")
		return 0
	end

	loadOverrides()
	Likes.loadCounts()

	local n = 0
	for _, mannequin in ipairs(folder:GetChildren()) do
		if validMannequin(mannequin) then
			applyStoredOverride(mannequin :: Model)
			applyTo(mannequin :: Model)
			setupPrompt(mannequin :: Model)
			-- Tag dipasang di SERVER supaya ikut replikasi ke semua client
			-- (termasuk mannequin yang baru streaming-in belakangan). Client
			-- MannequinFocus cuma mendengarkan tag ini, tidak pernah menebak
			-- nama model.
			CollectionService:AddTag(mannequin, MANNEQUIN_TAG)
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
		items = buildItemList(outfit, player), -- dipakai panel thumbnail (beli satuan/semua)
		likes = Likes.count(likeKeyOf(mannequin)),
		likedByMe = Likes.likedBy(player, likeKeyOf(mannequin)),
	}
end

-- dipakai panel admin "semua podium": data mentah, bukan Instance, supaya tidak
-- tergantung apakah mannequin itu sudah ter-stream ke client
GetAllMannequins.OnServerInvoke = function(player: Player)
	if not Roles.atLeast(player, "ADMIN") then
		return {}
	end
	local folder = folderRef()
	if not folder then
		return {}
	end

	local list: { { podiumIndex: number, gender: string, name: string, shirt: number, pants: number, price: number } } = {}
	for _, child in ipairs(folder:GetChildren()) do
		local mannequin = validMannequin(child)
		if mannequin then
			local outfit = outfitOf(mannequin)
			local index = mannequin:GetAttribute("PodiumIndex") :: number
			table.insert(list, {
				podiumIndex = index,
				gender = mannequin:GetAttribute("Gender") :: string,
				name = Catalog.displayName(index),
				shirt = outfit.shirt,
				pants = outfit.pants,
				price = outfit.price,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.podiumIndex == b.podiumIndex then
			return a.gender < b.gender
		end
		return a.podiumIndex < b.podiumIndex
	end)

	return list
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
		shirt.ShirtTemplate = "rbxassetid://" .. resolveShirtOrPantsId(outfit.shirt, "Shirt")
		shirt.Parent = character
	end
	if outfit.pants > 0 then
		local pants = character:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		pants.PantsTemplate = "rbxassetid://" .. resolveShirtOrPantsId(outfit.pants, "Pants")
		pants.Parent = character
	end
	applyAccessoriesTo(character, outfit.accessories)
end)

-- Dulu pakai player:LoadCharacter() -- itu respawn penuh, jadi karakter pindah
-- balik ke SpawnLocation walau pemain lagi di podium 90. Yang sebenarnya
-- diinginkan cuma lepas baju yang lagi dicoba, tanpa pindah tempat -- jadi
-- avatar di-reset ke penampilan ASLI pemain (dari Roblox, HumanoidDescription
-- yang sebenarnya) di posisi dia berdiri sekarang.
ResetAvatar.OnServerEvent:Connect(function(player: Player)
	if throttled(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end

	-- hapus manual dulu Shirt/Pants/accessory hasil Coba-Baju SEBELUM
	-- ApplyDescription -- ApplyDescription ternyata tidak selalu membuang
	-- Instance yang kita tempel sendiri di luar sistem HumanoidDescription
	-- kalau deskripsi aslinya memang tidak punya shirt/pants (nilai 0)
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Destroy()
	end
	local pants = character:FindFirstChildOfClass("Pants")
	if pants then
		pants:Destroy()
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("FromCatalog") then
			child:Destroy()
		end
	end

	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if ok and description then
		humanoid:ApplyDescription(description)
	end
end)

-- beli satu item spesifik (thumbnail per baris di panel)
BuyItem.OnServerEvent:Connect(function(player: Player, inst: any, assetId: any)
	if throttled(player) then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end
	if typeof(assetId) ~= "number" then
		return
	end

	-- pastikan assetId beneran bagian dari outfit mannequin ini, bukan ID bebas kiriman client
	local outfit = outfitOf(mannequin)
	local belongs = assetId == outfit.shirt or assetId == outfit.pants
	if not belongs then
		for _, acc in ipairs(outfit.accessories) do
			if acc.assetId == assetId then
				belongs = true
				break
			end
		end
	end
	if not belongs then
		return
	end

	MarketplaceService:PromptPurchase(player, assetId)
end)

-- beli semua item outfit sekaligus lewat Bulk Purchase API (checkout satu dialog,
-- Roblox sendiri yang menandai item yang sudah dimiliki/sudah tidak dijual)
BuyOutfit.OnServerEvent:Connect(function(player: Player, inst: any)
	if throttled(player) then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end

	local outfit = outfitOf(mannequin)
	local assetIds: { number } = {}
	if outfit.shirt > 0 then
		table.insert(assetIds, outfit.shirt)
	end
	if outfit.pants > 0 then
		table.insert(assetIds, outfit.pants)
	end
	for _, acc in ipairs(outfit.accessories) do
		table.insert(assetIds, acc.assetId)
	end
	if #assetIds == 0 then
		return
	end

	if #assetIds == 1 then
		MarketplaceService:PromptPurchase(player, assetIds[1])
		return
	end

	local lineItems = {}
	for _, assetId in ipairs(assetIds) do
		table.insert(lineItems, { Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(assetId) })
	end

	local ok, err = pcall(function()
		(MarketplaceService :: any):PromptBulkPurchase(player, lineItems, {})
	end)
	if not ok then
		warn("[Showroom] PromptBulkPurchase gagal: " .. tostring(err))
	end
end)

------------------------------------------------------------------
-- Suka per mannequin
--
-- Beda dari tombol hati di tiap item (itu Favorite katalog Roblox milik akun
-- pemain). Yang ini milik showroom: berapa orang menyukai TAMPILAN mannequin
-- ini. Penyimpanannya di LikeService; di sini cuma validasi + penyiaran.
------------------------------------------------------------------
LikeMannequin.OnServerEvent:Connect(function(player: Player, inst: any)
	if throttled(player) then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end

	local key = likeKeyOf(mannequin)
	local total, nowLiked = Likes.toggle(player, key)

	-- Jumlahnya disiarkan ke SEMUA pemain (angkanya publik), tapi status "aku
	-- sudah suka" cuma dikirim ke yang bersangkutan -- itu milik dia sendiri.
	LikesChanged:FireAllClients(key, total)
	LikesChanged:FireClient(player, key, total, nowLiked)
end)

-- Reset hanya untuk SUPERADMIN. inst = nil berarti seluruh mannequin.
ResetLikes.OnServerEvent:Connect(function(player: Player, inst: any)
	if not Roles.atLeast(player, "SUPERADMIN") then
		return
	end

	if inst == nil then
		Likes.reset(nil)
		local folder = folderRef()
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				local mannequin = validMannequin(child)
				if mannequin then
					LikesChanged:FireAllClients(likeKeyOf(mannequin), 0, false)
				end
			end
		end
		print(string.format("[Showroom] %s me-reset SEMUA suka mannequin", player.Name))
		return
	end

	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end
	local key = likeKeyOf(mannequin)
	Likes.reset(key)
	LikesChanged:FireAllClients(key, 0, false)
	print(string.format("[Showroom] %s me-reset suka podium %s", player.Name, key))
end)

------------------------------------------------------------------
-- Keranjang belanja
--
-- Kenapa ada, padahal sudah ada tombol "Beli Semua": tombol itu cuma bisa beli
-- isi SATU mannequin. Keranjang membiarkan pembeli keliling mall, mengumpulkan
-- barang dari podium mana saja, lalu bayar sekali di akhir.
--
-- Batas 20 bukan angka karangan -- itu batas keras Bulk Purchase API Roblox
-- (maksimal 20 line item per dialog checkout). Ditolak di server sekalian,
-- supaya pemain tahu penuh SEBELUM sampai ke dialog pembayaran.
--
-- Isinya disimpan per sesi di memori (bukan DataStore): keranjang yang tersimpan
-- berhari-hari malah bikin bingung karena harga & status jual barang bisa sudah
-- berubah saat pemain kembali.
------------------------------------------------------------------
local MAX_CART_ITEMS = 20

type CartEntry = { assetId: number, kind: string, label: string }
local carts: { [Player]: { CartEntry } } = {}

local function cartOf(player: Player): { CartEntry }
	local cart = carts[player]
	if not cart then
		cart = {}
		carts[player] = cart
	end
	return cart
end

local function cartHas(cart: { CartEntry }, assetId: number): boolean
	for _, entry in ipairs(cart) do
		if entry.assetId == assetId then
			return true
		end
	end
	return false
end

-- Harga/status jual/kepemilikan TIDAK disimpan di keranjang -- selalu diambil
-- ulang saat dibaca. Barang bisa ditarik dari penjualan atau ganti harga sambil
-- pemain masih belanja, dan keranjang yang menampilkan angka basi lebih buruk
-- daripada keranjang yang berubah di depan mata.
local function cartPayload(player: Player)
	local cart = cartOf(player)
	local items = {}
	for _, entry in ipairs(cart) do
		local forSale, price = resolveAvailability(entry.assetId, 0)
		table.insert(items, {
			assetId = entry.assetId,
			kind = entry.kind,
			label = entry.label,
			price = price,
			forSale = forSale,
			owned = Roles.owns(player, entry.assetId),
		})
	end
	return items
end

local function pushCart(player: Player, reason: string)
	CartUpdated:FireClient(player, cartPayload(player), reason)
end

GetCart.OnServerInvoke = function(player: Player)
	return cartPayload(player)
end

-- assetId nil/0 = masukkan SEMUA item mannequin ini sekaligus
CartAdd.OnServerEvent:Connect(function(player: Player, inst: any, assetId: any)
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end

	local outfit = outfitOf(mannequin)
	local candidates = buildItemList(outfit, player)

	-- Cuma item yang benar-benar dipakai mannequin ini yang boleh masuk. Tanpa
	-- ini, client bisa menyuntikkan assetId bebas ke keranjang orang lain.
	local wanted: { CartEntry } = {}
	if typeof(assetId) == "number" and assetId > 0 then
		for _, item in ipairs(candidates) do
			if item.assetId == assetId then
				table.insert(wanted, { assetId = item.assetId, kind = item.kind, label = item.label })
				break
			end
		end
		if #wanted == 0 then
			return -- assetId tidak ada di mannequin ini
		end
	else
		for _, item in ipairs(candidates) do
			table.insert(wanted, { assetId = item.assetId, kind = item.kind, label = item.label })
		end
	end

	local cart = cartOf(player)
	local added, skippedDuplicate = 0, 0
	local full = false
	for _, entry in ipairs(wanted) do
		if cartHas(cart, entry.assetId) then
			skippedDuplicate += 1
		elseif #cart >= MAX_CART_ITEMS then
			full = true
			break
		else
			table.insert(cart, entry)
			added += 1
		end
	end

	local reason = "added"
	if full then
		reason = "full"
	elseif added == 0 and skippedDuplicate > 0 then
		reason = "duplicate"
	end
	pushCart(player, reason)
end)

CartRemove.OnServerEvent:Connect(function(player: Player, assetId: any)
	if typeof(assetId) ~= "number" then
		return
	end
	local cart = cartOf(player)
	for i, entry in ipairs(cart) do
		if entry.assetId == assetId then
			table.remove(cart, i)
			pushCart(player, "removed")
			return
		end
	end
end)

CartClear.OnServerEvent:Connect(function(player: Player)
	carts[player] = {}
	pushCart(player, "cleared")
end)

BuyCart.OnServerEvent:Connect(function(player: Player)
	if throttled(player) then
		return
	end
	local cart = cartOf(player)
	if #cart == 0 then
		return
	end

	local lineItems = {}
	for _, entry in ipairs(cart) do
		table.insert(lineItems, { Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(entry.assetId) })
	end

	-- PromptBulkPurchase menolak dialog berisi satu baris, jadi kasus itu
	-- dialihkan ke prompt biasa
	if #lineItems == 1 then
		MarketplaceService:PromptPurchase(player, cart[1].assetId)
		return
	end

	local ok, err = pcall(function()
		(MarketplaceService :: any):PromptBulkPurchase(player, lineItems, {})
	end)
	if not ok then
		warn("[Showroom] PromptBulkPurchase (keranjang) gagal: " .. tostring(err))
	end
end)

------------------------------------------------------------------
-- Handler: admin
------------------------------------------------------------------
SetOutfit.OnServerEvent:Connect(function(player: Player, inst: any, shirtInput: any, pantsInput: any)
	if not Roles.atLeast(player, "ADMIN") then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end
	if typeof(shirtInput) ~= "number" or typeof(pantsInput) ~= "number" then
		return
	end
	if shirtInput < 0 or pantsInput < 0 or shirtInput % 1 ~= 0 or pantsInput % 1 ~= 0 then
		return
	end

	-- disimpan apa adanya sebagai ID KATALOG (angka dari link) -- konversi ke ID
	-- tekstur baru dilakukan di applyTo(), karena ID katalog yang dibutuhkan
	-- untuk thumbnail, harga, cek kepemilikan, dan tombol Beli
	local shirtId = shirtInput
	local pantsId = pantsInput
	warnIfNotCatalogId(shirtId, "Shirt")
	warnIfNotCatalogId(pantsId, "Pants")

	mannequin:SetAttribute("ShirtId", shirtId)
	mannequin:SetAttribute("PantsId", pantsId)
	applyTo(mannequin)
	setOverride(mannequin:GetAttribute("PodiumIndex") :: number, mannequin:GetAttribute("Gender") :: string, shirtId, pantsId)

	print(string.format("[Showroom] %s mengubah podium %s -> shirt %d, pants %d",
		player.Name, tostring(mannequin:GetAttribute("PodiumIndex")), shirtId, pantsId))
end)

-- sama seperti SetOutfit, tapi target dicari lewat PodiumIndex+Gender, bukan Instance
-- -> dipakai panel admin "semua podium" yang tidak pegang referensi Instance mannequin
SetOutfitByIndex.OnServerEvent:Connect(function(player: Player, podiumIndex: any, gender: any, shirtInput: any, pantsInput: any)
	if not Roles.atLeast(player, "ADMIN") then
		return
	end
	if typeof(podiumIndex) ~= "number" or typeof(gender) ~= "string" then
		return
	end
	if gender ~= "M" and gender ~= "F" then
		return
	end
	if typeof(shirtInput) ~= "number" or typeof(pantsInput) ~= "number" then
		return
	end
	if shirtInput < 0 or pantsInput < 0 or shirtInput % 1 ~= 0 or pantsInput % 1 ~= 0 then
		return
	end

	local folder = folderRef()
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		local mannequin = validMannequin(child)
		if mannequin
			and mannequin:GetAttribute("PodiumIndex") == podiumIndex
			and mannequin:GetAttribute("Gender") == gender
		then
			local shirtId = shirtInput -- ID katalog, lihat catatan di SetOutfit
			local pantsId = pantsInput
			warnIfNotCatalogId(shirtId, "Shirt")
			warnIfNotCatalogId(pantsId, "Pants")
			mannequin:SetAttribute("ShirtId", shirtId)
			mannequin:SetAttribute("PantsId", pantsId)
			applyTo(mannequin)
			setOverride(podiumIndex, gender, shirtId, pantsId)
			print(string.format("[Showroom] %s mengubah podium %d (%s) -> shirt %d, pants %d",
				player.Name, podiumIndex, gender, shirtId, pantsId))
			return
		end
	end
end)

-- ganti daftar accessory (rambut dll) lewat panel per-mannequin -- ambil beberapa
-- link/ID sekaligus, tiap ID divalidasi ulang server (harus Accessory classic)
SetAccessories.OnServerEvent:Connect(function(player: Player, inst: any, rawIds: any)
	if not Roles.atLeast(player, "ADMIN") then
		return
	end
	local mannequin = validMannequin(inst)
	if not mannequin then
		return
	end
	if typeof(rawIds) ~= "table" then
		return
	end

	local resolvedIds: { number } = {}
	for _, v in ipairs(rawIds) do
		if typeof(v) == "number" and v > 0 then
			local resolved = resolveCatalogAsset(v)
			if resolved and resolved.kind == "Accessory" then
				table.insert(resolvedIds, v)
			else
				warn(string.format("[Showroom] %d bukan Accessory classic yang valid, dilewati", v))
			end
		end
	end

	setAccessoryOverride(mannequin, resolvedIds)
	applyTo(mannequin)

	print(string.format("[Showroom] %s mengubah accessory podium %s -> %d item",
		player.Name, tostring(mannequin:GetAttribute("PodiumIndex")), #resolvedIds))
end)

-- Cari item langsung di katalog Roblox dari dalam game.
--
-- Ini solusi permanen untuk masalah "ID tekstur vs ID katalog": selama admin
-- mengetik/menempel angka sendiri, dia bisa saja menempel ID tekstur (AssetTypeId 1)
-- yang bikin thumbnail jelek, harga salah, dan tombol Beli gagal. Hasil dari
-- AvatarEditorService:SearchCatalogAsync SELALU ID katalog yang benar, jadi
-- admin cukup klik hasil pencarian dan tidak pernah menyentuh angka lagi.
--
-- Catatan API: SearchCatalogAsync butuh capability "AssetRead" dan mengembalikan
-- CatalogPages (paginated). Kita cuma ambil halaman pertama -- 60 hasil sudah
-- lebih dari cukup untuk kotak pencarian kecil di panel admin.
--
-- Nama member Enum diambil lewat string, BUKAN Enum.AvatarAssetType.X langsung.
-- Alasannya: mengetik nama member yang tidak ada (mis. "HatAccessory" -- yang
-- benar cuma "Hat") melempar error saat script DIMUAT, dan itu mematikan seisi
-- Showroom.server.luau -- semua panel, prompt, dan mannequin ikut hilang tanpa
-- ada hubungannya dengan fitur pencarian. Lewat lookup string, member yang tidak
-- dikenal cuma dilewati dengan warn.
-- Dicocokkan lewat GetEnumItems() (bukan Enum.AvatarAssetType[name]) karena
-- mengindeks nama yang tidak ada TETAP melempar error, sama seperti mengetiknya
-- langsung -- GetEnumItems cuma mengembalikan daftar, jadi tidak pernah melempar.
local AVATAR_ASSET_TYPE_BY_NAME: { [string]: Enum.AvatarAssetType } = {}
for _, item in ipairs(Enum.AvatarAssetType:GetEnumItems()) do
	AVATAR_ASSET_TYPE_BY_NAME[item.Name] = item
end

local function assetTypes(names: { string }): { Enum.AvatarAssetType }
	local out: { Enum.AvatarAssetType } = {}
	for _, name in ipairs(names) do
		local value = AVATAR_ASSET_TYPE_BY_NAME[name]
		if value then
			table.insert(out, value)
		else
			warn(string.format("[Showroom] Enum.AvatarAssetType.%s tidak ada di versi Roblox ini, dilewati", name))
		end
	end
	return out
end

local SEARCH_KINDS: { [string]: { Enum.AvatarAssetType } } = {
	Shirt = assetTypes({ "Shirt" }),
	Pants = assetTypes({ "Pants" }),
	-- "Hat" adalah nama resmi topi klasik (bukan "HatAccessory"); sisanya memang
	-- berakhiran Accessory
	Accessory = assetTypes({
		"HairAccessory",
		"Hat",
		"FaceAccessory",
		"NeckAccessory",
		"ShoulderAccessory",
		"FrontAccessory",
		"BackAccessory",
		"WaistAccessory",
	}),
}
local MAX_SEARCH_RESULTS = 24

type SearchResult = { id: number, name: string, price: number, forSale: boolean, creator: string }

-- hasil pencarian jarang berubah dalam satu sesi, dan SearchCatalogAsync
-- kena rate limit kalau dipanggil tiap ketikan -- jadi di-cache per (kind+keyword)
local searchCache: { [string]: { SearchResult } } = {}

SearchCatalog.OnServerInvoke = function(player: Player, kind: any, keyword: any): (boolean, any)
	if not Roles.atLeast(player, "ADMIN") then
		return false, "not_admin"
	end
	if typeof(kind) ~= "string" or not SEARCH_KINDS[kind] or #SEARCH_KINDS[kind] == 0 then
		return false, "bad_kind"
	end
	if typeof(keyword) ~= "string" then
		return false, "bad_keyword"
	end
	keyword = keyword:gsub("^%s+", ""):gsub("%s+$", "")
	if #keyword < 2 then
		return false, "too_short"
	end
	if #keyword > 100 then
		keyword = keyword:sub(1, 100)
	end
	if throttled(player) then
		return false, "throttled"
	end

	local cacheKey = kind .. "|" .. keyword:lower()
	local cached = searchCache[cacheKey]
	if cached then
		return true, cached
	end

	local ok, pagesOrErr = pcall(function()
		local params = CatalogSearchParams.new()
		params.SearchKeyword = keyword
		params.AssetTypes = SEARCH_KINDS[kind]
		-- CreatorType/SortType dibiarkan default (Relevance) -- sama seperti
		-- kotak pencarian katalog Roblox sendiri
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if not ok then
		warn("[Showroom] SearchCatalogAsync gagal: " .. tostring(pagesOrErr))
		return false, "search_failed"
	end

	local okPage, page = pcall(function()
		return (pagesOrErr :: any):GetCurrentPage()
	end)
	if not okPage or typeof(page) ~= "table" then
		return false, "search_failed"
	end

	local results: { SearchResult } = {}
	for _, item in ipairs(page :: { any }) do
		local id = tonumber(item.Id)
		-- Bundle punya struktur ID sendiri (bukan assetId) dan tidak bisa dipasang
		-- lewat Shirt/Pants/AddAccessory -- dilewati walau AssetTypes sudah difilter
		local isBundle = tostring(item.ItemType):find("Bundle") ~= nil
		if id and id > 0 and not isBundle then
			table.insert(results, {
				id = id,
				name = tostring(item.Name or ("Item " .. id)),
				price = tonumber(item.Price) or tonumber(item.LowestPrice) or 0,
				-- item gratis harganya 0 juga, jadi status jual TIDAK boleh
				-- disimpulkan dari harga -- pakai IsOffSale dari katalog
				forSale = item.IsOffSale ~= true,
				creator = tostring(item.CreatorName or ""),
			})
			if #results >= MAX_SEARCH_RESULTS then
				break
			end
		end
	end

	searchCache[cacheKey] = results
	return true, results
end

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
	carts[player] = nil -- kalau tidak, tabel ini menahan referensi Player selamanya
end)

local count = refreshAll()
print(string.format("[Showroom] siap. %d mannequin aktif.", count))
