# LAPORAN AUDIT KOMPREHENSIF CODEBASE CHATWOOT

Dokumen ini berisi hasil audit teknis, arsitektural, dan produk secara mendalam terhadap codebase Chatwoot (Community Edition / Pure MIT) yang mencakup 4 pilar utama:
1. **UI/UX & Arsitektur Frontend**
2. **System Design & Arsitektur Backend Core**
3. **Pengembangan Next Fitur & Strategic Roadmap**
4. **Pengelolaan Report, Analytics & Subsistem Rollup Data**

---

## 🏛️ EXECUTIVE ARCHITECTURAL SCORECARD

| Domain Investigasi | Skor Kesehatan (1-10) | Status | Ringkasan Kondisi Teknis |
|---|:---:|:---:|---|
| **1. UI/UX & Frontend** | **5.3 / 10** | ⚠️ Waspada | Terjebak dalam *dual-stack transition* (Vue 3 vs Options API legacy), 0 route lazy-loading pada menu settings/reports, DOM thrashing di list chat, dan pelanggaran styling Tailwind murni. |
| **2. System Design & Backend** | **5.8 / 10** | ⚠️ Waspada | Skema ID 32-bit (`:serial`) berisiko overflow pada 2.14B baris; Head-of-Line blocking pada EventDispatcher; anomali queue WhatsApp/Twilio pada prioritas rendah (`:low`); N+1 query kronis pada Jbuilder view. |
| **3. Pengembangan Next Fitur** | **6.5 / 10** | ℹ️ Potensial | Fondasi multi-LLM (`lib/llm/`) dan model marketplace sudah ada, namun webhook Tokopedia/Lazada belum menghasilkan pesan masuk (masih raw log), engine SLA hilang pasca-purge enterprise, dan campaign outbound belum di-chunk. |
| **4. Pengelolaan Report & Analytics** | **4.2 / 10** | ❌ Kritis | **Paradoks arsitektur:** sistem menulis ke tabel agregasi rollup harian tapi *read path* 100% masih scan tabel OLTP mentah (`RollupDataSource` masih TODO); ekspor CSV sinkron di thread Puma; ketiadaan indeks tanggal pada CSAT. |

---

## 1. AUDIT MENDALAM: UI/UX & ARSITEKTUR FRONTEND (`/app/javascript/dashboard`)

### A. Fragmentasi Tech Stack & State Management
1. **Dual-Stack Options API vs `<script setup>`:**
   - Dari 976 berkas `.vue`, **833 berkas** telah menggunakan `<script setup>`. Namun, **143 berkas** masih bertahan menggunakan Options API klasik atau pola hybrid anomali.
   - *Bukti Kritis:* `components/widgets/conversation/MessagesView.vue` (baris 1, 45, 56–70) mencampurkan Composition API di method `setup()` dengan deklarasi `mixins: [inboxMixin]`, `data()`, `computed: { ...mapGetters(...) }`, dan lifecycle hooks `mounted()`.
   - Di `ReplyBox.vue:105-106`, developer menggunakan shim instance proxy untuk menjembatani Options API ke hook composable:
     ```javascript
     const { proxy } = getCurrentInstance();
     useKeyboardEvents({
       Escape: { action: () => proxy.hideEmojiPicker(), allowOnFocusedInput: true },
       Enter: { action: e => { if (proxy.isAValidEvent('enter')) proxy.onSendReply(); } }
     });
     ```
     Pola `getCurrentInstance().proxy` merupakan *fragile shim pattern* yang tidak direkomendasikan oleh tim inti Vue, rentan mengalami `undefined` saat pengujian unit di Vitest atau refactoring.
2. **Ketergantungan Masif pada Vuex 4:**
   - Direktori `app/javascript/dashboard/stores/` (Pinia) hanya menampung **3 modul** (`companies.js`, `calls.js`, `callHistory.js`).
   - Direktori `app/javascript/dashboard/store/` (Vuex 4) masih mengelola **40+ modul sentral** (`conversations`, `contacts`, `inboxes`, `reports`, `notifications`, `teams`, `auth`, `macros`, dll).
   - Helper `composables/store.js:4-8` melempar runtime exception (`throw new Error('must be called in setup')`) jika fungsi dipanggil di luar konteks setup synchronous.
