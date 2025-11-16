# Comprehensive test of all Bloomy features
# Run with: mix run comprehensive_test.exs

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("COMPREHENSIVE BLOOMY LIBRARY TEST")
IO.puts(String.duplicate("=", 80) <> "\n")

test_results = []

# Helper assertion function
assert.= fn
  true -> :ok
  false -> raise "Assertion failed"
  condition when is_boolean(condition) -> if condition, do: :ok, else: raise "Assertion failed"
end

# Helper to track test results
track_test = fn name, test_fn ->
  IO.puts("\n📋 Testing: #{name}")
  try do
    test_fn.()
    IO.puts("   ✅ PASSED")
    {name, :passed}
  rescue
    e ->
      IO.puts("   ❌ FAILED: #{Exception.message(e)}")
      {name, {:failed, Exception.message(e)}}
  end
end

# ============================================================================
# 1. STANDARD BLOOM FILTER TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("1. STANDARD BLOOM FILTER")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Standard: Create and add", fn ->
  filter = Bloomy.new(1000)
  filter = Bloomy.add(filter, "test")
  assert.(Bloomy.member?(filter, "test") == true)
  assert.(Bloomy.member?(filter, "nothere") == false)
end) | test_results]

test_results = [track_test.("Standard: Batch operations", fn ->
  filter = Bloomy.new(1000)
  items = ["a", "b", "c", "d", "e"]
  filter = Bloomy.add_all(filter, items)

  # Check all items are present
  assert.Enum.all?(items, &Bloomy.member?(filter, &1))

  # Batch member?
  results = Bloomy.batch_member?(filter, ["a", "z"])
  assert.results["a"] == true
  assert.results["z"] == false
end) | test_results]

test_results = [track_test.("Standard: Info and statistics", fn ->
  filter = Bloomy.new(1000, false_positive_rate: 0.01)
  filter = Bloomy.add_all(filter, Enum.map(1..50, &"item_#{&1}"))

  info = Bloomy.info(filter)
  assert.info.type == :standard
  assert.info.capacity == 1000
  assert.info.items_count == 50
  assert.info.fill_ratio > 0
  assert.info.false_positive_rate == 0.01
end) | test_results]

test_results = [track_test.("Standard: Clear operation", fn ->
  filter = Bloomy.new(1000)
  filter = Bloomy.add(filter, "test")
  assert.Bloomy.member?(filter, "test") == true

  filter = Bloomy.clear(filter)
  assert.Bloomy.member?(filter, "test") == false

  info = Bloomy.info(filter)
  assert.info.items_count == 0
end) | test_results]

test_results = [track_test.("Standard: Union operation", fn ->
  f1 = Bloomy.new(1000) |> Bloomy.add("apple") |> Bloomy.add("banana")
  f2 = Bloomy.new(1000) |> Bloomy.add("orange") |> Bloomy.add("grape")

  merged = Bloomy.union(f1, f2)
  assert.Bloomy.member?(merged, "apple") == true
  assert.Bloomy.member?(merged, "orange") == true
end) | test_results]

test_results = [track_test.("Standard: Intersection operation", fn ->
  f1 = Bloomy.new(1000) |> Bloomy.add_all(["a", "b", "c"])
  f2 = Bloomy.new(1000) |> Bloomy.add_all(["b", "c", "d"])

  intersect = Bloomy.intersect_all([f1, f2])
  assert.Bloomy.member?(intersect, "b") == true
  assert.Bloomy.member?(intersect, "c") == true
end) | test_results]

# ============================================================================
# 2. COUNTING BLOOM FILTER TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("2. COUNTING BLOOM FILTER")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Counting: Create and add", fn ->
  filter = Bloomy.new(1000, type: :counting)
  filter = Bloomy.add(filter, "test")
  assert.Bloomy.member?(filter, "test") == true
end) | test_results]

test_results = [track_test.("Counting: Remove operation", fn ->
  filter = Bloomy.new(1000, type: :counting)
  filter = Bloomy.add(filter, "item1")
  assert.Bloomy.member?(filter, "item1") == true

  filter = Bloomy.remove(filter, "item1")
  assert.Bloomy.member?(filter, "item1") == false
end) | test_results]

test_results = [track_test.("Counting: Multiple add/remove", fn ->
  filter = Bloomy.new(1000, type: :counting)

  # Add same item multiple times
  filter = Bloomy.add(filter, "item")
  filter = Bloomy.add(filter, "item")
  assert.Bloomy.member?(filter, "item") == true

  # Remove once - should still be there
  filter = Bloomy.remove(filter, "item")
  assert.Bloomy.member?(filter, "item") == true

  # Remove again - should be gone
  filter = Bloomy.remove(filter, "item")
  assert.Bloomy.member?(filter, "item") == false
end) | test_results]

