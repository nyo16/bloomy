# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-16

### Added
- Initial release of Bloomy bloom filter library
- Standard bloom filter implementation
- Counting bloom filter with deletion support
- Scalable bloom filter with auto-growth
- Learned bloom filter with ML-enhanced filtering
- EXLA backend support for GPU/CPU acceleration
- Binary serialization and file persistence
- Batch operations for efficient bulk processing
- Union and intersection operations for filter merging
- Jaccard similarity calculation
- Comprehensive statistics and monitoring
- Full test suite with 9 tests covering all filter types
- Extensive documentation and examples

### Fixed
- Critical bug: Nx tensor backend mismatch in bit array operations causing silent failures
- All compiler warnings resolved

### Dependencies
- Nx ~> 0.10.0 (required)
- EXLA ~> 0.10.0 (optional, recommended for performance)
- Scholar ~> 0.4.0 (optional, required for learned filters)

[0.1.0]: https://github.com/YOUR_USERNAME/bloomy/releases/tag/v0.1.0
