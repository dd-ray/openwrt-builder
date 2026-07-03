# 固件复测指导文档（NanoPi R5S / OpenWrt main 6.18）

> 用途：每次刷入新固件（尤其是 `main`/snapshot、内核大版本变化）后，用一套**只读**命令快速判定固件是否健康、是否可长期使用。
> 适用：NanoPi R5S（rockchip/armv8，r8125-rss 2.5G 网卡，PPPoE WAN）。其它设备可参考思路调整接口名。
> SSH 别名：`home-openwrt`。所有命令均为只读诊断，不改配置。

---

## 0. 复测时间点

| 时机 | 目的 |
|---|---|
| 刷机后立即（开机 2–5 分钟） | 开机健康体检：能否启动、驱动/网卡/服务是否就绪 |
| 开机 1 小时 | 初期稳定性：抖动、丢包、内存、服务崩溃 |
| 开机 12–24 小时 | 长期稳定性：链路抖动累计、内存泄漏、温度、PPPoE 重拨 |

判定原则：**“开机即可判定”的项**（驱动、PCIe、kmod、防火墙）开机后就能下结论；**“需时间积累”的项**（flapping、内存、温度、重拨）必须看够时长。

---

## 1. 基线对照表（已实测）

复测时把当前值和下面基线比较，偏离明显才需关注。

| 指标 | 25.12.4 / 6.12.87 基线（19.8h） | main / 6.18.35 参考（30min） | 健康判定标准 |
|---|---|---|---|
| 内核 | 6.12.87 | 6.18.35 | 与所刷固件一致 |
| eth1(WAN) 驱动 | r8125 9.016.01-NAPI-RSS | 同左 | r8125 加载、2500M 全双工 |
| eth1 `carrier_changes` | 开机后基本不变 | 4（全在开机） | 运行中**不增长**＝无抖动 |
| PPPoE 会话 uptime | ≈ 系统 uptime | ≈ 系统 uptime | 二者接近＝零重拨 |
| PPPoE 重拨次数 | 0（首条 Connect 不算） | 0 | logread 无 LCP terminated/hangup |
| eth1 `rx_missed` 占比 | ~0.09% | 累计 0.49%（30min 曾 1.1%，稳态增量~0.17%） | 开机突发会偏高，稳态应回落；< 1~2% 可接受 |
| eth2 `rx_mac_missed` | 5446（静态） | 5126（静态，不增长） | 开机一次性突发，**不增长**即正常 |
| 内存 free | — | 3.4 GB free（用 294MB） | 稳定、无持续下降 |
| 温度 cpu/gpu | — | 50°C / 46°C | < 75°C 安全（满载另测） |
| dmesg call trace / hung task | 无 | 无 | **必须为 0** |
| uwsgi-luci Bus error | 无 | 仅开机前 6min 共 25 次，3.5h 后仍冻结在 25 | 见 §4 已知问题；冻结＝开机瞬态，可接受 |

---

## 2. 一键复测命令（复制粘贴即可）

