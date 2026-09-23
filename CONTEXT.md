# CONTEXT.md — Chatwoot Codebase Intelligence

> **Tujuan File Ini:**
> Dokumen ini adalah *Single Source of Truth* bagi AI (maupun developer baru) sebelum menganalisis,
> memodifikasi, atau menambahkan kode pada repositori Chatwoot. Baca seluruh dokumen ini terlebih
> dahulu sebelum mengambil keputusan teknis apapun.
>
> Jika sebuah topik sudah diatur oleh dokumen lain di repo, file ini hanya **menautkan dan meringkas**
> — tidak menduplikasi isinya.

---

## Daftar Isi

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [System Design](#3-system-design)
4. [Core Domain Models](#4-core-domain-models)
5. [Backend Architecture](#5-backend-architecture)
6. [Frontend Architecture](#6-frontend-architecture)
7. [Application Flow & Lifecycle](#7-application-flow--lifecycle)
8. [Testing & Development Guidelines](#8-testing--development-guidelines)
9. [AI Working Rules](#9-ai-working-rules)

---

## 1. Project Overview

**Chatwoot** adalah platform *omnichannel customer support* open source yang memungkinkan tim support
mengelola percakapan pelanggan dari berbagai saluran (WhatsApp, Email, Live Chat, Telegram, dll.)
dalam satu antarmuka terpadu.

### Tech Stack Utama

| Layer | Teknologi |
|---|---|
| **Backend** | Ruby on Rails 7, Ruby 3.3.x, Puma (web server) |
| **Database** | PostgreSQL 14+ (primer), Redis (cache, queue, presence) |
| **Background Jobs** | Sidekiq dengan 16-queue Strict Priority |
| **Real-time** | Rails ActionCable over WebSockets |
| **Frontend** | Vue 3, Vite 6, Vuex 4 + Pinia 3, Tailwind CSS |
| **Build Tool** | `vite-plugin-ruby` (integrasi Rails asset pipeline + Vite) |
| **Auth** | `devise_token_auth` (API token), Devise (web session) |
| **Event Bus** | Gem `wisper` (Pub/Sub in-process) |
| **File Storage** | Rails ActiveStorage (lokal / S3 / GCS / Azure Blob) |
| **Testing** | RSpec (Ruby), Vitest (JS/Vue), Playwright (E2E) |
| **Linting** | RuboCop (Ruby), ESLint Airbnb+Vue3 (JS/Vue) |

### Mode Deployment & Lisensi

- **100% Pure MIT (Community Edition)**: Seluruh codebase di repositori ini berada di bawah
  lisensi **MIT Expat**. Direktori komersial `enterprise/` telah sepenuhnya dipurging/dihapus,
  menjadikan codebase ini bersih, bebas lisensi ganda, dan siap untuk di-deploy di infrastruktur
  GitLab/server internal perusahaan.
- **Enterprise Hooks**: Pola injeksi `prepend_mod_with` tetap dipertahankan secara pasif (no-op)
  sebagai standar arsitektur inti tanpa memuat modul enterprise apapun.

### Proses Startup

```
# Development
pnpm dev  ATAU  overmind start -f ./Procfile.dev

# Procfile.dev menjalankan 3 proses:
#   backend: bin/rails s -p 3000
#   worker:  bundle exec sidekiq -C config/sidekiq.yml
#   vite:    bin/vite dev
```

---

## 2. Repository Structure

Berikut peta direktori top-level beserta **tujuan dan tanggung jawab** masing-masing:

```
chatwoot/
│
├── app/                        # Inti aplikasi Rails (OSS)
│   ├── builders/               # Merakit objek domain kompleks (transaksional, multi-step)
│   │   └── messages/           # MessageBuilder, NotificationBuilder, dll.
│   ├── channels/               # ActionCable server-side channels
│   │   └── room_channel.rb     # Satu-satunya WebSocket channel utama
│   ├── controllers/            # HTTP request handlers
│   │   ├── api/v1/accounts/    # Semua endpoint API agen/admin (scoped per tenant)
│   │   ├── api/v1/widget/      # Endpoint untuk Live Chat Widget customer
│   │   └── webhooks/           # Penerima webhook dari provider eksternal (WhatsApp, Twilio, dll.)
│   ├── dispatchers/            # Event Bus: Dispatcher, SyncDispatcher, AsyncDispatcher
│   ├── finders/                # Query builder untuk pencarian dan filter kompleks
│   ├── helpers/                # Rails view/controller helpers
│   ├── javascript/             # Semua kode frontend (Vue, JS, SDK)
│   ├── jobs/                   # Sidekiq background jobs
│   ├── listeners/              # Event subscriber (ActionCable, Webhook, Automation, dll.)
│   ├── mailboxes/              # Rails ActionMailbox (inbound email processing)
│   ├── models/                 # ActiveRecord domain models
│   │   └── concerns/           # Shared behavior antar model (Labelable, Channelable, dll.)
│   ├── policies/               # Pundit authorization policies (per resource, per role)
│   ├── serializers/            # JSON serializer (API response shaping)
│   └── services/               # Business logic terisolasi (non-CRUD, non-builder)
│
├── config/
│   ├── initializers/
│   │   └── 01_inject_enterprise_edition_module.rb  # Injector prepend_mod_with (no-op saat enterprise dihapus)
│   │   └── event_handlers.rb                       # Registrasi event listener ke Dispatcher
│   ├── routes.rb               # Semua route aplikasi OSS
│   └── sidekiq.yml             # Konfigurasi 16 queue Sidekiq (priority order)
│
├── lib/
│   ├── events/                 # Definisi konstanta nama event (Events::Types)
│   ├── integrations/           # Logika integrasi pihak ketiga (Dialogflow, Slack, Linear, Dyte)
│   └── online_status_tracker.rb  # Redis-based presence tracker
│
├── spec/                       # RSpec test suite (mirror struktur app/)
│
├── tests/playwright/           # Playwright E2E tests
│
├── AGENTS.md                   # ⚠️ Aturan wajib: Build, Test, Lint, Code Style, Dev Guidelines
└── CONTEXT.md                  # File ini — Peta arsitektur dan aturan kerja AI
```

> **Catatan Lisensi — 100% Pure MIT:**
> Folder komersial non-MIT (`enterprise/` dan `spec/enterprise/`) telah dipurging secara menyeluruh.
> Seluruh kode pada repositori ini bebas digunakan, dimodifikasi, dan didistribusikan di bawah lisensi MIT.

---

## 3. System Design

### 3.1 High-Level Infrastructure

```
[ EXTERNAL CHANNELS ]          [ AGENT BROWSER ]        [ CUSTOMER WEBSITE ]
  WhatsApp, Twilio,              Dashboard SPA              Embedded Widget
  Telegram, Email                (Vue 3 / Vite)             (iframe + SDK.js)
        |                              |                          |
        |  HTTP Webhook POST           |  HTTP + WebSocket        |  postMessage
        |                              v                          v
        |               +-------------------------------------+
        +-------------> |    Nginx / Reverse Proxy / CDN      |
                        +-----------------+-------------------+
                                          |
                        +-----------------v-------------------+
                        |      RAILS (PUMA) APP SERVERS       |
                        |  - Webhook Controllers              |
                        |  - API Controllers (v1/accounts)    |
                        |  - ActionCable WebSockets           |
                        |  - Service & Builder Layer          |
                        |  - Wisper Event Bus (Dispatcher)    |
                        +---------+---------------+-----------+
                                  |               |
               +------------------+               +------------------+
               v                                                     v
        +-------------+                                    +------------------+
        |  PostgreSQL  |                                    |      Redis        |
        | Row-Level    |                                    | - Sidekiq Queues  |
        | Multitenancy |                                    | - ActionCable PS  |
        | per-Account  |                                    | - Presence Sorted |
        | Sequences    |                                    |   Sets            |
        +-------------+                                    | - Distributed Lock|
                                                           +--------+----------+
                                                                    |
                                                           +--------v----------+
                                                           |  SIDEKIQ WORKERS  |
                                                           | (16 Priority Queue)|
                                                           +-------------------+
```

### 3.2 Multi-Tenancy: Row-Level Isolation

Chatwoot **tidak menggunakan gem `apartment` (schema-based) maupun `acts_as_tenant`**.
Isolasi multi-tenant diimplementasikan secara mandiri dengan 4 mekanisme:

| Mekanisme | Implementasi | File |
|---|---|---|
| **Thread Context** | `Current.account`, `Current.user` (thread_mattr_accessor) | `lib/current.rb` |
| **Controller Guard** | `ensure_current_account` — validasi keanggotaan user di akun sebelum request diproses | `app/controllers/concerns/ensure_current_account_helper.rb` |
| **Explicit Query Scoping** | Semua query selalu dimulai dari `Current.account.conversations.find(...)` — tidak ada hidden `default_scope` | Semua controllers & finders |
| **PostgreSQL Sequence per Tenant** | Saat akun dibuat, trigger PostgreSQL membuat sequence `conv_dpid_seq_<account_id>`. `display_id` percakapan diambil dari sequence akun tersebut | `app/models/account.rb`, `app/models/conversation.rb` |

### 3.3 Enterprise Extension Pattern (Status: Inactive / Pure OSS)

Secara bawaan, Chatwoot menggunakan pola `prepend_mod_with` untuk mendukung injeksi modul komersial.
Namun, karena direktori `enterprise/` telah dihapus:
- `ChatwootApp.enterprise?` selalu mengembalikan `false`.
- `ChatwootApp.extensions` menghasilkan array kosong `[]`.
- Semua pemanggilan `prepend_mod_with` di akhir model OSS berjalan sebagai **no-op (tanpa operasi)**.
- Kode berjalan 100% murni di atas implementasi Rails OSS (`app/`).

### 3.4 Sidekiq Queue Priority (16 Queues)

Urutan prioritas **absolut** (queue lebih rendah hanya diproses jika queue di atasnya kosong):

| Prioritas | Queue Name | Job Utama |
|---|---|---|
| 1 | `:critical` | `ActionCableBroadcastJob`, `EventDispatcherJob` |
| 2 | `:high` | `SendReplyJob` (kirim pesan ke WhatsApp/SMS/Email) |
| 3 | `:medium` | `WebhookJob`, `AgentBots::WebhookJob` |
| 4 | `:default` | Ingress webhook (`WhatsappEventsJob`), `AutoAssignment` |
| 5 | `:mailers` | ActionMailer async delivery |
| 6 | `:action_mailbox_routing` | Routing inbound email |
| 7 | `:low` | Reporting backfill, cache sekunder |
| 8 | `:scheduled_jobs` | Sidekiq-cron jobs terjadwal |
| 9 | `:deferred` | Eksekusi automation yang ditunda |
| 10 | `:purgable` | Pembersihan notifikasi usang |
| 11 | `:housekeeping` | Pembersihan session & stale contacts |
| 12–16 | `:async_database_migration`, `:bulk_reindex_low`, `:active_storage_*`, `:action_mailbox_incineration` | Infrastruktur & storage maintenance |

> **File konfigurasi:** `config/sidekiq.yml`

---

## 4. Core Domain Models

### 4.1 Entity Relationship Overview

```
Account (Tenant Root)
├── has_many :account_users          # Membership agen/admin
├── has_many :users, through: account_users
├── has_many :inboxes                # Saluran komunikasi
│   └── belongs_to :channel (polymorphic)
│       ├── Channel::WebWidget       # Live Chat (tabel: channel_web_widgets)
│       ├── Channel::Whatsapp        # WhatsApp Cloud API (tabel: channel_whatsapp)
│       ├── Channel::Email           # Email IMAP/SMTP (tabel: channel_email)
│       ├── Channel::TwilioSms       # SMS/WhatsApp via Twilio
│       ├── Channel::Telegram        # Telegram Bot API
│       ├── Channel::FacebookPage    # Facebook Messenger
│       ├── Channel::Instagram       # Instagram DM
│       ├── Channel::Api             # Custom API Channel (webhook)
│       ├── Channel::Line            # LINE Messaging
│       ├── Channel::Tiktok          # TikTok DM
│       ├── Channel::Sms             # Generic SMS HTTP Gateway
│       └── Channel::TwitterProfile  # Twitter DM
├── has_many :contacts               # Entitas pelanggan
│   └── has_many :contact_inboxes    # Binding kontak ke inbox + source_id
│       └── has_many :conversations  # Thread percakapan
│           └── has_many :messages   # Pesan individual
│               └── has_many :attachments (ActiveStorage)
└── has_many :teams
    └── has_many :team_members (join: User)
```

### 4.2 Model Kritis & Atribut Penting

**`Account`** (`app/models/account.rb`)
- `feature_flags` / `feature_flags_ext_1`: Bitset fitur per-tenant via gem `flag_shih_tzu`
- `settings` (JSONB): Konfigurasi tenant (timezone, working hours, auto-resolve, Captain AI models)
- `limits` (JSONB): Batas kuota (agent limit, inbox limit)

**`AccountUser`** (`app/models/account_user.rb`)
- Join model `User ↔ Account`, menentukan role dan availability per tenant
- `role` enum: `agent: 0`, `administrator: 1`
- `availability` enum: `online: 0`, `offline: 1`, `busy: 2`

**`Inbox`** (`app/models/inbox.rb`)
- Relasi polimorfik ke Channel: kolom `channel_id` + `channel_type`
- `has_many :contact_inboxes` → gateway ke semua percakapan dari sumber tertentu

**`ContactInbox`** (`app/models/contact_inbox.rb`)
- Mengikat identitas eksternal saluran: `source_id` (nomor telepon, Telegram chat ID, UUID session)
- `pubsub_token`: Token unik untuk WebSocket subscription pengunjung widget
- Constraint unik: `[inbox_id, source_id]`

**`Conversation`** (`app/models/conversation.rb`)
- `status` enum: `open: 0`, `resolved: 1`, `pending: 2`, `snoozed: 3`
- `priority` enum: `low: 0`, `medium: 1`, `high: 2`, `urgent: 3`
- `display_id`: Nomor tampil publik — diambil dari PostgreSQL sequence per-tenant
- `assignee_id` → `User` (agen), `team_id` → `Team`
- `ai_assignee`: Bot aktif yang sedang menangani percakapan ini

**`Message`** (`app/models/message.rb`)
- `message_type` enum: `incoming: 0`, `outgoing: 1`, `activity: 2`, `template: 3`
- `content_type` enum: `text`, `input_text`, `cards`, `form`, `article`, `incoming_email`, `input_csat`, `voice_call`, dll.
- `sender` (polymorphic): bisa berupa `User`, `Contact`, atau `AgentBot`
- `status` enum: `sent`, `delivered`, `read`, `failed`

### 4.3 Enum Conversation Status — State Machine

```
[Pesan baru masuk]
        |
        +-- Ada bot aktif? --> YES --> STATUS: pending (bot handle, agen tidak dinotifikasi)
        |
        +-- Tidak ada bot  --> STATUS: open   (agen dinotifikasi)

pending --> open       : Bot handoff / agen membalas langsung / assign manual
open    --> resolved   : Manual oleh agen / Automation Rule
resolved --> pending   : Pelanggan membalas lagi + ada bot aktif
resolved --> open      : Pelanggan membalas lagi + tidak ada bot
open    --> snoozed    : Ditunda sementara (dengan timestamp wake-up)
snoozed --> open       : Otomatis saat timer habis
```

---

## 5. Backend Architecture

### 5.1 Layer Separation of Concerns

Chatwoot menerapkan *skinny controllers, clean models* dengan memisahkan logic ke layer spesialis:

| Layer | Folder | Tanggung Jawab | Contoh |
|---|---|---|---|
| **Controller** | `app/controllers/` | Autentikasi, autorisasi (Pundit), strong params, delegate ke Builder/Service | `MessagesController#create` |
| **Builder** | `app/builders/` | Merakit objek domain kompleks lintas model, menangani race condition, transaksi DB | `Messages::MessageBuilder`, `ContactInboxWithContactBuilder` |
| **Service** | `app/services/` | Business logic terisolasi: channel parsing, filter, status update, pengiriman eksternal | `Whatsapp::IncomingMessageService`, `Conversations::FilterService` |
| **Finder** | `app/finders/` | Query builder filter kompleks, selalu di-scope dari akun aktif | `ConversationFinder` |
| **Listener** | `app/listeners/` | Event subscriber — reaktif, tidak inisiasi sendiri | `ActionCableListener`, `WebhookListener`, `AutomationRuleListener` |
| **Job** | `app/jobs/` | Unit kerja Sidekiq — satu tanggung jawab, idempoten | `SendReplyJob`, `ActionCableBroadcastJob` |
| **Integration** | `lib/integrations/` | Koneksi ke sistem pihak ketiga non-channel (Dialogflow, Slack, Linear) | `Integrations::Dialogflow::ProcessorService` |

### 5.2 Event Bus: Wisper Dual Dispatcher

Sumber kebenaran event: `lib/events/types.rb` (konstanta nama event: `'message.created'`, `'conversation.created'`, dll.)

```
Domain Model Callback (after_create_commit / after_update_commit)
        |
        v
Rails.configuration.dispatcher.dispatch(event_name, timestamp, data)
        |
        +-- SyncDispatcher (eksekusi langsung di main thread)
        |       ├── ActionCableListener  --> WebSocket push ke agen (real-time instant)
        |       └── AgentBotListener     --> Kirim ke webhook bot / Dialogflow processor
        |
        └── AsyncDispatcher (enqueue ke Sidekiq)
                |
                v
        EventDispatcherJob (queue: :critical)
                |
                v
        Async Listeners:
        ├── WebhookListener          --> HTTP POST ke webhook eksternal
        ├── NotificationListener     --> Push notification & in-app alert
        ├── AutomationRuleListener   --> Evaluasi & eksekusi aturan otomatisasi
        ├── HookListener             --> Slack sync, Linear issue, LeadSquared
        ├── CsatSurveyListener       --> Trigger survei kepuasan paska resolve
        ├── ReportingEventListener   --> Metrik analytics (FRT, Resolution Time)
        └── Conversations::UnreadCounts::Listener --> Badge unread per agen
```

**Konvensi nama method listener:** Nama event dengan notasi titik dikonversi ke underscore.
Contoh: event `'message.created'` → memanggil method `message_created(event)` pada listener.

### 5.3 ActionCable Real-Time Architecture

File: `app/channels/room_channel.rb`

```
Setiap browser client berlangganan RoomChannel dengan:
  - pubsub_token: Token unik milik User atau ContactInbox
  - account_id:   ID akun yang diakses
  - user_id:      ID agen (kosong jika pengunjung widget)

Dua scope streaming per agen:
  1. Stream privat: pubsub_token
     --> Menerima: pesan baru, status ketikan, notifikasi personal
  2. Stream akun:   "account_<account_id>"
     --> Menerima: event tingkat tenant (contact.created, cache_invalidated)

Online Presence: Redis Sorted Sets (lib/online_status_tracker.rb)
  - Score = epoch timestamp ping terakhir
  - Agen: kadaluwarsa 20 detik | Contact visitor: kadaluwarsa 90 detik
```

---

## 6. Frontend Architecture

### 6.1 Multi-Entry Point Applications

File entry point berada di `app/javascript/entrypoints/`:

| Entry Point | File | Teknologi | Peran |
|---|---|---|---|
| **dashboard** | `dashboard.js` | Vue 3 SPA, Vue Router (History), Vuex + Pinia, Vue I18n | Aplikasi utama agen & admin |
| **widget** | `widget.js` | Vue 3 SPA, Vue Router (Hash), Vuex, ActionCable client | Live Chat Widget (iframe terisolasi) |
| **sdk** | `sdk.js` | IIFE Vanilla JS murni (tanpa framework) | Loader script embed di website customer |
| **v3app** | `v3app.js` | Vue 3 SPA, Vue Router, Vuex | Auth pages (Login, SSO, Onboarding) |
| **portal** | `portal.js` | Hotwire Turbo + Rails UJS | Knowledge Base publik (server-rendered) |
| **survey** | `survey.js` | Vue 3 mini-SPA, Vuex, Vue I18n | Halaman CSAT (kepuasan pelanggan) |

Build pipeline:
- Semua entry point kecuali `sdk` dikompilasi via `vite-plugin-ruby` (integrated dengan Rails asset pipeline).
- `sdk.js` dikompilasi terpisah via `vite.lib.config.ts` menjadi single-file IIFE + versi Brotli & Gzip.
- Alias path penting: `components` → `dashboard/components`, `next` → `components-next`, `shared` → `shared/`.

### 6.2 State Management: Vuex 4 + Pinia 3 Coexistence

```
app/javascript/dashboard/
├── store/index.js              # Vuex 4 root store (40+ modul fungsional — STORE UTAMA)
│   ├── modules/conversations/  # Koleksi percakapan & pesan
│   ├── modules/inboxes.js
│   ├── modules/contacts/
│   ├── modules/agents.js
│   ├── modules/notifications/
│   └── captain/               # AI Copilot store modules
│
├── stores/                     # Pinia 3 (fitur baru — migrasi bertahap)
│   ├── calls.js                # useCallsStore (Twilio Voice WebRTC)
│   └── callHistory.js          # useCallHistoryStore
│
└── store/storeFactory.js       # Universal factory: satu definisi → Vuex ATAU Pinia
```

**Strategi caching client-side (IndexedDB via `idb`):**
- Database: `cw-store-<accountId>` dibuat per tenant di browser.
- Data yang dicache: `inbox`, `label`, `team`, `canned_response`.
- Validasi via `CacheEnabledApiClient`: bandingkan hash lokal dengan `/api/v1/accounts/:id/cache_keys`.
  Jika hash sama → ambil dari IndexedDB (tanpa network). Jika beda → fetch dan commit ulang.

### 6.3 Widget SDK: Iframe Isolation Pattern

```
[ Website Customer ]
        |
        | <script> menyematkan sdk.js
        v
[ SDK (sdk.js) — Vanilla JS IIFE ]
        |
        ├── Membuat <div id="cw-widget-holder"> di DOM host
        ├── Membuat <iframe src="/widget?website_token=..."> di dalam holder
        └── Membuat launcher bubble di luar iframe (agar animasi tetap responsif)
        |
        | Komunikasi: window.postMessage("chatwoot-widget:" + JSON.stringify({event, payload}))
        |
[ Widget Iframe — widget.js (Vue 3 SPA) ]
        |
        ├── Parent → Iframe: config-set, set-user, set-custom-attributes, toggle-open, change-url
        └── Iframe → Parent: loaded, setFrameHeightToFitContent, onEvent, toggleBubble
```

Dukungan mobile: Jika berjalan di React Native WebView, pesan dikirim via
`window.ReactNativeWebView.postMessage`.

### 6.4 Component Architecture

```
app/javascript/dashboard/
├── components-next/            # MODERN — wajib digunakan untuk UI baru
│   ├── button/, dialog/, dropdown-menu/, input/
│   ├── sidebar/, combobox/, table/, popover/
│   └── message/                # Message bubble components (gunakan ini, bukan yang lama)
│       └── bubbles/            # Text, Image, Audio, Video, Email, CSAT, VoiceCall, dll.
│
├── components/                 # LEGACY — sedang deprecated, JANGAN tambahkan komponen baru
│   └── index.js                # Plugin WootUIKit global (prefix woot-*)
│
└── routes/dashboard/
    ├── Dashboard.vue           # Root layout (Sidebar + main content area + overlays)
    └── conversation/
        ├── ChatList.vue        # Panel kiri: daftar percakapan
        ├── ConversationBox.vue # Panel tengah: timeline pesan + composer
        └── ContactPanel.vue    # Panel kanan: detail kontak + history
```

**Design System:**
- **Tailwind Only** — dilarang scoped CSS, inline styles, atau custom CSS class baru.
- **Color tokens:** `n-*` namespace (misal `bg-n-surface-1`, `text-n-slate-12`, `border-n-weak`)
  berbasis Radix UI Color Primitives. Periksa `tailwind.config.js` dan `theme/colors.js`.
- **Icons:** `@egoist/tailwindcss-icons` via Iconify — gunakan class seperti `i-lucide-phone`.
- **Typography:** Font `Inter` dan `InterDisplay`.

---

## 7. Application Flow & Lifecycle

### 7.1 Inbound Message Flow (Customer → Agent Dashboard)

```
[1] Customer mengirim pesan
     (WhatsApp, Widget, Telegram, Email, Twilio, dll.)
        ↓
[2] Webhook / API Controller menerima request
     - Verifikasi signature (HMAC untuk WhatsApp / JWE token untuk Widget)
     - Balas HTTP 200 OK segera ke provider (agar tidak timeout)
        ↓
[3] Ingress Job (Sidekiq queue: :default)
     Contoh: Webhooks::WhatsappEventsJob.perform_later(params)
        ↓
[4] Incoming Service + Builders
     ├── ContactInboxSourceIdResolver  → Ambil/buat Contact & ContactInbox
     ├── Conversation Finder/Builder   → Ambil percakapan aktif atau buat baru
     └── Messages::MessageBuilder      → Simpan Message + Attachments ke PostgreSQL
        ↓
[5] Database Commit → Callback: Message#after_create_commit
     → dispatch('message.created', ...)
        ↓
[6] Dual Dispatcher
     ├── [SYNC] ActionCableListener
     │     → ActionCableBroadcastJob (queue: :critical)
     │     → ActionCable.server.broadcast(pubsub_token, { event, data })
     │     → Vue store dispatch 'addMessage' → UI render real-time ✓
     │
     └── [ASYNC via Sidekiq] EventDispatcherJob (queue: :critical)
           ├── AutomationRuleListener  → Evaluasi & eksekusi aturan
           ├── NotificationListener   → Push notification ke agen
           ├── WebhookListener        → HTTP POST ke webhook eksternal
           └── ReportingEventListener → Catat metrik analytics
```

### 7.2 Outbound Message Flow (Agent → Customer)

```
[1] Agen klik Send di Dashboard (Vue 3)
     → Optimistic UI: Pesan sementara langsung tampil (status: PROGRESS)
        ↓
[2] HTTP POST /api/v1/accounts/:id/conversations/:conv_id/messages
     Controller: Api::V1::Accounts::Conversations::MessagesController#create
        ↓
[3] Messages::MessageBuilder
     → Validasi konten, sanitasi, pasang lampiran ActiveStorage
     → message.save! (status: :sent, message_type: :outgoing)
        ↓
[4] Callback: Message#send_reply
     → SendReplyJob.perform_later(message.id)  [queue: :high]
        ↓
[5] SendReplyJob (Sidekiq worker)
     → Deteksi tipe channel dari inbox
     → Delegasikan ke Channel Service:
          Channel::Whatsapp  → Whatsapp::SendOnWhatsappService  (Meta Graph API)
          Channel::TwilioSms → Twilio::SendOnTwilioService
          Channel::Email     → Email::SendOnEmailService (SMTP/Mailgun/SES)
          Channel::Telegram  → Telegram::SendOnTelegramService
          Channel::WebWidget → Messages::SendEmailNotificationService
        ↓
[6] Provider eksternal mengembalikan external_message_id
     → message.update!(source_id: external_id)
        ↓
[7] Delivery Receipt (DLR) — Asinkron dari Provider
     → Webhook status diterima (delivered / read)
     → Messages::StatusUpdateService (forward-only: sent→delivered→read)
     → Callback after_update_commit → dispatch('message.updated')
     → ActionCable broadcast → Vue store updateMessage
     → Indikator centang di UI berubah ✓
```

### 7.3 Bot & Automation State Machine

Lihat detail state machine di [Section 4.3](#43-enum-conversation-status--state-machine).

**Titik kode kritis:**
- `Conversation#bot_handoff!` → `app/models/conversation.rb` — Eskalasi bot ke agen manusia
- `Message#mark_pending_conversation_as_open_for_human_response` → `app/models/message.rb` — Intervensi langsung agen
- `Message#reopen_conversation` → `app/models/conversation.rb` — Re-open saat pesan baru masuk ke percakapan resolved
- `AutomationRules::ActionService#perform` → `app/services/automation_rules/action_service.rb` — Eksekusi aksi otomatisasi

### 7.4 Real-Time Reconnection & Resilience

Implementasi di `app/javascript/dashboard/helper/ReconnectService.js`:
- Jika WebSocket terputus → timer reconnect berkala (interval 1000ms).
- Jika terputus > 3 jam (`MAX_DISCONNECT_SECONDS = 10800`) → reload halaman otomatis.
- Saat reconnect berhasil:
  1. `fetchConversationsOnReconnect()` → sinkronisasi delta daftar percakapan.
  2. `syncActiveConversationMessages({ conversationId })` → tambal pesan yang terlewat.
  3. `revalidateCaches()` → validasi ulang hash IndexedDB.

---

## 8. Testing & Development Guidelines

> **Sumber utama:** Baca dan patuhi seluruh aturan di [`AGENTS.md`](./AGENTS.md).
> Dokumen ini hanya merangkum poin kritis agar tidak terlewat.

### 8.1 Perintah Wajib

```bash
# Setup
bundle install && pnpm install

# Jalankan aplikasi (development)
pnpm dev  ATAU  overmind start -f ./Procfile.dev

# Seed data minimal (untuk verifikasi fitur standar)
bundle exec rails db:seed

# Seed data kaya (untuk testing search/load/manual)
bundle exec rails search:setup_test_data

# Test Ruby (RSpec)
bundle exec rspec spec/path/to/file_spec.rb
bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER  # Test spesifik per baris

# Test JS/Vue (Vitest)
pnpm test
pnpm test:watch

# Lint Ruby
bundle exec rubocop -a

# Lint JS/Vue
pnpm eslint
pnpm eslint:fix
```

### 8.2 Aturan Kritis Testing

- **Jangan tulis spec kecuali diminta eksplisit oleh user.**
- Gunakan `let` dan setup per-example — hindari custom helper method kecuali menghilangkan kompleksitas signifikan.
- Untuk testing variabel environment, gunakan `with_modified_env` (bukan stub `ENV` langsung).
- Ketika membandingkan class error yang di-raise, gunakan `error.class.name` (string), bukan `error.class` (constant reference).

### 8.3 Aturan Kritis Development

- **Ruby**: Max 150 karakter per baris. Gunakan compact `module/class` definitions.
- **Vue**: Selalu gunakan Composition API dengan `<script setup>` di bagian paling atas komponen.
- **Styling**: Tailwind utility class only. Dilarang: custom CSS, scoped CSS, inline styles.
- **String di template**: Gunakan i18n key — dilarang bare string literal.
- **Strong params**: Validasi selalu di controller boundary, kembalikan `422 Unprocessable Entity` untuk input invalid.
- **Enterprise**: Sebelum mengedit file di `app/`, selalu cek apakah ada pasangan overlay di `enterprise/`. Gunakan `prepend_mod_with` untuk ekstensi Enterprise, bukan edit langsung file OSS.
- **Translations**: Hanya update `en.yml` (backend) dan `en.json` (frontend). File bahasa lain dikelola via Crowdin.
- **Commit messages**: Conventional Commits — `type(scope): subject`. Jangan menyebut nama AI di commit.

---

## 9. AI Working Rules

Bagian ini berisi instruksi eksplisit bagi AI yang menggunakan file ini sebagai konteks.

### 9.1 Prosedur Wajib Sebelum Menulis Kode

1. **Baca `AGENTS.md`** untuk memastikan kepatuhan terhadap code style, lint rules, dan dev workflow.
2. **Verifikasi path riil**: Gunakan `glob` atau `grep` untuk memastikan file yang akan diedit benar-benar ada. Dilarang mengarang path.
3. **Baca file sebelum edit**: Gunakan `read` untuk membaca konten aktual file target sebelum menggunakan tool `edit`.

### 9.2 Entry Point Investigasi per Domain

Gunakan titik masuk berikut saat menginvestigasi domain tertentu:

| Domain | Entry Point Investigasi |
|---|---|
| **Pesan masuk dari channel tertentu** | `app/services/<channel>/incoming_message_service.rb` |
| **Pesan keluar ke channel tertentu** | `app/jobs/send_reply_job.rb` → `app/services/<channel>/send_on_<channel>_service.rb` |
| **Event yang terjadi saat pesan dibuat** | `app/models/message.rb` → callback `after_create_commit` |
| **Aturan otomatisasi** | `app/listeners/automation_rule_listener.rb` → `app/services/automation_rules/` |
| **WebSocket broadcast** | `app/listeners/action_cable_listener.rb` → `app/jobs/action_cable_broadcast_job.rb` |
| **Autentikasi & autorisasi** | `app/controllers/concerns/ensure_current_account_helper.rb`, `app/policies/` |
| **Multi-tenancy scoping** | `lib/current.rb`, `app/controllers/api/v1/accounts/base_controller.rb` |
| **Channel polymorphism** | `app/models/inbox.rb`, `app/models/concerns/channelable.rb` |
| **Bot handoff logic** | `app/models/conversation.rb` (`bot_handoff!`), `app/models/message.rb` (`human_response?`) |
| **Frontend store** | `app/javascript/dashboard/store/modules/conversations/` |
| **Widget komunikasi** | `app/javascript/sdk/IFrameHelper.js`, `app/javascript/widget/helpers/utils.js` |

### 9.3 Hal yang Wajib Diverifikasi Sebelum Mengambil Keputusan

- **Tipe channel polymorphic**: `channel_type` di tabel `inboxes` — jangan asumsikan STI.
- **Status percakapan saat ini**: Perilaku berbeda antara `pending`, `open`, `resolved`.
- **Keberadaan bot aktif**: `conversation.inbox.active_bot?` — menentukan status percakapan saat re-open.
- **Queue Sidekiq job baru**: Sesuaikan dengan prioritas yang sudah ada di `config/sidekiq.yml`.
- **Scope query tenant**: Semua query **wajib** dimulai dari `Current.account` atau scope yang setara.
- **Apakah modul Enterprise perlu diupdate**: Jika method OSS dimodifikasi dan ada overlay Enterprise, kedua file harus diperbarui secara konsisten.

### 9.4 Anti-Pattern yang Harus Dihindari

- ❌ Menulis `default_scope` di model untuk scoping tenant — dapat menyebabkan kebocoran data.
- ❌ Menambahkan komponen Vue baru ke `dashboard/components/index.js` (legacy deprecated).
- ❌ Menulis CSS kustom atau scoped style — gunakan Tailwind utility class.
- ❌ Menggunakan `git add .` — selalu stage file spesifik.
- ❌ Menambahkan spec tanpa diminta eksplisit user.
- ❌ Menulis logika Business di controller — delegasikan ke Builder atau Service.
- ❌ Mengasumsikan channel menggunakan STI — channel adalah polymorphic association.
- ❌ Melakukan direct query tanpa scope akun: `Conversation.find(id)` → **SALAH**.
  Gunakan: `Current.account.conversations.find(id)` → **BENAR**.
- ❌ Memodifikasi file di `enterprise/` untuk logika yang seharusnya ada di `app/` (OSS), atau sebaliknya.
