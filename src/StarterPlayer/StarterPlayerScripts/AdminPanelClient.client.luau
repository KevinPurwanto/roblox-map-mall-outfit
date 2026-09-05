--!strict
-- AdminPanelClient
-- Panel admin untuk lihat/edit semua podium sekaligus, tanpa jalan ke tiap
-- mannequin satu-satu. Sama seperti ShowroomClient: UI di sini kosmetik,
-- validasi asli (role + tipe argumen) ada di Showroom.server.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GetMyRole = remotes:WaitForChild("GetMyRole") :: RemoteFunction
local GetAllMannequins = remotes:WaitForChild("GetAllMannequins") :: RemoteFunction
local SetOutfitByIndex = remotes:WaitForChild("SetOutfitByIndex") :: RemoteEvent

local PINK_DARK = Color3.fromRGB(214, 92, 150)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local NEUTRAL = Color3.fromRGB(235, 235, 240)

type Outfit = { shirt: number, pants: number }
type PodiumRow = { name: string, M: Outfit, F: Outfit }

-- ambil angka pertama dari teks -- terima link katalog penuh maupun assetId polos
-- (server yang resolve link/ID katalog ke ShirtTemplate/PantsTemplate asli)
local function extractId(text: string): number
	local digits = text:match("%d+")
	return (digits and tonumber(digits)) or 0
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

------------------------------------------------------------------
-- Rangka
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanelUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleAdminPanel"
toggleBtn.Position = UDim2.new(0, 16, 0, 16)
toggleBtn.Size = UDim2.new(0, 180, 0, 36)
toggleBtn.BackgroundColor3 = PINK_DARK
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "Kelola Semua Podium"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Visible = false
toggleBtn.Parent = gui
corner(toggleBtn, 8)

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.ZIndex = 10
backdrop.Parent = gui

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.new(0, 720, 0, 560)
window.BackgroundColor3 = PAPER
window.BorderSizePixel = 0
window.ZIndex = 11
window.Parent = backdrop
corner(window, 16)

local headerTitle = Instance.new("TextLabel")
headerTitle.Position = UDim2.new(0, 20, 0, 14)
headerTitle.Size = UDim2.new(1, -220, 0, 24)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "Kelola Semua Podium"
headerTitle.TextColor3 = PINK_DARK
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 20
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 11
headerTitle.Parent = window

