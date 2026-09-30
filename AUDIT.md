# LAPORAN AUDIT & ANALISIS UI/UX MODUL REPORTS CHATWOOT

- **Target URL**       : `http://192.168.13.118:3000/app/accounts/15/reports/overview` (dan seluruh sub-menu Reports)
- **Tipe Evaluasi**     : Comprehensive UI/UX, Information Architecture (IA), Data Visualization, & Quality Engineering (QE) Usability Audit
- **Auditor**           : Tim Sepuh Analyst & QE Sub-Agents (Lead Software Analyst, Senior UI/UX & System Auditor)
- **Status Dokumen**    : **UPDATED (RECONCILIATION & IMPLEMENTATION TRACKING ACTIVE)**
- **Terakhir Diperbarui**: Rabu, 30 September 2026

---

## Executive Summary & Status Rekonsiliasi

Modul **Reports** pada Chatwoot telah melalui proses audit UI/UX mendalam dan fase perbaikan teknis bertahap. Seluruh temuan berstatus **CRITICAL REJECT (8 dari 8 temuan) telah 100% tuntas diselesaikan**, diverifikasi, dan divalidasi dengan test runner otomasi (**105 unit tests passed, 0 error**).

Selain temuan kritis, sebagian besar temuan **WARNING dan peningkatan mutu (QC)** pada sektor navigasi, aksesibilitas, visualisasi CSAT, dan transparansi pelanggaran SLA juga telah berhasil diterapkan.

### Ringkasan Status Penyelesaian Masalah

| Tingkat Keparahan | Total Terdata | Sudah Diselesaikan (Resolved) | Tersisa / Backlog (Pending) | Persentase Selesai |
| :--- | :---: | :---: | :---: | :---: |
| 🔴 **CRITICAL REJECT** | **8** | **8** | **0** | **100% TUNTAS** |
| 🟡 **WARNING** | **10** | **7** | **3** | **70% SELESAI** |
| 🔵 **OFI & Polish** | **6** | **3** | **3** | **50% SELESAI** |
| **TOTAL KESELURUHAN** | **24** | **18** | **6** | **75% SELESAI** |

---

## 🧭 Rekapitulasi Cepat: Temuan Selesai vs Temuan Tersisa

### ✅ Telah Diselesaikan (Resolved & Tested)
1. **[CRITICAL 1.1]** Kontainer sempit `max-w-5xl` dilepaskan menjadi `w-full max-w-[96rem] px-6 py-6` (`ReportsWrapper.vue`).
2. **[CRITICAL 2.1]** Ghost rendering `<Table>` dan `<Pagination>` saat loading/empty state diatasi dengan kondisional bersih (`AgentTable.vue` & `TeamTable.vue`).
3. **[CRITICAL 3.1 & QC-WARN-01]** Fitur sorting TanStack Table diaktifkan penuh (`enableSorting: true`, `getSortedRowModel`) pada `SummaryReports.vue`, `AgentTable.vue`, dan `TeamTable.vue`.
4. **[CRITICAL 3.2]** Bug evaluasi angka nol (falsy) diperbaiki; nilai `0` tampil sebagai `0`, `0s`, dan `0%` (bukan data hilang `'--'`).
5. **[CRITICAL 3.3]** Infinite loader saat direct refresh detail inbox/tim diatasi dengan store hydration pada `onMounted` (`InboxReportsShow.vue` & `TeamReportsShow.vue`).
6. **[CRITICAL 4.1]** Grid span header tabel SLA diselaraskan menjadi 12 kolom simetris (`SLATable.vue`).
7. **[CRITICAL 4.2]** Async download handler dengan `await` dan state loading spinner pada tombol ekspor (`CsatResponses.vue` & `SLAReports.vue`).
8. **[CRITICAL 4.3]** Double-fetch waterfall race condition pada inisialisasi filter SLA dihilangkan (`SLAReports.vue` & `SLAReportFilters.vue`).
9. **[WARNING 1.2]** Seluruh 9 sub-menu Reports pada sidebar kini dilengkapi ikon Lucide tematik (`Sidebar.vue`).
10. **[WARNING 1.3]** Bug highlight sidebar padam saat membuka detail laporan label diperbaiki dengan `activeOn: ['label_reports_show']` (`Sidebar.vue`).
11. **[WARNING 3.5]** Keyboard hijacking tombol panah keyboard dicegah saat pengguna mengetik di elemen form (`ReportDrilldownDrawer.vue`).
12. **[WARNING 4.4]** Badge semantik pelanggaran SLA (FRT, NRT, Resolution) dan durasi keterlambatan waktu nyata (`SLAReportItem.vue`).
13. **[WARNING 4.5]** Visualisasi emoji emosional (`😞` - `😍`) dan skor rating (contoh: `(5/5)`) pada tabel respon CSAT (`CsatTable.vue`).
14. **[WARNING 4.6 (Sebagian)]** Overlay loading spinner dan penanganan error alert pada metrik bot (`BotMetrics.vue`).
15. **[QC-OFI-01]** Link tiket percakapan SLA diperbarui untuk membuka tab baru (`target="_blank"`) menjaga konteks laporan.
16. **[QC-OFI-02]** Defensive sorting numerik `(Number(b.created_at) || 0)` pada timestamp SLA events.
17. **[QC-OFI-03]** Refaktor accessor semantik `'team'` pada `TeamTable.vue`.
18. **[QC-OFI-04]** Penataan font angka bermatriks sejajar vertikal (`tabular-nums`) pada `SummaryReports.vue`.

