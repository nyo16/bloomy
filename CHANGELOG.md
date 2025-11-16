# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-16

### Added

#### Core Features
- **Standard Bloom Filter**: Classic space-efficient probabilistic set membership testing
- **Counting Bloom Filter**: Supports element deletion using counters (8/16/32-bit)
- **Scalable Bloom Filter**: Automatically grows capacity to maintain target false positive rate
- **Learned Bloom Filter**: ML-enhanced filtering with neural network for lower false positives

#### Performance
- Nx tensor-based operations for vectorized computing
- EXLA backend support for GPU/CPU acceleration (2-50x performance boost)
- Optimized batch operations for bulk processing
- Double hashing technique for efficient hash generation

#### Operations
- `add/2` and `add_all/2` for adding items
- `member?/2` for membership testing
- `remove/2` for deletion (counting filters only)
- `union/2` and `union_all/1` for merging filters
- `intersect_all/1` for filter intersection
- `batch_member?/2` for bulk membership testing
- `from_list/2` for creating filters from lists
- `jaccard_similarity/2` for similarity calculation
- `clear/1` for resetting filters

#### Persistence
- Binary serialization with `to_binary/2` and `from_binary/2`
- File I/O with `save/3` and `load/2`
- Optional compression support for reduced storage

#### Monitoring
- `info/1` returns comprehensive statistics:
  - Filter type, capacity, and size
  - Item count and fill ratio
  - Target and actual false positive rates
  - Backend information
  - Bits per item ratio

#### Testing & Quality
- Comprehensive test suite with 9 tests covering all filter types
- Standard bloom filter tests (create, add, batch ops, union, clear, from_list)
- Counting bloom filter deletion tests
- Scalable bloom filter auto-scaling tests
- Serialization tests

#### Documentation
- Extensive README with usage examples for all filter types
- API documentation with examples
- Performance comparison guidelines
- EXLA backend setup instructions
- Real-world use case examples

### Fixed
- **Critical**: Nx tensor backend mismatch in `BitArray` operations causing silent failures
  - Added `Nx.backend_transfer/2` calls in `set/2`, `all_set?/2`, and `get/2` functions
  - Ensures indices tensors match bit array backend before operations
  - Fixes issue where items couldn't be found after being added
- Fixed 5 compiler warnings:
  - Multi-clause function with default values (`train/3`)
  - Unused variables in `jaccard_similarity/2`
  - Dead code in `check_compatibility/1`
  - Unused alias in scalable filter module

### Dependencies
- **Required**: `nx ~> 0.10.0` - Numerical computing library
- **Optional**: `exla ~> 0.10.0` - Accelerated Linear Algebra (recommended for performance)
- **Optional**: `scholar ~> 0.4.0` - Machine learning (required for learned filters)
- **Development**: `ex_doc ~> 0.34` - Documentation generation
- **Development**: `benchee ~> 1.3` - Benchmarking

### Technical Details
- Elixir: ~> 1.18
- License: Apache 2.0
- Hash functions: MurmurHash3 + FNV-1a with double hashing
- Storage: Nx tensors (`:u8` for bits, `:u8/:u16/:u32` for counters)
- Optimal parameter calculation using bloom filter mathematics

[Unreleased]: https://github.com/nyo16/bloomy/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nyo16/bloomy/releases/tag/v0.1.0