local refreshBtn = Instance.new("TextButton")
refreshBtn.Position = UDim2.new(1, -190, 0, 14)
refreshBtn.Size = UDim2.new(0, 80, 0, 30)
refreshBtn.BackgroundColor3 = NEUTRAL
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "Muat ulang"
refreshBtn.TextColor3 = INK
refreshBtn.Font = Enum.Font.GothamMedium
refreshBtn.TextSize = 13
refreshBtn.ZIndex = 11
refreshBtn.Parent = window
corner(refreshBtn, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.new(1, -100, 0, 14)
closeBtn.Size = UDim2.new(0, 80, 0, 30)
closeBtn.BackgroundColor3 = NEUTRAL
closeBtn.BorderSizePixel = 0
closeBtn.Text = "Tutup"
closeBtn.TextColor3 = INK
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 13
closeBtn.ZIndex = 11
closeBtn.Parent = window
corner(closeBtn, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Position = UDim2.new(0, 20, 0, 44)
statusLabel.Size = UDim2.new(1, -40, 0, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = INK
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 11
statusLabel.Parent = window

local scroller = Instance.new("ScrollingFrame")
scroller.Position = UDim2.new(0, 12, 0, 68)
scroller.Size = UDim2.new(1, -24, 1, -80)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollBarThickness = 6
scroller.ZIndex = 11
scroller.Parent = window

local rowList = Instance.new("UIListLayout")
rowList.Padding = UDim.new(0, 6)
rowList.SortOrder = Enum.SortOrder.LayoutOrder
rowList.Parent = scroller

------------------------------------------------------------------
-- Satu field gender (label + Shirt + Pants)
------------------------------------------------------------------
local function genderField(parent: Instance, label: string, order: number, outfit: Outfit): (TextBox, TextBox)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(0.5, -4, 1, 0)
	box.BackgroundTransparency = 1
	box.LayoutOrder = order
	box.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = box

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0, 16, 1, 0)
	tag.BackgroundTransparency = 1
	tag.Text = label
	tag.TextColor3 = PINK_DARK
	tag.Font = Enum.Font.GothamBold
	tag.TextSize = 13
	tag.LayoutOrder = 1
	tag.Parent = box

	local shirtBox = Instance.new("TextBox")
	shirtBox.Size = UDim2.new(0, 74, 0, 26)
	shirtBox.BackgroundColor3 = Color3.new(1, 1, 1)
	shirtBox.BorderSizePixel = 0
	shirtBox.PlaceholderText = "Shirt"
	shirtBox.Text = outfit.shirt > 0 and tostring(outfit.shirt) or ""
	shirtBox.ClearTextOnFocus = false
	shirtBox.Font = Enum.Font.Gotham
	shirtBox.TextSize = 12
	shirtBox.TextColor3 = INK
	shirtBox.LayoutOrder = 2
	shirtBox.Parent = box
	corner(shirtBox, 6)

	local pantsBox = Instance.new("TextBox")
	pantsBox.Size = UDim2.new(0, 74, 0, 26)
	pantsBox.BackgroundColor3 = Color3.new(1, 1, 1)
	pantsBox.BorderSizePixel = 0
	pantsBox.PlaceholderText = "Pants"
	pantsBox.Text = outfit.pants > 0 and tostring(outfit.pants) or ""
	pantsBox.ClearTextOnFocus = false
	pantsBox.Font = Enum.Font.Gotham
	pantsBox.TextSize = 12
	pantsBox.TextColor3 = INK
	pantsBox.LayoutOrder = 3
	pantsBox.Parent = box
	corner(pantsBox, 6)

	return shirtBox, pantsBox
end

------------------------------------------------------------------
-- Satu baris podium (nomor + field M + field F + tombol simpan)
------------------------------------------------------------------
local function buildRow(podiumIndex: number, data: PodiumRow): Frame
	local row = Instance.new("Frame")
	row.Name = "Podium" .. tostring(podiumIndex)
	row.Size = UDim2.new(1, 0, 0, 60)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.LayoutOrder = podiumIndex
	row.ZIndex = 11
	corner(row, 10)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = row

	local idLabel = Instance.new("TextLabel")
	idLabel.Position = UDim2.new(0, 0, 0, 0)
	idLabel.Size = UDim2.new(0, 130, 1, 0)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = string.format("#%d  %s", podiumIndex, data.name)
	idLabel.TextColor3 = INK
	idLabel.Font = Enum.Font.GothamMedium
	idLabel.TextSize = 13
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.TextWrapped = true
	idLabel.ZIndex = 11
	idLabel.Parent = row

	local fieldsHolder = Instance.new("Frame")
	fieldsHolder.Position = UDim2.new(0, 140, 0, 0)
	fieldsHolder.Size = UDim2.new(1, -240, 1, 0)
	fieldsHolder.BackgroundTransparency = 1
	fieldsHolder.ZIndex = 11
	fieldsHolder.Parent = row

	local fieldsLayout = Instance.new("UIListLayout")
	fieldsLayout.FillDirection = Enum.FillDirection.Horizontal
	fieldsLayout.Padding = UDim.new(0, 8)
	fieldsLayout.Parent = fieldsHolder

	local mShirt, mPants = genderField(fieldsHolder, "M", 1, data.M)
	local fShirt, fPants = genderField(fieldsHolder, "F", 2, data.F)

	local saveBtn = Instance.new("TextButton")
	saveBtn.AnchorPoint = Vector2.new(1, 0.5)
	saveBtn.Position = UDim2.new(1, 0, 0.5, 0)
	saveBtn.Size = UDim2.new(0, 80, 0, 30)
	saveBtn.BackgroundColor3 = PINK_DARK
	saveBtn.BorderSizePixel = 0
	saveBtn.Text = "Simpan"
	saveBtn.TextColor3 = Color3.new(1, 1, 1)
	saveBtn.Font = Enum.Font.GothamMedium
	saveBtn.TextSize = 13
	saveBtn.ZIndex = 11
	saveBtn.Parent = row
	corner(saveBtn, 8)

	saveBtn.MouseButton1Click:Connect(function()
		local ms, mp = extractId(mShirt.Text), extractId(mPants.Text)
		local fs, fp = extractId(fShirt.Text), extractId(fPants.Text)
		SetOutfitByIndex:FireServer(podiumIndex, "M", ms, mp)
		SetOutfitByIndex:FireServer(podiumIndex, "F", fs, fp)
		saveBtn.Text = "Tersimpan"
		task.wait(1)
		saveBtn.Text = "Simpan"
	end)

	return row
end

------------------------------------------------------------------
-- Muat data dari server
------------------------------------------------------------------
local function clearRows()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function loadAll()
	statusLabel.Text = "Memuat..."
	clearRows()

	local ok, list = pcall(function()
		return GetAllMannequins:InvokeServer()
	end)
	if not ok or typeof(list) ~= "table" then
		statusLabel.Text = "Gagal memuat data dari server."
		return
	end

	local byIndex: { [number]: PodiumRow } = {}
	for _, item in ipairs(list) do
		local entry = byIndex[item.podiumIndex]
		if not entry then
			entry = { name = item.name, M = { shirt = 0, pants = 0 }, F = { shirt = 0, pants = 0 } }
			byIndex[item.podiumIndex] = entry
		end
		if item.gender == "M" then
			entry.M = { shirt = item.shirt, pants = item.pants }
		elseif item.gender == "F" then
			entry.F = { shirt = item.shirt, pants = item.pants }
		end
	end

	local indices = {}
	for podiumIndex in pairs(byIndex) do
		table.insert(indices, podiumIndex)
	end
	table.sort(indices)

	for _, podiumIndex in ipairs(indices) do
		buildRow(podiumIndex, byIndex[podiumIndex]).Parent = scroller
	end

	statusLabel.Text = string.format("%d podium dimuat.", #indices)
end

------------------------------------------------------------------
-- Buka / tutup
------------------------------------------------------------------
local function openPanel()
	backdrop.Visible = true
	loadAll()
end

local function closePanel()
	backdrop.Visible = false
end

toggleBtn.MouseButton1Click:Connect(openPanel)
closeBtn.MouseButton1Click:Connect(closePanel)
refreshBtn.MouseButton1Click:Connect(loadAll)

------------------------------------------------------------------
-- Dicek berkala (bukan cuma sekali di spawn) supaya tombol ini ikut muncul
-- kalau role berubah di tengah sesi (Debug Tools ganti POV, atau admin
-- diangkat/dicabut lewat ManageAdmin) -- tombol ini hanya disembunyikan di
-- sini; server tetap menolak SetOutfitByIndex kalau role beneran bukan admin.
task.spawn(function()
	while true do
		local ok, role = pcall(function()
			return GetMyRole:InvokeServer()
		end)
		toggleBtn.Visible = ok and typeof(role) == "string" and (role == "ADMIN" or role == "SUPERADMIN")
		task.wait(2)
	end
end)
