--!strict
-- AdminPanelClient
-- "Kelola Semua Podium": peta 120 podium + panel detail, supaya admin bisa
-- langsung tahu podium mana yang masih kosong, melihat bajunya sebagai gambar
-- (bukan angka ID), dan lompat ke podium itu di map.
--
-- Desain lama = 120 baris kotak teks ID mentah. Tiga masalahnya, dan jawabannya:
--   1. Tidak kelihatan mana yang belum diisi  -> kotak berwarna per status +
--      filter Kosong/Sebagian/Lengkap + progres "x/240 terisi"
--   2. Angka ID tidak bisa dicek benar/salah  -> pratinjau thumbnail langsung
--      begitu ID/link ditempel (ID tekstur yang salah langsung kelihatan aneh)
--   3. "Podium 47 itu yang mana?"             -> tombol Teleport ke podium itu
--
-- Sama seperti panel lain: UI di sini kosmetik, validasi asli (role + argumen)
-- ada di Showroom.server.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GetMyRole = remotes:WaitForChild("GetMyRole") :: RemoteFunction
local GetAllMannequins = remotes:WaitForChild("GetAllMannequins") :: RemoteFunction
local SetOutfitByIndex = remotes:WaitForChild("SetOutfitByIndex") :: RemoteEvent
local TeleportToPodium = remotes:WaitForChild("TeleportToPodium") :: RemoteFunction
local ResetLikes = remotes:WaitForChild("ResetLikes") :: RemoteEvent

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local MUTED = Color3.fromRGB(130, 120, 125)
local NEUTRAL = Color3.fromRGB(235, 235, 240)
local WHITE = Color3.new(1, 1, 1)

-- Warna status. Sengaja tiga warna yang jauh beda (abu/kuning/hijau), bukan
-- gradasi pink: admin harus bisa memindai 120 kotak sekilas.
local STATUS_COLOR = {
	empty = Color3.fromRGB(226, 222, 228),
	partial = Color3.fromRGB(255, 214, 128),
	full = Color3.fromRGB(150, 220, 170),
}
local STATUS_LABEL = { all = "Semua", empty = "Kosong", partial = "Sebagian", full = "Lengkap" }

-- di bawah lebar jendela ini, grid + detail berdampingan terlalu sempit ->
-- detail ditampilkan menutupi grid, dengan tombol Kembali
local WIDE_BREAKPOINT = 720
local DETAIL_WIDTH = 340

type GenderData = { shirt: number, pants: number, accessoryCount: number, likes: number }
type PodiumData = { index: number, name: string, M: GenderData?, F: GenderData? }
type Status = "empty" | "partial" | "full"

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function label(parent: Instance, text: string, size: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = INK
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, textColor: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = textColor or INK
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

-- ambil angka pertama dari teks -- terima link katalog penuh maupun assetId polos
local function extractId(text: string): number
	local digits = text:match("%d+")
	return (digits and tonumber(digits)) or 0
end

local function thumbFor(assetId: number): string
	if assetId <= 0 then
		return ""
	end
	return string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", assetId)
end

local function genderFilled(g: GenderData?): boolean
	return g ~= nil and (g.shirt > 0 or g.pants > 0)
end

local function statusOf(p: PodiumData): Status
	local filled, total = 0, 0
	for _, g in ipairs({ p.M, p.F }) do
		if g then
			total += 1
			if genderFilled(g) then
				filled += 1
			end
		end
	end
	if filled == 0 then
		return "empty"
	elseif filled == total then
		return "full"
	end
	return "partial"
end

------------------------------------------------------------------
-- Rangka
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanelUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = button(gui, "Kelola Semua Podium", PINK_DARK, WHITE)
toggleBtn.Name = "ToggleAdminPanel"
toggleBtn.Position = UDim2.new(0, 16, 0, 16)
toggleBtn.Size = UDim2.new(0, 180, 0, 36)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Visible = false

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
window.Size = UDim2.new(0.94, 0, 0.9, 0)
window.BackgroundColor3 = PAPER
window.BorderSizePixel = 0
window.Parent = backdrop
corner(window, 16)

local windowSize = Instance.new("UISizeConstraint")
windowSize.MinSize = Vector2.new(320, 320)
windowSize.MaxSize = Vector2.new(980, 640)
windowSize.Parent = window

local wPad = Instance.new("UIPadding")
wPad.PaddingTop = UDim.new(0, 14)
wPad.PaddingBottom = UDim.new(0, 14)
wPad.PaddingLeft = UDim.new(0, 16)
wPad.PaddingRight = UDim.new(0, 16)
wPad.Parent = window

------------------------------------------------------------------
-- Header: judul + progres + tombol
------------------------------------------------------------------
local title = label(window, "Kelola Semua Podium", 20, true)
title.TextColor3 = PINK_DARK
title.Size = UDim2.new(1, -340, 0, 24) -- sisakan ruang untuk 3 tombol header

local progressLabel = label(window, "", 12)
progressLabel.Position = UDim2.new(0, 0, 0, 26)
progressLabel.Size = UDim2.new(1, -340, 0, 16)
progressLabel.TextColor3 = MUTED

local refreshBtn = button(window, "Muat ulang", NEUTRAL)
refreshBtn.AnchorPoint = Vector2.new(1, 0)
refreshBtn.Position = UDim2.new(1, -88, 0, 0)
refreshBtn.Size = UDim2.new(0, 84, 0, 30)

-- Tutup di header, BUKAN di dalam area scroll -- selalu terjangkau
local closeBtn = button(window, "Tutup", NEUTRAL)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, 0, 0, 0)
closeBtn.Size = UDim2.new(0, 80, 0, 30)

