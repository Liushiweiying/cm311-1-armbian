# CM311-1 刷 Armbian 实战笔记

魔百盒 **CM311-1**（中国移动定制机顶盒）刷 **Armbian** 的完整准备与操作记录。

适用于 **Amlogic S905L3 系**（`s905l3` / `s905l3b`）机型，
覆盖 TTL 串口验证、启动介质选择、写入 eMMC、SSH 远控与故障排查。

---

## ⚠️ 先读这一节：型号与芯片极易搞错

**`CM311-1` 和 `CM311-1a` 不是同一台机器，芯片不同。**

| 型号 | SoC | 平台 | 设备树 | 内核支持 |
|---|---|---|---|---|
| **CM311-1** | `s905l3` / `s905l3b` | `meson-gxl` | `meson-gxl-s905l2-x7-5g.dtb`<br>`meson-gxl-s905l3b-m302a.dtb` | 仅 `stable/6.18.y` |
| CM311-1a | `s905l3a` | `meson-g12a` | `meson-g12a-s905l3a-cm311.dtb` | `stable/all` |

*（来源：[ophub 官方机型数据库](https://github.com/ophub/amlogic-s9xxx-armbian) ID 122 / 127 / 305）*

**两者镜像、dtb、u-boot 引导文件完全不通用。**
网上绝大多数「CM311 刷 Armbian 保姆教程」写的是 **1a（L3A）**，
直接照抄到 **1（L3/L3B）** 上会卡开机 logo 或黑屏。

### 常见的销售话术陷阱

- **「八核」** —— 不成立。L3/L3B/L3A 都是**四核**，商家把 CPU 核与 GPU 核凑一起算
- 页面写「S905L3 芯片」但配的是 1a 的教程 —— 芯片和教程对不上
- 标「CM311-1a」但实际是 `CM311-1` —— 型号名里的那个 **`a`** 是关键

**到货第一件事是用 TTL 串口确认平台，别信标签。**

---

## 🚨 不可逆风险（唯一真正危险的环节）

| 风险 | 后果 | 防范 |
|---|---|---|
| **12V 电源极性插反** | 烧 PMIC/SoC，**永久报废** | 万用表量原装头 → 量新头 → 一致才插 |
| 短接 eMMC 引脚失手 | 熔锡焊死，eMMC 报废 | 用 HDMI 免拆神器替代镊子 |
| TTL 转接板设成 5V | 可能损坏 SoC UART | 确认 **3.3V** |
| TTL 的 VCC 接到盒子 | 可能损坏 UART | **VCC 一律不接** |

**软件层面基本刷不死**：Amlogic 的 BootROM 烧在 SoC 硅片里，物理不可擦除，
最坏情况可用 Amlogic USB Burning Tool 线刷救回。
**真正不可逆的只有电源极性和手工短接。**

---

## 📁 仓库结构

```
.
├── README.md                      本文件
├── docs/
│   ├── 到货前检查清单.md           磁贴式清单 + 电视/TTL 分工
│   ├── 硬件兼容性记录.md           实机硬件、JMS578 UAS 坑、TTL 模块跳线
│   ├── 刷机操作手册_TTL+SSH.md     完整操作流程（主线）
│   ├── ADB开启与使用.md            ADB 排查与 TTL 优先级
│   └── tools.md                    工具官方来源、SHA256 校验值、为何不转存
├── scripts/
│   └── download-materials.ps1     一键下载镜像与工具（内置校验）
└── .gitignore
```

> **本仓库仅收录刷机（硬件改造）相关内容。**
> 网络架构、安全加固、自建服务部署等属个人基础设施，不在公开范围内。

**镜像与工具不进仓库**（体积大、且需校验来源），用 `scripts/download-materials.ps1` 拉取。

### 关于下载

本项目**不转存任何第三方二进制**，也不提供 release 附件：

- **法律**：Amlogic USB Burning Tool 是专有软件且**无再分发授权**
- **安全**：README 提醒读者"Burning Tool 需自行甄别来源"，
  若项目自己 re-host 一份，就等于把"需要甄别"变成"从这仓库下就行"——
  而这份副本**同样无法验证**，是在给下一个人挖坑

正确做法是**文档化官方来源 + 校验值**，详见 [`docs/tools.md`](docs/tools.md)。
`scripts/download-materials.ps1` 已内置可比对的 SHA256。

```powershell
# 默认下载到 .\materials
.\scripts\download-materials.ps1

# 只下工具（跳过约 2.5 GB 镜像）
.\scripts\download-materials.ps1 -ToolsOnly

# 指定目录
.\scripts\download-materials.ps1 -Base D:\cm311
```

> **若报 `running scripts is disabled on this system`**：
> 这是 Windows 默认执行策略，不必改系统设置，用进程级绕过即可：
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
> ```

---

## 🔧 物料清单

| 物料 | 必需性 | 说明 |
|---|---|---|
| **U 盘 或 SSD+硬盘盒** | ✅ **必需** | 启动介质，见下文 |
| **USB-TTL 转接线（3.3V）** | ✅ **必需** | L3 无显示输出，串口是唯一的「眼睛」 |
| 12V 电源 | ✅ 必需 | 原装 1A 够用；换 3A 留给 USB 外设余量 |
| 万用表 | ✅ 必需 | 量电源极性 |
| HDMI 线 + 显示器 | ⭕ 一次性 | 仅用于开 ADB 时看界面 |
| 双公头 USB 线 | ⭕ 备用 | 启用网络 ADB / 线刷救砖 |
| Amlogic USB Burning Tool | ⭕ 仅救砖 | 无官方直链，需自行甄别来源 |
| HDMI 免拆神器 | ⭕ 仅救砖 | 替代镊子短接，避免焊死引脚 |

---

## 🚀 快速流程

### 0. TTL 验机（到货第一件事）

```
转接板          盒子
 GND   ──────   GND     ← 先用通断档确认 GND 焊盘
 RX    ──────   TX      ← 交叉
 TX    ──────   RX      ← 交叉
 VCC   ──────   ✗ 不接
```

- 跳线 **3.3V**，串口参数 **115200 8N1**
- **串口工具先打开、连上 COM 口，再给盒子上电**（否则抓不到启动日志）
- 日志里找平台标识：
  - **`gxl`** → S905L3 / L3B ✅ 本方案
  - **`g12a`** → S905L3A（型号不对，需重新评估）
- 再区分 **L3 还是 L3B**，决定用哪个镜像
- 开机时按回车打断 u-boot，拿到 `u-boot>` 提示符

> **为什么必须用 TTL**：L3/L3B **不支持显示器显示**启动跑码信息，
> 屏幕全程无输出。串口是唯一可视化通道。

### 1. 选启动介质

**本机结论：用 U 盘。** 详见 [`docs/硬件兼容性记录.md`](docs/硬件兼容性记录.md)。

| 方案 | 本机可行性 |
|---|---|
| **U 盘** | ✅ **推荐** |
| SSD + thinkplus K01-A 硬盘盒 | ❌ 该盒是 **JMS578** 主控，UAS 兼容性差，且 quirk 在启动阶段无效 |

> **为什么硬盘盒不能当启动盘**：`usb-storage.quirks` 是 **Linux 内核参数**，
> 而启动阶段是 **u-boot** 在工作，没有内核模块机制，用不上这个参数。

**⚠️ 启动阶段优先直插盒子（靠近网口的 USB 口），不要经过 Hub。**

Hub 解决供电，却增加一层 USB 枚举，老旧 u-boot 对 Hub 后面的设备识别率明显下降。
建议顺序：**直插 → 不行再套供电拓展坞 → 都不行换介质**。

**⚠️ 一次只插一个存储设备**，写 eMMC 时多插容易认错设备节点。

### 2. 启动并写入 eMMC

**系统最终跑在盒子本体的 eMMC 上**，U 盘只负责"把系统送进去"。

```bash
armbian-ddbr        # ⚠️ 第一件事：备份原厂 eMMC！L3 底包难找
armbian-install     # 写入 eMMC，内部处理 dtb/u-boot/分区扩容
```

**不要用网文里的硬编码 `dd` 命令**——分区不会自动扩容，且设备节点编号不保证一致。

装完 → 断电 → **拔掉启动介质** → 重新上电，应从 eMMC 启动。

### 3. SSH 远控

```bash
ssh root@<盒子IP>     # 默认 root / 1234，首次登录强制改密码
```

**安全必修**：改强密码 → 配密钥登录 → 禁用密码登录 → **不要直接暴露到公网**。

---

## ⚖️ 本机型的已知约束

| 约束 | 影响 |
|---|---|
| **无 WiFi**，仅百兆网口 | 实际吞吐约 11 MB/s，NAS 场景的真正瓶颈 |
| **USB 2.0**（GXL 平台） | 外接 SSD 顺序读写约 35–40 MB/s 封顶 |
| 内核被钉在 `stable/6.18.y` | 不能随意跟随最新内核 |
| 社区资料以 L3A 为主 | 需自行筛选，多数教程不适用 |

---

## 📚 参考资料

- [ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian) —— 官方机型数据库与镜像
- [魔百盒 CM311-1 的刷机教程（恩山）](https://www.right.com.cn/FORUM/thread-8421413-1-1.html)
- [cm311-1a-yst 机顶盒刷 Armbian 问题汇总](https://www.cnblogs.com/dirgo/p/17558205.html)
- [cm311-1a 挂移动硬盘供电不足（恩山）](https://www.right.com.cn/forum/thread-8256963-1-1.html)
- [如何让 N1 盒子、机顶盒开机从优盘启动](https://blog.csdn.net/qq_42123284/article/details/135819870)
- [CoreELEC: Amlogic Bootcard / 短接 eMMC 警告](https://wiki.coreelec.org/coreelec%3aaml_burncard)
- [创维 E900V22D（S905L3B）刷机踩坑：最终用了 L3A 的 DTB](https://www.cnblogs.com/pcisig/p/19626901)

---

## ⚠️ 免责声明

本仓库为**个人折腾记录**，内容基于公开资料与社区经验整理，
**部分结论未经在全部机型/批次上实测验证**（尤其 dtb 选择、内核版本行为）。

刷机有风险，**电源极性接反等硬件操作可能永久损坏设备**。
请自行核对型号与芯片后再动手，**后果自负**。

欢迎 issue 补充你机型上的实测结果。