test_results = [track_test.("Counting: Different counter widths", fn ->
  f8 = Bloomy.new(1000, type: :counting, counter_width: 8)
  f16 = Bloomy.new(1000, type: :counting, counter_width: 16)
  f32 = Bloomy.new(1000, type: :counting, counter_width: 32)

  for filter <- [f8, f16, f32] do
    filter = Bloomy.add(filter, "test")
    assert.Bloomy.member?(filter, "test") == true
  end

  info8 = Bloomy.info(f8)
  info16 = Bloomy.info(f16)
  info32 = Bloomy.info(f32)

  assert.info8.counter_width == 8
  assert.info16.counter_width == 16
  assert.info32.counter_width == 32
end) | test_results]

test_results = [track_test.("Counting: Union operation", fn ->
  f1 = Bloomy.new(1000, type: :counting) |> Bloomy.add("a")
  f2 = Bloomy.new(1000, type: :counting) |> Bloomy.add("b")

  merged = Bloomy.Counting.union(f1, f2)
  assert.Bloomy.member?(merged, "a") == true
  assert.Bloomy.member?(merged, "b") == true
end) | test_results]

# ============================================================================
# 3. SCALABLE BLOOM FILTER TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("3. SCALABLE BLOOM FILTER")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Scalable: Create and add", fn ->
  filter = Bloomy.new(100, type: :scalable)
  filter = Bloomy.add(filter, "test")
  assert.Bloomy.member?(filter, "test") == true

  info = Bloomy.info(filter)
  assert.info.type == :scalable
  assert.info.slices_count == 1
end) | test_results]

test_results = [track_test.("Scalable: Auto-scaling behavior", fn ->
  filter = Bloomy.new(10, type: :scalable)

  # Add items to trigger scaling
  filter = Enum.reduce(1..50, filter, fn i, f ->
    Bloomy.add(f, "item_#{i}")
  end)

  info = Bloomy.info(filter)
  assert.info.slices_count > 1, "Expected multiple slices, got #{info.slices_count}"
  assert.info.items_count == 50

  # Verify all items are present
  assert.Bloomy.member?(filter, "item_1") == true
  assert.Bloomy.member?(filter, "item_50") == true
end) | test_results]

test_results = [track_test.("Scalable: Custom growth parameters", fn ->
  filter = Bloomy.new(10, type: :scalable, growth_factor: 3, error_tightening_ratio: 0.5)
  filter = Bloomy.add_all(filter, Enum.map(1..40, &"item_#{&1}"))

  info = Bloomy.info(filter)
  assert.info.growth_factor == 3
  assert.info.error_tightening_ratio == 0.5
end) | test_results]

# ============================================================================
# 4. LEARNED BLOOM FILTER TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("4. LEARNED BLOOM FILTER (ML)")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Learned: Create and train", fn ->
  filter = Bloomy.new(1000, type: :learned)

  training_data = %{
    positive: ["user_1", "user_2", "user_3", "user_4", "user_5"],
    negative: ["spam_1", "spam_2", "spam_3", "spam_4", "spam_5"]
  }

  filter = Bloomy.train(filter, training_data)

  info = Bloomy.info(filter)
  assert.info.type == :learned
  assert.info.trained == true
end) | test_results]

test_results = [track_test.("Learned: Add and query after training", fn ->
  filter = Bloomy.new(1000, type: :learned)

  training_data = %{
    positive: ["valid_1", "valid_2", "valid_3"],
    negative: ["invalid_1", "invalid_2", "invalid_3"]
  }

  filter = Bloomy.train(filter, training_data)
  filter = Bloomy.add(filter, "new_item")

  assert.Bloomy.member?(filter, "new_item") == true
end) | test_results]

test_results = [track_test.("Learned: Untrained fallback", fn ->
  filter = Bloomy.new(1000, type: :learned)
  filter = Bloomy.add(filter, "test")

  # Should work even without training (uses backup filter)
  assert.Bloomy.member?(filter, "test") == true
end) | test_results]

