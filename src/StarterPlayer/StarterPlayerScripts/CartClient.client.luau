--!strict
-- CartClient
-- Keranjang belanja: kumpulkan baju dari podium mana saja sambil keliling mall,
-- bayar sekali di akhir lewat satu dialog checkout Roblox.
--
-- Tombol keranjang sengaja PERSISTEN (selalu di layar), beda dari panel outfit
-- yang cuma muncul saat mendekati mannequin -- isi keranjang harus bisa dicek
-- kapan saja, bukan cuma saat berdiri di depan podium.
--
-- Isi keranjang dipegang SERVER. Script ini tidak pernah menyimpan daftarnya
-- sendiri: setiap perubahan datang lewat CartUpdated, jadi tidak ada dua sumber
-- kebenaran yang bisa berbeda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CartRemove = remotes:WaitForChild("CartRemove") :: RemoteEvent
local CartClear = remotes:WaitForChild("CartClear") :: RemoteEvent
local BuyCart = remotes:WaitForChild("BuyCart") :: RemoteEvent
local GetCart = remotes:WaitForChild("GetCart") :: RemoteFunction
local CartUpdated = remotes:WaitForChild("CartUpdated") :: RemoteEvent

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local MAX_CART_ITEMS = 20 -- harus sama dengan MAX_CART_ITEMS di Showroom.server.luau

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local BLUE = Color3.fromRGB(158, 216, 255)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local MUTED = Color3.fromRGB(130, 120, 125)

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
gui.Name = "CartUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

------------------------------------------------------------------
-- Tombol keranjang: ikon bulat + badge jumlah + keterangan kecil.
--
-- Dulu tombol teks "Keranjang (0)" -- gampang terbaca sebagai tombol debug/admin
-- dan tenggelam di antara tombol lain. Bentuk bulat mengambang dengan ikon
-- troli + badge angka adalah pola belanja yang sudah dikenal semua orang, jadi
-- pelanggan tidak perlu membaca apa pun untuk tahu fungsinya.
--
-- Ikonnya emoji, bukan asset gambar: tidak butuh assetId yang harus di-upload
-- dan tidak bisa gagal termuat.
------------------------------------------------------------------
local cartCorner = Instance.new("Frame")
cartCorner.Name = "CartCorner"
cartCorner.AnchorPoint = Vector2.new(0, 1)
cartCorner.Position = UDim2.new(0, 16, 1, -16)
cartCorner.Size = UDim2.new(0, 64, 0, 82)
cartCorner.BackgroundTransparency = 1
cartCorner.Parent = gui

local openBtn = Instance.new("TextButton")
openBtn.Name = "CartButton"
openBtn.AnchorPoint = Vector2.new(0.5, 0)
openBtn.Position = UDim2.new(0.5, 0, 0, 0)
openBtn.Size = UDim2.new(0, 58, 0, 58)
openBtn.BackgroundColor3 = PINK_DARK
openBtn.BorderSizePixel = 0
openBtn.Text = "🛒"
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 26
openBtn.Parent = cartCorner
corner(openBtn, 29) -- setengah dari 58 = lingkaran penuh

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.new(1, 1, 1)
btnStroke.Thickness = 2
btnStroke.Parent = openBtn

-- Badge jumlah barang, disembunyikan saat keranjang kosong supaya tidak
-- menampilkan "0" yang justru terlihat seperti error
local badge = Instance.new("TextLabel")
badge.Name = "Badge"
badge.AnchorPoint = Vector2.new(1, 0)
badge.Position = UDim2.new(1, 4, 0, -4)
badge.Size = UDim2.new(0, 24, 0, 24)
badge.BackgroundColor3 = Color3.fromRGB(226, 62, 87)
badge.BorderSizePixel = 0
badge.Text = "0"
badge.TextColor3 = Color3.new(1, 1, 1)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 12
badge.Visible = false
badge.ZIndex = 2
badge.Parent = openBtn
corner(badge, 12)

local badgeStroke = Instance.new("UIStroke")
badgeStroke.Color = Color3.new(1, 1, 1)
badgeStroke.Thickness = 2
badgeStroke.Parent = badge

local caption = Instance.new("TextLabel")
caption.AnchorPoint = Vector2.new(0.5, 1)
caption.Position = UDim2.new(0.5, 0, 1, 0)
caption.Size = UDim2.new(1, 0, 0, 16)
caption.BackgroundTransparency = 1
caption.Text = t("cartTitle")
caption.TextColor3 = PINK_DARK
caption.Font = Enum.Font.GothamBold
caption.TextSize = 12
caption.Parent = cartCorner