3. **Data Caching IndexedDB yang Kurang Efektif:**
   - Di `CacheEnabledApiClient.js:61-65`, meskipun data disimpan di IndexedDB (`DataManager`), setiap request pembacaan cache **tetap memicu round-trip HTTP synchronous** ke endpoint `/api/v1/accounts/:id/cache_keys`. Pendekatan ini menghilangkan manfaat *instant rendering* / *stale-while-revalidate*.

### B. Pelanggaran Standar Desain Sistem & Styling
1. **Pelanggaran Aturan Tailwind-Only:**
   - Panduan repo (`AGENTS.md`) secara tegas melarang scoped CSS, custom CSS, dan inline style.
   - *Temuan:* Ditemukan **30+ berkas dengan scoped SCSS** (misal: `ReplyBox.vue:1608`, `Editor.vue:143`, `Dialog.vue:182`, `contextMenu/menuItem.vue:60-81`).
   - Ditemukan **78+ berkas yang menginjeksi inline style** (misal: `ChatList.vue:1001` untuk lebar panel, `ConversationSidebar.vue:77`, `Input.vue:70`, `ResizableEditorWrapper.vue:158`).
2. **Redundansi Token Warna & Kebingungan Dark Mode:**
   - Sistem warna terbelah antara *Legacy Radix Mapping* (`woot`, `slate`, `green`, `yellow`, `red` skala 50–900) dan *Next System Tokens* (`n.slate`, `n.iris`, `n.ruby` skala 1–12 berbasis CSS Variable).
   - Di `components-next/input/Input.vue:45`, tertulis `text-n-ruby-9 dark:text-n-ruby-9`. Penulisan utilitas ganda ini redundan karena variabel `--ruby-9` di `_next-colors.scss` sudah otomatis berganti warna saat class `.dark` aktif di root HTML.
   - Di `commandbar.vue:279-284`, terdapat hardcoded hex colors (`#151718`, `#26292b`) yang mem-bypass CSS variables.

### C. Usability, Interaksi & Friction Points
1. **DOM Thrashing pada Percakapan Panjang (`MessageList.vue`):**
   - Daftar percakapan kiri (`ConversationList.vue:3, 66-71`) sudah menggunakan `Virtualizer` dari `virtua/vue`.
   - Namun area render bubble chat (`components-next/message/MessageList.vue:168-188`) masih me-render DOM mentah menggunakan `v-for="(message, index) in allMessages"` **tanpa virtualizer**. Percakapan panjang dengan ratusan pesan dan media memicu pembengkakan memori tab browser dan penurunan frame rate.
   - Di `MessageList.vue:44-52`, fungsi traversal rekursif `useCamelCase(messages, { deep: true })` dijalankan ulang terhadap **seluruh array pesan** setiap kali ada satu pesan baru masuk via ActionCable.
   - Di `MessagesView.vue:436-439`, kalkulasi scroll saat mengambil pesan lama (*prepend history*) dilakukan secara manual via DOM scroll height difference yang memicu layout thrashing.
2. **God Components:**
   - `ReplyBox.vue` (1.646 baris) dan `Editor.vue` (1.236 baris) bertindak sebagai *God Components*, menggabungkan formatting ProseMirror, audio recording, Canned Responses, Macro injection, Copilot bar, mentions, dan keyboard events secara bersamaan.
3. **Fragmentasi Validasi Form:**
   - Terdapat 3 pendekatan validasi yang bertabrakan: FormKit (`entrypoints/dashboard.js`), Vuelidate (`ForwardToOption.vue`), dan form mentah tanpa validasi sisi klien (seperti `Website.vue:43-114`). Pengguna dapat mengirim form kosong dan hanya menerima error toast banner umum dari respons backend.

### D. Aksesibilitas (A11y) & Performa Bundling
1. **Aksesibilitas (A11y) Kritis:**
   - Hanya ditemukan **44 selektor `focus-visible:`** di seluruh 976 berkas Vue. Navigasi keyboard melompat-lompat tanpa visual outline yang memadai.
   - `contextMenu/menuItem.vue:18` menggunakan `<div role="button">` tanpa `tabindex="0"` dan tanpa listener keyboard Enter/Space, melanggar WCAG 2.1 AA.
   - `useChatListKeyboardEvents.js:4-46` (shortcut `Alt+J`/`Alt+K`) melakukan `querySelectorAll('div.conversation')` langsung ke DOM fisik. Karena daftar percakapan berada di dalam Virtualizer, elemen di luar viewport tidak ada di DOM, sehingga navigasi shortcut keyboard macet saat agen menggulir ke bawah.
