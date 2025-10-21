#!/bin/bash
# Set CPU to performance mode and raise power limits for USB-C dock usage

LOG_FILE="/var/log/cpu-performance-usbc.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Detect USB-C charging (conditional activation)
if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null)" = "1" ] && [ "$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)" = "Charging" ]; then
    log_msg "USB-C charging detected - applying performance settings"

    # Set all CPUs to performance governor
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || log_msg "WARNING: Failed to set governor"

    # Raise Intel RAPL power limit from ~7W to 45W
    if [ -f /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw ]; then
        echo 45000000 > /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || log_msg "WARNING: Failed to set RAPL"
        log_msg "RAPL PL1 limit set to 45W"
    else
        log_msg "WARNING: RAPL interface not found"
    fi

    # (Optional) Set thermal profile to performance
    if command -v smbios-thermal-ctl &> /dev/null; then
        smbios-thermal-ctl --set-thermal-mode performance 2>/dev/null || log_msg "WARNING: Failed to set thermal mode"
        log_msg "Thermal profile set to performance"
    fi

    log_msg "CPU performance settings applied"
else
    log_msg "Not on USB-C charging - skipping"
fi

exit 0
