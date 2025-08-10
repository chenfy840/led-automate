# led-automate
会根据网络连接、磁盘占用率、CPU 温度和系统负载来动态切换灯光颜色，让系统状态一目了然。

# 🌟 LED 状态自动化脚本使用说明

本脚本用于根据系统状态自动控制 RGB LED 灯的颜色，实现可视化的运行监控效果。
已测试网心云OEC（T）

---

## 📦 安装方式

推荐使用一键安装脚本：

```shell
curl -fsSL https://raw.githubusercontent.com/chenfy840/led-automate/main/install-led.sh | sudo bash
```

## 📦 卸载方式

```shell
curl -fsSL https://raw.githubusercontent.com/chenfy840/led-automate/main/uninstall-led.sh | sudo bash
```

## 📦 使用方式

```shell
leda status        # 查看状态
leda set red/green/blue/...      # 设置颜色（若服务在运行会被覆盖）
leda service stop  # 停止服务后再手动设色
leda logs -f       # 查看日志
```
