# 🚀 Panduan Deploy PM Report Bot

## Overview Sistem

```
📱 Telegram (User)
      ↓ /laporan
🌐 Mini App (index.html) — via Cloudflare Tunnel / ngrok
      ↓ upload foto + form data
🐍 Flask Server (app.py) — port 5000
      ↓ generate dokumen
📄 generate.py — replace [IMG] & strip [CAPTION] di template DOCX
      ↓ kirim file
✈️ Telegram Group — terima file DOCX
```

---

## Struktur Folder

```
pm-report-bot/
├── app.py                  ← Flask server + Telegram bot handler
├── generate.py             ← Logic generate DOCX dari template
├── requirements.txt        ← Python dependencies
├── setup.sh                ← Script setup otomatis
├── .env                    ← Config rahasia (buat dari .env.example)
├── .env.example            ← Template config
├── DEPLOY_GUIDE.md         ← Panduan ini
│
├── miniapp/
│   └── index.html          ← UI Telegram Mini App
│
├── templates/              ← Template DOCX (jangan diubah)
│   ├── weeklymvxr.docx
│   ├── weeklyrtt.docx
│   ├── monthlymvxr.docx
│   └── monthlyrtt.docx
│
├── uploads/                ← Foto upload dari user (auto dibuat)
├── outputs/                ← Hasil generate DOCX (auto dibuat)
└── temp/                   ← File temporary (auto dibuat)
```

---

## Spesifikasi Server

| Komponen | Minimum | Rekomendasi |
|---|---|---|
| OS | Ubuntu 20.04 | Ubuntu 22.04 LTS |
| RAM | 1 GB | 2 GB |
| Storage | 10 GB | 20 GB |
| Python | 3.8+ | 3.10+ |
| Internet | Wajib | Wajib |

---

## Langkah 1: Persiapan Server

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip git curl wget screen
python3 --version
pip3 --version
```

---

## Langkah 2: Copy Project ke Server

```bash
mkdir -p ~/pm-report-bot
cd ~/pm-report-bot
# Copy semua file ke folder ini
```

Pastikan struktur folder sudah benar sebelum lanjut.

---

## Langkah 3: Jalankan Setup

```bash
cd ~/pm-report-bot
chmod +x setup.sh
./setup.sh
```

---

## Langkah 4: Konfigurasi .env

```bash
cp .env.example .env
nano .env
```

```env
BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ
CHAT_ID_GROUP=-1001234567890
SERVER_URL=https://app.yourdomain.com
```

**Cara dapat BOT_TOKEN:**
1. Buka @BotFather di Telegram
2. `/newbot` untuk buat baru atau `/mybots` untuk yang sudah ada
3. Copy token — jangan share ke siapapun!

**Cara dapat CHAT_ID_GROUP:**
1. Tambahkan @getidsbot ke group
2. Ketik `/id` di group
3. Copy angkanya (biasanya diawali `-100...`)
4. Hapus @getidsbot dari group

**SERVER_URL:**
- Wajib HTTPS
- Tanpa trailing slash
- Contoh: `https://app.pmreport.my.id`

---

## Langkah 5: Setup HTTPS

### Opsi A — Cloudflare Tunnel (Rekomendasi, Gratis, URL Permanen)

**Prasyarat:** Domain aktif di Cloudflare

```bash
# Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
cloudflared --version

# Login
cloudflared tunnel login
# Buka URL yang muncul di browser, authorize

# Buat tunnel
cloudflared tunnel create pm-report-bot
# Catat Tunnel ID yang muncul

# Buat config
mkdir -p ~/.cloudflared
nano ~/.cloudflared/config.yml
```

Isi `config.yml`:
```yaml
tunnel: TUNNEL-ID-KAMU
credentials-file: /home/USER/.cloudflared/TUNNEL-ID-KAMU.json

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:5000
  - service: http_status:404
```

```bash
# Tambah DNS record
cloudflared tunnel route dns pm-report-bot app.yourdomain.com

# Install & enable service (auto-start saat boot)
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

### Opsi B — ngrok (Testing saja, URL berubah tiap restart)

```bash
# Install
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# Daftar di https://ngrok.com lalu:
ngrok config add-authtoken TOKEN_NGROK_KAMU

# Jalankan di terminal terpisah
ngrok http 5000
# Copy URL https://xxxx.ngrok-free.app → update SERVER_URL di .env → restart gunicorn/pmbot
```

---

## Langkah 6: Setup Telegram Bot

1. Buka **@BotFather**
2. `/mybots` → pilih bot → **Bot Settings**
3. **Menu Button → Edit Menu Button URL**
4. Isi: `https://app.yourdomain.com`

Set commands (opsional):
```
/setcommands → pilih bot → paste:
laporan - Buat laporan PM baru
status - Cek status bot
```

---

## Langkah 7: Jalankan Aplikasi

### Manual (testing):
```bash
cd ~/pm-report-bot
gunicorn --workers 4 --bind 0.0.0.0:5000 app:app
```

