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
local SetOutfit = remotes:WaitForChild("SetOutfit") :: RemoteEvent
local GetMyRole = remotes:WaitForChild("GetMyRole") :: RemoteFunction
local GetMannequin = remotes:WaitForChild("GetMannequinInfo") :: RemoteFunction

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local BLUE = Color3.fromRGB(158, 216, 255)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)

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
panel.Size = UDim2.new(0, 260, 0, 300)
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
title.Text = "Outfit"
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.LayoutOrder = 1
title.Parent = panel

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 50)
info.BackgroundTransparency = 1
info.Text = ""
info.TextColor3 = INK
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Font = Enum.Font.Gotham
info.TextSize = 13
info.LayoutOrder = 2
info.Parent = panel

local tryBtn = button("Coba baju ini", PINK, 3, panel)
local buyBtn = button("Beli", BLUE, 4, panel)
local resetBtn = button("Kembalikan avatar", Color3.fromRGB(235, 235, 240), 5, panel)
local closeBtn = button("Tutup", Color3.fromRGB(235, 235, 240), 9, panel)

------------------------------------------------------------------
-- Bagian admin
------------------------------------------------------------------
local adminBox = Instance.new("Frame")
adminBox.Size = UDim2.new(1, 0, 0, 108)
adminBox.BackgroundColor3 = Color3.fromRGB(248, 238, 244)
adminBox.BorderSizePixel = 0
adminBox.Visible = false
adminBox.LayoutOrder = 6
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

local shirtField = idField("Shirt assetId", 1)
local pantsField = idField("Pants assetId", 2)
local saveBtn = button("Simpan ke mannequin", PINK_DARK, 3, adminBox)
saveBtn.TextColor3 = Color3.new(1, 1, 1)

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
	info.Text = string.format(
		"Podium %d  ·  %s\nShirt: %s\nPants: %s",
		data.podiumIndex,
		data.gender == "F" and "Cewek" or "Cowok",
		data.shirt > 0 and tostring(data.shirt) or "-",
		data.pants > 0 and tostring(data.pants) or "-"
	)

	buyBtn.Visible = data.price and data.price > 0 or data.shirt > 0
	buyBtn.Text = data.owned and "Sudah dimiliki" or "Beli"
	buyBtn.Active = not data.owned

	shirtField.Text = tostring(data.shirt)
	pantsField.Text = tostring(data.pants)

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

buyBtn.MouseButton1Click:Connect(function()
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
	local shirtId = tonumber(shirtField.Text) or 0
	local pantsId = tonumber(pantsField.Text) or 0
	SetOutfit:FireServer(selected, shirtId, pantsId)
	task.wait(0.2)
	open(selected)
end)

------------------------------------------------------------------
task.spawn(function()
	local ok, role = pcall(function()
		return GetMyRole:InvokeServer()
	end)
	if ok and typeof(role) == "string" then
		myRole = role
	end
	-- tombol admin hanya disembunyikan di sini; server tetap menolak kalau dipalsukan
	adminBox.Visible = (myRole == "ADMIN" or myRole == "SUPERADMIN")
end)
