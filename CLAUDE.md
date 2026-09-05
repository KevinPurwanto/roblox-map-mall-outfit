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

Dua Model bernama `Rig` di Workspace, keduanya **R6**, tinggi 5 studs,
lebar bahu 4 studs (torso 2 + lengan 1+1).

- **Cowok** — rig polos, tanpa `CharacterMesh`
- **Cewek** — punya 5 `CharacterMesh` paket Woman + accessory "Kate Hair"

MeshId paket Woman, kalau perlu membuat rig cewek baru dari rig cowok:

| BodyPart | MeshId |
|---|---|
| Torso | 82987757 |
| LeftArm | 83001137 |
| RightArm | 83001181 |
| LeftLeg | 746826007 |
| RightLeg | 746825633 |

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

**`ShirtId`/`PantsId` BUKAN angka dari URL katalog Roblox.** Item Shirt/Pants
classic punya 2 ID berbeda: ID katalog (di URL `roblox.com/catalog/<ID>/...`)
dan ID `ShirtTemplate`/`PantsTemplate` (tekstur asli di dalamnya) — beda angka.
Kode kita (`applyTo`, `TryOn`, `applyClothes`) langsung memasang nilai ini ke
`Shirt.ShirtTemplate`, jadi yang harus disimpan adalah ID tekstur, bukan ID
katalog — kalau salah, tidak ada error, cuma baju tidak pernah kelihatan.
Cara dapat ID yang benar: jalankan `tools/resolve_shirt_id.luau` di Command Bar
(isi `CATALOG_ID` dengan angka dari URL, print hasil `ShirtTemplate`-nya).

Nama mannequin: `Mannequin_M_NNN` / `Mannequin_F_NNN` (`NNN` = `PodiumIndex`,
misal `Mannequin_M_047` — angka disisipkan cuma supaya urutan kelihatan langsung
di Explorer, tidak ada kode yang bergantung pada nama persis ini, semua
pengecekan pakai attribute `PodiumIndex`/`Gender`).

### Accessories (rambut, topi, dll) dan beli satuan/borongan

`MannequinCatalog.Outfit.accessories` (opsional) — list `{ assetId, price?, label? }`,
Accessory **classic** saja (bukan Layered Clothing). Beda dari shirt/pants:
tidak bisa di-override lewat attribute per-mannequin (Roblox Attribute tidak
bisa nyimpan list) — jadi accessory cuma diatur lewat `MannequinCatalog.luau`,
tidak lewat panel admin "Simpan ke mannequin".

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

- set `KEEP_ACCESSORIES = false` di `tools/place_mannequins.luau`
- hapus `CharacterMesh` dan `BodyColors` dari clone
- atau ganti rig dengan satu MeshPart mannequin statis

`StreamingEnabled` sudah aktif dan cukup membantu.

## Yang belum dikerjakan

- `MannequinCatalog.entries` baru ada contoh untuk podium 1–2 (assetId masih `0`,
  placeholder), podium 3–120 belum diisi sama sekali
- `SUPERADMINS` di `RoleService.luau`: superadmin pertama (`concreabot`, UserId
  `9954653030`) sudah permanen. Slot kedua masih placeholder `[0]` (aman, tidak
  match akun manapun) — ganti dengan UserId asli begitu sudah ditentukan siapa
- Belum ada persistensi outfit yang diubah admin (sekarang hilang saat server restart)
- `test1.rbxl` kemungkinan belum pernah di-publish ke Roblox — `DataStoreService:GetDataStore()`
  terbukti throw dengan "You must publish this place to the web to access DataStore."
  Sudah dibungkus `pcall` di `RoleService.luau` supaya tidak menjatuhkan seisi
  `Showroom.server.luau`, tapi konsekuensinya: `ManageAdmin` (grant/revoke admin
  lewat DataStore) tidak akan tersimpan/terbaca sampai place ini di-publish minimal
  sekali. `SUPERADMINS` (hardcoded) tidak terpengaruh, tetap jalan normal.
- Belum ada handling `ProcessReceipt` untuk pembelian
