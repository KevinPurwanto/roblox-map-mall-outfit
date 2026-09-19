--!strict
-- StatsService
-- Statistik permanen per pemain: jumlah pembelian, Robux didonasikan, Robux
-- dibelanjakan. Ditampilkan lewat leaderstats (papan peringkat bawaan Roblox)
-- dan papan donatur di panel donasi.
--
-- DUA store, sengaja beda jenis:
--   * DataStore biasa  -> data lengkap milik satu pemain (dibaca saat join)
--   * OrderedDataStore -> cuma total donasi, karena HANYA OrderedDataStore yang
--     bisa menjawab "siapa 10 donatur terbesar" (GetSortedAsync). DataStore
--     biasa tidak bisa diurutkan sama sekali.
--
-- Catatan penting: di place yang belum pernah di-publish, GetDataStore() melempar
-- error. Semua akses dibungkus pcall dan modul tetap jalan dengan angka di
-- memori saja -- konsisten dengan RoleService dan override outfit.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local StatsService = {}

export type Stats = {
	purchases: number,
	donated: number,
	spent: number,
	receipts: { string }, -- PurchaseId yang sudah diproses, buat tolak duplikat
}

-- ProcessReceipt bisa dipanggil ULANG untuk transaksi yang sama kalau server
-- sempat gagal/restart sebelum sempat menjawab. Tanpa daftar ini, satu donasi
-- bisa terhitung dua kali. Dibatasi supaya data pemain tidak tumbuh selamanya.
local MAX_RECEIPTS = 50

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("PlayerStats_v1")
end)
local boardOk, board = pcall(function()
	return DataStoreService:GetOrderedDataStore("DonatedTotal_v1")
end)

if not storeOk or not boardOk then
	warn("[Stats] DataStore tidak tersedia -- statistik & leaderboard cuma hidup selama sesi ini. "
		.. "Publish place-nya sekali supaya tersimpan permanen.")
end

local cache: { [Player]: Stats } = {}
local dirty: { [Player]: boolean } = {}

local function blank(): Stats
	return { purchases = 0, donated = 0, spent = 0, receipts = {} }
end

------------------------------------------------------------------
-- leaderstats: papan peringkat BAWAAN Roblox (daftar pemain kanan-atas).
--
-- Roblox merender ini sendiri -- cukup sediakan Folder bernama persis
-- "leaderstats" di dalam Player, berisi IntValue per kolom. Nama Value-nya jadi
-- judul kolom, jadi TIDAK bisa ikut Localization: instance-nya satu di server
-- dan dilihat semua pemain sekaligus. Dipakai bahasa Inggris karena itu yang
-- lazim di daftar pemain Roblox.
------------------------------------------------------------------
local COLUMNS = { "Purchases", "Donated", "Spent" }

local function syncLeaderstats(player: Player)
	local stats = cache[player]
	if not stats then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	for _, column in ipairs(COLUMNS) do
		local value = folder:FindFirstChild(column) :: IntValue?
		if not value then
			local created = Instance.new("IntValue")
			created.Name = column
			created.Parent = folder
			value = created
		end
		if column == "Purchases" then
			(value :: IntValue).Value = stats.purchases
		elseif column == "Donated" then
			(value :: IntValue).Value = stats.donated
		else
			(value :: IntValue).Value = stats.spent
		end
	end
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

------------------------------------------------------------------
-- Baca / tulis
------------------------------------------------------------------
function StatsService.load(player: Player)
	local stats = blank()
	if storeOk then
		local ok, saved = pcall(function()
			return (store :: any):GetAsync(keyFor(player.UserId))
		end)
		if ok and typeof(saved) == "table" then
			stats.purchases = tonumber(saved.purchases) or 0
			stats.donated = tonumber(saved.donated) or 0
			stats.spent = tonumber(saved.spent) or 0
			if typeof(saved.receipts) == "table" then
				stats.receipts = saved.receipts
			end
		elseif not ok then
			warn("[Stats] Gagal baca statistik " .. player.Name .. ": " .. tostring(saved))
		end
	end
	cache[player] = stats
	syncLeaderstats(player)
end

function StatsService.get(player: Player): Stats
	return cache[player] or blank()
end

-- Dibedakan dari get(): get() mengembalikan angka nol untuk pemain yang datanya
-- BELUM selesai dimuat, dan itu tidak boleh dipakai sebagai dasar mencatat
-- donasi -- nanti donasinya ditambahkan ke data kosong lalu menimpa data asli.
function StatsService.isLoaded(player: Player): boolean
	return cache[player] ~= nil
end

-- true kalau DataStore memang tidak tersedia sama sekali (place belum pernah
-- di-publish). Pemanggil pakai ini untuk membedakan "tidak bisa disimpan,
-- memang begitu kondisinya" dari "gagal simpan, coba lagi nanti".
function StatsService.persistenceAvailable(): boolean
	return storeOk
end