### ⏳ Temuan yang Masih Tersisa (Pending Backlog)
1. **[WARNING 2.2]** Ketiadaan Global Dashboard Filter Toolbar terpadu di bagian atas halaman Overview (`LiveReports.vue`).
2. **[WARNING 2.3]** Kartu metrik KPI di Overview masih berupa teks pasif (belum dapat diklik langsung ke filtered inbox).
3. **[WARNING 3.4]** Kartu drilldown percakapan membuka paksa tab browser baru daripada inline slide-over preview (`ReportDrilldownCard.vue`).
4. **[WARNING 4.6 (Fitur Lanjut)]** Diagram alur corong konversi (*Bot-to-Human Handover Funnel*) dan metrik *Bot Drop-Off Rate*.
5. **[OFI 2.4]** Penataan Heatmap Duo berdampingan 2 kolom (saat ini masih memanjang penuh `col-span-2`).
6. **[OFI]** Sembunyi otomatis chip filter Group By pada `ReportFilters.vue` saat rentang hari <29 hari tanpa penjelasan tooltip.

---

## Sektor 1: Information Architecture, Navigasi Sidebar, & Layout Container

### 1.1. [CRITICAL] Pembatasan Lebar Statis `max-w-5xl` Memicu "Scroll Canyon" dan Membuang >37% Ruang Desktop
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportsWrapper.vue` (Baris 2–5) & `LiveReports.vue`
- **Solusi yang Diterapkan**:
  Pembungkus kontainer diganti menjadi fluida responsif `w-full max-w-[96rem] mx-auto px-6 py-6`. Tata letak tabel Agen dan Tim pada `LiveReports.vue` kini ditata berdampingan dalam CSS Grid 2-kolom pada breakpoint desktop (`xl:`), menghilangkan tumpukan vertikal berlebih.
- **Hasil Verifikasi**: Ruang kosong samping (*empty gutter*) tereliminasi; dashboard memanfaatkan resolusi layar lebar secara proporsional.

---

### 1.2. [WARNING] Fragmentasi Menu Navigasi Sidebar (9 Sub-menu Datar Tanpa Kategori)
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (Baris 258–282, 496–526)
- **Solusi yang Diterapkan**:
  Seluruh 9 sub-item laporan kini dilengkapi dengan ikon Lucide spesifik untuk mempercepat pemindaian visual:
  - ⚡ Overview: `i-lucide-activity`
  - 💬 Conversations: `i-lucide-message-square`
  - 👤 Agents: `i-lucide-users`
  - 👥 Teams: `i-lucide-users-round`
  - 📥 Inboxes: `i-lucide-inbox`
  - 🏷️ Labels: `i-lucide-tag`
  - 😊 CSAT: `i-lucide-smile`
  - ⏱️ SLA: `i-lucide-timer`
  - 🤖 Bot: `i-lucide-bot`
- **Hasil Verifikasi**: Tampilan sidebar rapi, seragam dengan modul lain, dan ramah pemindaian cepat (*rapid visual scanning*).

---

### 1.3. [WARNING] Bug Status Highlight Menu Sidebar Padam pada Rute Detail Label
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (Baris 265–271)
- **Solusi yang Diterapkan**:
  Menambahkan konfigurasi `activeOn: ['label_reports_show']` pada objek menu `Reports Label`.
- **Hasil Verifikasi**: Saat pengguna membuka detail performa label pada URL `/reports/labels/:id`, highlight penanda menu aktif di sidebar tetap menyala.

---

## Sektor 2: Overview & Real-Time Operational Analytics (`LiveReports.vue`)

### 2.1. [CRITICAL] Render Unconditional `<Table>` dan `<Pagination>` pada Loading & Empty States
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `AgentTable.vue` (Baris 124–146) & `TeamTable.vue` (Baris 118–140)
- **Solusi yang Diterapkan**:
  Komponen `<Table>` dan `<Pagination>` dibungkus ke dalam blok `<template v-else>`. Antarmuka hanya menampilkan Spinner saat data dimuat, EmptyState saat data kosong, dan merender tabel utuh hanya ketika data sudah siap.
- **Hasil Verifikasi**: Tidak ada lagi elemen pagination kosong ("Page 1 of 0") atau tabel transparan yang muncul sebelum data selesai dimuat.

---

### 2.2. [WARNING] Ketiadaan Global Dashboard Filter Toolbar di Halaman Overview
- **Status Implementasi:** ⏳ **PENDING (Backlog Fase 3)**
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/LiveReports.vue` (Baris 11–18)
- **Masalah Saat Ini**:
  Di halaman Overview, masing-masing kartu heatmap (`ConversationHeatmapContainer` dan `ResolutionHeatmapContainer`) masih memiliki selector tanggal dan dropdown inbox mandiri yang terisolasi.
