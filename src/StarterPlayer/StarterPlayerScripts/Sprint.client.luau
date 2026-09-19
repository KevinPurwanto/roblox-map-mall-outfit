--!strict
-- Sprint
-- Tahan Shift untuk lari. Pengganti item backpack "Speed Coil" yang lama.
--
-- Dipakai ContextActionService, bukan UserInputService, karena satu binding
-- sekaligus mengurus TIGA platform: keyboard (Shift), gamepad (L3), dan HP --
-- `createTouchButton = true` membuatkan tombol di layar secara otomatis, cuma
-- di perangkat sentuh, tanpa perlu bikin ScreenGui sendiri.
--
-- WalkSpeed sengaja diubah di CLIENT, bukan lewat remote ke server. Pemain
-- punya network ownership atas karakternya sendiri, jadi perubahan ini tetap
-- direplikasi ke server, dan responsnya instan (lewat remote selalu ada jeda
-- ping, terasa lengket untuk aksi yang ditahan-lepas seperti ini). Konsekuensi:
-- exploiter bisa menyetel kecepatan sendiri -- di showroom ini tidak ada yang
-- bisa dicurangi dengan lari cepat, jadi tidak dibayar dengan latensi.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage:WaitForChild("Localization"))

local player = Players.LocalPlayer

local WALK_SPEED = 16
local RUN_SPEED = 48
local ACTION_NAME = "Sprint"

local sprinting = false

local function humanoidOf(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

-- Script ini SATU-SATUNYA yang menulis WalkSpeed. DebugTools (Studio saja) tidak
-- menyetelnya sendiri -- kalau begitu, sekali tekan-lepas Shift akan
-- mengembalikannya ke 16 sementara tombol debug masih menyala "ON". Debug cuma
-- menaikkan kecepatan DASAR lewat attribute ini, dan di sinilah diterapkan.
local function baseSpeed(): number
	local debugBase = player:GetAttribute("DebugBaseSpeed")
	if typeof(debugBase) == "number" and debugBase > 0 then
		return debugBase
	end
	return WALK_SPEED
end

local function apply()
	local humanoid = humanoidOf()
	if humanoid then
		local base = baseSpeed()
		humanoid.WalkSpeed = sprinting and math.max(RUN_SPEED, base) or base
	end
end

local function setSprinting(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	apply()
end

local function onAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
	if state == Enum.UserInputState.Begin then
		-- Panel admin & teleporter punya TextBox. Tanpa penjagaan ini, mengetik
		-- huruf kapital (Shift + huruf) di kolom pencarian katalog akan bikin
		-- karakter ikut lari di belakang layar.
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		setSprinting(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setSprinting(false)
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(
	ACTION_NAME,
	onAction,
	true, -- createTouchButton: tombol lari di HP, otomatis tidak muncul di PC
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL3 -- stik kiri ditekan, konvensi lari di gamepad
)

ContextActionService:SetTitle(ACTION_NAME, Localization.t("sprintButton"))
-- Digeser ke kiri-bawah tombol lompat bawaan supaya jempol kanan tidak rebutan
-- ruang dengan tombol Jump.
ContextActionService:SetPosition(ACTION_NAME, UDim2.new(1, -140, 1, -140))

-- Respawn: Roblox mengembalikan WalkSpeed ke default sendiri, yang perlu
-- di-reset cuma flag kita -- kalau tidak, pemain yang mati sambil menahan Shift
-- akan bangun dalam keadaan "sprinting" tapi jalan pelan, dan tekanan Shift
-- berikutnya malah tidak melakukan apa-apa (state-nya sudah dikira true).
player.CharacterAdded:Connect(function()
	sprinting = false
end)

-- debug menaikkan/menurunkan kecepatan dasar saat karakter sedang berdiri diam:
-- terapkan langsung, jangan tunggu tekanan Shift berikutnya
player:GetAttributeChangedSignal("DebugBaseSpeed"):Connect(apply)
