# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-11-19

### Added

- Added CallWithTag
- Added CallWithThread
- Added connectOnce option to ConnectSafe

### Changed

- Changed ProtectTable behavior to call functions from inherited metatables

### Fixed

- Fixed attempting to call Log function when nil
- Fixed Call not returning tuples

## Deprecated

- Deprecated CallDeferred in favor of CallWithThread
- Deprecated SetPromiseModule
- Deprecated CallAsync

### Removed

- Removed contextTag parameter from Call