2. **0 Lazy Loading pada Routing (Critical Finding):**
   - Di `reports.routes.js:1-26` dan `settings.routes.js`, **seluruh komponen halaman diimpor secara STATIC/EAGER**. Agen CS biasa yang hanya bertugas melayani chat tetap dipaksa mengunduh bundle JavaScript seluruh halaman analitik dan administrasi pada load pertama.
   - `vite.config.ts` tidak mendefinisikan `manualChunks`, sehingga vendor berat (`prosemirror`, `highlight.js`, `date-fns`) bercampur secara suboptimal.
   - Terdapat **4.7 MB font statis** di `shared/assets/fonts/` dengan 18 file WOFF2 individual yang dapat dipangkas menggunakan `InterVariable.woff2`.

---

## 2. AUDIT MENDALAM: SYSTEM DESIGN & ARSITEKTUR BACKEND CORE

### A. Multi-Tenancy & Data Isolation
1. **Custom Thread Context Bukan Framework RLS:**
   - Multi-tenancy Chatwoot diimplementasikan melalui custom thread context di `lib/current.rb:1-17` (`thread_mattr_accessor`).
   - Pembersihan thread context dilakukan di controller via `RequestExceptionHandler#handle_with_exception ensure Current.reset`.
   - **Celah Background Worker:** Di sisi Sidekiq (`config/initializers/sidekiq.rb`), **tidak terdapat server middleware yang menjalankan `Current.reset`**. Pada worker threads yang digunakan kembali (*thread reuse*), state `Current` dari job sebelumnya berpotensi mencemari job berikutnya jika suatu job memodifikasi `Current`.
2. **Implicit vs Explicit Account Scoping:**
   - Di `app/finders/conversation_finder.rb:18-19`, akun diambil secara implisit via `current_user.account` yang bergantung pada `Current.account.id`. Jika method ini dieksekusi di background job tanpa setting `Current.account`, finder akan menghasilkan `nil`.
   - `ConversationPolicy` tidak mendefinisikan class `Scope` (fallback ke `ApplicationPolicy::Scope` yang mereturn record tanpa filter).
3. **IDOR / Authorization Gap pada Message Deletion:**
   - Di `Api::V1::Accounts::Conversations::MessagesController#destroy:21-26`, tidak ada pemanggilan `authorize message, :destroy?` (bahkan `MessagePolicy` tidak ada di codebase). Setiap user dengan role Agent yang memiliki akses ke percakapan dapat menghapus pesan siapapun (termasuk pesan incoming dari customer atau pesan agen lain).

### B. Polymorphic Channel Architecture
1. **Pelanggaran Open/Closed Principle (OCP) pada `SendReplyJob`:**
   - Pengiriman pesan dipusatkan secara monolitik di `SendReplyJob` (`app/jobs/send_reply_job.rb:4-31`):
     ```ruby
     CHANNEL_SERVICES = {
       'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
       'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
       # ... hardcoded hash 14 channel
     }.freeze
     ```
   - Penambahan channel baru mewajibkan modifikasi file core ini. Jika pemetaan terlewat, job gagal secara diam-diam (*silent failure*).
2. **Sinkronisasi HTTP Eksternal di Model Lifecycle:**
   - Pada `Channel::Whatsapp` (`app/models/channel/whatsapp.rb:158-160`), validasi data ActiveRecord mengeksekusi HTTP call sinkron ke provider Meta API (`validate_provider_config`).
   - Callback `before_destroy :teardown_webhooks` juga mengeksekusi network call sinkron. Hal ini memblokir koneksi database pool (`ActiveRecord connection pool starvation`). Jika Meta API mengalami lonjakan latensi (15–30 detik), thread Puma/Sidekiq akan terkunci.

