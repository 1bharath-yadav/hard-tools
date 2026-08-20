# Architecture & Technical Decision Log

### Decision 1: Passwordless Sudo for Archer
- **Date**: 2026-08-20
- **Context**: Arch container running on Android DroidSpaces.
- **Decision**: Configured `/etc/sudoers.d/archer` with `NOPASSWD: ALL` to allow automated non-interactive gadget manipulation.

### Decision 2: Preservation of `mass_storage_manager.sh`
- **Date**: 2026-08-20
- **Context**: Existing Mass Storage script was verified working.
- **Decision**: Strictly maintain `mass_storage_manager.sh` untouched. All launcher options call it directly.

### Decision 3: UDC Unbind Pattern (`echo none > UDC`)
- **Date**: 2026-08-20
- **Context**: ConfigFS `Invalid argument` (-22) when linking functions while UDC was bound.
- **Decision**: All scripts must execute `echo none > /config/usb_gadget/g1/UDC` before altering symlinks in `configs/b.1/`, then rebind to `a600000.dwc3`.

### Decision 4: Dynamic `/dev/hidg*` Resolution
- **Date**: 2026-08-20
- **Context**: Android UDC dynamically assigns character devices `/dev/hidg1` and `/dev/hidg2`.
- **Decision**: Implemented `map_hid()` to read `cat $G/functions/hid.*/dev` to extract minor numbers instead of hardcoding device paths.

### Decision 5: Touchpad Dual-Report Architecture
- **Date**: 2026-08-20
- **Context**: `hid.touchpad` descriptor contains Report ID `0x01` (relative mouse) and Report ID `0x04` (digitizer).
- **Decision**: Implemented `ptr01()` for mouse movement and `touch04()` for absolute coordinates/tap/drag within logical range `0..3528`.

### Decision 6: Codebase Modularity (<500 Lines per File)
- **Date**: 2026-08-20
- **Context**: Maintainability and agent context efficiency.
- **Decision**: Refactored keyboard keymaps and touch digitizer helpers into modular components in `lib/`, keeping all files under 500 lines.
