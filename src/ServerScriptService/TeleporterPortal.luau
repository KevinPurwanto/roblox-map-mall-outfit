--!strict
-- TeleporterPortal
-- Membangun portal teleporter berbentuk lingkaran dari Part biasa.
--
-- Dibuat sebagai MODUL (bukan langsung di Teleporter.server.luau) supaya bisa
-- dipratinjau di Edit mode tanpa Play: dari Command Bar / Studio MCP cukup
-- `require(<clone modul ini>).build(...)`. Portalnya sendiri tetap dibuat ulang
-- oleh server tiap game jalan, jadi desainnya hidup di repo (masuk git), bukan
-- di file place.
--
-- Tidak memakai asset ID apa pun (mesh/gambar): semua dari Part + material
-- bawaan Roblox. Efek "bergerak" datang dari material ForceField (beranimasi
-- sendiri), partikel, dan cahaya yang dibuat berdenyut di client.

local TeleporterPortal = {}

-- Ukuran (stud)
local RING_RADIUS = 5.4 -- jari-jari garis tengah bingkai (dekor map ini besar-besar; 4.3 terlihat mungil)
local RING_THICK = 1.3 -- tebal bingkai (arah radial)
local RING_DEPTH = 1.4 -- tebal bingkai (arah depan-belakang)
local RIM_RADIUS = 4.6 -- lingkar dalam yang menyala
local RIM_THICK = 0.35
local RIM_DEPTH = 1.6 -- sedikit menonjol dari bingkai supaya kelihatan dari samping
local DISC_RADIUS = 4.5 -- permukaan portal
local SEGMENTS = 32 -- makin banyak makin bulat; 32 sudah mulus dari jarak pemain
local BASE_LOW = { radius = 6.8, height = 0.6 }
local BASE_HIGH = { radius = 5.9, height = 0.5 }

-- Warna: tetap keluarga pink/ungu mall, tapi JAUH lebih pekat dari dinding &
-- lantainya. Versi pertama memakai pastel muda dan portalnya tenggelam di depan
-- kerucut pink raksasa di belakangnya (dicek lewat screenshot Studio).
local FRAME_COLOR = Color3.fromRGB(255, 244, 250)
local FRAME_ACCENT = Color3.fromRGB(255, 150, 200)
local RIM_COLOR = Color3.fromRGB(255, 70, 160)
local SURFACE_COLOR = Color3.fromRGB(150, 70, 235)
local GLOW_COLOR = Color3.fromRGB(255, 100, 190)
local CORE_COLOR = Color3.fromRGB(70, 30, 120) -- inti gelap di balik portal
local BASE_LOW_COLOR = Color3.fromRGB(232, 220, 255)
local BASE_HIGH_COLOR = Color3.fromRGB(255, 206, 228)

local function part(props: { [string]: any }, parent: Instance): BasePart
	local shape = props.Shape
	local p: BasePart = Instance.new("Part")
	if shape then
		(p :: Part).Shape = shape
	end
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.CanTouch = props.CanTouch == true
	p.CanQuery = props.CanQuery == true
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Transparency = props.Transparency or 0
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Name = props.Name or "Part"
	p.Parent = parent
	return p
end

-- Cincin dari SEGMENTS balok yang diputar mengelilingi pusat. Roblox tidak punya
-- primitif torus, dan memakai mesh berarti butuh asset ID.
-- Di ruang lokal `frame`: cincin terletak di bidang XY lokal, menghadap -Z lokal.
local function ring(model: Model, frame: CFrame, radius: number, thick: number, depth: number,
	material: Enum.Material, colorFor: (number) -> Color3, collide: boolean, name: string)
	local segLen = (2 * math.pi * radius / SEGMENTS) * 1.12 -- sedikit bertumpuk: tidak ada celah
	for i = 0, SEGMENTS - 1 do
		local angle = (i / SEGMENTS) * 2 * math.pi
		-- setelah diputar `angle` lalu digeser R ke X lokal: sumbu X = radial,
		-- sumbu Y = arah garis singgung -> panjang balok ditaruh di Y
		local cf = frame * CFrame.Angles(0, 0, angle) * CFrame.new(radius, 0, 0)
		part({
			Name = name,
			Size = Vector3.new(thick, segLen, depth),
			CFrame = cf,
			Material = material,
			Color = colorFor(i),
			CanCollide = collide,
			CastShadow = false,
		}, model)
	end
