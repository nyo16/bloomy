# Benchmark basic bloom filter operations
#
# Run with: mix run benchmarks/basic_operations.exs

# Setup test data
small_items = Enum.map(1..100, &"item_#{&1}")
medium_items = Enum.map(1..1_000, &"item_#{&1}")
large_items = Enum.map(1..10_000, &"item_#{&1}")

IO.puts("=== Benchmarking Basic Bloom Filter Operations ===\n")

Benchee.run(
  %{
    "add single item (1K capacity)" => fn ->
      filter = Bloomy.new(1_000)
      Bloomy.add(filter, "test_item")
    end,
    "add single item (10K capacity)" => fn ->
      filter = Bloomy.new(10_000)
      Bloomy.add(filter, "test_item")
    end,
    "add single item (100K capacity)" => fn ->
      filter = Bloomy.new(100_000)
      Bloomy.add(filter, "test_item")
    end,
    "member? query (1K capacity, 100 items)" => fn ->
      filter = Bloomy.new(1_000)
      filter = Bloomy.add_all(filter, small_items)
      Bloomy.member?(filter, "item_50")
    end,
    "member? query (10K capacity, 1K items)" => fn ->
      filter = Bloomy.new(10_000)
      filter = Bloomy.add_all(filter, medium_items)
      Bloomy.member?(filter, "item_500")
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Batch Add Operations ===\n")

Benchee.run(
  %{
    "add 100 items (1K capacity)" => fn ->
      filter = Bloomy.new(1_000)
      Bloomy.add_all(filter, small_items)
    end,
    "add 1,000 items (10K capacity)" => fn ->
      filter = Bloomy.new(10_000)
      Bloomy.add_all(filter, medium_items)
    end,
    "add 10,000 items (100K capacity)" => fn ->
      filter = Bloomy.new(100_000)
      Bloomy.add_all(filter, large_items)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Batch Member? Operations ===\n")

# Pre-create filters for member? tests
filter_100 = Bloomy.new(1_000) |> Bloomy.add_all(small_items)
filter_1k = Bloomy.new(10_000) |> Bloomy.add_all(medium_items)
filter_10k = Bloomy.new(100_000) |> Bloomy.add_all(large_items)

Benchee.run(
  %{
    "batch_member? 100 items" => fn ->
      Bloomy.batch_member?(filter_100, small_items)
    end,
    "batch_member? 1,000 items" => fn ->
      Bloomy.batch_member?(filter_1k, medium_items)
    end,
    "batch_member? 10,000 items" => fn ->
      Bloomy.batch_member?(filter_10k, large_items)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)
