#!/bin/bash

CONFIG="/etc/led-automate.conf"

# 读取配置文件中的通道路径
load_led_paths() {
  source "$CONFIG"
  IFS=',' read -r RED_PATH GREEN_PATH BLUE_PATH <<< "$LED_PATH"
}

# 设置灯光颜色（支持三通道）
set_rgb() {
  echo "$1" > "$RED_PATH" 2>/dev/null || echo "❌ RED 写入失败: $RED_PATH"
  echo "$2" > "$GREEN_PATH" 2>/dev/null || echo "❌ GREEN 写入失败: $GREEN_PATH"
  echo "$3" > "$BLUE_PATH" 2>/dev/null || echo "❌ BLUE 写入失败: $BLUE_PATH"
}

# 快捷颜色函数
show_blue()    { set_rgb 0 0 1; }
show_green()   { set_rgb 0 1 0; }
show_red()     { set_rgb 1 0 0; }
show_cyan()    { set_rgb 0 1 1; }
show_yellow()  { set_rgb 1 1 0; }
show_pink()    { set_rgb 1 0 1; }
show_white()   { set_rgb 1 1 1; }
show_off()     { set_rgb 0 0 0; }

# 网络检测
net_ok() {
  ping -c1 -W1 "$PING_ADDR" &>/dev/null
  return $?
}
blink_netdown_once() {
  show_white; sleep 0.3
  show_off; sleep 0.3
  show_green; sleep 0.3
  show_off; sleep 0.3
}

# 系统指标
get_cpu_temp()   { cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print int($1/1000)}'; }
get_disk_usage() { df -h / | awk '/\// {gsub("%",""); print $5}'; }
cpu_usage_pct()  { top -bn1 | awk '/Cpu/{print 100 - $8}' | cut -d. -f1; }
mem_usage_pct()  { free | awk '/Mem/{print int($3/$2 * 100)}'; }

# 初始化变量（可在配置文件中定义）
BOOT_TS=$(date +%s)
load_led_paths

THRESHOLD=${LOAD_THRESHOLD:-80}
DISK_THRESHOLD=${DISK_THRESHOLD:-85}
TEMP_THRESHOLD=${TEMP_THRESHOLD:-75}
BOOT_DELAY=${BOOT_DELAY:-300}
PING_ADDR=${PING_ADDR:-223.5.5.5}

# 启动状态
show_cyan

# 主循环
while true; do
  # 网络异常
  if ! net_ok; then
    blink_netdown_once
    continue
  fi

  DISK=$(get_disk_usage)
  TEMP=$(get_cpu_temp)

  if (( DISK >= DISK_THRESHOLD || TEMP >= TEMP_THRESHOLD )); then
    show_pink
    sleep 2
    continue
  fi

  NOW=$(date +%s)
  if (( NOW - BOOT_TS >= BOOT_DELAY )); then
    CPU=$(cpu_usage_pct)
    MEM=$(mem_usage_pct)
    if (( CPU >= THRESHOLD || MEM >= THRESHOLD )); then
      show_yellow
    else
      show_cyan
    fi
  else
    show_cyan
  fi

  sleep 2
done
