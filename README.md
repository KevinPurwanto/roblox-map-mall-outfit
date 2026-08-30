# Hello Kitty Mall

Showroom avatar Roblox. Script dikelola lewat Rojo, geometri map tetap di Studio.

## Persiapan sekali saja

1. Install [Rokit](https://github.com/rojo-rbx/rokit), lalu di folder ini jalankan:

   ```bash
   rokit install
   ```

2. Di Roblox Studio, pasang plugin **Rojo** (toolbox → Plugins → cari "Rojo").

3. Di VS Code, pasang ekstensi **Rojo** dan **Luau LSP**.

4. Salin `map_backup.rbxl` ke folder ini.

## Alur harian

```bash
rojo serve
```

Lalu di Studio: buka `map_backup.rbxl` → klik ikon Rojo → **Connect**.
Setiap perubahan file di `src/` langsung masuk ke Studio.

## Urutan menjalankan pertama kali

1. **Isi `SUPERADMINS`** di `src/ServerScriptService/RoleService.luau` dengan
   UserId kamu. Kalau dilewati, tidak ada yang bisa mengangkat admin.

2. Aktifkan **Game Settings → Security → Enable Studio Access to API Services**,
   supaya DataStore jalan di Studio.

3. Buat mannequin-nya. Buka **View → Command Bar**, tempel seluruh isi
   `tools/place_mannequins.luau`, tekan Enter. Hasilnya masuk ke
   `workspace.Mannequins` — 240 mannequin di 120 podium.

4. Tekan **Play**. `Showroom.server.luau` akan memakaikan baju sesuai catalog
   dan memasang ProximityPrompt di tiap mannequin.

## Struktur

```
src/ServerScriptService/
  RoleService.luau           role: superadmin / admin / player
  Showroom.server.luau       remote, dressing, try-on, purchase, aksi admin
src/ReplicatedStorage/
  MannequinCatalog.luau      assetId per podium (aman dibaca client)
src/StarterPlayer/StarterPlayerScripts/
  ShowroomClient.client.luau UI panel + panel admin
tools/
  place_mannequins.luau      generator mannequin, jalankan di Command Bar
```

## Undo generator

Hapus folder `workspace.Mannequins`. Menjalankan ulang generator juga otomatis
menghapus folder lama, jadi aman dicoba berulang kali sambil menyetel
`SWAP_SIDES`, `FACE_FLIP`, dan `GAP`.

Baca `CLAUDE.md` untuk konteks map dan aturan-aturan yang tidak boleh dilanggar.
