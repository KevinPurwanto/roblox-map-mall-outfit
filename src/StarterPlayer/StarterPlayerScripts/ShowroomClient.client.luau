--!strict
-- ShowroomClient
-- UI dibangun lewat kode supaya semuanya tetap berupa file teks (enak untuk git & Rojo).
-- Panel admin di sini murni kosmetik. Pengamanan sebenarnya ada di Showroom.server.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local MANNEQUIN_CLICK_TAG = "MannequinClickBox" -- dipasang server di Showroom.server.luau

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local TryOn = remotes:WaitForChild("TryOn") :: RemoteEvent
local ResetAvatar = remotes:WaitForChild("ResetAvatar") :: RemoteEvent
local BuyOutfit = remotes:WaitForChild("BuyOutfit") :: RemoteEvent
local BuyItem = remotes:WaitForChild("BuyItem") :: RemoteEvent
local SetOutfit = remotes:WaitForChild("SetOutfit") :: RemoteEvent
local CartAdd = remotes:WaitForChild("CartAdd") :: RemoteEvent
local SetAccessories = remotes:WaitForChild("SetAccessories") :: RemoteEvent
local GetMyRole = remotes:WaitForChild("GetMyRole") :: RemoteFunction
local GetMannequin = remotes:WaitForChild("GetMannequinInfo") :: RemoteFunction
local SearchCatalog = remotes:WaitForChild("SearchCatalog") :: RemoteFunction
local LikeMannequin = remotes:WaitForChild("LikeMannequin") :: RemoteEvent
local ResetLikes = remotes:WaitForChild("ResetLikes") :: RemoteEvent
local LikesChanged = remotes:WaitForChild("LikesChanged") :: RemoteEvent

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local BLUE = Color3.fromRGB(158, 216, 255)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local MUTED = Color3.fromRGB(130, 120, 125)

local myRole = "PLAYER"
local selected: Model? = nil
-- cache data panel per mannequin; lihat bagian "Ambil-duluan" untuk alasannya
local infoCache: { [Model]: { data: any, at: number } } = {}

------------------------------------------------------------------
-- Helper UI
------------------------------------------------------------------
local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function button(text: string, color: Color3, order: number, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = INK
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 14
	b.AutoButtonColor = true
	b.LayoutOrder = order
	b.Parent = parent
	corner(b, 8)
	return b
end

------------------------------------------------------------------
-- Rangka panel
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ShowroomUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Tinggi panel MENGIKUTI layar (1, -40), bukan angka tetap.
--
-- Sebelumnya 824 px tetap: di viewport Studio yang cuma ~670 px, tombol Tutup
-- berada di luar layar dan panel tidak bisa ditutup sama sekali. UISizeConstraint
-- menjaga supaya di monitor tinggi panelnya tidak ikut memanjang jadi aneh.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -92, 0.5, 0) -- geser ke kiri, sisakan kolom ikon di tepi kanan
panel.Size = UDim2.new(0, 430, 1, -40)
panel.BackgroundColor3 = PAPER
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 14)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MinSize = Vector2.new(260, 300)
panelSize.MaxSize = Vector2.new(430, 900)
panelSize.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 2
stroke.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 14)
pad.PaddingBottom = UDim.new(0, 14)
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.Parent = panel

------------------------------------------------------------------
-- Tiga bagian tetap: header di atas, isi yang bisa di-scroll di tengah,
-- tombol Tutup MENEMPEL di bawah. Tombol Tutup sengaja di luar area scroll --
-- kalau ikut di-scroll, di layar pendek ia bisa hilang lagi seperti dulu.
------------------------------------------------------------------
local HEADER_HEIGHT = 46
local FOOTER_HEIGHT = 34
local THUMB_HEIGHT = 112 -- tinggi gambar item di grid; dipakai buildItemTile

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.Parent = panel

local headerList = Instance.new("UIListLayout")
headerList.Padding = UDim.new(0, 4)
headerList.SortOrder = Enum.SortOrder.LayoutOrder
headerList.Parent = header

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + 6)
body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT + 14))
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.ScrollBarThickness = 4
body.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -96, 0, 22) -- sisakan ruang untuk tombol suka di kanan
title.BackgroundTransparency = 1
title.Text = "" -- langsung ditimpa data.name tiap open(), nilai default tidak pernah kelihatan
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextTruncate = Enum.TextTruncate.AtEnd
title.LayoutOrder = 1
title.Parent = header

local subInfo = Instance.new("TextLabel")
subInfo.BackgroundTransparency = 1
subInfo.Text = ""
subInfo.TextColor3 = MUTED
subInfo.TextXAlignment = Enum.TextXAlignment.Left
subInfo.Font = Enum.Font.Gotham
subInfo.TextSize = 12
subInfo.Size = UDim2.new(1, -96, 0, 18) -- sisakan ruang untuk tombol suka di kanan
subInfo.LayoutOrder = 2
subInfo.Parent = header

------------------------------------------------------------------
-- Tombol suka MANNEQUIN (bukan per baju).
--
-- Ditaruh di header, bukan di dalam `body` yang bisa di-scroll: jumlah suka itu
-- identitas mannequin ini, harus terlihat begitu panel dibuka tanpa perlu
-- menggulir. Angkanya publik dan dipegang server.
------------------------------------------------------------------
local likeBtn = Instance.new("TextButton")
likeBtn.Name = "LikeMannequin"
likeBtn.AnchorPoint = Vector2.new(1, 0)
likeBtn.Position = UDim2.new(1, 0, 0, 0)
likeBtn.Size = UDim2.new(0, 92, 0, 40)
likeBtn.BackgroundColor3 = ROW_BG
likeBtn.BorderSizePixel = 0
likeBtn.Font = Enum.Font.GothamBold
likeBtn.TextSize = 13
likeBtn.TextColor3 = INK
likeBtn.Text = "♡ 0"
likeBtn.Parent = panel -- BUKAN header: header punya UIListLayout yang akan menata ulang posisinya
corner(likeBtn, 10)