### C. Event-Driven Architecture & Queue Scalability
1. **Monolithic Sequential Listener & Head-of-Line (HoL) Blocking:**
   - `AsyncDispatcher#listeners` meregistrasi 10 listeners (`app/dispatchers/async_dispatcher.rb:11-24`).
   - `EventDispatcherJob` dimasukkan ke dalam `queue_as :critical` dan mengeksekusi **10 listeners secara sekuensial dalam satu job worker**.
   - Pada saat bersamaan, `ActionCableBroadcastJob` (pengiriman real-time chat) juga berada pada `queue_as :critical`. Ketika terjadi gelombang event massal, antrian `:critical` dipenuhi oleh `EventDispatcherJob` yang melakukan komputasi berat, menahan pengiriman pesan real-time WebSocket.
2. **Thread State Corruption oleh `ActionService`:**
   - Di `AutomationRules::ActionService#perform:19-21`, terdapat blok `ensure Current.reset`. Eksekusi reset ini di tengah rantai `EventDispatcherJob` menghapus seluruh context thread (`Current.user`, `Current.account`) sebelum listener berikutnya di dalam rantai `AsyncDispatcher` selesai dieksekusi.
3. **Degradasi Ingress WhatsApp & Twilio ke Queue `:low`:**
   - Webhook Facebook, Instagram, Shopee, Tokopedia, Lazada masuk ke antrian `:default`.
   - Namun `Webhooks::WhatsappEventsJob` dan `Webhooks::TwilioEventsJob` ditempatkan pada **`queue_as :low`** (prioritas ke-7). Jika sistem sedang memproses antrean email blast atau bulk maintenance, pemrosesan pesan masuk WhatsApp pelanggan akan mengalami starvation.
4. **Distributed Lock Thrashing pada Mutex WhatsApp (Mitigasi Jitter Diterapkan):**
   - `Webhooks::WhatsappEventsJob` mengunci Redis mutex dengan TTL 30 detik dan melakukan retry jika lock gagal didapat. Ketika kontak mengirim beberapa pesan cepat sekaligus, job berikutnya memicu `LockAcquisitionError`.
   - *Mitigasi Cepat yang Diterapkan:* Opsi `jitter: 0.2` ditambahkan pada `retry_on` untuk mendistribusikan waktu bangun worker secara acak (±20%), mengeliminasi collision sinkron ke Redis.
   - *Rekomendasi Fase 2:* Terapkan event buffering / message batching di level webhook controller sebelum men-spawn job 30s lock.

### D. Skema Database, Indexing & Caching
1. **Batas Kritis Integer 32-bit (`:serial`):**
   - Kolom `id` pada tabel `messages`, `conversations`, dan `contacts` di `db/schema.rb` didefinisikan sebagai `:serial` (maksimum 2.147.483.647 baris). Pada instalasi enterprise skala tinggi, tabel `messages` berisiko mencapai limit integer dan memicu exception fatal `PG::NumericValueOutOfRange`.
2. **Write Amplification GIN Trigram:**
   - Indeks `index_messages_on_content` menggunakan `gin_trgm_ops` pada teks pesan yang sangat dinamis, menimbulkan write amplification masif dan WAL bloat pada disk PostgreSQL.
3. **Ketiadaan Partitioning & Data Retention:**
   - Tabel `messages` dan `reporting_events` tidak memiliki PostgreSQL declarative table partitioning. Data mentah pada `reporting_events` tidak pernah dihapus meskipun data agregasinya sudah masuk ke rollup.
4. **Active Record Encryption Bersyarat (Plaintext Fallback):**
   - Enkripsi kredensial channel dibungkus guard `if Chatwoot.encryption_configured?`. Jika environment variables enkripsi tidak diset saat deployment, Chatwoot tetap berjalan normal tanpa error, namun seluruh token integrasi (WhatsApp token, Shopee partner key, Tokopedia secret, SMTP password) disimpan ke database dalam format **plaintext mentah**.
5. **N+1 Query pada List Percakapan:**
   - Template `_conversation.json.jbuilder` memicu N+1 query: `messages.first` untuk cuplikan pesan terakhir (baris 35-37), `unread_incoming_messages_count` (baris 67), dan nested count di dalam `push_event_data`. Mengambil 25 percakapan menghasilkan **75–120+ query SQL** individual.