-- Reset SEMUA suka -- khusus SUPERADMIN, sengaja ditaruh di sini dan BUKAN di
-- panel mannequin. Di sana ia duduk dekat tombol yang sering diklik, dan
-- pengaman "klik sekali lagi" lolos oleh double-click biasa. Di sini tombolnya
-- cuma membuka dialog; yang benar-benar menghapus butuh mengetik "RESET".
local resetAllBtn = button(window, "⚠ Reset semua suka", Color3.fromRGB(255, 226, 226), Color3.fromRGB(170, 40, 60))
resetAllBtn.AnchorPoint = Vector2.new(1, 0)
resetAllBtn.Position = UDim2.new(1, -180, 0, 0)
resetAllBtn.Size = UDim2.new(0, 150, 0, 30)
resetAllBtn.TextSize = 12
resetAllBtn.Visible = false

-- Bar progres: angka saja gampang dilewatkan, batang yang terisi langsung
-- memberi rasa "tinggal berapa lagi"
local progressTrack = Instance.new("Frame")
progressTrack.Position = UDim2.new(0, 0, 0, 46)
progressTrack.Size = UDim2.new(1, 0, 0, 6)
progressTrack.BackgroundColor3 = STATUS_COLOR.empty
progressTrack.BorderSizePixel = 0
progressTrack.Parent = window
corner(progressTrack, 3)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = PINK_DARK
progressFill.BorderSizePixel = 0
progressFill.Parent = progressTrack
corner(progressFill, 3)

------------------------------------------------------------------
-- Toolbar: lompat ke nomor + filter status
------------------------------------------------------------------
local TOOLBAR_Y = 60

local searchBox = Instance.new("TextBox")
searchBox.Position = UDim2.new(0, 0, 0, TOOLBAR_Y)
searchBox.Size = UDim2.new(0, 150, 0, 30)
searchBox.BackgroundColor3 = WHITE
searchBox.BorderSizePixel = 0
searchBox.PlaceholderText = "Lompat ke no. (1-120)"
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.TextColor3 = INK
searchBox.Parent = window
corner(searchBox, 8)

local chipRow = Instance.new("Frame")
chipRow.Position = UDim2.new(0, 160, 0, TOOLBAR_Y)
chipRow.Size = UDim2.new(1, -160, 0, 30)
chipRow.BackgroundTransparency = 1
chipRow.Parent = window

local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.Padding = UDim.new(0, 6)
chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipLayout.Parent = chipRow

local activeFilter = "all"
local chips: { [string]: TextButton } = {}

------------------------------------------------------------------
-- Area isi: grid (kiri) + detail (kanan)
------------------------------------------------------------------
local CONTENT_Y = TOOLBAR_Y + 40

local content = Instance.new("Frame")
content.Position = UDim2.new(0, 0, 0, CONTENT_Y)
content.Size = UDim2.new(1, 0, 1, -CONTENT_Y)
content.BackgroundTransparency = 1
content.Parent = window

