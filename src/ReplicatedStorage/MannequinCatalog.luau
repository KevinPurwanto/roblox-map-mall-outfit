--!strict
-- MannequinCatalog
-- Sumber kebenaran untuk baju tiap podium. Aman dibaca client (isinya cuma assetId publik).
--
-- Kunci tabel = attribute "PodiumIndex" pada mannequin (1..120).
-- Attribute ShirtId/PantsId di mannequin akan menimpa isi tabel ini.

export type AccessoryItem = {
	assetId: number, -- ID Accessory classic (rambut, topi, dll) -- BUKAN Layered Clothing/UGC baru
	price: number?, -- 0 / nil = tidak dijual
	label: string?, -- nil = pakai nama asli dari MarketplaceService:GetProductInfo
}

export type Outfit = {
	shirt: number?,
	pants: number?,
	price: number?, -- harga shirt (Robux), 0 / nil = tidak dijual
	pantsPrice: number?, -- harga pants (Robux), 0 / nil = tidak dijual
	label: string?,
	accessories: { AccessoryItem }?, -- rambut/aksesoris lain, masing-masing harga sendiri
}

export type PodiumEntry = {
	name: string?,
	M: Outfit?,
	F: Outfit?,
}

local Catalog = {}

-- "field: Type = value" bukan syntax Luau yang valid (cuma berlaku untuk local/parameter) --
-- makanya dideklarasikan sebagai local typed dulu, baru ditempel ke field Catalog.
local entries: { [number]: PodiumEntry } = {
	[1] = {
		name = "Koleksi Pink Bow",
		-- shirt/pants = ID KATALOG (angka dari URL roblox.com/catalog/<ID>/...),
		-- bukan ID ShirtTemplate. Server yang mengonversinya ke ID tekstur saat
		-- memasang baju ke mannequin.
		M = { shirt = 18728338281, pants = 0, price = 0, label = "Pink Under Armour (Cowok)" },
		F = { shirt = 0, pants = 0, price = 0, label = "Pink Bow (Cewek)" },
	},
	[2] = {
		name = "Koleksi Pastel",
		F = { shirt = 0, label = "Pastel Tee" },
	},
	-- lanjutkan sampai [120]
}
Catalog.entries = entries

-- dipakai kalau podium belum terdaftar di atas
local fallback: PodiumEntry = {
	name = "Belum diisi",
	M = { shirt = 0, pants = 0 },
	F = { shirt = 0, pants = 0 },
}
Catalog.fallback = fallback

function Catalog.get(podiumIndex: number, gender: string): Outfit?
	local entry = Catalog.entries[podiumIndex] or Catalog.fallback
	if gender == "M" then
		return entry.M
	elseif gender == "F" then
		return entry.F
	end
	return nil
end

function Catalog.displayName(podiumIndex: number): string
	local entry = Catalog.entries[podiumIndex]
	return (entry and entry.name) or ("Podium " .. tostring(podiumIndex))
end

return Catalog
