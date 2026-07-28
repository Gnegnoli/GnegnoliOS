"""Color palette and global QSS for Gnegnoli Control Center."""

BG_DARK = "#0d0d0d"
BG_PANEL = "#141414"
BG_PANEL_ALT = "#1a1a1a"
BORDER = "#262626"
TEXT = "#e6e6e6"
TEXT_DIM = "#8a8a8a"
ACCENT = "#ff3b30"
ACCENT_DIM = "#3a1210"
GREEN = "#34c759"

STYLESHEET = f"""
QWidget {{
    background-color: {BG_DARK};
    color: {TEXT};
    font-family: 'Segoe UI', 'Inter', sans-serif;
    font-size: 13px;
}}

#Sidebar {{
    background-color: {BG_PANEL};
    border-right: 1px solid {BORDER};
}}

QPushButton#NavButton {{
    text-align: left;
    padding: 10px 16px;
    border: none;
    border-radius: 6px;
    color: {TEXT_DIM};
    background: transparent;
    font-size: 13px;
}}
QPushButton#NavButton:hover {{
    background-color: {BG_PANEL_ALT};
    color: {TEXT};
}}
QPushButton#NavButton:checked {{
    background-color: {ACCENT_DIM};
    color: {ACCENT};
    font-weight: 600;
}}
QPushButton#NavButton[indent="true"] {{
    padding-left: 40px;
    font-size: 12px;
}}

QFrame#Card {{
    background-color: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: 10px;
}}

QLabel#CardTitle {{
    font-size: 14px;
    font-weight: 600;
    color: {TEXT};
}}

QLabel#SectionValue {{
    font-size: 22px;
    font-weight: 700;
}}

QProgressBar {{
    background-color: {BG_PANEL_ALT};
    border: none;
    border-radius: 5px;
    height: 10px;
    text-align: center;
    color: {TEXT};
}}
QProgressBar::chunk {{
    background-color: {ACCENT};
    border-radius: 5px;
}}

QPushButton#ActionButton {{
    background-color: {BG_PANEL_ALT};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 10px;
    color: {TEXT};
}}
QPushButton#ActionButton:hover {{
    border-color: {ACCENT};
    color: {ACCENT};
}}

QScrollArea {{
    border: none;
}}
"""