local grid = Instance.new("ScrollingFrame")
grid.Name = "PodiumGrid"
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.CanvasSize = UDim2.new(0, 0, 0, 0)
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollBarThickness = 5
grid.ZIndex = 1
grid.Parent = content

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 64, 0, 64)
gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 3)
gridPad.PaddingLeft = UDim.new(0, 3)
gridPad.Parent = grid

local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.BackgroundColor3 = ROW_BG
detail.BorderSizePixel = 0
detail.ZIndex = 2 -- di atas grid saat mode sempit (menutupinya)
detail.Parent = content
corner(detail, 12)

local dPad = Instance.new("UIPadding")
dPad.PaddingTop = UDim.new(0, 12)
dPad.PaddingBottom = UDim.new(0, 12)
dPad.PaddingLeft = UDim.new(0, 12)
dPad.PaddingRight = UDim.new(0, 12)
dPad.Parent = detail

local placeholder = label(detail, "← Pilih podium di peta untuk mengubah isinya.", 13)
placeholder.Size = UDim2.new(1, 0, 1, 0)
placeholder.TextWrapped = true
placeholder.TextXAlignment = Enum.TextXAlignment.Center
placeholder.TextColor3 = MUTED

------------------------------------------------------------------
-- Isi panel detail
------------------------------------------------------------------
local detailBody = Instance.new("Frame")
detailBody.Size = UDim2.fromScale(1, 1)
detailBody.BackgroundTransparency = 1
detailBody.Visible = false
detailBody.Parent = detail

-- tombol Kembali cuma muncul di mode sempit (detail menutupi grid)
local backBtn = button(detailBody, "← Kembali", NEUTRAL)
backBtn.Size = UDim2.new(0, 90, 0, 26)
backBtn.TextSize = 12
backBtn.Visible = false

local detailTitle = label(detailBody, "", 16, true)
detailTitle.TextColor3 = PINK_DARK
detailTitle.Size = UDim2.new(1, 0, 0, 22)

local detailSub = label(detailBody, "", 12)
detailSub.TextColor3 = MUTED
detailSub.Size = UDim2.new(1, 0, 0, 16)

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 30)
actionRow.BackgroundTransparency = 1
actionRow.Parent = detailBody

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 6)
actionLayout.Parent = actionRow

local teleportBtn = button(actionRow, "📍 Teleport ke sini", PINK)
teleportBtn.Size = UDim2.new(0.55, -3, 1, 0)
teleportBtn.TextSize = 12

local clearBtn = button(actionRow, "Kosongkan", NEUTRAL)
clearBtn.Size = UDim2.new(0.45, -3, 1, 0)
clearBtn.TextSize = 12

-- kartu M/F bisa lebih tinggi dari ruang yang ada di layar pendek -> discroll.
-- Tombol Simpan sengaja DI LUAR scroller ini, menempel di dasar (aturan layout).
local SAVE_HEIGHT = 34

local cardScroller = Instance.new("ScrollingFrame")
cardScroller.BackgroundTransparency = 1
cardScroller.BorderSizePixel = 0
cardScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
cardScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardScroller.ScrollBarThickness = 4
cardScroller.Parent = detailBody

local cardList = Instance.new("UIListLayout")
cardList.Padding = UDim.new(0, 8)
cardList.SortOrder = Enum.SortOrder.LayoutOrder
cardList.Parent = cardScroller

local saveBtn = button(detailBody, "Simpan podium ini", PINK_DARK, WHITE)
saveBtn.AnchorPoint = Vector2.new(0, 1)
saveBtn.Position = UDim2.new(0, 0, 1, 0)
saveBtn.Size = UDim2.new(1, 0, 0, SAVE_HEIGHT)
saveBtn.Font = Enum.Font.GothamBold

-- posisi vertikal elemen detail; diatur ulang saat tombol Kembali muncul/hilang
local function layoutDetail(showBack: boolean)
	local y = 0
	backBtn.Visible = showBack
	if showBack then
		backBtn.Position = UDim2.new(0, 0, 0, 0)
		y += 32
	end
	detailTitle.Position = UDim2.new(0, 0, 0, y)
	y += 22
	detailSub.Position = UDim2.new(0, 0, 0, y)
	y += 22
	actionRow.Position = UDim2.new(0, 0, 0, y)
	y += 38
	cardScroller.Position = UDim2.new(0, 0, 0, y)
	cardScroller.Size = UDim2.new(1, 0, 1, -(y + SAVE_HEIGHT + 8))
