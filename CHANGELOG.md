# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2025-11-27

### Added

Not this update.

### Changed

- Ensure `Call` and related wrappers (`CallWithTag`, `CallWithRetry`, `CallWithTimeout`, `CallBatch`, `CallAsync`) preserve multiple return values (including `nil`) so callers receive the exact tuple returned by wrapped functions.

- Refactored `ProtectTable` to preserve method binding and metamethod behavior when proxying tables.

### Fixed

- Fixed `Call` not returning tuples; also fixed `CallWithRetry`, `CallWithTimeout`, `CallBatch`, and `WrapFunction` so they correctly propagate full multi-value returns.

- Fixed `WrapFunction` and `BindableFunction` wrappers to return the exact tuple of values produced by the underlying callback (preserving `nil` values).

## Deprecated

Not this update.

### Removed

Not this update.
