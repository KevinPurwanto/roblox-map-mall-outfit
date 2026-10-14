--!strict
-- TeleporterClient
-- Panel portal teleporter: pilih podium tujuan, langsung lompat ke situ.
-- Terbuka lewat tombol E (ProximityPrompt "TeleporterPrompt") atau dengan
-- BERJALAN MASUK ke portal (PortalTrigger). Portalnya dibangun server, lihat
-- TeleporterPortal.luau.
--
-- Desain lama: kotak kecil 260x180 tanpa latar, menempel di depan portal, dan
-- pemain harus MENGETIK nomor -- padahal pemain tidak hafal nomor podium, dan di
-- HP mengetik itu merepotkan. Sekarang: modal di tengah (sama seperti keranjang
-- & donasi) dengan grid tombol nomor yang tinggal ditekan; kolom ketik tetap ada
-- untuk yang sudah tahu nomornya, plus tombol acak buat yang cuma mau jalan-jalan.
--
-- Teks multi-bahasa (id/en) lewat ReplicatedStorage/Localization.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TeleportToPodium = remotes:WaitForChild("TeleportToPodium") :: RemoteFunction

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local MAGENTA = Color3.fromRGB(255, 70, 160) -- sama dengan lingkar neon portal
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local ROW_BG = Color3.fromRGB(248, 238, 244)
local MUTED = Color3.fromRGB(130, 120, 125)
local WHITE = Color3.new(1, 1, 1)

local FALLBACK_PODIUM_COUNT = 120

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function textButton(parent: Instance, text: string, color: Color3, textColor: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = textColor
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

------------------------------------------------------------------
-- Rangka: latar gelap + jendela di tengah
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TeleporterUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.82, 0)
panel.BackgroundColor3 = PAPER
panel.BorderSizePixel = 0
panel.Parent = backdrop
corner(panel, 16)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MinSize = Vector2.new(280, 300)
panelSize.MaxSize = Vector2.new(470, 540)
panelSize.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = MAGENTA
stroke.Thickness = 3
stroke.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 14)
pad.PaddingBottom = UDim.new(0, 14)
pad.PaddingLeft = UDim.new(0, 16)
pad.PaddingRight = UDim.new(0, 16)
pad.Parent = panel

------------------------------------------------------------------
-- Header: judul + subjudul + tombol tutup (X). Tutup di header, DI LUAR area
-- scroll -- selalu terjangkau berapa pun tinggi layar.
------------------------------------------------------------------
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -44, 0, 26)
title.BackgroundTransparency = 1
title.Text = "✨ " .. t("teleporterTitle")
title.Font = Enum.Font.FredokaOne -- sama dengan tulisan di atas portal
title.TextSize = 22
title.TextColor3 = PINK_DARK
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.new(0, 0, 0, 26)
subtitle.Size = UDim2.new(1, -44, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = t("teleporterSubtitle")
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextColor3 = MUTED
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

-- "X" biasa, bukan "✕": font Gotham tidak punya glyph ✕ dan menampilkannya
-- sebagai kotak kosong (terlihat di screenshot Studio)
local closeBtn = textButton(panel, "X", ROW_BG, INK)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, 0, 0, 0)
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.TextSize = 18
-- bulat penuh: ubah radius sudut bawaan helper, jangan tambah UICorner kedua
(closeBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 18)

------------------------------------------------------------------
-- Baris cepat: kolom nomor + Pergi + Acak
------------------------------------------------------------------
local ROW_Y = 54

local field = Instance.new("TextBox")
field.Position = UDim2.new(0, 0, 0, ROW_Y)
field.Size = UDim2.new(1, -176, 0, 38)
field.BackgroundColor3 = WHITE
field.BorderSizePixel = 0
field.PlaceholderText = t("teleporterTypeHint")
field.Text = ""
field.ClearTextOnFocus = false
field.Font = Enum.Font.GothamMedium
field.TextSize = 15
field.TextColor3 = INK
field.Parent = panel
corner(field, 10)

local fieldStroke = Instance.new("UIStroke")
fieldStroke.Color = PINK
fieldStroke.Thickness = 1.5
fieldStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
fieldStroke.Parent = field

local goBtn = textButton(panel, t("teleporterGo"), MAGENTA, WHITE)
goBtn.AnchorPoint = Vector2.new(1, 0)
goBtn.Position = UDim2.new(1, -92, 0, ROW_Y)
goBtn.Size = UDim2.new(0, 76, 0, 38)

local randomBtn = textButton(panel, t("teleporterRandom"), ROW_BG, INK)
randomBtn.AnchorPoint = Vector2.new(1, 0)
randomBtn.Position = UDim2.new(1, 0, 0, ROW_Y)
randomBtn.Size = UDim2.new(0, 86, 0, 38)
randomBtn.TextSize = 13

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 0, 0, ROW_Y + 44)
status.Size = UDim2.new(1, 0, 0, 18)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = PINK_DARK
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = panel

------------------------------------------------------------------
-- Grid nomor podium -- mengisi sisa tinggi panel dan bisa digulir
------------------------------------------------------------------
local GRID_Y = ROW_Y + 68

local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.new(0, 0, 0, GRID_Y)
grid.Size = UDim2.new(1, 0, 1, -GRID_Y)
grid.BackgroundColor3 = ROW_BG
grid.BorderSizePixel = 0
grid.CanvasSize = UDim2.new(0, 0, 0, 0)
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollBarThickness = 5
grid.ScrollBarImageColor3 = PINK_DARK
grid.Parent = panel
corner(grid, 12)

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 8)
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.PaddingLeft = UDim.new(0, 8)
gridPad.PaddingRight = UDim.new(0, 8)
gridPad.Parent = grid

