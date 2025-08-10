#!/usr/bin/env bash
set -euo pipefail

# ========== 可调参数 ==========
DEV_NAME="${DEV_NAME:-@chenfy840}"            # 开发者名字（可用环境变量覆盖）
LED_SCRIPT_URL="${LED_SCRIPT_URL:-https://raw.githubusercontent.com/chenfy840/led-automate/main/led-automate.sh}"    # GitHub Raw 脚本地址，可用 -u 传入
SERVICE_NAME="led-automate.service"
SCRIPT_PATH="/usr/local/bin/led-automate.sh"
LEDA_PATH="/usr/local/bin/leda"
CONF_PATH="/etc/led-automate.conf"
PING_ADDR_DEFAULT="223.5.5.5"
YES=0
# =============================

usage() {
  cat <<EOF
用法: sudo bash $(basename "$0") [选项]
  -y                 自动确认安装（无人值守）
  -u <raw_url>       指定 LED 脚本的 GitHub Raw 地址
  -d <dev_name>      指定开发者名字（默认: ${DEV_NAME})
示例:
  sudo bash $(basename "$0")
  sudo bash $(basename "$0") -y -u https://raw.githubusercontent.com/<user>/<repo>/main/led-automate.sh
EOF
}

# 解析参数
while getopts ":yu:d:h" opt; do
  case $opt in
    y) YES=1 ;;
    u) LED_SCRIPT_URL="$OPTARG" ;;
    d) DEV_NAME="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "未知参数: -$OPTARG"; usage; exit 2 ;;
    :) echo "参数 -$OPTARG 需要值"; usage; exit 2 ;;
  esac
done

# 权限检查
if [[ $EUID -ne 0 ]]; then
  echo "请用 sudo 或 root 运行此脚本。"
  exit 1
fi

echo "开发者：${DEV_NAME}"
if [[ $YES -ne 1 ]]; then
  read -rp "是否自动下载安装 LED 状态脚本并启用服务？[Y/n] " ans
  ans="${ans:-Y}"
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "已取消安装。"
    exit 0
  fi
fi

# 依赖检查与安装
need_cmd() { command -v "$1" &>/dev/null; }
try_install() {
  if need_cmd apt; then
    apt update -y && apt install -y "$@"
  elif need_cmd dnf; then
    dnf install -y "$@"
  elif need_cmd yum; then
    yum install -y "$@"
  elif need_cmd pacman; then
    pacman -Sy --noconfirm "$@"
  else
    echo "请手动安装依赖: $*"; exit 1
  fi
}

need_cmd curl || try_install curl
need_cmd systemctl || { echo "此系统不支持 systemd（缺少 systemctl）。"; exit 1; }

# 读取/确认 GitHub Raw URL
if [[ -z "${LED_SCRIPT_URL}" ]]; then
  read -rp "请输入 LED 脚本的 GitHub Raw 地址（例如 https://raw.githubusercontent.com/<user>/<repo>/main/led-automate.sh）: " LED_SCRIPT_URL
fi
if [[ -z "${LED_SCRIPT_URL}" ]]; then
  echo "未提供 GitHub Raw 地址，无法继续。"
  exit 2
fi

# 创建配置文件（若不存在）
if [[ ! -f "${CONF_PATH}" ]]; then
  cat >/etc/led-automate.conf <<'CONF'
# LED Automate 配置文件
# LED_PATH: RGB 三色一体灯的 sysfs 路径（写入“R G B”的三元组）
LED_PATH="/sys/class/leds/rgb_led/color"

# 阈值设置
DISK_THRESHOLD=85     # 根分区占用 >= 85% 触发
TEMP_THRESHOLD=75     # CPU 温度 >= 75℃ 触发
LOAD_THRESHOLD=80     # CPU 或内存 >= 80% 触发
BOOT_DELAY=300        # 开机延迟秒数（排除短时波动）

# 网络检测地址（国内常用 DNS Anycast）
PING_ADDR="223.5.5.5"
CONF
  echo "已创建默认配置: ${CONF_PATH}"
else
  echo "检测到已有配置: ${CONF_PATH}"
fi

# 下载 LED 脚本
echo "从 GitHub 下载 LED 脚本..."
tmpfile="$(mktemp)"
if ! curl -fsSL "${LED_SCRIPT_URL}" -o "${tmpfile}"; then
  echo "下载失败：${LED_SCRIPT_URL}"
  exit 3
fi

# 安装脚本
install -m 0755 "${tmpfile}" "${SCRIPT_PATH}"
rm -f "${tmpfile}"
echo "已安装脚本到 ${SCRIPT_PATH}"

# 写入/覆盖 systemd 服务
cat >"/etc/systemd/system/${SERVICE_NAME}" <<UNIT
[Unit]
Description=LED automate service (network/disk/temp/load -> RGB LED)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
EnvironmentFile=-${CONF_PATH}
ExecStart=${SCRIPT_PATH}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
echo "已写入 systemd 服务: /etc/systemd/system/${SERVICE_NAME}"

# 安装 leda 命令行助手
cat >"${LEDA_PATH}" <<'LEDA'
#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/led-automate.conf"
SERVICE="led-automate.service"

