# Hello Kitty Mall — konteks proyek

Showroom avatar bertema Hello Kitty di Roblox. Pemain berkeliling mall, melihat
mannequin memakai outfit, mencobanya, lalu membelinya. Admin bisa mengganti
outfit mannequin saat game berjalan.

## Cara kerja repo ini

Geometri map **tidak** ada di repo. Yang ada di sini hanya script.

- `map_backup.rbxl` — place file, diedit manual di Roblox Studio
- `src/` — script yang di-sync Rojo ke Studio
- `tools/` — script sekali-jalan, ditempel manual ke Command Bar Studio

Alur kerja: buka `.rbxl` di Studio → `rojo serve` → klik Connect di plugin Rojo.

**Jangan pernah memetakan `Workspace` di `default.project.json`.** Map berisi
13.630 instance yang tidak ada padanannya di disk; kalau Workspace ikut dipetakan,
Rojo akan menghapusnya saat sync.

## Environment & tooling (status per 2026-08-31)

Toolchain sudah pernah disiapkan lengkap di satu komputer (Windows). Kalau kerja
dari komputer/session lain, ini yang perlu diulang — jangan asumsikan sudah ada:

- **Rokit** (toolchain manager resmi Rojo) — install via `winget install Rojo.Rokit`,
  lalu `rokit self-install`, lalu `rokit install` di folder ini. Ini menarik versi
  yang di-pin di `rokit.toml`: Rojo 7.7.0, StyLua 2.0.2, Selene 0.27.1. Rokit taruh
  binary di `~/.rokit/bin` — perlu shell/terminal baru supaya PATH kebaca.
  Tools dari author baru (`rojo-rbx`, `JohnnyMorganz`, `Kampfkarren`) butuh
  `rokit trust <author>` dulu sebelum `rokit install` jalan.
- **VS Code**: extension `evaera.vscode-rojo` (Rojo) dan `johnnymorganz.luau-lsp`
  (Luau LSP) — install via `code --install-extension <id>`.
- **Roblox Studio**: plugin resmi **Rojo** (ikon "R" merah, publisher Rojo/rojo-rbx,
  FREE, auto-update dari Creator Store — per 2026-08-31 versi terpasang 7.7.0).
  **Plugin dan CLI harus versi sama persis** — sudah terbukti TIDAK selalu kompatibel
  kalau beda (7.7.0 plugin vs 7.4.4 CLI gagal connect dengan error dari dalam kode
  plugin sendiri: `attempt to index number with 'protocolVersion'` di
  `ApiContext:28`, bukan pesan error yang jelas). Kalau plugin auto-update lagi,
  cek versinya (buka panel plugin Rojo di Studio) dan samakan pin di `rokit.toml`,
  lalu `rokit install` ulang.
  **Awas plugin niru nama di Creator Store**: hasil pencarian "Rojo" penuh
  lookalike (Rojo Boatly, RojoSessionUnlocker, Rojo 反苦鸟, Rojo Pro+, Rojo Plus,
  private_rojo_bidirectional, "Rojo For Eleons", dll) — itu **bukan** plugin resmi,
  jangan install.
