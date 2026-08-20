# Prioritized Action Items & Next Tasks

```yaml
priority_1:
  task: bluetooth_assessment
  description: "Execute BlueZ diagnostic check: local controller discovery, BLE beaconing, and L2ping latency."
  script: "scripts/bt_arsenal.sh"

priority_2:
  task: recon_toolkit
  description: "Build terminal-native hardware, network, USB, and kernel inventory utility."
  script: "scripts/recon.sh"

priority_3:
  task: session_recording
  description: "Build CLI session logger for reproducible logs and artifacts."
  script: "scripts/session.sh"

priority_4:
  task: payload_framework
  description: "Maintain structured cross-platform payload library in payloads/."

deferred:
  - web_dashboard
  - browser_dependency
  - proprietary_wifi_injection
```