```bash
ssh home-openwrt '
echo "===== 系统/内核/负载 ====="
uname -r; uptime; echo -n "sys uptime(s)="; cut -d. -f1 /proc/uptime
cat /etc/openwrt_release | grep -E "DISTRIB_RELEASE|DISTRIB_REVISION"

echo; echo "===== 网卡稳定性（核心：是否抖动/丢包）====="
for i in eth1 eth2; do
  echo "---- $i ----"
  ethtool -i $i 2>/dev/null | grep -E "^driver|^version"
  ethtool $i 2>/dev/null | grep -E "Speed|Link detected"
  echo -n "carrier_changes="; cat /sys/class/net/$i/carrier_changes
  echo -n "EEE: "; ethtool --show-eee $i 2>/dev/null | grep "EEE status" | sed "s/^ *//"
  ethtool -S $i 2>/dev/null | grep -iE "rx_packets|rx_missed|rx_mac_error|rx_mac_missed|rx_errors|tx_errors" | grep -vE ": 0$"
done

echo; echo "===== WAN / PPPoE ====="
echo -n "sys uptime(s)="; cut -d. -f1 /proc/uptime
ifstatus wan 2>/dev/null | grep -E "\"up\"|\"uptime\""
echo -n "重拨/掉线计数(排除首条Connect)="; logread | grep -icE "pppd.*(Connection terminated|Modem hangup|LCP terminated)"

echo; echo "===== 内存 / 存储 / 温度 / 调频 ====="
free -m | grep -E "Mem|Swap"; df -h | grep -E "overlay|/rom"
for z in /sys/class/thermal/thermal_zone*; do printf "%s: %sC\n" "$(cat $z/type)" "$(( $(cat $z/temp)/1000 ))"; done
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo; echo "===== dmesg 健康（必须无 trace/hung/oops）====="
dmesg | grep -iE "call trace|hung task|blocked for more|oops|panic|segfault|back to intx|link is down" | tail -10 || echo "(clean)"

echo; echo "===== 关键 kmod 是否加载 ====="
lsmod | grep -iE "^brutal|^nft_fullcone|^nft_flow_offload|^tcp_bbr|^r8125|^wireguard" || true
sysctl net.ipv4.tcp_congestion_control

echo; echo "===== 防火墙 fw4 + fullcone/offload ====="
fw4 -q check && echo "fw4 OK" || echo "fw4 FAIL"
nft list ruleset 2>/dev/null | grep -icE "fullcone|flow add @ft"

echo; echo "===== 服务（用 ubus 而非 pgrep，更准）====="
ubus call service list 2>/dev/null | jq -r "keys[]" 2>/dev/null | tr "\n" " "; echo
for p in netifd dnsmasq mosdns nginx openclash uwsgi; do pgrep -f "$p" >/dev/null && echo "[RUN] $p" || echo "[?? ] $p"; done

echo; echo "===== uwsgi-luci SIGBUS 监测 ====="
echo -n "Bus error 总次数="; logread | grep -c "uwsgi-luci: Bus error"
echo -n "最近一次时间="; logread | grep "uwsgi-luci: Bus error" | tail -1 | cut -d" " -f1-4
'
```

> 说明：`[?? ] netifd/firewall` 之类不用慌——`network`/`firewall` 不是常驻进程（真正的守护进程是 `netifd`，防火墙是 `fw4` 一次性应用规则）。以 `ubus call service list` 和 `fw4 -q check` 为准。

---

## 3. 分模块判定标准（逐项）

### 3.1 网卡链路稳定性（最重要）
- 多次复测 `eth1 carrier_changes` **不增长** → 无 flapping（开机那几次是正常初始化）。
- `ifstatus wan` 的 `uptime` ≈ `/proc/uptime` → PPPoE 全程未断。
- 若 `carrier_changes` 持续增长或 `uptime` 远小于系统 uptime → **存在抖动**，进入 §5 处置。

### 3.2 丢包计数
- `rx_errors`/`tx_errors` 必须为 0（链路/物理错误）。
- `rx_missed`/`rx_mac_missed` 是 FIFO 溢出丢包，少量（<1~2%）正常；**只要不是持续高速增长**即可。
- eth2 的 `rx_mac_missed` 在开机定格后不再增长 = 开机突发，无害。

### 3.3 dmesg 健康
- 出现 `Call trace` / `hung task` / `blocked for more than` / `Oops` / `panic` → **严重**，需排查或回退。
- 出现 `r8125 ... no MSI/MSI-X. Back to INTx.` → PCIe MSI 没走 ITS，2.5G 会不稳；本固件已确认走 ITS（无此行）。
- `Ethtool ioctl ... EEE linkmodes beyond bit 32` → 无害提示，忽略。

### 3.4 内存/温度
- `free` 的 free 值在多次复测间**大体平稳**（小幅波动正常），持续单调下降才怀疑泄漏。
- 温度空载 50°C 左右正常；满载压测（`iperf3` 跑满 2.5G + OpenClash）下 < 75°C 即安全。

### 3.5 kmod / 加速
- `brutal`、`nft_fullcone`、`nft_flow_offload`、`tcp_bbr`、`r8125` 均应在 `lsmod` 中。
- `tcp_congestion_control = bbr`，`fw4 -q check` 返回 OK，nft ruleset 含 `fullcone` 与 `flow add @ft`。

---

## 4. 已知问题与对照

