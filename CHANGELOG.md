# Changelog

## [1.0.0] - 2024-01-15

### Added
- Initial release of Cote Network Logger
- `NetworkLoggerInterceptor` for capturing Dio HTTP requests and responses
- `NetworkLogStore` for in-memory log storage (max 200 entries)
- `NetworkLogWebServer` for local web dashboard
- Real-time web dashboard with request/response details
- Auto-refresh functionality
- Status code highlighting
- Request/response body display (10KB limit)
- Clear logs functionality
- Debug mode only operation
- Example app with test scenarios
- Complete API documentation

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