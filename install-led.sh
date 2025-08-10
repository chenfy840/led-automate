#!/bin/bash

echo "开发者：@chenfy840"

CONFIG="/etc/led-automate.conf"
BIN_SCRIPT="/usr/local/bin/led-automate.sh"
LEDA_CLI="/usr/local/bin/leda"
SERVICE_FILE="/etc/systemd/system/led-automate.service"

create_config() {
  if [[ ! -f "$CONFIG" ]]; then
    echo "正在创建默认配置: $CONFIG"
    cat <<EOF > "$CONFIG"
LED_PATH="auto"
DISK_THRESHOLD=85
TEMP_THRESHOLD=75
LOAD_THRESHOLD=80
BOOT_DELAY=300
PING_ADDR="223.5.5.5"
EOF
  else
    echo "检测到已有配置: $CONFIG"
  fi
}

auto_detect_led_path() {
  echo "正在自动探测 LED 通道路径..."

  declare -A LEDS
  for entry in /sys/class/leds/*; do
    name=$(basename "$entry")
    if [[ "$name" == *red* ]]; then
      LEDS[red]="$entry/brightness"
    elif [[ "$name" == *green* ]]; then
      LEDS[green]="$entry/brightness"
    elif [[ "$name" == *blue* ]]; then
      LEDS[blue]="$entry/brightness"
    fi
  done

  if [[ -n "${LEDS[red]}" && -n "${LEDS[green]}" && -n "${LEDS[blue]}" ]]; then
    LED_PATH="${LEDS[red]},${LEDS[green]},${LEDS[blue]}"
    sed -i "s|^LED_PATH=.*|LED_PATH=\"$LED_PATH\"|" "$CONFIG"
    echo "✅ 自动设置 LED_PATH: $LED_PATH"
  else
    echo "⚠️ 未找到完整的 RGB LED 通道。请手动设置 LED_PATH。"
  fi
}

install_script() {
  echo "从 GitHub 下载 LED 脚本..."
  curl -fsSL https://raw.githubusercontent.com/chenfy840/led-automate/main/led-automate.sh -o "$BIN_SCRIPT"
  chmod +x "$BIN_SCRIPT"
}

install_service() {
  echo "已写入 systemd 服务: $SERVICE_FILE"
  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=LED 自动状态指示器
After=network.target

[Service]
ExecStart=$BIN_SCRIPT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable --now led-automate.service
}

install_leda_cli() {
  echo "已安装命令助手: $LEDA_CLI"
  cat <<'EOF' > "$LEDA_CLI"
#!/bin/bash

CONFIG="/etc/led-automate.conf"
source "$CONFIG"

get_rgb_by_name() {
  case "$1" in
    red) echo "1 0 0" ;;
    green) echo "0 1 0" ;;
    blue) echo "0 0 1" ;;
    yellow) echo "1 1 0" ;;
    pink) echo "1 0 1" ;;
    cyan) echo "0 1 1" ;;
    white) echo "1 1 1" ;;
    off) echo "0 0 0" ;;
    *) echo "0 0 0" ;;
  esac
}

case "$1" in
  status)
    echo "Service: $(systemctl is-active led-automate.service) / $(systemctl is-enabled led-automate.service)"
    echo "LED Path: $LED_PATH"
    echo "Thresholds -> DISK>=${DISK_THRESHOLD}% TEMP>=${TEMP_THRESHOLD}°C LOAD>=${LOAD_THRESHOLD}% BOOT_DELAY=${BOOT_DELAY}s"
    ;;
  set)
    shift
    if [[ "$1" == "rgb" ]]; then
      R="$2"; G="$3"; B="$4"
    else
      read R G B <<< "$(get_rgb_by_name "$1")"
    fi
    IFS=',' read -r RED GREEN BLUE <<< "$LED_PATH"
    echo "$R" > "$RED"
    echo "$G" > "$GREEN"
    echo "$B" > "$BLUE"
    ;;
  service)
    systemctl "$2" led-automate.service
    ;;
  logs)
    journalctl -u led-automate.service "${@:2}"
    ;;
  edit)
    ${EDITOR:-nano} "$CONFIG"
    ;;
  *)
    echo "用法: leda status | set <color|rgb R G B> | service <restart|stop|start> | logs [-f] | edit"
    ;;
esac
EOF
  chmod +x "$LEDA_CLI"
}

# 安装流程执行
create_config
auto_detect_led_path
install_script
install_service
install_leda_cli

echo "✅ 安装完成！你可以使用以下命令："
echo "  leda status        # 查看状态"
echo "  leda set pink      # 设置颜色（若服务在运行会被覆盖）"
echo "  leda service stop  # 停止服务后再手动设色"
echo "  leda logs -f       # 查看日志"
