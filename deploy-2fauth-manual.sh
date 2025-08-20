#!/bin/bash
set -e

# 这个脚本存在一定的问题，如需要手动设置DOMAIN和手动安装一些php拓展，请按照报错提示操作或者询问AI
# 记得关掉cloudflare的rocket loader
# 但除此之外实测可用

# ================= 配置 =================
APP_DIR="/opt/2fauth"
APP_PORT=8080
DOMAIN="you.domain.com"   # 替换成你的域名
EMAIL="admin@$DOMAIN"       # 用于 Let's Encrypt
PHP_VERSION="8.3"
PHP_BIN="/usr/bin/php"
# ========================================


echo "=== 更新系统 ==="
apt update && apt upgrade -y

echo "=== 安装基础依赖 ==="
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common unzip curl git sqlite3 nginx certbot python3-certbot-nginx

echo "=== 添加 sury PHP 源 ==="
wget -qO- https://packages.sury.org/php/apt.gpg | apt-key add -
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt update

echo "=== 安装 PHP 8.3 及扩展 ==="
apt install -y php$PHP_VERSION php$PHP_VERSION-cli php$PHP_VERSION-fpm \
php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-gd \
php$PHP_VERSION-curl php$PHP_VERSION-zip php$PHP_VERSION-tokenizer

echo "=== 安装 Composer ==="
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "=== 下载 2FAuth ==="
if [ ! -d "$APP_DIR" ]; then
    git clone https://github.com/Bubka/2FAuth.git "$APP_DIR"
fi
cd "$APP_DIR"

echo "=== 安装 PHP 依赖 ==="
composer install --no-dev --optimize-autoloader

echo "=== 配置环境变量 ==="
if [ ! -f ".env" ]; then
    cp .env.example .env
    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" .env
    sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=sqlite|" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=$APP_DIR/database/database.sqlite|" .env
    mkdir -p database
    touch database/database.sqlite
fi

echo "=== 初始化数据库 & 缓存 ==="
$PHP_BIN artisan key:generate
$PHP_BIN artisan migrate --force
$PHP_BIN artisan config:clear
$PHP_BIN artisan cache:clear
$PHP_BIN artisan route:clear

echo "=== 设置权限 ==="
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

echo "=== 配置 systemd 服务 ==="
cat >/etc/systemd/system/2fauth.service <<EOF
[Unit]
Description=2FAuth Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$PHP_BIN artisan serve --host=0.0.0.0 --port=$APP_PORT
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now 2fauth

echo "=== 配置 Nginx 反向代理 ==="
cat >/etc/nginx/sites-available/2fauth.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/2fauth.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "=== 获取 Let’s Encrypt 证书 ==="
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "✅ 部署完成 🎉"
echo "访问地址: https://$DOMAIN"
echo "服务已注册 systemd，可开机自启"
echo "查看服务状态: systemctl status 2fauth"
