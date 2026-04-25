FROM python:3.12-slim-bookworm

WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV FLARESOLVERR_URL=http://localhost:8191
ENV BYPARR_URL=http://localhost:8192
ENV BYPARR_PORT=8192
ENV PORT=7860
ENV PROXY=socks5h://127.0.0.1:1080

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ffmpeg chromium libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 \
    libcairo2 libatspi2.0-0 libxshmfence1 libglu1-mesa \
    ca-certificates fonts-liberation chromium-driver \
    gnupg lsb-release \
    && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update && apt-get install -y cloudflare-warp \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_EXE_PATH=/usr/bin/chromium
ENV CHROME_BIN=/usr/bin/chromium
ENV CHROME_DRIVER_PATH=/usr/bin/chromedriver

RUN git clone https://github.com/FlareSolverr/FlareSolverr.git /app/flaresolverr \
    && cd /app/flaresolverr \
    && pip install --no-cache-dir -r requirements.txt

RUN git clone https://github.com/ThePhaseless/Byparr.git /app/byparr_src \
    && cd /app/byparr_src \
    && sed -i 's/requires-python = .*/requires-python = ">=3.11"/' pyproject.toml \
    && pip install --no-cache-dir .
RUN python -m camoufox fetch

RUN git clone https://github.com/realbestia1/EasyProxy.git /app/easyproxy \
    && cd /app/easyproxy \
    && pip install --no-cache-dir -r requirements.txt \
    && python -m playwright install chromium

RUN echo '#!/bin/bash' > /app/entrypoint.sh \
    && echo 'echo "===== Starting $(date) ====="' >> /app/entrypoint.sh \
    && echo 'warp-svc &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos registration new 2>/dev/null || true' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos connect' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos mode proxy' >> /app/entrypoint.sh \
    && echo 'warp-cli --accept-tos proxy port 1080' >> /app/entrypoint.sh \
    && echo 'sleep 5' >> /app/entrypoint.sh \
    && echo 'warp-cli status 2>/dev/null || true' >> /app/entrypoint.sh \
    && echo 'export PROXY=socks5h://127.0.0.1:1080' >> /app/entrypoint.sh \
    && echo 'cd /app/flaresolverr && nohup python src/app.py > /tmp/flr.log 2>&1 &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'cd /app/byparr_src && nohup python -m byparr > /tmp/byp.log 2>&1 &' >> /app/entrypoint.sh \
    && echo 'sleep 3' >> /app/entrypoint.sh \
    && echo 'echo "[✓] Starting EasyProxy on :7860"' >> /app/entrypoint.sh \
    && echo 'cd /app/easyproxy && exec python app.py' >> /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

EXPOSE 7860
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
