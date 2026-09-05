--!strict
-- Tempel di Command Bar Roblox Studio, lalu Enter.
-- Menaruh sepasang mannequin (1 cowok + 1 cewek) di atas setiap AvatarPodium.
-- Semua hasil masuk ke Workspace.Mannequins -> hapus folder itu untuk undo.

------------------------------------------------------------------
-- PENGATURAN
------------------------------------------------------------------
local AUTO_SPACING = true   -- true = jarak dihitung dari lebar bahu rig + GAP
local GAP          = 0.5    -- celah antar bahu cowok & cewek (studs)
local SPACING      = 4.5    -- dipakai hanya kalau AUTO_SPACING = false
local LIFT         = 0.05   -- celah kecil dari permukaan podium
local FACE_FLIP    = false  -- true kalau arah hadapnya terbalik
local SWAP_SIDES   = true   -- true = cewek di kiri, cowok di kanan
local FACE_INWARD  = false  -- true = keduanya saling serong menghadap ke tengah
local CLEAR_EXIST  = true   -- hapus folder Mannequins lama dulu

-- opsional, isi assetId kalau mau langsung dipakaikan baju bawaan (0 = lewati)
local DEFAULT_SHIRT_M, DEFAULT_PANTS_M = 0, 0
local DEFAULT_SHIRT_F, DEFAULT_PANTS_F = 0, 0

-- PodiumIndex asalnya cuma ikut urutan child di Explorer (acak, tidak sesuai
-- posisi fisik). Map ini grid rapi 12 kolom x 10 podium (sudah dicek dari data
-- koordinat asli: kolom terpisah 24 studs di sumbu X, ada celah ~50 studs di
-- tengah tiap kolom -- kemungkinan lorong melintang, tapi tetap satu jalur).
-- Sempat dicoba nearest-neighbor supaya tidak perlu asumsi grid, tapi celah
-- yang berulang di tiap kolom itu malah bikin nearest-neighbor loncat-loncat
-- antar kolom di titik yang sama -- jadi baris/kolom manual ternyata lebih pas
-- untuk map spesifik ini.
local SORT_PODIUMS   = true  -- false = balik ke urutan Explorer apa adanya
local ROW_AXIS       = "X"   -- sumbu pengelompokan kolom -- JANGAN ganti ke "Z" (sudah terbukti bikin baris ketuker di map ini, grid-nya sedikit miring)
local ROW_TOLERANCE  = 6     -- studs; beda <= ini dianggap masih kolom yang sama
local ROW_DESCENDING = true  -- true = mulai dari kolom paling dekat SpawnLocation (-112,6,-203)
local ZIGZAG_ROWS    = true  -- arah bolak-balik tiap kolom (jalur jalan kaki alami)
local PRINT_ORDER    = true  -- cetak #index -> posisi ke Output untuk verifikasi manual
------------------------------------------------------------------

local ws = workspace

local podiumFolder = ws:FindFirstChild("AvatarPodium")
assert(podiumFolder, "Folder 'AvatarPodium' tidak ada di Workspace")

------------------------------------------------------------------
-- 1. Cari template cowok & cewek
------------------------------------------------------------------
local function isRig(obj: Instance): boolean
	return obj:IsA("Model")
		and obj:FindFirstChildOfClass("Humanoid") ~= nil
		and obj:FindFirstChild("HumanoidRootPart") ~= nil
end

local function looksFemale(rig: Model): boolean
	-- paket badan Woman dipasang lewat CharacterMesh; rig default tidak punya ini
	return rig:FindFirstChildOfClass("CharacterMesh") ~= nil
end

local maleTpl: Model?, femaleTpl: Model? = nil, nil

-- cari di Workspace, ServerStorage, dan ReplicatedStorage
local searchIn = {
	ws,
	game:GetService("ServerStorage"),
	game:GetService("ReplicatedStorage"),
}
for _, container in ipairs(searchIn) do
	for _, obj in ipairs(container:GetChildren()) do
		if isRig(obj) then
			if looksFemale(obj :: Model) then
				femaleTpl = femaleTpl or obj :: Model
			else
				maleTpl = maleTpl or obj :: Model
			end
		end
	end
end

