--!strict
-- SpeedTool (server)
-- Item di backpack semua pemain buat lari cepat keliling mall -- equip = cepat,
-- unequip/simpan = normal lagi.
--
-- Tool di StarterPack cuma TEMPLATE -- Roblox meng-CLONE isinya ke Backpack
-- tiap pemain spawn, dan Clone() tidak ikut menyalin koneksi :Connect() dari
-- script luar. Sempat dicoba dengan Backpack.ChildAdded untuk menangkap tiap
-- clone baru, tapi ternyata event itu tidak terpicu untuk kasus ini (kemungkinan
-- quirk cara Roblox menyalin StarterPack->Backpack). Solusi yang lebih tahan
-- banting: polling tiap 1 detik, cek Backpack & Character semua pemain, pasang
-- listener begitu ketemu tool yang belum pernah di-wire.

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local NORMAL_SPEED = 16
local FAST_SPEED = 50
local TOOL_NAME = "Speed Coil"

local function buildTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 2)
	handle.Color = Color3.fromRGB(255, 158, 203)
	handle.Material = Enum.Material.Neon
	handle.Parent = tool

	return tool
end

if not StarterPack:FindFirstChild(TOOL_NAME) then
	buildTemplate().Parent = StarterPack
end

local function setSpeed(character: Model, speed: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
		print(string.format("[SpeedTool] %s -> WalkSpeed %d", character:GetFullName(), speed))
	end
end

local function wireTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("SpeedWired") then
		return
	end
	tool:SetAttribute("SpeedWired", true)
	print("[SpeedTool] Tool ketemu & berhasil di-wire: " .. tool:GetFullName())

	-- Unequipped terpicu SETELAH tool.Parent balik ke Backpack -- jadi tidak
	-- bisa dipakai buat cari karakter lagi di titik itu. Simpan karakternya
	-- sendiri di sini (di-set ulang tiap Equipped) supaya Unequipped tetap tahu
	-- siapa yang harus dikembalikan WalkSpeed-nya.
	local lastCharacter: Model? = nil

	tool.Equipped:Connect(function()
		local character = tool.Parent
		if character and character:IsA("Model") then
			lastCharacter = character
			setSpeed(character, FAST_SPEED)
		end
	end)

	tool.Unequipped:Connect(function()
		if lastCharacter then
			setSpeed(lastCharacter, NORMAL_SPEED)
		end
	end)

	-- kalau pas ketemu tool ini sudah kepasang di tangan (equip duluan sebelum
	-- sempat ke-poll), langsung terapkan cepat sekarang juga
	if tool.Parent and tool.Parent:IsA("Model") then
		lastCharacter = tool.Parent :: Model
		setSpeed(lastCharacter, FAST_SPEED)
	end
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local backpack = player:FindFirstChild("Backpack")
			local tool = backpack and backpack:FindFirstChild(TOOL_NAME)
			if not tool then
				local character = player.Character
				tool = character and character:FindFirstChild(TOOL_NAME)
			end
			if tool then
				wireTool(tool)
			end
		end
		task.wait(1)
	end
end)
