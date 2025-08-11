# led-automate
会根据网络连接、磁盘占用率、CPU 温度和系统负载来动态切换灯光颜色，让系统状态一目了然。

# 🌟 LED 状态自动化脚本使用说明

本脚本用于根据系统状态自动控制 RGB LED 灯的颜色，实现可视化的运行监控效果。

已测试网心云OEC（T）

其他设备未做测试，但是按道理来说支持RGB三色灯设备支持使用自动化脚本

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
命令	         说明
leda status	查看当前系统状态与各项指标阈值
leda get	查看当前 LED 的颜色值
leda set cyan	手动设置为指定颜色（支持常用颜色英文名）
leda set rgb R G B	按 RGB 数值直接设定颜色（如 1 0 0）
leda service restart	重启 LED 自动控制服务
leda logs [-f]	查看日志信息，添加 -f 实时跟踪
leda edit	打开配置文件进行编辑
```
⚠️ 若服务运行中，手动设定的颜色可能被覆盖。可执行 leda service stop 暂停自动服务。


## 🌟  功能介绍

正常	系统运行正常	青色 (绿+蓝)

高负载	CPU 或内存占用 > 80%	黄色 (红+绿)

磁盘或温度异常	磁盘使用 > 85% 或 CPU温度 > 75°C	粉色 (红+蓝)

网络异常	无法连接外部地址	白 → 绿 闪烁
