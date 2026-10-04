#!/usr/bin/env python3
"""Gnegnoli Control Center - main entry point."""
import sys

from PyQt6.QtWidgets import QApplication

from window import MainWindow
from theme import STYLESHEET


def main():
    app = QApplication(sys.argv)
    app.setStyleSheet(STYLESHEET)
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
