ARG N8N_IMAGE=n8nio/n8n:latest

FROM python:3.13-alpine AS python-builder

RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    libffi

RUN python -m venv /opt/n8n-python && \
    /opt/n8n-python/bin/pip install --upgrade pip && \
    /opt/n8n-python/bin/pip install pandas numpy plotly anthropic requests playwright

FROM ${N8N_IMAGE}

USER root

COPY --from=python-builder /opt/n8n-python /opt/n8n-python
COPY --from=python-builder /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=python-builder /usr/local/lib/libpython3.13.so.1.0 /usr/local/lib/libpython3.13.so.1.0
COPY --from=python-builder /usr/local/lib/python3.13 /usr/local/lib/python3.13
COPY --from=python-builder /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=python-builder /usr/lib/libffi.so.8 /usr/lib/libffi.so.8
COPY --from=python-builder /usr/bin/chromium-browser /usr/bin/chromium-browser
COPY --from=python-builder /usr/lib/chromium /usr/lib/chromium
COPY --from=python-builder /etc/ssl/certs /etc/ssl/certs
COPY --from=python-builder /usr/share/fonts /usr/share/fonts

RUN mkdir -p /usr/local/lib/python3.13/site-packages && \
    cp -a /opt/n8n-python/lib/python3.13/site-packages/. /usr/local/lib/python3.13/site-packages/ && \
    ln -sf /usr/local/bin/python3.13 /usr/local/bin/python && \
    ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3 && \
    ln -sf /opt/n8n-python/bin/pip /usr/local/bin/pip && \
    ln -sf /opt/n8n-python/bin/pip /usr/local/bin/pip3

ENV PLAYWRIGHT_BROWSERS_PATH=/usr/lib/chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROMIUM_BIN=/usr/bin/chromium-browser
ENV PYTHONUNBUFFERED=1

USER node
