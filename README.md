文章框架由ai生成，由笔者重写。包含一部分从社区获得的经验与笔者的实战经历。


## 起因

从二手市场淘了一台魔百盒 CM311-1，2GB 内存 + 16GB 闪存，四核 Cortex-A53、百兆网口、两个 USB 2.0。

前任机主已经刷好了Android 9.0，ADB 默认开着。刚好可以满足小型服务器的需求。

## 准备

ai提到的工具很多，但是我只用上了一部分。
| 用上的 | 没用上的 |
|---|---|
| 网线 | TTL |
| U盘 | 双公头 USB 线 |
|  | 免拆神器 |
|  | 万用表 |
|  | 镊子 |
|  | 烙铁 |
|  | 12V3A 电源 |
|  | Type-C 充电线|


## 第一步：确认芯片

。CM311-1 和 CM311-1**a** 只差一个字母，但芯片完全不同：

| 型号 | SoC | 平台家族 | CPU 核心 |
|---|---|---|---|
| **CM311-1** | S905L3 / L3B | `meson-gxl` | **Cortex-A53** |
| CM311-1a | S905L3A | `meson-g12a` | Cortex-A55 |

两者镜像、设备树、引导文件**不通用**。

### 交叉验证

Agent老是要求**确认**。下面是交叉验证方法（适用于已打开ADB）：

```bash
# 系统属性
adb shell getprop ro.board.platform     # → p291_iptv

# CPU 核心型号（内核报告，难以伪造）
adb shell cat /proc/cpuinfo | grep "CPU part"   # → 0xd03
```

| CPU part | 核心 | 对应芯片 |
|---|---|---|
| **`0xd03`** | **Cortex-A53** | **S905L3 / L3B** |
| `0xd05` | Cortex-A55 | S905L3A |

**`0xd03` 一行排除 L3A。**

刷完之后看 Armbian 的开机横幅：

```
Amlogic Meson GXL (S905L2) X7 5G Tv Box
```

`GXL` 确认了平台家族，`X7 5G` 对应设备树 `meson-gxl-s905l2-x7-5g.dtb`。


## 第二步：刷机

### 用 ADB 触发，不用双公头线

如果盒子还能进安卓、ADB 还开着，有条捷径：

```bash
adb connect <盒子IP>:5555
adb shell reboot update
```

盒子会重启并尝试从 U 盘引导。**全程不需要拆机。**

### 写盘工具的选择

| 工具 | 结果 |
|---|---|
| balenaEtcher 2.1.7 | 安装成功但进程起不来 |
| **Rufus 4.15 便携版** | 直接可用 |

**写入时必须选「DD 映像模式」**，ISO 模式会写错。

### 最大的坑：首次启动网络不通

U 盘启动 Armbian 后，HDMI 显示进入了Amrbian的终端，但**路由器上找不到这台设备**。

当时排查了很久：网段扫描、端口探测、ARP 表。

**断电重启即可**


重启后 SSH 立即可用，HDMI显示变为满屏幕的命令。

## 第三步：写入 eMMC

### 先备份原厂系统

```bash
armbian-ddbr      # 交互式，选 b（backup）
```

L3 的安卓底包不好找，这个备份是唯一的退路。

14.6 GiB 的 eMMC 压缩后 3.2 GB。

### 安装

```bash
armbian-install
```

机型菜单里选 **ID 122**：

```
122   s905l3   CM311-1,HG680-LC,M401A,UNT402A,CM201-1-6-YS   meson-gxl-s905l2-x7-5g.dtb
```

文件系统选 **ext4**（2GB 内存跑 btrfs 太吃力）。

### 权限污染

装完之后 `sudo` 报错：

```
sudo: /etc/sudo.conf is owned by uid 1023, should be 0
```

检查发现：

```bash
find / -uid 1023 2>/dev/null | wc -l
# → 58448
```

**属主错误**

原因是：**在安卓运行时插着 U 盘，然后从 U 盘引导**，文件属主继承了错误的 uid。

修复：

```bash
chown -R root:root /etc /usr /var /opt /srv /root
```

改完重启，`systemctl --failed` 显示 0 个失败单元。

## 第四步：SSD 与存储(需要加Nofail)

一块 120GB 的 SATA SSD 装在 JMicron JMS578 芯片的硬盘盒（联想Thinkplus）里。

### UAS 不兼容

JMS578 支持 UAS（USB Attached SCSI），但在这个内核上会掉盘。要禁用：

编辑 `/boot/uEnv.txt`，在 `APPEND=` 行末尾追加：

```
usb-storage.quirks=0x152d:0xa578:u
```

重启后验证：

```bash
$ lsusb -t
|__ Port 001: Dev 003, If 0, Class=Mass Storage, Driver=usb-storage, 480M
                                                    ↑
                                            不是 uas，正确
```

### 拓展坞逆供电

本来买的是拓展坞（独立供电），但是插上之后发现拔了盒子电源线盒子还能工作，说明拓展坞在给盒子逆供电，这是廉价拓展坞的通病。

所以拔掉了拓展坞的电源线，改用盒子自带的 12V1A 电源，勉强能跑满USB 2.00的10MBps带宽。

## 第五步：目录隔离

SSD 上跑两类东西，必须隔离：

```
/mnt/ssd/
├── nas/          drwx------ root:root       ← Samba 共享
└── tuwunel/      drwx------ tuwunel:tuwunel ← Matrix 数据
```