6. **ActionCable Connection Handshake Tanpa Auth:**
   - `ApplicationCable::Connection` dibiarkan kosong tanpa `identified_by`. Pengecekan status kehadiran (*presence heartbeat*) mengeksekusi query database `Account.find` dan `account_users.where` setiap 20–60 detik per active tab agen.

---

## 3. AUDIT MENDALAM: PENGEMBANGAN NEXT FITUR & STRATEGIC ROADMAP

### A. Kondisi Pasca Pembersihan Direktori Enterprise
Repo saat ini beroperasi pada **100% Community Edition (Pure MIT)** setelah pembersihan direktori `enterprise/` pada commit `d90ef430d0`. Pembersihan ini menghapus lisensi komersial namun meninggalkan celah fungsional:
- **Engine SLA Hilang:** Fitur Service Level Agreement (penghitungan waktu breach FRT/RT dan eskalasi) terhapus dari backend runtime, meskipun tabel database dan template email masih tersisa.
- **Captain AI Controllers Hilang:** Frontend stub `useCaptain.js` dimatikan (`captainEnabled = false`).
- **Analitik Campaign Dihapus:** Outbound campaign tidak lagi memiliki tracking delivery status yang mendalam.

### B. Evaluasi Integrasi Marketplace (Shopee, Tokopedia, Lazada)
1. **Asimetri Ingress Webhook:**
   - **Shopee:** Telah matang dua arah melalui `Shopee::IncomingMessageService` dan `Shopee::SendOnShopeeService`.
   - **Tokopedia & Lazada:** Webhook job (`TokopediaEventsJob` & `LazadaEventsJob`) saat ini **baru sebatas memverifikasi signature HMAC dan mencatat log (`Rails.logger.info`)**, belum mengonversi payload menjadi percakapan atau pesan riil di database.
2. **Ketiadaan Konteks E-Commerce:**
   - Marketplace saat ini hanya diperlakukan sebagai saluran chat teks mentah. Belum ada kartu pesanan (Order Card), pelacakan nomor resi, atau informasi detail produk yang ditanyakan buyer di bubble chat.
3. **Ketiadaan Rate-Limiter Terpusat:**
   - Pengiriman pesan keluar langsung menembak HTTP API pada worker thread tanpa token bucket / queue throttling per `shop_id`, berisiko terkena ban/rate limit dari pihak marketplace.

### C. Evaluasi Engine Otomasi & AI (LLM)
1. **Rule Engine Linear (Non-Branching):**
   - `AutomationRule` hanya mendukung array kondisi linear tunggal (`AND`/`OR`). Tidak mendukung visual branching (IF-THEN-ELSE), delay bertingkat di tengah alur, atau evaluasi dua arah dari respon webhook eksternal (saat ini webhook action bersifat fire-and-forget).
2. **Potensi Native RAG (Retrieval-Augmented Generation):**
   - Chatwoot sudah memiliki router model AI (`config/llm.yml`) yang mendukung OpenAI, Anthropic, Gemini, serta formatter prompt percakapan.
   - **Celah Besar:** Belum memanfaatkan ekstensi `pgvector` pada PostgreSQL untuk membuat sistem RAG otomatis berbasis artikel Help Center internal dan histori solusi tiket terdahulu. Pemanggilan LLM masih synchronous HTTP blocking tanpa streaming token (ActionCable chunking) ke editor agen.

### D. CRM 360 & Outbound Broadcast
1. **Fragmentasi Identitas Marketplace (Identity Stitching):**
   - Pembeli marketplace masuk menggunakan ID unik platform, menghasilkan kontak anonim baru (`Shopee Buyer 12345`). Tidak ada mesin pencocok (*identity resolution*) yang menyarankan penggabungan (*merge*) kontak jika pembeli memberikan nomor WhatsApp atau email di dalam ruang chat.
2. **Risiko Skalabilitas WhatsApp Broadcast:**
   - `Whatsapp::OneoffCampaignService` memproses ribuan kontak secara perulangan sinkron (`contacts.each`) di dalam satu job Sidekiq, tanpa batching bertahap, berisiko memblokir worker thread dan terkena rate-limit Meta API.
3. **Ketiadaan Telephony & Call Logging:**
   - Tidak ada model, route, atau controller untuk menangani voice call (VoIP, WebRTC, SIP, atau Twilio Voice).

---

