--!strict
-- DonateClient
-- Panel donasi: kartu donatur teratas, papan donatur global, dan tombol nominal.
--
-- Nominalnya Developer Product -- PromptProductPurchase boleh dipanggil dari
-- client, jadi tidak perlu remote untuk membuka dialognya. Yang TIDAK boleh dari
-- client adalah mencatat hasilnya: itu dikerjakan ProcessReceipt di server
-- (Donations.server.luau), karena cuma server yang tahu pembayaran benar terjadi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GetDonationInfo = remotes:WaitForChild("GetDonationInfo") :: RemoteFunction
local StatsChanged = remotes:WaitForChild("StatsChanged") :: RemoteEvent

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local MUTED = Color3.fromRGB(130, 120, 125)

-- di bawah lebar ini, tiga kolom jadi terlalu sempit untuk dibaca -> ditumpuk
local WIDE_BREAKPOINT = 760

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- string.format tidak punya pemisah ribuan. Ditulis sebagai loop dari digit
-- paling kanan, bukan trik gsub+reverse: trik itu butuh karakter penanda
-- sementara di dalam pattern, dan itu area Lua yang gampang meleset diam-diam.
local function robuxText(amount: number): string
	local sep = t("thousandsSep")
	local digits = tostring(math.floor(math.max(amount, 0)))
	local out = ""
	local count = 0
	for i = #digits, 1, -1 do
		out = digits:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = sep .. out
		end
	end
	return out
end

------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DonateUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Tombol pembuka -- bersebelahan dengan ikon keranjang di kiri-bawah, bentuk
-- sama supaya terbaca sebagai sepasang aksi utama, bukan tombol admin.
local donateCorner = Instance.new("Frame")
donateCorner.AnchorPoint = Vector2.new(0, 1)
donateCorner.Position = UDim2.new(0, 88, 1, -16)
donateCorner.Size = UDim2.new(0, 64, 0, 82)
donateCorner.BackgroundTransparency = 1
donateCorner.Parent = gui

local openBtn = Instance.new("TextButton")
openBtn.Name = "DonateButton"
openBtn.AnchorPoint = Vector2.new(0.5, 0)
openBtn.Position = UDim2.new(0.5, 0, 0, 0)
openBtn.Size = UDim2.new(0, 58, 0, 58)
openBtn.BackgroundColor3 = PINK
openBtn.BorderSizePixel = 0
openBtn.Text = "🎁"
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 26
openBtn.Parent = donateCorner
corner(openBtn, 29)

local openStroke = Instance.new("UIStroke")
openStroke.Color = Color3.new(1, 1, 1)
openStroke.Thickness = 2
openStroke.Parent = openBtn

local openCaption = Instance.new("TextLabel")
openCaption.AnchorPoint = Vector2.new(0.5, 1)
openCaption.Position = UDim2.new(0.5, 0, 1, 0)
openCaption.Size = UDim2.new(1, 0, 0, 16)
openCaption.BackgroundTransparency = 1
openCaption.Text = t("donateButton")
openCaption.TextColor3 = PINK_DARK
openCaption.Font = Enum.Font.GothamBold
openCaption.TextSize = 12
openCaption.Parent = donateCorner

local captionStroke = Instance.new("UIStroke")
captionStroke.Color = Color3.new(1, 1, 1)
captionStroke.Thickness = 2
captionStroke.Parent = openCaption

------------------------------------------------------------------
-- Modal
------------------------------------------------------------------
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.ZIndex = 20
backdrop.Parent = gui

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.new(0.94, 0, 0.88, 0)
window.BackgroundColor3 = PAPER
window.BorderSizePixel = 0
window.ZIndex = 21
window.Parent = backdrop
corner(window, 16)

local windowSize = Instance.new("UISizeConstraint")
windowSize.MinSize = Vector2.new(300, 320)
windowSize.MaxSize = Vector2.new(860, 560)
windowSize.Parent = window

local wStroke = Instance.new("UIStroke")
wStroke.Color = PINK
wStroke.Thickness = 2
wStroke.Parent = window

