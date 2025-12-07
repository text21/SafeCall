## [1.5.0-beta] - 2025-12-05

### Added

- **SafeSandbox (experimental):** Allows execution of untrusted or dynamic code in an isolated environment with protected globals, optional whitelisting, and SafeCall-wrapped execution.
- **SafeRemote (experimental):** New SafeRemoteEvent and SafeRemoteFunction wrappers featuring:
  - Per-player rate limiting
  - Argument validation hooks
  - Automatic SafeCall protection
  - Error propagation & safer security defaults
  - Fully preserved multi-value returns

### Changed

- Internal execution paths updated to support sandboxed environments.
- SafeCall now exposes `CreateSandbox`, `CreateSafeRemoteEvent`, and `CreateSafeRemoteFunction`.

### Fixed

- Minor inconsistencies in error forwarding for nested async calls.

### Deprecated

- None this update.

### Removed

- None this update.

> This is a **beta release**. API surface for SafeSandbox and SafeRemote may change after developer feedback.