end

------------------------------------------------------------------
-- Kartu satu gender: thumbnail Shirt/Pants + kolom ID
------------------------------------------------------------------
type Card = {
	frame: Frame,
	note: TextLabel,
	shirtBox: TextBox,
	pantsBox: TextBox,
	shirtThumb: ImageLabel,
	pantsThumb: ImageLabel,
}

local function slot(parent: Instance, caption: string, order: number): (ImageLabel, TextBox)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.5, -4, 0, 118)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = parent

	local thumb = Instance.new("ImageLabel")
	thumb.AnchorPoint = Vector2.new(0.5, 0)
	thumb.Position = UDim2.new(0.5, 0, 0, 0)
	thumb.Size = UDim2.new(0, 72, 0, 72)
	thumb.BackgroundColor3 = WHITE
	thumb.BorderSizePixel = 0
	thumb.Parent = holder
	corner(thumb, 8)

	-- teks "kosong" di atas thumbnail; hilang otomatis begitu gambar ada
	local empty = label(thumb, caption, 11, true)
	empty.Name = "EmptyCaption"
	empty.Size = UDim2.fromScale(1, 1)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextColor3 = MUTED

	local box = Instance.new("TextBox")
	box.Position = UDim2.new(0, 0, 0, 78)
	box.Size = UDim2.new(1, 0, 0, 28)
	box.BackgroundColor3 = WHITE
	box.BorderSizePixel = 0
	box.PlaceholderText = caption .. ": link/ID"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.TextColor3 = INK
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.Parent = holder
	corner(box, 6)

	return thumb, box
end

local function setThumb(thumb: ImageLabel, assetId: number)
	thumb.Image = thumbFor(assetId)
	local caption = thumb:FindFirstChild("EmptyCaption") :: TextLabel?
	if caption then
		caption.Visible = assetId <= 0
	end
end

local function buildCard(heading: string, order: number): Card
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -6, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = PAPER
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.Parent = cardScroller
	corner(frame, 10)

	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local head = label(frame, heading, 13, true)
	head.Size = UDim2.new(1, 0, 0, 18)
	head.LayoutOrder = 1

	local slots = Instance.new("Frame")
	slots.Size = UDim2.new(1, 0, 0, 108)
	slots.BackgroundTransparency = 1
	slots.LayoutOrder = 2
	slots.Parent = frame

	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.Padding = UDim.new(0, 8)
	slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotLayout.Parent = slots

	local shirtThumb, shirtBox = slot(slots, "Shirt", 1)
	local pantsThumb, pantsBox = slot(slots, "Pants", 2)

	local note = label(frame, "", 11)
	note.Size = UDim2.new(1, 0, 0, 30)
	note.TextWrapped = true
	note.TextColor3 = MUTED
	note.LayoutOrder = 3

	-- Pratinjau langsung saat kolom ditinggalkan: kalau yang ditempel ternyata
	-- ID tekstur (bukan ID katalog), gambarnya langsung kelihatan beda -- flat,
	-- bukan render mannequin -- sebelum sempat disimpan.
	shirtBox.FocusLost:Connect(function()
		setThumb(shirtThumb, extractId(shirtBox.Text))
	end)
	pantsBox.FocusLost:Connect(function()
		setThumb(pantsThumb, extractId(pantsBox.Text))
	end)

	return {
		frame = frame,
		note = note,
		shirtBox = shirtBox,
		pantsBox = pantsBox,
		shirtThumb = shirtThumb,
		pantsThumb = pantsThumb,
	}
end

local cardM = buildCard("Cowok (M)", 1)
local cardF = buildCard("Cewek (F)", 2)

------------------------------------------------------------------
-- State
------------------------------------------------------------------
local podiums: { [number]: PodiumData } = {}
local cells: { [number]: { button: TextButton, stroke: UIStroke, dotM: Frame, dotF: Frame } } = {}
local selectedIndex: number? = nil
local detailOpenNarrow = false

local function isWide(): boolean
	return window.AbsoluteSize.X >= WIDE_BREAKPOINT
end

