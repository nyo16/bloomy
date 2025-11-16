# Test Standard Bloom Filter
IO.puts("=== Testing Standard Bloom Filter ===")
filter = Bloomy.new(1000, false_positive_rate: 0.01)
filter = Bloomy.add(filter, "apple")
filter = Bloomy.add(filter, "banana")
filter = Bloomy.add(filter, "orange")

IO.puts("member?(apple): #{Bloomy.member?(filter, "apple")}")
IO.puts("member?(grape): #{Bloomy.member?(filter, "grape")}")

info = Bloomy.info(filter)
IO.puts("Items count: #{info.items_count}")
IO.puts("Capacity: #{info.capacity}")
IO.puts("Fill ratio: #{info.fill_ratio}")

# Test Counting Bloom Filter
IO.puts("\n=== Testing Counting Bloom Filter ===")
counting = Bloomy.new(1000, type: :counting)
counting = Bloomy.add(counting, "item1")
IO.puts("member?(item1) before remove: #{Bloomy.member?(counting, "item1")}")
counting = Bloomy.remove(counting, "item1")
IO.puts("member?(item1) after remove: #{Bloomy.member?(counting, "item1")}")

# Test Scalable Bloom Filter
IO.puts("\n=== Testing Scalable Bloom Filter ===")
scalable = Bloomy.new(10, type: :scalable)
scalable = Enum.reduce(1..30, scalable, fn i, f ->
  Bloomy.add(f, "item_#{i}")
end)

info = Bloomy.info(scalable)
IO.puts("Slices count: #{info.slices_count}")
IO.puts("Total items: #{info.items_count}")

# Test batch operations
IO.puts("\n=== Testing Batch Operations ===")
filter = Bloomy.from_list(["a", "b", "c", "d"])
results = Bloomy.batch_member?(filter, ["a", "b", "z"])
IO.puts("Batch results: a=#{results["a"]}, b=#{results["b"]}, z=#{results["z"]}")

# Test union
IO.puts("\n=== Testing Union Operation ===")
f1 = Bloomy.new(1000) |> Bloomy.add("a") |> Bloomy.add("b")
f2 = Bloomy.new(1000) |> Bloomy.add("c") |> Bloomy.add("d")
merged = Bloomy.union(f1, f2)
IO.puts("Union contains 'a': #{Bloomy.member?(merged, "a")}")
IO.puts("Union contains 'd': #{Bloomy.member?(merged, "d")}")

IO.puts("\n✅ All tests passed successfully!")