local likeCaption = Instance.new("TextLabel")
likeCaption.AnchorPoint = Vector2.new(0.5, 1)
likeCaption.Position = UDim2.new(0.5, 0, 1, -3)
likeCaption.Size = UDim2.new(1, 0, 0, 12)
likeCaption.BackgroundTransparency = 1
likeCaption.Text = t("likeMannequin")
likeCaption.TextColor3 = MUTED
likeCaption.Font = Enum.Font.Gotham
likeCaption.TextSize = 10
likeCaption.Parent = likeBtn

local likeCount = 0
local likedByMe = false
local selectedLikeKey: string? = nil

local function paintLike()
	likeBtn.Text = (likedByMe and "♥ " or "♡ ") .. tostring(likeCount)
	likeBtn.TextColor3 = likedByMe and Color3.fromRGB(226, 62, 87) or INK
	likeBtn.BackgroundColor3 = likedByMe and Color3.fromRGB(255, 226, 234) or ROW_BG
end

------------------------------------------------------------------
-- Grid item (thumbnail besar + nama + harga + Beli satuan), ala grid katalog
-- Roblox -- tema warna/font tetap yang sekarang, cuma layoutnya jadi kotak-kotak
------------------------------------------------------------------
-- Frame biasa dengan AutomaticSize, BUKAN ScrollingFrame. Dulu ini scroller
-- sendiri di dalam panel; begitu panel ikut bisa di-scroll, dua scroller
-- bersarang bikin roda mouse bingung harus menggerakkan yang mana. Sekarang
-- grid ini tinggi apa adanya dan yang men-scroll cuma `body`.
local itemsScroller = Instance.new("Frame")
itemsScroller.Size = UDim2.new(1, 0, 0, 0)
itemsScroller.AutomaticSize = Enum.AutomaticSize.Y
itemsScroller.BackgroundTransparency = 1
itemsScroller.BorderSizePixel = 0
itemsScroller.LayoutOrder = 3
itemsScroller.Parent = body

local itemsGrid = Instance.new("UIGridLayout")
itemsGrid.CellSize = UDim2.new(0, 128, 0, 182) -- 3 kolom di panel 430px
itemsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
itemsGrid.SortOrder = Enum.SortOrder.LayoutOrder
itemsGrid.Parent = itemsScroller

------------------------------------------------------------------
-- Like = Favorite katalog Roblox yang SEBENARNYA.
--
-- Dipakai AvatarEditorService:PromptSetFavorite + GetFavoriteAsync, bukan
-- hitungan "suka" milik game ini sendiri. Alasannya: favorit ini tersimpan di
-- akun Roblox pemain dan muncul di daftar favorit mereka di luar game, jadi
-- jauh lebih berguna daripada angka yang cuma hidup di server kita -- dan tidak
-- butuh DataStore sama sekali (yang di place ini memang belum jalan).
--
-- Ketiga API-nya CLIENT-ONLY, jadi semuanya di sini, tidak lewat remote.
-- PromptSetFavoriteCompleted tidak menyebutkan item mana yang selesai, jadi
-- permintaan yang sedang berjalan dicatat di `pendingFavorite`.
------------------------------------------------------------------
local favoriteCache: { [number]: boolean } = {}
local favoriteButtons: { { btn: TextButton, assetId: number } } = {}
local pendingFavorite: { assetId: number, want: boolean }? = nil

local HEART_ON = "♥"
local HEART_OFF = "♡"

local function paintFavorite(btn: TextButton, assetId: number)
	local on = favoriteCache[assetId] == true
	btn.Text = on and HEART_ON or HEART_OFF
	btn.TextColor3 = on and Color3.fromRGB(226, 62, 87) or Color3.fromRGB(150, 140, 145)
end

local function refreshFavoriteButtons(assetId: number)
	for _, entry in ipairs(favoriteButtons) do
		if entry.assetId == assetId and entry.btn.Parent then
			paintFavorite(entry.btn, assetId)
		end
	end
end

AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result: Enum.AvatarPromptResult)
	local pending = pendingFavorite
	pendingFavorite = nil
	if not pending then
		return
	end
	if result == Enum.AvatarPromptResult.Success then
		favoriteCache[pending.assetId] = pending.want
		refreshFavoriteButtons(pending.assetId)
	elseif result == Enum.AvatarPromptResult.PermissionDenied then
		warn("[Showroom] " .. t("favoriteDenied"))
	else
		warn("[Showroom] " .. t("favoriteFailed"))
	end
end)

local function buildFavoriteButton(parent: GuiObject, assetId: number): TextButton
	-- ditumpuk di pojok thumbnail, bukan baris sendiri: tile sudah padat
	-- (thumbnail + nama + harga + Beli + Keranjang) dan hati di sudut gambar
	-- adalah pola yang sudah umum di aplikasi belanja
	local btn = Instance.new("TextButton")
	btn.Name = "Favorite"
	-- KIRI-atas: kanan-atas dipakai badge harga. Dulu dua-duanya di kanan dan
	-- saling menimpa.
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.Position = UDim2.new(0, 3, 0, 3)
	btn.Size = UDim2.new(0, 22, 0, 22)
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.ZIndex = 3
	btn.Parent = parent
	corner(btn, 11)

	paintFavorite(btn, assetId)
	table.insert(favoriteButtons, { btn = btn, assetId = assetId })

	-- status awal diambil di belakang layar: GetFavoriteAsync itu panggilan web
	-- yang yield, dan satu mannequin bisa punya banyak item -- kalau ditunggu,
	-- panel baru muncul setelah semuanya selesai
	if favoriteCache[assetId] == nil then
		task.spawn(function()
			local ok, fav = pcall(function()
				return AvatarEditorService:GetFavoriteAsync(assetId, Enum.AvatarItemType.Asset)
			end)
			if ok then
				favoriteCache[assetId] = fav == true
				refreshFavoriteButtons(assetId)
			end
		end)
	end

	btn.MouseButton1Click:Connect(function()
		if pendingFavorite then
			return -- satu dialog pada satu waktu
		end
		local want = not (favoriteCache[assetId] == true)
		pendingFavorite = { assetId = assetId, want = want }
		local ok = pcall(function()
			AvatarEditorService:PromptSetFavorite(assetId, Enum.AvatarItemType.Asset, want)
		end)
		if not ok then
			pendingFavorite = nil
			warn("[Showroom] " .. t("favoriteFailed"))
		end
	end)

	return btn