local function relayout()
	if isWide() then
		grid.Size = UDim2.new(1, -(DETAIL_WIDTH + 12), 1, 0)
		detail.Position = UDim2.new(1, -DETAIL_WIDTH, 0, 0)
		detail.Size = UDim2.new(0, DETAIL_WIDTH, 1, 0)
		detail.Visible = true
		grid.Visible = true
		layoutDetail(false)
	else
		-- mode sempit: grid penuh; detail menutupi grid hanya saat dibuka
		grid.Size = UDim2.fromScale(1, 1)
		detail.Position = UDim2.fromScale(0, 0)
		detail.Size = UDim2.fromScale(1, 1)
		detail.Visible = detailOpenNarrow
		layoutDetail(true)
	end
end

window:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

------------------------------------------------------------------
-- Peta podium
------------------------------------------------------------------
local function paintCell(index: number)
	local cell = cells[index]
	local data = podiums[index]
	if not cell or not data then
		return
	end
	local status = statusOf(data)
	cell.button.BackgroundColor3 = STATUS_COLOR[status]

	-- dua titik kecil = mannequin M dan F; terisi warna penuh, kosong pudar.
	-- "Sebagian" saja tidak cukup -- admin perlu tahu SISI MANA yang kurang.
	cell.dotM.BackgroundTransparency = genderFilled(data.M) and 0 or 0.75
	cell.dotF.BackgroundTransparency = genderFilled(data.F) and 0 or 0.75
	cell.dotM.Visible = data.M ~= nil
	cell.dotF.Visible = data.F ~= nil

	local selected = selectedIndex == index
	cell.stroke.Thickness = selected and 3 or 0
	cell.stroke.Enabled = selected

	cell.button.Visible = activeFilter == "all" or activeFilter == status
end

local function updateProgress()
	local filled, total = 0, 0
	local counts = { empty = 0, partial = 0, full = 0 }
	for _, data in pairs(podiums) do
		for _, g in ipairs({ data.M, data.F }) do
			if g then
				total += 1
				if genderFilled(g) then
					filled += 1
				end
			end
		end
		local s = statusOf(data)
		counts[s] += 1
	end
	progressLabel.Text = string.format("%d/%d mannequin terisi  ·  %d podium kosong", filled, total, counts.empty)
	progressFill.Size = UDim2.new(total > 0 and filled / total or 0, 0, 1, 0)

	for key, chip in pairs(chips) do
		local n = 0
		if key == "all" then
			for _ in pairs(podiums) do
				n += 1
			end
		else
			n = counts[key]
		end
		chip.Text = string.format("%s (%d)", STATUS_LABEL[key], n)
	end
end

local function makeChip(key: string, order: number)
	local chip = button(chipRow, STATUS_LABEL[key], key == "all" and WHITE or STATUS_COLOR[key])
	chip.Size = UDim2.new(0, 96, 1, 0)
	chip.TextSize = 12
	chip.LayoutOrder = order
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Name = "Active"
	chipStroke.Color = PINK_DARK
	chipStroke.Thickness = 2
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Enabled = key == activeFilter
	chipStroke.Parent = chip
	chips[key] = chip

	chip.MouseButton1Click:Connect(function()
		activeFilter = key
		for k, c in pairs(chips) do
			(c:FindFirstChild("Active") :: UIStroke).Enabled = k == key
		end
		for index in pairs(cells) do
			paintCell(index)
		end
	end)
end

makeChip("all", 1)
makeChip("empty", 2)
makeChip("partial", 3)
makeChip("full", 4)

