#!/bin/bash
# =======================================================
#   ZeroNokos — Auto Installer
#   Developed by NEXUSDEV
#   https://github.com/kiryusekei/ZeroNokos
# =======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://github.com/kiryusekei/ZeroNokos"
BOT_DIR="/root/ZeroNokos"
BOT_NAME="ZeroNokos"

clear
echo -e "${CYAN}"
cat << 'EOF'
 ███████╗███████╗██████╗  ██████╗ ███╗   ██╗ ██████╗ ██╗  ██╗ ██████╗ ███████╗
 ╚══███╔╝██╔════╝██╔══██╗██╔═══██╗████╗  ██║██╔═══██╗██║ ██╔╝██╔═══██╗██╔════╝
   ███╔╝ █████╗  ██████╔╝██║   ██║██╔██╗ ██║██║   ██║█████╔╝ ██║   ██║███████╗
  ███╔╝  ██╔══╝  ██╔══██╗██║   ██║██║╚██╗██║██║   ██║██╔═██╗ ██║   ██║╚════██║
 ███████╗███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╔╝██║  ██╗╚██████╔╝███████║
 ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
EOF
echo -e "${NC}"
echo -e "${BOLD}${BLUE}         Bot Telegram OTP & Sesi — by NEXUSDEV${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── Deteksi OS ────────────────────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        OS="unknown"
    fi
}

detect_os

echo -e "${YELLOW}[INFO] OS Terdeteksi: ${OS} ${OS_VER}${NC}"
echo ""

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Jalankan script ini sebagai root!${NC}"
    echo -e "Gunakan: ${BOLD}sudo bash install.sh${NC}"
    exit 1
fi

# ── Fungsi log ────────────────────────────────────────────────────────────────
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_info() { echo -e "${CYAN}[i]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[✗]${NC} $1"; }

# ── Update sistem ─────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[1/6] Update sistem...${NC}"
apt-get update -qq 2>/dev/null || yum update -y -q 2>/dev/null
log_ok "Sistem diperbarui"

# ── Install dependencies ───────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[2/6] Install dependencies sistem...${NC}"

PKGS="curl wget git zip unzip"
for pkg in $PKGS; do
    if ! command -v $pkg &>/dev/null; then
        log_info "Installing $pkg..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y -q $pkg 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y -q $pkg 2>/dev/null
        fi
    fi
done
log_ok "Dependencies sistem tersedia"

# ── Install Node.js ────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[3/6] Cek / Install Node.js...${NC}"

REQUIRED_NODE=18

install_nodejs() {
    log_info "Menginstall Node.js v${REQUIRED_NODE}..."
    if command -v curl &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE}.x | bash - 2>/dev/null
        apt-get install -y nodejs 2>/dev/null
    elif command -v wget &>/dev/null; then
        wget -qO- https://deb.nodesource.com/setup_${REQUIRED_NODE}.x | bash - 2>/dev/null
        apt-get install -y nodejs 2>/dev/null
    fi
}

if command -v node &>/dev/null; then
    CURRENT_NODE=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$CURRENT_NODE" -lt "$REQUIRED_NODE" ]; then
        log_warn "Node.js v${CURRENT_NODE} terlalu lama, mengupgrade ke v${REQUIRED_NODE}..."
        install_nodejs
    else
        log_ok "Node.js sudah tersedia: $(node -v)"
    fi
else
    install_nodejs
fi

if ! command -v node &>/dev/null; then
    log_err "Gagal install Node.js. Install manual: https://nodejs.org"
    exit 1
fi
log_ok "Node.js: $(node -v) | npm: $(npm -v)"

# ── Install PM2 ────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[4/6] Cek / Install PM2...${NC}"
if ! command -v pm2 &>/dev/null; then
    log_info "Installing PM2..."
    npm install -g pm2 -q 2>/dev/null
fi
log_ok "PM2: $(pm2 -v)"

# ── Clone / Update repo ────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[5/6] Download ZeroNokos dari GitHub...${NC}"