end

local function buildItemTile(item: any, order: number): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Item" .. order
	tile.BackgroundColor3 = ROW_BG
	tile.BorderSizePixel = 0
	tile.LayoutOrder = order
	corner(tile, 10)

	local tPad = Instance.new("UIPadding")
	tPad.PaddingTop = UDim.new(0, 6)
	tPad.PaddingBottom = UDim.new(0, 6)
	tPad.PaddingLeft = UDim.new(0, 6)
	tPad.PaddingRight = UDim.new(0, 6)
	tPad.Parent = tile

	local tList = Instance.new("UIListLayout")
	tList.Padding = UDim.new(0, 3)
	tList.SortOrder = Enum.SortOrder.LayoutOrder
	tList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tList.Parent = tile

	-- item.assetId = ID KATALOG, jadi thumbnail resmi Roblox-nya sudah berupa
	-- render (baju di atas mannequin abu-abu, aksesoris sebagai objek 3D) --
	-- sama persis dengan yang dipakai halaman katalog/Try-On Roblox sendiri
	local thumb = Instance.new("ImageLabel")
	thumb.BackgroundColor3 = Color3.new(1, 1, 1)
	thumb.Image = string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", item.assetId)
	thumb.Size = UDim2.new(1, 0, 0, THUMB_HEIGHT)
	thumb.LayoutOrder = 1
	thumb.Parent = tile
	corner(thumb, 6)

	-- Hati (favorit katalog Roblox) di KIRI, badge harga di KANAN -- dulu
	-- keduanya di kanan dan saling menimpa
	buildFavoriteButton(thumb, item.assetId)

	-- Harga jadi badge kecil menempel di thumbnail, bukan baris teks sendiri.
	-- Itu menghemat satu baris penuh per tile dan menyamakan tampilannya dengan
	-- grid katalog Roblox, di mana harga selalu menempel pada gambarnya.
	local priceBadge = Instance.new("TextLabel")
	priceBadge.AnchorPoint = Vector2.new(1, 0)
	priceBadge.Position = UDim2.new(1, -3, 0, 3)
	priceBadge.AutomaticSize = Enum.AutomaticSize.X
	priceBadge.Size = UDim2.new(0, 0, 0, 18)
	priceBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	priceBadge.BackgroundTransparency = 0.1
	priceBadge.BorderSizePixel = 0
	priceBadge.Font = Enum.Font.GothamBold
	priceBadge.TextSize = 11
	priceBadge.TextColor3 = INK
	priceBadge.ZIndex = 3
	if item.owned then
		priceBadge.Text = " ✓ "
		priceBadge.TextColor3 = Color3.fromRGB(46, 150, 90)
	elseif not item.forSale then
		priceBadge.Text = " — "
		priceBadge.TextColor3 = MUTED
	elseif (item.price or 0) <= 0 then
		priceBadge.Text = " " .. t("free") .. " "
	else
		priceBadge.Text = " R$ " .. tostring(item.price) .. " "
	end
	priceBadge.Parent = thumb
	corner(priceBadge, 9)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 26)
	label.BackgroundTransparency = 1
	label.Text = tostring(item.label)
	label.TextColor3 = INK
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 11
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.LayoutOrder = 2
	label.Parent = tile

	-- Satu baris aksi: Beli melebar, keranjang cuma ikon persegi di sebelahnya.
	-- Sebelumnya dua tombol lebar bertumpuk -- makan tinggi dua kali lipat
	-- untuk dua aksi yang sebenarnya setara.
	local actions = Instance.new("Frame")
	actions.Size = UDim2.new(1, 0, 0, 26)
	actions.BackgroundTransparency = 1
	actions.LayoutOrder = 3
	actions.Parent = tile

	local actionList = Instance.new("UIListLayout")
	actionList.FillDirection = Enum.FillDirection.Horizontal
	actionList.Padding = UDim.new(0, 4)
	actionList.SortOrder = Enum.SortOrder.LayoutOrder
	actionList.Parent = actions

	local canBuy = item.forSale and not item.owned

	local beliBtn = Instance.new("TextButton")
	beliBtn.Size = UDim2.new(1, -34, 1, 0)
	beliBtn.BorderSizePixel = 0
	beliBtn.Font = Enum.Font.GothamBold
	beliBtn.TextSize = 12
	beliBtn.TextColor3 = INK
	beliBtn.Text = item.owned and t("owned") or (item.forSale and t("buy") or t("unavailable"))
	beliBtn.BackgroundColor3 = canBuy and BLUE or Color3.fromRGB(225, 220, 222)
	beliBtn.Active = canBuy
	beliBtn.AutoButtonColor = canBuy
	beliBtn.LayoutOrder = 1
	beliBtn.Parent = actions
	corner(beliBtn, 6)

	beliBtn.MouseButton1Click:Connect(function()
		if selected and canBuy then
			BuyItem:FireServer(selected, item.assetId)
			infoCache[selected] = nil -- status "sudah punya" akan berubah
		end
	end)

	-- Masuk keranjang tetap diizinkan untuk barang yang sudah dimiliki / sedang
	-- tidak dijual: Roblox sendiri yang menandai dan mengeluarkannya dari total
	-- di dialog checkout, dan melarangnya di sini malah bikin pemain mengira
	-- tombolnya rusak.
	local cartBtn = Instance.new("TextButton")
	cartBtn.Size = UDim2.new(0, 30, 1, 0)
	cartBtn.BorderSizePixel = 0
	cartBtn.Font = Enum.Font.GothamBold
	cartBtn.TextSize = 14
	cartBtn.TextColor3 = INK
	cartBtn.Text = "🛒"
	cartBtn.BackgroundColor3 = Color3.fromRGB(255, 205, 224)
	cartBtn.LayoutOrder = 2
	cartBtn.Parent = actions
	corner(cartBtn, 6)

	cartBtn.MouseButton1Click:Connect(function()
		if selected then
			CartAdd:FireServer(selected, item.assetId)
		end
	end)

	return tile