-- override manual: rename rig-mu jadi RigMale / RigFemale kalau deteksi meleset
for _, container in ipairs(searchIn) do
	maleTpl = (container:FindFirstChild("RigMale") :: Model?) or maleTpl
	femaleTpl = (container:FindFirstChild("RigFemale") :: Model?) or femaleTpl
end

-- kalau cuma ketemu satu rig, pakai itu untuk dua-duanya
if maleTpl and not femaleTpl then
	warn("Rig cewek tidak ketemu - memakai rig cowok untuk kedua slot.")
	femaleTpl = maleTpl
elseif femaleTpl and not maleTpl then
	warn("Rig cowok tidak ketemu - memakai rig cewek untuk kedua slot.")
	maleTpl = femaleTpl
end

assert(maleTpl and femaleTpl,
	"Tidak ada satu pun Model berisi Humanoid + HumanoidRootPart di Workspace/ServerStorage/ReplicatedStorage")
print("Template cowok:", (maleTpl :: Model):GetFullName(), "| cewek:", (femaleTpl :: Model):GetFullName())

------------------------------------------------------------------
-- 2. Folder output
------------------------------------------------------------------
local old = ws:FindFirstChild("Mannequins")
if old and CLEAR_EXIST then
	old:Destroy()
	old = nil
end
local folder = old
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Mannequins"
	folder.Parent = ws
end

------------------------------------------------------------------
-- 3. Jadikan patung statis
------------------------------------------------------------------
local function applyClothes(rig: Model, shirtId: number, pantsId: number)
	if shirtId > 0 then
		local s = rig:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
		s.ShirtTemplate = "rbxassetid://" .. shirtId
		s.Parent = rig
	end
	if pantsId > 0 then
		local p = rig:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		p.PantsTemplate = "rbxassetid://" .. pantsId
		p.Parent = rig
	end
end

local function prepare(rig: Model, gender: string)
	rig.Name = (gender == "M") and "Mannequin_M" or "Mannequin_F"

	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- buang Animate dsb biar tidak jalan sendiri
		end
	end
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Camera") then
			d:Destroy() -- ThumbnailCamera bawaan Accessory, tidak terpakai
		end
	end

	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.RequiresNeck = false
		pcall(function()
			(hum :: any).EvaluateStateMachine = false
		end)
	end

	rig.PrimaryPart = (rig:FindFirstChild("HumanoidRootPart") :: BasePart?) or rig.PrimaryPart

	if gender == "M" then
		applyClothes(rig, DEFAULT_SHIRT_M, DEFAULT_PANTS_M)
	else
		applyClothes(rig, DEFAULT_SHIRT_F, DEFAULT_PANTS_F)
	end
end

------------------------------------------------------------------
-- 4. Urutkan podium berdasar posisi (bukan urutan acak Explorer)
------------------------------------------------------------------
type Candidate = { podium: Instance, cf: CFrame, size: Vector3, rowValue: number, colValue: number }

local function axisValue(pos: Vector3, axis: string): number
	if axis == "X" then
		return pos.X
	end
	return pos.Z
end

local colAxis = (ROW_AXIS == "X") and "Z" or "X"

