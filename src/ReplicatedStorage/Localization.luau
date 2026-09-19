--!strict
-- Localization
-- Kamus teks Indonesia/Inggris untuk panel yang dilihat semua pemain
-- (ShowroomClient, TeleporterClient). Roblox bisa auto-translate teks statis
-- yang dibuat lewat editor Studio, tapi TIDAK untuk teks yang dibuat lewat
-- script saat game jalan (semua panel kita begitu) -- jadi dipilih manual di
-- sini berdasar Players.LocalPlayer.LocaleId. Locale Indonesia -> "id", di
-- luar itu -> "en" (fallback default, bukan daftar lengkap semua bahasa).
--
-- Nama koleksi/label dari MannequinCatalog (mis. "Koleksi Pink Bow") TIDAK ikut
-- diterjemahkan di sini -- itu konten katalog, beda dari teks chrome UI (tombol,
-- placeholder, status) yang dicakup modul ini.

local Players = game:GetService("Players")

export type Lang = "id" | "en"

local strings: { [string]: { id: string, en: string } } = {
	tryOn = { id = "Coba baju ini", en = "Try this outfit" },
	buyAll = { id = "Beli Semua", en = "Buy All" },
	alreadyOwnedAll = { id = "Sudah dimiliki semua", en = "Already owned" },
	resetAvatar = { id = "Kembalikan avatar", en = "Reset avatar" },
	close = { id = "Tutup", en = "Close" },
	saveToMannequin = { id = "Simpan ke mannequin", en = "Save to mannequin" },
	shirtFieldPlaceholder = { id = "Shirt: link katalog atau assetId", en = "Shirt: catalog link or assetId" },
	pantsFieldPlaceholder = { id = "Pants: link katalog atau assetId", en = "Pants: catalog link or assetId" },
	accessoriesFieldPlaceholder = { id = "Aksesoris: link/ID, pisah koma", en = "Accessories: link/ID, comma separated" },
	alreadyOwned = { id = "Sudah dimiliki", en = "Already owned" },
	notForSale = { id = "Tidak dijual", en = "Not for sale" },
	robux = { id = "Robux", en = "Robux" },
	buy = { id = "Beli", en = "Buy" },
	owned = { id = "Dimiliki", en = "Owned" },
	unavailable = { id = "Tidak ada", en = "Unavailable" },
	podiumGenderLine = { id = "Podium %d  ·  %s", en = "Podium %d  ·  %s" },
	boy = { id = "Cowok", en = "Boy" },
	girl = { id = "Cewek", en = "Girl" },

	-- Pencarian katalog (kotak admin) -- dipakai supaya admin tidak pernah perlu
	-- mengetik/menempel angka ID sendiri, jadi tidak mungkin salah tempel ID tekstur
	searchOpen = { id = "Cari baju di katalog", en = "Search the catalog" },
	searchTitle = { id = "Cari di Katalog Roblox", en = "Search Roblox Catalog" },
	searchPlaceholder = { id = "Nama item, mis. Pink Hoodie", en = "Item name, e.g. Pink Hoodie" },
	searchButton = { id = "Cari", en = "Search" },
	searchHint = { id = "Klik hasil untuk mengisi ID otomatis", en = "Click a result to fill the ID" },
	searchKindShirt = { id = "Baju", en = "Shirt" },
	searchKindPants = { id = "Celana", en = "Pants" },
	searchKindAccessory = { id = "Aksesoris", en = "Accessory" },
	searchSearching = { id = "Mencari...", en = "Searching..." },
	searchResultCount = { id = "%d hasil", en = "%d results" },
	searchNoResult = { id = "Tidak ada hasil untuk \"%s\"", en = "No results for \"%s\"" },
	searchTooShort = { id = "Ketik minimal 2 huruf", en = "Type at least 2 characters" },
	searchFailed = { id = "Pencarian gagal, coba lagi", en = "Search failed, please retry" },
	searchThrottled = { id = "Terlalu cepat, tunggu sebentar", en = "Too fast, wait a moment" },
	searchNotAdmin = { id = "Hanya admin yang bisa mencari", en = "Admins only" },
	searchPickedShirt = { id = "Baju diisi: %s", en = "Shirt set: %s" },
	searchPickedPants = { id = "Celana diisi: %s", en = "Pants set: %s" },
	searchPickedAccessory = { id = "Aksesoris ditambah: %s", en = "Accessory added: %s" },
	searchSaveReminder = { id = "Jangan lupa klik Simpan ke mannequin", en = "Remember to click Save to mannequin" },
	free = { id = "Gratis", en = "Free" },

	-- judul tombol lari di layar HP (ContextActionService touch button)
	sprintButton = { id = "Lari", en = "Run" },

	-- Keranjang belanja
	cartTitle = { id = "Keranjang", en = "Cart" },
	cartButton = { id = "Keranjang (%d)", en = "Cart (%d)" },
	cartAddItem = { id = "+ Keranjang", en = "+ Cart" },
	cartAddAll = { id = "+ Semua ke keranjang", en = "+ Add all to cart" },
	cartEmpty = { id = "Keranjang masih kosong.", en = "Your cart is empty." },
	cartHint = { id = "Maksimal %d barang (batas checkout Roblox)", en = "Up to %d items (Roblox checkout limit)" },
	cartCount = { id = "%d/%d barang", en = "%d/%d items" },
	cartTotal = { id = "Total: %d Robux", en = "Total: %d Robux" },
	cartCheckout = { id = "Beli semua isi keranjang", en = "Buy everything in cart" },
	cartClear = { id = "Kosongkan", en = "Clear" },
	cartRemove = { id = "Hapus", en = "Remove" },
	cartAdded = { id = "Ditambahkan ke keranjang", en = "Added to cart" },
	cartFull = { id = "Keranjang penuh (maks %d barang)", en = "Cart is full (max %d items)" },
	cartDuplicate = { id = "Sudah ada di keranjang", en = "Already in your cart" },
	cartRemoved = { id = "Dihapus dari keranjang", en = "Removed from cart" },
	cartCleared = { id = "Keranjang dikosongkan", en = "Cart cleared" },
	cartOwnedNote = { id = "Barang yang sudah dimiliki tidak ikut dibayar.", en = "Items you already own are not charged." },

	-- Like = Favorite katalog Roblox yang sebenarnya (AvatarEditorService), bukan
	-- hitungan suka milik game ini sendiri -- teksnya sengaja menyebut "favorit"
	-- supaya pemain tahu ini tersimpan di akun Roblox mereka
	favoriteFailed = { id = "Gagal menyimpan favorit", en = "Couldn't save favorite" },
	favoriteDeniedShort = { id = "Favorit ditolak", en = "Favorite denied" },

	-- Suka per MANNEQUIN (milik showroom ini), beda dari tombol hati per item
	-- yang itu Favorite katalog Roblox milik akun pemain
	likeMannequin = { id = "Suka", en = "Like" },
	likeCount = { id = "%d suka", en = "%d likes" },
	likeReset = { id = "Reset suka podium ini", en = "Reset this podium's likes" },
	likeResetAll = { id = "Reset SEMUA suka", en = "Reset ALL likes" },
	likeResetConfirm = { id = "Klik sekali lagi untuk konfirmasi", en = "Click again to confirm" },

	-- Panel statistik server (tabel kanan-atas)
	statsPeople = { id = "Pemain", en = "People" },
	statsPurchases = { id = "Beli", en = "Purchases" },
	statsDonated = { id = "Donasi", en = "Donated" },
	statsSpent = { id = "Belanja", en = "Spent" },
	statsShow = { id = "Statistik server", en = "Server stats" },

	-- Panel donasi
	donateButton = { id = "Donasi", en = "Donate" },
	donateTitle = { id = "Donasi", en = "Donate" },
	donateTopDonor = { id = "Donatur Teratas", en = "Top Donor" },
	donateLeaderboard = { id = "Papan Donatur", en = "Leaderboard" },
	donateAmounts = { id = "Pilih nominal", en = "Pick an amount" },
	donateYouHave = { id = "Kamu sudah donasi", en = "You have donated" },
	donateNobody = { id = "Belum ada donatur", en = "No donors yet" },
	donateNoProducts = {
		id = "Nominal donasi belum disiapkan. Buat Developer Product dulu di Creator Dashboard.",
		en = "Donation amounts aren't set up yet. Create Developer Products in the Creator Dashboard first.",
	},
	donateThanks = { id = "Terima kasih!", en = "Thank you!" },
	-- pemisah ribuan: "21.000" di Indonesia, "21,000" di Inggris -- kalau
	-- disamakan, salah satunya terbaca sebagai angka desimal
	thousandsSep = { id = ".", en = "," },
	favoriteDenied = { id = "Favorit ditolak (izin)", en = "Favorite denied (permission)" },

	teleporterTitle = { id = "Teleporter Podium", en = "Podium Teleporter" },
	teleporterPlaceholder = { id = "Nomor podium (1-120)", en = "Podium number (1-120)" },
	teleporterButton = { id = "Teleport", en = "Teleport" },
	teleporterFillNumber = { id = "Isi nomor podium dulu (angka)", en = "Enter a podium number first" },
	teleporterInProgress = { id = "Teleporting...", en = "Teleporting..." },
	teleporterOk = { id = "Teleport ke podium %d", en = "Teleported to podium %d" },
	teleporterInvalidNumber = { id = "Nomor podium tidak valid", en = "Invalid podium number" },
	teleporterNoMannequins = { id = "Belum ada mannequin -- coba lagi sebentar", en = "No mannequins yet -- try again shortly" },
	teleporterNotFound = { id = "Podium %d tidak ditemukan (coba 1-120)", en = "Podium %d not found (try 1-120)" },
	teleporterNoCharacter = { id = "Karakter belum siap", en = "Character not ready" },
}

local function detectLang(): Lang
	local player = Players.LocalPlayer
	local locale = (player and player.LocaleId) or ""
	if locale:sub(1, 2):lower() == "id" then
		return "id"
	end
	return "en"
end

local Localization = {}

-- t("key", arg1, arg2, ...) -- args dipakai kalau string-nya punya %d/%s (string.format)
function Localization.t(key: string, ...: any): string
	local entry = strings[key]
	if not entry then
		return key
	end
	local lang = detectLang()
	local template = entry[lang] or entry.id
	local count = select("#", ...)
	if count == 0 then
		return template
	end
	return string.format(template, ...)
end

return Localization
