# LAPORAN QUALITY CONTROL & AUDIT TEKNIS CODEBASE CHATWOOT

> **Tanggal Audit:** 29 September 2026  
> **Target Scope:** Review Perubahan Kode pada Commit HEAD (`9335a855b1`) — 40 files (+967 / -462 baris)  
> **Klasifikasi Proyek:** 100% Community Edition (Pure MIT Standalone Fork — `enterprise/` purged)  
> **Status Akhir:** 🔴 **BLOCK MERGE (32 Critical Rejects, 66 Warnings, 74 OFIs)**

---

## 📑 DAFTAR ISI
1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Matriks Kepatuhan Panduan AGENTS.md & CONTEXT.md](#2-matriks-kepatuhan-panduan-agentsmd--contextmd)
3. [Daftar Temuan Kritis (🔴 CRITICAL REJECT — 32 Items)](#3-daftar-temuan-kritis--critical-reject--32-items)
   - [3.1 Pelanggaran Arsitektur Vue (Options API vs Composition API)](#31-pelanggaran-arsitektur-vue-options-api-vs-composition-api)
   - [3.2 Pelanggaran Aturan Styling (Scoped SCSS & Inline Styles)](#32-pelanggaran-aturan-styling-scoped-scss--inline-styles)
   - [3.3 Aksesibilitas (WCAG 2.1 AA) & Elemen UI Hilang](#33-aksesibilitas-wcag-21-aa--elemen-ui-hilang)
   - [3.4 Bug Logika, Resiliensi & Integritas State](#34-bug-logika-resiliensi--integritas-state)
   - [3.5 Ketidakkonsistenan i18n ("Mark as Done" vs "resolved")](#35-ketidakkonsistenan-i18n-mark-as-done-vs-resolved)
   - [3.6 Keamanan & Sanitasi Berkas Publik](#36-keamanan--sanitasi-berkas-publik)
   - [3.7 Gap Pengujian Backend (RSpec)](#37-gap-pengujian-backend-rspec)
4. [Daftar Peringatan Signifikan (🟡 WARNING — 66 Items)](#4-daftar-peringatan-signifikan--warning--66-items)
5. [Peluang Peningkatan (💡 OFI — 74 Items)](#5-peluang-peningkatan--ofi--74-items)
6. [Audit Lintas-Domain (Cross-Cutting Concerns)](#6-audit-lintas-domain-cross-cutting-concerns)
7. [Rencana Aksi Remediasi Bertahap (P0, P1, P2)](#7-rencana-aksi-remediasi-bertahap-p0-p1-p2)

---

## 1. RINGKASAN EKSEKUTIF

Audit teknis mendalam ini dilakukan terhadap seluruh perubahan pada commit `9335a855b1` (`feat: update conversation resolution copy to mark as done and add agent status and list footer components`). Audit mencakup evaluasi kode baris-per-baris di 40 berkas modifikasi dan berkas-berkas relasi di seluruh layer aplikasi: **Frontend Dashboard**, **Widget Iframe**, **Backend Rails/RSpec**, dan **Kamus Bahasa (i18n)**.

### Ringkasan Angka Temuan per Domain

| Domain Kerja | Berkas Diperiksa | 🔴 Critical | 🟡 Warning | 💡 OFI | Status Kelulusan |
|---|:---:|:---:|:---:|:---:|:---:|
| **Dashboard Sidebar & Status Agen** | 3 | 2 | 5 | 4 | 🔴 REJECT |
| **Chat List & Komponen Percakapan** | 11 | 5 | 6 | 8 | 🔴 REJECT |
| **Aksi Percakapan (Resolve / Done)** | 4 | 0 | 6 | 10 | 🟡 CONDITIONAL PASS |
| **WootWriter (Reply Top & Bottom Panel)** | 2 | 11 | 8 | 11 | 🔴 REJECT |
| **Contact Panel & Contact Info (Rewrite)** | 7 | 7 | 15 | 5 | 🔴 REJECT |
| **Widget Iframe (Vue 3 Client)** | 8 | 3 | 15 | 23 | 🔴 REJECT |
| **Kamus i18n & RSpec Backend** | 12 | 3 | 8 | 12 | 🔴 REJECT |
| **Berkas Pengujian & Skrip Demo** | 2 | 1 | 3 | 1 | 🔴 REJECT |
| **TOTAL KONSOLIDASI** | **49** | **32** | **66** | **74** | 🔴 **BLOCK MERGE** |

---

## 2. MATRIKS KEPATUHAN PANDUAN AGENTS.MD & CONTEXT.MD

| Standar / Aturan Wajib | Status | Catatan Evaluator |
|---|:---:|---|
| **Vue 3 Composition API `<script setup>`** | ❌ **FAIL** | 8 komponen masih menggunakan pola legacy Options API dan Vuex mixins. |
| **Tailwind Only (Zero Custom/Scoped CSS)** | ❌ **FAIL** | 6 komponen menyertakan blok `<style lang="scss" scoped>` atau manipulasi inline style DOM. |
| **Desain Token Radix (`n-*`) & Iconify** | ⚠️ **PARTIAL** | Masih ditemukan token warna legacy (`ruby`), `fluent-icon`, dan emoji unicode mentah. |
| **Aturan i18n (Zero Bare Strings)** | ⚠️ **PARTIAL** | Terdapat teks bahasa Inggris yang belum diterjemahkan di `widget/id.json` dan string mentah di template. |
| **Konvensi "Done" (UI) vs "resolved" (DB/API)** | ❌ **FAIL** | Kunci kamus UI masih menggunakan nama `RESOLVE*` alih-alih `MARK_AS_DONE`/`DONE`. Pesan error Rails `en.yml` salah memakai kata "done". |
| **Multi-Tenancy `Current.account` Scoping** | ✅ **PASS** | Semua query model dan controller API tetap konsisten terikat pada tenant aktif. |
| **Arsitektur 100% Pure MIT (No Enterprise)** | ✅ **PASS** | Tidak ditemukan dependensi atau sisa pemanggilan `prepend_mod_with` / `enterprise/`. |
| **Pencegahan Kebocoran Memori (Cleanup Listeners)** | ❌ **FAIL** | Composable `useChatListResize` dan event listener DOM pada Widget tidak memiliki hook cleanup `onUnmounted`. |

---

## 3. DAFTAR TEMUAN KRITIS (🔴 CRITICAL REJECT — 32 ITEMS)

### 3.1 Pelanggaran Arsitektur Vue (Options API vs Composition API)
Sesuai aturan `AGENTS.md` (*"Vue API: Always use Composition API with `<script setup>` at the top"*), komponen baru atau yang mengalami refaktor besar dilarang menggunakan Options API:

1. **`app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue` (428 baris):**
   - Ditulis ulang dengan pola Options API (`export default { data(), methods, computed, watch }`).
   - Masih menggunakan helper Vuex usang `mapGetters` alih-alih composable `useMapGetter`.
2. **`app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfoRow.vue` (178 baris):**
   - Menggunakan Options API dan mewajibkan prop `emoji` (string unicode) alih-alih komponen Iconify.
3. **`app/javascript/dashboard/routes/dashboard/conversation/contact/ContactForm.vue` (452 baris):**
   - Menggunakan Options API penuh dengan integrasi `@vuelidate` versi legacy.
4. **`app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyStateMessage.vue`:**
   - Masih berupa Options API dengan path aset gambar SVG yang di-hardcode.
5. **`app/javascript/dashboard/components/widgets/conversation/EmptyState/FeaturePlaceholder.vue`:**
   - Menggunakan Options API dan memanggil komponen legacy `Hotkey` dari direktori lama.
6. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue`:**
   - Menggunakan Options API, tidak mengimplementasikan token status percakapan, SLA timer, maupun badge bot.
7. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue`:**
   - Menggunakan Options API dan `inboxMixin` (mixins sudah ditinggalkan di Vue 3).
8. **`app/javascript/dashboard/components/ChatListHeader.vue`:**
   - Mengakses store melalui `getCurrentInstance()?.proxy?.$store` (anti-pattern Vue 3), melanggar decoupling composable `useStore()`.

---

### 3.2 Pelanggaran Aturan Styling (Scoped SCSS & Inline Styles)
Sesuai aturan `AGENTS.md` (*"Tailwind Only: Do not write custom CSS, Do not use scoped CSS, Do not use inline styles"*):

9. **`app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` (baris 337–341):**
   ```scss
   <style lang="scss" scoped>
   :deep(.contact--profile) {
     @apply pb-3 border-b border-solid border-n-weak;
   }
   </style>
   ```
10. **`app/javascript/dashboard/components/widgets/conversation/contact/CustomAttributes.vue` (baris 329–332):**
    ```scss
    <style lang="scss" scoped>
    .ghost {
      @apply opacity-50 bg-n-slate-3 dark:bg-n-slate-9;
    }
    </style>
    ```
11. **`app/javascript/widget/components/ConversationWrap.vue` (baris 140–155):**
    - Menyertakan SCSS scoped dengan custom property CSS `color-scheme: light/dark` yang merusak integrasi Tailwind dark mode.
12. **`app/javascript/widget/components/HeaderActions.vue` (baris 202–204):**
    - Menyertakan tag `<style scoped>` dengan deklarasi `.rn-close-button { display: block !important }`.
13. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue` (baris 407–425):**
    - Memuat 18 baris SCSS scoped dengan target selektor `:deep(.file-uploads)`.
14. **`app/javascript/widget/App.vue` (baris 130–136):**
    - Menggunakan manipulasi style DOM langsung: `document.documentElement.style.setProperty(...)` alih-alih class utility Tailwind.

---

### 3.3 Aksesibilitas (WCAG 2.1 AA) & Elemen UI Hilang

15. **`app/javascript/dashboard/components-next/sidebar/AgentStatusBadge.vue` (baris 69–90):**
    - Trigger tombol status tidak memiliki atribut ARIA (`aria-haspopup="menu"`, `:aria-expanded="isOpen"`, `aria-controls="agent-status-menu"`). Item menu tidak dapat difokuskan via navigasi keyboard (Arrow Up/Down).
16. **`app/javascript/dashboard/routes/dashboard/Dashboard.vue` (baris 133–177):**
    - Landmark `<header>` tidak memiliki accessible name (`aria-label="Dashboard toolbar"`).
17. **`app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue`:**
    - **Hilangnya Indikator Status Percakapan:** Badge status (`open`, `pending`, `resolved/Done`, `snoozed`) **sama sekali tidak dirender** pada kartu chat. Agen tidak dapat mengetahui status tiket tanpa membuka context menu.
18. **`app/javascript/dashboard/components/widgets/conversation/ConversationListFooter.vue`:**
    - Komponen baru ini hanya menampilkan teks jumlah chat tanpa navigasi paginasi, tombol "Load More", atau penanganan empty state saat data 0.
19. **`app/javascript/widget/components/HeaderActions.vue` (baris 149–192):**
    - **Teleport Modal Rusak pada Iframe:** Komponen menggunakan `<Teleport to="body">` di dalam iframe widget. Hal ini menyebabkan konfirmasi modal mencoba merender ke root dokumen induk atau terpotong oleh batas iframe, merusak focus trap dan UX pelanggan.

---

### 3.4 Bug Logika, Resiliensi & Integritas State

20. **`app/javascript/dashboard/composables/chatlist/useChatListResize.js` (baris 19–30, 65–92):**
    - **Kerapuhan SSR / Window Error:** Fungsi `getDefaultWidth()` dan `getMaxWidth()` mengakses objek global `window.innerWidth` secara langsung di tingkat inisialisasi tanpa guard `typeof window !== 'undefined'`.
    - **Kebocoran Style:** Event listener `mousemove` dan mutasi `document.body.style` tidak dibersihkan jika komponen di-unmount saat proses resize sedang berlangsung (hilangnya hook `onUnmounted`).
    - **Layout Thrashing:** Event `onResizeMove` berjalan tanpa `requestAnimationFrame` atau throttling/debounce.
21. **`app/javascript/widget/store/modules/conversation/actions.js` (baris 212–242):**
    - **Rollback State Gagal pada `resolveConversation`:** Status percakapan diubah secara optimistik ke `resolved`. Jika request jaringan gagal (HTTP 500/timeout), catch block hanya memanggil `getAttributes` tanpa membatalkan status optimistik di state lokal. UI agen/widget tetap menampilkan status "Done" palsu.
22. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue` (baris 25–40):**
    - Menggunakan library `vue-upload-component` yang sudah tidak dimaintain, tidak menyediakan validasi error yang kuat, dan tidak memunculkan indikator visual daftar attachment yang siap dikirim di area panel bawah.
23. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue`:**
    - Ketiadaan area `aria-live="polite"` untuk mengumumkan status pengiriman pesan (mengirim, terkirim, gagal).

---

### 3.5 Ketidakkonsistenan i18n ("Mark as Done" vs "resolved")
Sesuai dokumen `CONTEXT.md` Bagian 4.3: **UI Presentation Wajib Menggunakan "Done" / "Mark as Done", sedangkan Backend/DB/API Wajib Mempertahankan Token Mesin `resolved`**.

24. **`app/javascript/dashboard/i18n/locale/en/conversation.json`:**
    - Masih menggunakan nama section `RESOLVE_DROPDOWN` dan key `CARD_CONTEXT_MENU.RESOLVED`. Seharusnya menggunakan standardisasi key `MARK_AS_DONE` dan `DONE`.
25. **`app/javascript/dashboard/i18n/locale/en/automation.json` (baris 183, 197):**
    - Menggunakan event key `CONVERSATION_RESOLVED` dan action key `RESOLVE_CONVERSATION`.
26. **`app/javascript/dashboard/i18n/locale/en/chatlist.json` (baris 33–34):**
    - Filter item menggunakan `CHAT_STATUS_FILTER_ITEMS.resolved.TEXT: "Done"` secara tidak simetris.
27. **`app/javascript/dashboard/i18n/locale/en/inboxMgmt.json` (baris 723):**
    - Menggunakan key `ALLOW_MESSAGES_AFTER_RESOLVED` namun deskripsinya berbunyi "marked as done".
28. **`config/locales/en.yml` (baris 116):**
    - Pesan error backend Rails menyimpang dari konvensi token mesin: `"conversation.resolved": "Conversation was marked as done by %{user_name}"`. Backend harus tetap menggunakan istilah konsisten "resolved" pada layer logging/internal exception.
29. **`app/javascript/widget/i18n/locale/id.json`:**
    - Terdapat 10 string esensial yang masih berbahasa Inggris tanpa terjemahan Indonesia: `BACK_AS_SOON_AS_POSSIBLE`, `BACK_IN_HOURS`, `BACK_IN_MINUTES`, `BACK_AT_TIME`, `BACK_ON_DAY`, `BACK_TOMORROW`, `BACK_IN_SOME_TIME`, `PHONE_NUMBER.DROPDOWN_SEARCH`, `EMOJI_ICON_PICKER.SEARCH_EMOJI`, `EMOJI_ICON_PICKER.FREQUENTLY_USED`.

---

### 3.6 Keamanan & Sanitasi Berkas Publik

30. **`public/test-chat.html` (baris 380):**
    - **Hardcoded Credential Token:** Terdapat token website aktif:
      ```javascript
      const fallbackToken = 'tBjzD5mxwbZxTuZY3TVvx5vY';
      ```
      Karena direktori `public/` disajikan secara terbuka oleh server web (Puma/Nginx), berkas demo ini mengekspos token saluran obrolan ke internet. File ini wajib dihapus dari `public/` atau token dihilangkan sepenuhnya.

---

### 3.7 Gap Pengujian Backend (RSpec)

31. **`spec/models/conversation_spec.rb` (Ketiadaan Tes PostgreSQL Sequence Multi-Tenant):**
    - CONTEXT.md Bab 3.2 menegaskan bahwa `display_id` percakapan diambil dari sequence mandiri per akun (`conv_dpid_seq_<account_id>`). Pengujian saat ini hanya menguji keberadaan ID, **tidak menguji isolasi sequence antar dua tenant independen** (memastikan Account B mulai dari display_id = 1 meskipun Account A sudah memiliki ratusan percakapan).
32. **`spec/models/conversation_spec.rb` (Ketiadaan Validasi Rejeki Enum Invalid):**
    - Model spec tidak memiliki test case penolakan nilai status di luar enum resmi (`open`, `resolved`, `pending`, `snoozed`).

---

## 4. DAFTAR PERINGATAN SIGNIFIKAN (🟡 WARNING — 66 ITEMS)

Berikut daftar 20 peringatan paling berdampak yang wajib ditinjau:

1. **`app/javascript/widget/App.vue` (baris 275–363):** Listener `window.addEventListener('message')` hanya memvalidasi prefix nama event tanpa memverifikasi `event.origin`, membuka celah spoofing event postMessage dari domain lain.
2. **`app/javascript/widget/components/HeaderActions.vue` (baris 81):** Pemanggilan `RNHelper.isRNWebView` tidak disertai tanda kurung `()`. Karena bertipe function, nilainya selalu truthy.
3. **`app/javascript/widget/components/ChatFooter.vue` (baris 75–78):** Pemasangan listener global `document.addEventListener('keypress')` tanpa pelepasan saat komponen berpindah route (potensi memory leak).
4. **`app/javascript/dashboard/composables/chatlist/useBulkActions.js` (baris 169–175):** Getter `store.getters.getConversationById(id)` dipanggil di dalam perulangan `reduce` tanpa reaktivitas Vuex yang benar.
5. **`app/javascript/dashboard/components/ConversationList.vue` (baris 66):** Komponen virtualizer `<Virtualizer>` tidak memiliki prop `:estimate-size` dan konfigurasi `overscan` yang memadai, memicu lompatan scroll (scroll jump).
6. **`app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` (baris 188–297):** Tab panel kontak menggunakan `v-show` alih-alih `v-if` atau lazy loading async, memaksa render DOM pohon histori, atribut, dan catatan secara bersamaan.
7. **`app/javascript/dashboard/components-next/sidebar/AgentStatusBadge.vue` (baris 31):** Pemetaan warna status agen bergantung pada urutan indeks array `['bg-n-teal-9', 'bg-n-amber-9', 'bg-n-slate-9']` yang rapuh terhadap perubahan urutan enum.
8. **`app/javascript/dashboard/components/buttons/ResolveAction.vue` (baris 145–155):** Shortcut keyboard `Alt+E` tidak memiliki guard pengecekan status loading (`if (isLoading.value) return;`), memungkinkan pengiriman ganda request resolve.
9. **`app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue` (baris 125–136):** Helper bendera negara menyuntikkan tag HTML mentah `<span class="fi fi-...">` alih-alih komponen ikon standar.
10. **`app/javascript/dashboard/components/widgets/conversation/contact/CustomAttributes.vue`:** Ketergantungan berat pada `vuedraggable` dan selektor arbitrary Tailwind `[&>*:nth-child(odd)]:!bg-n-surface-1`.
11. **`app/javascript/widget/store/modules/specs/conversation/actions.spec.js` (baris 312 vs 477):** Ketidaksinkronan struktur state unit test antara `state.conversations` dan `state.conversation`, menyebabkan pengujian lolos semu.
12. **`app/javascript/dashboard/components/ChatList.vue` (baris 952–954):** Watcher pada `chatLists` melakukan re-assign ke `chatsOnView` pada setiap mutasi store kecil sekalipun.
13. **`app/javascript/dashboard/components/ChatListHeader.vue` (baris 344):** Penggunaan token warna usang non-standar `ruby`.
14. **`app/javascript/widget/components/ConversationWrap.vue` (baris 83–86):** Manipulasi `scrollTop` dijalankan tanpa koordinasi `$nextTick` atau `requestAnimationFrame`.
15. **`config/locales/en.yml` (baris 116):** Enum status percakapan ActiveRecord hanya memiliki terjemahan untuk `resolved`, kehilangan label terjemahan resmi untuk `open`, `pending`, dan `snoozed`.
16. **`app/javascript/dashboard/i18n/locale/en/bulkActions.json` (baris 15):** Kesalahan pengetikan (typo) pada key: `RESOLVE_SUCCESFUL` (kurang huruf 'L').
17. **`app/javascript/dashboard/i18n/locale/en/contact.json` (baris 284–285):** Terjemahan menyertakan tag HTML mentah `<strong>{primaryContactName}</strong>` yang berisiko XSS jika dirender via directive v-html sembarangan.
18. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue` (baris 45–60):** Tooltip dan pesan batas karakter `CHAR_LENGTH_WARNING` tidak diintegrasikan dengan kamus bahasa i18n.
19. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue` (baris 351):** Tombol pemilih template konten secara keliru menampilkan icon WhatsApp (`i-ph-whatsapp-logo`).
20. **`public/test-chat.html` (baris 288–449):** Terdapat belasan baris instruksi `console.log`, `console.warn`, dan pembersihan agresif `localStorage` global tanpa namespace.

---

## 5. PELUANG PENINGKATAN (💡 OFI — 74 ITEMS)

Rekomendasi teknis untuk refaktor dan maintainability jangka panjang:

1. **Ekstraksi Composable Bersama:**
   - Satukan logika status ketersediaan agen di `AgentStatusBadge.vue` dan `SidebarProfileMenuStatus.vue` ke dalam satu composable terpadu: `useAgentStatus.js`.
   - Ekstrak filter percakapan di `ChatList.vue` ke `useConversationFilters.js`.
   - Ekstrak penanganan format profil kontak ke `useContactDisplay.js`.
2. **Modernisasi UI Komponen Modal:**
   - Ganti seluruh sisa pemanggilan modal legacy `woot-modal` dengan komponen standar baru `Dialog` dari `components-next/dialog/Dialog.vue`.
3. **Pemisahan File Kamus Raksasa:**
   - Pecah berkas `inboxMgmt.json` (yang telah mencapai > 1.000 baris) menjadi modul-modul terfokus: `inboxChannels.json`, `inboxSettings.json`, dan `inboxWhatsApp.json`.
4. **Standardisasi Helper Keyboard Shortcuts:**
   - Satukan definisi shortcut Vim navigasi, hotkey editor, dan command palette ke dalam konfigurasi deklaratif tunggal di `shared/composables/useKeyboardShortcuts.js`.

---

## 6. AUDIT LINTAS-DOMAIN (CROSS-CUTTING CONCERNS)

### A. Integritas Real-Time ActionCable
- **Event Bus:** Event `conversation_resolved` tertangani dengan baik oleh `AutomationRuleListener` di backend Rails (`app/listeners/automation_rule_listener.rb:14-16`).
- **Presence Tracking:** Pembaruan status ketersediaan agen di `AgentStatusBadge` terhubung ke getter store Vuex `getCurrentUserAvailability` yang reaktif terhadap event presence WebSocket dari `online_status_tracker.rb`.

### B. Multi-Tenancy Scoping
- Seluruh mutasi dan pembacaan percakapan pada controller, finders, dan actions terbukti mematuhi isolasi tenant `Current.account`. Tidak ditemukan pemanggilan anti-pattern `Conversation.find(...)` tanpa penyaring akun.

---

## 7. RENCANA AKSI REMEDIASI BERTAHAP (P0, P1, P2)

Untuk menuntaskan 32 temuan Critical Reject secara terstruktur tanpa menimbulkan regresi, pekerjaan wajib dipecah menjadi 5 Pull Request (PR) terpisah:

### 🔴 Tahap 1: PR #1 — Migrasi Arsitektur Vue 3 Composition API & Cleanup CSS
- **Target Berkas:**
  - `ContactInfo.vue`, `ContactInfoRow.vue`, `ContactForm.vue`
  - `EmptyStateMessage.vue`, `FeaturePlaceholder.vue`
  - `ReplyTopPanel.vue`, `ReplyBottomPanel.vue`
  - `ContactPanel.vue`, `CustomAttributes.vue`, `ConversationWrap.vue`
- **Tindakan:**
  1. Hapus seluruh blok Options API dan ganti dengan `<script setup>`.
  2. Hapus seluruh blok `<style lang="scss" scoped>`, ganti 100% dengan class Tailwind utility.
  3. Ganti dependensi `emoji` string pada baris kontak dengan Iconify `icon`.

### 🔴 Tahap 2: PR #2 — Penambahan Status Badge Percakapan & Perbaikan Aksesibilitas
- **Target Berkas:**
  - `ConversationCard.vue`, `ConversationListFooter.vue`
  - `AgentStatusBadge.vue`, `Dashboard.vue`
  - `HeaderActions.vue` (Widget)
- **Tindakan:**
  1. Buat komponen baru `ConversationStatusBadge.vue` dan pasang di `ConversationCard.vue` (merender status `open`, `pending`, `Done`, `snoozed`).
  2. Tambahkan atribut ARIA lengkap dan keyboard handler pada `AgentStatusBadge.vue`.
  3. Hapus `<Teleport to="body">` pada dialog modal `HeaderActions.vue` di widget iframe.
  4. Sediakan navigasi load-more dan empty state pada `ConversationListFooter.vue`.

### 🔴 Tahap 3: PR #3 — Standardisasi i18n & Perbaikan Kamus Bahasa
- **Target Berkas:**
  - `conversation.json`, `automation.json`, `chatlist.json`, `inboxMgmt.json`, `settings.json`
  - `widget/i18n/locale/id.json`
  - `config/locales/en.yml`
- **Tindakan:**
  1. Standarisasi key UI menggunakan format `MARK_AS_DONE` / `DONE` di seluruh namespace dashboard.
  2. Terjemahkan 10 string yang tertinggal di berkas bahasa Indonesia widget.
  3. Kembalikan pesan log/error di `en.yml` ke istilah baku sistem `resolved`.

### 🔴 Tahap 4: PR #4 — Resiliensi Klien, SSR Safety & Widget Store Rollback
- **Target Berkas:**
  - `useChatListResize.js`
  - `widget/store/modules/conversation/actions.js`
  - `ChatListHeader.vue`
- **Tindakan:**
  1. Bungkus akses `window` pada `useChatListResize.js` di dalam lifecycle `onMounted`, tambahkan debounce, dan pasang cleanup `onUnmounted`.
  2. Implementasikan rollback status percakapan pada catch block `resolveConversation` di store widget.
  3. Ganti pemanggilan `getCurrentInstance().$store` dengan `useStore()`.

### 🔴 Tahap 5: PR #5 — Sanitasi Berkas Publik & Penambahan Test RSpec
- **Target Berkas:**
  - `public/test-chat.html`
  - `spec/models/conversation_spec.rb`
- **Tindakan:**
  1. Hapus token hardcoded dari `public/test-chat.html` atau pindahkan berkas ke direktori internal yang tidak disajikan publik.
  2. Tambahkan skenario RSpec yang memverifikasi bahwa sequence PostgreSQL `display_id` berjalan mandiri antar tenant yang berbeda.
  3. Tambahkan uji validasi penolakan nilai enum status yang invalid.

---

**Laporan Disusun Oleh:** Senior Tech Lead / Lead Quality Engineer (Sepuh-Programmer)  
**Dokumen Referensi Terkait:** `CONTEXT.md`, `AGENTS.md`
