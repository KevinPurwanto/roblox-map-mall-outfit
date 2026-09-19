# Fitur: Mannequin Focus Effect (Roblox Showroom)

## Tujuan

Saat pemain mendekat, **satu** mannequin terdekat terangkat sedikit dari lantai
dan diberi outline. Semua mannequin lain kembali ke posisi normal. Efek harus
bekerja di semua platform, termasuk mobile.

## Batasan Penting

- **Jangan pakai `MouseHoverEnter` / `MouseEnter`.** Tidak ada kursor di mobile,
  event ini tidak akan pernah menyala di HP.
- Deteksi **harus** berbasis jarak (magnitude ke HumanoidRootPart pemain).
- Efek visual bersifat **client-side** (LocalScript). Jangan replikasi ke server —
  tiap pemain melihat fokusnya masing-masing.
- Hanya `HumanoidRootPart` mannequin yang di-anchor. Bagian tubuh lain tetap
  unanchored dan tersambung Motor6D, supaya seluruh badan ikut saat HRP di-tween.

## Lokasi Script

`StarterPlayer > StarterPlayerScripts > MannequinFocus` (LocalScript)

## Registrasi Mannequin

Pakai `CollectionService` dengan tag `"Mannequin"`.

- Ambil semua yang sudah ada saat start: `GetTagged("Mannequin")`
- Dengarkan yang ditambahkan runtime: `GetInstanceAddedSignal("Mannequin")`
- Dengarkan yang dihapus: `GetInstanceRemovedSignal("Mannequin")` → bersihkan state

Jangan hardcode nama model seperti `Mannequin_F_001`.

## Konstanta

```
RADIUS      = 8      -- stud; radius aktivasi (kecil, supaya di HP tidak mudah tersenggol)
LIFT        = 1.5    -- stud; tinggi angkat
HYSTERESIS  = 2      -- stud; keunggulan untuk mannequin yang sedang aktif
TWEEN_TIME  = 0.6
EASING      = Quad, Out
```

## Struktur State

Satu tabel `tracked`, key = model, value = record:

```
{
  root        : HumanoidRootPart mannequin
  base        : CFrame asli (disimpan saat registrasi, JANGAN dihitung ulang)
  highlight   : Highlight instance
  active      : boolean
  tween       : Tween aktif (untuk di-Cancel sebelum bikin yang baru)
}
```

Plus satu variabel global `activeModel` = model yang sedang terangkat, atau nil.

## Pseudocode

### register(model)

```
root = model:FindFirstChild("HumanoidRootPart")
if not root then return end

highlight = Instance.new("Highlight")
highlight.FillTransparency    = 1
highlight.OutlineTransparency = 1        -- mulai tidak terlihat
highlight.OutlineColor        = warna aksen showroom
highlight.Adornee             = model
highlight.Parent              = model

tracked[model] = { root, base = root.CFrame, highlight, active = false, tween = nil }
```

### unregister(model)

```
if activeModel == model then activeModel = nil end
batalkan tracked[model].tween jika ada
hancurkan tracked[model].highlight
tracked[model] = nil
```

### setState(model, state, on)

```
if state.active == on then return end       -- guard: jangan kerja dua kali
state.active = on

if state.tween then state.tween:Cancel() end

target = on ? (state.base + Vector3(0, LIFT, 0)) : state.base
state.tween = TweenService:Create(state.root, INFO, { CFrame = target })
state.tween:Play()

tween highlight.OutlineTransparency ke (on ? 0 : 1)
```

### Loop utama — RunService.Heartbeat

```
character = LocalPlayer.Character
hrp = character and character:FindFirstChild("HumanoidRootPart")
if not hrp then return end                  -- respawn / belum load

-- FASE 1: cari pemenang, jangan ubah apa pun dulu
closest     = nil
closestDist = RADIUS

for model, state in tracked:
    if not state.root.Parent then
        unregister(model)
        continue
    end

    dist = (state.root.Position - hrp.Position).Magnitude

    -- hysteresis: yang sedang aktif dapat keunggulan, supaya fokus
    -- tidak bolak-balik saat dua mannequin berjarak nyaris sama
    if model == activeModel then
        dist = dist - HYSTERESIS
    end

    if dist < closestDist then
        closest     = model
        closestDist = dist
    end

-- FASE 2: terapkan HANYA jika pemenang berganti
if closest ~= activeModel then
    if activeModel and tracked[activeModel] then
        setState(activeModel, tracked[activeModel], false)
    end
    if closest then
        setState(closest, tracked[closest], true)
    end
    activeModel = closest
end
```

Poin kunci: fase 1 murni membaca, fase 2 murni menulis. Selama pemain diam di
depan satu mannequin, **tidak ada tween baru yang dibuat sama sekali**.

## Edge Case yang Harus Ditangani

1. **Pemain respawn** — `LocalPlayer.Character` jadi nil sesaat. Loop harus
   return diam-diam, dan `activeModel` di-reset ke nil supaya tidak ada
   mannequin yang tertinggal dalam posisi terangkat.
2. **Mannequin dihapus saat sedang aktif** — `activeModel` harus di-nil-kan,
   jangan sampai loop mengakses record yang sudah hilang.
3. **Model tanpa HumanoidRootPart** — lewati saat registrasi, jangan error.
4. **Tween tumpang tindih** — selalu `:Cancel()` tween lama sebelum membuat baru.
5. **`base` bergeser** — simpan sekali saat registrasi. Kalau dibaca ulang dari
   `root.CFrame` saat mannequin sedang terangkat, posisinya akan naik terus
   setiap kali fokus berpindah.

## Optimasi (opsional, kalau mannequin > 30)

Ganti iterasi seluruh tabel `tracked` dengan
`workspace:GetPartBoundsInRadius(hrp.Position, RADIUS + HYSTERESIS)`, lalu
petakan part hasilnya kembali ke model induknya. Dengan begitu hanya mannequin
di sekitar pemain yang ikut dihitung.

## Yang Tidak Termasuk Scope Ini

Interaksi tap/klik untuk membuka UI detail baju ditangani terpisah dengan
`ClickDetector.MouseClick` (event ini jalan di HP meski namanya "Mouse") atau
`ProximityPrompt`.
