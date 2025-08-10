#!/bin/bash

echo "🔄 正在卸载 led-automate 系统..."

# 停止并禁用 systemd 服务
systemctl stop led-automate.service
systemctl disable led-automate.service
rm -f /etc/systemd/system/led-automate.service

# 清理配置与脚本
rm -f /etc/led-automate.conf
rm -f /usr/local/bin/led-automate.sh
rm -f /usr/local/bin/leda

# 重新加载 systemd
systemctl daemon-reexec
systemctl daemon-reload

echo "✅ 卸载完成！LED 自动控制组件已移除。"
