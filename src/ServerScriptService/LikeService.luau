--!strict
-- LikeService
-- "Suka" per MANNEQUIN (podium + gender), bukan per baju. Beda dari tombol hati
-- di tiap item -- yang itu Favorite katalog Roblox milik akun pemain, sementara
-- ini milik showroom kita sendiri: hitungan berapa orang menyukai tampilan
-- mannequin tertentu.
--
-- Dua bentuk data, dua alasan berbeda:
--   * jumlah per mannequin -> SATU key berisi semua (seperti override outfit),
--     supaya startup cuma butuh 1x GetAsync, bukan 240x
--   * daftar mannequin yang disukai seorang pemain -> satu key per pemain,
--     supaya tombolnya bisa menampilkan status "sudah kamu suka" saat dia join
--     lagi, dan satu orang tidak bisa menyuka berkali-kali

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LikeService = {}

local SAVE_INTERVAL = 30 -- detik; jumlah like ditulis berkala, bukan tiap klik

local countStoreOk, countStore = pcall(function()
	return DataStoreService:GetDataStore("MannequinLikes_v1")
end)
local userStoreOk, userStore = pcall(function()
	return DataStoreService:GetDataStore("MannequinLikesByUser_v1")
end)

if not countStoreOk or not userStoreOk then
	warn("[Likes] DataStore tidak tersedia -- jumlah suka cuma hidup selama sesi ini. "
		.. "Publish place-nya sekali supaya tersimpan permanen.")
end

local COUNTS_KEY = "Counts"

local counts: { [string]: number } = {}
local liked: { [Player]: { [string]: boolean } } = {}
local countsDirty = false

------------------------------------------------------------------
function LikeService.key(podiumIndex: number, gender: string): string
	return tostring(podiumIndex) .. "_" .. gender
end

local function userKey(userId: number): string
	return "u_" .. tostring(userId)
end

------------------------------------------------------------------
-- Muat
------------------------------------------------------------------
function LikeService.loadCounts()
	if not countStoreOk then
		return
	end
	local ok, saved = pcall(function()
		return (countStore :: any):GetAsync(COUNTS_KEY)
	end)
	if ok and typeof(saved) == "table" then
		for key, value in pairs(saved) do
			if typeof(key) == "string" and typeof(value) == "number" then
				counts[key] = value
			end
		end
	elseif not ok then
		warn("[Likes] Gagal baca jumlah suka: " .. tostring(saved))
	end
end

local function loadUser(player: Player)
	local set: { [string]: boolean } = {}
	if userStoreOk then
		local ok, saved = pcall(function()
			return (userStore :: any):GetAsync(userKey(player.UserId))
		end)
		if ok and typeof(saved) == "table" then
			for key, value in pairs(saved) do
				if typeof(key) == "string" and value == true then
					set[key] = true
				end
			end
		elseif not ok then
			warn("[Likes] Gagal baca daftar suka " .. player.Name .. ": " .. tostring(saved))
		end
	end
	liked[player] = set
end

------------------------------------------------------------------
-- Simpan
------------------------------------------------------------------
-- Jumlah like ditulis BERKALA, bukan tiap klik: satu key dipakai bersama semua
-- pemain, jadi menulis tiap klik gampang kena rate limit DataStore dan saling
-- menimpa. Kehilangan maksimal 30 detik terakhir dinilai jauh lebih murah
-- daripada write yang ditolak.
local function saveCounts()
	if not countStoreOk or not countsDirty then
		return
	end
	countsDirty = false
	local snapshot = table.clone(counts)
	local ok, err = pcall(function()
		(countStore :: any):SetAsync(COUNTS_KEY, snapshot)
	end)
	if not ok then
		warn("[Likes] Gagal simpan jumlah suka: " .. tostring(err))
		countsDirty = true
	end
end

local function saveUser(player: Player)
	if not userStoreOk then
		return
	end
	local set = liked[player]
	if not set then
		return
	end
	local ok, err = pcall(function()
		(userStore :: any):SetAsync(userKey(player.UserId), set)
	end)
	if not ok then
		warn("[Likes] Gagal simpan daftar suka " .. player.Name .. ": " .. tostring(err))
	end
end

------------------------------------------------------------------
-- Baca / ubah
------------------------------------------------------------------
function LikeService.count(key: string): number
	return counts[key] or 0
end

function LikeService.likedBy(player: Player, key: string): boolean
	local set = liked[player]
	return set ~= nil and set[key] == true
end

-- Balikin (jumlahBaru, statusSukaSekarang). Toggle, bukan hanya menambah --
-- jadi tombol yang sama bisa membatalkan suka.
function LikeService.toggle(player: Player, key: string): (number, boolean)
	local set = liked[player]
	if not set then
		-- data pemain belum selesai dimuat; jangan ubah apa pun supaya tidak
		-- tertimpa saat load selesai
		return counts[key] or 0, false
	end

	local now = not set[key]
	set[key] = now or nil
	local current = counts[key] or 0
	counts[key] = math.max(0, current + (now and 1 or -1))
	countsDirty = true
	return counts[key], now
end

-- Reset khusus developer. key = nil berarti SEMUA mannequin.
function LikeService.reset(key: string?): boolean
	if key then
		counts[key] = nil
	else
		counts = {}
	end
	countsDirty = true
	saveCounts()

	-- Daftar "sudah disuka" milik pemain yang sedang online ikut dibersihkan,
	-- kalau tidak tombolnya masih menyala merah padahal hitungannya sudah nol.
	for player, set in pairs(liked) do
		if key then
			set[key] = nil
		else
			liked[player] = {}
		end
		saveUser(player)
	end
	return true
end

------------------------------------------------------------------
-- Siklus hidup
------------------------------------------------------------------
Players.PlayerAdded:Connect(loadUser)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadUser, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveUser(player)
	liked[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		saveCounts()
	end
end)

game:BindToClose(function()
	saveCounts()
	for _, player in ipairs(Players:GetPlayers()) do
		saveUser(player)
	end
end)

return LikeService
