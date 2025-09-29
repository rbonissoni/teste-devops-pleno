#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# ------ Variáveis vindas do Terraform ------
ENABLE_JENKINS="${ENABLE_JENKINS}"
REPO_URL="${REPO_URL}"
REPO_BRANCH="${REPO_BRANCH}"
DD_API_KEY="${DD_API_KEY}"
DD_SITE="${DD_SITE}"
DD_APP_KEY="${DD_APP_KEY}"

APP_ROOT="${APP_ROOT}"

# ------ Pacotes base ------
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release rsync nginx git unzip

# Node.js (LTS atual)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# ------ Jenkins (opcional) ------
if [ "${ENABLE_JENKINS}" = "true" ]; then
  apt-get install -y apt-transport-https software-properties-common
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  docker volume create jenkins-data
  docker run -d --name jenkins -p 8080:8080 -p 50000:50000 \
    -v jenkins-data:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock \
    jenkins/jenkins:lts
fi

# ------ Estrutura do app ------
mkdir -p "${APP_ROOT}"/{releases,current,shared}
chown -R www-data:www-data "${APP_ROOT}"
chmod -R 775 "${APP_ROOT}"

# Nginx - vhost
cat >/etc/nginx/sites-available/app.conf <<'NG'
server {
  listen 80;
  server_name _default_;

  access_log /var/log/nginx/app_access.log;
  error_log  /var/log/nginx/app_error.log;

  location /nginx_status {
    stub_status on;
    allow 127.0.0.1;
    deny all;
  }

  location /health {
    proxy_pass http://127.0.0.1:3000/health;
  }

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
  }
}
NG
ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx || systemctl restart nginx

# ------ Bootstrap do código ------
TMP=/tmp/bootstrap-repo
rm -rf "$TMP"
mkdir -p "$TMP"
if [ -n "${REPO_URL}" ]; then
  if git clone --depth 1 -b "${REPO_BRANCH}" "${REPO_URL}" "$TMP/repo"; then
    :
  else
    echo "WARN: clone do repo falhou. Usando fallback."
    mkdir -p "$TMP/repo/app"
  fi
else
  mkdir -p "$TMP/repo/app"
fi

# Caminho fonte esperado: preferimos $TMP/repo/app; se não existir, usamos $TMP/repo
SRC="$TMP/repo/app"
[ -d "$TMP/repo/app" ] || SRC="$TMP/repo"

# Publicar release
REL="bootstrap-$(date +%s)"
mkdir -p "${APP_ROOT}/releases/$REL"
rsync -a "$SRC/" "${APP_ROOT}/releases/$REL/" || true
ln -sfn "${APP_ROOT}/releases/$REL" "${APP_ROOT}/current"

# Se APÓS a publicação ainda não existir app.js, criamos um fallback mínimo DIRETO em current/
if [ ! -f "${APP_ROOT}/current/app.js" ]; then
  cat >"${APP_ROOT}/current/app.js" <<'JS'
const express=require('express');
const app=express();
const port=process.env.PORT||3000;
app.get('/', (req,res)=>res.send('OK - Home'));
app.get('/health', (req,res)=>res.json({status:'ok'}));
app.listen(port, ()=>console.log('App running on port', port));
JS
  cat >"${APP_ROOT}/current/package.json" <<'JSON'
{
  "name": "devops-pleno-app",
  "version": "1.0.0",
  "private": true,
  "scripts": {"start":"node app.js"},
  "dependencies": {"express":"^4.19.2"}
}
JSON
fi

chown -R www-data:www-data "${APP_ROOT}"

# Instala dependências do app (se houver package.json)
if [ -f "${APP_ROOT}/current/package.json" ]; then
  pushd "${APP_ROOT}/current" >/dev/null
  npm ci --omit=dev || npm install --omit=dev || true
  popd >/dev/null
fi

# ------ systemd do app ------
cat >/etc/systemd/system/app.service <<'SY'
[Unit]
Description=Node App Service
After=network.target

[Service]
Environment=PORT=3000
WorkingDirectory=/var/www/app/current
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=5
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
SY

systemctl daemon-reload
systemctl enable app
systemctl restart app

# ------ Datadog Agent ------
if ! command -v datadog-agent >/dev/null 2>&1; then
  DD_API_KEY="${DD_API_KEY}" DD_SITE="${DD_SITE}" \
    bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)" || true
fi
if ! command -v datadog-agent >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://keys.datadoghq.com/DATADOG_APT_KEY_CURRENT.public | gpg --dearmor -o /etc/apt/keyrings/datadog.gpg
  chmod a+r /etc/apt/keyrings/datadog.gpg
  echo "deb [signed-by=/etc/apt/keyrings/datadog.gpg] https://apt.datadoghq.com/ stable 7" > /etc/apt/sources.list.d/datadog.list
  apt-get update -y
  apt-get install -y datadog-agent
fi

mkdir -p /etc/datadog-agent
cat >/etc/datadog-agent/datadog.yaml <<YML
api_key: ${DD_API_KEY}
site: ${DD_SITE}
process_config:
  enabled: "true"
apm_config:
  enabled: false
YML

mkdir -p /etc/datadog-agent/nginx.d
cat >/etc/datadog-agent/nginx.d/conf.yaml <<'YML'
init_config:

instances:
  - nginx_status_url: http://127.0.0.1/nginx_status
    tags:
      - service:nginx

logs:
  - type: file
    path: /var/log/nginx/*.log
    service: nginx
    source: nginx
YML

systemctl enable datadog-agent
systemctl restart datadog-agent || true

# (Opcional) Criar monitor se app key fornecida
if [ -n "${DD_APP_KEY}" ]; then
  cat >/root/dd-monitor.json <<'MON'
{
  "name":"High 5xx on Nginx (example)",
  "type":"log alert",
  "query":"logs(\"service:nginx status:error\").index(\"*\").rollup(\"count\").by(\"host\").last(\"5m\") > 10",
  "message":"Aumento de erros no Nginx. @pagerduty @slack-ops",
  "tags":["env:prod","service:nginx"],
  "options":{"thresholds":{"critical":10},"notify_no_data":false,"no_data_timeframe":20}
}
MON
  curl -sS -X POST "https://api.${DD_SITE}/api/v1/monitor" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    -d @/root/dd-monitor.json || true
fi

# ------ Smoke checks (não quebram o boot) ------
for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:3000/health && break || true
  sleep 2
done
if ! curl -fsS http://127.0.0.1:3000/health >/dev/null; then
  echo "ERRO: app não respondeu em 60s (127.0.0.1:3000/health)"
  journalctl -u app -n 100 --no-pager || true
fi
curl -fsS http://127.0.0.1/nginx_status || true
