# Benchmark serialization and deserialization
#
# Run with: mix run benchmarks/serialization.exs

test_items = Enum.map(1..5_000, &"item_#{&1}")

# Create test filters
small_filter = Bloomy.new(1_000) |> Bloomy.add_all(Enum.take(test_items, 100))
medium_filter = Bloomy.new(10_000) |> Bloomy.add_all(Enum.take(test_items, 1_000))
large_filter = Bloomy.new(100_000) |> Bloomy.add_all(test_items)

counting_filter = Bloomy.new(10_000, type: :counting) |> Bloomy.add_all(Enum.take(test_items, 1_000))
scalable_filter = Bloomy.new(1_000, type: :scalable) |> Bloomy.add_all(test_items)

IO.puts("=== Benchmarking Serialization to Binary ===\n")

Benchee.run(
  %{
    "to_binary: small filter (1K capacity, 100 items)" => fn ->
      Bloomy.to_binary(small_filter)
    end,
    "to_binary: medium filter (10K capacity, 1K items)" => fn ->
      Bloomy.to_binary(medium_filter)
    end,
    "to_binary: large filter (100K capacity, 5K items)" => fn ->
      Bloomy.to_binary(large_filter)
    end,
    "to_binary: counting filter (10K, 1K items)" => fn ->
      Bloomy.to_binary(counting_filter)
    end,
    "to_binary: scalable filter (multiple slices)" => fn ->
      Bloomy.to_binary(scalable_filter)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Serialization with Compression ===\n")

Benchee.run(
  %{
    "to_binary without compression (10K)" => fn ->
      Bloomy.to_binary(medium_filter, compress: false)
    end,
    "to_binary with compression (10K)" => fn ->
      Bloomy.to_binary(medium_filter, compress: true)
    end,
    "to_binary without compression (100K)" => fn ->
      Bloomy.to_binary(large_filter, compress: false)
    end,
    "to_binary with compression (100K)" => fn ->
      Bloomy.to_binary(large_filter, compress: true)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Deserialization ===\n")

# Pre-serialize filters
small_binary = Bloomy.to_binary(small_filter)
medium_binary = Bloomy.to_binary(medium_filter)
large_binary = Bloomy.to_binary(large_filter)
counting_binary = Bloomy.to_binary(counting_filter)
compressed_binary = Bloomy.to_binary(medium_filter, compress: true)

Benchee.run(
  %{
    "from_binary: small filter (1K)" => fn ->
      Bloomy.from_binary(small_binary)
    end,
    "from_binary: medium filter (10K)" => fn ->
      Bloomy.from_binary(medium_binary)
    end,
    "from_binary: large filter (100K)" => fn ->
      Bloomy.from_binary(large_binary)
    end,
    "from_binary: counting filter" => fn ->
      Bloomy.from_binary(counting_binary)
    end,
    "from_binary: compressed filter" => fn ->
      Bloomy.from_binary(compressed_binary)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Round-trip Serialization ===\n")

Benchee.run(
  %{
    "round-trip: serialize + deserialize (small)" => fn ->
      binary = Bloomy.to_binary(small_filter)
      {:ok, _filter} = Bloomy.from_binary(binary)
    end,
    "round-trip: serialize + deserialize (medium)" => fn ->
      binary = Bloomy.to_binary(medium_filter)
      {:ok, _filter} = Bloomy.from_binary(binary)
    end,
    "round-trip: with compression (medium)" => fn ->
      binary = Bloomy.to_binary(medium_filter, compress: true)
      {:ok, _filter} = Bloomy.from_binary(binary)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Binary Size Comparison ===\n")

IO.puts("\nFilter Size Analysis:")
IO.puts("Small filter (1K capacity):")
IO.puts("  - Uncompressed: #{byte_size(Bloomy.to_binary(small_filter))} bytes")
IO.puts("  - Compressed:   #{byte_size(Bloomy.to_binary(small_filter, compress: true))} bytes")

IO.puts("\nMedium filter (10K capacity):")
IO.puts("  - Uncompressed: #{byte_size(Bloomy.to_binary(medium_filter))} bytes")
IO.puts("  - Compressed:   #{byte_size(Bloomy.to_binary(medium_filter, compress: true))} bytes")

IO.puts("\nLarge filter (100K capacity):")
IO.puts("  - Uncompressed: #{byte_size(Bloomy.to_binary(large_filter))} bytes")
IO.puts("  - Compressed:   #{byte_size(Bloomy.to_binary(large_filter, compress: true))} bytes")

IO.puts("\nCounting filter (10K capacity, 8-bit counters):")
IO.puts("  - Uncompressed: #{byte_size(Bloomy.to_binary(counting_filter))} bytes")
IO.puts("  - Compressed:   #{byte_size(Bloomy.to_binary(counting_filter, compress: true))} bytes")

# Temporary file paths for file I/O tests
tmp_path = "/tmp/bloomy_bench_filter.bloom"

IO.puts("\n=== Benchmarking File I/O ===\n")

Benchee.run(
  %{
    "save to file (medium filter)" => fn ->
      Bloomy.save(medium_filter, tmp_path)
    end,
    "load from file (medium filter)" => fn ->
      Bloomy.load(tmp_path)
    end,
    "save with compression" => fn ->
      Bloomy.save(medium_filter, tmp_path, compress: true)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ],
  after_each: fn _ ->
    # Clean up temp file
    File.rm(tmp_path)
  end
)