## 4. AUDIT MENDALAM: PENGELOLAAN REPORT, ANALYTICS & DATA ROLLUPS

### A. Kesenjangan Jalur Baca-Tulis (Read-Write Gap)
* **Write Penalty Tanpa Manfaat Read:**
  Setiap kali percakapan ditutup atau dibalas, `ReportingEventListener` menulis baris ke tabel mentah `reporting_events` DAN menjalankan upsert ke `reporting_events_rollups`.
* **Read Path Masih Raw Query:**
  Pada `app/services/reports/data_source.rb:8-13`:
  ```ruby
  def for(**context)
    # TODO: Route to Reports::RollupDataSource when rollup reads are implemented
    Reports::RawDataSource.new(**context)
  end
  ```
  Class `RollupDataSource` **belum pernah dibuat**. Seluruh permintaan grafik laporan, metrik summary, dan pembagian waktu respons tetap melakukan *full aggregate table scan* ke tabel mentah transaksi utama (`conversations`, `messages`, `reporting_events`).

### B. Beban Komputasi Kueri Analitik & Anti-Pattern
1. **14 Kueri Agregasi Berturut-turut pada Summary:**
   - Membuka halaman laporan mengeksekusi `MetricBuilder` yang menjalankan 7 kueri SQL berat (`COUNT`, `AVG`) untuk periode sekarang dan 7 kueri untuk periode perbandingan secara langsung ke database transaksi aktif.
2. **Dynamic Function `date_trunc` pada Postgres:**
   - Time-series reporting menggunakan `groupdate` yang menghasilkan `date_trunc('day', created_at AT TIME ZONE 'UTC')`. Fungsi ini memaksa PostgreSQL melakukan *expression evaluation* pada setiap baris, membatalkan *index-only scan* standar.
3. **Anti-Pattern `conversations.pluck(:id)` pada Team & Label:**
   - Di `app/models/team.rb:63-65` dan `app/models/label.rb:45-47`:
     ```ruby
     def reporting_events
       account.reporting_events.where(conversation_id: conversations.pluck(:id))
     end
     ```
     Menarik puluhan ribu ID percakapan ke memori Ruby untuk kemudian dikirim kembali sebagai klausul `WHERE conversation_id IN (...)` raksasa ke PostgreSQL. Ini memicu lonjakan memori (OOM) dan melumpuhkan database query planner.
4. **Row-Lock Contention pada Rollup Harian:**
   - Agregasi harian dilakukan secara inline via `ReportingEventsRollup.upsert_all`. Puluhan worker Sidekiq secara simultan memperebutkan *exclusive row lock* pada baris akun yang sama di hari yang bersangkutan (`ON CONFLICT DO UPDATE`), memicu *lock wait timeouts* dan silent data drift jika error ditelan oleh rescue block.

### C. Lubang Indeks Database pada Skema Pelaporan (`db/schema.rb`)
1. **`csat_survey_responses` TIDAK MEMILIKI Indeks `created_at`:**
   Filter tanggal laporan kepuasan pelanggan memicu *Full Table Scan* seluruh data akun.
2. **`conversations` Kehilangan Indeks `(account_id, created_at)`:**
   Indeks yang ada adalah `(account_id, status, created_at)`. Query penghitungan total percakapan tanpa filter status tidak dapat memanfaatkan B-tree index secara optimal.
3. **`reporting_events` Kehilangan Indeks `(account_id, user_id, created_at)`:**
   Mengakibatkan lambatnya tab Agent Performance Report pada akun bervolume besar.
4. **Indeks Redundan:**
   Indeks single-column `index_reporting_events_on_account_id` sepenuhnya redundan dengan indeks komposit `reporting_events__account_id__name__created_at`.

### D. Fitur Export Data (CSV) yang Sinkron
- Ekspor CSV laporan di `ReportsController#generate_csv` dan `CsatSurveyResponsesController#download` di-render **secara sinkron di dalam thread web server Puma**.
- Pada akun dengan rentang tanggal lebar atau data besar, query akan melampaui batas waktu 30–60 detik dan menghasilkan **HTTP 504 Gateway Timeout**, sekaligus menyandera thread web server dari melayani traffic chat real-time.
- Helper `DateRangeHelper` tidak memiliki batasan maksimal rentang tanggal (unbounded date query).
- Helper `TimeZoneHelper` mencocokkan timezone berdasarkan offset detik saat ini, berisiko meleset saat pergantian Daylight Saving Time (DST).
- Perhitungan jam kerja (`WorkingHours::Config`) memodifikasi variabel modul secara global, memicu *race condition* antar thread Sidekiq yang memproses laporan dari inbox dengan zona waktu berbeda.