if [ -d "$BOT_DIR/.git" ]; then
    log_info "Folder sudah ada, melakukan git pull..."
    cd "$BOT_DIR"
    # Simpan settings.js dan database sebelum pull
    [ -f settings.js ]         && cp settings.js /tmp/zeronokos_settings.bak
    [ -d database ]            && cp -r database /tmp/zeronokos_db.bak 2>/dev/null
    [ -f backupStats.json ]    && cp backupStats.json /tmp/zeronokos_bkstats.bak
    [ -f lastBackup.json ]     && cp lastBackup.json /tmp/zeronokos_lastbk.bak

    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null

    # Restore file config & data
    [ -f /tmp/zeronokos_settings.bak ] && cp /tmp/zeronokos_settings.bak settings.js && log_ok "settings.js dikembalikan"
    [ -d /tmp/zeronokos_db.bak ]       && cp -r /tmp/zeronokos_db.bak database 2>/dev/null
    [ -f /tmp/zeronokos_bkstats.bak ]  && cp /tmp/zeronokos_bkstats.bak backupStats.json
    [ -f /tmp/zeronokos_lastbk.bak ]   && cp /tmp/zeronokos_lastbk.bak lastBackup.json

    log_ok "Repo berhasil diperbarui"
else
    if [ -d "$BOT_DIR" ]; then
        log_warn "Folder $BOT_DIR ada tapi bukan git repo, menghapus..."
        rm -rf "$BOT_DIR"
    fi
    log_info "Cloning dari ${REPO_URL}..."
    git clone "$REPO_URL" "$BOT_DIR" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_err "Gagal clone repo. Cek koneksi internet atau URL repo."
        exit 1
    fi
    log_ok "Repo berhasil di-clone ke $BOT_DIR"
fi

# ── Install npm packages ────────────────────────────────────────────────────────
cd "$BOT_DIR"
log_info "Installing npm packages..."
npm install --silent 2>/dev/null
if [ $? -ne 0 ]; then
    log_warn "npm install gagal, mencoba ulang..."
    npm install 2>&1 | tail -5
fi
log_ok "npm packages terinstall"

# ── Setup settings.js ─────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}[6/6] Konfigurasi Bot...${NC}"

if [ ! -f "$BOT_DIR/settings.js" ]; then
    log_warn "settings.js tidak ditemukan, membuat dari template..."
    cp "$BOT_DIR/settings.example.js" "$BOT_DIR/settings.js" 2>/dev/null || true
fi

if grep -q "your-project-slug\|tokenUser.*'-'" "$BOT_DIR/settings.js" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  settings.js BELUM DIKONFIGURASI!        ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Edit file konfigurasi dengan perintah:"
    echo -e "${BOLD}  nano ${BOT_DIR}/settings.js${NC}"
    echo ""
    echo -e "Isi minimal yang diperlukan:"
    echo -e "  ${CYAN}tokenUser${NC}       — Token Bot User (dari @BotFather)"
    echo -e "  ${CYAN}tokenAdmin${NC}      — Token Bot Admin (dari @BotFather)"
    echo -e "  ${CYAN}ownerId${NC}         — Telegram ID Owner"
    echo -e "  ${CYAN}rumahOtpApiKey${NC}  — API Key RumahOTP.io"
    echo -e "  ${CYAN}pakasirProject${NC}  — Slug Proyek Pakasir"
    echo -e "  ${CYAN}pakasirApiKey${NC}   — API Key Pakasir"
    echo ""
fi

# ── PM2 setup ────────────────────────────────────────────────────────────────
cd "$BOT_DIR"

# Stop proses lama jika ada
pm2 stop $BOT_NAME 2>/dev/null
pm2 delete $BOT_NAME 2>/dev/null

# Start bot
pm2 start index.js --name "$BOT_NAME" --restart-delay=5000 2>/dev/null
pm2 save 2>/dev/null

# Aktifkan PM2 startup otomatis
pm2 startup 2>/dev/null | tail -1 | bash 2>/dev/null || true

# ── Selesai ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ✅  ZeroNokos berhasil diinstall!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Lokasi Bot    :${NC} ${BOT_DIR}"
echo -e "  ${BOLD}Konfigurasi   :${NC} ${BOT_DIR}/settings.js"
echo -e "  ${BOLD}Status PM2    :${NC} pm2 status"
echo -e "  ${BOLD}Log Real-time :${NC} pm2 logs ${BOT_NAME}"
echo -e "  ${BOLD}Restart Bot   :${NC} pm2 restart ${BOT_NAME}"
echo -e "  ${BOLD}Stop Bot      :${NC} pm2 stop ${BOT_NAME}"
echo ""
echo -e "${CYAN}  ⚡ Developed by NEXUSDEV | github.com/kiryusekei/ZeroNokos${NC}"
echo ""
