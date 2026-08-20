# Android Binary Execution & Runtime Diagnosis

This document investigates whether Android userspace binaries in `/system/bin` can be executed directly from inside the Arch Linux (DroidSpaces) container.

---

## 1. Executive Summary & Question Matrix

| Question | Status | Root Cause / Technical Detail |
| :--- | :--- | :--- |
| **1. Can Arch see Android binaries?** | ✅ **YES** | `/system` is mounted (`/dev/block/dm-1`). `/system/bin/dumpsys`, `cmd`, `service` are visible. |
| **2. Can Arch execute Android binaries?** | ❌ **NO** | `execve()` fails immediately with `ENOENT` (127: required file not found). |
| **3. Are required Android linkers visible?** | ❌ **BROKEN** | `/system/bin/linker64` links to `/apex/com.android.runtime/bin/linker64`. `/apex` is not mounted. |
| **4. Is Binder accessible?** | ⚠️ **NODES ONLY** | `/dev/binder`, `/dev/hwbinder`, `/dev/vndbinder` exist, but Android userspace IPC client libraries are not runnable. |
| **5. Can `dumpsys` run directly from Arch?** | ❌ **NO** | Cannot execute due to missing Bionic runtime linker (`/apex/.../linker64`). |

---

## 2. Technical Evidence & ELF Disassembly

### A. ELF Interpreter Header Inspection
Running `readelf -l /system/bin/dumpsys` reveals the required dynamic linker:
```text
[Requesting program interpreter: /system/bin/linker64]
```

### B. Broken Symlink Analysis
Checking the target of `/system/bin/linker64`:
```text
$ readlink /system/bin/linker64
/apex/com.android.runtime/bin/linker64
```
Because DroidSpaces mounts `/system` but **does not mount `/apex`**, the interpreter path does not resolve inside the container filesystem.

### C. Kernel Execve Failure
Tracing binary execution with `strace`:
```text
execve("/system/bin/dumpsys", ["/system/bin/dumpsys"], ...) = -1 ENOENT (No such file or directory)
```
The Linux kernel returns `ENOENT` because the ELF dynamic linker (`PT_INTERP`) is missing from the container's root filesystem.

---

## 3. Important Operational Warning: PATH Contamination

> [!CRITICAL]
> **DO NOT** prepend `/system/bin` or `/system/xbin` to `$PATH` (e.g. `export PATH="/system/bin:$PATH"`).
>
> Doing so causes standard shell utilities (`ls`, `grep`, `head`, `cat`) to resolve to Android's `/system/bin/` binaries, causing subsequent shell commands to fail with `cannot execute: required file not found`.
>
> Always keep Arch Linux binaries first:
> ```bash
> export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
> ```

---

## 4. Architectural Implication for Tooling

1. **Kernel/ConfigFS vs. Android Framework**:
   - `hard-tools` directly manages kernel subsystems via sysfs/ConfigFS (`/config/usb_gadget/g1`, `/sys/class/udc/`, `/dev/hidg*`, `iptables-legacy`, BlueZ `bluetoothctl`).
   - These kernel-level controls **do not depend on Android Bionic binaries** and function natively in Arch Linux.
2. **Android Framework Access (dumpsys/cmd)**:
   - Must be invoked through ADB, root Termux/Android shell, or if DroidSpaces is updated to bind-mount `/apex`.
