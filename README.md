# Dell XPS 15 9560 USB-C Performance Fix for Linux

A systemd-based solution to eliminate CPU throttling on the Dell XPS 15 9560 when charging over USB-C on Linux.

## The Problem

The Dell XPS 15 9560's Embedded Controller (EC) firmware artificially throttles the CPU to ~800 MHz when charging over USB-C, limiting package power to 7W instead of the normal 45W. This results in severely degraded performance—up to 4-5x slower than when using the barrel charger.

This is a hardware limitation in the EC firmware, not a Linux bug. This solution works around it by automatically adjusting RAPL (Running Average Power Limit) settings and CPU governor configuration.

## Quick Start

### Prerequisites

- Dell XPS 15 9560 (tested on Ubuntu 24.04, kernel 6.14)
- Linux kernel 5.x or 6.x with systemd
- Root access
- USB-C charger or dock (60W or higher recommended)

### Installation

1. **Install dependencies:**
   ```bash
   sudo apt update
   sudo apt install -y intel-rapl-msr cpupower linux-tools-generic libsmbios-bin
   ```

2. **Clone this repository:**
   ```bash
   git clone https://github.com/OpenGrid/dell-xps-performance-usbc.git
   cd dell-xps-performance-usbc
   ```

3. **Install the systemd service:**
   ```bash
   sudo cp src/cpu-performance-usbc.service /etc/systemd/system/
   sudo cp src/cpu-performance-usbc.timer /etc/systemd/system/
   sudo cp src/set-cpu-performance.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/set-cpu-performance.sh
   ```

4. **Enable and start the service:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now cpu-performance-usbc.timer
   ```

5. **Verify it's working:**
   ```bash
   sudo systemctl status cpu-performance-usbc.timer
   sudo journalctl -u cpu-performance-usbc.service -n 20
   ```

### Testing Performance

Run a CPU stress test to verify full performance:

```bash
# Install stress-ng if needed
sudo apt install -y stress-ng

# Monitor CPU frequency under load
turbostat --quiet --interval 1 &
stress-ng --cpu 4 --timeout 10s
```

**Expected results:**
- **Before fix:** ~800 MHz average CPU frequency
- **After fix:** ~3400+ MHz average CPU frequency (4-5x improvement)

## How It Works

The solution uses a systemd timer that runs every 5 minutes to:

1. **Detect USB-C charging** (checks power supply status)
2. **Set CPU governor to performance** (instead of powersave)
3. **Raise RAPL power limit** from 7W to 45W
4. **Set thermal profile to performance** (optional, increases fan activity)

The timer re-applies settings periodically because the EC firmware may reset them.

## Uninstallation

To remove the service and revert to default behavior:

```bash
sudo systemctl stop cpu-performance-usbc.timer
sudo systemctl disable cpu-performance-usbc.timer
sudo rm /etc/systemd/system/cpu-performance-usbc.service
sudo rm /etc/systemd/system/cpu-performance-usbc.timer
sudo rm /usr/local/bin/set-cpu-performance.sh
sudo systemctl daemon-reload
```

## Safety & Warranty

**Is this safe?** Yes. The solution uses standard Linux sysfs interfaces for power management (RAPL). No risky MSR register manipulation or undervolting is involved. The CPU still respects thermal limits and will throttle if it reaches 100°C.

**Warranty implications:** Using alternative charging methods (USB-C instead of barrel) may technically deviate from Dell's "intended use," but this software solution doesn't modify hardware or firmware. Standard Linux power management tuning is widely accepted practice.

**Important note on power draw:** When using USB-C charging (typically 60W vs barrel's 130W), the system may slowly drain the battery under very heavy sustained loads if power consumption exceeds supply. This is a hardware limitation, not a bug. Monitor with `cat /sys/class/power_supply/BAT0/status` during peak loads.

## Troubleshooting

### Service runs but CPU still throttles

Check if RAPL limit was applied:
```bash
cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
# Should show: 45000000 (45W)
```

Check if governor is set to performance:
```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
# All should show: performance
```

View service logs for errors:
```bash
sudo journalctl -u cpu-performance-usbc.service -n 50
```

### RAPL limit stays at 7W

Manually test RAPL write:
```bash
echo 45000000 | sudo tee /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
```

If this works but the service doesn't, check script permissions:
```bash
sudo chmod +x /usr/local/bin/set-cpu-performance.sh
sudo systemctl restart cpu-performance-usbc.service
```

### For more help

See the full troubleshooting guide in the article (link TBD) or open an issue on GitHub.

## Compatibility

**Tested on:**
- Dell XPS 15 9560 (i7-7700HQ)
- Ubuntu 24.04 LTS, kernel 6.14
- USB-C docks and chargers (60W negotiated)

**May also work on:**
- Dell XPS 15 9570, 9580
- Dell Precision models with similar USB-C throttling issues
- Other Intel 7th/8th gen Dell laptops with Thunderbolt 3

**Will NOT work on:**
- AMD-based XPS models (RAPL is Intel-specific)
- Non-Dell laptops (different EC firmware behavior)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

Areas for improvement:
- Better USB-C detection logic (currently checks AC online + battery charging)
- Support for kernel 6.11+ platform_profile sysfs interface
- Automatic RAPL limit calibration based on actual charger wattage
- Integration with TLP or other power management tools

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by similar work in the Arch Linux Wiki and various GitHub projects
- Thanks to the Linux kernel power management developers
- Community testing and feedback from XPS 15 9560 users

## Related Resources

- [Arch Linux Wiki: Dell XPS 15 9560](https://wiki.archlinux.org/title/Dell_XPS_15_(9560))
- [Linux Kernel RAPL Documentation](https://www.kernel.org/doc/html/latest/power/powercap/powercap.html)
- Full detailed article with technical deep-dive (link TBD)

---

**Found this helpful?** Star the repo and share with other XPS 15 9560 users struggling with USB-C throttling!