end

--[[
	Bangun portal.
	  basePosition : titik di LANTAI tempat pusat alas portal berdiri
	  facing       : arah yang dihadap portal (ke mana pemain datang)
	Mengembalikan Model bernama "TeleporterKiosk" berisi:
	  PortalTrigger    -- part tak terlihat di bidang portal; disentuh = buka panel
	  PromptAnchor     -- tempat ProximityPrompt "TeleporterPrompt"
	  PortalSurface    -- berisi PointLight "PortalGlow" (didenyutkan client)
]]
function TeleporterPortal.build(basePosition: Vector3, facing: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "TeleporterKiosk"

	local flatFacing = Vector3.new(facing.X, 0, facing.Z).Unit
	local groundCF = CFrame.lookAt(basePosition, basePosition + flatFacing)

	------------------------------------------------------------------
	-- Alas dua tingkat. Cylinder Roblox bersumbu X, jadi diputar 90 derajat
	-- di Z supaya berdiri tegak.
	------------------------------------------------------------------
	local upright = CFrame.Angles(0, 0, math.rad(90))
	part({
		Name = "BaseLow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(BASE_LOW.height, BASE_LOW.radius * 2, BASE_LOW.radius * 2),
		CFrame = groundCF * CFrame.new(0, BASE_LOW.height / 2, 0) * upright,
		Color = BASE_LOW_COLOR,
	}, model)
	-- garis menyala di tepi alas: memberi batas yang jelas dari lantai pink
	part({
		Name = "BaseGlowLine",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, BASE_LOW.radius * 2 + 0.3, BASE_LOW.radius * 2 + 0.3),
		CFrame = groundCF * CFrame.new(0, 0.06, 0) * upright,
		Material = Enum.Material.Neon,
		Color = RIM_COLOR,
		CanCollide = false,
		CastShadow = false,
	}, model)
	part({
		Name = "BaseHigh",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(BASE_HIGH.height, BASE_HIGH.radius * 2, BASE_HIGH.radius * 2),
		CFrame = groundCF * CFrame.new(0, BASE_LOW.height + BASE_HIGH.height / 2, 0) * upright,
		Color = BASE_HIGH_COLOR,
	}, model)

	local baseTop = BASE_LOW.height + BASE_HIGH.height

	------------------------------------------------------------------
	-- Pusat cincin diletakkan supaya BAGIAN BAWAH LUBANG portal rata dengan
	-- puncak alas -- pemain bisa berjalan masuk tanpa melompat. Sisi bawah
	-- bingkai jadi terbenam di alas (tidak terlihat), itu disengaja.
	------------------------------------------------------------------
	local center = groundCF * CFrame.new(0, baseTop + RIM_RADIUS - 0.1, 0)

	ring(model, center, RING_RADIUS, RING_THICK, RING_DEPTH, Enum.Material.SmoothPlastic, function(i)
		-- belang pink-putih tiap 2 segmen, seperti permen: terbaca jelas dari jauh
		return (i // 2) % 2 == 0 and FRAME_ACCENT or FRAME_COLOR
	end, true, "Frame")

	ring(model, center, RIM_RADIUS, RIM_THICK, RIM_DEPTH, Enum.Material.Neon, function()
		return RIM_COLOR
	end, false, "Rim")

	------------------------------------------------------------------
	-- Permukaan portal. Cylinder bersumbu X -> diputar 90 derajat di Y supaya
	-- sumbunya searah hadap portal (permukaannya menghadap pemain).
	------------------------------------------------------------------
	local faceOn = CFrame.Angles(0, math.rad(90), 0)
	local surface = part({
		Name = "PortalSurface",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, DISC_RADIUS * 2, DISC_RADIUS * 2),
		CFrame = center * faceOn,
		Material = Enum.Material.ForceField, -- beranimasi sendiri, tanpa asset
		Color = SURFACE_COLOR,
		CanCollide = false,
		CastShadow = false,
	}, model)
	part({
		Name = "PortalFill",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, DISC_RADIUS * 2 - 0.2, DISC_RADIUS * 2 - 0.2),
		CFrame = center * faceOn,
		Material = Enum.Material.Neon,
		Color = GLOW_COLOR,
		Transparency = 0.7, -- cukup tembus supaya cincin pusaran & inti gelap di belakangnya terlihat
		CanCollide = false,
		CastShadow = false,
	}, model)

	------------------------------------------------------------------
	-- Kedalaman. Tanpa ini, isi portal cuma piringan pink rata -- terlihat
	-- seperti cermin, bukan lorong ke tempat lain (dicek lewat screenshot).
	-- Lapisannya dari depan ke belakang (+Z lokal = ke belakang):
	--   permukaan ForceField + isian neon tembus pandang (z = 0)
	--   cincin neon tipis yang makin kecil & makin mundur (z = 0.15 .. 0.45)
	--   inti ungu gelap (z = 0.6) -- latar gelap bikin semua yang menyala di
	--   depannya "terbakar" lebih terang
	------------------------------------------------------------------
	part({
		Name = "PortalCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, DISC_RADIUS * 2, DISC_RADIUS * 2),
		CFrame = center * CFrame.new(0, 0, 0.6) * faceOn,
		Color = CORE_COLOR,
		CanCollide = false,
		CastShadow = false,
	}, model)
	for k, r in ipairs({ DISC_RADIUS * 0.78, DISC_RADIUS * 0.55, DISC_RADIUS * 0.32 }) do
		ring(model, center * CFrame.new(0, 0, 0.15 * k), r, 0.14, 0.05, Enum.Material.Neon, function()
			return k % 2 == 1 and GLOW_COLOR or SURFACE_COLOR
		end, false, "Vortex")
	end

	local light = Instance.new("PointLight")
	light.Name = "PortalGlow"
	light.Color = GLOW_COLOR
	light.Range = 12
	light.Brightness = 1.1 -- 2 membuat lantai sekitar putih silau (bloom lighting Future)
	light.Shadows = false
	light.Parent = surface

	------------------------------------------------------------------
	-- Kerlip yang keluar dari portal ke arah pemain. Sumbernya part tak
	-- terlihat seukuran lubang; EmissionDirection Front = -Z lokal = arah hadap.
	-- Tekstur dibiarkan bawaan (sparkle), tidak butuh asset ID.
	------------------------------------------------------------------
	local emitterSource = part({
		Name = "SparkleSource",
		Size = Vector3.new(DISC_RADIUS * 1.6, DISC_RADIUS * 1.6, 0.2),
		CFrame = center,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	}, model)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.EmissionDirection = Enum.NormalId.Front
	sparkles.Rate = 28
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Speed = NumberRange.new(1.2, 2.6)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.Drag = 0.8
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Color = ColorSequence.new(GLOW_COLOR, SURFACE_COLOR)
	sparkles.Parent = emitterSource

	------------------------------------------------------------------
	-- Permata di puncak + tulisan
	------------------------------------------------------------------
	local gem = part({
		Name = "TopGem",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = center * CFrame.new(0, RING_RADIUS + RING_THICK / 2 + 0.45, 0),
		Material = Enum.Material.Neon,
		Color = RIM_COLOR,
		CanCollide = false,
	}, model)

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.new(0, 220, 0, 46)
	sign.StudsOffset = Vector3.new(0, 1.6, 0)
	sign.MaxDistance = 90
	sign.LightInfluence = 0
	sign.Parent = gem
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	-- "Teleport" sama di bahasa Indonesia & Inggris -- BillboardGui dibuat di
	-- server dan dilihat semua pemain, jadi tidak bisa ikut Localization
	text.Text = "✨ TELEPORT ✨"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(214, 92, 150)
	text.Parent = sign
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = text

	------------------------------------------------------------------
	-- Interaksi
	------------------------------------------------------------------
	-- Disentuh = buka panel (ditangani TeleporterClient). Lebih kecil dari
	-- lubang supaya menyenggol bingkai dari samping tidak ikut membuka panel.
	part({
		Name = "PortalTrigger",
		Size = Vector3.new(DISC_RADIUS * 1.5, DISC_RADIUS * 1.6, 1.6),
		CFrame = center,
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
	}, model)

	local anchor = part({
		Name = "PromptAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = center,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	}, model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeleporterPrompt" -- TeleporterClient mencari prompt lewat nama ini
	prompt.ActionText = "Teleport"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	model.PrimaryPart = anchor
	return model
end

return TeleporterPortal