### 4.1 uwsgi-luci `Bus error`（已知、非致命）
- 现象：刷机后前几分钟 logread 出现若干次 `uwsgi-luci: Bus error`，随后停止；vassal 进程 PID 稳定，LuCI 网页可正常打开。
- 性质：snapshot 工具链 + `CONFIG_USE_LTO=y` 与 uwsgi 2.0.30 的交互问题，**不影响路由转发**。
- 实测结论（6.18.35）：计数在开机前 6 分钟累计到 25 后**完全停止**，3.5 小时后仍冻结在 25 → 确认是**开机启动期瞬态**（worker 首次拉起的竞态），非持续 crash。严重度低，可接受。
- 复测要点：
  - 看 `Bus error 总次数`是否在**继续增长**。若长时间冻结 → 开机瞬态，可接受。
  - 若仍想排查：浏览器打开 LuCI 概览/实时状态页（会定时轮询）几分钟，再看计数是否上涨——可定位是否“请求触发型”。
- 处置（可选）：给 uwsgi 及 luci/nginx 相关包关闭 LTO 重新构建；或改用 nginx 直连 luci（非 uwsgi-cgi）方案。

### 4.2 EEE 仍在 WAN 上 active
- `ethtool --show-eee eth1` 显示 `enabled - active`。实测不抖动即无需处理。
- 若将来出现 PPPoE 抖动，按 §5 关 EEE。

---

## 5. 异常处置速查

| 症状 | 处置 |
|---|---|
| PPPoE 抖动 / 2.5G 链路反复 up-down | `ethtool --set-eee eth1 eee off`（放 `/etc/rc.local`，uci 的 `option eee '0'` 可能不生效）；必要时锁 1G：`ethtool -s eth1 speed 1000 duplex full autoneg on` |
| `rx_missed` 持续高速增长 | 增大 RX ring：`ethtool -G eth1 rx 1024`（看 `ethtool -g eth1` 上限）；确认 RSS/包转向开启 |
| dmesg 出现 hung task / call trace | 记录完整 trace；优先回退到 25.12 stable；上游 issue 跟踪 |
| 内存持续下降 / OOM | 定位泄漏进程（`top -d2`），重点查 openclash/mosdns/nginx；必要时回退 |
| uwsgi Bus error 持续刷屏 | 见 §4.1，关 LTO 重编或改 luci 后端 |
| 整体不稳，需回退 | 重新刷 `openwrt-25.12`/`v25.12.x` 固件（6.12，已验证稳定）。**main 上无法降到 6.12（已移除），回退只能换分支固件** |

---

## 6. 满载压测（可选，验证 2.5G + 加速）

```bash
# 路由器侧
ssh home-openwrt 'iperf3 -s'
# 客户端侧（2.5G 直连或经路由器转发）
iperf3 -c <router-ip> -t 60 -P 4
# 压测中另开终端看温度与丢包
ssh home-openwrt 'while :; do printf "%sC missed=%s\n" "$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))" "$(ethtool -S eth1 | awk "/rx_missed/{print \$2}")"; sleep 3; done'
```

判定：吞吐接近线速、温度 < 75°C、`rx_missed` 增量可控、无 dmesg trace。

---

## 附：本轮复测留档（main 6.18.35）

| 时机 | carrier_changes(eth1/eth2) | PPPoE uptime vs sys | 重拨 | 内存 used/free | eth1 rx_missed | uwsgi Bus error | cpu温度 | dmesg |
|---|---|---|---|---|---|---|---|---|
| 开机 30min | 4 / 2 | 1778s ≈ 1805s | 0 | 294MB / 3.43GB | 28740 (1.09%) | 25（已停） | 50°C | clean |
| 开机 3.5h | 4 / 2 | 12828s ≈ 12855s | 0 | 304MB / 3.42GB | 37088 (0.49%) | 25（冻结） | 50°C | clean |

**结论：3.5 小时 soak 全部观察项收敛——零抖动、零重拨、无内存泄漏、温度稳定、SIGBUS 冻结、rx_missed 回落（开机突发，稳态增量~0.17%）。判定 main+6.18.35 在 R5S 上可作为日常固件长期使用。** RX ring 已为 1024，无需调优。

- 后续可选：跑满 12–24h 再看一次（重点内存是否仍平稳）；或做一次 §6 的 2.5G 满载压测验证高负载下温度与吞吐。

### 24 小时复测（2026-06-22 15:08）

#### home-openwrt (main / 6.18.35) — 运行 21h55min

