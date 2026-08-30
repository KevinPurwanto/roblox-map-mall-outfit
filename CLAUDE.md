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

Nama mannequin: `Mannequin_M` / `Mannequin_F`.

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

- Isi `MannequinCatalog.entries` masih kosong (semua assetId `0`)
- `SUPERADMINS` di `RoleService.luau` masih `[0]` — **wajib diganti UserId asli**
  sebelum tes, kalau tidak tidak ada yang bisa mengangkat admin pertama
- Belum ada persistensi outfit yang diubah admin (sekarang hilang saat server restart)
- Belum ada handling `ProcessReceipt` untuk pembelian