end

local function rebuildItems(items: { any })
	for _, child in ipairs(itemsScroller:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	-- tombol lama ikut dibuang bersama tile-nya; kalau daftarnya tidak
	-- dikosongkan, ia terus tumbuh tiap kali panel dibuka dan menahan referensi
	-- ke GuiObject yang sudah dihancurkan
	table.clear(favoriteButtons)
	for i, item in ipairs(items) do
		buildItemTile(item, i).Parent = itemsScroller
	end
end

local tryBtn = button(t("tryOn"), PINK, 4, body)
local buyAllBtn = button(t("buyAll"), BLUE, 5, body)
local addAllBtn = button(t("cartAddAll"), Color3.fromRGB(240, 228, 236), 6, body)
addAllBtn.Size = UDim2.new(1, 0, 0, 30)
local resetBtn = button(t("resetAvatar"), Color3.fromRGB(235, 235, 240), 7, body)

-- Di luar `body`, ditempel ke dasar panel -- selalu terjangkau berapa pun
-- tinggi layar. Ini yang dulu hilang di luar layar.
local closeBtn = button(t("close"), Color3.fromRGB(235, 235, 240), 9, panel)
closeBtn.AnchorPoint = Vector2.new(0, 1)
closeBtn.Position = UDim2.new(0, 0, 1, 0)
closeBtn.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT)

------------------------------------------------------------------
-- Bagian admin
------------------------------------------------------------------
local adminBox = Instance.new("Frame")
adminBox.Size = UDim2.new(1, 0, 0, 222) -- +32 untuk tombol reset suka podium ini
adminBox.BackgroundColor3 = ROW_BG
adminBox.BorderSizePixel = 0
adminBox.Visible = false
adminBox.LayoutOrder = 8
adminBox.Parent = body
corner(adminBox, 10)

local aPad = Instance.new("UIPadding")
aPad.PaddingTop = UDim.new(0, 8)
aPad.PaddingBottom = UDim.new(0, 8)
aPad.PaddingLeft = UDim.new(0, 8)
aPad.PaddingRight = UDim.new(0, 8)
aPad.Parent = adminBox

local aList = Instance.new("UIListLayout")
aList.Padding = UDim.new(0, 6)
aList.SortOrder = Enum.SortOrder.LayoutOrder
aList.Parent = adminBox

local function idField(placeholder: string, order: number): TextBox
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, 0, 0, 26)
	tb.BackgroundColor3 = Color3.new(1, 1, 1)
	tb.BorderSizePixel = 0
	tb.PlaceholderText = placeholder
	tb.Text = ""
	tb.ClearTextOnFocus = false
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 13
	tb.TextColor3 = INK
	tb.LayoutOrder = order
	tb.Parent = adminBox
	corner(tb, 6)
	return tb
end

local searchOpenBtn = button(t("searchOpen"), BLUE, 1, adminBox)
searchOpenBtn.Size = UDim2.new(1, 0, 0, 28)

local shirtField = idField(t("shirtFieldPlaceholder"), 2)
local pantsField = idField(t("pantsFieldPlaceholder"), 3)
local accessoriesField = idField(t("accessoriesFieldPlaceholder"), 4)
local saveBtn = button(t("saveToMannequin"), PINK_DARK, 5, adminBox)
saveBtn.TextColor3 = Color3.new(1, 1, 1)

-- Reset suka: hanya SUPERADMIN (dicek ulang di server). Butuh klik dua kali --
-- ini menghapus angka yang tidak bisa dikembalikan, dan tombolnya duduk persis
-- di bawah tombol Simpan yang sering dipakai.
local resetLikeBtn = button(t("likeReset"), Color3.fromRGB(245, 220, 226), 6, adminBox)
resetLikeBtn.Size = UDim2.new(1, 0, 0, 26)
resetLikeBtn.TextSize = 11
resetLikeBtn.Visible = false

-- "Reset SEMUA suka" sengaja TIDAK ada di panel mannequin -- terlalu dekat
-- dengan tombol yang sering diklik, dan dampaknya ke 240 mannequin sekaligus.
-- Pindah ke panel "Kelola Semua Podium" dengan konfirmasi ketik "RESET".

-- Tombol yang perlu konfirmasi: klik pertama mengubah teksnya, klik kedua baru
-- mengeksekusi -- tapi HANYA kalau jaraknya minimal ARM_DELAY. Tanpa jeda itu,
-- double-click biasa (dua klik dalam ~0,3 detik) langsung lolos konfirmasi,
-- padahal tujuan konfirmasi justru menangkap klik yang tidak disengaja.
local ARM_DELAY = 0.8 -- detik; jauh di atas jeda double-click
local ARM_WINDOW = 4 -- detik; setelah ini konfirmasi kedaluwarsa

local function armConfirm(btn: TextButton, label: string, action: () -> ())
	local armedAt: number? = nil
	btn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if armedAt then
			if now - armedAt < ARM_DELAY then
				return -- terlalu cepat: anggap bagian dari double-click, abaikan
			end
			armedAt = nil
			btn.Text = label
			action()
			return
		end
		armedAt = now
		btn.Text = t("likeResetConfirm")
		local thisArm = now
		task.delay(ARM_WINDOW, function()
			if armedAt == thisArm then
				armedAt = nil
				btn.Text = label
			end
		end)
	end)