local wPad = Instance.new("UIPadding")
wPad.PaddingTop = UDim.new(0, 14)
wPad.PaddingBottom = UDim.new(0, 14)
wPad.PaddingLeft = UDim.new(0, 14)
wPad.PaddingRight = UDim.new(0, 14)
wPad.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 0, 28)
title.BackgroundTransparency = 1
title.Text = t("donateTitle")
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.ZIndex = 22
title.Parent = window

-- Tutup di pojok kanan-atas, DI LUAR area scroll: selalu terjangkau berapa pun
-- tinggi layar (aturan layout di CLAUDE.md).
local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, 0, 0, 0)
closeBtn.Size = UDim2.new(0, 84, 0, 30)
closeBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
closeBtn.BorderSizePixel = 0
closeBtn.Text = t("close")
closeBtn.TextColor3 = INK
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 13
closeBtn.ZIndex = 22
closeBtn.Parent = window
corner(closeBtn, 8)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.new(0, 0, 0, 38)
content.Size = UDim2.new(1, 0, 1, -38)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 4
content.ZIndex = 21
content.Parent = window

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 10)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.Parent = content

local function makeColumn(order: number): Frame
	local col = Instance.new("Frame")
	col.BackgroundColor3 = ROW_BG
	col.BorderSizePixel = 0
	col.LayoutOrder = order
	col.ZIndex = 21
	col.Parent = content
	corner(col, 12)

	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 10)
	p.PaddingBottom = UDim.new(0, 10)
	p.PaddingLeft = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 10)
	p.Parent = col

	return col
end

local topCol = makeColumn(1)
local boardCol = makeColumn(2)
local amountCol = makeColumn(3)

------------------------------------------------------------------
-- Kolom 1: donatur teratas
------------------------------------------------------------------
local topTitle = Instance.new("TextLabel")
topTitle.Size = UDim2.new(1, 0, 0, 20)
topTitle.BackgroundTransparency = 1
topTitle.Text = t("donateTopDonor")
topTitle.TextColor3 = PINK_DARK
topTitle.Font = Enum.Font.GothamBold
topTitle.TextSize = 15
topTitle.ZIndex = 22
topTitle.Parent = topCol

local topAvatar = Instance.new("ImageLabel")
topAvatar.AnchorPoint = Vector2.new(0.5, 0)
topAvatar.Position = UDim2.new(0.5, 0, 0, 26)
topAvatar.Size = UDim2.new(0, 150, 0, 150)
topAvatar.BackgroundColor3 = Color3.new(1, 1, 1)
topAvatar.BackgroundTransparency = 0.5
topAvatar.BorderSizePixel = 0
topAvatar.ZIndex = 22
topAvatar.Parent = topCol
corner(topAvatar, 12)

local topName = Instance.new("TextLabel")
topName.AnchorPoint = Vector2.new(0.5, 0)
topName.Position = UDim2.new(0.5, 0, 0, 182)
topName.Size = UDim2.new(1, 0, 0, 22)
topName.BackgroundTransparency = 1
topName.Text = t("donateNobody")
topName.TextColor3 = INK
topName.Font = Enum.Font.GothamBold
topName.TextSize = 15
topName.TextTruncate = Enum.TextTruncate.AtEnd
topName.ZIndex = 22
topName.Parent = topCol

local topAmount = Instance.new("TextLabel")
topAmount.AnchorPoint = Vector2.new(0.5, 0)
topAmount.Position = UDim2.new(0.5, 0, 0, 204)
topAmount.Size = UDim2.new(1, 0, 0, 20)
topAmount.BackgroundTransparency = 1
topAmount.Text = ""
topAmount.TextColor3 = PINK_DARK
topAmount.Font = Enum.Font.GothamBold
topAmount.TextSize = 14
topAmount.ZIndex = 22
topAmount.Parent = topCol

------------------------------------------------------------------
-- Kolom 2: papan donatur
------------------------------------------------------------------
local boardTitle = Instance.new("TextLabel")
boardTitle.Size = UDim2.new(1, 0, 0, 20)
boardTitle.BackgroundTransparency = 1
boardTitle.Text = t("donateLeaderboard")
boardTitle.TextColor3 = PINK_DARK
boardTitle.Font = Enum.Font.GothamBold
boardTitle.TextSize = 15
boardTitle.ZIndex = 22
boardTitle.Parent = boardCol

