--!strict
-- MannequinFocus
-- Mannequin terdekat terangkat sedikit + diberi outline saat pemain mendekat.
-- Murni client-side: tiap pemain punya fokusnya sendiri, tidak ada replikasi.
--
-- Sengaja BUKAN MouseHoverEnter/MouseEnter -- di HP tidak ada kursor, event itu
-- tidak akan pernah menyala. Deteksinya jarak (magnitude ke HumanoidRootPart).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

local MANNEQUIN_TAG = "Mannequin" -- dipasang server di Showroom.server.luau

local RADIUS = 8 -- stud; radius aktivasi (kecil, supaya di HP tidak mudah tersenggol)
local LIFT = 1.5 -- stud; tinggi angkat awal
local HYSTERESIS = 2 -- stud; keunggulan untuk mannequin yang sedang aktif
local TWEEN_TIME = 0.6
local TWEEN_INFO = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Setelah selesai terangkat, mannequin melayang naik-turun terus. Dua fase
-- terpisah karena easing-nya memang beda maksudnya: Quad/Out untuk "terangkat"
-- (cepat lalu melambat, terasa seperti terkena daya angkat), Sine/InOut untuk
-- "melayang" (mulus di kedua ujung, tidak ada titik berhenti yang kentara).
--
-- Reverses = true + RepeatCount = -1 membuat satu tween bolak-balik selamanya,
-- jadi tidak perlu loop RunService sendiri untuk ini.
local BOB = 0.35 -- stud; jarak naik-turun dari titik mengambang
local BOB_INFO = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local OUTLINE_COLOR = Color3.fromRGB(255, 158, 203) -- pink aksen showroom

-- Scan jarak dijalankan ~30x/detik, bukan tiap frame. Map ini punya 240
-- mannequin dan StreamingEnabled tidak banyak memangkasnya (map cuma 421x331
-- stud, muat dalam radius streaming), jadi tiap scan = ~240 perhitungan
-- magnitude. Di 30Hz bebannya separuh, dan untuk tween 0.6 detik selisih
-- 33 ms tidak terasa sama sekali.
local SCAN_INTERVAL = 1 / 30

------------------------------------------------------------------
-- Highlight: SATU instance dipakai bergantian, bukan satu per mannequin.
--
-- Roblox cuma merender sejumlah kecil Highlight sekaligus (batasnya puluhan);
-- 240 mannequin x 1 Highlight sudah lewat batas itu, dan sisanya diam-diam
-- tidak dirender. Toh cuma satu mannequin yang aktif pada satu waktu, jadi
-- satu Highlight sudah cukup -- yang berpindah cuma Adornee-nya.
--
-- Parent-nya Camera, BUKAN mannequin-nya: kalau ditempel ke model, Highlight
-- ikut terhapus saat mannequin itu streaming-out.
------------------------------------------------------------------
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1 -- mulai tidak terlihat
highlight.OutlineColor = OUTLINE_COLOR
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Adornee = nil
highlight.Parent = workspace.CurrentCamera

local outlineTween: Tween? = nil

------------------------------------------------------------------
-- State
------------------------------------------------------------------
type Record = {
	root: BasePart,
	base: CFrame, -- pivot ASLI, disimpan sekali saat registrasi
	active: boolean,
	lift: NumberValue?, -- dibuat saat pertama kali difokuskan, bukan saat registrasi
	tween: Tween?, -- fase naik / turun (sekali jalan)
	bob: Tween?, -- fase melayang (berulang selamanya)
	conn: RBXScriptConnection?,
}

local tracked: { [Model]: Record } = {}
local activeModel: Model? = nil