---

## 5. STRATEGIC RECOMMENDATION & ACTION PLAN

```
                ┌─────────────────────────────────────────────────────────┐
                │             STRATEGI EKSEKUSI TIGA FASE                 │
                └────────────────────────────┬────────────────────────────┘
                                             │
      ┌──────────────────────────────────────┼──────────────────────────────────────┐
      ▼                                      ▼                                      ▼
[FASE 1: STABILISASI (1-2 SPRINT)]    [FASE 2: ARSITEKTUR (1-2 KUARTAL)]   [FASE 3: MODERNISASI (ROADMAP)]
- Selesaikan Ingress Toko & Lazada     - Aktifkan Reports::RollupDataSource - Migrasi :serial -> :bigint (DB)
- Pindahkan WA/Twilio ke queue default - Dekopel EventDispatcher per-listener- Partisi tabel Postgres (Messages)
- Tambah indeks DB (CSAT created_at)   - Virtualisasi MessageList.vue       - Engine RAG native (pgvector)
- Lazy-load semua route settings/report- Bangun Native SLA Engine (MIT)      - Migrasi Vuex 4 penuh ke Pinia
- Perbaiki N+1 & Pluck pada Reporting  - Jadwalkan Async Batching Campaign   - ClickHouse untuk analitik 10M+
```

### A. Fase 1: Quick Wins & Stabilisasi Sistem (1–2 Sprint) — [STATUS: 100% SELESAI ✅]
1. **Lengkapi Ingress Tokopedia & Lazada:** `[SELESAI ✅]`
   - Diimplementasikan `Tokopedia::IncomingMessageService` dan `Lazada::IncomingMessageService` dengan proteksi echo balasan seller, deduplikasi `source_id`, dan parser JSON template IM Lazada.
   - Dihubungkan ke `Webhooks::TokopediaEventsJob` dan `Webhooks::LazadaEventsJob` dengan fallback test mode di development/sandbox.
   - Unit test RSpec lengkap: 11 examples, 0 failures.
2. **Koreksi Prioritas Antrean Sidekiq:** `[SELESAI ✅]`
   - Dipindahkan `Webhooks::WhatsappEventsJob` dan `Webhooks::TwilioEventsJob` dari `queue_as :low` ke `queue_as :default` untuk mencegah starvation pesan pelanggan saat sistem sibuk. Dilengkapi `jitter: 0.2` pada retry lock Redis.
3. **Tutup Lubang Indeks Database:** `[SELESAI ✅]`
   - Dijalankan migrasi non-blocking `20261002020000_add_critical_reporting_indexes.rb` (`algorithm: :concurrently`):
     - `csat_survey_responses`: `[:account_id, :created_at]`
     - `conversations`: `[:account_id, :created_at]`
     - `reporting_events`: `[:account_id, :user_id, :created_at]`
     - Dihapus indeks redundan `index_reporting_events_on_account_id`.
4. **Hilangkan `pluck(:id)` pada Reporting:** `[SELESAI ✅]`
   - Diganti pemanggilan pluck di `Team#messages`, `Team#reporting_events`, `Label#messages`, dan `Label#reporting_events` dengan subquery SQL ActiveRecord (`where(conversation_id: conversations.select(:id))`).
5. **Dynamic Lazy-Loading pada Frontend Routes:** `[SELESAI ✅]`
   - Diubah seluruh deklarasi rute di `reports.routes.js`, `campaigns.routes.js`, dan 20 sub-rute `settings/` menjadi dynamic import `() => import(...)`.
   - Diintegrasikan pembungkus `<Suspense>` dengan fallback `<Spinner>` pada `ReportsWrapper.vue`, `CampaignsPageRouteView.vue`, `SettingsWrapper.vue`, dan `Wrapper.vue` untuk eliminasi blank flash saat transit rute.
