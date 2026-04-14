# 🚀 Panduan Deploy PM Report Bot ke Render.com

Render.com adalah opsi populer selain Heroku dan Railway. Render menyediakan **Web Service gratis** yang bisa dimanfaatkan, namun ada **beberapa batasan penting** yang harus kamu ketahui sebelum melanjutkan.

---

## ⚠️ Batasan Render.com (Free Tier)
1. **Aplikasi "Tidur" (Sleep):** Setelah 15 menit tanpa ada request masuk ke web, Render akan mematikan aplikasi kamu untuk menghemat resource. Aplikasi akan nyala lagi ketika ada request, tapi akan memakan waktu sekitar 30 detik (cold start) dan Telegram bot kamu tidak akan bisa merespon saat aplikasi tidur.
2. **Disk Ephemeral (Sementara):** Setiap kali aplikasi restart atau bangun dari tidur, semua file di folder `uploads/` dan `outputs/` **akan hilang**. Ini batas toleransi yang aman karena pengguna biasanya langsung mendownload DOCX yang baru dibuat, tapi file log dan cache akan bersih kembali.
3. **Keterbatasan Background Worker:** Render memerlukan bayaran untuk menjalankan Background Worker yang khusus menangani polling Telegram Bot 24/7. Oleh karena itu, kita akan menjalankan Web (Gunicorn) dan Bot Polling di dalam satu container.

Jika kamu setuju dengan batasan tersebut (cocok untuk testing atau pemakaian ringan), mari kita lanjutkan.

---

## Langkah 1: Persiapan File Modifikasi
Agar Render bisa menjalankan **Web Server (Flask)** dan **Telegram Bot** secara bersamaan dalam satu layanan gratis, kita harus membuat script pemula.

Buat file baru di root project kamu dengan nama `render_start.sh` dan isi dengan:

```bash
#!/bin/bash
# Jalankan bot di background
python app.py bot &

# Jalankan Gunicorn Web Server di foreground
gunicorn --workers 2 --bind 0.0.0.0:$PORT app:app
```

Jangan lupa mengubah permission agar script bisa dieksekusi, tapi kita juga bisa langsung memanggilnya dengan bash di Render.

## Langkah 2: Upload Kode ke GitHub
Render akan menarik dan mendeploy kode kamu langsung dari repository GitHub pribadi kamu.
1. Buat repository baru di [GitHub](https://github.com/).
2. Upload semua file (kecuali folder `__pycache__`, `uploads/`, `temp/`, `outputs/` dan file `app.log`, `.env`). Pastikan file `render_start.sh` dan `requirements.txt` ikut terupload.

---

## Langkah 3: Deploy di Dashboard Render
1. Buka [Dashboard Render](https://dashboard.render.com/) dan login menggunakan akun GitHub-mu.
2. Klik tombol **New +** dan pilih **Web Service**.
3. Pilih opsi **Build and deploy from a Git repository** dan klik Next.
4. Hubungkan dan pilih repository GitHub kamu yang berisi kode PM Report Bot.

---

## Langkah 4: Konfigurasi Web Service
Isi formulir konfigurasi layanan dengan detail berikut:

- **Name:** `pm-report-bot` (Bebas)
- **Region:** Singapore atau Frankfurt (Pilih yang paling dekat)
- **Branch:** `main` (Atau `master`)
- **Runtime:** `Python 3`
- **Build Command:** `pip install -r requirements.txt`
- **Start Command:** `bash render_start.sh`

**Pilih Free Plan** pada bagian instance type.

---

## Langkah 5: Set Environment Variables
Scroll ke bawah dan klik tulisan **Advanced** lalu **Add Environment Variable**. Tambahkan ini:

| Key | Value | Keterangan |
|---|---|---|
| `BOT_TOKEN` | *Token bot kamu* | Token dari @BotFather |
| `CHAT_ID_GROUP` | *ID Group kamu* | Harus minus, contoh: `-1001234567890` |
| `ALLOWED_USERS` | *ID User* | Contoh: `12345,67890` (Opsional, pisah dengan koma) |
| `SERVER_URL` | *Isi sementara dulu* | Contoh: `https://pm-report-bot.onrender.com` |
| `PYTHON_VERSION`| `3.10.0` | (Sangat disarankan: Menghindari error kompatibilitas) |

> 💡 **Penting mengenai `SERVER_URL`:** 
> Vercel maupun Render otomatis membuatkan URL untuk websitemu, format Render biasanya `https://<nama-app>.onrender.com`. Sementara gunakan tebakan namamu (kamu bisa cek URL final di kiri atas dashboard setelah tekan "Create Web Service").

Klik tombol **Create Web Service**.

---

## Langkah 6: Proses Build & Koreksi SERVER_URL
Render akan mulai melakukan build dan install python dependency sesuai `requirements.txt`.
Tunggu sampai indikator berwarna hijau bertanda **Live**.

Jika di awal kamu menebak `SERVER_URL` yang salah:
1. Salin URL asli aplikasi publik dari pojok kiri atas dashboard (contoh: `https://pm-report-bot-xyz.onrender.com`).
2. Masuk ke tab **Environment** dari aplikasimu.
3. Ubah `SERVER_URL` menjadi URL yang benar (hilangkan slash `/` atau enter di akhir URL!).
4. Simpan, Render akan otomatis me-restart aplikasi.

---

## Langkah 7: Hubungkan ke Telegram Bot
Pada titik ini API dan Web App Mini sudah jalan.
1. Buka **@BotFather** di Telegram.
2. Kirim perintah `/mybots` lalu pilih bot milikmu.
3. Masuk ke **Bot Settings** → **Menu Button** → **Edit Menu Button URL**.
4. Masukkan URL dari Render tadi (Sesuai SERVER_URL, contoh: `https://pm-report-bot.onrender.com`).

**Test Bot Kamu:**
Buka bot kamu lalu tekan `/laporan` atau tekan tombol menu di kiri bawah layar. Mini App harus terbuka menggunakan antarmuka website dari Render.

---

## 💡 Troubleshooting / Masalah Umum
1. **Bot Tidak Merespon `/laporan`:** Aplikasi mungkin sedang "Tidur" (Kelemahan Free-tier Render). Buka halaman `https://<url-render-mu>/health` di browser untuk membangunkannya paksa. (Tunggu 30 detik untuk cold-start).
2. **Muncul Error 500 / 502:** Buka tab **Logs** di Render dashboard untuk melihat error apa yang dikeluhkan oleh Python.
3. **Upload Foto Gagal:** Pastikan Render tidak membunuh koneksi karena melewati batas timeout. Ukuran foto 5MB harusnya cukup kecil, namun Render memiliki batasan payload per request yang mungkin terlewati. Pastikan log menunjukan proses file yang benar.
4. **Meminta untuk keep-alive:** Bisa pakai jasa cron-job.org untuk *ping* atau membuka halaman `/health` setiap 10 menit agar bot kamu berjalan terus tanpa tertidur.
