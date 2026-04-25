# ============================================
# EasyProxy + FlareSolverr + Byparr + WARP
# Per Render.com
# ============================================

FROM python:3.12-slim-bookworm

# 1. Environment Settings
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV FLARESOLVERR_URL=http://localhost:8191
ENV BYPARR_URL=http://localhost:8192
ENV BYPARR_PORT=8192
ENV PORT=7860
ENV PROXY=socks5h://127.0.0.1:1080
ENV PYTHONPATH=/app
ENV CHROME_EXE_PATH=/usr/bin/chromium
ENV CHROME_BIN=/usr/bin/chromium
ENV CHROME_DRIVER_PATH=/usr/bin/chromedriver

# 2. System Dependencies + WARP
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ffmpeg \
    chromium \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    libxshmfence1 \
    libglu1-mesa \
    ca-certificates \
    fonts-liberation \
    chromium-driver \
    gnupg \
    lsb-release \
    net-tools \
    && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get install -y cloudflare-warp \
    && rm -rf /var/lib/apt/lists/*

# 3. FlareSolverr v3
RUN git clone https://github.com/FlareSolverr/FlareSolverr.git /app/flaresolverr \
    && cd /app/flaresolverr \
    && sed -i 's/driver_executable_path=driver_exe_path/driver_executable_path="\/usr\/bin\/chromedriver"/' src/utils.py \
    && sed -i "s|options.add_argument('--no-sandbox')|options.add_argument('--no-sandbox'); options.add_argument('--disable-dev-shm-usage'); options.add_argument('--disable-gpu'); options.add_argument('--headless=new')|" src/utils.py \
    && sed -i "s|^\([[:space:]]*\)start_xvfb_display()|\1pass|g" src/utils.py \
    && pip install --no-cache-dir -r requirements.txt

# 4. Byparr
RUN git clone https://github.com/ThePhaseless/Byparr.git /app/byparr_src \
    && cd /app/byparr_src \
    && sed -i 's/requires-python = .*/requires-python = ">=3.11"/' pyproject.toml \
    && pip install --no-cache-dir .
RUN python -m camoufox fetch

# 5. EasyProxy
RUN git clone https://github.com/realbestia1/EasyProxy.git /app/easyproxy \
    && cd /app/easyproxy \
    && pip install --no-cache-dir -r requirements.txt \
    && python -m playwright install chromium

# 6. Entrypoint Script (avvia tutto)
RUN echo '#!/bin/bash' > /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo 'echo "=========================================="' >> /app/entrypoint.sh \
    && echo 'echo "  EasyProxy + WARP + FlareSolverr + Byparr"' >> /app/entrypoint.sh \
    && echo 'echo "  Starting at $(date)"' >> /app/entrypoint.sh \
    && echo 'echo "=========================================="' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# ---------- WARP ----------' >> /app/entrypoint.sh \
    && echo 'echo "[*] Starting Cloudflare WARP..."' >> /app/entrypoint.sh \
    && echo 'warp-svc &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos registration new 2>/dev/null || echo "WARP: already registered"' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos connect 2>/dev/null || echo "WARP: connection failed (will continue without it)"' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos mode proxy 2>/dev/null || true' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos proxy port 1080 2>/dev/null || true' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'if netstat -tlnp 2>/dev/null | grep -q 1080; then' >> /app/entrypoint.sh \
    && echo '    echo "[✓] WARP SOCKS5 proxy: 127.0.0.1:1080"' >> /app/entrypoint.sh \
    && echo 'else' >> /app/entrypoint.sh \
    && echo '    echo "[!] WARP not running (proxy will work without it)"' >> /app/entrypoint.sh \
    && echo 'fi' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# ---------- FlareSolverr ----------' >> /app/entrypoint.sh \
    && echo 'echo "[*] Starting FlareSolverr..."' >> /app/entrypoint.sh \
    && echo 'cd /app/flaresolverr && nohup python src/app.py > /tmp/flaresolverr.log 2>&1 &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'echo "[✓] FlareSolverr: http://localhost:8191"' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# ---------- Byparr ----------' >> /app/entrypoint.sh \
    && echo 'echo "[*] Starting Byparr..."' >> /app/entrypoint.sh \
    && echo 'cd /app/byparr_src && nohup python -m byparr > /tmp/byparr.log 2>&1 &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'echo "[✓] Byparr: http://localhost:8192"' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# ---------- EasyProxy ----------' >> /app/entrypoint.sh \
    && echo 'echo "=========================================="' >> /app/entrypoint.sh \
    && echo 'echo "[✓] All services started"' >> /app/entrypoint.sh \
    && echo 'echo "[*] EasyProxy: http://0.0.0.0:${PORT:-7860}"' >> /app/entrypoint.sh \
    && echo 'echo "=========================================="' >> /app/entrypoint.sh \
    && echo 'cd /app/easyproxy && exec python app.py' >> /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

# 7. Porte
EXPOSE 7860 8191 8192 1080

# 8. Avvio
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