# ============================================================================
# 5. SERIALIZATION TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("5. SERIALIZATION & PERSISTENCE")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Serialization: to_binary/from_binary", fn ->
  filter = Bloomy.new(1000)
  filter = Bloomy.add_all(filter, ["a", "b", "c"])

  binary = Bloomy.to_binary(filter)
  assert.is_binary(binary)

  {:ok, loaded} = Bloomy.from_binary(binary)
  assert.Bloomy.member?(loaded, "a") == true
  assert.Bloomy.member?(loaded, "b") == true
  assert.Bloomy.member?(loaded, "c") == true
end) | test_results]

test_results = [track_test.("Serialization: with compression", fn ->
  filter = Bloomy.new(10_000)
  filter = Bloomy.add_all(filter, Enum.map(1..100, &"item_#{&1}"))

  uncompressed = Bloomy.to_binary(filter, compress: false)
  compressed = Bloomy.to_binary(filter, compress: true)

  assert.byte_size(compressed) < byte_size(uncompressed)

  {:ok, loaded} = Bloomy.from_binary(compressed)
  assert.Bloomy.member?(loaded, "item_50") == true
end) | test_results]

test_results = [track_test.("Serialization: file save/load", fn ->
  tmp_path = "/tmp/bloomy_test_#{:rand.uniform(10000)}.bloom"

  filter = Bloomy.new(1000)
  filter = Bloomy.add_all(filter, ["test1", "test2", "test3"])

  :ok = Bloomy.save(filter, tmp_path)
  assert.File.exists?(tmp_path)

  {:ok, loaded} = Bloomy.load(tmp_path)
  assert.Bloomy.member?(loaded, "test1") == true
  assert.Bloomy.member?(loaded, "test2") == true

  File.rm(tmp_path)
end) | test_results]

test_results = [track_test.("Serialization: all filter types", fn ->
  filters = [
    {:standard, Bloomy.new(1000)},
    {:counting, Bloomy.new(1000, type: :counting)},
    {:scalable, Bloomy.new(100, type: :scalable)}
  ]

  for {type, filter} <- filters do
    filter = Bloomy.add(filter, "test_#{type}")
    binary = Bloomy.to_binary(filter)
    {:ok, loaded} = Bloomy.from_binary(binary)
    assert.Bloomy.member?(loaded, "test_#{type}") == true
  end
end) | test_results]

# ============================================================================
# 6. ADVANCED OPERATIONS TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("6. ADVANCED OPERATIONS")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Operations: from_list", fn ->
  items = ["a", "b", "c", "d", "e"]
  filter = Bloomy.from_list(items)

  assert.Enum.all?(items, &Bloomy.member?(filter, &1))
end) | test_results]

test_results = [track_test.("Operations: union_all (multiple filters)", fn ->
  f1 = Bloomy.new(1000) |> Bloomy.add("a")
  f2 = Bloomy.new(1000) |> Bloomy.add("b")
  f3 = Bloomy.new(1000) |> Bloomy.add("c")

  merged = Bloomy.union_all([f1, f2, f3])

  assert.Bloomy.member?(merged, "a") == true
  assert.Bloomy.member?(merged, "b") == true
  assert.Bloomy.member?(merged, "c") == true
end) | test_results]

test_results = [track_test.("Operations: Jaccard similarity", fn ->
  f1 = Bloomy.new(1000) |> Bloomy.add_all(["a", "b", "c"])
  f2 = Bloomy.new(1000) |> Bloomy.add_all(["b", "c", "d"])

  similarity = Bloomy.jaccard_similarity(f1, f2)
  assert.is_float(similarity)
  assert.similarity > 0.0 and similarity <= 1.0
end) | test_results]

test_results = [track_test.("Operations: overlap coefficient", fn ->
  f1 = Bloomy.new(1000) |> Bloomy.add_all(["a", "b"])
  f2 = Bloomy.new(1000) |> Bloomy.add_all(["a", "b", "c", "d"])

  overlap = Bloomy.Operations.overlap_coefficient(f1, f2)
  assert.is_float(overlap)
  assert.overlap > 0.0 and overlap <= 1.0
end) | test_results]

test_results = [track_test.("Operations: batch_member?", fn ->
  filter = Bloomy.new(1000)
  filter = Bloomy.add_all(filter, ["a", "b", "c"])

  results = Bloomy.batch_member?(filter, ["a", "b", "z"])

  assert.is_map(results)
  assert.results["a"] == true
  assert.results["b"] == true
  assert.results["z"] == false
end) | test_results]

