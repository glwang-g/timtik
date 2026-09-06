# 部署到 `timtik.freexlib.com`

timtik 是静态 PWA。部署工作流会在推送 `master` 后，通过 SSH 和 rsync 将运行文件同步到已有服务器；它不会修改 Nginx、创建目录或以 root 身份执行命令。

## 1. 服务器准备

在服务器上创建一个由部署用户可写的目标目录，例如：

```bash
sudo mkdir -p /var/www/timtik
sudo chown deploy:deploy /var/www/timtik
```

为部署用户创建一对专用 SSH 密钥；把公钥放入该用户的 `~/.ssh/authorized_keys`。不要复用个人登录私钥，也不要给部署用户不必要的 sudo 权限。

Nginx 的站点根目录指向此目录，并为 PWA 保留正确的缓存策略：

```nginx
server {
  listen 443 ssl http2;
  server_name timtik.freexlib.com;
  root /var/www/timtik;
  index index.html;

  location = /service-worker.js {
    add_header Cache-Control "no-cache" always;
    try_files $uri =404;
  }

  location = /manifest.webmanifest {
    add_header Cache-Control "no-cache" always;
    try_files $uri =404;
  }

  location / {
    try_files $uri $uri/ =404;
  }
}
```

证书必须覆盖 `timtik.freexlib.com`；HTTPS 对 Service Worker、安装和麦克风权限都是必要条件。

## 2. GitHub Actions Secrets

进入仓库 **Settings → Secrets and variables → Actions**，添加以下 Repository secrets：

| Secret | 示例 | 说明 |
| --- | --- | --- |
| `DEPLOY_HOST` | `your-server.example` | 服务器主机名或 IP |
| `DEPLOY_USER` | `deploy` | SSH 部署用户 |
| `DEPLOY_PORT` | `22` | SSH 端口；不填时工作流也会默认 22，但建议明确设置 |
| `DEPLOY_PATH` | `/var/www/timtik` | 已存在、部署用户可写的目录 |
| `DEPLOY_SSH_KEY` | 私钥全文 | 专用于部署的私钥（建议 ed25519） |
| `SSH_KNOWN_HOSTS` | `host ssh-ed25519 AAAA...` | 服务器的 SSH host key；不要关闭 host key 校验 |

生成 known_hosts 条目时，在你信任的本机执行（将主机和端口替换为与 `DEPLOY_HOST`、`DEPLOY_PORT` **完全相同**的值）：

```bash
ssh-keyscan -p 22 -t ed25519 your-server.example
```

若服务器 SSH 端口不是 22，必须带上相同端口，例如：

```bash
ssh-keyscan -p 2222 -t ed25519 your-server.example
```

该输出会使用 `[your-server.example]:2222` 形式；这是 GitHub Runner 用非 22 端口连接时所需的形式。若服务器没有 ed25519 host key，可移除 `-t ed25519`，获取服务器实际提供的 ecdsa/rsa key。

将完整输出（可多行）原样粘贴到 `SSH_KNOWN_HOSTS`。不要在 `DEPLOY_HOST` 填 `https://`、路径或与扫描不同的别名：扫描域名、扫描 IP、`DEPLOY_HOST` 三者必须一致。应通过服务器控制台或既有可信记录核验指纹，避免仅信任网络扫描结果。

`DEPLOY_SSH_KEY` 必须是部署密钥的**完整私钥**，包含开始、结束行与中间每一行换行，例如：

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

不要填 `.pub` 文件（它通常以 `ssh-ed25519 AAAA...` 开头）、不要把换行改为字面量 `\n`、不要只复制中间 base64 内容，也不要使用需要交互输入口令的私钥。对应的公钥才应放到服务器部署用户的 `~/.ssh/authorized_keys`。工作流会在连接前用 `ssh-keygen -y` 校验 Secret 写出的私钥；若这里失败，重新从本机私钥文件完整复制到 GitHub Secret。

出现 `Host key verification failed` 时，优先逐项核对：

1. `SSH_KNOWN_HOSTS` Secret 是否已保存到 **同一个 timtik 仓库**，且不是空值。
2. 扫描时的主机名/IP 和端口是否分别等于 `DEPLOY_HOST` / `DEPLOY_PORT`。
3. Secret 中是否保留了整行 `host key-type base64-key`，没有粘贴 SSH 用户私钥或 `ssh-keyscan` 的错误信息。
4. 若服务器重装或轮换过 SSH host key，重新核验后更新 Secret。

## 3. 首次发布与验证

1. 将本工作流推送到 `master`。
2. 在 GitHub 的 **Actions → Deploy timtik** 查看运行日志；也可手动运行 `workflow_dispatch`。
3. 访问 `https://timtik.freexlib.com`，确认页面、语音授权和按钮操作。
4. 在 DevTools 的 Application 面板确认 Manifest 与 Service Worker 已激活；发布新版本后刷新一次，确认 Service Worker 能更新。

如果部署失败，工作流会在目标目录不存在或 SSH host key 不匹配时停止，而不会把文件同步到未知位置。
