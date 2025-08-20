# 2FAuth 一键部署脚本

`deploy-2fauth.sh` 是一个针对 Debian 13 系统的 **2FAuth 一键部署脚本**，可以自动完成 PHP、数据库、Laravel、Passport、Nginx、HTTPS 等所有配置，帮助你快速部署可用的 [2FAuth](https://github.com/Bubka/2FAuth) 服务。

作者自用，但至少一半的BUG归咎于Chatgpt-5，求助罪魁祸首或者仔细阅读报错可能是最快的解决方案。

再次鸣谢[Bubka](https://github.com/Bubka)大佬的[2FAuth](https://github.com/Bubka/2FAuth) 

---


## 使用方法

### 1. 下载脚本

```bash
wget https://github.com/JerryZhi/deploy-2fauth/raw/refs/heads/main/deploy-2fauth.sh -O deploy-2fauth.sh
chmod +x deploy-2fauth.sh
```

### 2. 执行脚本

```bash
sudo ./deploy-2fauth.sh
```

### 3. 脚本会做的事情

1. 安装 PHP 8.3 和必要扩展
2. 安装 Composer 并拉取依赖
3. 配置 Laravel `.env` 文件
4. 创建 SQLite 数据库文件
5. 执行迁移和数据填充
6. 安装 Passport 密钥
7. 修复目录权限
8. 配置 Nginx 并重启
9. 自动获取 HTTPS 证书
10. 清理 Laravel 缓存

### 4. 部署完成后访问

```text
https://<你的域名>
日志路径: /opt/2fauth/storage/logs/laravel.log
```

---

## 功能特点

* 自动安装 PHP 8.3 及必需扩展
* 安装 Composer 并拉取 2FAuth 项目依赖
* 自动生成 Laravel `APP_KEY`
* 自动创建 SQLite 数据库文件并执行迁移/填充
* 自动安装 Laravel Passport 密钥
* 修复 storage / bootstrap/cache 权限
* 自动配置 Nginx 并启用站点
* 自动获取 Let's Encrypt HTTPS 证书
* 提示 Cloudflare Rocket Loader / CSP 注意事项
* 自动清理 Laravel 缓存

---

## 环境要求

* **操作系统**：Debian 13 (作者实测可用，其他发行版未知)
* **权限**：root 或 sudo 权限
* **域名**：公网解析可用的域名（用于自动获取 HTTPS）

---

## 注意事项

* **Cloudflare 用户**：请确保关闭 Rocket Loader，否则前端 JS 可能被 CSP 拦截导致白屏。
* **域名解析**：自动 HTTPS 依赖域名解析正确，DNS 必须指向当前服务器 IP。
* **防火墙**：确保 80 和 443 端口允许访问。

---

## 常见问题

### 1. 前端白屏 / 控制台 CSP 报错

* 原因：Cloudflare Rocket Loader 或 CSP 策略阻止 JS 加载
* 解决方法：关闭 Rocket Loader 或调整 CSP，允许加载 `/cdn-cgi/scripts/`

### 2. 日志文件不存在或无法写入

* 确认 `storage` 和 `bootstrap/cache` 目录权限：

```bash
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

### 3. HTTPS 获取失败

* 确认域名解析正确，并且 80 端口可访问
* Certbot 会自动尝试获取证书，失败时可以手动执行：

```bash
sudo certbot --nginx -d <你的域名>
```

### 4. Passport 错误

* 如果出现 `Invalid key supplied` 错误：

```bash
php artisan passport:install
chown www-data:www-data storage/oauth-*.key
chmod 600 storage/oauth-*.key
```

---

## 卸载或重新部署

1. 停止 Nginx 并删除站点配置：

```bash
sudo rm /etc/nginx/sites-enabled/2fauth.conf
sudo rm /etc/nginx/sites-available/2fauth.conf
sudo systemctl reload nginx
```

2. 删除 2FAuth 目录：

```bash
sudo rm -rf /opt/2fauth
```

3. 删除 SSL 证书：

```bash
sudo certbot delete --cert-name <你的域名>
```

---

## 许可证

MIT License

---