end

armConfirm(resetLikeBtn, t("likeReset"), function()
	if selected then
		ResetLikes:FireServer(selected)
	end
end)

-- ambil angka pertama dari teks -- terima link katalog penuh maupun assetId polos
local function extractId(text: string): number
	local digits = text:match("%d+")
	return (digits and tonumber(digits)) or 0
end

-- pisah per koma, ambil angka dari tiap bagian -- buat field aksesoris (bisa banyak)
local function extractIds(text: string): { number }
	local ids: { number } = {}
	for part in text:gmatch("[^,]+") do
		local digits = part:match("%d+")
		if digits then
			table.insert(ids, tonumber(digits) :: number)
		end
	end
	return ids
end

------------------------------------------------------------------
-- Panel pencarian katalog (admin)
--
-- Alasan panel ini ada: selama admin mengetik/menempel angka ID sendiri, dia
-- bisa saja menempel ID TEKSTUR (AssetTypeId 1, hasil "copy image id") dan bukan
-- ID KATALOG. Bedanya tidak kelihatan sebagai error -- bajunya tetap terpasang,
-- tapi thumbnail-nya jadi gambar tekstur mentah (bukan render 3D seperti di
-- katalog Roblox), harga salah, dan tombol Beli gagal. Hasil dari
-- AvatarEditorService:SearchCatalogAsync di server DIJAMIN ID katalog, jadi
-- kalau admin memilih lewat panel ini masalah itu tidak bisa terjadi lagi.
--
-- Dibuat sebagai panel terpisah (bukan di dalam adminBox) supaya panel utama
-- tidak jadi terlalu tinggi -- grid hasil pencarian butuh ruang sendiri.
------------------------------------------------------------------
local searchPanel = Instance.new("Frame")
searchPanel.Name = "SearchPanel"
searchPanel.AnchorPoint = Vector2.new(1, 0.5)
searchPanel.Position = UDim2.new(1, -534, 0.5, 0) -- di kiri panel utama (92 + 430 + 12)
-- ikut tinggi layar seperti panel utama, supaya tombol Tutup-nya tidak pernah
-- terdorong keluar layar di viewport pendek
searchPanel.Size = UDim2.new(0, 320, 1, -40)
searchPanel.BackgroundColor3 = PAPER
searchPanel.BorderSizePixel = 0
searchPanel.Visible = false
searchPanel.Parent = gui
corner(searchPanel, 14)

local searchSize = Instance.new("UISizeConstraint")
searchSize.MinSize = Vector2.new(240, 300)
searchSize.MaxSize = Vector2.new(320, 440)
searchSize.Parent = searchPanel

local sStroke = Instance.new("UIStroke")
sStroke.Color = PINK
sStroke.Thickness = 2
sStroke.Parent = searchPanel

local sPad = Instance.new("UIPadding")
sPad.PaddingTop = UDim.new(0, 12)
sPad.PaddingBottom = UDim.new(0, 12)
sPad.PaddingLeft = UDim.new(0, 12)
sPad.PaddingRight = UDim.new(0, 12)
sPad.Parent = searchPanel

local sList = Instance.new("UIListLayout")
sList.Padding = UDim.new(0, 6)
sList.SortOrder = Enum.SortOrder.LayoutOrder
sList.Parent = searchPanel

local sTitle = Instance.new("TextLabel")
sTitle.Size = UDim2.new(1, 0, 0, 20)
sTitle.BackgroundTransparency = 1
sTitle.Text = t("searchTitle")
sTitle.TextColor3 = PINK_DARK
sTitle.TextXAlignment = Enum.TextXAlignment.Left
sTitle.Font = Enum.Font.GothamBold
sTitle.TextSize = 15
sTitle.LayoutOrder = 1
sTitle.Parent = searchPanel

-- pemilih jenis: menentukan AssetTypes yang dikirim ke SearchCatalogAsync
-- sekaligus kolom mana yang diisi kalau hasil diklik
local kindRow = Instance.new("Frame")
kindRow.Size = UDim2.new(1, 0, 0, 26)
kindRow.BackgroundTransparency = 1
kindRow.LayoutOrder = 2
kindRow.Parent = searchPanel

local kindLayout = Instance.new("UIListLayout")
kindLayout.FillDirection = Enum.FillDirection.Horizontal
kindLayout.Padding = UDim.new(0, 6)
kindLayout.SortOrder = Enum.SortOrder.LayoutOrder
kindLayout.Parent = kindRow

local currentKind = "Shirt"
local kindButtons: { [string]: TextButton } = {}

local function refreshKindButtons()
	for kind, btn in pairs(kindButtons) do
		local active = kind == currentKind
		btn.BackgroundColor3 = active and PINK_DARK or Color3.fromRGB(235, 230, 233)
		btn.TextColor3 = active and Color3.new(1, 1, 1) or INK
	end
end

local function makeKindButton(kind: string, labelKey: string, order: number)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.333, -4, 1, 0)
	b.BorderSizePixel = 0
	b.Text = t(labelKey)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.LayoutOrder = order
	b.Parent = kindRow
	corner(b, 6)
	kindButtons[kind] = b
	b.MouseButton1Click:Connect(function()
		currentKind = kind
		refreshKindButtons()
	end)
end

makeKindButton("Shirt", "searchKindShirt", 1)
makeKindButton("Pants", "searchKindPants", 2)
makeKindButton("Accessory", "searchKindAccessory", 3)
refreshKindButtons()

