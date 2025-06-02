# Changelog

## [1.0.9] - 2025-06-02

### Added
- Support for staging environment via `STAGING_ENV` flag
- Network logger can now be enabled in release builds for staging/testing
- Added `NetworkLoggerConfig` for centralized configuration
- Improved environment-specific behavior control
- Enhanced security with explicit staging opt-in

### Changed
- Updated documentation with staging environment setup
- Improved security documentation
- Better environment detection logic
- Centralized configuration management

### Security
- Added explicit staging environment opt-in
- Improved production environment safety
- Better environment isolation
- Enhanced security documentation

## [1.0.8] - 2025-05-31

### Added
- Custom environment support
- Environment builder pattern
- Better developer experience
- Comprehensive example app

### Changed
- Simplified API for environment configuration
- Improved documentation
- Better code organization
- Enhanced example app

### Fixed
- Environment validation
- Documentation clarity
- Example code structure
- Code formatting

## [1.0.7] - 2025-05-31

### Added
- Initial release of Cote Network Logger
- Web dashboard for viewing HTTP network logs
- Real-time network monitoring
- Cross-platform support
- Memory-safe logging
- Debug-only functionality
- Local-only web server

### Features
- HTTP activity tracking
- Real-time web dashboard
- Zero-setup installation
- Debug mode only
- Memory-bounded storage
- Modern responsive UI
- Cross-platform support

### Security
- Debug builds only
- Local network binding
- No external communication
- Memory-only storage
- Automatic cleanup

## [1.0.6] - 2025-05-31

### Changed
- Package maintenance and optimization
- Code quality improvements
- Enhanced performance and stability
- Updated project dependencies

### Fixed
- Fixed contradictory Android emulator documentation
- Clarified that Android emulator dashboard is only accessible from emulator browser, not host Mac/Windows browser
- Updated documentation to recommend iOS Simulator as best option for Mac developers

## [1.0.5] - 2025-05-31

### Changed
- Updated documentation to prioritize simple Dio setup in Quick Start
- Improved onboarding instructions for new users
- Updated and added dashboard screenshots
- Clarified advanced/manual logging and HTTP package interceptor usage

## [1.0.4] - 2025-01-20

### Fixed
- Added screenshots as package assets for proper display on pub.dev
- Screenshots now bundled with package instead of relying on external GitHub links

## [1.0.0] - 2025-01-15

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