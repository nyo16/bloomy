# Bloomy 🌸

**High-performance Bloom Filter library for Elixir, powered by Nx**

Bloomy provides probabilistic data structures for efficient set membership testing with minimal memory usage. Built on Nx tensors for blazing-fast performance with optional EXLA/GPU acceleration.

[![Elixir](https://img.shields.io/badge/elixir-%3E%3D%201.18-purple)](https://elixir-lang.org/)
[![Nx](https://img.shields.io/badge/nx-0.10-blue)](https://github.com/elixir-nx/nx)

## Features

- 🚀 **High Performance** - Nx tensor operations with EXLA/GPU acceleration
- 🎯 **Multiple Types** - Standard, Counting (with deletion), Scalable (auto-grows), Learned (ML-enhanced)
- 💾 **Persistence** - Serialization with optional compression
- 🔀 **Merge Operations** - Union/intersection for distributed systems
- 📊 **Rich Statistics** - Comprehensive monitoring and metrics
- 🎓 **Well Documented** - Extensive docs and examples

## Installation

Add `bloomy` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bloomy, "~> 0.1.0"},
    {:nx, "~> 0.10.0"},
    {:exla, "~> 0.10.0"}  # Optional but recommended for performance
  ]
end
```

## Quick Start

```elixir
# Create a bloom filter for 10,000 items with 1% false positive rate
filter = Bloomy.new(10_000, false_positive_rate: 0.01)

# Add items
filter = filter
  |> Bloomy.add("user@example.com")
  |> Bloomy.add("alice@example.com")
  |> Bloomy.add("bob@example.com")

# Check membership
Bloomy.member?(filter, "user@example.com")  # => true
Bloomy.member?(filter, "other@example.com") # => false

# Get statistics
Bloomy.info(filter)
# => %{
#   type: :standard,
#   capacity: 10000,
#   items_count: 3,
#   fill_ratio: 0.0021,
#   false_positive_rate: 0.01,
#   ...
# }
```

## Bloom Filter Types

### Standard Bloom Filter

Classic space-efficient probabilistic set membership test.

```elixir
filter = Bloomy.new(10_000)
filter = Bloomy.add(filter, "apple")
Bloomy.member?(filter, "apple")  # => true
```

### Counting Bloom Filter

Supports deletion operations using counters instead of bits.

```elixir
filter = Bloomy.new(10_000, type: :counting)

filter = Bloomy.add(filter, "item")
Bloomy.member?(filter, "item")  # => true

filter = Bloomy.remove(filter, "item")
Bloomy.member?(filter, "item")  # => false
```

### Scalable Bloom Filter

Automatically grows to maintain target false positive rate.

```elixir
filter = Bloomy.new(1_000, type: :scalable)

# Add millions of items - it will automatically scale!
filter = Enum.reduce(1..1_000_000, filter, fn i, f ->
  Bloomy.add(f, "item_#{i}")
end)

info = Bloomy.info(filter)
info.slices_count  # => Multiple slices created automatically
```

### Learned Bloom Filter

ML-enhanced filter with lower false positive rates.

```elixir
filter = Bloomy.new(10_000, type: :learned)

# Train with positive and negative examples
training_data = %{
  positive: ["valid_user_1", "valid_user_2", "valid_user_3"],
  negative: ["spam_1", "spam_2", "spam_3"]
}

filter = Bloomy.train(filter, training_data)
filter = Bloomy.add(filter, "valid_user_1")

Bloomy.member?(filter, "valid_user_1")  # => true (uses ML model + backup filter)
```

## Performance: Using EXLA Backend

### Why EXLA?

EXLA provides significant performance improvements (2-20x faster) by:
- JIT compilation of numerical operations
- CPU/GPU acceleration
- Optimized tensor operations

### Option 1: Set Default Backend (Recommended)

In your `config/config.exs`:

```elixir
# Use EXLA with CPU
config :nx, default_backend: EXLA.Backend

# Or use EXLA with GPU (if CUDA is available)
config :nx, default_backend: {EXLA.Backend, client: :cuda}

# Or use EXLA with specific device
config :nx, default_backend: {EXLA.Backend, client: :cuda, device_id: 0}
```

### Option 2: Per-Filter Backend

Specify backend when creating filters:

```elixir
# Use EXLA backend for this filter
filter = Bloomy.new(100_000, backend: EXLA.Backend)

# Use BinaryBackend (default, no compilation)
filter = Bloomy.new(100_000, backend: Nx.BinaryBackend)
```

### Option 3: Runtime Backend Selection

```elixir
# Set backend at runtime
Nx.default_backend(EXLA.Backend)

# All filters created after this will use EXLA
filter = Bloomy.new(100_000)
```

### GPU Acceleration

To use GPU acceleration (requires CUDA):

```elixir
# In config/config.exs
config :nx, default_backend: {EXLA.Backend, client: :cuda}

# Or at runtime
Nx.default_backend({EXLA.Backend, client: :cuda})

# Create filter - will automatically use GPU
filter = Bloomy.new(1_000_000)
```

### Backend Performance Comparison

Run the backend comparison benchmark:

```bash
mix run benchmarks/backend_comparison.exs
```

**Typical Performance Gains:**
- Small filters (<10K): ~1.5x faster
- Medium filters (10K-100K): 2-5x faster
- Large filters (>100K): 5-10x faster
- Batch operations: 10-20x faster
- GPU (large filters): 20-50x faster

## Operations

### Batch Operations

```elixir
# Add multiple items efficiently
filter = Bloomy.add_all(filter, ["apple", "banana", "orange"])

# Batch membership testing
results = Bloomy.batch_member?(filter, ["apple", "grape", "banana"])
# => %{"apple" => true, "grape" => false, "banana" => true}

# Create from list
filter = Bloomy.from_list(["a", "b", "c", "d"])
```

### Merge Operations

```elixir
# Union (merge) filters
f1 = Bloomy.new(10_000) |> Bloomy.add("apple")
f2 = Bloomy.new(10_000) |> Bloomy.add("banana")

merged = Bloomy.union(f1, f2)
Bloomy.member?(merged, "apple")   # => true
Bloomy.member?(merged, "banana")  # => true

# Union multiple filters
filters = [filter1, filter2, filter3]
merged = Bloomy.union_all(filters)

# Intersection
intersected = Bloomy.intersect_all([filter1, filter2])
```

### Similarity Metrics

```elixir
# Calculate Jaccard similarity
similarity = Bloomy.jaccard_similarity(filter1, filter2)
# => 0.75 (75% similar)

# Calculate overlap coefficient
overlap = Bloomy.Operations.overlap_coefficient(filter1, filter2)
```

## Persistence

### Binary Serialization

```elixir
# Serialize to binary
binary = Bloomy.to_binary(filter)

# With compression (recommended for large filters)
binary = Bloomy.to_binary(filter, compress: true)

# Deserialize
{:ok, loaded_filter} = Bloomy.from_binary(binary)
```

### File I/O

```elixir
# Save to file
:ok = Bloomy.save(filter, "my_filter.bloom")

# Save with compression
:ok = Bloomy.save(filter, "my_filter.bloom", compress: true)

# Load from file
{:ok, filter} = Bloomy.load("my_filter.bloom")
```

## Benchmarking

Run the included benchmarks to see performance on your system:

```bash
# Basic operations (add, member?, batch operations)
mix run benchmarks/basic_operations.exs

# Compare filter types (Standard, Counting, Scalable)
mix run benchmarks/filter_comparison.exs

# Merge operations (union, intersection, similarity)
mix run benchmarks/operations.exs

# Serialization and persistence
mix run benchmarks/serialization.exs

# Backend comparison (BinaryBackend vs EXLA)
mix run benchmarks/backend_comparison.exs
```

## Configuration Options

### Creating Filters

```elixir
Bloomy.new(capacity, opts)
```

**Common Options:**
- `:type` - Filter type: `:standard`, `:counting`, `:scalable`, `:learned` (default: `:standard`)
- `:false_positive_rate` - Target false positive rate (default: `0.01` or 1%)
- `:backend` - Nx backend: `Nx.BinaryBackend`, `EXLA.Backend` (default: `Nx.default_backend()`)

**Counting Filter Options:**
- `:counter_width` - Bits per counter: `8`, `16`, `32` (default: `8`)

**Scalable Filter Options:**
- `:growth_factor` - Capacity multiplier for new slices (default: `2`)
- `:error_tightening_ratio` - Error rate multiplier (default: `0.8`)

**Learned Filter Options:**
- `:confidence_threshold` - Model confidence threshold (default: `0.7`)

### Examples

```elixir
# Standard with custom false positive rate
filter = Bloomy.new(10_000, false_positive_rate: 0.001)

# Counting with 16-bit counters and EXLA
filter = Bloomy.new(10_000,
  type: :counting,
  counter_width: 16,
  backend: EXLA.Backend
)

# Scalable with custom growth
filter = Bloomy.new(1_000,
  type: :scalable,
  growth_factor: 3,
  error_tightening_ratio: 0.5
)
```

## Use Cases

### Web Application - User Session Tracking

```elixir
# Track active sessions
defmodule SessionTracker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    # 1M sessions, 0.1% false positive rate, use EXLA for speed
    filter = Bloomy.new(1_000_000,
      false_positive_rate: 0.001,
      backend: EXLA.Backend
    )
    {:ok, filter}
  end

  def track_session(session_id) do
    GenServer.cast(__MODULE__, {:track, session_id})
  end

  def active?(session_id) do
    GenServer.call(__MODULE__, {:check, session_id})
  end

  def handle_cast({:track, session_id}, filter) do
    {:noreply, Bloomy.add(filter, session_id)}
  end

  def handle_call({:check, session_id}, _from, filter) do
    {:reply, Bloomy.member?(filter, session_id), filter}
  end
end
```

### Distributed System - Seen Items Cache

```elixir
# Track which items have been processed across nodes
defmodule DistributedCache do
  def merge_caches(node_filters) do
    # Collect filters from all nodes
    filters = Enum.map(node_filters, & &1)

    # Merge into single filter
    merged = Bloomy.union_all(filters)

    # Distribute back to all nodes
    distribute_filter(merged)
  end

  def sync_filter(local_filter) do
    # Save filter to shared storage
    Bloomy.save(local_filter, "/shared/cache.bloom", compress: true)
  end

  def load_filter do
    case Bloomy.load("/shared/cache.bloom") do
      {:ok, filter} -> filter
      {:error, _} -> Bloomy.new(1_000_000)
    end
  end
end
```

### Data Pipeline - Deduplication

```elixir
defmodule Deduplicator do
  def process_stream(stream) do
    initial_filter = Bloomy.new(10_000_000, type: :scalable)

    Stream.transform(stream, initial_filter, fn item, filter ->
      if Bloomy.member?(filter, item.id) do
        # Skip duplicate
        {[], filter}
      else
        # New item, add to filter and pass through
        {[item], Bloomy.add(filter, item.id)}
      end
    end)
  end
end
```

## Performance Tips

1. **Use EXLA Backend** - Significant performance improvement (2-20x faster)
   ```elixir
   config :nx, default_backend: EXLA.Backend
   ```

2. **Choose Appropriate Capacity** - Overestimate slightly for better performance
   ```elixir
   # If expecting ~10K items, use 15K capacity
   filter = Bloomy.new(15_000)
   ```

3. **Batch Operations** - Use `add_all` and `batch_member?` for multiple items
   ```elixir
   # Fast: single batch operation
   filter = Bloomy.add_all(filter, items)

   # Slower: many individual operations
   filter = Enum.reduce(items, filter, &Bloomy.add(&2, &1))
   ```

4. **Use Scalable for Unknown Sizes** - Automatically adapts to data volume
   ```elixir
   filter = Bloomy.new(1_000, type: :scalable)
   ```

5. **Serialize with Compression** - Reduces storage/network overhead
   ```elixir
   Bloomy.save(filter, "cache.bloom", compress: true)
   ```

## How It Works

### Bloom Filters

A Bloom filter is a space-efficient probabilistic data structure that tests whether an element is a member of a set:
- **False positives** are possible (item might be in set)
- **False negatives** are impossible (if not found, definitely not in set)
- Uses multiple hash functions to set/check bits in an array

### Mathematical Foundation

- **Optimal bit array size**: `m = -(n * ln(p)) / (ln(2)^2)`
- **Optimal hash functions**: `k = (m / n) * ln(2)`
- **False positive rate**: `p = (1 - e^(-kn/m))^k`

Where:
- `n` = number of items
- `p` = false positive rate
- `m` = bit array size
- `k` = number of hash functions

### Implementation Details

- **Hash Functions**: MurmurHash3 + FNV-1a with double hashing technique
- **Storage**: Nx tensors (`:u8` for bits, `:u8/:u16/:u32` for counters)
- **Acceleration**: EXLA JIT compilation for vectorized operations
- **ML**: Simple neural network for learned filters

## API Reference

### Main Functions

- `new/2` - Create new bloom filter
- `add/2` - Add item to filter
- `add_all/2` - Add multiple items
- `member?/2` - Check if item might be in set
- `remove/2` - Remove item (counting filters only)
- `clear/1` - Reset filter to empty state
- `info/1` - Get statistics and metadata

### Operations

- `union/2`, `union_all/1` - Merge filters
- `intersect_all/1` - Intersect filters
- `batch_member?/2` - Test multiple items
- `from_list/2` - Create filter from list
- `jaccard_similarity/2` - Calculate similarity

### Persistence

- `save/3` - Save to file
- `load/2` - Load from file
- `to_binary/2` - Serialize to binary
- `from_binary/2` - Deserialize from binary

### ML (Learned Filters)

- `train/3` - Train model on examples

## Testing

Run the test suite:

```bash
mix test
```

Run the integration tests:

```bash
mix run test_bloomy.exs
```

## License

MIT License

## Acknowledgments

- Built with [Nx](https://github.com/elixir-nx/nx) - Numerical computing library
- Uses [EXLA](https://github.com/elixir-nx/nx/tree/main/exla) - Accelerated Linear Algebra
- ML features powered by [Scholar](https://github.com/elixir-nx/scholar)
- Inspired by classical bloom filter research and "The Case for Learned Index Structures"

## Resources

- [Bloom Filter on Wikipedia](https://en.wikipedia.org/wiki/Bloom_filter)
- [Nx Documentation](https://hexdocs.pm/nx)
- [EXLA Documentation](https://hexdocs.pm/exla)
- [Space/Time Trade-offs in Hash Coding with Allowable Errors](https://dl.acm.org/doi/10.1145/362686.362692) - Original paper

---

Made with ❤️ and Elixir