local function dot(parent: Instance, text: string, x: number): Frame
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 1)
	d.Position = UDim2.new(x, 0, 1, -5)
	d.Size = UDim2.new(0, 18, 0, 14)
	d.BackgroundColor3 = PINK_DARK
	d.BorderSizePixel = 0
	d.Parent = parent
	corner(d, 4)

	local l = label(d, text, 9, true)
	l.Size = UDim2.fromScale(1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextColor3 = WHITE
	return d
end

local selectPodium: (index: number) -> ()

local function buildCell(index: number)
	local b = Instance.new("TextButton")
	b.Name = "Podium" .. index
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = true
	b.LayoutOrder = index
	b.Parent = grid
	corner(b, 10)

	local number = label(b, tostring(index), 18, true)
	number.Size = UDim2.new(1, 0, 0, 36)
	number.TextXAlignment = Enum.TextXAlignment.Center

	local stroke = Instance.new("UIStroke")
	stroke.Color = PINK_DARK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Enabled = false
	stroke.Parent = b

	cells[index] = {
		button = b,
		stroke = stroke,
		dotM = dot(b, "M", 0.3),
		dotF = dot(b, "F", 0.7),
	}

	b.MouseButton1Click:Connect(function()
		selectPodium(index)
	end)
end

------------------------------------------------------------------
-- Detail
------------------------------------------------------------------
local function fillCard(card: Card, g: GenderData?)
	card.frame.Visible = g ~= nil
	if not g then
		return
	end
	card.shirtBox.Text = g.shirt > 0 and tostring(g.shirt) or ""
	card.pantsBox.Text = g.pants > 0 and tostring(g.pants) or ""
	setThumb(card.shirtThumb, g.shirt)
	setThumb(card.pantsThumb, g.pants)
	-- aksesoris tidak bisa diubah dari sini (butuh Instance mannequin, bukan
	-- cuma nomor podium) -- diberi tahu, bukan disembunyikan diam-diam
	card.note.Text = string.format(
		"♥ %d suka  ·  %d aksesoris (ubah aksesoris dari panel mannequin-nya langsung)",
		g.likes,
		g.accessoryCount
	)
end

function selectPodium(index: number)
	local data = podiums[index]
	if not data then
		return
	end
	local previous = selectedIndex
	selectedIndex = index
	if previous then
		paintCell(previous)
	end
	paintCell(index)

	placeholder.Visible = false
	detailBody.Visible = true
	detailTitle.Text = string.format("#%d  %s", index, data.name)
	local status = statusOf(data)
	detailSub.Text = "Status: " .. STATUS_LABEL[status]

	fillCard(cardM, data.M)
	fillCard(cardF, data.F)
	cardScroller.CanvasPosition = Vector2.zero

	if not isWide() then
		detailOpenNarrow = true
		detail.Visible = true
	end
end

local function scrollToCell(index: number)
	local cell = cells[index]
	if not cell then
		return
	end
	task.defer(function()
		local y = cell.button.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y - 6
		grid.CanvasPosition = Vector2.new(0, math.max(0, y))
	end)
end

backBtn.MouseButton1Click:Connect(function()
	detailOpenNarrow = false
	detail.Visible = false
end)

searchBox.FocusLost:Connect(function()
	local n = tonumber(searchBox.Text:match("%d+") or "")
	if not n or not podiums[n] then
		return
	end
	-- filter yang sedang aktif bisa menyembunyikan podium tujuan -> reset ke Semua
	if activeFilter ~= "all" and statusOf(podiums[n]) ~= activeFilter then
		activeFilter = "all"
		for k, c in pairs(chips) do
			(c:FindFirstChild("Active") :: UIStroke).Enabled = k == "all"
		end
		for index in pairs(cells) do
			paintCell(index)
		end
	end
	selectPodium(n)
	scrollToCell(n)
end)

------------------------------------------------------------------
-- Aksi
------------------------------------------------------------------
local function flash(btn: TextButton, text: string, original: string)
	btn.Text = text
	task.delay(1.4, function()
		btn.Text = original
	end)
end

-- clearAll = true -> kirim 0/0 tanpa membaca kolom (dipakai tombol Kosongkan)
local function saveGender(index: number, gender: string, g: GenderData?, card: Card, clearAll: boolean)
	if not g then
		return
	end
	local shirt = clearAll and 0 or extractId(card.shirtBox.Text)
	local pants = clearAll and 0 or extractId(card.pantsBox.Text)
	SetOutfitByIndex:FireServer(index, gender, shirt, pants)
	-- data lokal diperbarui langsung, supaya warna kotak & progres ikut berubah
	-- tanpa memuat ulang 240 mannequin dari server
	g.shirt = shirt
	g.pants = pants
end

local function save(index: number, clearAll: boolean)
	local data = podiums[index]
	if not data then
		return
	end
	saveGender(index, "M", data.M, cardM, clearAll)
	saveGender(index, "F", data.F, cardF, clearAll)
	paintCell(index)
	updateProgress()
	selectPodium(index)
end

saveBtn.MouseButton1Click:Connect(function()
	if selectedIndex then
		save(selectedIndex, false)
		flash(saveBtn, "Tersimpan ✓", "Simpan podium ini")
	end
end)

-- Kosongkan butuh dua klik: sekali hapus, isinya hilang dari mannequin di map
-- untuk semua pemain, dan tidak ada tombol undo.
local clearArmed = false
clearBtn.MouseButton1Click:Connect(function()
	if not selectedIndex then
		return
	end
	if not clearArmed then
		clearArmed = true
		clearBtn.Text = "Yakin? Klik lagi"
		task.delay(3, function()
			clearArmed = false
			clearBtn.Text = "Kosongkan"
		end)
		return
	end
	clearArmed = false
	clearBtn.Text = "Kosongkan"
	save(selectedIndex, true)
end)

-- Teleport: menjawab "podium 47 itu yang mana di map". Panel ditutup supaya
-- admin langsung melihat mannequin-nya.
teleportBtn.MouseButton1Click:Connect(function()
	if not selectedIndex then
		return
	end
	local ok, success = pcall(function()
		return TeleportToPodium:InvokeServer(selectedIndex)
	end)
	if ok and success then
		backdrop.Visible = false
	else
		flash(teleportBtn, "Gagal teleport", "📍 Teleport ke sini")
	end
end)

------------------------------------------------------------------
-- Muat data dari server
------------------------------------------------------------------
local function loadAll()
	progressLabel.Text = "Memuat..."
	local ok, list = pcall(function()
		return GetAllMannequins:InvokeServer()
	end)
	if not ok or typeof(list) ~= "table" then
		progressLabel.Text = "Gagal memuat data dari server."
		return
	end

	podiums = {}
	for _, item in ipairs(list) do
		local index = tonumber(item.podiumIndex)
		if index then
			local data = podiums[index]
			if not data then
				data = { index = index, name = tostring(item.name), M = nil, F = nil }
				podiums[index] = data
			end
			local g: GenderData = {
				shirt = tonumber(item.shirt) or 0,
				pants = tonumber(item.pants) or 0,
				accessoryCount = tonumber(item.accessoryCount) or 0,
				likes = tonumber(item.likes) or 0,
			}
			if item.gender == "M" then
				data.M = g
			elseif item.gender == "F" then
				data.F = g
			end
		end
	end

	-- kotak cuma dibangun sekali; muat ulang hanya mengecat ulang
	for index in pairs(podiums) do
		if not cells[index] then
			buildCell(index)
		end
	end
	for index, cell in pairs(cells) do
		if not podiums[index] then
			cell.button:Destroy()
			cells[index] = nil
		end
	end
	for index in pairs(cells) do
		paintCell(index)
	end
	updateProgress()

	if selectedIndex and podiums[selectedIndex] then
		selectPodium(selectedIndex)
	end
end

------------------------------------------------------------------
-- Buka / tutup
------------------------------------------------------------------
toggleBtn.MouseButton1Click:Connect(function()
	backdrop.Visible = true
	relayout()
	loadAll()
end)
closeBtn.MouseButton1Click:Connect(function()
	backdrop.Visible = false
end)
refreshBtn.MouseButton1Click:Connect(loadAll)

------------------------------------------------------------------
-- Dialog Reset SEMUA suka
------------------------------------------------------------------
local CONFIRM_WORD = "RESET"

local resetOverlay = Instance.new("Frame")
resetOverlay.Size = UDim2.fromScale(1, 1)
resetOverlay.BackgroundColor3 = PAPER
resetOverlay.BackgroundTransparency = 0.08
resetOverlay.BorderSizePixel = 0
resetOverlay.Visible = false
resetOverlay.ZIndex = 5 -- di atas header, toolbar, dan isi
resetOverlay.Parent = window

local resetCard = Instance.new("Frame")
resetCard.AnchorPoint = Vector2.new(0.5, 0.5)
resetCard.Position = UDim2.fromScale(0.5, 0.5)
resetCard.Size = UDim2.new(1, 0, 0, 230)
resetCard.BackgroundColor3 = WHITE
resetCard.BorderSizePixel = 0
resetCard.Parent = resetOverlay
corner(resetCard, 12)

local resetCardMax = Instance.new("UISizeConstraint")
resetCardMax.MaxSize = Vector2.new(380, 230)
resetCardMax.Parent = resetCard

local resetStroke = Instance.new("UIStroke")
resetStroke.Color = Color3.fromRGB(220, 90, 110)
resetStroke.Thickness = 2
resetStroke.Parent = resetCard

local rPad = Instance.new("UIPadding")
rPad.PaddingTop = UDim.new(0, 14)
rPad.PaddingBottom = UDim.new(0, 14)
rPad.PaddingLeft = UDim.new(0, 14)
rPad.PaddingRight = UDim.new(0, 14)
rPad.Parent = resetCard

local rList = Instance.new("UIListLayout")
rList.Padding = UDim.new(0, 8)
rList.SortOrder = Enum.SortOrder.LayoutOrder
rList.Parent = resetCard

local rTitle = label(resetCard, "Hapus SEMUA suka?", 16, true)
rTitle.Size = UDim2.new(1, 0, 0, 20)
rTitle.TextColor3 = Color3.fromRGB(170, 40, 60)
rTitle.LayoutOrder = 1

local rBody = label(resetCard, "Jumlah suka di seluruh mannequin akan jadi 0, dan tidak bisa dikembalikan. "
	.. "Ketik " .. CONFIRM_WORD .. " untuk melanjutkan.", 12)
rBody.Size = UDim2.new(1, 0, 0, 46)
rBody.TextWrapped = true
rBody.TextTruncate = Enum.TextTruncate.None
rBody.LayoutOrder = 2

local rInput = Instance.new("TextBox")
rInput.Size = UDim2.new(1, 0, 0, 32)
rInput.BackgroundColor3 = ROW_BG
rInput.BorderSizePixel = 0
rInput.PlaceholderText = "Ketik " .. CONFIRM_WORD
rInput.Text = ""
rInput.ClearTextOnFocus = false
rInput.Font = Enum.Font.GothamBold
rInput.TextSize = 14
rInput.TextColor3 = INK
rInput.LayoutOrder = 3
rInput.Parent = resetCard
corner(rInput, 8)

local rButtons = Instance.new("Frame")
rButtons.Size = UDim2.new(1, 0, 0, 32)
rButtons.BackgroundTransparency = 1
rButtons.LayoutOrder = 4
rButtons.Parent = resetCard

local rButtonsLayout = Instance.new("UIListLayout")
rButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
rButtonsLayout.Padding = UDim.new(0, 8)
rButtonsLayout.Parent = rButtons

-- Batal di KIRI dan dibuat menonjol, tombol hapus di kanan & pudar sampai
-- kata konfirmasinya benar -- jadi klik refleks paling mungkin kena Batal.
local rCancel = button(rButtons, "Batal", NEUTRAL)
rCancel.Size = UDim2.new(0.5, -4, 1, 0)

local rConfirm = button(rButtons, "Hapus semua suka", Color3.fromRGB(220, 90, 110), WHITE)
rConfirm.Size = UDim2.new(0.5, -4, 1, 0)
rConfirm.Font = Enum.Font.GothamBold

local function confirmReady(): boolean
	-- huruf besar wajib persis; spasi di ujung dimaafkan
	return (rInput.Text:gsub("^%s+", ""):gsub("%s+$", "")) == CONFIRM_WORD
end

local function paintConfirm()
	local ready = confirmReady()
	rConfirm.Active = ready
	rConfirm.AutoButtonColor = ready
	rConfirm.BackgroundTransparency = ready and 0 or 0.6
end

rInput:GetPropertyChangedSignal("Text"):Connect(paintConfirm)

local function closeReset()
	resetOverlay.Visible = false
	rInput.Text = ""
	paintConfirm()
end

resetAllBtn.MouseButton1Click:Connect(function()
	rInput.Text = ""
	paintConfirm()
	resetOverlay.Visible = true
end)

rCancel.MouseButton1Click:Connect(closeReset)

rConfirm.MouseButton1Click:Connect(function()
	if not confirmReady() then
		return
	end
	ResetLikes:FireServer(nil) -- server mengecek ulang: hanya SUPERADMIN
	closeReset()
	progressLabel.Text = "Semua suka direset. Memuat ulang..."
	-- server menulis ke DataStore dulu sebelum selesai; beri jeda sebelum membaca
	task.delay(1, loadAll)
end)

relayout()

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
		local isAdmin = ok and typeof(role) == "string" and (role == "ADMIN" or role == "SUPERADMIN")
		toggleBtn.Visible = isAdmin
		if not isAdmin then
			backdrop.Visible = false
		end
		-- admin biasa tetap bisa kelola podium, tapi reset suka cuma SUPERADMIN
		local isSuper = ok and role == "SUPERADMIN"
		resetAllBtn.Visible = isSuper
		if not isSuper then
			resetOverlay.Visible = false
		end
		task.wait(2)
	end
end)
