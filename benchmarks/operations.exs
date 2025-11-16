# Benchmark merge operations and advanced features
#
# Run with: mix run benchmarks/operations.exs

test_items_1 = Enum.map(1..1_000, &"user_#{&1}")
test_items_2 = Enum.map(1001..2_000, &"user_#{&1}")
test_items_3 = Enum.map(2001..3_000, &"user_#{&1}")

IO.puts("=== Benchmarking Union Operations ===\n")

# Pre-create filters for union tests
filter1 = Bloomy.new(10_000) |> Bloomy.add_all(test_items_1)
filter2 = Bloomy.new(10_000) |> Bloomy.add_all(test_items_2)
filter3 = Bloomy.new(10_000) |> Bloomy.add_all(test_items_3)

Benchee.run(
  %{
    "union of 2 filters (1K items each)" => fn ->
      Bloomy.union(filter1, filter2)
    end,
    "union of 3 filters (1K items each)" => fn ->
      Bloomy.union_all([filter1, filter2, filter3])
    end,
    "union of 5 filters" => fn ->
      filters = [filter1, filter2, filter3, filter1, filter2]
      Bloomy.union_all(filters)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Intersection Operations ===\n")

# Create filters with overlapping data
overlap_items = Enum.map(1..500, &"common_#{&1}")
filter_a = Bloomy.new(10_000) |> Bloomy.add_all(Enum.concat(test_items_1, overlap_items))
filter_b = Bloomy.new(10_000) |> Bloomy.add_all(Enum.concat(test_items_2, overlap_items))

Benchee.run(
  %{
    "intersect 2 filters (50% overlap)" => fn ->
      Bloomy.intersect_all([filter_a, filter_b])
    end,
    "intersect 3 filters" => fn ->
      Bloomy.intersect_all([filter_a, filter_b, filter1])
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Similarity Calculations ===\n")

# Create filters with different similarity levels
similar_a = Bloomy.new(10_000) |> Bloomy.add_all(Enum.take(test_items_1, 800))
similar_b = Bloomy.new(10_000) |> Bloomy.add_all(Enum.concat(Enum.take(test_items_1, 600), Enum.take(test_items_2, 200)))
dissimilar_c = Bloomy.new(10_000) |> Bloomy.add_all(test_items_2)

Benchee.run(
  %{
    "jaccard_similarity (high similarity)" => fn ->
      Bloomy.jaccard_similarity(similar_a, similar_b)
    end,
    "jaccard_similarity (low similarity)" => fn ->
      Bloomy.jaccard_similarity(similar_a, dissimilar_c)
    end,
    "overlap_coefficient" => fn ->
      Bloomy.Operations.overlap_coefficient(similar_a, similar_b)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking from_list Convenience Function ===\n")

small_list = Enum.to_list(1..100)
medium_list = Enum.to_list(1..1_000)
large_list = Enum.to_list(1..10_000)

Benchee.run(
  %{
    "from_list with 100 items" => fn ->
      Bloomy.from_list(small_list)
    end,
    "from_list with 1,000 items" => fn ->
      Bloomy.from_list(medium_list)
    end,
    "from_list with 10,000 items" => fn ->
      Bloomy.from_list(large_list)
    end,
    "from_list with 1K items (counting)" => fn ->
      Bloomy.from_list(medium_list, type: :counting)
    end,
    "from_list with 1K items (scalable)" => fn ->
      Bloomy.from_list(medium_list, type: :scalable)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

IO.puts("\n=== Benchmarking Batch Member? vs Individual Queries ===\n")

test_filter = Bloomy.new(10_000) |> Bloomy.add_all(test_items_1)
query_list = Enum.take(test_items_1, 100)

Benchee.run(
  %{
    "100 individual member? calls" => fn ->
      Enum.each(query_list, &Bloomy.member?(test_filter, &1))
    end,
    "batch_member? with 100 items" => fn ->
      Bloomy.batch_member?(test_filter, query_list)
    end,
    "100 individual member? (map result)" => fn ->
      Enum.map(query_list, &{&1, Bloomy.member?(test_filter, &1)}) |> Map.new()
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)
