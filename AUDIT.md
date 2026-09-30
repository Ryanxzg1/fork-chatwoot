# LAPORAN AUDIT & ANALISIS UI/UX MODUL REPORTS CHATWOOT

- **Target URL**       : `http://192.168.13.118:3000/app/accounts/15/reports/overview` (dan seluruh sub-menu Reports)
- **Tipe Evaluasi**     : Comprehensive UI/UX, Information Architecture (IA), Data Visualization, & Quality Engineering (QE) Usability Audit
- **Auditor**           : Tim Sepuh Analyst & QE Sub-Agents (Lead Software Analyst, Senior UI/UX & System Auditor)
- **Status Audit**      : **COMPLETED (CRITICAL OVERHAUL RECOMMENDED)**

---

## Executive Summary

Modul **Reports** pada Chatwoot saat ini mengalami masalah fundamental yang melampaui sekadar preferensi estetika visual. Evaluasi teknis mendalam terhadap kode sumber front-end (`app/javascript/dashboard/routes/dashboard/settings/reports` dan `components-next/sidebar/Sidebar.vue`) menemukan bahwa arsitektur antarmuka saat ini:
1. **Membuang >37% ruang layar desktop aktif** akibat pembatasan statis kontainer `max-w-5xl` (1024px) yang memicu tumpukan vertikal berkepanjangan (*Scroll Canyon*).
2. **Memiliki cacat fungsional kritis** seperti penonaktifan total fitur sorting pada tabel kinerja (`enableSorting: false`), evaluasi angka 0 yang keliru menjadi data hilang (`--`), infinite loader saat direct refresh halaman detail inbox/tim, dan tata letak tabel SLA yang patah/miring akibat ketidaksesuaian grid span (11 vs 12).
3. **Mengalami fragmentasi navigasi** (9 sub-menu bertumpuk tanpa kategori, tanpa ikon pembeda, dan hilangnya status highlight menu pada rute label).
4. **Menyajikan metrik pasif tanpa kemampuan tindak lanjut operasional** (*dead-end KPI cards* tanpa *click-through action* atau indikator urgensi semantik).

### Ringkasan Temuan Masalah

| Tingkat Keparahan | Jumlah Temuan | Dampak Utama |
| :--- | :---: | :--- |
| 🔴 **CRITICAL REJECT** | **8** | Bug layout patah, infinite loader, fitur esensial mati (sorting), data hilang palsu, dan silent promise rejection |
| 🟡 **WARNING** | **17** | Kerusakan hierarki navigasi, disrupsi alur kerja drilldown, inkonsistensi filter, ketiadaan indikator urgensi |
| 🔵 **OFI (Opportunity for Improvement)** | **11** | Optimasi visual scanning, emoji CSAT, perataan teks angka tabel, konvensi kode modern |
| **TOTAL TEMUAN** | **36** | Memerlukan restrukturisasi layout, filter, dan data presentation menyeluruh |

---

## Sektor 1: Information Architecture, Navigasi Sidebar, & Layout Container