local captionStroke = Instance.new("UIStroke")
captionStroke.Color = Color3.new(1, 1, 1)
captionStroke.Thickness = 2 -- garis putih supaya terbaca di atas lantai terang maupun gelap
captionStroke.Parent = caption

local panel = Instance.new("Frame")
panel.Name = "CartPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -16)
-- Tinggi ikut layar, dibatasi UISizeConstraint. Dulu 430 px tetap: di viewport
-- pendek panel melewati batas atas layar sekaligus menindih tombol pembukanya
-- sendiri di bawah.
panel.Size = UDim2.new(0, 300, 1, -80)
panel.BackgroundColor3 = PAPER
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 14)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MinSize = Vector2.new(220, 260)
panelSize.MaxSize = Vector2.new(300, 430)
panelSize.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 2
stroke.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 20)
title.BackgroundTransparency = 1
title.Text = t("cartTitle")
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.LayoutOrder = 1
title.Parent = panel

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, 0, 0, 28)
countLabel.BackgroundTransparency = 1
countLabel.Text = t("cartHint", MAX_CART_ITEMS)
countLabel.TextColor3 = MUTED
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 11
countLabel.TextWrapped = true
countLabel.LayoutOrder = 2
countLabel.Parent = panel

local scroller = Instance.new("ScrollingFrame")
-- tinggi SISA panel, bukan 250 tetap -- yang menyusut saat panel mengecil harus
-- daftar barangnya, bukan tombol checkout/Tutup yang terdorong keluar
scroller.Size = UDim2.new(1, 0, 1, -237)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollBarThickness = 4
scroller.LayoutOrder = 3
scroller.Parent = panel

local rows = Instance.new("UIListLayout")
rows.Padding = UDim.new(0, 5)
rows.SortOrder = Enum.SortOrder.LayoutOrder
rows.Parent = scroller

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Size = UDim2.new(1, 0, 0, 40)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text = t("cartEmpty")
emptyLabel.TextColor3 = MUTED
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 12
emptyLabel.TextWrapped = true
emptyLabel.LayoutOrder = 1
emptyLabel.Parent = scroller

local totalLabel = Instance.new("TextLabel")
totalLabel.Size = UDim2.new(1, 0, 0, 18)
totalLabel.BackgroundTransparency = 1
totalLabel.Text = t("cartTotal", 0)
totalLabel.TextColor3 = INK
totalLabel.TextXAlignment = Enum.TextXAlignment.Left
totalLabel.Font = Enum.Font.GothamBold
totalLabel.TextSize = 13
totalLabel.LayoutOrder = 4
totalLabel.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 15)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = MUTED
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.LayoutOrder = 5
statusLabel.Parent = panel

local function button(text: string, color: Color3, order: number, textColor: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = textColor
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.LayoutOrder = order
	b.Parent = panel
	corner(b, 8)
	return b
end

local checkoutBtn = button(t("cartCheckout"), BLUE, 6, INK)
local clearBtn = button(t("cartClear"), Color3.fromRGB(235, 235, 240), 7, INK)
local closeBtn = button(t("close"), Color3.fromRGB(235, 235, 240), 8, INK)

------------------------------------------------------------------
-- Render
------------------------------------------------------------------
local function buildRow(item: any, order: number): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, 46)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	corner(row, 8)

	-- assetId keranjang selalu ID KATALOG, jadi rbxthumb-nya render resmi Roblox
	local thumb = Instance.new("ImageLabel")
	thumb.Size = UDim2.new(0, 38, 0, 38)
	thumb.Position = UDim2.new(0, 4, 0, 4)
	thumb.BackgroundColor3 = Color3.new(1, 1, 1)
	thumb.BorderSizePixel = 0
	thumb.Image = string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", item.assetId)
	thumb.Parent = row
	corner(thumb, 6)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 48, 0, 5)
	name.Size = UDim2.new(1, -110, 0, 16)
	name.BackgroundTransparency = 1
	name.Text = tostring(item.label)
	name.TextColor3 = INK
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 12
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = row

	local price = Instance.new("TextLabel")
	price.Position = UDim2.new(0, 48, 0, 23)
	price.Size = UDim2.new(1, -110, 0, 15)
	price.BackgroundTransparency = 1
	if item.owned then
		price.Text = t("alreadyOwned")
	elseif not item.forSale then
		price.Text = t("notForSale")
	else
		price.Text = tostring(item.price) .. " " .. t("robux")
	end
	price.TextColor3 = MUTED
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.Font = Enum.Font.Gotham
	price.TextSize = 11
	price.Parent = row

	local removeBtn = Instance.new("TextButton")
	removeBtn.AnchorPoint = Vector2.new(1, 0.5)
	removeBtn.Position = UDim2.new(1, -6, 0.5, 0)
	removeBtn.Size = UDim2.new(0, 52, 0, 24)
	removeBtn.BackgroundColor3 = Color3.fromRGB(235, 225, 230)
	removeBtn.BorderSizePixel = 0
	removeBtn.Text = t("cartRemove")
	removeBtn.TextColor3 = INK
	removeBtn.Font = Enum.Font.Gotham
	removeBtn.TextSize = 11
	removeBtn.Parent = row
	corner(removeBtn, 6)

	removeBtn.MouseButton1Click:Connect(function()
		CartRemove:FireServer(item.assetId)
	end)

	return row
