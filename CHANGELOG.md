# Changelog

## [1.0.7] - 2025-05-31

### Fixed
- Fixed all Dart formatting and linting issues
- Replaced `print()` statements with `debugPrint()` in example code
- Added missing trailing commas for better code formatting
- Improved code readability with proper line breaks

### Changed
- Enhanced code quality to meet pub.dev scoring requirements
- Improved Dart code conventions compliance
- Better adherence to Flutter/Dart style guidelines
- Optimized static analysis results

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

## [1.0.0] - 2024-01-15

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

## [1.0.4] - 2024-01-20

### Fixed
- Added screenshots as package assets for proper display on pub.dev
- Screenshots now bundled with package instead of relying on external GitHub links 

## [1.0.5] - 2025-05-31

### Changed
- Updated documentation to prioritize simple Dio setup in Quick Start
- Improved onboarding instructions for new users
- Updated and added dashboard screenshots
- Clarified advanced/manual logging and HTTP package interceptor usage 