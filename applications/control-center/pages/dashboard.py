"""Dashboard page: mirrors the mockup's card grid, live CPU/RAM/disk via psutil."""
import psutil
from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import (
    QGridLayout, QHBoxLayout, QLabel, QProgressBar, QVBoxLayout, QWidget
)

import sysinfo
from commands import run_or_notify, which
from widgets import Card, Gauge, Sparkline, action_grid, info_row, status_row

REFRESH_MS = 1500

DISKS = [
    ("/ (Root)", "/", "Btrfs"),
    ("/home", "/home", "Btrfs"),
    ("Games", "/games", "Btrfs"),
]

GOVERNORS = [
    ("Power Saver", "powersave"),
    ("Balanced", "ondemand"),
    ("Performance", "performance"),
    ("Turbo", "performance"),
]


def _labeled_bar(card, name, extra=""):
    row = QHBoxLayout()
    row.addWidget(QLabel(name))
    row.addStretch()
    value_label = QLabel("0%")
    row.addWidget(value_label)
    card.layout.addLayout(row)
    bar = QProgressBar()
    bar.setRange(0, 100)
    bar.setTextVisible(False)
    card.add(bar)
    return bar, value_label


class DashboardPage(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._procs = []  # keeps QProcess instances alive while running
        outer = QVBoxLayout(self)
        outer.setContentsMargins(24, 24, 24, 24)
        outer.setSpacing(16)

        outer.addLayout(self._build_header())

        row1 = QGridLayout()
        row1.setSpacing(16)
        outer.addLayout(row1)
        row1.addWidget(self._build_overview_card(), 0, 0)
        row1.addWidget(self._build_performance_card(), 0, 1)
        row1.addWidget(self._build_updates_card(), 0, 2)
        row1.addWidget(self._build_drivers_card(), 0, 3)

        row2 = QGridLayout()
        row2.setSpacing(16)
        outer.addLayout(row2)
        row2.addWidget(self._build_gaming_card(), 0, 0)
        row2.addWidget(self._build_containers_card(), 0, 1)
        row2.addWidget(self._build_software_card(), 0, 2)
        row2.addWidget(self._build_tools_card(), 0, 3)

        row3 = QGridLayout()
        row3.setSpacing(16)
        outer.addLayout(row3)
        row3.addWidget(self._build_storage_card(), 0, 0)
        row3.addWidget(self._build_quick_actions_card(), 0, 1)
        row3.addWidget(self._build_status_card(), 0, 2)
        row3.addWidget(self._build_branding_card(), 0, 3)

        outer.addStretch()

        self._prev_disk_bytes = _disk_bytes()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(REFRESH_MS)
        self.refresh()

    # -- header ------------------------------------------------------------

    def _build_header(self):
        row = QHBoxLayout()
        greeting = QVBoxLayout()
        title = QLabel(f"Welcome back, <span style='color:#ff3b30;'>{sysinfo.username()}</span>")
        title.setStyleSheet("font-size: 20px; font-weight: 700;")
        subtitle = QLabel("System is running smoothly. Everything is under control.")
        subtitle.setStyleSheet("color: #8a8a8a;")
        greeting.addWidget(title)
        greeting.addWidget(subtitle)
        row.addLayout(greeting)
        row.addStretch()

        strip = Card(None)
        strip_row = QHBoxLayout()
        for label, value in [
            ("Operating System", sysinfo.os_pretty_name()),
            ("Kernel", sysinfo.kernel_version()),
            ("Uptime", sysinfo.uptime_str()),
            ("System Load", sysinfo.load_avg()),
        ]:
            col = QVBoxLayout()
            l = QLabel(label)
            l.setStyleSheet("color: #8a8a8a; font-size: 11px;")
            v = QLabel(value)
            v.setStyleSheet("font-weight: 700;")
            col.addWidget(l)
            col.addWidget(v)
            strip_row.addLayout(col)
        strip.layout.addLayout(strip_row)
        row.addWidget(strip)
        return row

    # -- row 1 ---------------------------------------------------------------

    def _build_overview_card(self):
        card = Card("System Overview", "monitor")
        card.layout.addLayout(info_row("CPU", sysinfo.cpu_model()))
        card.layout.addLayout(info_row("GPU", sysinfo.gpu_model()))
        card.layout.addLayout(info_row("Memory", f"{sysinfo.memory_total_gib():.1f} GiB"))
        card.layout.addLayout(info_row("Motherboard", sysinfo.motherboard()))
        return card

    def _build_performance_card(self):
        card = Card("Performance Mode", "sliders-horizontal")
        self.gauge = Gauge(50, "Balanced", "Optimal balance between\nperformance and efficiency")
        card.add(self.gauge)
        actions = [(name, self._make_governor_slot(gov)) for name, gov in GOVERNORS]
        card.layout.addLayout(action_grid(actions, columns=4))
        return card

    def _make_governor_slot(self, governor):
        def slot(checked=False, g=governor):
            run_or_notify(self, (["cpupower", "frequency-set", "-g", g], True))
        return slot

    def _build_updates_card(self):
        card = Card("Updates", "refresh-cw")
        pacman_n = len(_quick_lines(["pacman", "-Qu"]))
        aur_helper = which("yay", "paru")
        aur_n = len(_quick_lines([aur_helper, "-Qua"])) if aur_helper else 0
        flatpak_n = len(_quick_lines(["flatpak", "remote-ls", "--updates", "flathub"])) if which("flatpak") else 0
        card.layout.addLayout(info_row("System Updates", str(pacman_n)))
        card.layout.addLayout(info_row("AUR Updates", str(aur_n)))
        card.layout.addLayout(info_row("Flatpak Updates", str(flatpak_n)))
        return card

    def _build_drivers_card(self):
        card = Card("Drivers", "plug")
        card.layout.addLayout(status_row("NVIDIA", "driver", ok=bool(which("nvidia-smi"))))
        card.layout.addLayout(status_row("AMD / Mesa", "driver", ok=sysinfo.package_installed("mesa")))
        card.layout.addLayout(status_row("Wi-Fi", "driver", ok=sysinfo.has_wifi()))
        return card

    # -- row 2 -----------------------------------------------------------------

    def _build_gaming_card(self):
        card = Card("Gaming Hub", "gamepad-2")
        card.layout.addLayout(status_row("Proton-GE", "installed", ok=sysinfo.proton_ge_installed()))
        card.layout.addLayout(status_row("Wine", "installed", ok=bool(which("wine"))))
        card.layout.addLayout(status_row("Lutris", "installed", ok=bool(which("lutris"))))
        return card

    def _build_containers_card(self):
        card = Card("Containers & Virtualization", "boxes")
        card.layout.addLayout(status_row("Docker", "running" if sysinfo.is_active("docker") else "stopped",
                                          ok=sysinfo.is_active("docker")))
        card.layout.addLayout(status_row("Podman", "installed", ok=bool(which("podman"))))
        return card

    def _build_software_card(self):
        card = Card("Software Center", "package-2")
        installed = _quick_lines(["pacman", "-Q"])
        card.layout.addLayout(info_row("Installed Packages", str(len(installed))))
        card.layout.addLayout(info_row("Flatpak", "installed" if which("flatpak") else "not installed"))
        card.layout.addLayout(info_row("Snap", "installed" if which("snap") else "not installed"))
        return card

    def _build_tools_card(self):
        card = Card("System Tools", "folder-cog")
        card.layout.addLayout(action_grid([
            ("Backup Manager", self._act(lambda: (["snapper", "list"], False))),
            ("System Monitor", self._act(lambda: ([which("btop", "htop") or "btop"], False))),
            ("Disk Utility", self._act(lambda: (["gnome-disks"], False))),
        ], columns=1))
        return card

    # -- row 3 ----------------------------------------------------------------

    def _build_storage_card(self):
        card = Card("Storage", "hard-drive-download")
        self.disk_bars = []
        for name, path, fstype in DISKS:
            bar, value_label = _labeled_bar(card, f"{name}  ({fstype})")
            self.disk_bars.append((path, bar, value_label))
        return card

    def _build_quick_actions_card(self):
        card = Card("Quick Actions", "zap")
        card.layout.addLayout(action_grid([
            ("Install Packages", self._act(lambda: None)),  # needs a package picker UI
            ("Remove Packages", self._act(lambda: None)),  # needs a package picker UI
            ("Add Repo", self._act(lambda: None)),  # needs a repo-entry dialog
            ("System Cleanup", self._act(lambda: (["journalctl", "--vacuum-time=7d"], True))),
            ("Optimize System", self._act(lambda: (["pacman", "-Sc", "--noconfirm"], True))),
            ("Repair System", self._act(lambda: (["pacman", "-Qkk"], False))),
        ], columns=2))
        return card

    def _act(self, build_result):
        return lambda checked=False: run_or_notify(self, build_result())

    def _build_status_card(self):
        card = Card("System Status", "trending-up")
        self.cpu_spark = self._spark_row(card, "CPU Usage")
        self.ram_spark = self._spark_row(card, "RAM Usage")
        self.disk_spark = self._spark_row(card, "Disk Activity")
        return card

    def _spark_row(self, card, label):
        card.add(QLabel(label))
        spark = Sparkline()
        card.add(spark)
        return spark

    def _build_branding_card(self):
        card = Card("GnegnoliOS", "bar-chart-3")
        text = QLabel("Forged in code. Built for freedom.\nMade for creators, gamers and professionals.")
        text.setWordWrap(True)
        text.setStyleSheet("color: #8a8a8a;")
        card.add(text)
        link = QLabel('<a href="https://gnegnolios.org" style="color:#ff3b30;">https://gnegnolios.org</a>')
        link.setOpenExternalLinks(True)
        card.add(link)
        return card

    # -- refresh ----------------------------------------------------------------

    def refresh(self):
        cpu = psutil.cpu_percent()
        ram = psutil.virtual_memory().percent

        for path, bar, value_label in self.disk_bars:
            try:
                usage = psutil.disk_usage(path)
                bar.setValue(int(usage.percent))
                value_label.setText(
                    f"{usage.percent:.0f}% ({usage.used // (1024**3)}G / {usage.total // (1024**3)}G)"
                )
            except FileNotFoundError:
                bar.setValue(0)
                value_label.setText("not mounted")

        self.gauge.set_value(cpu)
        self.cpu_spark.push(cpu)
        self.ram_spark.push(ram)

        now_bytes = _disk_bytes()
        delta_mb = (now_bytes - self._prev_disk_bytes) / (1024 ** 2)
        self._prev_disk_bytes = now_bytes
        # ponytail: scaled against an arbitrary 20MB/interval ceiling for the
        # sparkline's 0-100 range; raise the ceiling if it clips on fast disks.
        self.disk_spark.push(min(100, delta_mb / 20 * 100))


def _disk_bytes():
    io = psutil.disk_io_counters()
    return (io.read_bytes + io.write_bytes) if io else 0


def _quick_lines(argv):
    import subprocess
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=3)
        return [l for l in out.stdout.splitlines() if l.strip()]
    except Exception:
        return []