local queryField = Instance.new("TextBox")
queryField.Size = UDim2.new(1, 0, 0, 30)
queryField.BackgroundColor3 = Color3.new(1, 1, 1)
queryField.BorderSizePixel = 0
queryField.PlaceholderText = t("searchPlaceholder")
queryField.Text = ""
queryField.ClearTextOnFocus = false
queryField.Font = Enum.Font.Gotham
queryField.TextSize = 13
queryField.TextColor3 = INK
queryField.LayoutOrder = 3
queryField.Parent = searchPanel
corner(queryField, 6)

local searchBtn = button(t("searchButton"), PINK, 4, searchPanel)
searchBtn.Size = UDim2.new(1, 0, 0, 28)

local searchStatus = Instance.new("TextLabel")
searchStatus.Size = UDim2.new(1, 0, 0, 16)
searchStatus.BackgroundTransparency = 1
searchStatus.Text = t("searchHint")
searchStatus.TextColor3 = MUTED
searchStatus.TextXAlignment = Enum.TextXAlignment.Left
searchStatus.Font = Enum.Font.Gotham
searchStatus.TextSize = 11
searchStatus.TextTruncate = Enum.TextTruncate.AtEnd
searchStatus.LayoutOrder = 5
searchStatus.Parent = searchPanel

local resultsScroller = Instance.new("ScrollingFrame")
-- tinggi SISA panel (bukan 262 tetap): kalau panel mengecil di layar pendek,
-- yang menyusut area hasil pencarian, bukan tombol Tutup yang terdorong keluar
resultsScroller.Size = UDim2.new(1, 0, 1, -202)
resultsScroller.BackgroundTransparency = 1
resultsScroller.BorderSizePixel = 0
resultsScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
resultsScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
resultsScroller.ScrollBarThickness = 4
resultsScroller.LayoutOrder = 6
resultsScroller.Parent = searchPanel

local resultsGrid = Instance.new("UIGridLayout")
resultsGrid.CellSize = UDim2.new(0, 88, 0, 122)
resultsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
resultsGrid.SortOrder = Enum.SortOrder.LayoutOrder
resultsGrid.Parent = resultsScroller

local searchCloseBtn = button(t("close"), Color3.fromRGB(235, 235, 240), 7, searchPanel)
searchCloseBtn.Size = UDim2.new(1, 0, 0, 28)

------------------------------------------------------------------
-- hasil dipilih -> isi kolom ID yang sesuai. Untuk aksesoris ditambahkan ke
-- daftar (bisa lebih dari satu), untuk shirt/pants menimpa nilai lama.
local function pickResult(result: any)
	if currentKind == "Shirt" then
		shirtField.Text = tostring(result.id)
		searchStatus.Text = t("searchPickedShirt", tostring(result.name))
	elseif currentKind == "Pants" then
		pantsField.Text = tostring(result.id)
		searchStatus.Text = t("searchPickedPants", tostring(result.name))
	else
		local ids = extractIds(accessoriesField.Text)
		for _, existing in ipairs(ids) do
			if existing == result.id then
				return -- sudah ada, jangan dobel
			end
		end
		table.insert(ids, result.id)
		local text = {}
		for _, id in ipairs(ids) do
			table.insert(text, tostring(id))
		end
		accessoriesField.Text = table.concat(text, ", ")
		searchStatus.Text = t("searchPickedAccessory", tostring(result.name))
	end
end

local function buildResultTile(result: any, order: number): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = "Result" .. order
	tile.BackgroundColor3 = ROW_BG
	tile.BorderSizePixel = 0
	tile.Text = ""
	tile.AutoButtonColor = true
	tile.LayoutOrder = order
	corner(tile, 8)

	local tPad = Instance.new("UIPadding")
	tPad.PaddingTop = UDim.new(0, 5)
	tPad.PaddingBottom = UDim.new(0, 5)
	tPad.PaddingLeft = UDim.new(0, 5)
	tPad.PaddingRight = UDim.new(0, 5)
	tPad.Parent = tile

	local tList = Instance.new("UIListLayout")
	tList.Padding = UDim.new(0, 3)
	tList.SortOrder = Enum.SortOrder.LayoutOrder
	tList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tList.Parent = tile

	-- ID dari SearchCatalogAsync selalu ID katalog, jadi rbxthumb di sini pasti
	-- render 3D resmi Roblox -- sama persis dengan yang tampil di katalog
	local thumb = Instance.new("ImageLabel")
	thumb.BackgroundColor3 = Color3.new(1, 1, 1)
	thumb.Image = string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", result.id)
	thumb.Size = UDim2.new(1, 0, 0, 78)
	thumb.LayoutOrder = 1
	thumb.Parent = tile
	corner(thumb, 6)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 13)
	name.BackgroundTransparency = 1
	name.Text = tostring(result.name)
	name.TextColor3 = INK
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 10
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.LayoutOrder = 2
	name.Parent = tile

	local price = Instance.new("TextLabel")
	price.Size = UDim2.new(1, 0, 0, 12)
	price.BackgroundTransparency = 1
	if not result.forSale then
		price.Text = t("notForSale")
	elseif (result.price or 0) <= 0 then
		price.Text = t("free")
	else
		price.Text = tostring(result.price) .. " " .. t("robux")
	end
	price.TextColor3 = MUTED
	price.Font = Enum.Font.Gotham
	price.TextSize = 9
	price.TextTruncate = Enum.TextTruncate.AtEnd
	price.LayoutOrder = 3
	price.Parent = tile

	tile.MouseButton1Click:Connect(function()
		pickResult(result)
	end)

	return tile
end