end

local function render(items: { any })
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	emptyLabel.Visible = #items == 0

	-- Total hanya menjumlahkan yang benar-benar akan ditagih. Barang yang sudah
	-- dimiliki atau sudah tidak dijual dikeluarkan Roblox sendiri dari total
	-- bayar, jadi menghitungnya di sini cuma akan bikin angka kita lebih besar
	-- daripada angka di dialog checkout -- terlihat seperti salah hitung.
	local total = 0
	for i, item in ipairs(items) do
		buildRow(item, i).Parent = scroller
		if item.forSale and not item.owned then
			total += item.price
		end
	end

	totalLabel.Text = t("cartTotal", total)
	badge.Text = #items > 99 and "99+" or tostring(#items)
	badge.Visible = #items > 0

	-- Catatan "sudah dimiliki tidak ikut dibayar" ditempel ke baris jumlah,
	-- BUKAN ke statusLabel: statusLabel dipakai pesan sementara ("Ditambahkan ke
	-- keranjang" dst) yang di-set setelah render, jadi catatan ini akan selalu
	-- langsung tertimpa dan praktis tidak pernah terbaca.
	local hasOwned = false
	for _, item in ipairs(items) do
		if item.owned then
			hasOwned = true
			break
		end
	end
	countLabel.Text = t("cartCount", #items, MAX_CART_ITEMS)
	if hasOwned then
		countLabel.Text ..= "  ·  " .. t("cartOwnedNote")
	end

	local canBuy = #items > 0
	checkoutBtn.Active = canBuy
	checkoutBtn.AutoButtonColor = canBuy
	checkoutBtn.BackgroundColor3 = canBuy and BLUE or Color3.fromRGB(225, 220, 222)
end

local function describeReason(reason: string): string
	if reason == "added" then
		return t("cartAdded")
	elseif reason == "full" then
		return t("cartFull", MAX_CART_ITEMS)
	elseif reason == "duplicate" then
		return t("cartDuplicate")
	elseif reason == "removed" then
		return t("cartRemoved")
	elseif reason == "cleared" then
		return t("cartCleared")
	end
	return ""
end

------------------------------------------------------------------
-- Event
------------------------------------------------------------------
CartUpdated.OnClientEvent:Connect(function(items: any, reason: any)
	if typeof(items) ~= "table" then
		return
	end
	render(items)
	if typeof(reason) == "string" then
		statusLabel.Text = describeReason(reason)
	end
end)

-- Tombol pembuka DISEMBUNYIKAN selama panel terbuka. Panel menempati sudut yang
-- sama, jadi kalau keduanya tampil, tombol Tutup panel duduk persis di atas
-- tombol keranjang -- terlihat seperti panel menutupi tombolnya sendiri.
local function setOpen(open: boolean)
	panel.Visible = open
	cartCorner.Visible = not open
	if open then
		statusLabel.Text = ""
	end
end

openBtn.MouseButton1Click:Connect(function()
	setOpen(true)
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

clearBtn.MouseButton1Click:Connect(function()
	CartClear:FireServer()
end)

checkoutBtn.MouseButton1Click:Connect(function()
	BuyCart:FireServer()
end)

-- Ambil isi awal: keranjang bertahan selama pemain masih di server yang sama,
-- jadi setelah respawn/reset karakter isinya harus muncul lagi apa adanya.
task.spawn(function()
	local ok, items = pcall(function()
		return GetCart:InvokeServer()
	end)
	if ok and typeof(items) == "table" then
		render(items)
	end
end)
