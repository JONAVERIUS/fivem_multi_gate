#!/bin/bash

# ==============================================================================
# SKRIP FINAL - INSTALASI PROXY NGINX UNTUK FIVEM DI UBUNTU 20.04 (MULTI-SERVER)
# ==============================================================================

# -- KONFIGURASI --
TARGETS_FILE="/etc/nginx/gate_targets.list"

# -- FUNGSI UTAMA (MENCETAK PESAN) --
print_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[32m[SUKSES]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    # Jangan langsung exit di sini agar loop menu tidak berhenti kecuali error fatal
}

print_fatal() {
    echo -e "\e[31m[FATAL]\e[0m $1"
    exit 1
}

# -- FUNGSI PENDUKUNG (SISTEM) --

install_nginx() {
    print_info "Memulai instalasi Nginx..."
    apt-get update >/dev/null 2>&1
    apt-get install -y gnupg2 lsb-release software-properties-common wget curl >/dev/null 2>&1
    
    OS_CODENAME=$(lsb_release -cs)
    curl -fsSL http://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ $OS_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null

    apt-get update >/dev/null 2>&1
    apt-get install -y nginx >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    systemctl start nginx
    print_success "Instalasi Nginx selesai."
}

setup_firewall() {
    print_info "Mengkonfigurasi firewall UFW..."
    ufw allow 22/tcp >/dev/null 2>&1
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    ufw allow 30120/tcp >/dev/null 2>&1
    ufw allow 30120/udp >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    print_success "Firewall selesai."
}

cleanup_old_configs() {
    print_info "Membersihkan konfigurasi default Nginx..."
    [ -d "/etc/nginx" ] || mkdir -p /etc/nginx
    rm -f /etc/nginx/conf.d/default.conf
    mkdir -p /etc/nginx/ssl
}

# -- FUNGSI KONFIGURASI NGINX --

