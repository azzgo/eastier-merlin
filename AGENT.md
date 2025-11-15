# EasyTier Merlin Plugin - Agent Context

## Project Overview
- **Target Device**: ASUS RT-BT86U router (ARM64 architecture)
- **Purpose**: Personal KoolShare plugin for easytier-core VPN mesh networking
- **Status**: **COMPLETED** - Fully functional plugin ready for use
- **Version**: v1.7 (Latest stable release)

## Project Architecture

### Core Components
- **easytier_config.sh** - Main configuration and service management script
- **easytier_status.cgi** - Web API for status checking
- **Module_easytier.asp** - Web interface for configuration
- **install.sh** - KoolShare-compatible installation script

### Fixed Configuration
- `--no-tun` parameter is hardcoded (required for router environment)
- ARM64 architecture only (aarch64)
- Integrates with KoolShare software center framework

### Supported Parameters
1. **IPv4 Address** - Virtual network IP (e.g., 10.0.0.1)
2. **Network Name** - Network identifier (e.g., "home-vpn")
3. **Network Secret** - Encryption key for network security
4. **Peers** - Remote node addresses (tcp://host:port, udp://host:port)

## Current Implementation Status

### ✅ **Completed Features**
- [x] Full web interface with configuration management
- [x] Service start/stop/restart functionality
- [x] Configuration validation and error handling
- [x] Persistent configuration storage (dbus + file)
- [x] Real-time status monitoring
- [x] KoolShare software center integration
- [x] Automatic service startup on boot
- [x] Comprehensive error logging
- [x] Shell compatibility fixes (bash/ash/sh)

### 🔧 **Technical Details**
- **API Endpoint**: `/_api/` with method `easytier_config.sh`
- **Configuration Storage**: dbus + `/koolshare/configs/easytier.conf`
- **Service Management**: systemd-style start/stop with PID management
- **Log Location**: `/tmp/easytier_log.txt`
- **Installation Path**: `/koolshare/` (software center standard)

### 📁 **File Structure**
```
/koolshare/
├── bin/easytier-core                    # ARM64 binary
├── scripts/
│   ├── easytier_config.sh              # Main control script  
│   └── easytier_status.cgi             # Status API
├── webs/Module_easytier.asp            # Web interface
├── configs/easytier.conf               # Configuration file
├── res/icon-easytier.png              # Plugin icon
└── init.d/S99easytier.sh              # Boot startup script
```

## Usage Instructions

### Web Interface
1. Access router admin panel
2. Go to Software Center → EasyTier
3. Configure IPv4, network name, secret, and peers
4. Save configuration and start service

### Command Line
```bash
# Service management
/koolshare/scripts/easytier_config.sh start
/koolshare/scripts/easytier_config.sh stop
/koolshare/scripts/easytier_config.sh restart
/koolshare/scripts/easytier_config.sh status

# Configuration management  
/koolshare/scripts/easytier_config.sh save_config
/koolshare/scripts/easytier_config.sh get_config
```

## Build and Deployment

### Build Tools
- **build_package.sh** - Creates KoolShare-compatible installation package
- **create_test_env.sh** - Sets up local testing environment
- **config.json.js** - Plugin metadata for software center

### Installation Package
- **File**: `easytier.tar.gz`
- **Structure**: Standard KoolShare plugin format
- **Verification**: MD5 checksum included
- **Compatibility**: All KoolShare-supported platforms (hnd, qca, mtk, etc.)

## Development History

### Major Milestones
1. **v1.0** - Basic plugin structure and service management
2. **v1.2** - Configuration persistence and web interface improvements
3. **v1.5** - API timeout fixes and error handling
4. **v1.7** - Shell compatibility fixes and syntax standardization

### Key Fixes Applied
- Fixed shell function syntax for multi-environment compatibility
- Implemented proper API response handling with `XU6J03M6` markers
- Added comprehensive input validation
- Resolved configuration persistence issues
- Optimized service startup/shutdown procedures

## Known Limitations
- ARM64 architecture only (RT-BT86U specific)
- No TUN device support (hardcoded --no-tun)
- Personal use project (no official support/distribution)
- Requires KoolShare-compatible Merlin firmware
## Maintenance Notes

- Monitor `/tmp/upload/easytier_log.txt` for operational issues
- Configuration backup recommended before updates
- Service automatically restarts on configuration changes
- dbus variables persist across reboots for reliability

**Project Status**: PRODUCTION READY