------------------------------------------------------------------
-- Registrasi
------------------------------------------------------------------
-- BUG YANG PERNAH TERJADI: dulu di sini dipakai FindFirstChild("HumanoidRootPart")
-- dan langsung `return` kalau belum ada. Tag CollectionService bisa sampai ke
-- client SEBELUM anak-anak model ikut direplikasi, jadi sebagian mannequin
-- ditolak di sini dan -- karena GetInstanceAddedSignal tidak akan menyala dua
-- kali untuk instance yang sama -- TIDAK PERNAH terdaftar sepanjang sesi itu.
-- Gejalanya acak: beberapa mannequin diam saja saat didekati, tanpa error.
-- Makanya sekarang ditunggu pakai WaitForChild di thread terpisah.
local pending: { [Model]: boolean } = {}

local function register(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	if tracked[model] or pending[model] then
		return
	end
	pending[model] = true

	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		pending[model] = nil
		-- bisa saja sudah streaming-out lagi atau keburu terdaftar lewat jalur lain
		if not root or not model.Parent or tracked[model] then
			return
		end

		tracked[model] = {
			root = root,
			-- disimpan SEKALI. Kalau dibaca ulang saat mannequin sedang terangkat,
			-- posisinya akan naik terus tiap kali fokus berpindah.
			base = model:GetPivot(),
			active = false,
			lift = nil,
			tween = nil,
			bob = nil,
			conn = nil,
		}
	end)
end

local function unregister(inst: Instance)
	local model = inst :: Model
	local record = tracked[model]
	if not record then
		return
	end
	if activeModel == model then
		activeModel = nil
		highlight.Adornee = nil
	end
	if record.tween then
		record.tween:Cancel()
	end
	if record.bob then
		record.bob:Cancel()
	end
	if record.conn then
		record.conn:Disconnect()
	end
	if record.lift then
		record.lift:Destroy()
	end
	tracked[model] = nil
end

