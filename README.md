# Singularity (kebab) + KernelSU-Next 自编译构建套件

给 OnePlus 8T（`kebab`）用的 **GitHub Actions 构建配置**：把 `The-Anomalist/Singularity` 内核源码
和指定版本的 **KernelSU-Next**（默认 `v3.4.2`）一起编译，再打包成可直接在 LineageOS Recovery 里
`adb sideload` 的 AnyKernel3 zip。

产出的内核版本形如：

```
4.19.325-cip135-st19-ksu342-Singularity
```

---

## 0. 为什么需要自己编

KernelSU 的版本是**编译进内核镜像**的，不是能单独刷的组件。作者目前发布的 `V17` 里内核侧是
KSU-Next **3.3.0**：

- 管理器 APK 升到 3.4.2 会显示 `Kernel update required`，且 KSU-Next 在“管理器版本高于内核、
  且低于最低要求”时会**无法正常管理 root 授权**（参见 [issue #917](https://github.com/KernelSU-Next/KernelSU-Next/issues/917)）。
- 作者的 KSU fork（`The-Anomalist/KernelSU-Next`）只有 `v3.3.0` / `v3.3.0-singularity` 两个 tag，
  没有 3.4.x 分支。

所以要拿到 3.4.2 内核，只能：**换掉 `KernelSU-Next` submodule 的版本 → 重新编译 → 重新打包**。本目录就是干这个的。

---

## 1. 目录内容

```
kernel-build/
├─ .github/workflows/build-kebab.yml   # 整个构建流水线
├─ scripts/pack_anykernel.sh           # 把新 Image 塞回作者的 AnyKernel3 骨架并打包
└─ README.md
```

流水线做的事：

1. 浅克隆内核源码（分支 `event-horizon`），初始化 submodule；
2. 把 `kernel/KernelSU-Next` 切到你指定的 tag（默认 `v3.4.2`，来源改为上游 `KernelSU-Next/KernelSU-Next`）；
3. 改写 `localversion-st`，让 `uname -r` 能区分自编译版本；
4. 下载 AOSP 预编译 clang（默认 `clang-r596125`，即作者用的 clang 22）；
5. `make vendor/kona-perf_defconfig` + `make Image`；
6. （可选）关掉 `CONFIG_KSU` 再编一个 No-KSU 版；
7. 下载作者 `V17` 的 AnyKernel3 zip 当骨架，替换 `Image-KSU` / `Image-NoKSU`，重新打包（DTB/DTBO 沿用作者的，
   保证硬件描述不变）；
8. 上传 artifact。

关键事实（已核对源码，不是猜的）：

| 项 | 值 |
| --- | --- |
| defconfig | `arch/arm64/configs/vendor/kona-perf_defconfig`，本身已含 `CONFIG_KSU=y`、`CONFIG_KSU_MANUAL_HOOK=y` 和全套 `CONFIG_KSU_SUSFS_*` |
| KSU 接入 | `drivers/kernelsu` 是指向 `../KernelSU-Next/kernel` 的符号链接，`drivers/Kconfig` 已 `source "drivers/kernelsu/Kconfig"` |
| 版本号来源 | `localversion-cip`（`-cip135`）+ `localversion-st`（`-st19`）+ `CONFIG_LOCALVERSION="-Singularity"` |

---

## 2. 一次性准备（约 5 分钟）

1. 在 GitHub 新建一个**私有空仓库**，例如 `singularity-kebab-build`。
2. 把本目录内容推上去（`A` 换成你的用户名）：

```bash
cd kernel-build
git init
git add -A
git commit -m "init: kebab kernel build"
git branch -M main
git remote add origin https://github.com/A/singularity-kebab-build.git
git push -u origin main
```

> 注意：`.github/workflows/build-kebab.yml` 必须在仓库**根目录**的 `.github/workflows/` 下，Actions 才会识别。

3. 打开仓库 → **Actions** → 左侧 `Build Singularity kebab (KernelSU-Next)` → **Run workflow**。

---

## 3. 建议分两次跑

### 第一次：验证流水线（`ksu_ref = v3.3.0`）

目的：确认「克隆 + 工具链 + 编译 + 打包」这套流程本身没问题。

- 点 **Run workflow**，把 `ksu_ref` 改成 `v3.3.0`，其他保持默认。
- 产物应该和作者的 V17 非常接近（内核侧还是 3.3.0）。
- **如果想要零风险**：这一步的产物你可以先不刷，只看构建是否成功、`make kernelrelease` 打印的版本号对不对。

这一步能过的意义很大：说明后面的失败只可能来自 KSU 3.4.2 的代码本身。

### 第二次：真正升级到 3.4.2

- 再点一次 **Run workflow**，`ksu_ref` 保持默认 `v3.4.2`。
- 构建成功后下载 artifact：`singularity-kebab-v3.4.2-<run>-<sha>.zip` 及同名 `.txt`（含 sha256）。

---

## 4. 刷机

前提：手机当前已经是 Singularity 内核 + KernelSU-Next 环境（你现在就是这个状态）。

1. 电脑上确认设备在线：

```powershell
adb devices
```

2. 进 recovery 的 sideload：

```powershell
adb reboot recovery
# 手机：Apply update -> Apply from ADB
adb -d sideload path\to\Singularity-kebab-v3.4.2-....zip
```

3. 传输完成后，安装器会问内核模式：

- **音量上 = KernelSU 内核** ← 选这个
- 音量下 = No-KSU 内核

4. 屏幕出现 `Singularity install completed` 后，回主菜单 **Reboot system now**。

5. 换管理器：内核现在是 3.4.2 了，把 APK 换成对应版本：

```powershell
adb install -r D:\LOS\kernel\KernelSU_Next_v3.4.2-release.apk
```

> 如果你先装了 3.3.0 管理器，需要先 `adb uninstall com.rifsxd.ksunext` 再装 3.4.2（版本号回退不允许覆盖安装）。

### 验证

```powershell
adb shell uname -r
# 期望：4.19.325-cip135-st19-ksu342-Singularity
```

打开 KernelSU-Next 管理器：

- 首页应显示 **工作中**，内核版本 `v3.4.2`，管理器版本 `v3.4.2`
- 不再出现 `Kernel update required`
- `SuSFS 版本` 一栏应显示 `支持 v2.2.0 (NON-GKI)`
- `模块` 计数应与你原来的 9 个一致

---

## 5. 失败排查

| 现象 | 原因 / 对策 |
| --- | --- |
| `drivers/kernelsu/*` 编译报错（找不到符号、函数签名不匹配） | 最可能：作者在 `singularity-ksunext-v3.3.0-backport` 分支里做了 4.19 的 backport 适配，上游 3.4.2 的 legacy 代码没有对应改动。需要把这几个文件与作者 fork 的对应分支做 diff，把适配补丁搬到上游 3.4.2 上 |
| `unknown symbol CONFIG_KSU_SUSFS_*` | 3.4.x 里部分 SUSFS 配置项改名/删除，属警告，`olddefconfig` 会自动丢弃；功能以 3.4.2 的 Kconfig 为准 |
| `defconfig` 阶段报 `CONFIG_KSU` 不存在 | submodule 没切成功（`git describe` 那步没打印出 tag）。检查 `Swap KernelSU-Next` 步骤日志 |
| clang 下载 404 | `main-kernel` 分支里没有该 `clang-rNNNNNN`，换成日志里可用的版本，或改用 `clang-r547379` |
| 编译 OOM / 被杀 | 把 `-j$(nproc)` 改成 `-j4`；4.19 单文件很大，2 核跑更稳 |
| 构建成功但刷完不开机 | 内核代码可编 ≠ 能启动。先刷回作者 `V17` 的包恢复；再用 `ksu_ref=v3.3.0` 验证“自编译的内核本身能不能开机”，把变量分开 |

> 重要：**CI 只能证明“能编译”，不能证明“能开机”**。所以务必保留作者 `V17` 的 AnyKernel zip
> （本地 `D:\LOS\kernel\Singularity-V1.5.0-unified-Root-or-NoKSU.zip`）作为回退包。

---

## 6. 回退

任何一步不顺，都能回到作者官方内核（3.3.0）：

1. `adb reboot recovery` → Apply update → Apply from ADB；
2. `adb -d sideload D:\LOS\kernel\Singularity-V1.5.0-unified-Root-or-NoKSU.zip`；
3. 音量上选 KernelSU；
4. 重启后若管理器是 3.4.2，会重新出现 `Kernel update required`，这时把管理器退回 3.3.0：

```powershell
adb uninstall com.rifsxd.ksunext
adb install D:\LOS\kernel\KernelSU_Next_v3.3.0-release.apk
```

---

## 7. 关于 3.3.0 / 3.4.2 的实际差别

3.4.x 相对 3.3.x 主要是：`meta module`（元模块）、`shell_su_adb_only`、启动期内核模块黑名单、
SUSFS 的 LKM / open_redirect 改进。**日常 root 授权、模块加载、SUSFS 隐藏这些核心能力 3.3.0 全都有**。
如果你并不需要元模块这类新特性，留在作者发布的 3.3.0 配对是更省事、也更稳的选择。

---

## 8. 这套东西的验证状态（重要，请先读）

为了避免你推上去才发现低级错误，本套件在交付前做过以下**本地验证**：

| 验证项 | 结果 |
| --- | --- |
| `build-kebab.yml` YAML 语法 + 结构（11 个 step，每个都有 `run` 或 `uses`） | ✅ 通过 |
| `pack_anykernel.sh` 的 `bash -n` 语法检查 | ✅ 通过 |
| 打包脚本**端到端试跑**：真实下载 V17 骨架 → 替换 Image → 改 `kernel.string` → 重打包 | ✅ 通过（产物 46 个条目，`anykernel.sh` 在根目录，`devices/kebab/dtb.img`、`dtbo.img` 均在） |
| 内核**能否编译成功** | ❌ 未验证（本机没有 Linux/WSL/Docker，无法在此实际交叉编译） |
| 编译产物**能否开机** | ❌ 未验证（只能烧到真机才知道） |

也就是说：**流水线的“管道”是通的，但“水”能不能流到终点要靠 CI 跑一次才知道。**
最可能的失败点在「KernelSU-Next 3.4.2 的 legacy 代码与作者 3.3.0 backport 补丁的差异」，
届时把 CI 报错贴给我，我们按文件逐个对回去即可。

另外一个已经踩过并修掉的坑，供你以后改脚本时注意：`pack_anykernel.sh` 里给 `anykernel.sh`
写版本号的 `sed`，分隔符不能和替换文本里出现的字符相同（`|`、`,` 都踩过，现在用 `#`）。