local function clearResults()
	for _, child in ipairs(resultsScroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- kode error dari server -> teks lokal (server sengaja balikin kode, bukan kalimat)
local function describeSearchError(code: string): string
	if code == "not_admin" then
		return t("searchNotAdmin")
	elseif code == "too_short" then
		return t("searchTooShort")
	elseif code == "throttled" then
		return t("searchThrottled")
	end
	return t("searchFailed")
end

local searching = false

local function runSearch()
	if searching then
		return
	end
	local keyword = queryField.Text
	local trimmed = (keyword:gsub("%s", ""))
	if #trimmed < 2 then
		searchStatus.Text = t("searchTooShort")
		return
	end

	searching = true
	searchBtn.Active = false
	searchStatus.Text = t("searchSearching")
	clearResults()

	local ok, success, payload = pcall(function()
		return SearchCatalog:InvokeServer(currentKind, keyword)
	end)

	searching = false
	searchBtn.Active = true

	if not ok or not success then
		searchStatus.Text = describeSearchError(typeof(payload) == "string" and payload or "search_failed")
		return
	end
	if typeof(payload) ~= "table" or #payload == 0 then
		searchStatus.Text = t("searchNoResult", keyword)
		return
	end

	for i, result in ipairs(payload) do
		buildResultTile(result, i).Parent = resultsScroller
	end
	searchStatus.Text = t("searchResultCount", #payload) .. "  ·  " .. t("searchSaveReminder")
end

searchBtn.MouseButton1Click:Connect(runSearch)
queryField.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		runSearch()
	end
end)

searchOpenBtn.MouseButton1Click:Connect(function()
	searchPanel.Visible = not searchPanel.Visible
end)

searchCloseBtn.MouseButton1Click:Connect(function()
	searchPanel.Visible = false
end)

------------------------------------------------------------------
-- Logika
------------------------------------------------------------------
------------------------------------------------------------------
-- Ambil-duluan (prefetch) + cache data mannequin
--
-- Dulu open() menunggu InvokeServer dulu baru panel muncul -- terasa delay,
-- apalagi server dulu memeriksa kepemilikan item satu per satu ke web Roblox.
-- Sekarang dua hal:
--   1. Begitu tombol "E" sebuah mannequin MUNCUL (= pemain sudah dekat),
--      datanya diambil di belakang layar. Saat diklik, biasanya sudah siap.
--   2. Kalau belum siap, panel tetap terbuka SEKETIKA dengan status memuat,
--      lalu terisi begitu data datang -- bukan diam menunggu.
------------------------------------------------------------------
local CACHE_TTL = 15 -- detik; cukup pendek supaya harga/status jual tidak basi
-- (infoCache dideklarasikan di atas, dekat `selected` -- tile item yang
-- dibangun lebih dulu juga perlu membuangnya saat tombol Beli diklik)
local inflight: { [Model]: boolean } = {}
local openToken = 0 -- membuang jawaban lama kalau pemain keburu membuka mannequin lain

local function freshCache(mannequin: Model): any
	local entry = infoCache[mannequin]
	if entry and os.clock() - entry.at < CACHE_TTL then
		return entry.data
	end
	return nil
end

local function fetchInfo(mannequin: Model): any
	local ok, data = pcall(function()
		return GetMannequin:InvokeServer(mannequin)
	end)
	if ok and data then
		infoCache[mannequin] = { data = data, at = os.clock() }
		return data
	end
	return nil
end

local function prefetch(mannequin: Model)
	if inflight[mannequin] or freshCache(mannequin) then
		return
	end
	inflight[mannequin] = true
	task.spawn(function()
		fetchInfo(mannequin)
		inflight[mannequin] = nil
	end)
end

-- Kepemilikan & stok berubah setelah membeli; cache dibuang supaya panel
-- berikutnya tidak menampilkan "Beli" untuk barang yang baru saja dibeli.
local function invalidateInfo(mannequin: Model?)
	if mannequin then
		infoCache[mannequin] = nil
	else
		table.clear(infoCache)
	end
end

local function render(mannequin: Model, data: any)
	selected = mannequin
	title.Text = data.name
	subInfo.Text = t("podiumGenderLine", data.podiumIndex, data.gender == "F" and t("girl") or t("boy"))

	local items = (typeof(data.items) == "table" and data.items) or {}
	rebuildItems(items)

	local anyBuyable = false
	for _, item in ipairs(items) do
		if item.forSale and not item.owned then
			anyBuyable = true
			break
		end
	end
	buyAllBtn.Visible = #items > 0
	addAllBtn.Visible = #items > 0 -- mannequin kosong tidak punya apa pun untuk dimasukkan
	buyAllBtn.Text = anyBuyable and t("buyAll") or t("alreadyOwnedAll")
	buyAllBtn.Active = anyBuyable
	buyAllBtn.AutoButtonColor = anyBuyable

	-- kunci suka dihitung ulang di client cuma untuk mencocokkan siaran
	-- LikesChanged; server tetap yang menentukan angkanya
	selectedLikeKey = tostring(data.podiumIndex) .. "_" .. tostring(data.gender)
	likeCount = tonumber(data.likes) or 0
	likedByMe = data.likedByMe == true
	paintLike()

	shirtField.Text = data.shirt > 0 and tostring(data.shirt) or ""
	pantsField.Text = data.pants > 0 and tostring(data.pants) or ""

	local accessoryIds = {}
	for _, item in ipairs(items) do
		if item.kind == "Accessory" then
			table.insert(accessoryIds, tostring(item.assetId))
		end
	end
	accessoriesField.Text = table.concat(accessoryIds, ", ")

	panel.Visible = true
end

local function open(mannequin: Model, forceFresh: boolean?)
	openToken += 1
	local myToken = openToken

	if forceFresh then
		invalidateInfo(mannequin)
	end

	local cached = freshCache(mannequin)
	if cached then
		render(mannequin, cached) -- seketika, tanpa menunggu server
		return
	end

	-- Belum ada data: panel dibuka SEKARANG dalam keadaan memuat, bukan diam
	-- menunggu. Isi lama dikosongkan supaya tidak sempat terlihat seperti
	-- milik mannequin yang baru diklik.
	selected = mannequin
	title.Text = "..."
	subInfo.Text = t("searchSearching")
	rebuildItems({})
	buyAllBtn.Visible = false
	addAllBtn.Visible = false
	panel.Visible = true

	local data = fetchInfo(mannequin)
	if myToken ~= openToken then
		return -- pemain sudah membuka mannequin lain sementara ini menunggu
	end
	if not data then
		subInfo.Text = t("searchFailed")
		return
	end
	render(mannequin, data)
end

-- Tombol "E" muncul = pemain sudah cukup dekat untuk kemungkinan membuka panel
-- -> saat yang tepat mengambil data duluan
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	local mannequin = prompt.Parent and prompt.Parent.Parent
	if mannequin and mannequin:IsA("Model") and mannequin:GetAttribute("PodiumIndex") then
		prefetch(mannequin)
	end
end)