local gridLayout = Instance.new("UIGridLayout")
-- 48 px: target sentuh yang nyaman di HP (pedoman umum ~44 px ke atas)
gridLayout.CellSize = UDim2.new(0, 48, 0, 48)
gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent = grid

------------------------------------------------------------------
-- Teleport
------------------------------------------------------------------
-- kode status dari server -> teks lokal (biar pesan sukses/error ikut multi-bahasa)
local function describeResult(code: string, podiumIndex: number?): string
	if code == "ok" and podiumIndex then
		return t("teleporterOk", podiumIndex)
	elseif code == "not_found" and podiumIndex then
		return t("teleporterNotFound", podiumIndex)
	elseif code == "invalid_number" then
		return t("teleporterInvalidNumber")
	elseif code == "no_mannequins" then
		return t("teleporterNoMannequins")
	elseif code == "no_character" then
		return t("teleporterNoCharacter")
	end
	return code
end

-- Setelah panel ditutup, pemain biasanya masih berdiri DI DALAM portal. Tanpa
-- jeda ini, langkah sekecil apa pun langsung membuka panelnya lagi.
local REOPEN_COOLDOWN = 3
local closedAt = 0
local busy = false

local function closePanel()
	backdrop.Visible = false
	closedAt = os.clock()
end

local function teleportTo(n: number)
	if busy then
		return -- jangan tumpuk permintaan kalau tombol ditekan beruntun
	end
	busy = true
	status.Text = t("teleporterInProgress")
	local ok, success, code, podiumIndex = pcall(function()
		return TeleportToPodium:InvokeServer(math.floor(n))
	end)
	busy = false
	if not ok then
		status.Text = t("teleporterInvalidNumber")
		return
	end
	status.Text = describeResult(code, podiumIndex)
	if success then
		task.wait(0.25)
		closePanel()
	end
end

------------------------------------------------------------------
-- Isi grid. Jumlah podium dibaca dari mannequin yang ada (tag Mannequin),
-- bukan ditulis mati -- kalau podium ditambah/dikurangi, grid ikut.
------------------------------------------------------------------
local function podiumCount(): number
	local highest = 0
	for _, m in ipairs(CollectionService:GetTagged("Mannequin")) do
		local index = m:GetAttribute("PodiumIndex")
		if typeof(index) == "number" and index > highest then
			highest = index
		end
	end
	return highest > 0 and highest or FALLBACK_PODIUM_COUNT
end

local builtCount = 0

local function buildGrid()
	local count = podiumCount()
	if count == builtCount then
		return
	end
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i = 1, count do
		-- Kelipatan 10 diberi warna sebagai patokan. Dulu selang-seling warna
		-- per 10 nomor, tapi jumlah kolom grid ikut lebar layar (bukan 10),
		-- jadi pitanya tidak sejajar baris dan terlihat acak.
		local landmark = i % 10 == 0
		local b = textButton(grid, tostring(i), landmark and PINK or WHITE, landmark and WHITE or INK)
		b.LayoutOrder = i
		b.TextSize = 15
		local bStroke = Instance.new("UIStroke")
		bStroke.Color = PINK
		bStroke.Thickness = 1
		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bStroke.Parent = b
		b.MouseButton1Click:Connect(function()
			teleportTo(i)
		end)
	end
	builtCount = count
end

local function openPanel()
	if backdrop.Visible or os.clock() - closedAt < REOPEN_COOLDOWN then
		return
	end
	buildGrid() -- dibangun saat dibuka: saat script mulai, mannequin mungkin belum tiba
	status.Text = ""
	field.Text = ""
	grid.CanvasPosition = Vector2.zero
	backdrop.Visible = true
end

goBtn.MouseButton1Click:Connect(function()
	local n = tonumber(field.Text:match("%d+") or "")
	if not n then
		status.Text = t("teleporterFillNumber")
		return
	end
	teleportTo(n)
end)

field.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		local n = tonumber(field.Text:match("%d+") or "")
		if n then
			teleportTo(n)
		end
	end
end)

randomBtn.MouseButton1Click:Connect(function()
	teleportTo(math.random(1, math.max(builtCount, 1)))
end)

closeBtn.MouseButton1Click:Connect(closePanel)

ProximityPromptService.PromptTriggered:Connect(function(prompt, promptPlayer)
	if promptPlayer ~= player then
		return
	end
	if prompt.Name == "TeleporterPrompt" then
		closedAt = 0 -- tombol E itu niat eksplisit: abaikan jeda
		openPanel()
	end
end)

------------------------------------------------------------------
-- Portal: masuk = buka panel, cahaya berdenyut.
--
-- Keduanya di CLIENT. Touched pada karakter sendiri disimulasikan di client,
-- jadi responsnya instan. Denyut cahaya kalau dijalankan di server akan
-- mengirim perubahan properti ke semua pemain tiap frame, untuk efek yang
-- murni kosmetik.
------------------------------------------------------------------
task.spawn(function()
	local kiosk = workspace:WaitForChild("TeleporterKiosk", 60)
	if not kiosk then
		return
	end

	local trigger = kiosk:WaitForChild("PortalTrigger", 10) :: BasePart?
	if trigger then
		trigger.Touched:Connect(function(hit: BasePart)
			local character = player.Character
			if character and hit:IsDescendantOf(character) then
				openPanel()
			end
		end)
	end

	local surface = kiosk:WaitForChild("PortalSurface", 10)
	local light = surface and surface:FindFirstChild("PortalGlow") :: PointLight?
	if light then
		local base = light.Brightness
		local pulse = TweenService:Create(
			light,
			TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Brightness = base * 1.8 }
		)
		pulse:Play()
	end
end)
