--!strict
-- Tempel di Command Bar Roblox Studio, ganti CATALOG_ID di bawah, lalu Enter.
--
-- Classic Shirt/Pants punya 2 ID berbeda:
--   1. ID katalog -- yang ada di URL roblox.com/catalog/<ID>/Nama-Item
--   2. ID ShirtTemplate/PantsTemplate -- tekstur asli di dalamnya, angka BEDA
-- MannequinCatalog.luau dan attribute ShirtId/PantsId di mannequin butuh yang
-- KEDUA, bukan ID katalog -- itu sebabnya baju tidak pernah kelihatan walau
-- ID-nya "benar" menurut halaman katalog.
------------------------------------------------------------------
local CATALOG_ID = 18728338281
------------------------------------------------------------------

local InsertService = game:GetService("InsertService")

local ok, result = pcall(function()
	return InsertService:LoadAsset(CATALOG_ID)
end)
assert(ok, "Gagal load asset " .. CATALOG_ID .. " -- pastikan ID benar dan bisa diakses: " .. tostring(result))

local model = result :: Model
local shirt = model:FindFirstChildOfClass("Shirt")
local pants = model:FindFirstChildOfClass("Pants")

if shirt then
	print(string.format("Shirt (katalog %d) -> ShirtTemplate: %s", CATALOG_ID, shirt.ShirtTemplate))
elseif pants then
	print(string.format("Pants (katalog %d) -> PantsTemplate: %s", CATALOG_ID, pants.PantsTemplate))
else
	warn(string.format(
		"ID %d bukan Shirt/Pants classic -- kemungkinan Layered Clothing/Accessory (item ini tidak akan bekerja lewat ShirtTemplate). Isi model:",
		CATALOG_ID))
	for _, child in ipairs(model:GetChildren()) do
		print("  ->", child.ClassName, child.Name)
	end
end

model:Destroy()
