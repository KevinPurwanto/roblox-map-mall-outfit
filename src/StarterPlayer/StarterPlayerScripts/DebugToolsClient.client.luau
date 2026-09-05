--!strict
-- DebugToolsClient
-- Panel testing (Studio only): ganti role sendiri (Player/Admin/Superadmin) dan
-- toggle lari cepat. Server (DebugTools.server.luau) menolak total kalau bukan
-- di Studio, jadi panel ini tidak berguna sama sekali di server live beneran.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local DebugSetRole = remotes:WaitForChild("DebugSetRole", 10) :: RemoteEvent?
local DebugSetSpeed = remotes:WaitForChild("DebugSetSpeed", 10) :: RemoteEvent?
local GetMyRole = remotes:WaitForChild("GetMyRole", 10) :: RemoteFunction?
if not DebugSetRole or not DebugSetSpeed or not GetMyRole then
	return -- server-nya entah kenapa tidak Studio juga -- jangan tampilkan apa-apa
end

local PINK_DARK = Color3.fromRGB(214, 92, 150)
local INK = Color3.fromRGB(60, 44, 54)
local PAPER = Color3.fromRGB(255, 246, 250)
local NEUTRAL = Color3.fromRGB(235, 235, 240)
local GREEN = Color3.fromRGB(160, 220, 170)

local isFast = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DebugToolsUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleDebugTools"
toggleBtn.Position = UDim2.new(0, 16, 0, 60)
toggleBtn.Size = UDim2.new(0, 180, 0, 32)
toggleBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "Debug: POV & Speed"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Parent = gui
corner(toggleBtn, 8)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 98)
panel.Size = UDim2.new(0, 220, 0, 230)
panel.BackgroundColor3 = PAPER
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 90, 100)
stroke.Thickness = 2
stroke.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 18)
title.BackgroundTransparency = 1
title.Text = "Role sekarang: PLAYER"
title.TextColor3 = INK
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 1
title.Parent = panel

local function roleBtn(label: string, role: string?, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = NEUTRAL
	b.BorderSizePixel = 0
	b.Text = label
	b.TextColor3 = INK
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.LayoutOrder = order
	b.Parent = panel
	corner(b, 8)
	b.MouseButton1Click:Connect(function()
		DebugSetRole:FireServer(role)
		task.wait(0.15)
		local ok, current = pcall(function()
			return GetMyRole:InvokeServer()
		end)
		title.Text = "Role sekarang: " .. (ok and tostring(current) or "?")
	end)
	return b
end

roleBtn("POV: Pembeli (Player)", "PLAYER", 2)
roleBtn("POV: Admin", "ADMIN", 3)
roleBtn("POV: Superadmin", "SUPERADMIN", 4)
roleBtn("Reset ke role asli", nil, 5)

local speedBtn = Instance.new("TextButton")
speedBtn.Size = UDim2.new(1, 0, 0, 30)
speedBtn.BackgroundColor3 = NEUTRAL
speedBtn.BorderSizePixel = 0
speedBtn.Text = "Lari cepat: OFF"
speedBtn.TextColor3 = INK
speedBtn.Font = Enum.Font.GothamMedium
speedBtn.TextSize = 13
speedBtn.LayoutOrder = 6
speedBtn.Parent = panel
corner(speedBtn, 8)

speedBtn.MouseButton1Click:Connect(function()
	isFast = not isFast
	DebugSetSpeed:FireServer(isFast)
	speedBtn.Text = "Lari cepat: " .. (isFast and "ON" or "OFF")
	speedBtn.BackgroundColor3 = isFast and GREEN or NEUTRAL
end)

toggleBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

------------------------------------------------------------------
task.spawn(function()
	local ok, role = pcall(function()
		return GetMyRole:InvokeServer()
	end)
	title.Text = "Role sekarang: " .. (ok and tostring(role) or "?")
end)
