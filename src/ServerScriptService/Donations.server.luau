--!strict
-- Donations (server)
-- Donasi Robux ke pemilik game lewat Developer Product, plus pencatatan
-- pembelian/belanja untuk leaderstats bawaan Roblox dan papan donatur.
--
-- KENAPA DEVELOPER PRODUCT, BUKAN TRANSFER LANGSUNG: Roblox tidak punya API
-- untuk memindahkan Robux antar pemain, dan tidak akan pernah ada. Satu-satunya
-- cara Robux berpindah adalah pemain membeli sesuatu. Developer Product =
-- Robux masuk ke pemilik experience ini.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Stats = require(ServerScriptService:WaitForChild("StatsService"))

------------------------------------------------------------------
-- DAFTAR PRODUK DONASI -- HARUS DIISI MANUAL
--
-- Developer Product tidak bisa dibuat dari dalam kode. Buat dulu di
-- Creator Dashboard: Creations > (experience ini) > Monetization >
-- Developer Products > Create. Bikin satu produk per nominal, lalu salin
-- ID-nya ke sini.
--
-- productId = 0 berarti "belum dibuat" -- tombolnya otomatis TIDAK ditampilkan
-- ke pemain, jadi tidak ada tombol yang diklik lalu gagal diam-diam.
------------------------------------------------------------------
local DONATION_PRODUCTS: { { productId: number, robux: number } } = {
	{ productId = 0, robux = 5 },
	{ productId = 0, robux = 10 },
	{ productId = 0, robux = 100 },
	{ productId = 0, robux = 250 },
	{ productId = 0, robux = 500 },
	{ productId = 0, robux = 1000 },
	{ productId = 0, robux = 5000 },
	{ productId = 0, robux = 10000 },
	{ productId = 0, robux = 100000 },
}

local TOP_DONOR_COUNT = 10

-- productId -> nominal, biar ProcessReceipt tidak perlu menyusuri list
local robuxByProduct: { [number]: number } = {}
local activeProducts: { { productId: number, robux: number } } = {}
for _, entry in ipairs(DONATION_PRODUCTS) do
	if entry.productId > 0 then
		robuxByProduct[entry.productId] = entry.robux
		table.insert(activeProducts, entry)
	end
end

if #activeProducts == 0 then
	warn("[Donations] Belum ada Developer Product yang diisi di DONATION_PRODUCTS -- "
		.. "panel donasi akan tampil tanpa tombol nominal. Buat produknya di Creator Dashboard, "
		.. "lalu isi productId-nya di src/ServerScriptService/Donations.server.luau.")
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

local GetDonationInfo = ensure("RemoteFunction", "GetDonationInfo") :: RemoteFunction
local StatsChanged = ensure("RemoteEvent", "StatsChanged") :: RemoteEvent

------------------------------------------------------------------
-- Penyiaran ke client
------------------------------------------------------------------
-- Tabel angka per pemain TIDAK dikirim lewat sini lagi: itu sekarang tugas
-- `leaderstats` (papan peringkat bawaan Roblox), yang direplikasi Roblox sendiri.
-- StatsChanged cuma sinyal "ada yang berubah" supaya panel donasi yang sedang
-- terbuka ikut menyegarkan papan donaturnya.
local function broadcastStats()
	StatsChanged:FireAllClients()
end


GetDonationInfo.OnServerInvoke = function(player: Player)
	return {
		products = activeProducts,
		topDonors = Stats.topDonors(TOP_DONOR_COUNT),
		myDonated = Stats.get(player).donated,
	}
end

