#!/bin/bash
# Set CPU to performance mode and raise power limits for USB-C dock usage
# Compatible with Ubuntu 24.04, Kernel 6.14+

LOG_FILE="/var/log/cpu-performance-usbc.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Detect AC power (works for both USB-C and barrel charger)
# We check if AC is online, regardless of battery charging status
# This handles cases where battery is full ("Not charging") or actively charging ("Charging")
AC_ONLINE=$(cat /sys/class/power_supply/AC/online 2>/dev/null)

if [ "$AC_ONLINE" != "1" ]; then
    log_msg "Running on battery - skipping performance settings"
    exit 0
fi

log_msg "AC power detected - applying performance settings"

# Set all CPUs to performance governor
SUCCESS_COUNT=0
FAIL_COUNT=0
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        if echo "performance" > "$cpu" 2>/dev/null; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
done

if [ $SUCCESS_COUNT -gt 0 ]; then
    log_msg "Set governor to performance on $SUCCESS_COUNT CPUs"
fi
if [ $FAIL_COUNT -gt 0 ]; then
    log_msg "WARNING: Failed to set governor on $FAIL_COUNT CPUs"
fi

# Raise Intel RAPL power limit from ~7W to 45W
RAPL_FILE="/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw"
if [ -w "$RAPL_FILE" ]; then
    if echo 45000000 > "$RAPL_FILE" 2>/dev/null; then
        log_msg "RAPL PL1 limit set to 45W"
    else
        log_msg "ERROR: Failed to write RAPL limit"
    fi
else
    log_msg "WARNING: RAPL sysfs file not writable"
fi

# Set thermal profile to performance using modern platform_profile interface
# Available on kernel 6.11+ (replaces smbios-thermal-ctl)
PLATFORM_PROFILE="/sys/firmware/acpi/platform_profile"
if [ -w "$PLATFORM_PROFILE" ]; then
    if echo "performance" > "$PLATFORM_PROFILE" 2>/dev/null; then
        log_msg "Platform profile set to performance"
    else
        log_msg "WARNING: Failed to set platform profile"
    fi
elif command -v smbios-thermal-ctl &> /dev/null; then
    # Fallback for older systems with libsmbios
    if smbios-thermal-ctl --set-thermal-mode performance 2>/dev/null; then
        log_msg "Thermal profile set to performance (via smbios-thermal-ctl)"
    else
        log_msg "WARNING: Failed to set thermal mode via smbios-thermal-ctl"
    fi
else
    log_msg "INFO: No thermal profile control available"
fi

log_msg "CPU performance settings applied successfully"
exit 0