local boardScroller = Instance.new("ScrollingFrame")
boardScroller.Position = UDim2.new(0, 0, 0, 26)
boardScroller.Size = UDim2.new(1, 0, 1, -26)
boardScroller.BackgroundTransparency = 1
boardScroller.BorderSizePixel = 0
boardScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
boardScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
boardScroller.ScrollBarThickness = 4
boardScroller.ZIndex = 22
boardScroller.Parent = boardCol

local boardList = Instance.new("UIListLayout")
boardList.Padding = UDim.new(0, 5)
boardList.SortOrder = Enum.SortOrder.LayoutOrder
boardList.Parent = boardScroller

local boardEmpty = Instance.new("TextLabel")
boardEmpty.Size = UDim2.new(1, 0, 0, 40)
boardEmpty.BackgroundTransparency = 1
boardEmpty.Text = t("donateNobody")
boardEmpty.TextColor3 = MUTED
boardEmpty.Font = Enum.Font.Gotham
boardEmpty.TextSize = 12
boardEmpty.TextWrapped = true
boardEmpty.ZIndex = 22
boardEmpty.LayoutOrder = 1
boardEmpty.Parent = boardScroller

------------------------------------------------------------------
-- Kolom 3: nominal
------------------------------------------------------------------
local amountTitle = Instance.new("TextLabel")
amountTitle.Size = UDim2.new(1, 0, 0, 20)
amountTitle.BackgroundTransparency = 1
amountTitle.Text = t("donateAmounts")
amountTitle.TextColor3 = PINK_DARK
amountTitle.Font = Enum.Font.GothamBold
amountTitle.TextSize = 15
amountTitle.ZIndex = 22
amountTitle.Parent = amountCol

local amountScroller = Instance.new("ScrollingFrame")
amountScroller.Position = UDim2.new(0, 0, 0, 26)
amountScroller.Size = UDim2.new(1, 0, 1, -64)
amountScroller.BackgroundTransparency = 1
amountScroller.BorderSizePixel = 0
amountScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
amountScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
amountScroller.ScrollBarThickness = 4
amountScroller.ZIndex = 22
amountScroller.Parent = amountCol

local amountList = Instance.new("UIListLayout")
amountList.Padding = UDim.new(0, 6)
amountList.SortOrder = Enum.SortOrder.LayoutOrder
amountList.Parent = amountScroller

local myDonated = Instance.new("TextLabel")
myDonated.AnchorPoint = Vector2.new(0, 1)
myDonated.Position = UDim2.new(0, 0, 1, 0)
myDonated.Size = UDim2.new(1, 0, 0, 34)
myDonated.BackgroundColor3 = PINK
myDonated.BackgroundTransparency = 0.5
myDonated.BorderSizePixel = 0
myDonated.Text = t("donateYouHave") .. ": 0"
myDonated.TextColor3 = INK
myDonated.Font = Enum.Font.GothamBold
myDonated.TextSize = 13
myDonated.TextWrapped = true
myDonated.ZIndex = 22
myDonated.Parent = amountCol
corner(myDonated, 8)

------------------------------------------------------------------
-- Tata letak responsif: 3 kolom sejajar di layar lebar, ditumpuk di layar sempit.
-- Roblox tidak punya media query, jadi dipantau lewat AbsoluteSize ScreenGui.
------------------------------------------------------------------
local STACKED_HEIGHTS = { [topCol] = 240, [boardCol] = 260, [amountCol] = 320 }

local function relayout()
	local wide = gui.AbsoluteSize.X >= WIDE_BREAKPOINT
	contentList.FillDirection = wide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	for col, stackedHeight in pairs(STACKED_HEIGHTS) do
		if wide then
			-- tiga kolom + dua celah 10px; 0.327 menyisakan ruang untuk celah itu
			col.Size = UDim2.new(0.327, 0, 1, 0)
		else
			col.Size = UDim2.new(1, 0, 0, stackedHeight)
		end
	end
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
relayout()

------------------------------------------------------------------
-- Isi data
------------------------------------------------------------------
local function buildAmountButton(entry: any, order: number)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = PINK
	btn.BorderSizePixel = 0
	btn.Text = robuxText(entry.robux) .. " Robux"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.LayoutOrder = order
	btn.ZIndex = 23
	btn.Parent = amountScroller
	corner(btn, 8)

	btn.MouseButton1Click:Connect(function()
		-- PromptProductPurchase boleh dari client; yang mencatat hasilnya tetap
		-- ProcessReceipt di server
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, entry.productId)
		end)
	end)