------------------------------------------------------------------
-- ProcessReceipt -- satu-satunya tempat donasi boleh dicatat
--
-- Roblox MENGIRIM ULANG receipt yang sama sampai kita menjawab PurchaseGranted.
-- Jadi dua aturan keras di sini:
--   1. jangan menjawab PurchaseGranted sebelum angkanya benar-benar tersimpan
--   2. jangan menambah angka dua kali untuk PurchaseId yang sama
-- Keduanya ditangani Stats.addDonation (yang menyimpan daftar PurchaseId).
------------------------------------------------------------------
MarketplaceService.ProcessReceipt = function(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Pemain sudah keluar sebelum sempat diproses. JANGAN PurchaseGranted:
		-- Roblox akan mencoba lagi saat dia join berikutnya, dan donasinya tetap
		-- tercatat. Kalau dijawab granted di sini, Robux-nya hilang tanpa catatan.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local robux = robuxByProduct[receiptInfo.ProductId]
	if not robux then
		-- Produk asing (mis. dibuat di dashboard tapi belum didaftarkan di sini).
		-- Tetap granted supaya pemain tidak ditagih berulang untuk sesuatu yang
		-- tidak akan pernah kita kenali.
		warn(string.format("[Donations] ProductId %s tidak terdaftar di DONATION_PRODUCTS",
			tostring(receiptInfo.ProductId)))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Data pemain belum selesai dibaca dari DataStore. Kalau dipaksa dicatat
	-- sekarang, angkanya ditambahkan ke data kosong lalu menimpa total aslinya.
	-- NotProcessedYet bikin Roblox mencoba lagi sebentar kemudian.
	if not Stats.isLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, result = pcall(function()
		return Stats.addDonation(player, robux, tostring(receiptInfo.PurchaseId))
	end)
	if not ok then
		warn("[Donations] Gagal mencatat donasi: " .. tostring(result))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if result == "save_failed" or result == "not_loaded" then
		-- JANGAN granted: Robux sudah terpotong tapi belum tercatat di mana pun.
		-- Roblox akan mengirim ulang receipt ini sampai berhasil.
		warn(string.format("[Donations] Donasi %s belum bisa dicatat (%s) -- akan dicoba ulang",
			player.Name, tostring(result)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if result == "ok" then
		print(string.format("[Donations] %s donasi %d Robux", player.Name, robux))
		broadcastStats()
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------
-- Pencatatan pembelian baju (kolom Purchases & Spent di leaderstats)
--
-- PromptPurchaseFinished melaporkan apa kata dialog di CLIENT, jadi tidak boleh
-- dipercaya mentah-mentah. Kepemilikannya diverifikasi ulang ke server Roblox
-- lewat PlayerOwnsAsset sebelum angkanya ditambah.
------------------------------------------------------------------
local function priceOf(assetId: number): number
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	if ok and info then
		return tonumber(info.PriceInRobux) or 0
	end
	return 0
end

local function recordAssetPurchase(player: Player, assetId: number)
	local owns = false
	local ok, result = pcall(function()
		return MarketplaceService:PlayerOwnsAsset(player, assetId)
	end)
	owns = ok and result == true
	if not owns then
		return
	end
	Stats.addPurchase(player, 1, priceOf(assetId))
	broadcastStats()
end

MarketplaceService.PromptPurchaseFinished:Connect(function(player: Player, assetId: number, isPurchased: boolean)
	if not isPurchased then
		return
	end
	task.spawn(recordAssetPurchase, player, assetId)
end)

-- Bentuk tabel `results` untuk pembelian borongan TIDAK didokumentasikan Roblox,
-- jadi dibaca defensif: cari apa pun yang menyerupai id aset di dalamnya, lalu
-- verifikasi satu per satu lewat PlayerOwnsAsset seperti pembelian satuan.
-- Kalau bentuknya berubah, yang terjadi cuma angka tidak bertambah -- bukan error.
MarketplaceService.PromptBulkPurchaseFinished:Connect(function(player: Player, _status, results: any)
	if typeof(results) ~= "table" then
		return
	end
	task.spawn(function()
		local seen: { [number]: boolean } = {}
		for _, row in pairs(results :: { any }) do
			local id: number? = nil
			if typeof(row) == "table" then
				id = tonumber(row.Id) or tonumber(row.id) or tonumber(row.AssetId)
			end
			if id and id > 0 and not seen[id] then
				seen[id] = true
				recordAssetPurchase(player, id)
			end
		end
	end)
end)

------------------------------------------------------------------
Players.PlayerAdded:Connect(function()
	task.wait(1) -- beri waktu StatsService memuat datanya dulu
	broadcastStats()
end)
Players.PlayerRemoving:Connect(function()
	task.defer(broadcastStats)
end)

print(string.format("[Donations] siap. %d nominal donasi aktif.", #activeProducts))