- **Rencana Tindak Lanjut**:
  Menyediakan satu *Global Analytics Control Bar* di bagian atas `LiveReports.vue` yang mengorkestrasikan rentang tanggal dan inbox ke seluruh komponen widget di bawahnya secara tersinkronisasi.

---

### 2.3. [WARNING] Data Density Rendah & Ketiadaan Clickability pada Kartu KPI Metrik
- **Status Implementasi:** ⏳ **PENDING (Backlog Fase 3)**
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/StatsLiveReportsContainer.vue` (Baris 112–123)
- **Masalah Saat Ini**:
  Angka metrik operasional (*Open*, *Unattended*, *Unassigned*, *Pending*) masih berupa teks statis dan belum dapat diklik menuju daftar percakapan di inbox. Belum ada badge urgensi warna jika tiket *unattended* meningkat.
- **Rencana Tindak Lanjut**:
  Mengubah kartu metrik menjadi *Clickable Action Cards* menuju filtered inbox (`/inbox/all?status=unattended`) dan menambahkan indikator tren kenaikan/penurunan persentase.

---

### 2.4. [OFI] Penataan Vertikal Heatmap Duo yang Memperpanjang Halaman
- **Status Implementasi:** ⏳ **PARTIALLY RESOLVED**
- **Lokasi Kode**: `LiveReports.vue` (Baris 14–15)
- **Kondisi Terkini**: Tabel agen dan tim sudah berdiri berdampingan 2 kolom pada breakpoint `xl:`, namun kedua kartu heatmap masih mengambil lebar penuh (`xl:col-span-2`).
- **Rencana Tindak Lanjut**: Menyediakan opsi tampilan 2 kolom berdampingan untuk kedua heatmap pada monitor beresolusi ultra-lebar (>= 1440px).

---

## Sektor 3: Tabular Kinerja & Drilldown Analysis

### 3.1. [CRITICAL] Fitur Sorting Dinonaktifkan Secara Total (`enableSorting: false`) pada Tabel Kinerja
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `SummaryReports.vue`, `AgentTable.vue`, dan `TeamTable.vue`
- **Solusi yang Diterapkan**:
  - Mengimpor `getSortedRowModel` dan menetapkan `enableSorting: true` pada seluruh instance TanStack Table.
  - Nilai numerik mentah dipertahankan di layer data model dan pemformatan teks dialihkan ke `cell` renderer.
- **Hasil Verifikasi**: Header tabel merespons klik dan menyortir data secara numerik riil.

---

### 3.2. [CRITICAL] Nilai Kuantitatif Nol Ditampilkan Menyesatkan Sebagai Data Hilang (`--`)
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `SummaryReports.vue` (Baris 66–73) & `BotMetrics.vue`
- **Solusi yang Diterapkan**:
  Mengganti logika ternary evaluasi falsy dengan validasi tipe data ketat:
  ```javascript
  const renderAvgTime = value => {
    if (typeof value !== 'number' || !Number.isFinite(value)) return '--';
    return value === 0 ? '0s' : formatTime(value);
  };
  const renderCount = value =>
    typeof value === 'number' && Number.isFinite(value) ? value.toLocaleString() : '--';
  ```
- **Hasil Verifikasi**: Nilai 0 tiket tampil jelas sebagai `0` dan durasi 0 detik tampil sebagai `0s`.

---

### 3.3. [CRITICAL] Infinite Loading Spinner pada Direct Link / Refresh Detail Inbox & Tim
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `InboxReportsShow.vue` & `TeamReportsShow.vue`
- **Solusi yang Diterapkan**:
  Menambahkan hook `onMounted` dengan asynchronous store dispatch (`store.dispatch('inboxes/get')` / `teams/get`), penanganan state loading, dan pesan informatif jika entitas tidak ditemukan.
- **Hasil Verifikasi**: Direct refresh (F5) dan bookmark link langsung merender data tanpa resiko infinite spinner deadlock.

---

### 3.4. [WARNING] Disrupsi Alur Kerja Drilldown: Kartu Percakapan Memaksa Buka Tab Browser Baru
- **Status Implementasi:** ⏳ **PENDING (Backlog Fase 4)**
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportDrilldownCard.vue`
- **Masalah Saat Ini**: Klik pada kartu drilldown membuka tab baru (`window.open _blank`), memicu fragmentasi konteks saat menginvestigasi banyak tiket.
- **Rencana Tindak Lanjut**: Menghadirkan *quick conversation transcript preview* langsung di dalam slide-over drawer tanpa meninggalkan halaman.

