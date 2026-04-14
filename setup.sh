#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
sec()  { echo -e "\n${BLUE}── $1 ──${NC}"; }

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║     PM Report Bot — Setup Script      ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Cek direktori
sec "Verifikasi Direktori"
if [ ! -f "app.py" ]; then
    err "Jalankan dari folder pm-report-bot/ yang berisi app.py"
    exit 1
fi
ok "Direktori: $(pwd)"

# Cek Python
sec "Cek Python"
if ! command -v python3 &> /dev/null; then
    warn "Menginstall Python3..."
    sudo apt update && sudo apt install -y python3 python3-pip
fi
ok "Python: $(python3 --version)"

# Install dependencies
sec "Install Python Dependencies"
pip3 install -r requirements.txt --quiet
python3 -c "import flask, telebot, docx, docxtpl, PIL, dotenv; print('OK')" \
    && ok "Semua library terinstall" \
    || { err "Ada library yang gagal install, cek requirements.txt"; exit 1; }

# Buat folder
sec "Setup Folder"
mkdir -p templates outputs uploads temp miniapp
ok "Folder: templates/ outputs/ uploads/ temp/ miniapp/"

# Cek template DOCX
sec "Cek Template DOCX"
MISSING=0
for tpl in weeklymvxr.docx weeklyrtt.docx monthlymvxr.docx monthlyrtt.docx; do
    if [ -f "templates/$tpl" ]; then
        ok "templates/$tpl"
    else
        err "templates/$tpl TIDAK ADA"
        MISSING=$((MISSING+1))
    fi
done

[ $MISSING -gt 0 ] && warn "$MISSING template kurang — copy ke folder templates/"

# Verifikasi jumlah [IMG]
python3 -c "
import os
from docx import Document
for t in ['weeklymvxr','weeklyrtt','monthlymvxr','monthlyrtt']:
    p = f'templates/{t}.docx'
    if not os.path.exists(p): continue
    doc = Document(p)
    n = sum(1 for tbl in doc.tables for row in tbl.rows
            for cell in row.cells for para in cell.paragraphs
            if '[IMG]' in para.text)
    s = '✓' if n==29 else f'✗ HARUS 29, ini {n}'
    print(f'  {t}: {n} [IMG] {s}')
" 2>/dev/null || true

# Cek miniapp
sec "Cek Mini App"
if [ -f "miniapp/index.html" ]; then
    ok "miniapp/index.html ($(wc -c < miniapp/index.html) bytes)"
else
    err "miniapp/index.html tidak ada — copy file index.html ke miniapp/"
fi

# Setup .env
sec "Konfigurasi .env"
if [ ! -f ".env" ]; then
    [ -f ".env.example" ] && cp .env.example .env && warn ".env dibuat dari .env.example — wajib diisi!"
else
    ok ".env sudah ada"
    BOT=$(grep "^BOT_TOKEN=" .env | cut -d= -f2 | tr -d ' ')
    CID=$(grep "^CHAT_ID_GROUP=" .env | cut -d= -f2 | tr -d ' ')
    URL=$(grep "^SERVER_URL=" .env | cut -d= -f2 | tr -d ' ')
    [ -z "$BOT" ] || [ "$BOT" = "ISI_TOKEN_BOT_KAMU" ] && warn "BOT_TOKEN belum diisi" || ok "BOT_TOKEN: ${BOT:0:12}..."
    [ -z "$CID" ] || [ "$CID" = "ISI_CHAT_ID_GROUP" ] && warn "CHAT_ID_GROUP belum diisi" || ok "CHAT_ID_GROUP: $CID"
    [ -z "$URL" ] || [ "$URL" = "https://YOUR_SERVER_URL" ] && warn "SERVER_URL belum diisi" || ok "SERVER_URL: $URL"
fi

# Cek tools
sec "Cek Tools"
command -v screen &>/dev/null && ok "screen: tersedia" || { warn "Menginstall screen..."; sudo apt install -y screen; }
command -v cloudflared &>/dev/null && ok "cloudflared: tersedia" || warn "cloudflared belum ada (opsional)"

# Validasi syntax Python
sec "Validasi Kode Python"
python3 -m py_compile app.py      && ok "app.py: OK"      || err "app.py: SYNTAX ERROR"
python3 -m py_compile generate.py && ok "generate.py: OK" || err "generate.py: SYNTAX ERROR"

# Summary
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║           Setup Selesai!              ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Langkah selanjutnya:"
echo "  1. Edit .env → isi BOT_TOKEN, CHAT_ID_GROUP, SERVER_URL"
echo "  2. Copy 4 template DOCX ke templates/ jika belum ada"
echo "  3. Setup HTTPS (lihat DEPLOY_GUIDE.md)"
echo "  4. Jalankan:"
echo "       screen -S pmbot"
echo "       gunicorn --workers 4 --bind 0.0.0.0:5000 app:app"
echo "       Ctrl+A, D untuk detach"
echo "  5. Test: curl http://localhost:5000/health"
echo ""