test_results = [track_test.("Operations: compatibility checking", fn ->
  f1 = Bloomy.new(1000)
  f2 = Bloomy.new(1000)
  f3 = Bloomy.new(2000)  # Different size

  assert.Bloomy.Operations.compatible?(f1, f2) == :ok
  assert.{:error, _} = Bloomy.Operations.compatible?(f1, f3)
end) | test_results]

# ============================================================================
# 7. BACKEND TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("7. BACKEND CONFIGURATION")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Backend: BinaryBackend", fn ->
  filter = Bloomy.new(1000, backend: Nx.BinaryBackend)
  filter = Bloomy.add(filter, "test")

  assert.Bloomy.member?(filter, "test") == true

  info = Bloomy.info(filter)
  assert.info.backend == Nx.BinaryBackend
end) | test_results]

test_results = [track_test.("Backend: EXLA.Backend", fn ->
  filter = Bloomy.new(1000, backend: EXLA.Backend)
  filter = Bloomy.add(filter, "test")

  assert.Bloomy.member?(filter, "test") == true

  info = Bloomy.info(filter)
  assert.info.backend == EXLA.Backend
end) | test_results]

# ============================================================================
# 8. PARAMETER CALCULATION TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("8. PARAMETER CALCULATIONS")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Params: optimal size calculation", fn ->
  size = Bloomy.Params.optimal_size(1000, 0.01)
  assert.size > 0
  assert.is_integer(size)
end) | test_results]

test_results = [track_test.("Params: optimal hash functions", fn ->
  k = Bloomy.Params.optimal_hash_functions(9586, 1000)
  assert.k > 0
  assert.is_integer(k)
end) | test_results]

test_results = [track_test.("Params: false positive rate calculation", fn ->
  rate = Bloomy.Params.calculate_false_positive_rate(9586, 7, 1000)
  assert.is_float(rate)
  assert.rate > 0.0 and rate < 1.0
end) | test_results]

test_results = [track_test.("Params: parameter validation", fn ->
  params = Bloomy.Params.calculate(1000, 0.01)
  assert.{:ok, ^params} = Bloomy.Params.validate(params)
end) | test_results]

# ============================================================================
# 9. HASH FUNCTION TESTS
# ============================================================================
IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("9. HASH FUNCTIONS")
IO.puts(String.duplicate("-", 80))

test_results = [track_test.("Hash: generate k hashes", fn ->
  hashes = Bloomy.Hash.hash("test", 5, 1000)

  assert.Nx.shape(hashes) == {5}

  hash_list = Nx.to_list(hashes)
  assert.length(hash_list) == 5
  assert.Enum.all?(hash_list, &(&1 >= 0 and &1 < 1000))
end) | test_results]

test_results = [track_test.("Hash: different items produce different hashes", fn ->
  hashes1 = Bloomy.Hash.hash("item1", 5, 1000)
  hashes2 = Bloomy.Hash.hash("item2", 5, 1000)

  list1 = Nx.to_list(hashes1)
  list2 = Nx.to_list(hashes2)

  # At least some hashes should be different
  assert.list1 != list2
end) | test_results]

test_results = [track_test.("Hash: to_binary conversion", fn ->
  assert.Bloomy.Hash.to_binary("string") == "string"
  assert.Bloomy.Hash.to_binary(:atom) == "atom"
  assert.is_binary(Bloomy.Hash.to_binary(123))
  assert.is_binary(Bloomy.Hash.to_binary(3.14))
end) | test_results]

# ============================================================================
# SUMMARY
# ============================================================================
IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("TEST RESULTS SUMMARY")
IO.puts(String.duplicate("=", 80) <> "\n")

test_results = Enum.reverse(test_results)

passed = Enum.count(test_results, fn {_, status} -> status == :passed end)
failed = Enum.count(test_results, fn {_, status} -> match?({:failed, _}, status) end)
total = length(test_results)

IO.puts("Total Tests: #{total}")
IO.puts("✅ Passed: #{passed}")
IO.puts("❌ Failed: #{failed}")
IO.puts("")

if failed > 0 do
  IO.puts("Failed Tests:")
  for {name, {:failed, reason}} <- test_results do
    IO.puts("  ❌ #{name}")
    IO.puts("     Reason: #{reason}")
  end
  IO.puts("")
end

success_rate = Float.round(passed / total * 100, 1)
IO.puts("Success Rate: #{success_rate}%")

if failed == 0 do
  IO.puts("\n🎉 ALL TESTS PASSED! Bloomy library is working perfectly! 🎉\n")
  System.halt(0)
else
  IO.puts("\n⚠️  Some tests failed. Please review the errors above.\n")
  System.halt(1)
end
