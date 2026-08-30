--!strict
-- MannequinCatalog
-- Sumber kebenaran untuk baju tiap podium. Aman dibaca client (isinya cuma assetId publik).
--
-- Kunci tabel = attribute "PodiumIndex" pada mannequin (1..120).
-- Attribute ShirtId/PantsId di mannequin akan menimpa isi tabel ini.

export type Outfit = {
	shirt: number?,
	pants: number?,
	price: number?, -- 0 / nil = tidak dijual
	label: string?,
}

export type PodiumEntry = {
	name: string?,
	M: Outfit?,
	F: Outfit?,
}

local Catalog = {}

Catalog.entries: { [number]: PodiumEntry } = {
	[1] = {
		name = "Koleksi Pink Bow",
		M = { shirt = 0, pants = 0, price = 0, label = "Pink Bow (Cowok)" },
		F = { shirt = 0, pants = 0, price = 0, label = "Pink Bow (Cewek)" },
	},
	[2] = {
		name = "Koleksi Pastel",
		F = { shirt = 0, label = "Pastel Tee" },
	},
	-- lanjutkan sampai [120]
}

-- dipakai kalau podium belum terdaftar di atas
Catalog.fallback: PodiumEntry = {
	name = "Belum diisi",
	M = { shirt = 0, pants = 0 },
	F = { shirt = 0, pants = 0 },
}

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
