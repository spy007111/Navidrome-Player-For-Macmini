# Apple Music for macOS (支持本地音乐与 Navidrome 串流)

一款深度仿照 macOS 原生 **Apple Music** 设计风格的高保真音乐播放器。既支持扫描并播放本地音乐库（MP3, FLAC, M4A, WAV, AAC, ALAC），又可无缝连接您的自建 **Navidrome** / Subsonic 音乐服务器。

---

## 📦 下载安装

### 直接下载（推荐）

前往 [Releases](https://github.com/spy007111/Navidrome-Player-For-Macmini/releases/latest) 下载：

| 文件 | 说明 |
|---|---|
| `AppleMusicPlayer-v1.0.0-macOS-universal.zip` | 通用版，Apple 芯片与 Intel Mac 均可运行 |

**系统要求**：macOS 14.0 (Sonoma) 或更高版本。

**安装步骤**

1. 下载并解压 zip，得到 `AppleMusicPlayer.app`
2. 拖入「应用程序」文件夹
3. 首次打开请**右键点击 App → 选择「打开」→ 在弹窗中再点「打开」**

> 本 App 使用 ad-hoc 签名，未经过 Apple 公证（公证需付费开发者账号）。首次启动被 Gatekeeper 拦截属于预期行为。若右键打开仍被阻止，可在终端执行：
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/AppleMusicPlayer.app
> ```

### 从源码构建

```bash
git clone https://github.com/spy007111/Navidrome-Player-For-Macmini.git
cd Navidrome-Player-For-Macmini
./build_app.sh
open AppleMusicPlayer.app
```

构建脚本会编译 Universal 二进制（arm64 + x86_64），并自动打包与本地签名。

---

## ✨ 核心特性

### 1. 纯正 Apple Music 原生界面体验
- **磨砂玻璃侧边栏 (Vibrancy & Material)**：
  - **Apple Music / 发现**：现在就听、浏览全部专辑。
  - **资料库**：最近添加、艺人、专辑、歌曲列表。
  - **音乐源**：本地音乐库与 Navidrome 服务器状态指示。
- **顶部 LCD 胶囊播放栏**：
  - 左侧播放控制：上一首、播放/暂停、下一首、随机播放模式、单曲/全部循环模式。
  - 中间高精播放视窗：实时专辑封面微缩图、歌曲名、艺人、无级进度拖拽条（已播放时间与剩余倒计时）、本地/云端来源标识。
  - 右侧音量滑块、一键静音、实时歌词切换、待播清单面板。

### 2. 本地音乐库管理
- 默认自动关联 macOS 用户音乐目录（`~/Music`），并支持添加自定义文件夹或外接移动硬盘。
- 基于 `AVAsset` 异步解析音频元数据（ID3 标签：标题、艺人、专辑、年份、流派、曲目编号与高清内嵌封面）。
- 本地音乐库自动持久化缓存至 Application Support，秒级冷启动。

### 3. Navidrome / Subsonic 深度整合
- 支持连接任何标准 Navidrome 或 Subsonic 兼容服务器。
- 采用规范的 **Salt + MD5 Token** 身份认证协议，保证传输安全。
- 具备快速**测试连接**功能，检测服务器类型与 API 版本。
- **云端音乐浏览**：分类浏览（最近添加、最新发行、最常播放、随机探索、全部专辑）。
- **全局搜索**：支持在 Navidrome 服务器中跨单曲、专辑与艺人实时检索。
- **高音质流式串流**：无缝在线解码播放，自动载入远程高清封面。

### 4. Apple Music 沉浸式动态歌词
- 支持从本地伴随 `.lrc` 文件、音频内嵌歌词（USLT）或 Navidrome 云端歌词服务拉取。
- 采用 Apple Music 招牌式的**彩色弥散光晕背景**。
- 当前正在播放行高亮放大、平滑滚动居中；**点击任意歌词行可即时跳转歌曲对应时间戳**。

### 5. 系统级整合与快捷键
- **macOS 系统控制中心与媒体键**：支持键盘 F8（Play/Pause）、F7/F9 切换曲目，支持 Control Center 播放小组件与锁屏封面展示。
- **全局快捷键**：
  - `空格键`：播放 / 暂停
  - `⌘ + →`：下一首
  - `⌘ + ←`：上一首
  - `⌘ + L`：开启 / 关闭实时歌词
  - `⌘ + U`：开启 / 关闭待播清单

---

## 🚀 快速启动

构建完成后，也可用启动脚本直接打开 App：

```bash
./run.sh
```

---

## ⚙️ Navidrome 服务器配置指南

1. 启动播放器后，点击左侧边栏底部的 **“Navidrome 设置 (⚙️ 图标)”** 或选择 **“Navidrome”** 页面中的 **“配置服务器连接”**。
2. 输入您的服务器信息：
   - **服务器地址**：例如 `http://192.168.1.100:4533` 或 `https://music.yourdomain.com`
   - **用户名**：您的 Navidrome 账号
   - **密码**：您的 Navidrome 密码
3. 点击 **“测试连接”**，显示连接成功后点击 **“保存并连接”**。
4. 随后即可在侧边栏直接点播您的私有云端曲库！
