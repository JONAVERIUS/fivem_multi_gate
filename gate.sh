#!/bin/bash

# ==============================================================================
# SKRIP FINAL - INSTALASI PROXY NGINX UNTUK FIVEM DI UBUNTU 20.04 (PORT MAPPING)
# ==============================================================================

TARGETS_FILE="/etc/nginx/gate_targets.list"

# -- FUNGSI UTAMA (MENCETAK PESAN) --
print_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
print_success() { echo -e "\e[32m[SUKSES]\e[0m $1"; }
print_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
print_fatal() { echo -e "\e[31m[FATAL]\e[0m $1"; exit 1; }

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
    print_info "Mengkonfigurasi firewall dasar (SSH, HTTP, HTTPS)..."
    ufw allow 22/tcp >/dev/null 2>&1
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    print_success "Firewall dasar selesai."
}

cleanup_old_configs() {
    print_info "Membersihkan konfigurasi default Nginx..."
    [ -d "/etc/nginx" ] || mkdir -p /etc/nginx
    rm -f /etc/nginx/conf.d/default.conf
    mkdir -p /etc/nginx/ssl
}

# -- FUNGSI KONFIGURASI NGINX --

configure_nginx() {
    local entries=("$@")
    
    [ -d "/etc/nginx" ] || mkdir -p /etc/nginx

    print_info "Menghasilkan konfigurasi Nginx..."
    
    # 1. Generate main nginx.conf (HTTP part load balances everything to the first group or stays generic)
    # FiveM usually uses the same port for web and game. Here we focus on Stream Proxying.
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
}

include /etc/nginx/stream.conf;
EOF

    # 2. Generate stream.conf (Complex Port Mapping)
    echo "stream {" > /etc/nginx/stream.conf
    
    # Extract unique gate ports
    local gate_ports=()
    for entry in "${entries[@]}"; do
        port=$(echo "$entry" | cut -d':' -f1)
        if [[ ! " ${gate_ports[@]} " =~ " ${port} " ]]; then
            gate_ports+=("$port")
        fi
    done

    for port in "${gate_ports[@]}"; do
        print_info "Konfigurasi Port Gateway: $port..."
        
        # Open port in firewall
        ufw allow "$port/tcp" >/dev/null 2>&1
        ufw allow "$port/udp" >/dev/null 2>&1

        echo "    upstream backend_$port {" >> /etc/nginx/stream.conf
        for entry in "${entries[@]}"; do
            target_port=$(echo "$entry" | cut -d':' -f1)
            target_ip=$(echo "$entry" | cut -d':' -f2)
            target_backend_port=$(echo "$entry" | cut -d':' -f3)
            
            if [ "$target_port" == "$port" ]; then
                echo "        server $target_ip:$target_backend_port;" >> /etc/nginx/stream.conf
            fi
        done
        echo "    }" >> /etc/nginx/stream.conf
        
        echo "    server {" >> /etc/nginx/stream.conf
        echo "        listen $port;" >> /etc/nginx/stream.conf
        echo "        proxy_pass backend_$port;" >> /etc/nginx/stream.conf
        echo "    }" >> /etc/nginx/stream.conf
        
        echo "    server {" >> /etc/nginx/stream.conf
        echo "        listen $port udp reuseport;" >> /etc/nginx/stream.conf
        echo "        proxy_pass backend_$port;" >> /etc/nginx/stream.conf
        echo "    }" >> /etc/nginx/stream.conf
    done
    
    echo "}" >> /etc/nginx/stream.conf

    print_info "Memeriksa konfigurasi Nginx..."
    if ! nginx -t >/dev/null 2>&1; then
        print_error "Konfigurasi Nginx tidak valid!"
        return 1
    fi

    print_info "Memulai ulang Nginx..."
    if systemctl restart nginx; then
        print_success "Nginx Refreshed! Gateway Port aktif: ${gate_ports[*]}"
    else
        print_error "Gagal merefresh Nginx."
        return 1
    fi
}

# -- MANAJEMEN TARGET --

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
    echo -e "\n--- Daftar Pemetaan Port ---"
    if [ ${#targets[@]} -eq 0 ]; then
        echo "   (Kosong)"
    else
        printf "   %-5s | %-12s | %-20s\n" "No" "Gate Port" "Target Backend"
        echo "   --------------------------------------------"
        for i in "${!targets[@]}"; do
            gp=$(echo "${targets[$i]}" | cut -d':' -f1)
            tip=$(echo "${targets[$i]}" | cut -d':' -f2)
            tp=$(echo "${targets[$i]}" | cut -d':' -f3)
            printf "   [%-3d] | %-12s | %-20s\n" "$((i+1))" "$gp" "$tip:$tp"
        done
    fi
    echo ""
}

add_target() {
    echo ""
    print_info "Tambah Pemetaan Port Baru"
    read -p "    Port Gateway (VPS ini, misal: 30120): " gport
    read -p "    IP Target Backend: " tip
    read -p "    Port Target Backend (default 30120): " tport
    tport=${tport:-30120}

    if [[ -n "$gport" && -n "$tip" ]]; then
        targets+=("$gport:$tip:$tport")
        save_targets
        print_success "Pemetaan ditambahkan: $gport -> $tip:$tport"
    else
        print_error "Input Port Gateway dan IP Target tidak boleh kosong."
    fi
}

delete_target() {
    list_targets
    if [ ${#targets[@]} -eq 0 ]; then return; fi
    
    read -p "    Masukkan nomor yang ingin dihapus (0=batal): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#targets[@]} ]; then
        idx=$((choice-1))
        removed=${targets[$idx]}
        unset 'targets[idx]'
        targets=("${targets[@]}")
        save_targets
        print_success "Pemetaan $removed dihapus."
    fi
}

# -- EXECUTION --

if [ "$(id -u)" != "0" ]; then print_fatal "Harus root!"; fi
[ -d "/etc/nginx" ] || mkdir -p /etc/nginx
load_targets

while true; do
    echo -e "\n=== FIVEM GATEWAY - PORT MAPPING ===\n1. Instalasi Nginx\n2. Lihat Pemetaan\n3. Tambah Pemetaan\n4. Hapus Pemetaan\n0. Keluar"
    read -p "Pilihan: " mc
    case $mc in
        1) install_nginx; setup_firewall; cleanup_old_configs ;;
        2) list_targets ;;
        3) load_targets; add_target ;;
        4) load_targets; delete_target ;;
        0) exit 0 ;;
        *) print_error "Pilihan tidak valid." ;;
    esac
done
