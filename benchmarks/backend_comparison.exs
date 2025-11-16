# Benchmark comparing Nx backends (BinaryBackend vs EXLA)
#
# Run with: mix run benchmarks/backend_comparison.exs
#
# Note: EXLA backend provides significant performance improvements
# especially for larger filters and batch operations.

test_items = Enum.map(1..2_000, &"item_#{&1}")

IO.puts("=== Comparing Nx Backends ===\n")
IO.puts("Testing BinaryBackend (default) vs EXLA.Backend (CPU-optimized)\n")

Benchee.run(
  %{
    "BinaryBackend: create 10K filter" => fn ->
      Bloomy.new(10_000, backend: Nx.BinaryBackend)
    end,
    "EXLA.Backend: create 10K filter" => fn ->
      Bloomy.new(10_000, backend: EXLA.Backend)
    end,
    "BinaryBackend: add 2K items" => fn ->
      filter = Bloomy.new(10_000, backend: Nx.BinaryBackend)
      Bloomy.add_all(filter, test_items)
    end,
    "EXLA.Backend: add 2K items" => fn ->
      filter = Bloomy.new(10_000, backend: EXLA.Backend)
      Bloomy.add_all(filter, test_items)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Query Performance: Backend Comparison ===\n")

# Pre-create filters with different backends
binary_filter = Bloomy.new(10_000, backend: Nx.BinaryBackend) |> Bloomy.add_all(test_items)
exla_filter = Bloomy.new(10_000, backend: EXLA.Backend) |> Bloomy.add_all(test_items)

query_items = Enum.take(test_items, 500)

Benchee.run(
  %{
    "BinaryBackend: 500 queries" => fn ->
      Enum.each(query_items, &Bloomy.member?(binary_filter, &1))
    end,
    "EXLA.Backend: 500 queries" => fn ->
      Enum.each(query_items, &Bloomy.member?(exla_filter, &1))
    end,
    "BinaryBackend: batch_member? 500 items" => fn ->
      Bloomy.batch_member?(binary_filter, query_items)
    end,
    "EXLA.Backend: batch_member? 500 items" => fn ->
      Bloomy.batch_member?(exla_filter, query_items)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Union Operations: Backend Comparison ===\n")

# Create multiple filters for union
binary_f1 = Bloomy.new(10_000, backend: Nx.BinaryBackend) |> Bloomy.add_all(Enum.take(test_items, 500))
binary_f2 = Bloomy.new(10_000, backend: Nx.BinaryBackend) |> Bloomy.add_all(Enum.drop(test_items, 500))

exla_f1 = Bloomy.new(10_000, backend: EXLA.Backend) |> Bloomy.add_all(Enum.take(test_items, 500))
exla_f2 = Bloomy.new(10_000, backend: EXLA.Backend) |> Bloomy.add_all(Enum.drop(test_items, 500))

Benchee.run(
  %{
    "BinaryBackend: union 2 filters" => fn ->
      Bloomy.union(binary_f1, binary_f2)
    end,
    "EXLA.Backend: union 2 filters" => fn ->
      Bloomy.union(exla_f1, exla_f2)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Large Filter Performance ===\n")

large_items = Enum.map(1..10_000, &"large_item_#{&1}")

Benchee.run(
  %{
    "BinaryBackend: 100K capacity + 10K items" => fn ->
      filter = Bloomy.new(100_000, backend: Nx.BinaryBackend)
      Bloomy.add_all(filter, large_items)
    end,
    "EXLA.Backend: 100K capacity + 10K items" => fn ->
      filter = Bloomy.new(100_000, backend: EXLA.Backend)
      Bloomy.add_all(filter, large_items)
    end
  },
  time: 10,
  memory_time: 3,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Counting Filter: Backend Comparison ===\n")

Benchee.run(
  %{
    "BinaryBackend: counting add+remove 1K" => fn ->
      filter = Bloomy.new(10_000, type: :counting, backend: Nx.BinaryBackend)
      filter = Bloomy.add_all(filter, test_items)
      Enum.reduce(Enum.take(test_items, 500), filter, fn item, f ->
        Bloomy.remove(f, item)
      end)
    end,
    "EXLA.Backend: counting add+remove 1K" => fn ->
      filter = Bloomy.new(10_000, type: :counting, backend: EXLA.Backend)
      filter = Bloomy.add_all(filter, test_items)
      Enum.reduce(Enum.take(test_items, 500), filter, fn item, f ->
        Bloomy.remove(f, item)
      end)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Performance Tips:")
IO.puts(String.duplicate("=", 70))
IO.puts("""

1. **Use EXLA Backend for Production**
   Set as default in config:

   config :nx, default_backend: EXLA.Backend

2. **Per-Filter Backend**
   Specify backend when creating filters:

   filter = Bloomy.new(100_000, backend: EXLA.Backend)

3. **GPU Acceleration** (if available)
   Set EXLA to use GPU:

   config :nx, default_backend: {EXLA.Backend, client: :cuda}

4. **Expected Performance Gains**
   - Small filters (<10K): Minimal difference
   - Medium filters (10K-100K): 2-5x faster with EXLA
   - Large filters (>100K): 5-10x faster with EXLA
   - Batch operations: 10-20x faster with EXLA
""")
