--!strict
-- ShowroomClient
-- UI dibangun lewat kode supaya semuanya tetap berupa file teks (enak untuk git & Rojo).
-- Panel admin di sini murni kosmetik. Pengamanan sebenarnya ada di Showroom.server.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local TryOn = remotes:WaitForChild("TryOn") :: RemoteEvent
local ResetAvatar = remotes:WaitForChild("ResetAvatar") :: RemoteEvent
local BuyOutfit = remotes:WaitForChild("BuyOutfit") :: RemoteEvent
local BuyItem = remotes:WaitForChild("BuyItem") :: RemoteEvent
local SetOutfit = remotes:WaitForChild("SetOutfit") :: RemoteEvent
local SetAccessories = remotes:WaitForChild("SetAccessories") :: RemoteEvent
local GetMyRole = remotes:WaitForChild("GetMyRole") :: RemoteFunction
local GetMannequin = remotes:WaitForChild("GetMannequinInfo") :: RemoteFunction

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

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.new(0, 300, 0, 676)
panel.BackgroundColor3 = PAPER
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 14)

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

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 22)
title.BackgroundTransparency = 1
title.Text = "" -- langsung ditimpa data.name tiap open(), nilai default tidak pernah kelihatan
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.LayoutOrder = 1
title.Parent = panel

local subInfo = Instance.new("TextLabel")
subInfo.Size = UDim2.new(1, 0, 0, 18)
subInfo.BackgroundTransparency = 1
subInfo.Text = ""
subInfo.TextColor3 = MUTED
subInfo.TextXAlignment = Enum.TextXAlignment.Left
subInfo.Font = Enum.Font.Gotham
subInfo.TextSize = 12
subInfo.LayoutOrder = 2
subInfo.Parent = panel

------------------------------------------------------------------
-- Grid item (thumbnail besar + nama + harga + Beli satuan), ala grid katalog
-- Roblox -- tema warna/font tetap yang sekarang, cuma layoutnya jadi kotak-kotak
------------------------------------------------------------------
local itemsScroller = Instance.new("ScrollingFrame")
itemsScroller.Size = UDim2.new(1, 0, 0, 234)
itemsScroller.BackgroundTransparency = 1
itemsScroller.BorderSizePixel = 0
itemsScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
itemsScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemsScroller.ScrollBarThickness = 4
itemsScroller.LayoutOrder = 3
itemsScroller.Parent = panel

local itemsGrid = Instance.new("UIGridLayout")
itemsGrid.CellSize = UDim2.new(0, 84, 0, 116)
itemsGrid.CellPadding = UDim2.new(0, 6, 0, 6)
itemsGrid.SortOrder = Enum.SortOrder.LayoutOrder
itemsGrid.Parent = itemsScroller

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

	local thumb = Instance.new("ImageLabel")
	thumb.Size = UDim2.new(1, 0, 0, 58)
	thumb.BackgroundColor3 = Color3.new(1, 1, 1)
	thumb.Image = string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", item.assetId)
	thumb.LayoutOrder = 1
	thumb.Parent = tile
	corner(thumb, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.Text = tostring(item.label)
	label.TextColor3 = INK
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.LayoutOrder = 2
	label.Parent = tile

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 12)
	status.BackgroundTransparency = 1
	status.TextColor3 = MUTED
	status.Font = Enum.Font.Gotham
	status.TextSize = 9
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.LayoutOrder = 3
	if item.owned then
		status.Text = t("alreadyOwned")
	elseif not item.forSale then
		status.Text = t("notForSale")
	else
		status.Text = tostring(item.price) .. " " .. t("robux")
	end
	status.Parent = tile

	local beliBtn = Instance.new("TextButton")
	beliBtn.Size = UDim2.new(1, 0, 0, 22)
	beliBtn.BorderSizePixel = 0
	beliBtn.Font = Enum.Font.GothamBold
	beliBtn.TextSize = 11
	beliBtn.TextColor3 = INK
	local canBuy = item.forSale and not item.owned
	beliBtn.Text = item.owned and t("owned") or (item.forSale and t("buy") or t("unavailable"))
	beliBtn.BackgroundColor3 = canBuy and BLUE or Color3.fromRGB(225, 220, 222)
	beliBtn.Active = canBuy
	beliBtn.AutoButtonColor = canBuy
	beliBtn.LayoutOrder = 4
	beliBtn.Parent = tile
	corner(beliBtn, 6)

	beliBtn.MouseButton1Click:Connect(function()
		if selected and canBuy then
			BuyItem:FireServer(selected, item.assetId)
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
	for i, item in ipairs(items) do
		buildItemTile(item, i).Parent = itemsScroller
	end
end

local tryBtn = button(t("tryOn"), PINK, 4, panel)
local buyAllBtn = button(t("buyAll"), BLUE, 5, panel)
local resetBtn = button(t("resetAvatar"), Color3.fromRGB(235, 235, 240), 6, panel)
local closeBtn = button(t("close"), Color3.fromRGB(235, 235, 240), 9, panel)

------------------------------------------------------------------
-- Bagian admin
------------------------------------------------------------------
local adminBox = Instance.new("Frame")
adminBox.Size = UDim2.new(1, 0, 0, 150)
adminBox.BackgroundColor3 = ROW_BG
adminBox.BorderSizePixel = 0
adminBox.Visible = false
adminBox.LayoutOrder = 7
adminBox.Parent = panel
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

local shirtField = idField(t("shirtFieldPlaceholder"), 1)
local pantsField = idField(t("pantsFieldPlaceholder"), 2)
local accessoriesField = idField(t("accessoriesFieldPlaceholder"), 3)
local saveBtn = button(t("saveToMannequin"), PINK_DARK, 4, adminBox)
saveBtn.TextColor3 = Color3.new(1, 1, 1)

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
-- Logika
------------------------------------------------------------------
local function open(mannequin: Model)
	local data = GetMannequin:InvokeServer(mannequin)
	if not data then
		return
	end

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
	buyAllBtn.Text = anyBuyable and t("buyAll") or t("alreadyOwnedAll")
	buyAllBtn.Active = anyBuyable
	buyAllBtn.AutoButtonColor = anyBuyable

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

local function close()
	panel.Visible = false
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

tryBtn.MouseButton1Click:Connect(function()
	if selected then
		TryOn:FireServer(selected)
	end
end)

buyAllBtn.MouseButton1Click:Connect(function()
	if selected then
		BuyOutfit:FireServer(selected)
	end
end)

resetBtn.MouseButton1Click:Connect(function()
	ResetAvatar:FireServer()
	close()
end)

closeBtn.MouseButton1Click:Connect(close)

saveBtn.MouseButton1Click:Connect(function()
	if not selected then
		return
	end
	local shirtId = extractId(shirtField.Text)
	local pantsId = extractId(pantsField.Text)
	SetOutfit:FireServer(selected, shirtId, pantsId)
	SetAccessories:FireServer(selected, extractIds(accessoriesField.Text))
	task.wait(0.2)
	open(selected)
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
		adminBox.Visible = (myRole == "ADMIN" or myRole == "SUPERADMIN")
		task.wait(2)
	end
end)