| 方向 | 结果 |
|---|---|
| Samba → Matrix 数据 | 看不见（共享路径只指向 `nas/`） |
| Matrix 进程 → NAS 数据 | 进不去（权限 700，属主不是它） |

再加一层 systemd 加固：

```ini
[Service]
ProtectSystem=strict
ReadWritePaths=/var/lib/tuwunel /etc/tuwunel /run/tuwunel
ProtectHome=yes
NoNewPrivileges=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
```

### `InaccessiblePaths` 会启动失败

本来还想加一条 `InaccessiblePaths=/mnt/ssd/nas`，结果服务起不来：

```
tuwunel.service: Failed to set up mount namespacing:
/mnt/ssd/nas: No such file or directory
```

**原因是 `/mnt/ssd` 本身是 USB 设备的挂载点，在它的子路径上做命名空间覆盖挂载会失败。**

去掉这条，改用目录权限（`chmod 700`）实现隔离，效果一样。

## 第六步：私有 Matrix 服务器

选 [Tuwunel](https://github.com/matrix-construct/tuwunel) —— Conduwuit 的官方继任者，Rust 写的，1–5 个用户只占 100–200MB 内存。

对比 Synapse 要 800MB–1.5GB 还得外加 PostgreSQL，2GB 盒子上只有这条路。

### 安装

```bash
curl -fsSL -o /usr/share/keyrings/tuwunel-archive-keyring.gpg \
  https://apt.f.dog/tuwunel-archive-keyring.gpg

tee /etc/apt/sources.list.d/tuwunel.sources >/dev/null <<'EOF'
Types: deb
URIs: https://apt.f.dog
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/tuwunel-archive-keyring.gpg
EOF

apt update && apt install tuwunel
```

### 配置要点

```toml
[global]
server_name = "weishi1079.top"     # 永不可改
database_path = "/var/lib/tuwunel"
address = "127.0.0.1"
port = 6167
allow_registration = true
registration_token = "<随机令牌>"
allow_federation = false           # 关闭联邦
ip_source = "cf_connecting_ip"     # 走 Cloudflare

[global.well_known]
client = "<个人Server URL>"
server = "<个人Server URL>:443"
```

**`server_name` 一旦启动就烧进数据库，永久不可改。** 所以官方建议用根域而不是子域 —— 以后换部署位置不用动身份。

数据库放在 SSD 上，用 bind mount 绕开 AppArmor 的路径限制：

```bash
/mnt/ssd/tuwunel  /var/lib/tuwunel  none  bind  0  0
```

### systemd `Type=notify` 不兼容

`cloudflared service install` 生成的服务单元用了 `Type=notify`，但手工运行 `cloudflared tunnel run` 不会发就绪信号，systemd 一直等到超时：

```
Job for cloudflared.service failed because a timeout was exceeded.
```

修复（drop-in 覆盖）：

```bash
mkdir -p /etc/systemd/system/cloudflared.service.d
cat > /etc/systemd/system/cloudflared.service.d/type-fix.conf <<'EOF'
[Service]
Type=simple
EOF
```

### Token 账号不匹配

这个最难查。服务启动后日志报：

```
ERR Register tunnel error from server side error="Failed to get tunnel"
```

Token 结构完全合法 —— base64 能解码、`a`/`t`/`s` 三个字段齐全、Tunnel ID 也对得上 DNS 记录。

**但服务端说这条 Tunnel 不存在。**

最后把 token 解码对比才发现：

```json
{"a":"3302164450cbae93e3b693cc1b38d", ...}   ← 旧 token 的账号 ID
{"a":"b2cc745c2e169f50bb6ac0c9cabe2850", ...} ← 后台实际账号 ID
```

**两个完全不同的账号。** 换成后台重新生成的 token 后立刻正常。

## 最终架构

```
Cloudflare Tunnel
  ├── weishi1079.top        → Caddy:80  → 博客静态文件
  │                           └─ /.well-known/matrix/* → JSON（委托）
  ├── matrix.weishi1079.top → Tuwunel:6167
  └── www.weishi1079.top    → Caddy:80

盒子内部：
  eMMC 14G    → 系统
  SSD  110G   → /mnt/ssd
                 ├── nas/      → Samba 共享
                 ├── tuwunel/  → Matrix 数据库
                 └── www/blog/ → 博客
```

## 资源占用

| 进程 | 内存 |
|---|---|
| Tuwunel | 88 MB |
| cloudflared | 39 MB |
| Caddy | 35 MB |
| **合计** | **~163 MB** / 1.7 GB |

CPU 温度稳定在 52–58°C。

## 复盘

整件事没用上：双公头 USB 线、短接、免拆神器、TTL 串口。

但踩了七个坑：

1. 首次 U 盘启动网络不通 → 断电重启
2. 权限污染 58448 个文件 → `chown`
3. JMS578 的 UAS 不兼容 → `usb-storage.quirks`
4. SSD 供电不足掉盘 → 修 fsck
5. `InaccessiblePaths` 跨挂载点失败 → 改用目录权限
6. `Type=notify` 不兼容 → drop-in 改 `Type=simple`
7. **Tunnel token 账号 ID 不匹配** → 换后台新 token

排查时用过一个诊断脚本，把配置层、服务层、链路层、证据层一次性收集起来 —— 包括用 `openssl s_client` 抓 TLS 证书来判断有没有中间人。**证书 `issuer` 显示是 Cloudflare 的正规证书，才排除了 MITM，把方向转到 Connector 归属上。**