### 1.1. [CRITICAL] Pembatasan Lebar Statis `max-w-5xl` Memicu "Scroll Canyon" dan Membuang >37% Ruang Desktop
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportsWrapper.vue` (Baris 2–5)
- **Kondisi Kode Saat Ini**:
  ```html
  <template>
    <div class="overflow-auto bg-n-surface-1 w-full px-6">
      <div class="max-w-5xl mx-auto pb-12">
        <router-view />
      </div>
    </div>
  </template>
  ```
- **Analisis Dampak UI/UX**:
  - `max-w-5xl` di Tailwind mengunci lebar maksimal di `64rem` (1024px).
  - Pada resolusi desktop standar (Full HD 1920x1080) setelah dikurangi sidebar navigasi primer dan sekunder (~280px), area viewport aktif adalah ~1640px. Akibatnya, tersisa margin kosong tanpa fungsi (*empty gutter*) selebar **~308px di sisi kiri dan ~308px di sisi kanan** (>615px atau >37% ruang layar terbuang sia-sia). Pada monitor 2K (1440p) dan ultrawide, pemborosan mencapai lebih dari 55%.
  - Modul analitik membutuhkan ruang horizontal untuk menyajikan data matriks (Heatmap 24 jam x 7 hari = 168 sel, serta tabel komparasi multi-kolom). Karena dipaksa masuk ke dalam 1024px, seluruh komponen di `LiveReports.vue` terpaksa ditumpuk ke bawah menjadi satu kolom vertikal yang sangat panjang (*Scroll Canyon*). Supervisor harus menggulir ribuan piksel ke bawah hanya untuk melihat tabel performa tim.
- **Rekomendasi Solusi**:
  - Ganti pembungkus di `ReportsWrapper.vue` menjadi fluida adaptif: `w-full max-w-[96rem] mx-auto px-6 py-6`.
  - Terapkan sistem grid multi-kolom pada breakpoint layar lebar (`xl:` dan `2xl:`).

---

### 1.2. [WARNING] Fragmentasi Menu Navigasi Sidebar (9 Sub-menu Datar Tanpa Kategori)
- **Lokasi Kode**: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (Baris 491–523)
- **Kondisi Kode Saat Ini**:
  ```javascript
  {
    name: 'Reports',
    label: t('SIDEBAR.REPORTS'),
    icon: 'i-lucide-chart-spline',
    children: [
      { name: 'Report Overview', ... },
      { name: 'Report Conversation', ... },
      ...reportRoutes.value, // Agents, Labels, Inboxes, Teams
      { name: 'Reports CSAT', ... },
      { name: 'Reports SLA', ... },
      { name: 'Reports Bot', ... },
    ],
  }
  ```
- **Analisis Dampak UI/UX**:
  - **Cognitive Overload**: 9 sub-item disajikan datar tanpa pengelompokan tematik: *Overview, Conversations, Agents, Labels, Inboxes, Teams, CSAT, SLA, Bot*. Pengguna tidak diberikan batasan yang jelas antara pemantauan operasional *real-time* (Overview), evaluasi volume & efisiensi historis (Conversations, Inboxes, Agents, Labels, Teams), dan audit kepatuhan/kualitas layanan (CSAT, SLA, Bot).
  - **Ketiadaan Ikon Pembeda**: Sub-menu laporan tidak memiliki ikon Lucide individual, berbeda dengan menu *Settings* atau *Contacts*. Hal ini memperlambat pemindaian visual (*visual scanning speed*).
  - **Inkonsistensi Naming**: Format penamaan campur aduk antara bentuk jamak dan tunggal: "Conversations", "Agents", "Labels" (plural), sedangkan "Inbox", "Team" (singular).
- **Rekomendasi Solusi**:
  Restrukturisasi 9 sub-menu ke dalam 3 grup logis dengan ikon pembeda visual:
  ```
  📊 Reports
    ├── 🟢 Operations
    │     └── [i-lucide-activity] Live Overview
    ├── 📈 Performance & Volume
    │     ├── [i-lucide-message-square] Conversations
    │     ├── [i-lucide-users] Agents
    │     ├── [i-lucide-users-round] Teams
    │     ├── [i-lucide-inbox] Inboxes
    │     └── [i-lucide-tag] Labels
    └── 🎯 Quality & Compliance
          ├── [i-lucide-smile] CSAT Responses
          ├── [i-lucide-timer] SLA Metrics
          └── [i-lucide-bot] Bot Performance
  ```

---

### 1.3. [WARNING] Bug Status Highlight Menu Sidebar Padam pada Rute Detail Label
- **Lokasi Kode**: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (Baris 265–268)
- **Kondisi Kode Saat Ini**:
  ```javascript
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    to: accountScopedRoute('label_reports_index'),
    // TIDAK MEMILIKI activeOn!
  }
  ```
- **Analisis Dampak UI/UX**:
  Rute Agent, Inbox, dan Team memiliki `activeOn: ['agent_reports_show']`, `['inbox_reports_show']`, `['team_reports_show']`. Namun rute Label tidak menyertakan `activeOn: ['label_reports_show']`.
  Saat pengguna mengklik label tertentu pada URL `/reports/labels/:id`, highlight penanda menu aktif di sidebar seketika mati/padam. Pengguna kehilangan orientasi posisi di dalam aplikasi.
- **Rekomendasi Solusi**:
  Tambahkan `activeOn: ['label_reports_show']` pada objek menu `Reports Label`.

---

## Sektor 2: Overview & Real-Time Operational Analytics (`LiveReports.vue`)

### 2.1. [CRITICAL] Render Unconditional `<Table>` dan `<Pagination>` pada Loading & Empty States
- **Lokasi Kode**:
  - `app/javascript/dashboard/routes/dashboard/settings/reports/components/overview/AgentTable.vue` (Baris 124–146)
  - `app/javascript/dashboard/routes/dashboard/settings/reports/components/overview/TeamTable.vue` (Baris 118–140)
- **Kondisi Kode Saat Ini**:
  ```html
  <template>
    <div class="flex flex-col flex-1">
      <Table :table="table" class="max-h-[calc(100vh-21.875rem)]" />
      <Pagination
        class="mt-2"
        :table="table"
        show-page-size-selector
        :default-page-size="getPageSize()"
        @page-size-change="handlePageSizeChange"
      />
      <div v-if="isLoading" class="items-center flex text-base justify-center p-8">
        <Spinner />
        <span>{{ $t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.LOADING_MESSAGE') }}</span>
      </div>
      <EmptyState v-else-if="!isLoading && !agents.length" :title="..." />
    </div>
  </template>
  ```
- **Analisis Dampak UI/UX**:
  - Komponen `<Table>` dan `<Pagination>` dirender tanpa pengondisian `v-if`. Keduanya selalu muncul di DOM.
  - Saat data dimuat (`isLoading: true`), pengguna melihat header tabel kosong dan bilah pagination, sementara indikator spinner muncul canggung di *bawah* pagination.
  - Saat data kosong, pengguna disajikan header tabel tanpa baris, bilah pagination ("Page 1 of 0"), dan komponen `<EmptyState>` di bawahnya.
  - Ini adalah cacat hierarki visual status (*state display hierarchy*).
- **Rekomendasi Solusi**:
  Terapkan blok kondisional terstruktur dengan skeleton/spinner saat loading, empty state saat data kosong, dan hanya render tabel beserta pagination saat data riil tersedia:
  ```html
  <div v-if="isLoading" class="p-8 flex justify-center items-center">
    <Spinner />
  </div>
  <EmptyState v-else-if="!tableData.length" :title="..." />
  <template v-else>
    <Table :table="table" />
    <Pagination :table="table" ... />
  </template>
  ```

---

### 2.2. [WARNING] Ketiadaan Global Dashboard Filter Toolbar di Halaman Overview
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/LiveReports.vue` (Baris 11–18)
- **Kondisi Kode Saat Ini**:
  ```html
  <template>
    <ReportHeader :header-title="$t('OVERVIEW_REPORTS.HEADER')" />
    <div class="flex flex-col gap-4 pb-6">
      <StatsLiveReportsContainer />
      <ConversationHeatmapContainer />
      <ResolutionHeatmapContainer />
      <AgentLiveReportContainer />
      <TeamLiveReportContainer />
    </div>
  </template>
  ```
- **Analisis Dampak UI/UX**:
  - Di halaman `LiveReports.vue`, tidak ada global filter toolbar terpadu di bagian atas.
  - Masing-masing kartu heatmap (`ConversationHeatmapContainer` dan `ResolutionHeatmapContainer`) memiliki selector tanggal dan dropdown inbox mandiri yang terisolasi.
  - Manajer yang ingin menganalisis performa inbox tertentu dalam 7 hari terakhir terpaksa memilih tanggal dan inbox dua kali secara terpisah pada masing-masing kartu.
- **Rekomendasi Solusi**:
  Sediakan satu *Global Analytics Control Bar* di bagian atas `LiveReports.vue` (Date Range Selector, Inbox Filter, Team Filter, dan Business Hours Toggle) yang mengorkestrasi state filter ke seluruh visualisasi di bawahnya secara tersinkronisasi.

---

### 2.3. [WARNING] Data Density Rendah & Ketiadaan Clickability pada Kartu KPI Metrik
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/StatsLiveReportsContainer.vue` (Baris 112–123)
- **Analisis Dampak UI/UX**:
  - Angka metrik operasional (*Open*, *Unattended*, *Unassigned*, *Pending*) dan status agen (*Online*, *Busy*, *Offline*) hanya dirender sebagai teks statis polos (`text-3xl`).
  - **Dead-End UX**: Ketika supervisor melihat angka "14 Unattended" atau "8 Unassigned", angka tersebut tidak dapat diklik. Mengklik kartu tidak membawa supervisor ke daftar percakapan terkait di inbox, memutuskan alur investigasi langsung.
  - **Ketiadaan Urgensi Semantik**: Tidak ada warna peringatan jika tiket belum tertangani meningkat (seharusnya berwarna amber/merah saat *unattended* > 0).
  - **Ketiadaan Indikator Tren**: Tidak ada penanda delta persentase perbandingan (*trend indicator*) terhadap periode sebelumnya.
- **Rekomendasi Solusi**:
  - Ubah kartu metrik menjadi *Clickable Action Cards* yang otomatis membuka antarmuka inbox dengan query filter terkait (`/app/accounts/:id/inbox/all?status=unattended`).
  - Tambahkan badge status semantik (merah/oranye/hijau) berdasarkan batas ambang (*threshold*).
  - Tampilkan sparkline tren kecil atau delta persentase (misal: `+12% vs kemarin`).

---

### 2.4. [OFI] Penataan Vertikal Heatmap Duo yang Memperpanjang Halaman
- **Lokasi Kode**: `LiveReports.vue` (Baris 14–15)
- **Analisis Dampak UI/UX**:
  Dua grafik heatmap (*Conversation Volume Heatmap* dan *Resolution Speed Heatmap*) ditumpuk vertikal satu per satu. Pada layar widescreen (>= 1280px), kedua kartu ini memakan ketinggian vertikal >900px.
- **Rekomendasi Solusi**:
  Dengan melebarkan layout kontainer dari `max-w-5xl` ke `w-full max-w-[96rem]`, posisikan kedua heatmap ini berdampingan secara seimbang (2 kolom: Kiri = Volume Masuk, Kanan = Kecepatan Resolusi) pada layar desktop.

---

## Sektor 3: Tabular Kinerja & Drilldown Analysis

### 3.1. [CRITICAL] Fitur Sorting Dinonaktifkan Secara Total (`enableSorting: false`) pada Tabel Kinerja
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/SummaryReports.vue` (Baris 173)
- **Kondisi Kode Saat Ini**:
  ```javascript
  const table = useVueTable({
    get data() { return tableData.value; },
    get columns() { return columns.value; },
    enableSorting: false,
    getCoreRowModel: getCoreRowModel(),
  });
  ```
- **Analisis Dampak UI/UX**:
  - Fitur pengurutan (sorting) dinonaktifkan secara sengaja (`enableSorting: false`) pada tabel kinerja (Agents, Inboxes, Teams, Labels).
  - Manajer atau auditor **sama sekali tidak dapat mengurutkan kolom** untuk mengidentifikasi:
    * Agen dengan rata-rata waktu resolusi terlama (*worst SLA performers*).
    * Inbox dengan beban volume tiket tertinggi.
    * Tim dengan jumlah tiket terselesaikan terbanyak.
  - Selain itu, fungsi pemformatan di baris 111–133 memformat angka menjadi teks string terformat sebelum masuk ke TanStack Table (`renderCount`, `renderAvgTime`). Jika sorting diaktifkan tanpa accessor numerik mentah, pengurutan akan berjalan alfabetis (misal `"10m"` mendahului `"2m"`).
- **Rekomendasi Solusi**:
  1. Ubah konfigurasi menjadi `enableSorting: true` dan daftarkan `getSortedRowModel: getSortedRowModel()`.
  2. Pertahankan nilai numerik mentah (*raw seconds / integer counts*) pada data model, lalu gunakan fungsi pemformatan (*formatter*) hanya pada definisi `cell` renderer di `columnHelper` agar logika sorting mengacu pada perbandingan angka riil.

---

### 3.2. [CRITICAL] Nilai Kuantitatif Nol Ditampilkan Menyesatkan Sebagai Data Hilang (`--`)
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/SummaryReports.vue` (Baris 108–110)
- **Kondisi Kode Saat Ini**:
  ```javascript
  const renderAvgTime = value => (value ? formatTime(value) : '--');
  const renderCount = value => (value ? value.toLocaleString() : '--');
  ```
- **Analisis Dampak UI/UX**:
  - Di JavaScript, angka `0` bernilai *falsy* (`Boolean(0) === false`).
  - Akibat ternary di atas, setiap metrik kuantitatif yang bernilai `0` (misalnya agen yang melayani 0 percakapan dalam rentang filter) akan ditampilkan sebagai tanda hubung ganda `'--'`.
  - Hal ini menyesatkan audiens bisnis: tanda `--` mengindikasikan data kosong/gagal ditarik (*null / missing value*), padahal nilai `0` adalah hasil pengukuran valid yang menunjukkan ketidakaktifan atau ketiadaan tiket.
- **Rekomendasi Solusi**:
  Gunakan pengecekan tipe data numerik eksplisit:
  ```javascript
  const renderCount = value => (typeof value === 'number' ? value.toLocaleString() : '-');
  const renderAvgTime = value => (typeof value === 'number' && value > 0 ? formatTime(value) : (value === 0 ? '0s' : '-'));
  ```

---

### 3.3. [CRITICAL] Infinite Loading Spinner pada Direct Link / Refresh Halaman Detail Inbox & Tim
- **Lokasi Kode**:
  - `app/javascript/dashboard/routes/dashboard/settings/reports/InboxReportsShow.vue` (Baris 8–14)
  - `app/javascript/dashboard/routes/dashboard/settings/reports/TeamReportsShow.vue` (Baris 8–14)
- **Kondisi Kode Saat Ini**:
  ```javascript
  const route = useRoute();
  const inbox = useFunctionGetter('inboxes/getInboxById', route.params.id);
  // TIDAK ADA onMounted(() => store.dispatch('inboxes/get'))!
  ```
  ```html
  <template>
    <WootReports v-if="inbox.id" ... />
    <div v-else class="flex justify-center p-8">
      <Spinner />
    </div>
  </template>
  ```
- **Analisis Dampak UI/UX**:
  - Pada `AgentReportsShow.vue` dan `LabelReportsShow.vue`, terdapat hooks lifecycle `onMounted` yang men-dispatch fetch data master jika store kosong. Namun pada `InboxReportsShow.vue` dan `TeamReportsShow.vue`, dispatch store ini **alpa ditulis**.
  - Jika pengguna membuka halaman melalui direct link, bookmark, atau melakukan refresh (F5) pada URL `/reports/inboxes/:id` atau `/reports/teams/:id`, objek `inbox.id` bernilai `undefined`.
  - Halaman jatuh ke blok `v-else` dan menampilkan `<Spinner />` selamanya (*deadlock / infinite spinning loader*).
- **Rekomendasi Solusi**:
  Tambahkan `onMounted` hook untuk memanggil fetch store:
  ```javascript
  onMounted(() => {
    store.dispatch('inboxes/get'); // untuk InboxReportsShow.vue
    store.dispatch('teams/get');   // untuk TeamReportsShow.vue
  });
  ```

---

### 3.4. [WARNING] Disrupsi Alur Kerja Drilldown: Kartu Percakapan Memaksa Buka Tab Browser Baru
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportDrilldownCard.vue` (Baris 181–189, 193–200)
- **Kondisi Kode Saat Ini**:
  ```javascript
  const openInNewTab = url => {
    if (!url) return;
    window.open(url, '_blank', 'noopener,noreferrer');
  };
  const openRecord = () => {
    openInNewTab(conversationPath.value);
  };
  ```
- **Analisis Dampak UI/UX**:
  Setiap klik pada kartu drilldown percakapan secara agresif membuka jendela/tab browser baru (`window.open(url, '_blank')`). Ketika seorang auditor memeriksa lonjakan metrik (*metric spike*) dengan mengecek 10 sampel percakapan, browser akan memunculkan 10 tab baru yang memecah konsentrasi dan merusak alur kerja analitik (*context fragmentation*).
- **Rekomendasi Solusi**:
  Implementasikan secondary drawer atau slide-over modal untuk menampilkan *quick conversation transcript preview* langsung di dalam konteks layar laporan tanpa meninggalkan halaman, dengan tetap menyediakan tombol sekunder opsional *"Open in new tab"*.

---

### 3.5. [WARNING] Global Keydown Hijacking pada Keyboard Navigation Drawer Drilldown
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/ReportDrilldownDrawer.vue` (Baris 155–165)
- **Kondisi Kode Saat Ini**:
  ```javascript
  const onKeydown = event => {
    if (!props.open) return;
    if (event.key === 'ArrowLeft') navigate(-1);
    else if (event.key === 'ArrowRight') navigate(1);
  };
  useEventListener(document, 'keydown', onKeydown);
  ```
- **Analisis Dampak UI/UX**:
  Event listener tombol panah keyboard (`ArrowLeft` dan `ArrowRight`) dipasang langsung pada objek global `document` tanpa memeriksa apakah fokus kursor saat ini sedang berada pada input teks, combobox, atau textarea. Jika pengguna sedang mengetik di input saat drawer terbuka, penekanan tombol panah akan memotong aksi kursor dan memicu perpindahan tanggal analitik (*bucket navigation*) secara tidak sengaja.
- **Rekomendasi Solusi**:
  Tambahkan guard pengecekan elemen aktif:
  ```javascript
  const activeEl = document.activeElement;
  if (activeEl && ['INPUT', 'TEXTAREA', 'SELECT'].includes(activeEl.tagName)) return;
  ```

---

### 3.6. [WARNING] False Affordance: Elemen Grafik Tampak Dapat Diklik Non-Admin Namun Menghasilkan Alert Error
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/ReportContainer.vue` (Baris 224–227, 329)
- **Analisis Dampak UI/UX**:
  Prop `:clickable` pada `BarChart` diikat ke `isDrilldownEnabled()` yang hanya mengecek keberadaan filter tanggal. Grafik dirender seolah-olah dapat diklik (*clickable visual affordance*) bagi seluruh pengguna termasuk agen biasa non-administrator.
  Ketika agen non-admin mengklik grafik, sistem memunculkan pesan peringatan toast error: `"REPORT.DRILLDOWN.ADMIN_ONLY"`. Ini memberikan pengalaman pengguna yang mengecoh (*false affordance baiting*).
- **Rekomendasi Solusi**:
  Sertakan status otorisasi admin ke dalam status aktivasi interaktivitas grafik:
  ```javascript
  isDrilldownEnabled() {
    return !!(this.from && this.to && this.isAdmin);
  }
  ```

---

## Sektor 4: Specialized Analytics (CSAT, SLA, & Bot Performance)

### 4.1. [CRITICAL] Grid Span Mismatch pada SLATable (Header 11 Kolom vs Baris 12 Kolom)
- **Lokasi Kode**:
  - `app/javascript/dashboard/routes/dashboard/settings/reports/components/SLA/SLATable.vue` (Baris 63–78)
  - `app/javascript/dashboard/routes/dashboard/settings/reports/components/SLA/SLAViewDetails.vue` (Baris 37)
- **Kondisi Kode Saat Ini**:
  ```html
  <!-- Header SLATable: total span = 6 + 2 + 2 + 1 = 11 kolom -->
  <div class="grid content-center h-12 grid-cols-12 gap-4 px-6 ...">
    <TableHeaderCell :span="6" label="Conversation" />
    <TableHeaderCell :span="2" label="Policy" />
    <TableHeaderCell :span="2" label="Agent" />
    <TableHeaderCell :span="1" label="" />
  </div>

  <!-- Baris SLAViewDetails: col-span-2 -->
  <div class="flex items-center col-span-2 ... justify-end">
  ```
- **Analisis Dampak UI/UX**:
  Pada grid 12-kolom (`grid-cols-12`), komponen header mendefinisikan total span **11 kolom**, menyisakan 1 kolom kosong tanpa alokasi. Sebaliknya, pada baris data, tombol aksi menggunakan `col-span-2` sehingga total baris = **12 kolom**.
  Akibatnya, header kolom aksi **tidak sejajar dengan tombol "View Details" di bawahnya (layout tabel patah/miring ke kanan)**.
- **Rekomendasi Solusi**:
  Ubah span header action pada baris 77 `SLATable.vue` dari `:span="1"` menjadi `:span="2"` agar genap 12 kolom, atau migrasikan `SLATable` ke semantic HTML `<table>` menggunakan `@tanstack/vue-table`.

---

### 4.2. [CRITICAL] Silent Unhandled Promise Rejection & Ketiadaan Loading Feedback pada Ekspor CSAT & SLA
- **Lokasi Kode**:
  - `app/javascript/dashboard/routes/dashboard/settings/reports/CsatResponses.vue` (Baris 73–83)
  - `app/javascript/dashboard/routes/dashboard/settings/reports/SLAReports.vue` (Baris 68–78)
- **Kondisi Kode Saat Ini**:
  ```javascript
  downloadReports() {
    try {
      this.$store.dispatch('csat/downloadCSATReports', ...);
    } catch (error) {
      useAlert(...);
    }
  }
  ```
- **Analisis Dampak UI/UX**:
  - `this.$store.dispatch(...)` mengembalikan `Promise` (asinkron), namun tidak menggunakan kata kunci `await`. Blok `try...catch` sinkron tidak pernah dapat menangkap error jaringan (menghasilkan *Unhandled Promise Rejection* tak tertangani di console browser).
  - Tombol ekspor `V4Button` tidak memiliki atribut `:is-loading` atau `:disabled`. Pada dataset laporan ribuan baris, tidak ada indikator proses saat file CSV disiapkan. Pengguna yang mengira kliknya tidak direspon akan melakukan klik berulang-ulang (*rage clicks*) yang membebani server backend.
- **Rekomendasi Solusi**:
  Ubah method menjadi `async downloadReports()`, tambahkan state reaktif `isDownloading = ref(false)`, gunakan `await this.$store.dispatch(...)`, tangkap error di blok catch async, dan bind `:is-loading="isDownloading"` serta `:disabled="isDownloading"` pada tombol ekspor.

---

### 4.3. [CRITICAL] Double-Fetch Waterfall Race Condition saat Inisialisasi SLA Reports
- **Lokasi Kode**:
  - `app/javascript/dashboard/routes/dashboard/settings/reports/SLAReports.vue` (Baris 47–48)
  - `app/javascript/dashboard/routes/dashboard/settings/reports/components/SLA/SLAReportFilters.vue` (Baris 77–86)
- **Kondisi Kode Saat Ini**:
  ```javascript
  // SLAReports.vue mounted:
  this.fetchSLAMetrics();
  this.fetchSLAReports();

  // SLAReportFilters.vue mounted:
  setInitialRange(); // -> trigger emitChange() -> trigger fetchSLAMetrics & fetchSLAReports kedua kalinya!
  ```
- **Analisis Dampak UI/UX**:
  Saat halaman SLA dibuka, `SLAReports.vue` langsung memanggil API dengan parameter tanggal default (`from: 0, to: 0`). Sesaat kemudian, child component `SLAReportFilters.vue` selesai mount, menghitung rentang 7 hari, lalu menembakkan event `filterChange` yang memicu pemanggilan kedua ke API.
  Hal ini menimbulkan redundansi request ke server (2x fetch per kunjungan halaman) dan memicu *race condition* jika respons request pertama datang lebih lambat dari request kedua.
- **Rekomendasi Solusi**:
  Hapus inisialisasi manual dari `mounted()` di `SLAReports.vue`. Biarkan fetch hanya dipicu oleh event `filterChange` saat filter telah selesai menginisialisasi parameter tanggal.

---

### 4.4. [WARNING] Ketiadaan Visualisasi Urgensi, Overdue Time, & Tipe Pelanggaran pada Tabel SLA
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/SLA/SLAReportItem.vue` (Baris 41–73)
- **Analisis Dampak UI/UX**:
  Baris tabel pelanggaran SLA hanya memuat ID percakapan, nama kontak, policy, dan nama agen. **Tidak ada satupun indikator visual mengenai esensi pelanggaran**:
  1. Jenis metrik SLA yang terlanggar (apakah *First Response Time*, *Next Response Time*, atau *Resolution Time*).
  2. Waktu terjadinya breach / durasi keterlambatan (*overdue duration*, misal "Terlambat 15 menit" vs "Terlambat 4 jam").
  3. Indikator urgensi / tingkat keparahan (*color-coded badge*: merah menyala untuk breach kritis, oranye untuk moderat).
  4. Status tiket (apakah masih terbuka atau sudah selesai).
  Supervisor terpaksa mengklik tombol *"View Details"* satu per satu pada setiap baris hanya untuk mengetahui apa yang terlanggar (*high interaction cost*).
- **Rekomendasi Solusi**:
  Tambahkan badge status pelanggaran pada baris (misal badge merah `FRT Breached` / `RT Breached`), tampilkan durasi keterlambatan (*breach offset*), serta bedakan visual antara percakapan yang masih *ongoing breach* dengan yang sudah *resolved*.

---

### 4.5. [WARNING] Ketiadaan Emoji dan Skala Skor pada Tabel Respon CSAT
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/components/CsatTable.vue` (Baris 183–194)
- **Analisis Dampak UI/UX**:
  Di `shared/constants/messages.js`, setiap rating CSAT memiliki emoji (`😞`, `😑`, `😐`, `😀`, `😍`) dan nilai skor numerik 1–5. Namun pada `CsatTable.vue`, kolom Rating hanya menampilkan teks terjemahan di dalam pill warna berkontras rendah tanpa emoji visual dan tanpa angka skala skor. Hal ini menghilangkan ekspresi emosional respon pelanggan dan memperlambat pemindaian supervisor.
- **Rekomendasi Solusi**:
  Tampilkan emoji reaktif dan rating score (contoh: `😍 Sangat Puas (5/5)`) pada tabel respon dan legenda persentase distribusi.

---

### 4.6. [WARNING] Ketiadaan Fitur Ekspor Data, Hilangnya Metrik Drop-Off Rate, dan Corong Handover pada Bot Reports
- **Lokasi Kode**: `app/javascript/dashboard/routes/dashboard/settings/reports/BotReports.vue` (Baris 89–108) dan `components/BotMetrics.vue` (Baris 40–67)
- **Analisis Dampak UI/UX**:
  - Halaman CSAT dan SLA memiliki tombol unduh laporan di header, namun **halaman Bot Reports sama sekali tidak menyediakan tombol ekspor data**.
  - Metrik bot hanya menyajikan 4 kartu datar: Total Percakapan, Respon, Resolution Rate, dan Handoff Rate. Jika Resolution Rate 40% dan Handoff Rate 35%, terdapat 25% percakapan yang tidak diketahui nasibnya. Ini adalah **Bot Drop-Off / Abandonment Rate** (pengguna keluar tanpa tuntas dan tanpa minta dialihkan ke manusia) yang tidak ditampilkan sama sekali.
  - Ketiadaan diagram alur perpindahan (*Bot-to-Human Handover Funnel*): supervisor tidak dapat melihat di tahap mana bot gagal memenuhi kebutuhan pengguna.
  - Filter bot menonaktifkan filter kanal/inbox (`:show-entity-filter="false"`), sehingga manajer tidak dapat membandingkan efektivitas bot per saluran (misal Bot WhatsApp vs Bot Web Widget).
- **Rekomendasi Solusi**:
  - Tambahkan tombol ekspor laporan bot pada `ReportHeader`.
  - Hadirkan kartu metrik *Bot Drop-Off Rate* dan *Average Bot Handle Time*.
  - Sediakan visualisasi diagram Funnel Percakapan Bot: *Started -> Self-Served -> Handover -> Abandoned*.
  - Aktifkan opsi filter Inbox / Channel pada `ReportFilters`.

---

## Matriks Evaluasi: Kondisi Saat Ini (As-Is) vs Rekomendasi Solusi (To-Be)

| Komponen / Area | Kondisi Saat Ini (As-Is) | Rekomendasi Solusi (To-Be) |
| :--- | :--- | :--- |
| **Lebar Kontainer** | Dibatasi kaku `max-w-5xl` (1024px); membuang >37% lebar layar desktop. | Fluida adaptif `w-full max-w-[96rem] mx-auto px-6`; multi-kolom dashboard grid. |
| **Navigasi Sidebar** | 9 sub-menu datar tanpa grup, tanpa ikon, highlight menu Label padam di rute show. | Dikelompokkan ke 3 kategori (Operations, Volume & Performance, Quality) dengan ikon Lucide dan perbaikan rute. |
| **Kartu Metrik KPI** | Angka statis pasif; tidak bisa diklik; tidak ada indikator urgensi warna. | *Clickable Action Cards* menuju filtered inbox; badge warna semantik; delta komparasi tren. |
| **Heatmap Overview** | 2 kartu heatmap ditumpuk vertikal satu kolom panjang (*Scroll Canyon*). | 2 kolom seimbang berdampingan (Kiri: Volume Masuk, Kanan: Kecepatan Resolusi). |
| **Tabel Kinerja** | Fitur sorting dimatikan (`enableSorting: false`); angka 0 dirender sebagai `'--'`. | Sorting multi-arah aktif di semua kolom; angka 0 dirender benar (`0` / `0s`); perataan teks angka rata kanan (`text-right`). |
| **Loading State Tabel** | Header tabel & pagination dirender duluan; spinner muncul aneh di bawah pagination. | State rendering bersih: Skeleton/Spinner saat loading, EmptyState saat kosong, Tabel saat data siap. |
| **Detail Route Show** | Direct refresh me-render infinite spinner pada Inbox & Team show pages. | Lifecycle hook `onMounted` dengan fetch store hydration; breadcrumb navigasi kembali yang aman. |
| **Drilldown Percakapan** | Klik kartu memaksa buka tab browser baru (`window.open _blank`). | Quick transcript preview slide-over drawer di halaman yang sama, tombol tab baru sekunder. |
| **Tabel SLA** | Layout miring (Header 11 span vs Baris 12 span); tanpa tipe breach dan overdue duration. | Grid diselaraskan 12 span; badge status urgensi pelanggaran (FRT/RT); durasi keterlambatan eksplisit. |
| **Unduh Ekspor Laporan**| Download tanpa `await`, tanpa spinner loading; Bot Reports tidak memiliki tombol ekspor. | Asynchronous download handler dengan visual loading spinner pada tombol; tombol ekspor di Bot Reports. |
| **Tampilan CSAT** | Respon hanya teks terjemahan tanpa emoji visual dan tanpa angka skala 1–5. | Tampilan emoji reaktif (`😞` - `😍`) dan skor bintang numerik (contoh: `😍 5/5`). |
| **Metrik Bot** | Hanya 4 kartu datar tanpa metrik drop-off dan tanpa visualisasi funnel serah-terima. | Funnel serah-terima interaktif (Bot to Human), metrik drop-off rate, dan filter per kanal inbox. |

---

## Roadmap Rekomendasi Eksekusi Redesain

Untuk mengeksekusi perbaikan ini secara terukur dan minim risiko regresi, berikut pentahapan kerja yang disarankan:

### Fase 1: Perbaikan Cacat Fungsional & Integritas Data (Quick Wins)
1. **Perbaikan TanStack Table Sorting**: Aktifkan `enableSorting: true` dan daftarkan `getSortedRowModel` pada `SummaryReports.vue`, `AgentTable.vue`, dan `TeamTable.vue`.
2. **Koreksi Evaluasi Falsy Angka Nol**: Perbaiki fungsi format di `SummaryReports.vue` dan `BotMetrics.vue` agar angka `0` tidak berubah menjadi `'--'`.
3. **Perbaikan Grid Span SLATable**: Selaraskan header action di `SLATable.vue` dari span 1 menjadi span 2 agar simetris 12 kolom.
4. **Pencegahan Infinite Loader**: Tambahkan lifecycle `onMounted` store dispatch pada `InboxReportsShow.vue` dan `TeamReportsShow.vue`.
5. **Perbaikan Download Promise & Loading**: Tambahkan `await` dan state loading pada tombol download di `CsatResponses.vue` dan `SLAReports.vue`.
6. **Perbaikan Highlight Sidebar Label**: Tambahkan `activeOn: ['label_reports_show']` di `Sidebar.vue`.

### Fase 2: Transformasi Widescreen Layout & Arsitektur Navigasi
1. **Ekspansi Widescreen Kontainer**: Ganti `max-w-5xl` di `ReportsWrapper.vue` menjadi `w-full max-w-[96rem] mx-auto px-6`.
2. **Hierarki 3 Kategori Sidebar**: Kelompokkan 9 submenu laporan di `Sidebar.vue` ke dalam sekat *Operations*, *Performance & Volume*, dan *Quality & Compliance* lengkap dengan ikon Lucide.
3. **Redesain Live Overview Grid**: Tata ulang `LiveReports.vue` menjadi 2-kolom berdampingan untuk *Heatmap Duo* dan *Workload Tables Duo*.
4. **Kondisional Loading/Empty State**: Rapikan rendering `<Table>` dan `<Pagination>` pada `AgentTable.vue` dan `TeamTable.vue`.

### Fase 3: Peningkatan Interaktivitas & Standardisasi Filter
1. **Clickable Actionable KPI Cards**: Sambungkan kartu metrik di `StatsLiveReportsContainer.vue` agar mengarahkan supervisor langsung ke filter inbox percakapan terkait.
2. **Unified Filter Bar**: Satukan kontrol filter tanggal, inbox, dan tim di bagian atas halaman overview.
3. **Inline Search & Text Alignment**: Tambahkan input pencarian cepat pada tabel agen/tim dan terapkan perataan teks rata kanan (`text-right`) untuk seluruh kolom numerik.
4. **Non-Disruptive Drilldown Preview**: Sediakan preview transkrip percakapan langsung di dalam drawer alih-alih membuka paksa tab browser baru.

### Fase 4: Overhaul Pengalaman Specialized Reports (SLA, CSAT, & Bot)
1. **SLA Operations Enhancements**: Tampilkan badge tipe pelanggaran (FRT/RT), waktu keterlambatan (*overdue duration*), dan ganti popover mengambang dengan slide-over panel.
2. **CSAT Visual Experience**: Tambahkan emoji pelanggan dan skala bintang skor 1–5 pada tabel respon serta distribusi rating.
3. **Bot Lifecycle & Funnel Analytics**: Sediakan visualisasi corong alur interaksi bot (*Started -> Self-Served -> Handover -> Abandoned*), metrik drop-off rate, filter per kanal inbox, dan tombol ekspor data.

---
*Dokumen ini disusun sebagai panduan teknis implementasi redesign modul Reports Chatwoot.*