end

local function buildBoardRow(entry: any, rank: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, 44)
	row.BackgroundColor3 = entry.userId == player.UserId and PINK or PAPER
	row.BackgroundTransparency = entry.userId == player.UserId and 0.4 or 0
	row.BorderSizePixel = 0
	row.LayoutOrder = rank
	row.ZIndex = 23
	row.Parent = boardScroller
	corner(row, 8)

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Position = UDim2.new(0, 6, 0, 0)
	rankLabel.Size = UDim2.new(0, 30, 1, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "#" .. rank
	rankLabel.TextColor3 = PINK_DARK
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextSize = 13
	rankLabel.ZIndex = 24
	rankLabel.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Position = UDim2.new(0, 38, 0, 5)
	avatar.Size = UDim2.new(0, 34, 0, 34)
	avatar.BackgroundColor3 = Color3.new(1, 1, 1)
	avatar.BorderSizePixel = 0
	avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.userId)
	avatar.ZIndex = 24
	avatar.Parent = row
	corner(avatar, 17)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 78, 0, 5)
	name.Size = UDim2.new(1, -84, 0, 17)
	name.BackgroundTransparency = 1
	name.Text = tostring(entry.name)
	name.TextColor3 = INK
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 24
	name.Parent = row

	local amount = Instance.new("TextLabel")
	amount.Position = UDim2.new(0, 78, 0, 22)
	amount.Size = UDim2.new(1, -84, 0, 16)
	amount.BackgroundTransparency = 1
	amount.Text = robuxText(entry.donated) .. " Robux"
	amount.TextColor3 = MUTED
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Font = Enum.Font.Gotham
	amount.TextSize = 12
	amount.ZIndex = 24
	amount.Parent = row
end

local amountsBuilt = false

local function refresh()
	local ok, info = pcall(function()
		return GetDonationInfo:InvokeServer()
	end)
	if not ok or typeof(info) ~= "table" then
		return
	end

	-- Tombol nominal tidak pernah berubah selama sesi, jadi cukup dibangun sekali
	if not amountsBuilt then
		amountsBuilt = true
		local products = typeof(info.products) == "table" and info.products or {}
		if #products == 0 then
			local note = Instance.new("TextLabel")
			note.Size = UDim2.new(1, 0, 0, 70)
			note.BackgroundTransparency = 1
			note.Text = t("donateNoProducts")
			note.TextColor3 = MUTED
			note.Font = Enum.Font.Gotham
			note.TextSize = 12
			note.TextWrapped = true
			note.ZIndex = 23
			note.Parent = amountScroller
		else
			for i, entry in ipairs(products) do
				buildAmountButton(entry, i)
			end
		end
	end

	myDonated.Text = t("donateYouHave") .. ": " .. robuxText(tonumber(info.myDonated) or 0)

	for _, child in ipairs(boardScroller:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local donors = typeof(info.topDonors) == "table" and info.topDonors or {}
	boardEmpty.Visible = #donors == 0
	for i, entry in ipairs(donors) do
		buildBoardRow(entry, i)
	end

	local best = donors[1]
	if best then
		topAvatar.Image = string.format("rbxthumb://type=AvatarBust&id=%d&w=420&h=420", best.userId)
		topName.Text = tostring(best.name)
		topAmount.Text = robuxText(best.donated) .. " Robux"
	else
		topAvatar.Image = ""
		topName.Text = t("donateNobody")
		topAmount.Text = ""
	end
end

------------------------------------------------------------------
local function setOpen(open: boolean)
	backdrop.Visible = open
	donateCorner.Visible = not open
	if open then
		task.spawn(refresh)
	end
end

openBtn.MouseButton1Click:Connect(function()
	setOpen(true)
end)
closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- Donasi yang baru masuk menyiarkan StatsChanged -- kalau panelnya sedang
-- terbuka, angkanya ikut berubah tanpa perlu ditutup-buka lagi
StatsChanged.OnClientEvent:Connect(function()
	if backdrop.Visible then
		task.spawn(refresh)
	end
end)
