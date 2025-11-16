defmodule BloomyTest do
  use ExUnit.Case
  # Skip doctests for now due to multi-line example formatting issues
  # doctest Bloomy

  describe "Standard Bloom Filter" do
    test "create and add items" do
      filter = Bloomy.new(1000)
      filter = Bloomy.add(filter, "test_item")

      assert Bloomy.member?(filter, "test_item") == true
      assert Bloomy.member?(filter, "not_added") == false
    end

    test "batch operations" do
      filter = Bloomy.new(1000)
      items = ["a", "b", "c", "d", "e"]
      filter = Bloomy.add_all(filter, items)

      Enum.each(items, fn item ->
        assert Bloomy.member?(filter, item) == true
      end)
    end

    test "info returns correct statistics" do
      filter = Bloomy.new(1000, false_positive_rate: 0.01)
      filter = Bloomy.add_all(filter, ["a", "b", "c"])

      info = Bloomy.info(filter)
      assert info.type == :standard
      assert info.capacity == 1000
      assert info.items_count == 3
      assert info.false_positive_rate == 0.01
    end

    test "clear operation" do
      filter = Bloomy.new(1000)
      filter = Bloomy.add(filter, "item")
      assert Bloomy.member?(filter, "item") == true

      filter = Bloomy.clear(filter)
      assert Bloomy.member?(filter, "item") == false

      info = Bloomy.info(filter)
      assert info.items_count == 0
    end

    test "union operation" do
      f1 = Bloomy.new(1000) |> Bloomy.add("apple")
      f2 = Bloomy.new(1000) |> Bloomy.add("banana")

      merged = Bloomy.union(f1, f2)
      assert Bloomy.member?(merged, "apple") == true
      assert Bloomy.member?(merged, "banana") == true
    end

    test "from_list creates filter" do
      items = ["x", "y", "z"]
      filter = Bloomy.from_list(items)

      Enum.each(items, fn item ->
        assert Bloomy.member?(filter, item) == true
      end)
    end
  end

  describe "Counting Bloom Filter" do
    test "supports deletion" do
      filter = Bloomy.new(1000, type: :counting)
      filter = Bloomy.add(filter, "removable")

      assert Bloomy.member?(filter, "removable") == true

      filter = Bloomy.remove(filter, "removable")
      assert Bloomy.member?(filter, "removable") == false
    end
  end

  describe "Scalable Bloom Filter" do
    test "auto-scales with data" do
      filter = Bloomy.new(10, type: :scalable)

      # Add more items than initial capacity
      items = Enum.map(1..50, &"item_#{&1}")
      filter = Bloomy.add_all(filter, items)

      # Check filter scaled
      info = Bloomy.info(filter)
      assert info.slices_count > 1

      # Verify items are present
      assert Bloomy.member?(filter, "item_1") == true
      assert Bloomy.member?(filter, "item_50") == true
    end
  end

  describe "Serialization" do
    test "to_binary and from_binary" do
      filter = Bloomy.new(1000)
      filter = Bloomy.add_all(filter, ["one", "two", "three"])

      binary = Bloomy.to_binary(filter)
      assert is_binary(binary)

      {:ok, loaded} = Bloomy.from_binary(binary)
      assert Bloomy.member?(loaded, "one") == true
      assert Bloomy.member?(loaded, "two") == true
      assert Bloomy.member?(loaded, "three") == true
    end
  end
end
