# Changelog

## [1.0.0] - 2024-01-XX

### Added
- Initial release of Cote Network Logger
- Web dashboard for viewing HTTP network logs in real-time
- `CoteNetworkLogger` for capturing Dio HTTP requests and responses
- Cross-platform support (iOS, Android, macOS, Windows, Linux)
- Memory-safe logging with automatic cleanup
- Debug-only functionality (completely disabled in release builds)
- Local-only web server for security

### Features
- HTTP activity tracking
- Real-time web dashboard
- Zero-setup installation
- Debug mode only (production safe)
- Memory-bounded storage
- Modern responsive UI
- Cross-platform support

### Security
- Debug builds only
- Local network binding (localhost only)
- No external communication
- Memory-only storage
- Automatic cleanup 