6. **Sidekiq Server Middleware Sanitasi Thread:** `[SELESAI ✅]`
   - Diimplementasikan `lib/sidekiq_current_sanitizer.rb` dan diregistrasikan ke `config/initializers/sidekiq.rb` untuk deterministik `Current.reset` di blok ensure worker. Unit spec di `spec/lib/sidekiq_current_sanitizer_spec.rb` lulus 100%.

### B. Fase 2: Peningkatan Skalabilitas & Arsitektur (1–2 Kuartal)
1. **Aktifkan `Reports::RollupDataSource`:**
   Selesaikan implementasi read path pada `Reports::DataSource.for` agar dashboard analitik membaca data agregasi `reporting_events_rollups` untuk data historis, bukan men-scan jutaan baris tabel OLTP mentah.
2. **Dekopel `EventDispatcherJob`:**
   Pecah `EventDispatcherJob` agar tidak mengeksekusi 10 listeners secara sekuensial monolitik. Kirim background job independen per kategori listener (`AutomationRuleJob`, `ReportingEventJob`, `WebhookDeliveryJob`).
3. **Virtualisasi Rendering Bubble Pesan (`MessageList.vue`):**
   Integrasikan `Virtualizer` dari `virtua/vue` ke dalam `MessageList.vue` untuk mencegah DOM thrashing pada percakapan panjang. Pindahkan normalisasi `useCamelCase` ke layer ingress payload, bukan di-compute ulang pada setiap render.
4. **Bangun Kembali Native SLA Engine (MIT):**
   Implementasikan model `SlaPolicy` dan `AppliedSla` di layer open-source dengan service kalkulasi business hours dan cron job Sidekiq untuk monitoring status breach serta eskalasi otomatis.
5. **Migrasi Ekspor CSV ke Asinkron:**
   Ubah flow ekspor pada `ReportsController` dan `CsatSurveyResponsesController` menjadi asinkron via Sidekiq + ActiveStorage + Notifikasi Email, menghilangkan risiko HTTP 504 Gateway Timeout.
6. **Chunked Outbound Campaign & Rate Limiting:**
   Pecah `Whatsapp::OneoffCampaignService` agar membagi audiens ke dalam batch kecil menggunakan `CampaignBatchDeliveryJob` dengan distributed rate limiting per channel.

### C. Fase 3: Modernisasi Skala Tinggi & Diferensiasi Pasar (Roadmap Jangka Panjang)
1. **Zero-Downtime Migration dari `:serial` (Int32) ke `:bigserial` (Int64):**
   Rencanakan migrasi bertahap untuk kolom `id` pada tabel `messages`, `conversations`, dan `contacts` guna mencegah *integer overflow* fatal pada volume 2,14 miliar baris.
2. **PostgreSQL Declarative Table Partitioning:**
   Terapkan *Range Partitioning* bulanan pada tabel `messages` dan `reporting_events` menggunakan kolom `created_at` untuk mempercepat query analitik dan memudahkan retensi/purging data lama.
3. **Native Vector RAG & Copilot Streaming:**
   Aktifkan ekstensi `pgvector` pada database PostgreSQL Chatwoot untuk menyimpan embedding artikel Help Center. Hubungkan `Integrations::LlmBaseService` dengan ActionCable streaming untuk menghasilkan draft balasan Copilot secara real-time di editor agen.
4. **Standardized E-Commerce Order Panel & Identity Stitching:**
   Ekstrak arsitektur `ShopifyController` menjadi generalized interface `Commerce::OrderProvider` yang menghubungkan API Shopee, Tokopedia, Lazada, dan ERP eksternal. Bangun sistem resolusi identitas untuk mencocokkan akun marketplace dengan kontak utama secara otomatis.
5. **Migrasi Penuh Frontend ke Pinia & TanStack Query:**
   Hapuskan sisa Vuex 4, migrasikan 40+ modul ke Pinia Store dengan Composition API, dan gunakan TanStack Query untuk caching data serta offline support yang tangguh.
6. **Evaluasi Dedicated OLAP Engine (ClickHouse / TimescaleDB):**
   Untuk instalasi berskala 10M+ percakapan, pertimbangkan memindahkan subsistem pelaporan dari Postgres ke ClickHouse atau TimescaleDB untuk kompresi data ekstrem dan kecepatan agregasi instan.
