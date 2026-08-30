--!strict
-- MannequinDresser
--
-- Dua cara pakai:
--   1. Runtime  -> taruh sebagai Script di ServerScriptService, jalan otomatis saat Play.
--   2. Edit time -> tempel seluruh isi file ini di Command Bar untuk melihat hasilnya
--                   langsung di viewport tanpa menekan Play.
--
-- Prioritas sumber data:
--   Attribute di mannequin  >  CATALOG di bawah  >  dilewati

------------------------------------------------------------------
-- CATALOG: assetId per podium. Isi seperlunya, sisanya boleh kosong.
-- Nomor podium ada di attribute "PodiumIndex" tiap mannequin.
------------------------------------------------------------------
local CATALOG: { [number]: { M: { shirt: number?, pants: number? }?, F: { shirt: number?, pants: number? }? } } = {
	[1] = {
		M = { shirt = 0, pants = 0 },
		F = { shirt = 0, pants = 0 },
	},
	[2] = {
		F = { shirt = 0 }, -- slot boleh diisi sebagian saja
	},
	-- [3] = { ... }
}

-- kalau podium belum ada di CATALOG dan tidak punya attribute, pakai ini (0 = lewati)
local FALLBACK = {
	M = { shirt = 0, pants = 0 },
	F = { shirt = 0, pants = 0 },
}
------------------------------------------------------------------

local ws = workspace
local folder = ws:FindFirstChild("Mannequins")
assert(folder, "Folder 'Mannequins' tidak ada di Workspace - jalankan dulu script generator")

local function setAsset(rig: Model, className: string, propName: string, id: number)
	if id <= 0 then
		return false
	end
	local obj = rig:FindFirstChildOfClass(className)
	if not obj then
		obj = Instance.new(className)
		obj.Parent = rig
	end
	;(obj :: any)[propName] = "rbxassetid://" .. id
	return true
end

local dressed, skipped = 0, 0

for _, rig in ipairs(folder:GetChildren()) do
	if not rig:IsA("Model") then
		continue
	end

	local gender = rig:GetAttribute("Gender") :: string?
	local index = rig:GetAttribute("PodiumIndex") :: number?
	if not gender or not index then
		skipped += 1
		continue
	end

	-- 1. attribute langsung di mannequin ini
	local shirt = rig:GetAttribute("ShirtId") :: number?
	local pants = rig:GetAttribute("PantsId") :: number?

	-- 2. catalog per podium
	local entry = CATALOG[index] and CATALOG[index][gender :: any]
	if entry then
		shirt = shirt or entry.shirt
		pants = pants or entry.pants
	end

	-- 3. fallback global
	local fb = FALLBACK[gender :: any]
	if fb then
		shirt = shirt or fb.shirt
		pants = pants or fb.pants
	end

	local a = setAsset(rig, "Shirt", "ShirtTemplate", shirt or 0)
	local b = setAsset(rig, "Pants", "PantsTemplate", pants or 0)

	if a or b then
		dressed += 1
	else
		skipped += 1
	end
end

print(string.format("MannequinDresser: %d mannequin dipakaikan baju, %d dilewati", dressed, skipped))
