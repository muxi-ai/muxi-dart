# Changelog

All notable changes to this project will be documented in this file.

## 0.20260211.1

### Added
- `mode` parameter in `FormationConfig` for draft/live URL routing
  - `mode="live"` (default): Uses `/api/{id}/v1` prefix
  - `mode="draft"`: Uses `/draft/{id}/v1` prefix for local development with `muxi up`
- SDK version update notifications (via `X-Muxi-SDK-Latest` response header)
  - Notifies when newer SDK version available (max once per 12 hours)
  - Disable with `MUXI_SDK_VERSION_NOTIFICATION=0`
- Console telemetry support via internal `_app` parameter
- Example code in `example/` directory

## 0.20260129.0

### Added
- Initial release
- `ServerClient` for managing formations via HMAC authentication
- `FormationClient` for interacting with agent runtimes
- Support for chat, threads, memories, and tools APIs
- Webhook signature verification
