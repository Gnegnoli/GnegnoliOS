"""Read-only static/host info for the dashboard header and overview cards.

Fast, one-shot reads (files or quick subprocess calls) — not the long-running
actions in commands.py, so plain blocking calls are fine here. Every getter
falls back to "N/A" on failure since this is reading arbitrary host state
(missing files, absent tools, sandboxed containers).
"""
import getpass
import glob
import os
import platform
import subprocess
import time

import psutil


def _quick(argv):
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=2)
        return out.stdout.strip()
    except Exception:
        return ""


def username():
    return getpass.getuser().capitalize()


def os_pretty_name():
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "Linux"


def kernel_version():
    return platform.release() or "N/A"


def uptime_str():
    seconds = time.time() - psutil.boot_time()
    hours, rem = divmod(int(seconds), 3600)
    minutes = rem // 60
    return f"{hours}h {minutes}m"


def load_avg():
    try:
        return f"{os.getloadavg()[0]:.2f}"
    except (OSError, AttributeError):
        return "N/A"


def cpu_model():
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "N/A"


def gpu_model():
    out = _quick(["lspci"])
    for line in out.splitlines():
        if "VGA" in line or "3D controller" in line:
            return line.split(": ", 1)[-1].strip()
    return "N/A"


def motherboard():
    try:
        base = "/sys/devices/virtual/dmi/id"
        with open(f"{base}/board_vendor") as f:
            vendor = f.read().strip()
        with open(f"{base}/board_name") as f:
            name = f.read().strip()
        return f"{vendor} {name}".strip() or "N/A"
    except OSError:
        return "N/A"


def memory_total_gib():
    return psutil.virtual_memory().total / (1024 ** 3)


def is_active(service):
    return _quick(["systemctl", "is-active", service]) == "active"


def package_installed(name):
    try:
        return subprocess.run(
            ["pacman", "-Qi", name], capture_output=True, timeout=2
        ).returncode == 0
    except Exception:
        return False


def has_wifi():
    return bool(glob.glob("/sys/class/net/*/wireless"))


def proton_ge_installed():
    return bool(glob.glob(os.path.expanduser("~/.steam/root/compatibilitytools.d/*")))
