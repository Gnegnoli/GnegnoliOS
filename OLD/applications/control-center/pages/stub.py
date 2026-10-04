"""One page per sidebar section, each wired to real system commands.

Every action is (label, handler) where handler(page) returns either:
  - (argv: list[str], needs_root: bool)  -> runs via commands.run_or_notify;
    if the binary is missing, commands.run offers to pacman -S install it.
  - None                                  -> "not available" popup (used only
    when there's no single command that would make sense to run/install, e.g.
    a feature that needs a picker UI that doesn't exist yet).
Handlers that pick between alternatives (AUR helper, fastfetch/neofetch/inxi)
still use commands.which() to choose which one to call.
"""
import os

from PyQt6.QtWidgets import QLabel, QTextEdit, QVBoxLayout, QWidget

from commands import run_or_notify, which
from widgets import Card, action_grid

HOME = os.path.expanduser("~")


class StubPage(QWidget):
    title = "Untitled"
    actions = []  # list of (label, handler) pairs

    def __init__(self, parent=None):
        super().__init__(parent)
        self._procs = []  # keeps QProcess instances alive while running

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(16)

        header = QLabel(self.title)
        header.setStyleSheet("font-size: 20px; font-weight: 700;")
        layout.addWidget(header)

        card = Card(None)
        card.layout.addLayout(action_grid(
            [(label, self._make_slot(handler)) for label, handler in self.actions]
        ))
        layout.addWidget(card)

        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setStyleSheet("font-family: monospace; font-size: 12px;")
        layout.addWidget(self.console, 1)

    def _make_slot(self, handler):
        return lambda checked=False, h=handler: self._run(h)

    def _run(self, handler):
        run_or_notify(self, handler(self), console=self.console)


# --- System ---------------------------------------------------------------

def _system_info(page):
    tool = which("fastfetch", "neofetch", "inxi")
    if tool == "inxi":
        return (["inxi", "-Fxxxz"], False)
    if tool:
        return ([tool], False)
    return (["uname", "-a"], False)


class SystemPage(StubPage):
    title = "System"
    actions = [
        ("System Information", _system_info),
        ("Repair System", lambda p: (["pacman", "-Qkk"], False)),
        ("Optimize System", lambda p: (["pacman", "-Sc", "--noconfirm"], True)),
        ("System Cleanup", lambda p: (["journalctl", "--vacuum-time=7d"], True)),
    ]


# --- Updates ----------------------------------------------------------------

def _check_pacman_updates(page):
    tool = which("checkupdates")
    if tool:
        return ([tool], False)
    return (["pacman", "-Qu"], False)


def _check_aur_updates(page):
    helper = which("yay", "paru")
    if helper:
        return ([helper, "-Qua"], False)
    return None


class UpdatesPage(StubPage):
    title = "Updates"
    actions = [
        ("Check pacman Updates", _check_pacman_updates),
        ("Check AUR Updates", _check_aur_updates),
        ("Check Flatpak Updates", lambda p: (["flatpak", "remote-ls", "--updates", "flathub"], False)),
        ("Update System", lambda p: (["pacman", "-Syu", "--noconfirm"], True)),
    ]


# --- Drivers ------------------------------------------------------------

class DriversPage(StubPage):
    title = "Drivers"
    actions = [
        ("NVIDIA Driver", lambda p: (["pacman", "-Qi", "nvidia"], False)),
        ("AMD Driver", lambda p: (["pacman", "-Qi", "mesa"], False)),
        ("Wi-Fi Driver", lambda p: (["lspci", "-k"], False)),
        ("Driver Manager", lambda p: None),
    ]


# --- Kernels -----------------------------------------------------------

class KernelsPage(StubPage):
    title = "Kernels"
    actions = [
        ("List Installed Kernels", lambda p: (["ls", "/usr/lib/modules"], False)),
        ("Install linux-zen", lambda p: (["pacman", "-S", "linux-zen", "--noconfirm"], True)),
        ("Remove linux-zen", lambda p: (["pacman", "-R", "linux-zen", "--noconfirm"], True)),
        ("Set Default Kernel", lambda p: None),
    ]


# --- Performance (cpupower governor) ------------------------------------

def _governor(name):
    return lambda p: (["cpupower", "frequency-set", "-g", name], True)


class PerformancePage(StubPage):
    title = "Performance"
    actions = [
        ("Power Saver", _governor("powersave")),
        ("Balanced", _governor("ondemand")),
        ("Performance", _governor("performance")),
        ("Turbo", _governor("performance")),
    ]


