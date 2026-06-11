# Codex Quota Float

[English](README.md) | [简体中文](README.zh-CN.md)

Codex Quota Float 是一个 macOS 悬浮窗和命令行工具，用来查看本机 Codex
账号的额度桶和剩余额度。它读取当前机器上已经登录的 Codex 账号，并把额度信息
展示在一个置顶的小浮窗里。

## 安装

```bash
curl -fsSL "https://raw.githubusercontent.com/chenf99/codex-quota-float/main/install.sh?$(date +%s)" | zsh
```

安装脚本会把仓库安装到 `~/.local/share/codex-quota-float`，并把
`codex-quota-float` 命令放到 `~/.local/bin`。如果 `~/.local/bin` 不在当前
shell 的 `PATH` 里，安装脚本会打印需要添加的命令。

## 常用命令

```bash
codex-quota-float start
codex-quota-float status
codex-quota-float skin set ~/Pictures/skin.png "My Skin"
codex-quota-float autostart install
codex-quota-float stop
codex-quota-float update
```

悬浮球或展开面板上可以右键打开菜单，用于刷新、切换皮肤和退出。

## 命令说明

```bash
codex-quota-float start [--interval seconds] [--normal-window]
```

打开额度悬浮窗。首次运行时会构建本地 `.app`，默认每 60 秒刷新一次额度。

```bash
codex-quota-float stop
```

关闭当前安装路径启动的悬浮窗。

```bash
codex-quota-float restart [--interval seconds] [--normal-window]
```

关闭并重新打开悬浮窗。

```bash
codex-quota-float status [--pretty|--json]
```

读取本机 Codex app-server 的账号和 rate-limit 快照，并在终端输出一次性额度摘要。

```bash
codex-quota-float skin set <image-path> [skin-title]
```

把本地图片复制到 `~/.codex-quota-float/skins/`，并作为悬浮球和展开面板的皮肤。
可选的 `skin-title` 会显示在皮肤菜单里。

```bash
codex-quota-float skin reset
```

移除自定义皮肤配置，恢复为内置的 `Classic Glass` 皮肤。

```bash
codex-quota-float skin path
```

打印当前用户的皮肤配置路径；如果已经配置了皮肤，也会显示当前配置内容。

```bash
codex-quota-float autostart install
```

创建 `~/Library/LaunchAgents/local.codex-quota-float.plist`，通过 `launchctl`
加载并立即启动一次。之后 macOS 用户登录时会自动打开悬浮窗。

```bash
codex-quota-float autostart uninstall
```

卸载并删除上面的 LaunchAgent，之后 macOS 登录时不会再自动启动。

```bash
codex-quota-float update
```

从 GitHub 更新已安装的仓库，并刷新 CLI wrapper。

```bash
codex-quota-float path
```

打印安装目录，通常是 `~/.local/share/codex-quota-float`。

```bash
codex-quota-float cli install [target-directory-or-path]
```

重新安装 shell wrapper。通常只有在你想把命令安装到 `~/.local/bin` 之外的目录时才需要用。

`open`、`quit`、`upgrade`、`login install/uninstall` 是兼容别名，分别对应
`start`、`stop`、`update`、`autostart install/uninstall`。

## 个性化皮肤

公开仓库不会包含任何个人图片。你可以配置自己的本地图片皮肤：

```bash
codex-quota-float skin set /path/to/image.png "My Skin Name"
```

图片会被复制到 `~/.codex-quota-float/skins/`，不会写入仓库。没有配置自定义图片时，
工具会使用 `Classic Glass`。

## 仅支持 macOS

当前版本使用 Swift 和 AppKit（`NSWindow`、`.app` bundle、`launchctl`、`sips`）。
Windows 和 Linux 暂不支持。

## 开发

在仓库里直接运行：

```bash
scripts/codex-quota-float start
scripts/codex-quota-float status
```

构建产物会放在 `.build/` 和 `dist/`。
