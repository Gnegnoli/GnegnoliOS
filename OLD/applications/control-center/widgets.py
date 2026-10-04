"""Reusable widgets shared across pages."""
from collections import deque

from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QColor, QFont, QPainter, QPen
from PyQt6.QtWidgets import (
    QFrame, QGridLayout, QHBoxLayout, QLabel, QPushButton, QVBoxLayout
)

import icons
from theme import ACCENT, BG_PANEL_ALT, BORDER, GREEN, TEXT, TEXT_DIM


class Card(QFrame):
    """Bordered panel with a title, matching the mockup's dashboard tiles."""

    def __init__(self, title, icon=None, parent=None):
        super().__init__(parent)
        self.setObjectName("Card")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(16, 14, 16, 14)
        self.layout.setSpacing(10)

        if title:
            head = QHBoxLayout()
            if icon:
                icon_label = QLabel()
                icon_label.setPixmap(icons.pixmap(icon, TEXT, 16))
                head.addWidget(icon_label)
            label = QLabel(title)
            label.setObjectName("CardTitle")
            head.addWidget(label)
            head.addStretch()
            self.layout.addLayout(head)

    def add(self, widget):
        self.layout.addWidget(widget)
        return widget


def action_grid(actions, columns=2):
    """Build a QGridLayout of ActionButtons from [(label, slot), ...]."""
    grid = QGridLayout()
    grid.setSpacing(10)
    for i, (label, slot) in enumerate(actions):
        btn = QPushButton(label)
        btn.setObjectName("ActionButton")
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        if slot:
            btn.clicked.connect(slot)
        grid.addWidget(btn, i // columns, i % columns)
    return grid


def info_row(label, value):
    """A 'Label ......... value' row used in overview-style cards."""
    row = QHBoxLayout()
    left = QLabel(label)
    left.setStyleSheet(f"color: {TEXT_DIM};")
    right = QLabel(value)
    right.setStyleSheet(f"color: {TEXT}; font-weight: 600;")
    row.addWidget(left)
    row.addStretch()
    row.addWidget(right)
    return row


def status_row(label, sub, ok=True):
    """Icon-less status line: title + subtitle on the left, check/cross on the right."""
    row = QHBoxLayout()
    text_col = QVBoxLayout()
    title = QLabel(label)
    title.setStyleSheet(f"color: {TEXT}; font-weight: 600;")
    subtitle = QLabel(sub)
    subtitle.setStyleSheet(f"color: {TEXT_DIM}; font-size: 11px;")
    text_col.addWidget(title)
    text_col.addWidget(subtitle)
    text_col.setSpacing(0)
    row.addLayout(text_col)
    row.addStretch()
    mark = QLabel()
    mark.setPixmap(icons.pixmap("circle-check" if ok else "circle-x", GREEN if ok else ACCENT, 16))
    row.addWidget(mark)
    return row


class Gauge(QFrame):
    """Simple semicircular dial (0-100) with a label under the needle."""

    def __init__(self, value=0, mode_name="Balanced", subtitle="", parent=None):
        super().__init__(parent)
        self._value = value
        self.mode_name = mode_name
        self.subtitle = subtitle
        self.setMinimumHeight(120)

    def set_value(self, value, mode_name=None, subtitle=None):
        self._value = max(0, min(100, value))
        if mode_name is not None:
            self.mode_name = mode_name
        if subtitle is not None:
            self.subtitle = subtitle
        self.update()

    def paintEvent(self, _event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        w, h = self.width(), self.height()
        side = min(w, h * 2)
        rect = QRectF((w - side) / 2, 8, side, side)

        pen = QPen(QColor(BORDER))
        pen.setWidth(10)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(pen)
        painter.drawArc(rect, 0 * 16, 180 * 16)

        pen.setColor(QColor(ACCENT))
        painter.setPen(pen)
        span = int(180 * (self._value / 100) * 16)
        painter.drawArc(rect, 180 * 16, -span)

        painter.setPen(QColor(TEXT))
        painter.setFont(QFont(self.font().family(), 13, QFont.Weight.Bold))
        painter.drawText(
            QRectF(0, rect.bottom() - 30, w, 24),
            Qt.AlignmentFlag.AlignCenter, self.mode_name
        )
        painter.setPen(QColor(TEXT_DIM))
        painter.setFont(QFont(self.font().family(), 9))
        painter.drawText(
            QRectF(0, rect.bottom() - 8, w, 32),
            int(Qt.AlignmentFlag.AlignCenter) | int(Qt.TextFlag.TextWordWrap),
            self.subtitle
        )


class Sparkline(QFrame):
    """Rolling line chart, fed one sample at a time (e.g. from a QTimer)."""

    def __init__(self, maxlen=40, parent=None):
        super().__init__(parent)
        self.samples = deque(maxlen=maxlen)
        self.setMinimumHeight(28)
        self.setMaximumHeight(36)

    def push(self, value):
        self.samples.append(value)
        self.update()

    def paintEvent(self, _event):
        if len(self.samples) < 2:
            return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        w, h = self.width(), self.height()
        pen = QPen(QColor(ACCENT))
        pen.setWidth(2)
        painter.setPen(pen)

        n = len(self.samples)
        step = w / max(1, n - 1)
        top_margin = 3
        points = [
            (i * step, h - top_margin - (v / 100) * (h - 2 * top_margin))
            for i, v in enumerate(self.samples)
        ]
        for (x1, y1), (x2, y2) in zip(points, points[1:]):
            painter.drawLine(int(x1), int(y1), int(x2), int(y2))