configure_nginx() {
    local servers=("$@")
    
    [ -d "/etc/nginx" ] || mkdir -p /etc/nginx

    if [ ${#servers[@]} -eq 0 ]; then
        print_info "Peringatan: Tidak ada target server terdaftar."
    fi

    print_info "Menghasilkan konfigurasi Nginx..."
    
    # Generate main nginx.conf
    cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes  auto;
worker_rlimit_nofile 65535;
error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  65535;
    multi_accept on;
}

http {
    upstream backend {
$(for s in "${servers[@]}"; do echo "        server $s;"; done)
    }

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    ssl_protocols TLSv1.2;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    keepalive_timeout 65;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    include /etc/nginx/web.conf;
}

include /etc/nginx/stream.conf;
EOF

    # Generate stream.conf
    cat <<EOF > /etc/nginx/stream.conf
stream {
    upstream backend_stream {
$(for s in "${servers[@]}"; do echo "        server $s;"; done)
    }
    server {
        listen 30120;
        proxy_pass backend_stream;
    }
    server {
        listen 30120 udp reuseport;
        proxy_pass backend_stream;
    }
}
EOF

    # Generate web.conf
    SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
    cat <<EOF > /etc/nginx/web.conf
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    print_info "Memeriksa konfigurasi Nginx..."
    if ! nginx -t >/dev/null 2>&1; then
        print_error "Konfigurasi Nginx tidak valid! Jalankan 'nginx -t' di terminal untuk melihat detail error."
        return 1
    fi

    print_info "Memulai ulang Nginx..."
    if systemctl restart nginx; then
        print_success "Nginx berhasil direfresh dengan konfigurasi baru."
    else
        print_error "Gagal merefresh Nginx. Periksa systemd logs."
        return 1
    fi
}

# -- FUNGSI MANAJEMEN TARGET --

load_targets() {
    if [ -f "$TARGETS_FILE" ]; then
        mapfile -t targets < "$TARGETS_FILE"
    else
        targets=()
    fi
}

save_targets() {
    [ -d "/etc/nginx" ] || mkdir -p /etc/nginx
    printf "%s\n" "${targets[@]}" > "$TARGETS_FILE"
    configure_nginx "${targets[@]}"
}

list_targets() {
    load_targets
    echo ""
    print_info "Daftar Target Server Saat Ini:"
    if [ ${#targets[@]} -eq 0 ]; then
        echo "   (Kosong)"
    else
        for i in "${!targets[@]}"; do
            echo "   [$((i+1))] ${targets[$i]}"
        done
    fi
    echo ""
}

add_target() {
    echo ""
    print_info "Tambah Target Server Baru"
    read -p "    Masukkan IP:Port (Contoh: 1.1.1.1:30120): " new_target
    if [ -n "$new_target" ]; then
        targets+=("$new_target")
        save_targets
    else
        print_error "Input tidak boleh kosong."
    fi
}

delete_target() {
    list_targets
    if [ ${#targets[@]} -eq 0 ]; then return; fi
    
    read -p "    Masukkan nomor target yang ingin dihapus (atau 0 untuk batal): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#targets[@]} ]; then
        idx=$((choice-1))
        removed_target=${targets[$idx]}
        unset 'targets[idx]'
        targets=("${targets[@]}") # Re-index
        save_targets
        print_success "Target $removed_target telah dihapus."
    elif [ "$choice" == "0" ]; then
        print_info "Batal menghapus."
    else
        print_error "Pilihan tidak valid."
    fi
}

edit_target() {
    list_targets
    if [ ${#targets[@]} -eq 0 ]; then return; fi

    read -p "    Masukkan nomor target yang ingin diganti (atau 0 untuk batal): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#targets[@]} ]; then
        idx=$((choice-1))
        old_target=${targets[$idx]}
        read -p "    Masukkan IP:Port baru untuk [$choice] (Target sekarang: $old_target): " new_val
        if [ -n "$new_val" ]; then
            targets[$idx]="$new_val"
            save_targets
            print_success "Target [$choice] diperbarui."
        else
            print_error "Input tidak boleh kosong."
        fi
    elif [ "$choice" == "0" ]; then
        print_info "Batal mengedit."
    else
        print_error "Pilihan tidak valid."
    fi
}

manage_targets_menu() {
    while true; do
        echo ""
        print_info "=== KELOLA TARGET SERVER ==="
        echo "1. Lihat Daftar Target"
        echo "2. Tambah Target Baru"
        echo "3. Edit/Ganti Target"
        echo "4. Hapus Target"
        echo "0. Kembali ke Menu Utama"
        echo ""
        read -p "Masukkan pilihan: " subchoice
        
        case $subchoice in
            1) list_targets ;;
            2) load_targets; add_target ;;
            3) load_targets; edit_target ;;
            4) load_targets; delete_target ;;
            0) break ;;
            *) print_error "Pilihan tidak valid." ;;
        esac
    done
}

# -- EKSEKUSI AWAL --

# 1. Root check
if [ "$(id -u)" != "0" ]; then
   print_fatal "Skrip ini harus dijalankan sebagai root (gunakan sudo)."
fi

# 2. Persiapan Direktori
[ -d "/etc/nginx" ] || mkdir -p /etc/nginx

# 3. Load Targets
load_targets

# -- MENU UTAMA --

while true; do
    echo ""
    print_info "=== NGINX PROXY UNTUK FIVEM (MANAGEMENT) ==="
    echo "1. Instalasi Lengkap (Nginx + Proxy)"
    echo "2. Kelola Target Server (View, Add, Delete, Edit)"
    echo "0. Keluar"
    echo ""
    read -p "Pilihan Anda: " mainchoice

    case $mainchoice in
        1)
            print_info "Mode: Instalasi Lengkap"
            install_nginx
            setup_firewall
            cleanup_old_configs
            print_info "Silakan tambahkan target pertama Anda:"
            add_target
            ;;
        2)
            manage_targets_menu
            ;;
        0)
            print_info "Keluar dari skrip."
            exit 0
            ;;
        *)
            print_error "Pilihan tidak valid."
            ;;
    esac
done
