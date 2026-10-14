--!strict
-- HideGuiClient
-- Sembunyikan semua panel buatan game ini sekaligus, buat foto/rekaman.
--
-- Tombolnya sendiri TIDAK ikut disembunyikan -- kalau ikut, tidak ada jalan
-- kembali selain keluar-masuk server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)

-- Ikut disembunyikan juga: daftar pemain (leaderstats), chat, dan tombol
-- backpack bawaan Roblox. Justru itu yang paling mengganggu saat berfoto.
local CORE_TO_HIDE = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.EmotesMenu,
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HideGuiUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50 -- selalu di atas panel lain, supaya tidak pernah tertutup
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -16, 0.5, 92) -- di bawah ikon Keranjang & Donasi
holder.Size = UDim2.new(0, 64, 0, 82)
holder.BackgroundTransparency = 1
holder.Parent = gui

local btn = Instance.new("TextButton")
btn.Name = "HideGuiButton"
btn.AnchorPoint = Vector2.new(0.5, 0)
btn.Position = UDim2.new(0.5, 0, 0, 0)
btn.Size = UDim2.new(0, 58, 0, 58)
btn.BackgroundColor3 = PINK
btn.BorderSizePixel = 0
btn.Text = "👁"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 26
btn.Parent = holder
corner(btn, 29)

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.new(1, 1, 1)
btnStroke.Thickness = 2
btnStroke.Parent = btn

local caption = Instance.new("TextLabel")
caption.AnchorPoint = Vector2.new(0.5, 1)
caption.Position = UDim2.new(0.5, 0, 1, 0)
caption.Size = UDim2.new(1, 0, 0, 16)
caption.BackgroundTransparency = 1
caption.Text = t("hideGui")
caption.TextColor3 = PINK_DARK
caption.Font = Enum.Font.GothamBold
caption.TextSize = 12
caption.Parent = holder

local captionStroke = Instance.new("UIStroke")
captionStroke.Color = Color3.new(1, 1, 1)
captionStroke.Thickness = 2
captionStroke.Parent = caption

------------------------------------------------------------------
local hidden = false

-- Keadaan SEBELUM disembunyikan disimpan, bukan sekadar di-set true saat
-- dipulihkan. Kalau tidak, panel yang memang sedang tertutup (mis. panel outfit
-- yang belum dibuka) malah ikut menyala saat GUI ditampilkan lagi.
local previous: { [ScreenGui]: boolean } = {}

local function setHidden(value: boolean)
	hidden = value

	if hidden then
		table.clear(previous)
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") and child ~= gui then
				previous[child] = child.Enabled
				child.Enabled = false
			end
		end
	else
		for screen, wasEnabled in pairs(previous) do
			if screen.Parent then
				screen.Enabled = wasEnabled
			end
		end
		table.clear(previous)
	end

	for _, coreType in ipairs(CORE_TO_HIDE) do
		-- SetCore/SetCoreGuiEnabled bisa melempar kalau CoreGui belum siap atau
		-- tipe itu tidak tersedia di platform ini -- tidak fatal, jadi di-pcall
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, not hidden)
		end)
	end

	btn.Text = hidden and "🙈" or "👁"
	caption.Text = hidden and t("showGui") or t("hideGui")
end

btn.MouseButton1Click:Connect(function()
	setHidden(not hidden)
end)

-- ScreenGui yang dibuat BELAKANGAN (script lain bisa saja memuat lebih lambat)
-- ikut disembunyikan juga, kalau tidak ia akan muncul sendirian di layar kosong.
playerGui.ChildAdded:Connect(function(child: Instance)
	if hidden and child:IsA("ScreenGui") and child ~= gui then
		previous[child] = child.Enabled
		child.Enabled = false
	end
end)