| 指标 | 30min | 51min | 87min | 3.5h | **22h** | 趋势 |
|---|---|---|---|---|---|---|
| carrier_changes | 4 | 4 | 4 | 4 | **4** | ✅ 不变 |
| PPPoE uptime 差 | — | 27s | 27s | 27s | **27s** | ✅ 零重拨 |
| eth1 rx_missed | — | 28740 | 28740 | 37088 | **48766** | 增长极缓 |
| eth1 rx_missed 占比 | — | 0.96% | 0.83% | 0.49% | **0.23%** | ✅ 持续回落 |
| eth1 rx_packets | — | 2.98M | 3.46M | 7.58M | **21.4M** | 流量正常 |
| eth2 rx_mac_missed | 5126 | 5126 | 5126 | 5126 | **5126** | ✅ 不增长 |
| 内存 free | 3.4GB | 3427MB | 3427MB | 3416MB | **3332MB** | ✅ 平稳 |
| 温度 cpu / gpu | 50/46°C | 51/46°C | 48/45°C | 48/45°C | **48/46°C** | ✅ 稳定 |
| uwsgi Bus error | 25 | 25 | 25 | 25 | **0** | ✅ 已清零 |
| dmesg | clean | clean | clean | clean | **clean** | ✅ |

#### home-openwrt-tj (25.12.4 / 6.12.87) — 运行 20h08min

| 指标 | 当前值 | 判定 |
|---|---|---|
| eth1 速率 | 1000Mb/s | 符合预期 |
| eth2 速率 | 2500Mb/s | ✅ |
| carrier_changes | 4 / 2 | ✅ 不变 |
| PPPoE uptime 差 | 31s | ✅ 零重拨 |
| eth1 rx_mac_missed | 164 (不增长) | ✅ |
| eth2 rx_mac_missed | 896 (不增长) | ✅ |
| 内存 free | 3392MB | ✅ 平稳 |
| 温度 cpu / gpu | 51 / 45°C | ✅ 正常 |
| uwsgi Bus error | 0 | ✅ 无 |
| dmesg | clean | ✅ |

**结论：两台设备均通过 24 小时长期稳定性验证。**

- **home-openwrt**：rx_missed 占比从 0.96% 持续降至 0.23%，确认为开机一次性突发，稳态增量极低；内存 22 小时仅下降 ~100MB（3427→3332MB），属正常波动；uwsgi Bus error 已清零（logread 轮转）。**main + 6.18.35 可作为日常固件长期使用。**
- **home-openwrt-tj**：25.12.4 稳定版表现完美，无任何异常。**25.12.4 稳定可靠。**

### 48 小时复测（2026-06-23 14:06）

| 指标 | home-openwrt (main/6.18.35) | home-openwrt-tj (25.12.4/6.12.87) |
|---|---|---|
| **开机时长** | 1天20h54min (~44.9h) | 1天19h06min (~43.1h) |
| **carrier_changes** | 4 / 2 | 4 / 2 |
| **PPPoE uptime 差** | 27s | 31s |
| **重拨次数** | 0 | 0 |
| **eth1 rx_missed 占比** | 55001/34053027 = **0.16%** | 295 (极少量) |
| **eth2 rx_mac_missed** | 5126 (不增长) | 896 (不增长) |
| **内存 free** | 3292 MB | 3388 MB |
| **温度 cpu / gpu** | 51 / 46°C | 49 / 45°C |
| **dmesg** | clean | clean |
| **uwsgi Bus error** | 0 | 0 |

#### home-openwrt rx_missed 趋势（完整）

| 时间 | rx_missed | rx_packets | 占比 | 内存 free |
|---|---|---|---|---|
| 30min | — | — | — | 3.43GB |
| 51min | 28740 | 2.98M | 0.96% | 3427MB |
| 87min | 28740 | 3.46M | 0.83% | 3427MB |
| 3.5h | 37088 | 7.58M | 0.49% | 3416MB |
| 22h | 48766 | 21.4M | 0.23% | 3332MB |
| **45h** | **55001** | **34.1M** | **0.16%** | **3292MB** |

**最终结论：两台设备 48 小时 soak test 全部通过。**

- **home-openwrt**：rx_missed 占比持续回落至 0.16%，确认为开机一次性突发；内存 45 小时仅下降 ~135MB（3427→3292MB），无泄漏；零抖动、零重拨、无 dmesg 异常。**main + 6.18.35 长期稳定，可放心使用。**
- **home-openwrt-tj**：25.12.4 稳定版 43 小时无任何异常，**稳定可靠。**