# --- Gaming --------------------------------------------------------------

class GamingPage(StubPage):
    title = "Gaming"
    actions = [
        ("Configure Gaming", lambda p: None),
        ("Gamemode Status", lambda p: (["gamemoded", "-s"], False)),
        ("Controller Setup", lambda p: None),
        ("MangoHud Toggle", lambda p: None),
    ]


# --- Proton --------------------------------------------------------------

class ProtonPage(StubPage):
    title = "Proton"
    actions = [
        ("List Proton Versions", lambda p: (["ls", "-1", f"{HOME}/.steam/root/compatibilitytools.d"], False)),
        ("Install Proton-GE", lambda p: ([which("yay", "paru"), "-S", "proton-ge-custom", "--noconfirm"], False) if which("yay", "paru") else None),
        ("Remove Version", lambda p: None),
        ("Set Default", lambda p: None),
    ]


# --- Wine ------------------------------------------------------------------

class WinePage(StubPage):
    title = "Wine"
    actions = [
        ("List Wine Prefixes", lambda p: (["ls", "-la", f"{HOME}/.wine"], False)),
        ("Create Prefix", lambda p: (["wineboot"], False)),
        ("Winetricks", lambda p: (["winetricks"], False)),
        ("Wine Configuration", lambda p: (["winecfg"], False)),
    ]


# --- Lutris ------------------------------------------------------------

class LutrisPage(StubPage):
    title = "Lutris"
    actions = [
        ("Open Lutris", lambda p: (["lutris"], False)),
        ("Install Game", lambda p: None),
        ("Sync Library", lambda p: None),
        ("Check for Updates", lambda p: None),
    ]


# --- Software ------------------------------------------------------------

class SoftwarePage(StubPage):
    title = "Software"
    actions = [
        ("Browse Software", lambda p: ([which("pamac-manager", "gnome-software") or "pamac-manager"], False)),
        ("Install Packages", lambda p: None),
        ("Remove Packages", lambda p: None),
        ("Snap Packages", lambda p: (["snap", "list"], False)),
    ]


# --- Flatpak ------------------------------------------------------------

class FlatpakPage(StubPage):
    title = "Flatpak"
    actions = [
        ("List Installed", lambda p: (["flatpak", "list"], False)),
        ("Check Updates", lambda p: (["flatpak", "remote-ls", "--updates", "flathub"], False)),
        ("Update All", lambda p: (["flatpak", "update", "-y"], False)),
        ("Repair", lambda p: (["flatpak", "repair"], True)),
    ]


# --- Docker ---------------------------------------------------------------

class DockerPage(StubPage):
    title = "Docker"
    actions = [
        ("Service Status", lambda p: (["systemctl", "status", "docker"], False)),
        ("List Containers", lambda p: (["docker", "ps", "-a"], False)),
        ("List Images", lambda p: (["docker", "images"], False)),
        ("Start Service", lambda p: (["systemctl", "start", "docker"], True)),
    ]


# --- Personalization -----------------------------------------------------

class PersonalizationPage(StubPage):
    title = "Personalization"
    actions = [
        ("Themes", lambda p: None),
        ("Icons", lambda p: None),
        ("Wallpapers", lambda p: None),
        ("Fonts", lambda p: (["fc-list"], False)),
    ]


# --- Backups (Btrfs + snapper) ---------------------------------------------

class BackupsPage(StubPage):
    title = "Backups"
    actions = [
        ("Create Snapshot", lambda p: (["snapper", "-c", "root", "create", "--description", "manual"], True)),
        ("Restore Snapshot", lambda p: None),
        ("Backup Manager", lambda p: (["snapper", "list"], False)),
        ("Schedule Backups", lambda p: None),
    ]


# --- Diagnostics -----------------------------------------------------------

class DiagnosticsPage(StubPage):
    title = "Diagnostics"
    actions = [
        ("System Logs", lambda p: (["journalctl", "-b", "--no-pager", "-n", "200"], False)),
        ("Run Benchmark", lambda p: None),
        ("Hardware Test", lambda p: (["lspci"], False)),
        ("Generate Report", lambda p: ([which("fastfetch", "neofetch") or "uname"], False)),
    ]


# --- Settings ----------------------------------------------------------

class SettingsPage(StubPage):
    title = "Settings"
    actions = [
        ("General", lambda p: None),
        ("Notifications", lambda p: None),
        ("Appearance", lambda p: None),
        ("About", lambda p: (["uname", "-a"], False)),
    ]
