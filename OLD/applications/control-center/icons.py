"""Load bundled Lucide SVG icons (assets/icons/, ISC license) as colored QIcons.

Each SVG uses stroke="currentColor" so we recolor it ourselves at render time
instead of shipping a separate file per color.
"""
import os

from PyQt6.QtCore import QByteArray, Qt
from PyQt6.QtGui import QIcon, QPainter, QPixmap
from PyQt6.QtSvg import QSvgRenderer

from theme import ACCENT, TEXT_DIM

ICONS_DIR = os.path.join(os.path.dirname(__file__), "assets", "icons")


def pixmap(name, color=TEXT_DIM, size=18):
    path = os.path.join(ICONS_DIR, f"{name}.svg")
    with open(path, "r", encoding="utf-8") as f:
        svg = f.read().replace("currentColor", color)
    renderer = QSvgRenderer(QByteArray(svg.encode("utf-8")))
    pm = QPixmap(size, size)
    pm.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pm)
    renderer.render(painter)
    painter.end()
    return pm


def icon(name, size=18):
    """QIcon that's dim gray normally, accent red when the button is checked."""
    ic = QIcon()
    ic.addPixmap(pixmap(name, TEXT_DIM, size), QIcon.Mode.Normal, QIcon.State.Off)
    ic.addPixmap(pixmap(name, ACCENT, size), QIcon.Mode.Normal, QIcon.State.On)
    return ic