-- UpdateAsync, bukan SetAsync: kalau pemain sempat join di dua server (berpindah
-- server saat data belum tersimpan), SetAsync akan menimpa dan menghilangkan
-- donasi yang baru saja tercatat di server lain.
function StatsService.save(player: Player): boolean
	local stats = cache[player]
	if not stats then
		return false
	end
	if not storeOk then
		return true -- mode terdegradasi: tidak ada tempat menyimpan, bukan kegagalan
	end
	if not dirty[player] then
		return true
	end
	dirty[player] = nil

	local ok, err = pcall(function()
		(store :: any):UpdateAsync(keyFor(player.UserId), function(old: any)
			local merged = typeof(old) == "table" and old or {}
			merged.purchases = math.max(tonumber(merged.purchases) or 0, stats.purchases)
			merged.donated = math.max(tonumber(merged.donated) or 0, stats.donated)
			merged.spent = math.max(tonumber(merged.spent) or 0, stats.spent)
			merged.receipts = stats.receipts
			return merged
		end)
	end)
	if not ok then
		warn("[Stats] Gagal simpan statistik " .. player.Name .. ": " .. tostring(err))
		dirty[player] = true -- coba lagi di kesempatan berikutnya
		return false
	end
	return true
end

local function publishDonationTotal(player: Player, total: number)
	if not boardOk then
		return
	end
	local ok, err = pcall(function()
		(board :: any):SetAsync(keyFor(player.UserId), total)
	end)
	if not ok then
		warn("[Stats] Gagal update papan donasi: " .. tostring(err))
	end
end

------------------------------------------------------------------
-- Penambahan
------------------------------------------------------------------
function StatsService.addPurchase(player: Player, count: number, robux: number)
	local stats = cache[player]
	if not stats then
		return
	end
	stats.purchases += count
	stats.spent += robux
	dirty[player] = true
	syncLeaderstats(player)
	StatsService.save(player)
end

-- Status, bukan sekadar true/false -- pemanggilnya (ProcessReceipt) harus
-- memutuskan apakah menjawab PurchaseGranted, dan jawaban yang salah di sini
-- berarti Robux pemain hilang tanpa tercatat:
--   "ok"         -> tercatat & tersimpan            -> granted
--   "duplicate"  -> receipt ini sudah pernah masuk   -> granted (jangan dihitung lagi)
--   "not_loaded" -> data pemain belum selesai dimuat -> JANGAN granted, biar diulang
--   "save_failed"-> DataStore menolak                -> JANGAN granted, biar diulang
export type DonationResult = "ok" | "duplicate" | "not_loaded" | "save_failed"

function StatsService.addDonation(player: Player, robux: number, purchaseId: string): DonationResult
	local stats = cache[player]
	if not stats then
		return "not_loaded"
	end
	for _, seen in ipairs(stats.receipts) do
		if seen == purchaseId then
			return "duplicate"
		end
	end

	table.insert(stats.receipts, purchaseId)
	while #stats.receipts > MAX_RECEIPTS do
		table.remove(stats.receipts, 1)
	end
	stats.donated += robux
	dirty[player] = true

	if not StatsService.save(player) then
		-- kembalikan ke keadaan semula supaya percobaan ulang nanti tidak
		-- terbaca sebagai duplikat lalu hilang diam-diam
		stats.donated -= robux
		for i = #stats.receipts, 1, -1 do
			if stats.receipts[i] == purchaseId then
				table.remove(stats.receipts, i)
				break
			end
		end
		return "save_failed"
	end

	syncLeaderstats(player)
	publishDonationTotal(player, stats.donated)
	return "ok"
end

------------------------------------------------------------------
-- Papan donatur global
------------------------------------------------------------------
export type BoardEntry = { userId: number, name: string, donated: number }

local boardCache: { BoardEntry } = {}
local boardFetchedAt = 0
local BOARD_TTL = 60 -- detik; GetSortedAsync kena rate limit kalau dipanggil tiap klik

-- Nama pemain tidak disimpan di OrderedDataStore (nilainya cuma boleh angka),
-- jadi diambil dari userId. GetNameFromUserIdAsync itu panggilan web, makanya
-- hasilnya di-cache selamanya -- nama Roblox jarang berubah.
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = (ok and typeof(name) == "string") and name or ("User " .. userId)
	nameCache[userId] = resolved
	return resolved
end

function StatsService.topDonors(limit: number): { BoardEntry }
	if not boardOk then
		return {}
	end
	if os.clock() - boardFetchedAt < BOARD_TTL and #boardCache > 0 then
		return boardCache
	end

	local ok, pages = pcall(function()
		return (board :: any):GetSortedAsync(false, math.clamp(limit, 1, 100))
	end)
	if not ok then
		warn("[Stats] Gagal baca papan donasi: " .. tostring(pages))
		return boardCache
	end

	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or typeof(page) ~= "table" then
		return boardCache
	end

	local entries: { BoardEntry } = {}
	for _, row in ipairs(page :: { any }) do
		-- key-nya "u_<userId>", angkanya dikupas balik di sini
		local userId = tonumber(tostring(row.key):match("%d+"))
		local value = tonumber(row.value) or 0
		if userId and value > 0 then
			table.insert(entries, { userId = userId, name = nameFor(userId), donated = value })
		end
	end

	boardCache = entries
	boardFetchedAt = os.clock()
	return entries
end

------------------------------------------------------------------
-- Siklus hidup
------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	StatsService.load(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(StatsService.load, player)
end

Players.PlayerRemoving:Connect(function(player)
	StatsService.save(player)
	cache[player] = nil
	dirty[player] = nil
end)

-- Tanpa ini, donasi beberapa detik terakhir sebelum server ditutup bisa hilang:
-- Roblox memberi waktu tunggu di BindToClose khusus untuk penyimpanan terakhir.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		StatsService.save(player)
	end
end)

return StatsService