------------------------------------------------------------------
-- Perubahan state
------------------------------------------------------------------
local function setState(model: Model, record: Record, on: boolean)
	if record.active == on then
		return -- guard: jangan bikin tween baru untuk state yang sudah benar
	end
	record.active = on

	if record.tween then
		record.tween:Cancel()
	end
	-- Tween melayang HARUS dihentikan lebih dulu. Kalau tidak, ia terus menarik
	-- NumberValue yang sama dan berebut dengan tween turun -- mannequin akan
	-- tersangkut di udara sambil bergetar.
	if record.bob then
		record.bob:Cancel()
		record.bob = nil
	end

	-- Mannequin di proyek ini di-anchor SELURUHNYA (aturan "mannequin adalah
	-- patung" di CLAUDE.md), jadi men-tween HumanoidRootPart saja tidak akan
	-- menyeret badannya -- Motor6D tidak berlaku untuk part yang di-anchor.
	-- Lagi pula OutfitPromptAnchor (tempat ProximityPrompt "E") cuma di-CFrame
	-- sekali dan tidak di-weld, jadi ia akan tertinggal di bawah.
	-- Solusinya: seluruh model digeser lewat PivotTo, dan yang di-tween adalah
	-- angka tinggi angkatnya -- easing Quad/Out tetap dapat, semua part ikut.
	--
	-- NumberValue-nya dibuat saat mannequin ini PERTAMA kali difokuskan, bukan
	-- saat registrasi, supaya 240 mannequin tidak langsung berarti 240
	-- NumberValue + 240 koneksi padahal kebanyakan tidak pernah didekati.
	local lift = record.lift
	if not lift then
		lift = Instance.new("NumberValue")
		lift.Value = 0
		local base = record.base
		record.conn = lift.Changed:Connect(function(value: number)
			-- Translasi ditaruh di KIRI supaya naiknya mengikuti sumbu Y dunia,
			-- bukan sumbu atas milik mannequin. Mannequin di map ini menghadap
			-- berbagai arah; kalau ada satu saja yang miring, `base * offset`
			-- akan membuatnya melayang menyamping.
			model:PivotTo(CFrame.new(0, value, 0) * base)
		end)
		record.lift = lift
	end

	local liftValue = lift :: NumberValue
	local tween = TweenService:Create(liftValue, TWEEN_INFO, { Value = on and LIFT or 0 })
	record.tween = tween

	if on then
		-- Melayang baru dimulai SETELAH naiknya selesai, bukan berbarengan --
		-- dua tween pada properti yang sama akan saling menimpa.
		tween.Completed:Connect(function(state: Enum.PlaybackState)
			if state ~= Enum.PlaybackState.Completed then
				return -- dibatalkan karena pemain keburu menjauh
			end
			if not record.active or record.bob then
				return
			end
			local bob = TweenService:Create(liftValue, BOB_INFO, { Value = LIFT + BOB })
			record.bob = bob
			bob:Play()
		end)
	end

	tween:Play()

	if on then
		-- Highlight dipindah langsung ke pemenang baru (tidak ada crossfade --
		-- cuma ada satu Highlight), lalu outline-nya di-fade in.
		highlight.Adornee = model
		if outlineTween then
			outlineTween:Cancel()
		end
		highlight.OutlineTransparency = 1
		outlineTween = TweenService:Create(highlight, TWEEN_INFO, { OutlineTransparency = 0 })
		;(outlineTween :: Tween):Play()
	elseif highlight.Adornee == model then
		if outlineTween then
			outlineTween:Cancel()
		end
		outlineTween = TweenService:Create(highlight, TWEEN_INFO, { OutlineTransparency = 1 })
		;(outlineTween :: Tween):Play()
	end
end

-- dipakai saat karakter hilang (respawn): turunkan yang sedang terangkat,
-- jangan tinggalkan mannequin menggantung di udara
local function clearActive()
	if activeModel then
		local record = tracked[activeModel]
		if record then
			setState(activeModel, record, false)
		end
		activeModel = nil
	end
end

------------------------------------------------------------------
-- Loop utama
--
-- Fase 1 murni MEMBACA, fase 2 murni MENULIS. Selama pemain diam di depan satu
-- mannequin, tidak ada tween baru yang dibuat sama sekali.
------------------------------------------------------------------
local accumulator = 0

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	if accumulator < SCAN_INTERVAL then
		return
	end
	accumulator = 0

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		clearActive() -- respawn / belum load
		return
	end
	local origin = hrp.Position

	-- FASE 1: cari pemenang, jangan ubah apa pun dulu
	local closest: Model? = nil
	local closestDist = RADIUS

	for model, record in pairs(tracked) do
		if not record.root.Parent then
			unregister(model) -- aman: menghapus key saat pairs dibolehkan di Lua
			continue
		end

		local dist = (record.root.Position - origin).Magnitude

		-- hysteresis: yang sedang aktif dapat keunggulan, supaya fokus tidak
		-- bolak-balik saat dua mannequin berjarak nyaris sama -- di podium ini
		-- cowok & cewek memang berdiri berdampingan
		if model == activeModel then
			dist -= HYSTERESIS
		end

		if dist < closestDist then
			closest = model
			closestDist = dist
		end
	end

	-- FASE 2: terapkan HANYA kalau pemenang berganti
	if closest ~= activeModel then
		if activeModel then
			local previous = tracked[activeModel]
			if previous then
				setState(activeModel, previous, false)
			end
		end
		if closest then
			local record = tracked[closest]
			if record then
				setState(closest, record, true)
			end
		end
		activeModel = closest
	end
end)

------------------------------------------------------------------
-- Registrasi lewat CollectionService -- jangan hardcode nama model seperti
-- "Mannequin_F_001". Dengan StreamingEnabled, mannequin yang jauh bisa
-- dihapus/ditambah client kapan saja, dan dua signal ini yang menanganinya.
------------------------------------------------------------------
for _, inst in ipairs(CollectionService:GetTagged(MANNEQUIN_TAG)) do
	register(inst)
end
CollectionService:GetInstanceAddedSignal(MANNEQUIN_TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(MANNEQUIN_TAG):Connect(unregister)
