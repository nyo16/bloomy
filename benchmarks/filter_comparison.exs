# Benchmark comparing different bloom filter types
#
# Run with: mix run benchmarks/filter_comparison.exs

test_items = Enum.map(1..1_000, &"item_#{&1}")
query_items = Enum.map(1..100, &"query_#{&1}")

IO.puts("=== Comparing Bloom Filter Types ===\n")

Benchee.run(
  %{
    "Standard: create + add 1K items" => fn ->
      filter = Bloomy.new(10_000, type: :standard)
      Bloomy.add_all(filter, test_items)
    end,
    "Counting: create + add 1K items" => fn ->
      filter = Bloomy.new(10_000, type: :counting)
      Bloomy.add_all(filter, test_items)
    end,
    "Scalable: create + add 1K items" => fn ->
      filter = Bloomy.new(1_000, type: :scalable)
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

IO.puts("\n=== Comparing Query Performance ===\n")

# Pre-create filters
standard_filter = Bloomy.new(10_000, type: :standard) |> Bloomy.add_all(test_items)
counting_filter = Bloomy.new(10_000, type: :counting) |> Bloomy.add_all(test_items)
scalable_filter = Bloomy.new(1_000, type: :scalable) |> Bloomy.add_all(test_items)

Benchee.run(
  %{
    "Standard: 100 member? queries" => fn ->
      Enum.each(query_items, &Bloomy.member?(standard_filter, &1))
    end,
    "Counting: 100 member? queries" => fn ->
      Enum.each(query_items, &Bloomy.member?(counting_filter, &1))
    end,
    "Scalable: 100 member? queries" => fn ->
      Enum.each(query_items, &Bloomy.member?(scalable_filter, &1))
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Counting Filter: Remove Operations ===\n")

Benchee.run(
  %{
    "add item" => fn ->
      filter = Bloomy.new(10_000, type: :counting)
      Bloomy.add(filter, "test_item")
    end,
    "add + remove item" => fn ->
      filter = Bloomy.new(10_000, type: :counting)
      filter = Bloomy.add(filter, "test_item")
      Bloomy.remove(filter, "test_item")
    end,
    "add 100 + remove 50" => fn ->
      filter = Bloomy.new(10_000, type: :counting)
      filter = Bloomy.add_all(filter, Enum.take(test_items, 100))
      Enum.reduce(Enum.take(test_items, 50), filter, fn item, f ->
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

IO.puts("\n=== Scalable Filter: Auto-scaling Behavior ===\n")

Benchee.run(
  %{
    "add items without scaling (500 items, 1K capacity)" => fn ->
      filter = Bloomy.new(1_000, type: :scalable)
      Bloomy.add_all(filter, Enum.take(test_items, 500))
    end,
    "add items with scaling (2K items, 1K capacity)" => fn ->
      filter = Bloomy.new(1_000, type: :scalable)
      Bloomy.add_all(filter, Enum.concat(test_items, test_items))
    end,
    "add items with multiple scales (5K items, 500 capacity)" => fn ->
      filter = Bloomy.new(500, type: :scalable)
      items = Enum.flat_map(1..5, fn _ -> test_items end)
      Bloomy.add_all(filter, items)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Memory Usage Comparison ===\n")

Benchee.run(
  %{
    "Standard filter (10K capacity)" => fn ->
      Bloomy.new(10_000, type: :standard)
    end,
    "Counting filter 8-bit (10K capacity)" => fn ->
      Bloomy.new(10_000, type: :counting, counter_width: 8)
    end,
    "Counting filter 16-bit (10K capacity)" => fn ->
      Bloomy.new(10_000, type: :counting, counter_width: 16)
    end,
    "Counting filter 32-bit (10K capacity)" => fn ->
      Bloomy.new(10_000, type: :counting, counter_width: 32)
    end,
    "Scalable filter (1K initial capacity)" => fn ->
      Bloomy.new(1_000, type: :scalable)
    end
  },
  time: 3,
  memory_time: 2,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console
  ]
)
