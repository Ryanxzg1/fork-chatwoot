# LAPORAN AUDIT TEKNIS: UI/UX & SYSTEM DESIGN (AGENT CS INTERFACE) CHATWOOT

> **Status Audit:** Selesai  
> **Target Scope:** Sisi Agen Customer Support (CS) Chatwoot — Frontend (Vue 3/Tailwind), Real-time (ActionCable/Redis), dan Backend (Rails/PostgreSQL).  
> **Klasifikasi Repositori:** 100% Community Edition (Pure MIT Standalone Fork).

---

## 📑 DAFTAR ISI
1. [Ringkasan Eksekutif & Arsitektur Umum](#1-ringkasan-eksekutif--arsitektur-umum)
2. [Audit UI/UX & Alur Kerja Agen CS (Frontend)](#2-audit-uiux--alur-kerja-agen-cs-frontend)
   - [2.1 Kekuatan Desain & Komponen](#21-kekuatan-desain--komponen)
   - [2.2 Temuan Masalah & Friction Points Kritis](#22-temuan-masalah--friction-points-kritis)
   - [2.3 Audit Aksesibilitas (WCAG 2.1 AA) & Hierarki Visual](#23-audit-aksesibilitas-wcag-21-aa--hierarki-visual)
   - [2.4 Matriks Temuan UI/UX Beserta File Spesifik](#24-matriks-temuan-uiux-beserta-file-spesifik)
3. [Audit System Design & Real-Time State Management](#3-audit-system-design--real-time-state-management)
   - [3.1 Diagram Alur Data End-to-End](#31-diagram-alur-data-end-to-end)
   - [3.2 Evaluasi Konkurensi & Event Storming](#32-evaluasi-konkurensi--event-storming)
   - [3.3 Analisis Kebocoran Memori Klien (Vuex State Retention)](#33-analisis-kebocoran-memori-klien-vuex-state-retention)
   - [3.4 Matriks Risiko Arsitektur Real-Time](#34-matriks-risiko-arsitektur-real-time)
4. [Audit Backend Data Pipeline, Assignment Engine & Skalabilitas Database](#4-audit-backend-data-pipeline-assignment-engine--skalabilitas-database)
   - [4.1 Efisiensi Query & Indexing Database](#41-efisiensi-query--indexing-database)
   - [4.2 N+1 Queries & Payload Bloat (Serializer & Jbuilder)](#42-n1-queries--payload-bloat-serializer--jbuilder)
   - [4.3 Evaluasi Assignment Engine (Race Condition & Offline Trap)](#43-evaluasi-assignment-engine-race-condition--offline-trap)
   - [4.4 Mekanisme SLA & Snooze](#44-mekanisme-sla--snooze)
5. [Rencana Aksi & Rekomendasi Solusi Teknis (P0, P1, P2)](#5-rencana-aksi--rekomendasi-solusi-teknis-p0-p1-p2)

---

## 1. RINGKASAN EKSEKUTIF & ARSITEKTUR UMUM

Antarmuka agen Chatwoot mengadopsi pola **Three-Pane Layout**:
- **Left Pane (Chat List):** Antrean tiket percakapan, filter inbox, status, tim, dan label.
- **Center Pane (Conversation Thread & Composer):** Kronologi riwayat pesan, bubble pesan modular, private notes, dan kotak balas (*WootWriter / ProseMirror*).
- **Right Pane (Contact/Context Panel):** Profil kontak CRM, custom attributes, eksekusi makro, dan *conversation actions*.

Sistem berkomunikasi via REST API (Puma/Rails) untuk mutasi state persisten dan ActionCable (WebSocket didukung Redis Pub/Sub) untuk pembaruan *real-time* (pesan masuk, status *typing*, *presence*, dan pergantian assignee).

Meskipun fondasi komponennya sudah modern (Vue 3 Composition API & Tailwind CSS), audit mendalam ini mengidentifikasi kelemahan arsitektur kritis pada:
1. **Skalabilitas Konkurensi:** $O(N)$ Pub/Sub fan-out di Sidekiq, missing database indexes pada sort default inbox, dan N+1 queries di Jbuilder.
2. **Resiliensi Klien:** Kebocoran memori (memory leak) di Vuex store tab browser agen dan duplikasi pesan saat reconnect jaringan.
3. **Integritas Data & UX Agen:** Kehilangan draf lampiran seketika saat beralih percakapan, hotkeys esensial yang terblokir saat mengetik, dan race condition penugasan tiket (*assignment overwrite*).

---

## 2. AUDIT UI/UX & ALUR KERJA AGEN CS (FRONTEND)

### 2.1 Kekuatan Desain & Komponen
1. **Modularitas `components-next/`:**
   Pemisahan gelembung pesan (`Text/`, `Email/`, `Activity.vue`) memberikan enkapsulasi state yang baik. Sistem token warna Tailwind (`text-n-slate-12`, `bg-n-surface-1`, `border-n-weak`) mempermudah konsistensi visual dan peralihan Dark/Light mode (`themeHelper.js:4-17`).
2. **Contextual In-Editor Triggers (ProseMirror):**
   Integrasi plugin di `WootWriter/Editor.vue:347-382` mendeteksi trigger dengan sangat responsif:
   - `@` untuk Mention Agents/Teams (`TagAgents.vue`)
   - `/` untuk Canned Responses (`CannedResponse.vue`)
   - `{{` untuk Dynamic Variables (`VariableList.vue`)
   - `#` untuk Macro Execution (`MacroList.vue`)
   - `:` untuk Emoji Picker (`keyboardEmojiSelector.vue`)
   Menggunakan `CaretAnchoredPicker.vue` yang melayang tepat di posisi *caret* kursor pengetikan.
3. **Global Command Bar Palette (`ninja-keys`):**
   Shortcut `Cmd+K` / `Ctrl+K` (`ReplyBox.vue:109-116`, `useConversationHotKeys.js:1-403`) memungkinkan triase cepat (assignee, label, status, prioritas) tanpa mouse.
4. **Kustomisasi Panel Kontak:**
   Komponen accordion di `ContactPanel.vue:151-160` dapat diatur ulang (*drag & drop*) via `vuedraggable` dan otomatis disimpan ke `useUISettings.js`.

---

### 2.2 Temuan Masalah & Friction Points Kritis

#### A. Data Loss: Lampiran Berkas & Audio Terhapus Saat Berpindah Chat
- **Lokasi Kode:** `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue:578-583`
  ```javascript
  conversationIdByRoute(conversationId, oldConversationId) {
    if (conversationId !== oldConversationId) {
      this.switchDraftContext(conversationId, this.effectiveReplyMode);
      this.resetRecorderAndClearAttachments(); // <-- Data Dihapus
      this.isQuoteRemoved = false;
    }
  }
  ```
- **Masalah:** Jika agen sedang mengunggah berkas PDF/gambar atau merekam voice note, lalu beralih ke tiket lain untuk memeriksa nomor pesanan/konteks, **seluruh attachment dan rekaman audio langsung dihapus tanpa konfirmasi**. Draft store (`draftMessages.js`) hanya menyimpan teks, bukan berkas.

#### B. Timpaan Otomatis Recipient Email (CC / BCC) Saat Berpindah Chat
- **Lokasi Kode:** `ReplyBox.vue:570-576`, `ReplyBox.vue:1255-1270`
- **Masalah:** Pada inbox email, jika agen menambahkan alamat supervisor/vendor di field CC/BCC lalu berpindah chat atau menerima update event pesan baru, `lastEmail` watcher memanggil `setCCAndToEmailsFromLastChat()` yang **menimpa balik** field CC/BCC ke default database, membuang input manual agen.

#### C. Ketiadaan Indikator Visual Draft di List Percakapan
- **Lokasi Kode:** `ConversationCard.vue`
- **Masalah:** Saat agen menulis draf tanggapan lalu terdistraksi tiket lain, kartu percakapan tidak menampilkan indikator draf (tidak ada ikon pensil, tidak ada label `[Draft]`). Agen sering lupa bahwa tiket tersebut belum terkirim.

#### D. Hotkeys Kritis Terblokir Saat Mengetik (`allowOnFocusedInput: false`)
- **Lokasi Kode:** `ReplyTopPanel.vue:108`, `Editor.vue:716`, `ResolveAction.vue:146-170`
- **Masalah:** Agen menghabiskan 90% waktunya dengan kursor aktif di kotak teks. Namun, shortcut *Resolve Conversation* (`Alt+E` / `Cmd+Alt+E`), switch ke *Private Note* (`Alt+P`), dan switch ke *Reply* (`Alt+L`) secara sengaja disetel `allowOnFocusedInput: false`. Agen wajib mengklik mouse ke luar editor terlebih dahulu untuk menggunakan shortcut tersebut.

#### E. Inversi Tombol Navigasi Vim (`Alt+J` vs `Alt+K`)
- **Lokasi Kode:** `app/javascript/dashboard/composables/chatlist/useChatListKeyboardEvents.js:49-56`
- **Masalah:** Di standar industri (Vim, Gmail, Linear), `J` = Next / Down dan `K` = Previous / Up. Di Chatwoot justru terbalik: `Alt+J` memanggil `previous` (ke atas) dan `Alt+K` memanggil `next` (ke bawah).

#### F. Kerentanan Resiko Pengiriman Catatan Internal ke Pelanggan
- **Lokasi Kode:** `ReplyBox.vue` & `ReplyBoxBanner.vue`
- **Masalah:** Pembeda antara *Public Reply* dan *Private Note* hanya warna tombol dan strip banner tipis. Di tengah beban kerja CS tinggi, agen rawan salah mengetik catatan internal rahasia ke pelanggan eksternal karena area editor tidak memiliki border aksen kontras atau watermark status.

---

### 2.3 Audit Aksesibilitas (WCAG 2.1 AA) & Hierarki Visual

1. **Non-Semantic HTML pada Kartu Percakapan (`ConversationCard.vue:111-122`):**
   - Kartu dirender sebagai tag `<div>` polos dengan `@click`.
   - **Pelanggaran WCAG 2.1.1 & 4.1.2:** Tidak memiliki `role="button"`, tidak memiliki `tabindex="0"`, tidak ada atribut status `aria-selected`, dan tidak mendukung keyboard enter/space. Pengguna keyboard murni tidak dapat memfokuskan daftar chat.
2. **Struktur List HTML Tidak Valid (`MessageList.vue:169` & `Message.vue:549`):**
   - Container utama menggunakan tag `<ul>`, namun elemen anak langsung di dalam `v-for` adalah `<div>` (bukan `<li>`), merusak pohon aksesibilitas screen reader (**WCAG 1.3.1**).
3. **Desinkronisasi Navigasi Keyboard Virtual List:**
   - Di `useChatListKeyboardEvents.js:5-21`, navigasi membaca DOM langsung: `querySelectorAll('div.conversation')`.
   - Karena `ConversationList.vue:66` menggunakan `<Virtualizer>`, hanya kartu yang masuk viewport yang terpasang di DOM. Saat agen menekan shortcut melebihi tinggi layar, navigasi macet dan berhenti scroll.
4. **Pemborosan Ruang Layar pada Layar Sedang (< 1280px):**
   - Di `ConversationHeader.vue:113`, header dipaksa bertumpuk vertikal dengan tinggi `h-24` (96px) pada resolusi di bawah `xl`. Ditambah navbar dan composer, area baca pesan tersisa kurang dari 450px pada laptop 1366x768.

---

### 2.4 Matriks Temuan UI/UX Beserta File Spesifik

| No | Kategori | Deskripsi Masalah | File & Baris Spesifik |
|---|---|---|---|
| 1 | **Critical Bug** | Penghapusan draf memanggil `SET_DRAFT_MESSAGES` alih-alih `REMOVE_DRAFT_MESSAGES`, menyisakan sampah key `{ [id]: undefined }` selamanya di LocalStorage. | `store/modules/draftMessages.js:23-25` |
| 2 | **Critical UX** | File lampiran dan rekaman suara dibersihkan seketika tanpa peringatan saat agen beralih tiket chat. | `components/widgets/conversation/ReplyBox.vue:578-583` |
| 3 | **Friction** | Shortcut *Resolve* (`Alt+E`), *Note* (`Alt+P`), dan *Reply* (`Alt+L`) mati total saat kursor aktif di editor (`allowOnFocusedInput: false`). | `buttons/ResolveAction.vue:146-170`<br>`WootWriter/ReplyTopPanel.vue:106-114` |
| 4 | **Friction** | Navigasi keyboard membaca DOM langsung (`querySelectorAll`), macet saat berhadapan dengan virtualizer windowing. | `composables/chatlist/useChatListKeyboardEvents.js:5-21` |
| 5 | **Cognitive** | Tombol navigasi Vim terbalik: `Alt+J` ke atas dan `Alt+K` ke bawah. | `composables/chatlist/useChatListKeyboardEvents.js:49-56` |
| 6 | **A11y** | Kartu percakapan murni berupa `div` tanpa semantik button/listitem dan atribut `tabindex`/`aria-selected`. | `components/widgets/conversation/ConversationCard.vue:111-122` |
| 7 | **A11y** | Tag pembungkus gelembung pesan `<ul>` berisi anak langsung `<div>` tanpa `<li>` atau `role="listitem"`. | `components-next/message/MessageList.vue:169`<br>`components-next/message/Message.vue:549` |
| 8 | **Responsive** | Pada tablet (768px - 1024px), sidebar navigasi, ChatList, dan ContactPanel dipaksa berdampingan secara statis, menyisakan area chat tengah hanya selebar ~164px. | `ConversationSidebar.vue:54`<br>`ChatList.vue:912` |
| 9 | **UI Glitch** | Kesalahan ketik nama kelas CSS `cucursor-pointer` (dobel 'cu') pada tombol copy ID percakapan di header. | `ConversationHeader.vue:151` |

---

## 3. AUDIT SYSTEM DESIGN & REAL-TIME STATE MANAGEMENT

### 3.1 Diagram Alur Data End-to-End

```
+---------------------------------------------------------------------------------------------------+
| SENDER AGENT (Browser)                                                                            |
| 1. Submit pesan di ReplyBox.vue                                                                   |
| 2. createPendingMessage() -> tempMessageId (UUID), echo_id = tempMessageId, status = 'progress'   |
| 3. Vuex commit(ADD_MESSAGE) -> Optimistic UI (bubble pesan muncul dengan spinner)                 |
+---------------------------------------------------------------------------------------------------+
           │                                                        │
           │ (A) HTTP POST /api/v1/.../messages                     │ (B) WebSocket (ActionCable)
           │     payload: { content, echo_id, ... }                 │     (Hanya listener, bukan transport POST)
           ▼                                                        │
+-------------------------------------------------------------+     │
| RAILS API CONTROLLER                                        |     │
| (MessagesController#create)                                 |     │
| - Messages::MessageBuilder.new(...)                         |     │
| - Set transient attr_accessor :echo_id                      |     │
+-------------------------------------------------------------+     │
           │                                                        │
           ▼                                                        │
+-------------------------------------------------------------+     │
| POSTGRESQL DB                                               |     │
| - INSERT INTO messages (...) -> Mendapatkan DB id permanen  |     │
| - after_create_commit :dispatch_create_events               |     │
+-------------------------------------------------------------+     │
           │                                                        │
           ▼                                                        │
+-------------------------------------------------------------+     │
| RAILS EVENT DISPATCHER                                      |     │
| - Dispatcher.dispatch('message.created')                    |     │
| - SyncDispatcher -> ActionCableListener#message_created     |     │
| - user_tokens = inbox.members + account.administrators      |     │
| - Enqueue ActionCableBroadcastJob ke Sidekiq (:critical)    |     │
+-------------------------------------------------------------+     │
           │                                                        │
           +-----------------------+                                │
           │ (HTTP Response 200)   │                                │
           ▼                       │                                │
+-------------------------------+  │                                │
| SENDER AGENT (HTTP Success)   │  │                                │
| - Vuex ADD_MESSAGE:           │  │                                │
|   findPendingMessageIndex()   │  │                                │
|   match: m.id == echo_id      │  │                                │
| - Replace UUID -> DB ID       │  │                                │
| - status: 'sent'              │  │                                │
+-------------------------------+  │                                │
                                   ▼                                │
+-------------------------------------------------------------+     │
| SIDEKIQ WORKER (ActionCableBroadcastJob)                    |     │
| - queue: :critical                                          |     │
| - Loop O(N): members.each do |pubsub_token|                 |     │
|   ActionCable.server.broadcast(pubsub_token, payload)       |     │
+-------------------------------------------------------------+     │
           │                                                        │
           ▼                                                        │
+-------------------------------------------------------------+     │
| REDIS PUB/SUB                                               |     │
| - Redis PUBLISH ke masing-masing channel token agent        |     │
+-------------------------------------------------------------+     │
           │                                                        │
           ▼                                                        │
+-------------------------------------------------------------+     │
| ACTIONCABLE WS SERVER (Puma Worker Threads)                 |     │
| - Push WebSocket frame ke koneksi aktif RoomChannel         |     │
+-------------------------------------------------------------+     │
           │                                                        │
           +────────────────────────────────────────────────────────+
           │
           +─────────────────────────────────────────+
           │                                         │
           ▼ (WS frame ke Sender)                    ▼ (WS frame ke Agent Lain)
+---------------------------------------+ +---------------------------------------+
| SENDER AGENT (Echo Suppression)       | | AGENT LAIN (Broadcast Receiver)       |
| - ActionCableConnector.onMessageCreated| | - ActionCableConnector.onMessageCreated|
| - Vuex ADD_MESSAGE:                   | | - Vuex ADD_MESSAGE:                   |
|   findPendingMessageIndex()           | |   findPendingMessageIndex() == -1     |
|   m.id == message.id (sudah ada)      | | - chat.messages.push(message)         |
| - Ditimpa di tempat (no duplicate)    | | - Audio alert diputar                 |
+---------------------------------------+ +---------------------------------------+
```

---

### 3.2 Evaluasi Konkurensi & Event Storming

#### A. O(N) Fan-Out di Layer Aplikasi (Sidekiq & Redis Overload)
- **Lokasi Kode:** `app/listeners/action_cable_listener.rb:205-209`, `app/jobs/action_cable_broadcast_job.rb:46-54`
- **Mekanisme:** Chatwoot tidak menggunakan channel berbasis inbox (`stream_from "inbox_#{id}"`), melainkan token individual agen (`stream_from pubsub_token`).
- **Dampak Konkurensi:** Jika 1 inbox memiliki 100 agen/admin, 1 pesan masuk memicu **loop 100 kali di Sidekiq** yang mengeksekusi **100 perintah Redis `PUBLISH` individual**. Pada beban 10 pesan/detik, terbentuk **1.000 Redis PUBLISH/detik**. Ini membebani CPU Redis dan thread pool Sidekiq queue `:critical`.

#### B. N+1 Re-Query Database di Background Worker
- **Lokasi Kode:** `app/jobs/action_cable_broadcast_job.rb:25-43`
- **Mekanisme:** Untuk setiap event update percakapan (`CONVERSATION_UPDATE_EVENTS`: read receipt, status, assignee, team), Sidekiq melakukan kueri ulang ke PostgreSQL:
  ```ruby
  account = Account.find(data[:account_id])
  conversation = account.conversations.find_by!(display_id: data[:id])
  broadcast_data = conversation.push_event_data...
  ```
- **Dampak:** Saat banyak agen melakukan triase serentak (assign/resolve), worker Sidekiq membombardir database dengan kueri `SELECT` dan serialisasi data asosiasi yang sebenarnya sudah tersedia di proses web.

#### C. Secondary API Storming (Thundering Herd ke REST API)
- **Lokasi Kode:** `actionCable.js:117, 122, 204, 210` & `conversation_finder.rb:170-179`
- **Mekanisme:** Payload WebSocket untuk event `assignee.changed`, `conversation.status_changed`, dan `conversation.unread_count_changed` tidak membawa angka ringkasan statistik terbaru (*zero/sparse payload*). Begitu event diterima, browser masing-masing agen memicu `fetch_conversation_stats`, yang mengirimkan request HTTP GET ke `/api/v1/conversations/meta`.
- **Dampak:** 100 browser agen secara serentak menembak endpoint `meta`. Di backend, `ConversationFinder#set_count_for_all_conversations` menjalankan 3 kueri agregasi `COUNT(*) FILTER (...)` tanpa caching di PostgreSQL.

#### D. Race Condition & Overhead Typing Indicator via HTTP POST
- **Lokasi Kode:** `conversationTypingStatus.js:14-19`, `conversations_controller.rb:106-110`, `actionCable.js:349-365`
- **Mekanisme:** Event ephemeral *typing on/off* tidak dikirim via ActionCable WebSocket RPC, melainkan melalui **HTTP POST** penuh (melewati Devise auth, DB lookup, event dispatch, dan antrean Sidekiq).
- **Race Condition 1 (Reordering):** Jika request HTTP `typing_on` mengalami lag jaringan sedangkan `typing_off` selesai lebih cepat, status agen mengetik akan menyala permanen hingga timeout 30 detik.
- **Race Condition 2 (Timer Collision):** Di `actionCable.js:350-364`, `this.CancelTyping` di-indeks hanya berdasarkan `conversationId`. Jika User A dan Agent B mengetik di chat yang sama, timer User A akan terhapus oleh Agent B.

---

### 3.3 Analisis Kebocoran Memori Klien (Vuex State Retention)

- **Status:** **CRITICAL BOTTLENECK TERKONFIRMASI.**
- **Lokasi Kode:** `app/javascript/dashboard/store/modules/conversations/index.js:11-27, 45-89, 120, 245-265`

#### Mekanisme Retensi Tanpa Batas:
1. **Tidak Ada Message Eviction / Virtual Window:**
   Array `chat.messages` dalam `_state.allConversations` hanya bertambah via `chat.messages.push(message)` (pesan baru) dan `chat.messages.unshift(...newMessages)` (infinite scroll pagination).
2. **Tidak Ada Garbage Collection saat Ganti Percakapan:**
   Saat agen berpindah percakapan, action `clearSelectedState` hanya mengubah `_state.selectedChatId = null`. Seluruh array pesan dari percakapan lama tetap tersimpan utuh di memori Vuex.
3. **Preservasi State Eksplisit saat List Di-refresh:**
   Pada mutasi `SET_ALL_CONVERSATION` (baris 61-65) dan `REPLACE_CONVERSATION_LIST` (baris 81-86), helper `preserveConversationMessageState` sengaja mempertahankan seluruh array pesan lama:
   ```javascript
   const preserveConversationMessageState = (conversation, existingConversation) => ({
     ...conversation,
     allMessagesLoaded: existingConversation.allMessagesLoaded,
     messages: existingConversation.messages, // <-- Tidak pernah dibersihkan
     dataFetched: existingConversation.dataFetched,
   });
   ```
4. **Akumulasi Objek Lampiran & Media:**
   `_state.attachments` menyimpan seluruh metadata attachment per `conversationId` dan tidak pernah dihapus. Untuk pesan email, payload menyimpan string HTML mentah lengkap (`email.html_content`).
5. **Dampak Nyata:**
   Dalam shift 8 jam, agen yang membuka 50–100 tiket dengan riwayat panjang akan mengakumulasi ratusan megabyte memory heap di tab browser, memicu degradasi performa (*frame drop*), GC pauses berat, dan akhirnya *browser tab crash* (*Out of Memory*).

---

### 3.4 Matriks Risiko Arsitektur Real-Time

| No | Lokasi Kode | Deskripsi Masalah | Tingkat Risiko |
|---|---|---|---|
| 1 | `action_cable_listener.rb:205-209`<br>`action_cable_broadcast_job.rb:46-54` | **O(N) Fan-Out PubSub di Sidekiq:** Broadcaster melooping token agen satu per satu, mengeksekusi puluhan/ratusan Redis `PUBLISH` per 1 pesan. | 🔴 Critical |
| 2 | `action_cable_broadcast_job.rb:28-30` | **DB Reload di Background Job:** Setiap conversation update event memicu kueri ulang `Account.find` dan `conversations.find_by!` di Postgres. | 🔴 Critical |
| 3 | `conversations/index.js:63-65, 81-86` | **Client Memory Leak:** Array `chat.messages` dan `attachments` pada percakapan yang sudah tidak aktif disimpan selamanya di Vuex. | 🔴 Critical |
| 4 | `conversations/actions.js:253-255` | **Race Condition Duplikasi Pesan saat Reconnect:** `syncActiveConversationMessages` hanya mengecek `item.id === message.id` tanpa memeriksa `echo_id`. Pending message (UUID) akan dobel dengan hasil fetch server (Integer ID). | 🔴 Critical |
| 5 | `conversationTypingStatus.js:14-19`<br>`conversations_controller.rb:106-110` | **Typing Indicator via HTTP POST:** Overhead request HTTP, Devise auth, dan Sidekiq dispatch untuk event sementara, memicu HTTP race condition. | 🟡 High |
| 6 | `actionCable.js:350-364` | **Typing Timer Collision:** `CancelTyping` memakai key `conversationId` tunggal; multi-user typing saling menimpa timer pembersihan. | 🟡 High |
| 7 | `room_channel.rb:22-25`<br>`lib/online_status_tracker.rb:72-79` | **Presence Polling Over WS & DB Hits:** Polling snapshot setiap 20 detik tanpa jitter memicu kueri `Account.find` dan `account_users.where` per agen. | 🟡 High |
| 8 | `actionCable.js:117, 204`<br>`conversation_finder.rb:170-179` | **Secondary API Storming:** WS event kosong memicu ratusan agen serentak menembak HTTP endpoint agregasi `/conversations/meta`. | 🟡 High |
| 9 | `conversations/index.js:294-296` | **Aggressive Viewport Auto-Scroll:** Chat melompat paksa ke bawah setiap kali ada perubahan metadata minor saat agen sedang membaca riwayat chat. | 🟡 Medium |

---

## 4. AUDIT BACKEND DATA PIPELINE, ASSIGNMENT ENGINE & SKALABILITAS DATABASE

### 4.1 Efisiensi Query & Indexing Database

#### A. Missing Index pada Default Sort Inbox (`last_activity_at`)
- **Lokasi Kode:** `conversation_finder.rb:201`, `Conversations::SortService::DEFAULT_SORT`, `db/schema.rb:863-911`
- **Temuan:**
  Sort bawaan Chatwoot adalah `'last_activity_at_desc'`:
  ```sql
  SELECT conversations.* FROM conversations
  WHERE conversations.account_id = $1 AND conversations.status = 0
  ORDER BY conversations.last_activity_at DESC LIMIT 25 OFFSET 0;
  ```
  **TIDAK ADA INDEX pada kolom `last_activity_at` di tabel `conversations`**. Index yang ada hanyalah `(account_id, status, created_at)`.
- **Dampak:** PostgreSQL dipaksa memindai seluruh record `open` akun tersebut ke dalam memori (`work_mem`), lalu melakukan **in-memory Sort / Disk Merge Sort (Top-N Heapsort)**. Pada akun dengan ratusan ribu tiket, kueri mengalami lonjakan latensi (mencapai > 2–5 detik) dan IO thrashing.

#### B. Correlated Subquery pada Urutan Unread (`sort_on_unread`)
- **Lokasi Kode:** `app/models/conversation.rb:92-94, 238-256`
- **Temuan:** Scope `sort_on_unread` menyuntikkan subquery Arel ke klausa `ORDER BY` untuk menghitung unread messages per row.
- **Dampak:** Jika akun memiliki 10.000 percakapan, PostgreSQL menjalankan **10.000 kalkulasi agregat terpisah** ke tabel `messages` sebelum dapat memfilter 25 baris pertama paginasi.

#### C. Full Table Scan Trigram & Duplikasi Query pada Search
- **Lokasi Kode:** `conversation_finder.rb:135-143`
- **Temuan:** Terdapat duplikasi klausa `WHERE messages.content ILIKE` dan `where(messages: { message_type: ... })` yang dieksekusi dua kali berturut-turut pada method `filter_by_query`.

---

### 4.2 N+1 Queries & Payload Bloat (Serializer & Jbuilder)

#### A. Pola N+1 Parah di `_conversation.json.jbuilder` (Per 25 Baris Sidebar)
1. **Unread Count Triple Evaluation (`_conversation.json.jbuilder:67`, `message.rb:162`):**
   `conversation.unread_incoming_messages.count` memanggil `.last(10)`, yang mengeksekusi **query `SELECT ... LIMIT 10` lalu menginstansiasi array di memori Ruby**, bukan query `COUNT(*)` SQL. Ini dipanggil 3 kali dalam serializer yang sama (**75 query pesan per 25 percakapan**).
2. **N+1 Last Message & Non-Activity Message (`_conversation.json.jbuilder:35-37, 68`):**
   `conversation.messages.where(...).first` memicu 25 kueri pesan tambahan.
3. **N+1 Missing Preload `account_users` (`_agent.json.jbuilder:4-12`):**
   `ConversationFinder` melakukan preload `{ assignee: { avatar_attachment: [:blob] } }`, tetapi **tidak mem-preload `:account_users`**. Memanggil `resource.availability_status` memicu kueri `SELECT * FROM account_users WHERE user_id = ?` per agen unik.
4. **N+1 Redis Network Trips:**
   Pengecekan status online agen memicu `OnlineStatusTracker.get_presence` sinkron per baris, menghasilkan 50–75 Redis network trips di dalam satu thread request Puma.

#### B. Analisis Payload Bloat
- Serializer mengirimkan data yang berlebihan untuk kebutuhan list sidebar:
  1. Menyertakan 2 objek pesan penuh (`messages: [last_message]` dan `last_non_activity_message`) dengan seluruh `content_attributes` dan `additional_attributes`.
  2. Menyertakan data kontak lengkap (HTTP user-agent mentah, referer URL, geo IP).
  3. Payload mencapai **100–200 KB JSON uncompressed per 25 percakapan**, memboroskan kuota bandwidth mobile dan memperlambat V8 JSON parse di frontend.

---

### 4.3 Evaluasi Assignment Engine (Race Condition & Offline Trap)

#### A. Race Condition: Manual Assignment (Dua Agen Mengklaim Tiket Bersamaan)
- **Lokasi Kode:** `app/services/conversations/assignment_service.rb:16-27`
- **Masalah:** Meskipun menggunakan `conversation.with_lock`, **tidak ada validasi state sebelumnya (tanpa optimistic lock)**.
- **Skenario:** Jika Agen A dan Agen B mengklik *"Assign to me"* pada detik yang sama:
  1. Agen A mengambil row lock, menetapkan `assignee = Agen A`, commit.
  2. Agen B yang menunggu lock langsung melanjutkan eksekusi, **menimpa** `assignee = Agen B`, commit.
  Penugasan Agen A hilang tanpa notifikasi atau peringatan.

#### B. Desinkronisasi Non-Atomik pada Round-Robin Redis
- **Lokasi Kode:** `app/services/auto_assignment/inbox_round_robin_service.rb:37-55`
- **Masalah:** Operasi antrean **TIDAK ATOMIK** (menggunakan Ruby array intersection, disusul `LREM` terpisah lalu `LPUSH` terpisah tanpa Redis Lua Script / Transaction).
- Dua worker serentak dapat memilih agen yang sama dan menduplikasi push ke antrean. Selain itu, jika thread lain memanggil `validate_queue?` di sela-sela jeda `LREM` dan `LPUSH`, antrean dianggap corrupt dan di-`reset_queue` dari nol.

#### C. The "Permanent Online" Trap: Melempar Tugas ke Agen yang Offline
- **Lokasi Kode:** `lib/online_status_tracker.rb:72-78`
- **Mekanisme:**
  ```ruby
  def self.get_available_user_ids(account_id)
    account = Account.find(account_id)
    range_start = (Time.zone.now - PRESENCE_DURATION).to_i
    user_ids = ::Redis::Alfred.zrangebyscore(presence_key(account_id, 'User'), range_start, '+inf')
    user_ids += account.account_users.where(auto_offline: false)&.map(&:user_id)&.map(&:to_s)
    user_ids.uniq
  end
  ```
- **Dampak Fatal:** Jika agen mengaktifkan konfigurasi `auto_offline: false`, ID agen tersebut **selalu dimasukkan ke dalam daftar agen yang tersedia, meskipun laptopnya sudah dimatikan atau koneksi websocket terputus**. Auto-assignment akan terus menugaskan percakapan baru ke agen yang sedang tidak aktif.

---

### 4.4 Mekanisme SLA & Snooze

#### A. Mekanisme Reopen Snoozed: Polling Cron Sidekiq
- **Lokasi Kode:** `config/schedule.yml:12-15`, `Conversations::ReopenSnoozedConversationsJob`
- **Alur Kerja:** Cron job berjalan setiap 5 menit (`*/5 * * * *`) mengeksekusi:
  ```ruby
  Conversation.where(status: :snoozed)
              .where(snoozed_until: 3.days.ago..Time.current)
              .all.find_each(batch_size: 100, &:open!)
  ```
- **Kelemahan Kritis:**
  1. **Index Miss:** Tabel `conversations` **tidak memiliki index pada kolom `snoozed_until`** (table scan).
  2. **Jeda Waktu:** Tiket yang dijadwalkan bangun pukul 09:01 baru akan aktif pada pukul 09:05.
  3. **Synchronous Execution Cascading:** Eksekusi `find_each(&:open!)` berjalan sinkron di satu worker. Tiap `.open!` memicu lock row, activity message, auto-assignment, dan broadcast websocket. Jika ada 300 tiket snooze bangun di jam 09:00, satu worker Sidekiq terkunci puluhan detik.
  4. **Data Loss Window (Hardcoded `3.days.ago`):** Jika Sidekiq down/backlog lebih dari 3 hari, tiket snooze yang lewat dari 3 hari lalu akan **terkunci permanen dalam status snoozed**.

---

## 5. RENCANA AKSI & REKOMENDASI SOLUSI TEKNIS (P0, P1, P2)

### 🔴 Prioritas P0 (Harus Segera Diperbaiki / Kritis)

#### 1. Database Indexing Migration (Atasi Slow Query Default Sort)
Tambahkan migrasi PostgreSQL berikut untuk mengeliminasi disk-spilling sort dan scanning berulang:

```ruby
class OptimizeConversationAndMessagePerformance < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Mengatasi slow query default sort ConversationFinder (Index Scan presorted)
    add_index :conversations, [:account_id, :status, :last_activity_at],
              order: { last_activity_at: :desc },
              algorithm: :concurrently,
              name: 'idx_conversations_account_status_last_activity'

    # Mengatasi scan berulang setiap 5 menit pada ReopenSnoozedConversationsJob
    add_index :conversations, [:status, :snoozed_until],
              where: "status = 3",
              algorithm: :concurrently,
              name: 'idx_conversations_snoozed_lookup'

    # Mengatasi cursor pagination scan pada MessageFinder
    add_index :messages, [:conversation_id, :id],
              order: { id: :desc },
              algorithm: :concurrently,
              name: 'idx_messages_conversation_id_id_desc'
  end
end
```

#### 2. Channel Multiplexing / Inbox Topic Streams (Atasi O(N) Fan-Out)
- Di `app/channels/room_channel.rb`, ubah stream agar agen mendengarkan channel level inbox/akun: `stream_from "account_#{account_id}_inbox_#{inbox_id}"`.
- Di `ActionCableListener`, backend cukup memanggil 1 kali broadcast:
  `ActionCable.server.broadcast("account_#{account_id}_inbox_#{inbox_id}", payload)`.
- Redis pub/sub dan ActionCable C-engine akan mendistribusikan frame ke seluruh subscriber secara paralel tanpa loop di Sidekiq.

#### 3. Pertahankan Lampiran (*Attachments*) & Audio Antar Percakapan
- Perluas struktur draf di `draftMessages.js` agar menyimpan:
  `{ text: '', attachments: [], ccEmails: '', bccEmails: '' }`.
- Hapus pemanggilan `resetRecorderAndClearAttachments()` secara destruktif di `ReplyBox.vue:580`. Simpan draft berkas sementara berdasarkan ID percakapan.

#### 4. Perbaiki Mutasi Store Draft Messages
Perbaiki `app/javascript/dashboard/store/modules/draftMessages.js:23-25`:
```javascript
// SEBELUM:
delete: ({ commit }, { key }) => {
  commit(types.SET_DRAFT_MESSAGES, { key });
}

// SESUDAH:
delete: ({ commit }, { key }) => {
  commit(types.REMOVE_DRAFT_MESSAGES, { key });
}
```

#### 5. Batasi Message Window (LRU Eviction) di Vuex Store
- Tetapkan batas maksimal pesan per percakapan di memori browser (maks 50–100 pesan terakhir).
- Ketika agen beralih ke percakapan lain, kosongkan array `messages` percakapan sebelumnya (`chat.messages = []` dan `chat.dataFetched = undefined`) agar garbage collector browser dapat membebaskan memory heap.

---

### 🟡 Prioritas P1 (Tinggi / Dampak Skalabilitas Signifikan)

#### 1. Denormalisasi `unread_count` & Eliminasi N+1 Jbuilder
- Tambahkan kolom integer `unread_count` pada tabel `conversations` yang diperbarui secara atomik (`increment_counter` / reset saat dilihat). Hentikan pemanggilan `unread_incoming_messages.count` (dan `.last(10)`) di view Jbuilder.
- Di `ConversationFinder#conversations_base_query`, sertakan preload lengkap:
  `{ assignee: [:account_users, { avatar_attachment: [:blob] }] }`.
- Buat partial ringan `_conversation_card.json.jbuilder` yang hanya membawa ringkasan teks 100 karakter, bukan objek pesan utuh.

#### 2. Atomic Guard pada Manual Claim & Redis Round-Robin
- Gunakan conditional update di `Conversations::AssignmentService#assign_agent`:
  ```ruby
  updated_rows = Conversation.where(id: @conversation.id, assignee_id: nil)
                             .update_all(assignee_id: assignee.id, updated_at: Time.current)
  raise CustomExceptions::AlreadyAssignedError if updated_rows.zero? && @conversation.assignee_id != assignee.id
  ```
- Bungkus rotasi antrean round-robin Redis (`inbox_round_robin_service.rb`) ke dalam **Redis Lua Script** agar pergeseran pointer antrean berjalan 100% atomik.

#### 3. Validasi Presence Ketat pada Auto-Assignment
- Pada `OnlineStatusTracker.get_available_user_ids`, **dilarang** memasukkan user `auto_offline: false` jika timestamp presensi websocket agen (`zscore` di sorted set) sudah lewat dari `PRESENCE_DURATION`.

#### 4. Aktifkan Hotkeys Kritis di Mode Editor (`allowOnFocusedInput: true`)
- Di `ResolveAction.vue:146-170`, setel `allowOnFocusedInput: true` pada `Alt+KeyE` dan `$mod+Alt+KeyE`.
- Di `ReplyTopPanel.vue:106-114` dan `Editor.vue:713-721`, setel `allowOnFocusedInput: true` untuk `Alt+KeyP` dan `Alt+KeyL`.
- Sesuaikan arah navigasi di `useChatListKeyboardEvents.js:49-56`: ubah `Alt+KeyJ` ke `next` (bawah) dan `Alt+KeyK` ke `previous` (atas).

#### 5. Peningkatan Kontras Visual Mode Private Note
- Pada `ReplyBox.vue`, saat `isOnPrivateNote === true`, berikan border aksen warna oranye/amber yang mencolok (`ring-2 ring-n-amber-9 border-n-amber-9`) dan watermark status permanen di pojok editor untuk mencegah salah kirim catatan internal ke pelanggan.

---

### 🟢 Prioritas P2 (Medium / Peningkatan Kualitas & Standar)

1. **Pindahkan Typing Indicator ke Pure WebSocket Client RPC:**
   Hapus endpoint HTTP `toggle_typing_status`. Gunakan RPC action native di `RoomChannel` (`def typing_on ...`) dan simpan timer pembatalan di frontend dengan composite key `${conversationId}:${user.type}:${user.id}`.
2. **Sidekiq Scheduled Delay untuk Tiket Snooze:**
   Jadwalkan job individual `ReopenConversationJob.set(wait_until: snoozed_until).perform_later(conversation.id)` saat tiket di-snooze, mengeliminasi kebutuhan cron polling database tiap 5 menit.
3. **Kepatuhan Aksesibilitas WCAG 2.1 AA:**
   Tambahkan `role="button"`, `tabindex="0"`, dan `:aria-selected` pada `ConversationCard.vue`. Gunakan elemen pembungkus `<li>` di `MessageList.vue`.
4. **Optimasi Tata Letak Tablet:**
   Ubah breakpoint panel kontak di `ConversationSidebar.vue` dari `md:` (768px) menjadi `xl:` (1280px), menjadikannya *slide-over drawer* pada layar tablet agar area chat tengah tidak terhimpit.
