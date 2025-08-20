#!/bin/bash
# 一键部署 2FAuth (Debian 13) + HTTPS + 自动 SSL

set -e

# -----------------------------
# 1️⃣ 询问域名
# -----------------------------
read -p "请输入你的域名（必须有公网解析，自动获取 HTTPS）： " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "必须提供域名才能自动获取 HTTPS。"
    exit 1
fi

# -----------------------------
# 2️⃣ 安装基础依赖
# -----------------------------
apt update
apt install -y curl unzip git nginx php8.3-cli php8.3-fpm php8.3-bcmath php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-zip php8.3-sqlite3 composer certbot python3-certbot-nginx

# -----------------------------
# 3️⃣ 创建部署目录
# -----------------------------
DEPLOY_DIR=/opt/2fauth
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# -----------------------------
# 4️⃣ 克隆或更新 2FAuth
# -----------------------------
if [ ! -d "$DEPLOY_DIR/.git" ]; then
    git clone https://github.com/your-repo/2fauth.git .   # 替换成2FAuth仓库地址
else
    git pull
fi

# -----------------------------
# 5️⃣ 安装 Composer 依赖
# -----------------------------
composer install --no-dev --optimize-autoloader

# -----------------------------
# 6️⃣ 配置 .env 文件
# -----------------------------
if [ ! -f ".env" ]; then
    cp .env.example .env
fi

php artisan key:generate

# 默认使用 SQLite
DB_FILE=$DEPLOY_DIR/database/database.sqlite
mkdir -p database
touch $DB_FILE
chmod 664 $DB_FILE

sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=sqlite|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_FILE|" .env

# -----------------------------
# 7️⃣ 设置权限
# -----------------------------
chown -R www-data:www-data storage bootstrap/cache database
chmod -R 775 storage bootstrap/cache database

# -----------------------------
# 8️⃣ 数据库迁移和填充
# -----------------------------
php artisan migrate --force
php artisan db:seed --force

# -----------------------------
# 9️⃣ 安装 Passport 密钥
# -----------------------------
rm -f storage/oauth-*.key
php artisan passport:install
chown www-data:www-data storage/oauth-*.key
chmod 600 storage/oauth-*.key

# -----------------------------
# 10️⃣ 清理缓存
# -----------------------------
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# -----------------------------
# 11️⃣ 配置 Nginx
# -----------------------------
NGINX_CONF="/etc/nginx/sites-available/2fauth.conf"
cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $DEPLOY_DIR/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf $NGINX_CONF /etc/nginx/sites-enabled/2fauth.conf
nginx -t && systemctl restart nginx

# -----------------------------
# 12️⃣ 自动获取 HTTPS
# -----------------------------
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# -----------------------------
# 13️⃣ Cloudflare / CSP 提示
# -----------------------------
echo "⚠️ 如果使用 Cloudflare，请确认 Rocket Loader 已关闭，否则前端 JS 可能被 CSP 拦截导致白屏。"

# -----------------------------
# 14️⃣ 部署完成提示
# -----------------------------
echo "🎉 2FAuth 已部署完成！"
echo "访问: https://$DOMAIN"
echo "日志路径: $DEPLOY_DIR/storage/logs/laravel.log"
