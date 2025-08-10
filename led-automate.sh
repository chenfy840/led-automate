#!/bin/bash

# 灯光颜色快捷方式定义
set_rgb() { echo "$1 $2 $3" > /sys/class/leds/rgb_led/color; }
show_blue()    { set_rgb 0 0 1; }
show_green()   { set_rgb 0 1 0; }
show_red()     { set_rgb 1 0 0; }
show_cyan()    { set_rgb 0 1 1; }  # 蓝 + 绿
show_yellow()  { set_rgb 1 1 0; }  # 红 + 绿
show_pink()    { set_rgb 1 0 1; }  # 红 + 蓝
show_white()   { set_rgb 1 1 1; }
show_off()     { set_rgb 0 0 0; }

# 网络检测：尝试 ping 外部地址
net_ok() {
  ping -c 1 -W 1 223.5.5.5 &> /dev/null
  return $?
}
blink_netdown_once() {
  show_white; sleep 0.3
  show_off; sleep 0.3
  show_green; sleep 0.3
  show_off; sleep 0.3
}

# CPU 温度读取（单位：℃）
get_cpu_temp() {
  local temp
  temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
  echo $((temp / 1000))
}

# 根分区磁盘占用率（单位：%）
get_disk_usage() {
  df -h / | awk '/\// {gsub("%",""); print $5}'
}

# 系统负载（CPU和内存占用率）
cpu_usage_pct() {
  top -bn1 | awk '/Cpu/ {print 100 - $8}' | cut -d. -f1
}
mem_usage_pct() {
  free | awk '/Mem/ {print int($3/$2 * 100)}'
}

# 参数定义
BOOT_TS=$(date +%s)
THRESHOLD=80        # 高负载阈值 (%)
DISK_THRESHOLD=85   # 磁盘占用阈值 (%)
TEMP_THRESHOLD=75   # 温度异常阈值 (℃)
BOOT_DELAY=300      # 开机等待时间 (秒)

# 初始化显示青色（系统正常）
show_cyan

# 主循环
while true; do
  # 网络异常优先处理
  if ! net_ok; then
    blink_netdown_once
    continue
  fi

  # 磁盘占用或温度异常
  DISK=$(get_disk_usage)
  TEMP=$(get_cpu_temp)
  if (( DISK >= DISK_THRESHOLD || TEMP >= TEMP_THRESHOLD )); then
    show_pink
    sleep 2
    continue
  fi

  # 高负载判断（排除刚开机阶段）
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
