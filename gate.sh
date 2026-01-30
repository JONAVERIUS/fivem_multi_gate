<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FiveM Nginx Proxy - Panduan Lengkap</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link
        href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap"
        rel="stylesheet">
    <style>
        :root {
            --primary: #6366f1;
            --primary-glow: rgba(99, 102, 241, 0.4);
            --secondary: #a855f7;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.7);
            --text: #f8fafc;
            --text-dim: #94a3b8;
            --border: rgba(255, 255, 255, 0.1);
            --success: #10b981;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Plus Jakarta Sans', sans-serif;
        }

        body {
            background-color: var(--bg);
            background-image:
                radial-gradient(circle at 10% 20%, rgba(99, 102, 241, 0.1) 0%, transparent 40%),
                radial-gradient(circle at 90% 80%, rgba(168, 85, 247, 0.1) 0%, transparent 40%);
            color: var(--text);
            line-height: 1.6;
            overflow-x: hidden;
        }

        .container {
            max-width: 1000px;
            margin: 0 auto;
            padding: 40px 20px;
        }

        header {
            text-align: center;
            margin-bottom: 80px;
            animation: fadeIn 1s ease-out;
        }

        h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 3.5rem;
            font-weight: 800;
            background: linear-gradient(135deg, #fff 0%, #a855f7 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 1rem;
            letter-spacing: -1px;
        }

        .subtitle {
            color: var(--text-dim);
            font-size: 1.2rem;
            max-width: 600px;
            margin: 0 auto;
        }

        .section {
            background: var(--card-bg);
            backdrop-filter: blur(12px);
            border: 1px border var(--border);
            border-radius: 24px;
            padding: 40px;
            margin-bottom: 40px;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
            transition: transform 0.3s ease;
        }

        .section:hover {
            transform: translateY(-5px);
        }

        h2 {
            font-family: 'Outfit', sans-serif;
            font-size: 1.8rem;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 12px;
        }

        h2::before {
            content: '';
            width: 4px;
            height: 24px;
            background: var(--primary);
            border-radius: 2px;
            box-shadow: 0 0 15px var(--primary-glow);
        }

        .code-block {
            background: #000;
            padding: 20px;
            border-radius: 12px;
            position: relative;
            margin: 20px 0;
            border: 1px solid rgba(255, 255, 255, 0.05);
            font-family: 'Fira Code', monospace;
            overflow-x: auto;
        }

        code {
            color: var(--success);
            font-size: 0.95rem;
        }

        .copy-btn {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(255, 255, 255, 0.1);
            border: none;
            color: #fff;
            padding: 5px 10px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.8rem;
            transition: all 0.2s;
        }

        .copy-btn:hover {
            background: var(--primary);
        }

        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }

        .feature-card {
            background: rgba(255, 255, 255, 0.03);
            padding: 24px;
            border-radius: 16px;
            border: 1px solid var(--border);
        }

        .feature-card h3 {
            font-size: 1.1rem;
            margin-bottom: 10px;
            color: var(--primary);
        }

        .menu-list {
            list-style: none;
        }

        .menu-list li {
            padding: 12px 0;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .menu-num {
            background: var(--primary);
            width: 28px;
            height: 28px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            font-size: 0.85rem;
            flex-shrink: 0;
        }

        .footer {
            text-align: center;
            padding: 40px;
            color: var(--text-dim);
            font-size: 0.9rem;
        }

        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }

            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @media (max-width: 768px) {
            h1 {
                font-size: 2.5rem;
            }

            .section {
                padding: 25px;
            }
        }
    </style>
</head>

<body>

    <div class="container">
        <header>
            <h1>FiveM Proxy Solution</h1>
            <p class="subtitle">Kelola akses server FiveM Anda dengan aman, cepat, dan profesional menggunakan Nginx
                Proxy Gateway.</p>
        </header>

        <div class="section">
            <h2>Instalasi Cepat</h2>
            <p>Gunakan satu baris perintah di bawah ini untuk mengunduh dan menjalankan skrip instalasi secara otomatis.
            </p>
            <div class="code-block" id="installCmd">
                <code>curl -fsSL https://raw.githubusercontent.com/JONAVERIUS/fivem_multi_gate/refs/heads/main/gate.sh | tr -d '\r' > gate.sh && sudo bash gate.sh</code>
                <button class="copy-btn" onclick="copyCode()">Copy</button>
            </div>
        </div>

        <div class="section">
            <h2>Fitur Utama</h2>
            <div class="features-grid">
                <div class="feature-card">
                    <h3>Multi-Server Target</h3>
                    <p>Mendukung lebih dari satu IP target. Trafik akan dibagikan secara otomatis melalui Nginx
                        Upstream.</p>
                </div>
                <div class="feature-card">
                    <h3>Manajemen Target</h3>
                    <p>Dilengkapi menu interaktif untuk Menambah, Mengedit, dan Menghapus target server kapan saja.</p>
                </div>
                <div class="feature-card">
                    <h3>Data Persisten</h3>
                    <p>Skrip menyimpan daftar target Anda secara otomatis. Tidak perlu input ulang setelah restart.</p>
                </div>
                <div class="feature-card">
                    <h3>Keamanan Layer 4/7</h3>
                    <p>Protokol TCP/UDP dioptimalkan untuk performa FiveM yang rendah latensi.</p>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>Panduan Menu</h2>
            <p style="margin-bottom: 20px;">Jalankan kembali skrip dengan <code>sudo bash gatefivem.sh</code> untuk
                melihat menu manajemen:</p>
            <ul class="menu-list">
                <li>
                    <div class="menu-num">1</div>
                    <div><strong>Instalasi Lengkap</strong> - Setup awal Nginx, Firewall, dan konfigurasi proxy dasar.
                    </div>
                </li>
                <li>
                    <div class="menu-num">2</div>
                    <div><strong>Kelola Target Server</strong> - Masuk ke sub-menu manajemen (Lihat, Tambah, Hapus,
                        Edit).</div>
                </li>
                <li>
                    <div class="menu-num">0</div>
                    <div><strong>Keluar</strong> - Menutup skrip dengan aman.</div>
                </li>
            </ul>
        </div>

        <div class="section">
            <h2>Lokasi File Penting</h2>
            <div class="features-grid">
                <div class="feature-card">
                    <h3>Konfigurasi</h3>
                    <p style="font-family: monospace; font-size: 0.85rem; margin-top: 5px;">
                        /etc/nginx/nginx.conf<br>/etc/nginx/stream.conf</p>
                </div>
                <div class="feature-card">
                    <h3>Data Target</h3>
                    <p style="font-family: monospace; font-size: 0.85rem; margin-top: 5px;">/etc/nginx/gate_targets.list
                    </p>
                </div>
            </div>
        </div>

        <div class="footer">
            &copy; 2026 FiveM Proxy Gateway Solution. All rights reserved.
        </div>
    </div>

    <script>
        function copyCode() {
            const code = document.querySelector('#installCmd code').innerText;
            navigator.clipboard.writeText(code).then(() => {
                const btn = document.querySelector('.copy-btn');
                btn.innerText = 'Copied!';
                setTimeout(() => btn.innerText = 'Copy', 2000);
            });
        }
    </script>

</body>

</html>
