"""Main window: fixed left sidebar (icons + collapsible groups) + QStackedWidget."""
from PyQt6.QtCore import QSize, Qt
from PyQt6.QtWidgets import (
    QButtonGroup, QHBoxLayout, QMainWindow, QPushButton, QStackedWidget,
    QVBoxLayout, QWidget
)

import icons
from pages.dashboard import DashboardPage
from pages.stub import (
    BackupsPage, DiagnosticsPage, DockerPage, DriversPage, FlatpakPage,
    GamingPage, KernelsPage, LutrisPage, PerformancePage,
    PersonalizationPage, ProtonPage, SettingsPage, SoftwarePage, SystemPage,
    UpdatesPage, WinePage,
)

# (lucide icon name, label, page_class, children | None)
# children entries are (icon, label, page_class) shown nested when expanded.
NAV_TREE = [
    ("layout-dashboard", "Dashboard", DashboardPage, None),
    ("monitor", "System", SystemPage, None),
    ("refresh-cw", "Updates", UpdatesPage, None),
    ("plug", "Drivers", DriversPage, None),
    ("puzzle", "Kernels", KernelsPage, None),
    ("sliders-horizontal", "Performance", PerformancePage, None),
    ("gamepad-2", "Gaming", GamingPage, [
        ("wine", "Proton", ProtonPage),
        ("wine", "Wine", WinePage),
        ("dice-5", "Lutris", LutrisPage),
    ]),
    ("boxes", "Software", SoftwarePage, [
        ("package-2", "Flatpak", FlatpakPage),
        ("container", "Docker", DockerPage),
        ("palette", "Personalization", PersonalizationPage),
        ("hard-drive-download", "Backups", BackupsPage),
        ("stethoscope", "Diagnostics", DiagnosticsPage),
    ]),
    ("settings", "Settings", SettingsPage, None),
]


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Gnegnoli Control Center")
        self.resize(1400, 900)

        central = QWidget()
        self.setCentralWidget(central)
        root = QHBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)
        self.stack = QStackedWidget()
        self._child_rows = []

        root.addWidget(self._build_sidebar())
        root.addWidget(self.stack, 1)

        self.nav_group.buttons()[0].setChecked(True)
        self.stack.setCurrentIndex(0)

    def _build_sidebar(self):
        sidebar = QWidget()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(230)
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(8, 16, 8, 16)
        layout.setSpacing(2)

        index = 0
        for icon_name, name, page_cls, children in NAV_TREE:
            parent_btn, index = self._add_nav_button(layout, icon_name, name, page_cls, index)
            if children:
                child_buttons = []
                for c_icon, c_name, c_page_cls in children:
                    kid_btn, index = self._add_nav_button(
                        layout, c_icon, c_name, c_page_cls, index, indent=True
                    )
                    kid_btn.setVisible(False)
                    child_buttons.append(kid_btn)
                self._child_rows.append(child_buttons)
                parent_btn.clicked.connect(
                    lambda checked, kids=child_buttons: self._toggle_group(kids)
                )

        layout.addStretch()
        return sidebar

    def _toggle_group(self, child_buttons):
        expanded = not child_buttons[0].isVisible()
        for kid in child_buttons:
            kid.setVisible(expanded)

    def _add_nav_button(self, layout, icon_name, name, page_cls, index, indent=False):
        btn = QPushButton(name)
        btn.setObjectName("NavButton")
        btn.setProperty("indent", "true" if indent else "false")
        btn.setIcon(icons.icon(icon_name))
        btn.setIconSize(QSize(18, 18))
        btn.setCheckable(True)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.clicked.connect(lambda checked, i=index: self.stack.setCurrentIndex(i))
        self.nav_group.addButton(btn, index)
        self.stack.addWidget(page_cls())
        layout.addWidget(btn)
        return btn, index + 1
