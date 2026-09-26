# 工具来源与校验

> **本项目不转存任何第三方二进制。** 所有工具请从**官方上游**获取。
> 原因见文末「为什么不做 release 转存」。

用 `scripts/download-materials.ps1` 可一键拉取，脚本内置下列校验值并自动核对。

---

## 一、必需工具

### 1. balenaEtcher —— 写盘

| 项目 | 值 |
|---|---|
| 用途 | 把 Armbian 镜像写入 U 盘 / SSD |
| 官方发布页 | <https://github.com/balena-io/etcher/releases> |
| 本文档对应版本 | **v2.1.7** |
| 直链 | `https://github.com/balena-io/etcher/releases/download/v2.1.7/balenaEtcher-2.1.7.Setup.exe` |
| **SHA256** | `386BB45DA6E0EDEB20E065427CDEF30A876E4D2A59579F8ADD329D8510AC12F8` |
| 许可 | Apache 2.0 |

**校验依据**：该值已与官方发布的 `SHA256SUMS.Windows.x64.txt` 逐字比对通过。

> 版本会更新。若官网已是新版，请下载对应的 `SHA256SUMS.Windows.x64.txt` 自行核对。

### 2. Android platform-tools —— adb

| 项目 | 值 |
|---|---|
| 用途 | `adb connect <IP>:5555`、`adb tcpip 5555` |
| 官方直链 | `https://dl.google.com/android/repository/platform-tools-latest-windows.zip` |
| **SHA256（下载时）** | `45F4D63113E895EBDE0C90F194099A4676B6AC653BD28D54314A9E022BBC1A99` |
| 许可 | Google / Android SDK 条款 |

> ⚠️ 这是 **`latest` 滚动链接**，内容随时间更新，**上述校验值会漂移**。
> 用于一次性核对"我下的这份和记录一致"，不适合当作长期固定值。

验证方式：

```powershell
adb version
# Android Debug Bridge version 1.0.41 / Version 37.0.1-...
```

### 3. 7-Zip —— 解压 `.img.gz`

| 项目 | 值 |
|---|---|
| 用途 | 需要时手动解压镜像（balenaEtcher 可直接吃 `.img.gz`，通常不必） |
| 官网 | <https://www.7-zip.org/> |
| 直链 | `https://www.7-zip.org/a/7z2501-x64.exe` |
| 许可 | LGPL（含 unRAR 限制，见 [官方许可](https://www.7-zip.org/license.txt)） |

> 未固化校验值。7-Zip 官网明确建议**只从其站点获取**，因为非官方来源的 7-Zip
> 是历史上有名的供应链攻击载体。需要校验请到官网查看。

---

## 二、Armbian 镜像

| 项目 | 值 |
|---|---|
| 上游 | <https://github.com/ophub/amlogic-s9xxx-armbian/releases> |
| 本文档对应 tag | `Armbian_trixie_arm64_server_2026.09` |
| 版本 | `26.11.0` / Debian 13 (trixie) / 内核 `6.18.51` / server |

| 板型 | 文件 | SHA256 |
|---|---|---|
| `s905l3` | `..._amlogic_s905l3_trixie_6.18.51_server_2026.09.14.img.gz` | `2A3886AE263A7CF3A44A53FC8BF674FD181A5D34A8A06FC3403A8713CCD4A205` |
| `s905l3b` | `..._amlogic_s905l3b_trixie_6.18.51_server_2026.09.14.img.gz` | `7C121575CBC35E7AF680B251BC90049605E82915DC62F756551C80C20F0CD8B2` |
| `s905l3-cm211` | `..._amlogic_s905l3-cm211_trixie_6.18.51_server_2026.09.14.img.gz` | `54A137C2BF58CA0B151D6F54BF52953280E4427CC434AC882D4F87951FB27862` |

> 上述为**本地下载后实测值**，非上游公布值（ophub 的 release 正文未提供校验和）。
> 可用于确认"我这份和作者下的是同一份"，也可对照上游文件大小复核。

---

## 三、❌ 未提供、也不会转存的工具

### Amlogic USB Burning Tool

| 项目 | 说明 |
|---|---|
| 用途 | 线刷安卓底包 / 救砖（**主流程用不到**） |
| 版权 | **晶晨专有软件** |
| 官方公开直链 | **无** |
| 再分发授权 | **无** |

**请自行从你信任的社区论坛获取，并自行扫描。** 常见坑：

- 有 SEO 农场站点打着"官方最新版"旗号，下载按钮实际指向**完全无关的软件**
- 网盘分享的副本无法校验来源
- 该工具需要安装底层 USB 驱动，**且会要求关闭驱动签名 / 内存完整性**——权限很高

**下载后建议**：用你的杀毒软件扫描，或上传 VirusTotal 复核。

### CM311-1 (YST) 原厂安卓固件

仅救砖需要。同样**不转存**——固件包体积大、来源杂、且可能包含运营商定制内容。

---

## 四、为什么不做 release 转存

虽然"把工具打包进 release"看起来方便，本项目**刻意不这么做**，理由有两条：

**1. 法律上站不住脚**

Amlogic USB Burning Tool 是**专有软件且无再分发授权**。7-Zip 的许可是 LGPL +
unRAR 限制，官方也明确建议从其站点获取。转存属于再分发，且没有正当理由。

**2. ⚠️ 更重要的：会制造供应链风险**

这才是核心。本项目 README 里提醒读者：

> Amlogic USB Burning Tool 无官方直链，需自行甄别来源

**如果项目自己 re-host 一份，就等于把"需要甄别来源"变成"从我的仓库下就行"——
而这个副本同样无法验证。**

现实中有活生生的例子：某篇号称「Amlogic V3.2 官方最新版」的文章，
下载按钮实际指向一个**毫不相干的软件**。

**把这种文件放进一个看起来像"项目官方"的 release，是在给下一个人挖同一个坑。**

**正确做法**：文档化**官方来源 + 校验值**，让使用者自己从上游拿，并自行核对。
这也是开源社区的标准实践——`scripts/download-materials.ps1` 就是这个思路的实现。

---

## 五、自行核对方法

```powershell
# 单个文件
Get-FileHash .\balenaEtcher-2.1.7.Setup.exe -Algorithm SHA256

# 批量核对（比对本文档表格）
Get-ChildItem -Recurse -File | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  "{0}`n  {1}" -f $_.Name, $h
}
```