### Pakai screen (rekomendasi):
```bash
screen -S pmbot
cd ~/pm-report-bot
gunicorn --workers 4 --bind 0.0.0.0:5000 app:app
# Ctrl+A lalu D untuk detach
# screen -r pmbot untuk kembali
```

### Pakai systemd (production, auto-restart):

**1. Service untuk Gunicorn (Flask Web)**
```bash
sudo nano /etc/systemd/system/pmbot.service
```

```ini
[Unit]
Description=PM Report Bot Web Service
After=network.target

[Service]
Type=simple
User=minis
WorkingDirectory=/home/minis/pm-report-bot
ExecStart=/usr/local/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 app:app
Restart=always
RestartSec=10
EnvironmentFile=/home/minis/pm-report-bot/.env

[Install]
WantedBy=multi-user.target
```

**2. Service untuk Telegram Bot (Polling)**
Aplikasi telegram bot dijalankan di service yang terpisah dari web server Gunicorn.
```bash
sudo nano /etc/systemd/system/pmbot-telegram.service
```

```ini
[Unit]
Description=PM Report Telegram Bot Service
After=network.target

[Service]
Type=simple
User=minis
WorkingDirectory=/home/minis/pm-report-bot
ExecStart=/usr/bin/python3 app.py bot
Restart=always
RestartSec=10
EnvironmentFile=/home/minis/pm-report-bot/.env

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable pmbot pmbot-telegram
sudo systemctl start pmbot pmbot-telegram
sudo systemctl status pmbot
sudo systemctl status pmbot-telegram

# Lihat log real-time
journalctl -u pmbot -f
journalctl -u pmbot-telegram -f
```

---

## Langkah 8: Verifikasi

```bash
# 1. Test Flask lokal
curl http://localhost:5000/health
# Output: {"status":"ok","time":"..."}

# 2. Test via HTTPS
curl https://app.yourdomain.com/health
# Output: {"status":"ok","time":"..."}

# 3. Test di Telegram
# Ketik /laporan → tap tombol 📋 Buat Laporan PM → Mini App terbuka
```

---

## Maintenance

### Update file kode:
```bash
cd ~/pm-report-bot

# Kalau pakai systemd:
sudo systemctl stop pmbot
cp /path/to/new/file.py .
cp /path/to/new/index.html miniapp/
sudo systemctl start pmbot

# Kalau pakai screen:
screen -r pmbot → Ctrl+C
cp file baru
gunicorn --workers 4 --bind 0.0.0.0:5000 app:app
```

### Bersihkan file lama dengan cron:
```bash
crontab -e
```
Tambahkan:
```
# Hapus isi folder uploads dan outputs yang lebih lama dari 2 jam (120 menit)
# Pengecekan berjalan setiap jam di menit 0
0 * * * * find /home/minis/pm-report-bot/uploads -type f -mmin +120 -delete
0 * * * * find /home/minis/pm-report-bot/outputs -type f -mmin +120 -delete
```

---

## Troubleshooting

| Masalah | Penyebab | Solusi |
|---|---|---|
| `Token must contain a colon` | `.env` tidak terbaca | Pastikan `load_dotenv()` ada di `app.py`, format `.env` tanpa spasi/quotes |
| `Template tidak ditemukan` | File DOCX tidak ada | Copy 4 file ke `templates/` |
| `Jumlah foto tidak sesuai` | Total foto ≠ 29 | Semua template butuh tepat **29 foto** (6+9+14) |
| Mini App tidak bisa dibuka | Bukan HTTPS | SERVER_URL harus `https://` |
| `[CAPTION]` masih muncul | `generate.py` lama / belum restart | Copy file terbaru + restart gunicorn / pmbot |
| Laporan tidak terkirim ke Telegram | CHAT_ID salah | Pakai @getidsbot untuk dapat ID group |
| `Connection refused` port 5000 | Flask tidak jalan | Cek gunicorn service + `sudo ufw allow 5000` |
| Upload foto gagal | Timeout / koneksi lambat | Foto dikompres otomatis, cek koneksi internet |
| Error 1033 Cloudflare | cloudflared tidak reach Flask | Jalankan Flask dulu, baru cloudflared |

---

## Informasi Teknis

### Template DOCX:
- Semua 4 template: **29 placeholder [IMG]**
- Breakdown: Section 1 MVXR (6) + Section 2 RTT110 (9) + Section 3 Weekly/Monthly (14) = **29**
- Placeholder teks: `{{date}}`, `{{personil}}`, `{{serial_number}}`
- Placeholder gambar: `[IMG]` → diganti foto
- Placeholder caption: `[CAPTION]` → dihapus otomatis

### Nama file output:
```
Dokumentasi_Laporan_PM_Peralatan_HBS_DD-MM-YYYY.docx
```

### Port yang digunakan:
- **5000** — Flask server (internal)
- **443** — HTTPS via Cloudflare Tunnel (eksternal)
