--!strict
-- SprintSupport (server)
-- Pendamping Sprint.client.luau. Isinya cuma dua hal yang MEMANG tidak bisa
-- dikerjakan dari client.
--
-- Kecepatan larinya sendiri diatur di client (lihat Sprint.client.luau).

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

-- Shift Lock bawaan Roblox juga dipetakan ke Left Shift, jadi kalau dibiarkan
-- aktif, satu tekanan Shift akan lari SEKALIGUS mengunci kamera -- terasa seperti
-- bug padahal dua fitur berebut tombol yang sama. Properti ini cuma bisa diubah
-- dari server. Set true kalau suatu saat Shift Lock lebih dibutuhkan daripada
-- lari (dan pindahkan tombol lari ke KeyCode lain di Sprint.client.luau).
local ALLOW_SHIFT_LOCK = false

-- Sisa dari sistem lama "Speed Coil" (item backpack) yang sudah diganti tombol
-- lari. Tool-nya masih tersimpan di dalam file .rbxl, jadi dibuang saat runtime
-- supaya tidak muncul lagi di hotbar pemain. Ini TIDAK mengubah file .rbxl --
-- hapus manual di StarterPack (Edit mode) kalau mau permanen, lalu blok ini
-- boleh ikut dihapus.
local OBSOLETE_TOOL_NAME = "Speed Coil"

local function removeObsoleteTool(container: Instance?)
	if not container then
		return
	end
	local tool = container:FindFirstChild(OBSOLETE_TOOL_NAME)
	if tool then
		tool:Destroy()
		print("[SprintSupport] Item lama '" .. OBSOLETE_TOOL_NAME .. "' dibuang dari " .. container:GetFullName())
	end
end

removeObsoleteTool(StarterPack)

local function onPlayer(player: Player)
	player.DevEnableMouseLock = ALLOW_SHIFT_LOCK

	removeObsoleteTool(player:FindFirstChild("Backpack"))
	player.CharacterAdded:Connect(function(character: Model)
		removeObsoleteTool(character)
		removeObsoleteTool(player:FindFirstChild("Backpack"))
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerAdded:Connect(onPlayer)