local function sortPodiums(list: { Candidate }): { Candidate }
	table.sort(list, function(a, b)
		return a.rowValue < b.rowValue
	end)

	-- kelompokkan jadi kolom: item baru gabung kolom berjalan kalau masih
	-- dalam toleransi dari rata-rata kolom itu, kalau tidak buka kolom baru
	local rows: { { Candidate } } = {}
	local rowSum, rowCount = 0, 0
	for _, item in ipairs(list) do
		local row = rows[#rows]
		if row == nil or math.abs(item.rowValue - rowSum / rowCount) > ROW_TOLERANCE then
			row = {}
			table.insert(rows, row)
			rowSum, rowCount = 0, 0
		end
		table.insert(row, item)
		rowSum += item.rowValue
		rowCount += 1
	end

	for i, row in ipairs(rows) do
		local descending = ZIGZAG_ROWS and (i % 2 == 0)
		table.sort(row, function(a, b)
			if descending then
				return a.colValue > b.colValue
			end
			return a.colValue < b.colValue
		end)
	end

	if ROW_DESCENDING then
		local reversed: { { Candidate } } = {}
		for i = #rows, 1, -1 do
			table.insert(reversed, rows[i])
		end
		rows = reversed
	end

	local sorted: { Candidate } = {}
	for _, row in ipairs(rows) do
		for _, item in ipairs(row) do
			table.insert(sorted, item)
		end
	end
	return sorted
end

------------------------------------------------------------------
-- 5. Tempatkan
------------------------------------------------------------------
local candidates: { Candidate } = {}
for _, podium in ipairs(podiumFolder:GetChildren()) do
	local cf: CFrame, size: Vector3

	if podium:IsA("Model") then
		cf, size = podium:GetBoundingBox()
	elseif podium:IsA("BasePart") then
		cf, size = podium.CFrame, podium.Size
	else
		continue
	end

	table.insert(candidates, {
		podium = podium,
		cf = cf,
		size = size,
		rowValue = axisValue(cf.Position, ROW_AXIS),
		colValue = axisValue(cf.Position, colAxis),
	})
end

if SORT_PODIUMS then
	candidates = sortPodiums(candidates)
end

local count, index = 0, 0

for _, candidate in ipairs(candidates) do
	local podium, cf, size = candidate.podium, candidate.cf, candidate.size

	index += 1
	do
		-- strip suffix _NNN lama dulu (kalau ada) supaya rerun tidak menumpuk jadi _047_047
		local baseName = podium.Name:match("^(.-)_%d+$") or podium.Name
		podium.Name = string.format("%s_%03d", baseName, index)
	end
	if PRINT_ORDER then
		print(string.format("  #%d -> %s @ (%.1f, %.1f, %.1f)",
			index, podium:GetFullName(), cf.Position.X, cf.Position.Y, cf.Position.Z))
	end
	local top = cf.Position.Y + size.Y / 2

	-- berjajar di sisi panjang podium, menghadap sisi pendek
	local axis, faceDir
	if size.X >= size.Z then
		axis, faceDir = cf.RightVector, cf.LookVector
	else
		axis, faceDir = cf.LookVector, cf.RightVector
	end
	axis = Vector3.new(axis.X, 0, axis.Z).Unit
	faceDir = Vector3.new(faceDir.X, 0, faceDir.Z).Unit
	if FACE_FLIP then
		faceDir = -faceDir
	end

	local pairing = {
		{ tpl = maleTpl :: Model, gender = "M", side = SWAP_SIDES and 1 or -1 },
		{ tpl = femaleTpl :: Model, gender = "F", side = SWAP_SIDES and -1 or 1 },
	}

	-- clone & ukur dulu, baru tentukan jaraknya
	local prepared = {}
	for _, slot in ipairs(pairing) do
		local rig = slot.tpl:Clone()
		prepare(rig, slot.gender)

		-- PrimaryPart sudah diset di prepare(), jadi bbox ini ikut orientasi rig:
		-- rsize.X = lebar bahu, rsize.Y = tinggi total
		local rcf, rsize = rig:GetBoundingBox()
		local footY = rcf.Position.Y - rsize.Y / 2

		table.insert(prepared, {
			rig = rig,
			gender = slot.gender,
			side = slot.side,
			width = rsize.X,
			pivotY = rig:GetPivot().Position.Y - footY,
		})
	end

	local spacing = SPACING
	if AUTO_SPACING then
		-- setengah lebar masing-masing + celah = bahu tidak saling tembus
		spacing = (prepared[1].width + prepared[2].width) / 2 + GAP
	end

	for _, item in ipairs(prepared) do
		local rig = item.rig
		local pos = Vector3.new(cf.Position.X, top + LIFT + item.pivotY, cf.Position.Z)
			+ axis * (spacing / 2 * item.side)

		local look = faceDir
		if FACE_INWARD then
			look = (faceDir - axis * item.side * 0.4).Unit
		end

		rig:PivotTo(CFrame.lookAt(pos, pos + look))
		rig:SetAttribute("PodiumIndex", index)
		rig:SetAttribute("Gender", item.gender)
		rig.Name = string.format("%s_%03d", rig.Name, index) -- "Mannequin_M_047" -- biar urutan kelihatan langsung di Explorer
		rig.Parent = folder
		count += 1
	end
end

print(string.format("Selesai: %d mannequin (%d pasang) di %d podium -> Workspace.Mannequins",
	count, count // 2, index))