# 加载配置
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  . "$CONF"
fi
LED_PATH="${LED_PATH:-/sys/class/leds/rgb_led/color}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
TEMP_THRESHOLD="${TEMP_THRESHOLD:-75}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-80}"
BOOT_DELAY="${BOOT_DELAY:-300}"
PING_ADDR="${PING_ADDR:-223.5.5.5}"

need_root() { [[ $EUID -eq 0 ]] || { echo "需要 root: 请使用 sudo $0 $*"; exit 1; }; }

set_rgb() { echo "$1 $2 $3" | sudo tee "$LED_PATH" >/dev/null; }
get_rgb() { [[ -r "$LED_PATH" ]] && cat "$LED_PATH" || echo "N/A"; }

show() {
  case "${1:-}" in
    red)    set_rgb 1 0 0 ;;
    green)  set_rgb 0 1 0 ;;
    blue)   set_rgb 0 0 1 ;;
    yellow) set_rgb 1 1 0 ;;
    cyan)   set_rgb 0 1 1 ;;
    pink|magenta)  set_rgb 1 0 1 ;;
    white)  set_rgb 1 1 1 ;;
    off|black) set_rgb 0 0 0 ;;
    rgb)    set_rgb "${2:-0}" "${3:-0}" "${4:-0}" ;;
    *) echo "用法: leda set {red|green|blue|yellow|cyan|pink|white|off|rgb R G B}"; exit 2;;
  esac
}

cpu_temp_c() {
  local t
  t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
  echo $((t/1000))
}
cpu_pct() {
  top -bn1 | awk '/Cpu/ {print 100 - $8}' | cut -d. -f1
}
mem_pct() {
  free | awk '/Mem/ {print int($3/$2*100)}'
}
disk_pct() {
  df -h / | awk '/\// {gsub("%",""); print $5}'
}
net_ok() {
  ping -c1 -W1 "$PING_ADDR" &>/dev/null
}

service_cmd() {
  case "${1:-}" in
    start|stop|restart|status) sudo systemctl "$1" "$SERVICE" ;;
    enable|disable)            sudo systemctl "$1" "$SERVICE" ;;
    *) echo "用法: leda service {start|stop|restart|status|enable|disable}"; exit 2;;
  esac
}

status() {
  echo "Service: $(systemctl is-active "$SERVICE") / $(systemctl is-enabled "$SERVICE" 2>/dev/null || true)"
  echo "LED Path: $LED_PATH"
  echo "Current RGB: $(get_rgb)"
  echo "CPU: $(cpu_pct)%  MEM: $(mem_pct)%  TEMP: $(cpu_temp_c)°C  DISK: $(disk_pct)%"
  if net_ok; then echo "Network: OK ($PING_ADDR)"; else echo "Network: DOWN ($PING_ADDR)"; fi
  echo "Thresholds -> DISK>=$DISK_THRESHOLD% TEMP>=$TEMP_THRESHOLD°C LOAD>=$LOAD_THRESHOLD% BOOT_DELAY=${BOOT_DELAY}s"
}

logs() {
  if [[ "${1:-}" == "-f" ]]; then
    sudo journalctl -u "$SERVICE" -f
  else
    sudo journalctl -u "$SERVICE" -n 100 --no-pager
  fi
}

edit_conf() {
  need_root edit
  ${EDITOR:-nano} "$CONF"
}

help() {
  cat <<HLP
leda - LED 管理助手
用法:
  leda status                 查看服务与系统/LED 状态
  leda get                    读取当前 RGB 值
  leda set <color>            设置颜色: red|green|blue|yellow|cyan|pink|white|off
  leda set rgb R G B          直接设置 RGB（0 或 1）
  leda service <cmd>          管理服务: start|stop|restart|status|enable|disable
  leda logs [-f]              查看日志（-f 跟随）
  leda edit                   编辑配置文件 (/etc/led-automate.conf)
说明:
  若服务正在运行，手动设色可能很快被自动逻辑覆盖。
  如需临时手动控制，可先执行: leda service stop
HLP
}

case "${1:-}" in
  status) status ;;
  get)    get_rgb ;;
  set)    shift; show "$@" ;;
  service) shift; service_cmd "$@" ;;
  logs)   shift || true; logs "${1:-}" ;;
  edit)   edit_conf ;;
  -h|--help|help|"") help ;;
  *) echo "未知命令: $1"; help; exit 2 ;;
esac
LEDA
chmod +x "${LEDA_PATH}"
echo "已安装命令助手: ${LEDA_PATH}"

# 预检测 LED 路径是否存在
# shellcheck disable=SC1091
. "${CONF_PATH}"
LED_PATH="${LED_PATH:-/sys/class/leds/rgb_led/color}"
if [[ ! -e "${LED_PATH}" ]]; then
  echo "注意：未发现 LED 路径 ${LED_PATH}。"
  echo "你可以稍后运行: sudo leda edit    来修正 LED_PATH。"
fi

# 启用并启动服务
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
sleep 0.5
systemctl is-active "${SERVICE_NAME}" >/dev/null && echo "服务已启动: ${SERVICE_NAME}" || echo "警告：服务未处于 active，请用 'leda logs' 查看日志。"

echo "安装完成！你可以使用以下命令："
echo "  leda status        # 查看状态"
echo "  leda set pink      # 手动改为粉色（若服务在运行，可能会被覆盖）"
echo "  leda service stop  # 停止服务后再手动设色"
echo "  leda logs -f       # 跟踪服务日志"
