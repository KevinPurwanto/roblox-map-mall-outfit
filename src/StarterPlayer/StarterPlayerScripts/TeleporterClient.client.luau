--!strict
-- TeleporterClient
-- Panel kecil buat kios teleporter dekat spawn -- isi nomor podium, langsung
-- lompat ke situ. Terbuka lewat ProximityPrompt "TeleporterPrompt" (dibuat
-- Teleporter.server.luau), bukan lewat tombol persisten seperti panel lain.
--
-- Teks di panel ini multi-bahasa (id/en) lewat ReplicatedStorage/Localization,
-- dipilih otomatis dari Players.LocalPlayer.LocaleId.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TeleportToPodium = remotes:WaitForChild("TeleportToPodium") :: RemoteFunction

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))
local t = Localization.t

local PINK = Color3.fromRGB(255, 158, 203)
local PINK_DARK = Color3.fromRGB(214, 92, 150)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TeleporterUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0, 260, 0, 180)
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
title.Size = UDim2.new(1, 0, 0, 20)
title.BackgroundTransparency = 1
title.Text = t("teleporterTitle")
title.Font = Enum.Font.GothamBold
title.TextColor3 = PINK_DARK
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 1
title.Parent = panel

local field = Instance.new("TextBox")
field.Size = UDim2.new(1, 0, 0, 32)
field.BackgroundColor3 = Color3.new(1, 1, 1)
field.BorderSizePixel = 0
field.PlaceholderText = t("teleporterPlaceholder")
field.Text = ""
field.ClearTextOnFocus = false
field.Font = Enum.Font.Gotham
field.TextSize = 14
field.TextColor3 = INK
field.LayoutOrder = 2
field.Parent = panel
corner(field, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 18)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = INK
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextWrapped = true
status.LayoutOrder = 3
status.Parent = panel

local goBtn = Instance.new("TextButton")
goBtn.Size = UDim2.new(1, 0, 0, 34)
goBtn.BackgroundColor3 = PINK_DARK
goBtn.BorderSizePixel = 0
goBtn.Text = t("teleporterButton")
goBtn.TextColor3 = Color3.new(1, 1, 1)
goBtn.Font = Enum.Font.GothamMedium
goBtn.TextSize = 14
goBtn.LayoutOrder = 4
goBtn.Parent = panel
corner(goBtn, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(1, 0, 0, 30)
closeBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
closeBtn.BorderSizePixel = 0
closeBtn.Text = t("close")
closeBtn.TextColor3 = INK
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 13
closeBtn.LayoutOrder = 5
closeBtn.Parent = panel
corner(closeBtn, 8)

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

goBtn.MouseButton1Click:Connect(function()
	local n = tonumber(field.Text)
	if not n then
		status.Text = t("teleporterFillNumber")
		return
	end
	status.Text = t("teleporterInProgress")
	local ok, code, podiumIndex = TeleportToPodium:InvokeServer(math.floor(n))
	status.Text = describeResult(code, podiumIndex)
	if ok then
		task.wait(0.3)
		panel.Visible = false
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, promptPlayer)
	if promptPlayer ~= player then
		return
	end
	if prompt.Name == "TeleporterPrompt" then
		status.Text = ""
		field.Text = ""
		panel.Visible = true
	end
end)
