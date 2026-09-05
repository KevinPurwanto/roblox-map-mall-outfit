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