- **Urutan connect yang benar**: jalankan `rojo serve` di terminal folder ini
  DULU (sampai muncul "listening on port 34872"), baru klik **Connect** di panel
  plugin Studio. Kalau belum ada `rojo serve` yang jalan, tombol Connect gagal
  diam-diam karena tidak ada apa pun di port 34872.
  **Verifikasi SEBELUM Play**: expand `ServerScriptService` di Explorer (masih
  dalam Edit mode) — harus ada isinya (`Showroom`, `RoleService`, dst). Kalau
  masuk Play saat Rojo belum benar-benar connected, Rojo bisa gagal reconnect
  dengan error HTTP dari konteks Client ("Http requests can only be executed by
  game server"), dan seisi ServerScriptService/ReplicatedStorage/StarterPlayer
  jadi kosong sepanjang sesi Play itu tanpa pesan error yang mencolok.
- **Repo GitHub**: `https://github.com/KevinPurwanto/roblox-map-mall-outfit`,
  branch `main`. Root git = folder `hello-kitty-mall/` ini sendiri (BUKAN folder
  induk `Maps baju Vicky/`, yang juga berisi `map_backup.rbxl` lepas di luar repo).
  `.gitignore` sudah meng-exclude `*.rbxl` — place file sengaja tidak masuk repo,
  konsisten dengan aturan "geometri map tidak ada di repo" di atas.
- **Dua file `.rbxl` beredar, belum ada keputusan final**: `test1.rbxl` (di dalam
  folder ini, ini yang sejauh ini dibuka & disambungkan ke Rojo di Studio) vs
  `map_backup.rbxl` (satu folder di atas `hello-kitty-mall/`, backup lebih lama).
  Isinya beda (hash file beda, bukan salinan satu sama lain). Sampai ada
  konfirmasi lebih lanjut, anggap `test1.rbxl` yang aktif dipakai.

## Fakta map (hasil parsing `map_backup.rbxl`)

- Ukuran terbangun ±421 × 331 studs, di kuadran X negatif / Z negatif
- 13.630 instance, 105 class. Awalnya **tidak ada script sama sekali** — murni build
- 3D text di map bertuliskan "Build by Lallaquell" (aset orang lain)
- `StreamingEnabled = true`, lighting Future
- `SpawnLocation` di (-112, 6, -203)

### Grup penting di Workspace

| Nama | Isi |
|---|---|
| `AvatarPodium` | **120 Model + 1 MeshPart** — podium display |
| `DecorPack` | 10 model unit toko |
| `Dinding` | 17 model dinding/pilar |
| `BaseJalan` | jalur pejalan kaki |
| `Mannequins` | **dibuat oleh script**, bukan bawaan map |

### Ukuran podium

- Permukaan atas seragam di **Y = 4.09** (berlaku untuk semua 120 model)
- Footprint median **4,33 × 8,33 studs**; sisi panjang dipakai untuk menjajarkan
  sepasang mannequin

### Rig template

> **Status terbaru (dicek lewat Studio MCP, 2026-10-14):** template di place
> yang aktif sekarang adalah **`RigMale` dan `RigFemale`, keduanya R15** dengan
> **dynamic head** (Head = MeshPart, wajah = `TextureID` + `FaceControls`,
> bukan Decal). 240 mannequin di `workspace.Mannequins` juga sudah R15. Bagian
> di bawah tentang rig R6 adalah keadaan awal map, dipertahankan sebagai
> referensi.

Keadaan awal: dua Model bernama `Rig` di Workspace, keduanya **R6**, tinggi 5 studs,
lebar bahu 4 studs (torso 2 + lengan 1+1).

- **Cowok** — rig polos, tanpa `CharacterMesh`
- **Cewek** — punya 5 `CharacterMesh` paket Woman + accessory "Kate Hair"

Itu isi *template*-nya. Mannequin hasil `tools/place_mannequins.luau` sengaja
dibuat polos: wajah dan semua Accessory bawaan dibuang (`STRIP_FACE`,
`STRIP_HAIR`). Wajah ada **dua bentuk** dan keduanya ditangani: Decal di Head
(kepala klasik) **dan** `Head.TextureID` + `FaceControls` (dynamic head R15).
Versi awal tool cuma membuang Decal — di dynamic head itu tidak menghapus apa
pun, dan cek "berapa mannequin masih punya Decal wajah" menjawab **0** padahal
wajahnya masih jelas terlihat. Jangan pakai jumlah Decal sebagai bukti wajah
sudah hilang; cek `Head.TextureID`.

MeshId paket Woman, kalau perlu membuat rig cewek baru dari rig cowok:

| BodyPart | MeshId |
|---|---|
| Torso | 82987757 |
| LeftArm | 83001137 |
| RightArm | 83001181 |
| LeftLeg | 746826007 |
| RightLeg | 746825633 |

#### Pindah ke R15 (SUDAH dilakukan -- template sekarang RigMale/RigFemale R15)

Kode server **tidak** terikat R6 — yang dipakai cuma `Head` dan
`HumanoidRootPart`, dua-duanya ada di R6 dan R15. Shirt/Pants/Accessory classic
juga jalan di kedua rig. Penempatan di `place_mannequins.luau` mengukur bounding
box rig secara dinamis (`AUTO_SPACING`, `footY`), jadi beda tinggi/lebar R15
tertangani sendiri.

Yang perlu dilakukan manual di Studio:

1. **Game Settings → Avatar → Avatar Type = R15** (ini untuk karakter pemain,
   memengaruhi Coba-Baju dan `ApplyDescription`)
2. Ganti dua template `Rig` di Workspace dengan rig R15 (tab **Avatar → Rig
   Builder → R15**), lalu jalankan ulang `tools/place_mannequins.luau`

`CharacterMesh` **tidak ada di R15** (badan sudah MeshPart), jadi deteksi rig
cewek lama yang mengandalkan class itu akan gagal — sekarang `looksFemale()`
mengecek attribute `Gender` ("M"/"F") dulu, lalu nama rig (mengandung
"female"/"cewek"/"woman"/"girl"/dll), baru `CharacterMesh` sebagai jalur R6.
Script juga mencetak `RigType` kedua template dan memperingatkan kalau tercampur
R6+R15 (gejalanya diam-diam: mannequin cowok & cewek beda tinggi).

Konsekuensi yang perlu ditimbang: R15 = 15 BasePart + 15 Motor6D per rig (R6:
6+6), jadi 240 mannequin bertambah sekitar **+4.000 instance** di atas ~19.000
yang sudah ada — lihat bagian "Beban instance". Imbalannya, **Layered Clothing
cuma jalan di R15**, dan sebagian besar katalog UGC modern berupa layered —
di R6 barang-barang itu tidak bisa dipajang sama sekali.

## Konvensi

Setiap mannequin di `workspace.Mannequins` punya attribute:

| Attribute | Tipe | Keterangan |
|---|---|---|
| `PodiumIndex` | number | 1..120, kunci ke `MannequinCatalog` |
| `Gender` | string | `"M"` atau `"F"` |
| `ShirtId` | number | opsional, menimpa catalog |
| `PantsId` | number | opsional, menimpa catalog |
| `Price` | number | opsional, 0 = tidak dijual |

Urutan prioritas sumber outfit: **attribute → catalog → 0 (dilewati)**.

**`ShirtId`/`PantsId` = ID KATALOG** (angka dari URL `roblox.com/catalog/<ID>/...`),
bukan ID `ShirtTemplate`. Item Shirt/Pants classic punya 2 ID berbeda: ID katalog
(item yang dijual) dan ID `ShirtTemplate`/`PantsTemplate` (tekstur mentah di
dalamnya). Yang disimpan harus ID **katalog**, karena itu yang dibutuhkan untuk:
thumbnail (`rbxthumb://type=Asset` — ID katalog menghasilkan render mannequin,
ID tekstur cuma gambar flat), harga & status jual (`GetProductInfo`), cek
kepemilikan (`PlayerOwnsAsset`), dan tombol Beli (`PromptPurchase`). Tekstur
mentah tidak pernah dijual, jadi kalau yang disimpan ID tekstur, semua fitur itu
salah/gagal diam-diam (panel menampilkan "Tidak dijual" padahal bajunya dijual).

Konversi ke ID tekstur dilakukan otomatis di server (`resolveShirtOrPantsId`,
hasilnya di-cache) tepat saat memasang `Shirt.ShirtTemplate`. Fungsi itu juga
toleran: kalau diberi ID tekstur (data lama), ia gagal me-resolve lalu memakai
angka itu apa adanya — bajunya tetap terpasang, cuma thumbnail/harga/beli yang
tidak akan benar. `tools/resolve_shirt_id.luau` sekarang cuma alat diagnosa,
tidak lagi perlu dipakai untuk mengisi data.

**Cara paling aman mengisi ID: jangan diketik manual.** Kotak admin di panel
mannequin punya tombol "Cari baju di katalog" yang membuka panel pencarian
(`SearchCatalog` RemoteFunction → `AvatarEditorService:SearchCatalogAsync`).
Hasilnya SELALU ID katalog, jadi salah-tempel ID tekstur tidak mungkin terjadi.
Kolom ID manual tetap ada untuk kasus khusus (item yang tidak muncul di
pencarian), dan `warnIfNotCatalogId()` di server mencetak peringatan eksplisit
di Output kalau `AssetTypeId` yang tersimpan bukan 11 (Shirt) / 12 (Pants).
Catatan: `SearchCatalogAsync` butuh capability "AssetRead"; kalau gagal
(mis. Studio tanpa akses API) panel menampilkan "Pencarian gagal" dan server
mencetak `warn` — kolom ID manual jadi jalan cadangannya.

**Awas nama member Enum saat script dimuat.** Mengetik member yang tidak ada
(mis. `Enum.AvatarAssetType.HatAccessory` — yang benar `Hat`) melempar error di
tingkat *load*, dan itu mematikan SELURUH `Showroom.server.luau`: panel, prompt,
dan mannequin hilang semua padahal yang salah cuma satu baris di fitur yang
belum dipakai. Gejalanya menyesatkan (kelihatan seperti Rojo tidak sync). Karena
itu daftar `AvatarAssetType` untuk pencarian dibangun lewat
`Enum.AvatarAssetType:GetEnumItems()` + lookup nama, bukan diketik langsung —
member yang tidak dikenal cuma dilewati dengan `warn`.

Nama mannequin: `Mannequin_M_NNN` / `Mannequin_F_NNN` (`NNN` = `PodiumIndex`,
misal `Mannequin_M_047` — angka disisipkan cuma supaya urutan kelihatan langsung
di Explorer, tidak ada kode yang bergantung pada nama persis ini, semua
pengecekan pakai attribute `PodiumIndex`/`Gender`).

### Cara membuka panel outfit: "E" atau klik/tap

Dua jalan, keduanya memanggil `open()` yang sama di `ShowroomClient`:

- **ProximityPrompt** di `OutfitPromptAnchor` (part tak-terlihat 2 stud di atas
  kepala). `ActionText`/`ObjectText` sengaja **dikosongkan** — yang muncul cuma
  lingkaran tombol "E". Teks panjang menutupi baju mannequin, padahal itu justru
  barang yang mau dilihat pembeli; nama koleksinya toh jadi judul panel begitu
  dibuka.
- **Klik/tap badan mannequin** lewat `ClickDetector` di part `OutfitClickBox`.
  `ClickDetector.MouseClick` tetap menyala di HP walau namanya "Mouse".

`OutfitClickBox` harus part terpisah, **tidak bisa** ditempel ke badan mannequin:
`place_mannequins.luau` menyetel `CanQuery = false` di semua part mannequin, dan
part seperti itu tidak pernah kena raycast mouse — ClickDetector di situ tidak
akan pernah menyala. Jadi dipakai satu part tak-terlihat seukuran bounding box
mannequin dengan `CanQuery = true`. Ukurannya diambil **sebelum**
`OutfitPromptAnchor` dibuat, kalau tidak kotaknya jadi kelewat tinggi.

**Semua part lain di mannequin WAJIB `CanQuery = false`, termasuk aksesoris.**
Bug yang pernah terjadi: aksesoris dipasang server lewat `AddAccessory`, yang
membawa setelan bawaan Roblox (`CanQuery = true`, tidak di-anchor). Mouse
mengenai rambut/topi duluan, kotak klik di belakangnya tidak pernah tersentuh.
Gejalanya: kursor tetap panah (bukan tangan) di mannequin beraksesoris, sementara
yang tanpa aksesoris bisa diklik. Sekarang `applyTo()` mengunci ulang SEMUA
BasePart kecuali `OutfitClickBox` setiap kali outfit dipasang.

**Kecepatan membuka panel** — dua lapis:

- **Server:** kepemilikan item di-cache per pemain (`ownsCached`). "Sudah punya"
  disimpan selamanya (tidak bisa hilang di tengah sesi); "belum punya" cuma 60
  detik dan langsung dibuang saat pemain membeli sesuatu. Info produk +
  kepemilikan semua item diambil **paralel** (`prefetchItems`), jadi waktu
  tunggu = panggilan web paling lambat, bukan jumlah semuanya. Dulu
  `PlayerOwnsAsset` dipanggil berurutan per item, tanpa cache, setiap panel
  dibuka — itulah sumber delay-nya.
- **Client:** data mannequin **diambil duluan** saat tombol "E"-nya muncul
  (`ProximityPromptService.PromptShown` = pemain sudah dekat), di-cache 15 detik.
  Kalau belum siap saat diklik, panel tetap terbuka **seketika** dalam keadaan
  memuat, bukan diam menunggu. `openToken` membuang jawaban lama kalau pemain
  keburu membuka mannequin lain. Cache dibuang saat tombol Beli diklik dan saat
  admin menyimpan; angka suka di cache ikut diperbarui lewat `LikesChanged`.

### Tag `"Mannequin"` / `"MannequinClickBox"`

Server memasang dua tag CollectionService di `refreshAll()`/`setupPrompt()`. Tag
ikut replikasi, jadi client tidak perlu menebak nama instance maupun menunggu
`WaitForChild` — cukup `GetInstanceAddedSignal`/`GetInstanceRemovedSignal`, yang
sekaligus menangani mannequin yang keluar-masuk karena `StreamingEnabled`.

| Tag | Dipasang di | Dibaca oleh |
|---|---|---|
| `Mannequin` | Model mannequin | `MannequinFocus` (efek angkat + outline) |
| `MannequinClickBox` | Part `OutfitClickBox` | `ShowroomClient` (klik = buka panel) |

`MannequinFocus.client.luau` mengangkat mannequin terdekat ±1,5 stud + memberi
outline. Deteksinya **jarak**, bukan `MouseHoverEnter` — di HP tidak ada kursor,
event hover tidak akan pernah menyala. Tiga hal yang berbeda dari pendekatan
"standar" karena kondisi proyek ini:

- **Pendaftaran WAJIB pakai `WaitForChild`, bukan `FindFirstChild`.** Bug yang
  pernah terjadi: tag CollectionService bisa sampai ke client SEBELUM anak-anak
  model ikut direplikasi. Dulu `register()` langsung `return` kalau
  `HumanoidRootPart` belum ada — dan karena `GetInstanceAddedSignal` tidak
  menyala dua kali untuk instance yang sama, mannequin itu **tidak pernah**
  terdaftar sepanjang sesi. Gejalanya acak dan tanpa error: sebagian mannequin
  diam saja saat didekati.
- **Offset naik ditulis `CFrame.new(0, y, 0) * base`, bukan `base * CFrame...`.**
  Translasi di kiri = sumbu Y dunia; di kanan = sumbu atas milik mannequin.
  Mannequin menghadap berbagai arah, jadi kalau ada satu yang miring, versi
  kanan membuatnya melayang menyamping.
- **Satu mannequin aktif pada satu waktu, ini disengaja.** Cowok & cewek di satu
  podium berdiri berdampingan, jadi yang terangkat cuma yang terdekat (dengan
  hysteresis 2 stud supaya tidak bolak-balik). Kalau suatu saat diinginkan
  keduanya terangkat bersama, yang diubah adalah fase 2 di loop utama.
- **Dua fase animasi, sengaja beda easing.** Fase naik pakai Quad/Out (cepat
  lalu melambat — terasa seperti terkena daya angkat); setelah selesai, fase
  melayang naik-turun pakai Sine/InOut dengan `Reverses = true` +
  `RepeatCount = -1`, jadi satu tween bolak-balik selamanya tanpa perlu loop
  `RunService` sendiri. Fase melayang **harus** dibatalkan sebelum tween turun
  dibuat — kalau tidak, keduanya menarik `NumberValue` yang sama dan mannequin
  tersangkut di udara sambil bergetar.
- **Digerakkan dengan `Model:PivotTo()`, bukan tween `HumanoidRootPart`.** Semua
  part mannequin di-anchor (aturan "mannequin adalah patung"), dan Motor6D tidak
  menyeret part yang di-anchor. `OutfitPromptAnchor` juga cuma di-CFrame sekali
  tanpa weld, jadi ia akan tertinggal di bawah. Yang di-tween adalah sebuah
  `NumberValue` tinggi angkat (supaya easing Quad/Out tetap dapat), lalu
  `PivotTo` dipanggil di `Changed`-nya. NumberValue dibuat saat mannequin
  pertama kali difokuskan, bukan saat registrasi.
- **Satu `Highlight` dipakai bergantian**, bukan satu per mannequin. Roblox cuma
  merender sejumlah kecil Highlight sekaligus; 240 instance sudah lewat batas dan
  sisanya diam-diam tidak muncul. Parent-nya `workspace.CurrentCamera` — kalau
  ditempel ke model, Highlight ikut terhapus saat mannequin streaming-out.
- **`GetPartBoundsInRadius` TIDAK bisa dipakai** untuk mempersempit kandidat:
  `place_mannequins.luau` menyetel `CanQuery = false` di semua part mannequin,
  dan query spasial melewatkan part seperti itu. Jadi iterasinya tetap seluruh
  tabel, tapi di-throttle ~30 Hz (bukan tiap frame).

Efeknya murni client-side — tiap pemain punya fokusnya sendiri, tidak ada
replikasi. Konsekuensi kecil: kalau admin mengganti outfit tepat saat mannequin
sedang terangkat di layar pemain lain, Accessory yang baru datang muncul di
ketinggian asli sampai fokus berpindah sekali.

### Dua "suka" yang berbeda — jangan tertukar

| | Tombol hati di tiap **item** | Tombol Suka di **header panel** |
|---|---|---|
| Milik siapa | akun Roblox pemain | showroom ini |
| Disimpan di | Roblox (`AvatarEditorService`) | `MannequinLikes_v1` DataStore |
| Cakupan | satu baju/aksesoris | satu mannequin (podium + gender) |
| Terlihat orang lain | tidak | ya, angkanya publik |

`LikeService.luau` menyimpan dua bentuk data dengan alasan berbeda: **jumlah per
mannequin** dalam SATU key (startup cuma 1x `GetAsync`, bukan 240x), dan
**daftar mannequin yang disukai seorang pemain** per key pemain (supaya tombolnya
tahu "sudah kamu suka" saat dia join lagi, dan satu orang tidak bisa menyuka
berkali-kali).

Jumlah like ditulis **berkala (30 detik), bukan tiap klik** — satu key dipakai
bersama semua pemain, jadi menulis tiap klik gampang kena rate limit DataStore
dan saling menimpa. Kehilangan maksimal 30 detik terakhir jauh lebih murah
daripada write yang ditolak.

Reset hanya **SUPERADMIN** (dicek ulang di server). Dua tingkat pengaman,
sesuai besar dampaknya:

| Reset | Di mana | Pengaman |
|---|---|---|
| satu podium | kotak admin di panel mannequin | klik dua kali, **jeda minimal 0,8 detik** di antaranya |
| SEMUA mannequin | header panel "Kelola Semua Podium" | dialog terpisah, harus **mengetik `RESET`** |

Reset SEMUA sengaja **tidak** ada di panel mannequin: dulu sempat di sana, tapi
duduk dekat tombol Simpan yang sering diklik, dan pengaman "klik sekali lagi"
**lolos oleh double-click biasa** (dua klik ~0,3 detik). Itu juga sebabnya
`armConfirm` sekarang mengabaikan klik kedua yang datang < 0,8 detik — klik
secepat itu hampir pasti bagian dari double-click, bukan konfirmasi sadar.
Di dialog Reset SEMUA, Batal di kiri dan menonjol; tombol hapus pudar sampai
kata konfirmasinya benar.

Reset juga membersihkan daftar "sudah disuka" pemain yang sedang online — kalau
tidak, tombolnya masih menyala merah padahal hitungannya sudah nol.

### Accessories (rambut, topi, dll) dan beli satuan/borongan

`MannequinCatalog.Outfit.accessories` (opsional) — list `{ assetId, price?, label? }`,
Accessory **classic** saja (bukan Layered Clothing). Beda dari shirt/pants:
tidak bisa di-override lewat **attribute** (Roblox Attribute tidak bisa
nyimpan list), jadi override aksesoris disimpan di DataStore override
(`OutfitOverride.accessoryIds`) lewat remote `SetAccessories`. Remote itu butuh
**Instance** mannequin, jadi aksesoris hanya bisa diubah dari kotak admin di
panel mannequin langsung — tidak dari "Kelola Semua Podium", yang cuma
memegang nomor podium.

Status jual + harga yang ditampilkan ke pemain diambil **live** dari
`MarketplaceService:GetProductInfo()` (field `IsForSale`/`PriceInRobux`), bukan
cuma angka statis di catalog — supaya barang yang sudah ditarik dari penjualan
(event berakhir dll) otomatis kelihatan "Tidak dijual", bukan basi menampilkan
tombol Beli yang sebenarnya gagal. Angka di catalog cuma fallback kalau
`GetProductInfo` gagal (rate limit / asset dihapus total).

Beli borongan (`BuyOutfit` remote, tombol "Beli Semua") pakai
`MarketplaceService:PromptBulkPurchase()` (Bulk Purchase API, dirilis Roblox
Juli 2024) — satu dialog checkout untuk semua item outfit sekaligus, maksimal
20 item. Roblox sendiri yang menandai item yang sudah dimiliki/sudah tidak
dijual di ringkasan itu (terkonfirmasi dari testing, bukan asumsi) dan
mengeluarkannya dari total bayar — tidak perlu logika tambahan di kita untuk
itu. Beli satu item spesifik pakai `BuyItem` remote + `PromptPurchase` biasa.

### Keranjang belanja

`CartClient.client.luau` + blok "Keranjang belanja" di `Showroom.server.luau`.
Beda dari "Beli Semua" (yang cuma bisa satu mannequin), keranjang membiarkan
pembeli keliling mall mengumpulkan barang dari podium mana saja, lalu bayar
sekali di akhir lewat satu dialog `PromptBulkPurchase`.

- **Batas 20 barang** bukan angka karangan — itu batas keras Bulk Purchase API
  (maks 20 line item per dialog). Ditolak di server juga, supaya pemain tahu
  penuh sebelum sampai ke dialog pembayaran.
- **Isi keranjang dipegang server** (`carts[player]`, di memori). Client tidak
  pernah menyimpan daftarnya sendiri — setiap perubahan dikirim balik lewat
  `CartUpdated`, jadi tidak ada dua sumber kebenaran. Dibersihkan di
  `PlayerRemoving`, kalau tidak tabelnya menahan referensi `Player` selamanya.
- **Tidak masuk DataStore, sengaja.** Keranjang yang bertahan berhari-hari malah
  membingungkan: harga dan status jual bisa sudah berubah saat pemain kembali.
- Yang disimpan cuma `assetId`/`kind`/`label`. Harga, status jual, dan
  kepemilikan **selalu diambil ulang** saat keranjang dibaca — sama alasannya
  dengan panel outfit: angka basi lebih buruk daripada angka yang berubah.
- Item yang sudah dimiliki / sedang tidak dijual **tetap boleh dimasukkan**.
  Roblox sendiri yang menandai dan mengeluarkannya dari total bayar; melarangnya
  di client cuma bikin pemain mengira tombolnya rusak. Total di panel juga tidak
  menghitungnya, supaya angkanya cocok dengan dialog checkout.
- `CartAdd` dengan `assetId = 0` berarti "masukkan semua item mannequin ini"
  (tombol "+ Semua ke keranjang"). Server tetap memvalidasi tiap assetId benar
  bagian dari outfit mannequin yang dikirim — tanpa itu client bisa menyuntikkan
  assetId bebas ke keranjang.

### Like = Favorite katalog Roblox (bukan hitungan sendiri)

Tombol hati di pojok thumbnail tiap item memakai **AvatarEditorService**, bukan
counter "suka" milik game ini:

| API | Kegunaan | Capability |
|---|---|---|
| `PromptSetFavorite(id, Enum.AvatarItemType.Asset, bool)` | buka dialog favorit | Players, PlatformAvatarEditing |
| `GetFavoriteAsync(id, Enum.AvatarItemType.Asset)` | status awal hati (yields) | Players, AssetRead |
| `PromptSetFavoriteCompleted(result)` | hasil dialog | Players, PlatformAvatarEditing |

Ketiganya **client-only**, jadi semuanya di `ShowroomClient.client.luau`, tidak
lewat remote sama sekali.

Kenapa dipilih ini dan bukan counter sendiri: favoritnya tersimpan di **akun
Roblox pemain** dan muncul di daftar favorit mereka di luar game — lebih berguna
daripada angka yang cuma hidup di server kita, dan tidak butuh DataStore (yang
di place ini memang belum jalan sampai di-publish).

Dua jebakan yang sudah ditangani:

- `PromptSetFavoriteCompleted` **tidak menyebutkan item mana** yang selesai —
  cuma `Enum.AvatarPromptResult` (`Success`/`PermissionDenied`/`Failed`). Jadi
  permintaan yang sedang berjalan dicatat di `pendingFavorite`, dan cuma satu
  dialog boleh jalan pada satu waktu.
- `GetFavoriteAsync` itu panggilan web yang **yield**. Satu mannequin bisa punya
  banyak item, jadi status awal diambil di `task.spawn` (hasilnya di-cache per
  assetId) — kalau ditunggu, panel baru muncul setelah semua item selesai dicek.
- `favoriteButtons` dikosongkan di `rebuildItems()`; tanpa itu daftarnya tumbuh
  tiap panel dibuka dan menahan referensi ke GuiObject yang sudah dihancurkan.

`GetFavorite` (tanpa `Async`) sudah **deprecated** — jangan dipakai.

### Donasi & statistik pemain

`StatsService.luau` (modul) + `Donations.server.luau` + `DonateClient` (modal
donasi). Angka per pemain tampil di `leaderstats` bawaan Roblox (lihat bawah).

Donasi di sini memakai **Developer Product**: Robux-nya masuk ke pemilik
experience. Itu pilihan pengguna ("donasi ke developer/game").

> **Koreksi (2026-10-14):** catatan lama di sini menyatakan Roblox tidak punya
> API untuk memindahkan Robux antar pemain. **Itu salah.** Dokumentasi resmi
> (`production/monetization/robux-transfers.md`) memuat
> `MarketplaceService:PromptRobuxTransferAsync(sender, receiverUserId, amount)`,
> dan `ProcessReceipt` punya field `CurrencySpent`/`TransferRequestId` untuk
> itu. Donasi antar pemain (gaya PLS DONATE) jadi mungkin tanpa gamepass —
> belum diterapkan, dan syarat/kelayakannya belum dicek. Cek dokumentasi
> terbaru (Context7: `/roblox/creator-docs`) sebelum merancangnya.

> ⚠️ **Belum bisa dipakai sampai productId-nya diisi.** Developer Product tidak
> bisa dibuat dari kode. Buat manual di Creator Dashboard → Monetization →
> Developer Products (satu produk per nominal), lalu salin ID-nya ke
> `DONATION_PRODUCTS` di `Donations.server.luau`. `productId = 0` berarti belum
> dibuat, dan tombolnya sengaja TIDAK ditampilkan — daripada ada tombol yang
> diklik lalu gagal diam-diam.

**Dua DataStore, sengaja beda jenis:**

| Store | Jenis | Kenapa |
|---|---|---|
| `PlayerStats_v1` | DataStore | data lengkap satu pemain |
| `DonatedTotal_v1` | **Ordered**DataStore | cuma OrderedDataStore yang bisa `GetSortedAsync` ("siapa 10 donatur terbesar"). DataStore biasa tidak bisa diurutkan sama sekali |

**ProcessReceipt adalah satu-satunya tempat donasi boleh dicatat** (ini juga
menutup gap "belum ada handling ProcessReceipt"). Tiga aturan keras, karena
jawaban yang salah di sini berarti Robux pemain hilang tanpa tercatat:

1. **Jangan `PurchaseGranted` sebelum angkanya benar-benar tersimpan.** Roblox
   mengirim ulang receipt sampai dijawab granted — itu jaring pengamannya.
2. **Jangan menghitung dua kali.** `PurchaseId` yang sudah diproses disimpan di
   data pemain (dibatasi 50 terakhir supaya tidak tumbuh selamanya).
3. **Jangan mencatat sebelum data pemain selesai dimuat.** Kalau dipaksa,
   donasinya ditambahkan ke data kosong lalu menimpa total aslinya. Makanya
   `addDonation` mengembalikan status (`ok`/`duplicate`/`not_loaded`/
   `save_failed`), bukan sekadar boolean — dan `not_loaded`/`save_failed`
   dijawab `NotProcessedYet` supaya Roblox mengulang.

`save()` pakai `UpdateAsync`, bukan `SetAsync`: kalau pemain berpindah server
saat data belum tersimpan, `SetAsync` akan menimpa dan menghilangkan donasi yang
baru tercatat di server lain.

**Kolom "Beli"/"Belanja"** diisi dari `PromptPurchaseFinished`. Event itu
melaporkan apa kata dialog di CLIENT, jadi tidak dipercaya mentah-mentah —
kepemilikannya diverifikasi ulang lewat `PlayerOwnsAsset` sebelum dihitung.
**`PromptBulkPurchaseFinished` itu CLIENT-ONLY.** Pernah dipasang di server
(di `Showroom` dan `Donations`) dan melempar *"can only be subscribed to from a
local script"* saat script **dimuat** — seluruh `Showroom.server.luau` mati:
mannequin abu-abu tanpa baju, tidak mengambang (tag `Mannequin` tak terpasang),
tombol admin hilang (`GetMyRole` tak terpasang, superadmin terlihat seperti
pemain biasa). Pemeriksaan statis (`selene`) tidak menangkap ini; baru ketahuan
lewat Output Studio. Jalur yang benar sekarang:

1. Server mencatat barang yang ia tawarkan saat membuka dialog borongan
   (`rememberBulk` → `pendingBulk`), hanya yang **belum dimiliki** saat itu.
2. Client mendengarkan `PromptBulkPurchaseFinished` dan cuma mengirim sinyal
   kosong `BulkPurchaseDone` — tanpa hasil/isi apa pun.
3. Server memverifikasi sendiri kepemilikan tiap barang di `pendingBulk` ke
   Roblox, lalu mencatatnya. Sinyal client sekali pakai dan tidak bisa
   menambah barang di luar daftar server.

`StatsService.addAssetPurchase` mengabaikan aset yang sudah tercatat di sesi
itu — tidak terdokumentasi apakah `PromptPurchaseFinished` ikut menyala untuk
item dalam pembelian borongan, dan satu aset hanya bisa dibeli sekali per akun.

**Aturan umum:** sebelum men-`Connect` event `MarketplaceService`/
`AvatarEditorService` di server, pastikan event itu memang boleh di server —
salah konteks = error saat load = seluruh script mati, bukan cuma fitur itu.

`DonateClient` memakai 3 kolom sejajar di layar lebar dan menumpuk di layar
sempit (`WIDE_BREAKPOINT`). Roblox tidak punya media query, jadi dipantau lewat
`gui:GetPropertyChangedSignal("AbsoluteSize")`.

**Angka per pemain tampil lewat `leaderstats`** (daftar pemain bawaan Roblox di
kanan-atas), bukan panel buatan sendiri — dulu sempat ada `ServerStatsClient`
tapi dibuang karena Roblox sudah merender ini gratis, lengkap dengan
pengurutan dan tampilan mobile. Cukup sediakan Folder bernama persis
`leaderstats` di dalam Player berisi `IntValue` per kolom (`Purchases`,
`Donated`, `Spent`); `syncLeaderstats()` di `StatsService` memperbaruinya tiap
angka berubah. Nama kolom **tidak bisa ikut Localization** — instance-nya satu
di server dan dilihat semua pemain sekaligus, jadi dipakai bahasa Inggris.
`StatsChanged` sekarang cuma sinyal kosong "ada yang berubah" untuk menyegarkan
papan donatur yang sedang terbuka.

### Lari (Shift / tombol HP)

`Sprint.client.luau` — tahan **Shift** untuk lari (16 → 48, 3x jalan normal). Dipakai
`ContextActionService`, bukan `UserInputService`, karena satu binding mengurus
keyboard, gamepad (L3), dan HP sekaligus: `createTouchButton = true` membuatkan
tombol lari di layar hanya di perangkat sentuh, tanpa ScreenGui buatan sendiri.

- **`WalkSpeed` ditulis di client, dan HANYA oleh script ini.** Pemain punya
  network ownership atas karakternya sendiri, jadi perubahannya tetap
  direplikasi ke server tanpa jeda ping — penting untuk aksi tahan-lepas.
  Konsekuensinya bisa di-exploit, tapi di showroom ini tidak ada yang bisa
  dicurangi dengan lari cepat.
- `DebugTools` (Studio saja) **tidak** menyetel `WalkSpeed` sendiri — ia cuma
  mengubah attribute Player `DebugBaseSpeed`, lalu `Sprint` yang menerapkannya.
  Kalau keduanya sama-sama menulis, sekali tekan-lepas Shift akan mengembalikan
  kecepatan ke 16 sementara tombol debug masih menyala "ON".
- `DevEnableMouseLock` dimatikan di `SprintSupport.server.luau`: Shift Lock
  bawaan Roblox memakai tombol Shift yang sama, jadi kalau dibiarkan, satu
  tekanan akan lari sekaligus mengunci kamera.

Sistem lama **"Speed Coil" (item backpack) sudah dihapus.** `SpeedTool.server.luau`
tidak ada lagi; Tool-nya masih tersimpan di dalam `.rbxl` (StarterPack tidak
dipetakan Rojo), jadi `SprintSupport.server.luau` membuangnya saat runtime.
Hapus manual di StarterPack (Edit mode) kalau mau permanen — setelah itu blok
`removeObsoleteTool` boleh ikut dihapus.

### Kelola Semua Podium (panel admin)

`AdminPanelClient.client.luau` — peta 120 podium + panel detail. Desain lama
(120 baris kotak teks ID mentah) punya tiga masalah, masing-masing dijawab satu
fitur:

| Masalah | Jawaban |
|---|---|
| Tidak kelihatan mana yang belum diisi | kotak berwarna per status (abu = kosong, kuning = sebagian, hijau = lengkap), titik M/F di tiap kotak, filter status, bar progres "x/240 terisi" |
| Angka ID tidak bisa dicek benar/salah | pratinjau thumbnail langsung saat kolom ditinggalkan — ID tekstur yang salah tempel langsung kelihatan flat, bukan render mannequin |
| "Podium 47 itu yang mana di map?" | tombol **Teleport ke sini** (pakai `TeleportToPodium` yang sudah ada), panel menutup sendiri supaya mannequin-nya langsung terlihat |

Status dihitung per mannequin: terisi = `shirt > 0 or pants > 0`. Podium
"sebagian" = salah satu dari M/F terisi — titik M/F ada supaya admin tahu
**sisi mana** yang kurang, bukan cuma "ada yang kurang".

Simpan memperbarui data lokal langsung (warna kotak & progres berubah tanpa
memuat ulang 240 mannequin). Server tidak membalas `SetOutfitByIndex`, jadi
kalau perlu memastikan, pakai **Muat ulang**. Kosongkan butuh dua klik — tidak
ada undo, dan efeknya langsung terlihat semua pemain.

Aksesoris **tidak** bisa diubah dari panel ini: `SetAccessories` butuh Instance
mannequin, bukan cuma nomor podium. Panel menuliskan jumlah aksesorisnya dan
menyuruh mengubah lewat panel mannequin langsung — sengaja diberi tahu, bukan
disembunyikan diam-diam.

Di jendela < 720 px, detail menutupi grid (dengan tombol Kembali) alih-alih
berdampingan.

### Aturan layout UI

Semua panel dibangun lewat kode, jadi tidak ada editor yang memperingatkan kalau
isinya melebihi layar. Terbukti bikin panel outfit tidak bisa ditutup sama
sekali (tinggi 824 px tetap, viewport Studio cuma ~670 px — tombol Tutup ada di
luar layar). Aturannya sekarang:

1. **Jangan pernah pakai tinggi piksel tetap untuk panel.** Pakai `1, -margin`
   (ikut layar) plus `UISizeConstraint` `MinSize`/`MaxSize` supaya tidak
   memanjang aneh di monitor tinggi.
2. **Tombol Tutup di luar area scroll**, ditempel ke dasar panel
   (`AnchorPoint (0,1)`, `Position (0,0,1,0)`). Kalau ikut di dalam `UIListLayout`
   yang di-scroll, di layar pendek ia hilang lagi.
3. **Satu panel = satu ScrollingFrame.** Scroller bersarang bikin roda mouse
   bingung harus menggerakkan yang mana. Grid item di panel outfit sengaja
   `Frame` + `AutomaticSize.Y`, bukan scroller sendiri.
4. **Elemen yang mengisi sisa ruang pakai tinggi scale** (`1, -<jumlah tinggi
   elemen lain>`), supaya yang menyusut saat panel mengecil adalah daftar
   isinya, bukan tombol aksi yang terdorong keluar.
5. **Panel dan tombol pembukanya tidak boleh tampil bersamaan di sudut yang
   sama.** Keranjang menyembunyikan tombolnya sendiri saat panel terbuka —
   kalau tidak, tombol Tutup panel duduk persis di atas tombol keranjang.

Pembagian layar saat ini:

| Area | Isi |
|---|---|
| kiri-atas | tombol admin & debug |
| tepi kanan (kolom ikon bulat) | Keranjang (`0.5, -92`), Donasi (`0.5, 0`), Sembunyikan UI (`0.5, +92`) |
| kanan, digeser `-92` | panel outfit (lebar 430, menyisakan ruang untuk kolom ikon) |
| kiri panel outfit (`-534`) | panel pencarian katalog |
| tengah (modal + latar gelap) | keranjang, donasi, kelola semua podium |
| kanan-atas | daftar pemain bawaan Roblox (`leaderstats`) |
| kanan-bawah | tombol lompat/lari bawaan Roblox di HP |

Panel yang setinggi layar (panel outfit) dan panel yang menempel di sudut tidak
boleh berada di sisi yang sama — keranjang sempat begitu dan langsung bertumpuk.
Kalau ragu, jadikan modal di tengah.

**Sembunyikan UI** (`HideGuiClient`) mematikan `Enabled` semua ScreenGui kecuali
dirinya sendiri, plus `PlayerList`/`Chat`/`Backpack`/`EmotesMenu` lewat
`SetCoreGuiEnabled`. Keadaan sebelum disembunyikan **disimpan dulu**, bukan
di-set `true` saat dipulihkan — kalau tidak, panel yang memang sedang tertutup
(mis. panel outfit yang belum dibuka) ikut menyala saat UI ditampilkan lagi.
`DisplayOrder = 50` menjaga tombolnya selalu di atas panel lain.

## Aturan yang tidak boleh dilanggar

1. **Role diperiksa di server, selalu.** `RoleService` ada di `ServerScriptService`
   supaya daftar superadmin tidak terbaca client. UI client hanya menyembunyikan
   tombol — itu kosmetik, bukan pengamanan.
2. **Validasi setiap argumen remote.** Instance yang dikirim client harus dicek
   benar-benar anak dari `workspace.Mannequins` dan punya attribute wajib.
   Lihat `validMannequin()` di `Showroom.server.luau`.
3. **Mannequin adalah patung.** Semua BasePart di-anchor, `CanCollide = false`,
   dan semua `LuaSourceContainer` (termasuk `Animate`) dihapus saat clone.
4. `superadmin` hardcoded di `RoleService.luau`, `admin` dari DataStore atau rank
   grup. `buyer` **bukan** role — itu status kepemilikan, dicek per item lewat
   `Roles.owns()`.

## Beban instance

Tiap rig ±67–87 descendant. 120 podium × 2 = **240 mannequin**, artinya sekitar
19.000 instance baru di atas 13.630 yang sudah ada. Kalau berat:

- aksesoris bawaan rig sudah dibuang (`STRIP_HAIR = true` di
  `tools/place_mannequins.luau`); sisa pengurangan: kurangi aksesoris yang
  dipasang dari katalog
- hapus `CharacterMesh` dan `BodyColors` dari clone
- atau ganti rig dengan satu MeshPart mannequin statis

**Jangan andalkan `StreamingEnabled` di map ini.** Radius streaming default
Roblox 512 stud, sementara seluruh map cuma ±421 × 331 stud — jadi praktis
semua mannequin selalu termuat. Culling manual berdasar jarak juga **tidak**
disarankan: GPU sudah tidak menggambar yang di luar layar (frustum culling) +
LOD otomatis, menyembunyikan mannequin tidak mengurangi instance count maupun
memori tekstur, dan mannequin yang kosong dari jauh merusak fungsi showroom.
Kalau terasa berat, **ukur dulu** (Performance Stats `Ctrl+Shift+F2`,
MicroProfiler `Ctrl+F6`) sebelum memilih jalur di atas.

## Yang belum dikerjakan

- `MannequinCatalog.entries` baru ada contoh untuk podium 1–2 (podium 1 cowok
  sudah berisi ID katalog asli, sisanya `0`); podium 3–120 belum diisi sama
  sekali — pengisian sehari-hari lebih praktis lewat panel "Kelola Semua
  Podium" (tersimpan di DataStore override), bukan mengedit file ini
- Mannequin tanpa wajah & rambut (`STRIP_FACE`/`STRIP_HAIR` di
  `tools/place_mannequins.luau`) baru berlaku setelah tool itu **dijalankan
  ulang** di Command Bar
- `SUPERADMINS` di `RoleService.luau`: superadmin pertama (`concreabot`, UserId
  `9954653030`) sudah permanen. Slot kedua masih placeholder `[0]` (aman, tidak
  match akun manapun) — ganti dengan UserId asli begitu sudah ditentukan siapa
- Persistensi outfit admin **sudah ada** (DataStore, satu key `Overrides`, dimuat
  di awal `refreshAll()`) — tapi sama seperti `ManageAdmin`, baru benar-benar
  tersimpan setelah place di-publish minimal sekali (lihat poin di bawah)
- **Update 2026-10-14:** place yang terbuka di Studio ("testing mall") ternyata **sudah
  di-publish** (PlaceId `140187788240233`), jadi DataStore seharusnya bisa jalan --
  asalkan Game Settings > Security > Enable Studio Access to API Services aktif.
  Catatan lama di bawah dipertahankan sebagai riwayat.
- (lama) `test1.rbxl` kemungkinan belum pernah di-publish ke Roblox — `DataStoreService:GetDataStore()`
  terbukti throw dengan "You must publish this place to the web to access DataStore."
  Sudah dibungkus `pcall` di `RoleService.luau` supaya tidak menjatuhkan seisi
  `Showroom.server.luau`, tapi konsekuensinya: `ManageAdmin` (grant/revoke admin
  lewat DataStore) tidak akan tersimpan/terbaca sampai place ini di-publish minimal
  sekali. `SUPERADMINS` (hardcoded) tidak terpengaruh, tetap jalan normal.
- `ProcessReceipt` **sudah ada** (di `Donations.server.luau`, untuk Developer
  Product donasi). Pembelian baju katalog tidak lewat ProcessReceipt sama sekali
  -- itu aset Roblox, bukan produk kita
- **Developer Product donasi belum dibuat**: `DONATION_PRODUCTS` di
  `Donations.server.luau` semuanya masih `productId = 0`, jadi panel donasi
  tampil tanpa tombol nominal sampai diisi
