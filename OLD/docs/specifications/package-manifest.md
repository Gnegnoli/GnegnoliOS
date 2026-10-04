# GnegnoliOS Package Manifest Specification

Version: 1.0

Every package inside `packages/` must contain a file called:

package.yaml

---

## Required fields

### name

Unique package identifier.

Example:

name: gnegnolios-release

---

### description

Human readable description.

---

### version

Package version.

---

### enabled

Whether this package is enabled.

Values:

- true
- false

---

### build

Whether the package should be built.

Values:

- true
- false

---

### install

Installation targets.

Example:

install:
  iso: true
  repository: true

---

### dependencies

Logical dependencies.

Example:

dependencies:
  - gnegnolios-release

---

### build_system

Currently supported:

- makepkg

Future:

- cmake
- meson
- cargo

---

## Directory layout

Example:

packages/

└── my-package/
    ├── PKGBUILD
    ├── package.yaml
    └── files/

---

## Validation rules

- Every package must contain package.yaml.
- Every package must contain PKGBUILD.
- Package names must be unique.
- Disabled packages are ignored.