local function close()
	panel.Visible = false
	searchPanel.Visible = false -- panel pencarian anak dari gui, bukan panel -- harus ditutup manual
	selected = nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, promptPlayer)
	if promptPlayer ~= player then
		return
	end
	local mannequin = prompt.Parent and prompt.Parent.Parent
	if mannequin and mannequin:IsA("Model") then
		open(mannequin)
	end
end)

------------------------------------------------------------------
-- Klik/tap mannequin = sama saja dengan menekan "E".
--
-- ClickDetector-nya ada di part OutfitClickBox (dibuat server), BUKAN di badan
-- mannequin -- part badan di-set CanQuery = false jadi tidak pernah kena raycast
-- mouse. MouseClick tetap menyala di HP walau namanya "Mouse".
--
-- Dicari lewat tag, bukan WaitForChild, supaya tidak ada 240 coroutine menunggu
-- dan tidak bergantung pada urutan replikasi. Tag ini juga yang menangani
-- mannequin yang keluar-masuk karena StreamingEnabled.
------------------------------------------------------------------
local function hookClickBox(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local detector = inst:FindFirstChildOfClass("ClickDetector")
	local mannequin = inst.Parent
	if not detector or not mannequin or not mannequin:IsA("Model") then
		return
	end
	detector.MouseClick:Connect(function()
		open(mannequin :: Model)
	end)
end

for _, inst in ipairs(CollectionService:GetTagged(MANNEQUIN_CLICK_TAG)) do
	hookClickBox(inst)
end
CollectionService:GetInstanceAddedSignal(MANNEQUIN_CLICK_TAG):Connect(hookClickBox)

tryBtn.MouseButton1Click:Connect(function()
	if selected then
		TryOn:FireServer(selected)
	end
end)

buyAllBtn.MouseButton1Click:Connect(function()
	if selected then
		BuyOutfit:FireServer(selected)
		invalidateInfo(selected)
	end
end)

-- assetId dikosongkan = server memasukkan SEMUA item mannequin ini sekaligus
addAllBtn.MouseButton1Click:Connect(function()
	if selected then
		CartAdd:FireServer(selected, 0)
	end
end)

resetBtn.MouseButton1Click:Connect(function()
	ResetAvatar:FireServer()
	close()
end)

closeBtn.MouseButton1Click:Connect(close)

------------------------------------------------------------------
-- Suka mannequin
------------------------------------------------------------------
likeBtn.MouseButton1Click:Connect(function()
	if not selected then
		return
	end
	-- Tampilannya langsung dibalik supaya terasa responsif; server tetap yang
	-- menentukan angka akhirnya lewat LikesChanged sesaat kemudian.
	likedByMe = not likedByMe
	likeCount = math.max(0, likeCount + (likedByMe and 1 or -1))
	paintLike()
	LikeMannequin:FireServer(selected)
end)

-- Siaran ke semua pemain: angkanya publik. Argumen ketiga (status "aku sudah
-- suka") cuma dikirim ke pemain yang bersangkutan, jadi di sini bisa nil --
-- kalau nil, status pribadi dibiarkan apa adanya.
LikesChanged.OnClientEvent:Connect(function(key: any, total: any, mine: any)
	if typeof(key) ~= "string" then
		return
	end
	-- data di cache ikut diperbarui -- kalau tidak, membuka ulang mannequin ini
	-- dalam 15 detik menampilkan angka suka yang lama
	for _, entry in pairs(infoCache) do
		local d = entry.data
		if tostring(d.podiumIndex) .. "_" .. tostring(d.gender) == key then
			d.likes = tonumber(total) or d.likes
			if typeof(mine) == "boolean" then
				d.likedByMe = mine
			end
		end
	end
	if key ~= selectedLikeKey then
		return
	end
	likeCount = tonumber(total) or likeCount
	if typeof(mine) == "boolean" then
		likedByMe = mine
	end
	paintLike()
end)

saveBtn.MouseButton1Click:Connect(function()
	if not selected then
		return
	end
	local shirtId = extractId(shirtField.Text)
	local pantsId = extractId(pantsField.Text)
	SetOutfit:FireServer(selected, shirtId, pantsId)
	SetAccessories:FireServer(selected, extractIds(accessoriesField.Text))
	task.wait(0.2)
	open(selected, true) -- paksa ambil ulang: isinya baru saja diubah
end)

------------------------------------------------------------------
-- Dicek berkala (bukan cuma sekali di spawn) supaya panel admin ikut update
-- kalau role berubah di tengah sesi (Debug Tools ganti POV, atau admin
-- diangkat/dicabut lewat ManageAdmin) -- tombol admin hanya disembunyikan di
-- sini; server tetap menolak kalau dipalsukan.
task.spawn(function()
	while true do
		local ok, role = pcall(function()
			return GetMyRole:InvokeServer()
		end)
		if ok and typeof(role) == "string" then
			myRole = role
		end
		local isAdmin = (myRole == "ADMIN" or myRole == "SUPERADMIN")
		adminBox.Visible = isAdmin
		-- reset suka khusus SUPERADMIN, bukan admin biasa (server juga mengecek ulang)
		resetLikeBtn.Visible = myRole == "SUPERADMIN"
		if not isAdmin then
			searchPanel.Visible = false
		end
		task.wait(2)
	end
end)
