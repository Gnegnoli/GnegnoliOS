"""Helpers to run real system commands from the GUI without blocking it.

Uses QProcess (Qt's native async process API) instead of subprocess.run,
since long commands (pacman -Syu, etc) would freeze the UI thread otherwise.
"""
import shutil

from PyQt6.QtCore import QProcess
from PyQt6.QtWidgets import QMessageBox

# Binaries whose pacman package name doesn't match the executable name.
# Covers the binaries this app actually shells out to; extend if a new
# action wires up a binary not listed here (falls back to same name).
BINARY_TO_PACKAGE = {
    "wineboot": "wine",
    "winecfg": "wine",
    "winetricks": "winetricks",
    "gnome-disks": "gnome-disk-utility",
    "lspci": "pciutils",
    "nvidia-smi": "nvidia-utils",
}


def which(*names):
    """Return the first binary name found on PATH, or None."""
    for name in names:
        if shutil.which(name):
            return name
    return None


def run(owner, argv, console=None, needs_root=False):
    """Run argv as a child process, streaming merged stdout/stderr into console.

    owner: a QWidget to parent the QProcess to (keeps it alive, and doubles as
    the QMessageBox parent); must have a `_procs` list attribute the caller
    maintains, so the process isn't garbage-collected mid-run.
    console: optional QTextEdit-like widget with insertPlainText/
    ensureCursorVisible. Pass None to run silently (e.g. dashboard quick
    actions) — a missing/failed binary still surfaces via a popup.
    """
    target_bin = argv[0]
    if needs_root:
        argv = ["pkexec"] + argv

    proc = QProcess(owner)
    proc.setProgram(argv[0])
    proc.setArguments(argv[1:])
    proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)

    def on_output():
        if console is None:
            return
        data = bytes(proc.readAllStandardOutput()).decode(errors="replace")
        console.insertPlainText(data)
        console.ensureCursorVisible()

    def on_finished(exit_code, _status):
        if console is not None:
            console.insertPlainText(f"\n[exit {exit_code}]\n\n")
            console.ensureCursorVisible()
        if proc in owner._procs:
            owner._procs.remove(proc)

    def on_error(error):
        if proc in owner._procs:
            owner._procs.remove(proc)
        if error == QProcess.ProcessError.FailedToStart:
            _offer_install(owner, target_bin, console)
        else:
            QMessageBox.warning(
                owner, "Command failed",
                f"'{target_bin}' failed while running."
            )

    proc.readyReadStandardOutput.connect(on_output)
    proc.finished.connect(on_finished)
    proc.errorOccurred.connect(on_error)

    if console is not None:
        console.insertPlainText(f"$ {' '.join(argv)}\n")
        console.ensureCursorVisible()
    owner._procs.append(proc)
    proc.start()
    return proc


def _offer_install(owner, binary, console):
    package = BINARY_TO_PACKAGE.get(binary, binary)
    reply = QMessageBox.question(
        owner, "Command not found",
        f"'{binary}' isn't installed.\nInstall package '{package}' now?",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
    )
    if reply == QMessageBox.StandardButton.Yes:
        run(owner, ["pacman", "-S", package, "--noconfirm"], console, needs_root=True)


def run_or_notify(owner, result, console=None):
    """Run a (argv, needs_root) result from an action handler, or pop up
    "not available" when the handler returned None. Shared by every page so
    there's one place that decides how an unwired/unsupported action is
    surfaced, instead of each caller silently doing nothing.
    """
    if result is None:
        QMessageBox.information(
            owner, "Not available",
            "This feature isn't available on this system."
        )
        return None
    argv, needs_root = result
    return run(owner, argv, console, needs_root=needs_root)