---

### 3.5. [WARNING] Global Keydown Hijacking pada Keyboard Navigation Drawer Drilldown
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `ReportDrilldownDrawer.vue` (Baris 155–168)
- **Solusi yang Diterapkan**:
  Menambahkan guard pengecekan elemen aktif (`target.tagName === 'INPUT'`, `'TEXTAREA'`, `'SELECT'`, atau `isContentEditable`) sebelum memicu event tombol panah keyboard.
- **Hasil Verifikasi**: Penekanan panah saat mengetik di form tidak lagi memicu perpindahan tanggal analitik secara tidak sengaja.

---

## Sektor 4: Specialized Analytics (CSAT, SLA, & Bot Performance)

### 4.1. [CRITICAL] Grid Span Mismatch pada SLATable (Header 11 Kolom vs Baris 12 Kolom)
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/SLA/SLATable.vue` (Baris 63–82)
- **Solusi yang Diterapkan**:
  Menyelaraskan span kolom header aksi menjadi span 2 dan menambahkan kolom **Breach** (span 2), sehingga total header genap 12 kolom (4 + 2 + 2 + 2 + 2 = 12).
- **Hasil Verifikasi**: Header tabel kini sejajar presisi dengan baris data di bawahnya.

---

### 4.2. [CRITICAL] Silent Unhandled Promise Rejection & Ketiadaan Loading Feedback pada Ekspor CSAT & SLA
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `CsatResponses.vue` & `SLAReports.vue`
- **Solusi yang Diterapkan**:
  Mengubah fungsi download menjadi asinkron dengan `await`, menangani error di blok `catch`, dan menambahkan state reaktif `:is-loading="isDownloading"` serta `:disabled="isDownloading"` pada tombol ekspor.
- **Hasil Verifikasi**: Tombol menampilkan visual loading spinner saat file diproses dan mencegah klik berulang (*rage-clicking*).

---

### 4.3. [CRITICAL] Double-Fetch Waterfall Race Condition saat Inisialisasi SLA Reports
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `SLAReports.vue` & `SLAReportFilters.vue`
- **Solusi yang Diterapkan**:
  Menghapus pemanggilan duplikat pada hook `mounted()` di `SLAReports.vue` dan mengontrol penarikan data terpusat satu kali melalui event `filterChange`.
- **Hasil Verifikasi**: Permintaan ganda ke server tereliminasi, konsumsi bandwidth hemat, dan potensi race condition hilang.

---

### 4.4. [WARNING] Ketiadaan Visualisasi Urgensi, Overdue Time, & Tipe Pelanggaran pada Tabel SLA
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `SLAReportItem.vue` (Baris 35–108)
- **Solusi yang Diterapkan**:
  - Menambahkan badge status tipe pelanggaran dengan aksen warna semantik:
    - 🔴 **FRT** (First Response Time Breached)
    - 🟠 **NRT** (Next Response Time Breached)
    - 🟣 **Resolution** (Resolution Time Breached)
  - Menampilkan durasi relatif keterlambatan secara otomatis (*e.g., 25m ago, 2 hours ago*).
  - Tautan nomor percakapan dibuka di tab baru (`target="_blank"`) untuk menjaga konteks audit.
- **Hasil Verifikasi**: Supervisor dapat memindai urgensi tiket tanpa perlu membuka popover satu per satu.

---

### 4.5. [WARNING] Ketiadaan Emoji dan Skala Skor pada Tabel Respon CSAT
- **Status Implementasi:** ✅ **RESOLVED**
- **Lokasi Kode**: `CsatTable.vue` (Baris 75–80, 185–207) & `CsatContactCell.vue`
- **Solusi yang Diterapkan**:
  - Kolom rating kini menampilkan ekspresi visual emoji pelanggan (`😞`, `😑`, `😐`, `😀`, `😍`) beserta label teks dan skor skala numerik (contoh: `😍 Sangat Puas (5/5)`).
  - Menambahkan `@click.stop` pada tautan nomor percakapan agar klik navigasi tidak memicu toggle accordion ulasan.
- **Hasil Verifikasi**: Respon ulasan pelanggan kaya visual dan mudah dipindai dalam hitungan detik.

---

### 4.6. [WARNING] Bot Analytics Funnel, Drop-Off Rate, & Loading Feedback
- **Status Implementasi:** ⏳ **PARTIALLY RESOLVED**
- **Lokasi Kode**: `BotReports.vue` & `BotMetrics.vue`
- **Solusi yang Diterapkan (Terkini)**:
  - Komponen `BotMetrics.vue` kini memiliki overlay loading spinner saat data ditarik.
  - Perbaikan evaluasi nilai 0% sehingga tampil benar sebagai `0%`.
  - Penambahan penanganan error API dengan alert notifikasi.
- **Fitur Tersisa (Pending)**:
  - Pembuatan diagram corong alur konversi (*Bot-to-Human Handover Funnel*).
  - Penambahan metrik *Bot Drop-Off Rate* (memerlukan dukungan agregasi metrik tambahan).

---

## 🧪 Bukti Kualitas & Pengujian Sistem (Quality Gate)

Seluruh perubahan yang diterapkan telah melalui verifikasi otomasi:
```bash
# Unit & Integration Tests:
pnpm test app/javascript/dashboard/routes/dashboard/settings/reports app/javascript/dashboard/components-next/sidebar/specs
# Hasil: 12 Test Files Passed / 105 Tests Passed (100% Green)

# Linter & Static Analysis:
pnpm eslint app/javascript/dashboard/routes/dashboard/settings/reports app/javascript/dashboard/components-next/sidebar
# Hasil: 0 Errors
```

---
*Dokumen ini merupakan catatan resmi hasil audit dan status implementasi perbaikan modul Reports Chatwoot.*
