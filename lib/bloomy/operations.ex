defmodule Bloomy.Operations do
  @moduledoc """
  Advanced operations for bloom filters.

  This module provides utilities for merging, comparing, and operating on
  multiple bloom filters. Useful for distributed systems and parallel processing.

  ## Features

  - Union and intersection of multiple filters
  - Batch operations
  - Compatibility checking
  - Distributed bloom filter support
  - Similarity metrics

  ## Examples

      iex> # Union multiple filters
      iex> filters = [
      iex>   Bloomy.Standard.new(1000) |> Bloomy.Standard.add("a"),
      iex>   Bloomy.Standard.new(1000) |> Bloomy.Standard.add("b"),
      iex>   Bloomy.Standard.new(1000) |> Bloomy.Standard.add("c")
      iex> ]
      iex> merged = Bloomy.Operations.union_all(filters)
      iex> Bloomy.Standard.member?(merged, "a") and
      iex> Bloomy.Standard.member?(merged, "b") and
      iex> Bloomy.Standard.member?(merged, "c")
      true
  """

  alias Bloomy.{Standard, Counting}

  @doc """
  Union multiple bloom filters into one.

  All filters must be of the same type and have compatible parameters.

  ## Parameters

    * `filters` - List of bloom filters (must all be the same type)

  ## Returns

  A new bloom filter containing the union of all input filters.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add("a")
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add("b")
      iex> f3 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add("c")
      iex> merged = Bloomy.Operations.union_all([f1, f2, f3])
      iex> Bloomy.Standard.member?(merged, "b")
      true
  """
  def union_all([]), do: raise(ArgumentError, "Cannot union empty list of filters")
  def union_all([single]), do: single

  def union_all([first | rest] = filters) when is_list(filters) do
    # Verify all filters are compatible
    case check_compatibility(filters) do
      :ok ->
        perform_union_all(first, rest)

      {:error, reason} ->
        raise ArgumentError, "Incompatible filters for union: #{reason}"
    end
  end

  @doc """
  Intersection of multiple bloom filters.

  Returns a new filter containing only items likely present in all input filters.
  Note: The result may have false positives.

  ## Parameters

    * `filters` - List of bloom filters (must all be the same type)

  ## Returns

  A new bloom filter containing the intersection.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b", "c"])
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["b", "c", "d"])
      iex> f3 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["c", "d", "e"])
      iex> intersect = Bloomy.Operations.intersect_all([f1, f2, f3])
      iex> Bloomy.Standard.member?(intersect, "c")
      true
  """
  def intersect_all([]), do: raise(ArgumentError, "Cannot intersect empty list of filters")
  def intersect_all([single]), do: single

  def intersect_all([first | rest] = filters) when is_list(filters) do
    case check_compatibility(filters) do
      :ok ->
        perform_intersect_all(first, rest)

      {:error, reason} ->
        raise ArgumentError, "Incompatible filters for intersection: #{reason}"
    end
  end

  @doc """
  Check if two bloom filters are compatible for merge operations.

  Compatible filters must have the same type, size, and hash functions.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  `:ok` if compatible, `{:error, reason}` otherwise.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000)
      iex> f2 = Bloomy.Standard.new(1000)
      iex> Bloomy.Operations.compatible?(f1, f2)
      :ok

      iex> f1 = Bloomy.Standard.new(1000)
      iex> f2 = Bloomy.Standard.new(2000)
      iex> {:error, _} = Bloomy.Operations.compatible?(f1, f2)
  """
  def compatible?(filter1, filter2) do
    check_compatibility([filter1, filter2])
  end

  @doc """
  Calculate Jaccard similarity between two bloom filters.

  The Jaccard similarity is the size of the intersection divided by the
  size of the union. Returns a value between 0 and 1.

  Note: This is an estimate based on bit patterns, not actual set similarity.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  Float between 0.0 and 1.0 representing similarity.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b", "c"])
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["b", "c", "d"])
      iex> similarity = Bloomy.Operations.jaccard_similarity(f1, f2)
      iex> similarity > 0 and similarity < 1
      true
  """
  def jaccard_similarity(%Standard{} = f1, %Standard{} = f2) do
    case compatible?(f1, f2) do
      :ok ->
        # Count bits in union/intersection
        union_bits = f1 |> Standard.union(f2) |> then(&Bloomy.BitArray.count(&1.bit_array))

        intersect_bits =
          f1 |> Standard.intersect(f2) |> then(&Bloomy.BitArray.count(&1.bit_array))

        if union_bits == 0 do
          1.0
        else
          intersect_bits / union_bits
        end

      {:error, _} ->
        raise ArgumentError, "Cannot calculate similarity for incompatible filters"
    end
  end

  @doc """
  Calculate the overlap coefficient between two bloom filters.

  The overlap coefficient is the size of the intersection divided by the
  size of the smaller set. Returns a value between 0 and 1.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  Float between 0.0 and 1.0.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b"])
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b", "c", "d"])
      iex> overlap = Bloomy.Operations.overlap_coefficient(f1, f2)
      iex> overlap > 0
      true
  """
  def overlap_coefficient(%Standard{} = f1, %Standard{} = f2) do
    case compatible?(f1, f2) do
      :ok ->
        bits1 = Bloomy.BitArray.count(f1.bit_array)
        bits2 = Bloomy.BitArray.count(f2.bit_array)

        intersect_bits =
          f1 |> Standard.intersect(f2) |> then(&Bloomy.BitArray.count(&1.bit_array))

        min_bits = min(bits1, bits2)

        if min_bits == 0 do
          0.0
        else
          intersect_bits / min_bits
        end

      {:error, _} ->
        raise ArgumentError, "Cannot calculate overlap for incompatible filters"
    end
  end

  @doc """
  Create a bloom filter from a list of items.

  Convenience function for creating and populating a filter in one step.

  ## Parameters

    * `items` - List of items to add
    * `opts` - Options for filter creation:
      * `:capacity` - Expected capacity (default: length of items * 1.5)
      * `:false_positive_rate` - Desired false positive rate (default: 0.01)
      * `:type` - Filter type: `:standard`, `:counting`, or `:scalable` (default: `:standard`)

  ## Returns

  A new bloom filter containing all items.

  ## Examples

      iex> filter = Bloomy.Operations.from_list(["a", "b", "c", "d"])
      iex> Bloomy.Standard.member?(filter, "c")
      true
  """
  def from_list(items, opts \\ []) when is_list(items) do
    capacity = Keyword.get(opts, :capacity, round(length(items) * 1.5))
    false_positive_rate = Keyword.get(opts, :false_positive_rate, 0.01)
    type = Keyword.get(opts, :type, :standard)

    filter =
      case type do
        :standard ->
          Standard.new(capacity, false_positive_rate: false_positive_rate)

        :counting ->
          Counting.new(capacity, false_positive_rate: false_positive_rate)

        :scalable ->
          alias Bloomy.Scalable
          Scalable.new(capacity, false_positive_rate: false_positive_rate)

        _ ->
          raise ArgumentError, "Unknown filter type: #{type}"
      end

    add_items(filter, items)
  end

  @doc """
  Test multiple items for membership in batch.

  More efficient than calling `member?` individually for many items.

  ## Parameters

    * `filter` - The bloom filter
    * `items` - List of items to test

  ## Returns

  Map with items as keys and membership test results as values.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b"])
      iex> results = Bloomy.Operations.batch_member?(filter, ["a", "b", "c"])
      iex> results["a"] == true and results["c"] == false
      true
  """
  def batch_member?(%Standard{} = filter, items) when is_list(items) do
    Map.new(items, fn item ->
      {item, Standard.member?(filter, item)}
    end)
  end

  def batch_member?(%Counting{} = filter, items) when is_list(items) do
    Map.new(items, fn item ->
      {item, Counting.member?(filter, item)}
    end)
  end

  # Private helper functions

  defp check_compatibility([first | rest]) do
    type = filter_type(first)
    params = extract_params(first)

    rest
    |> Enum.reduce_while(:ok, fn filter, _acc ->
      cond do
        filter_type(filter) != type ->
          {:halt, {:error, "Mixed filter types"}}

        extract_params(filter) != params ->
          {:halt, {:error, "Different parameters (size or hash functions)"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp filter_type(%Standard{}), do: :standard
  defp filter_type(%Counting{}), do: :counting
  defp filter_type(_), do: :unknown

  defp extract_params(%Standard{params: params}) do
    {params.size, params.hash_functions}
  end

  defp extract_params(%Counting{params: params}) do
    {params.size, params.hash_functions}
  end

  defp perform_union_all(first, rest) do
    Enum.reduce(rest, first, fn filter, acc ->
      union_two(acc, filter)
    end)
  end

  defp perform_intersect_all(first, rest) do
    Enum.reduce(rest, first, fn filter, acc ->
      intersect_two(acc, filter)
    end)
  end

  defp union_two(%Standard{} = f1, %Standard{} = f2), do: Standard.union(f1, f2)
  defp union_two(%Counting{} = f1, %Counting{} = f2), do: Counting.union(f1, f2)

  defp intersect_two(%Standard{} = f1, %Standard{} = f2), do: Standard.intersect(f1, f2)

  defp intersect_two(%Counting{} = _f1, %Counting{} = _f2) do
    raise ArgumentError, "Intersection not implemented for counting bloom filters"
  end

  defp add_items(%Standard{} = filter, items), do: Standard.add_all(filter, items)
  defp add_items(%Counting{} = filter, items), do: Counting.add_all(filter, items)

  defp add_items(filter, items) do
    Enum.reduce(items, filter, fn item, acc ->
      Bloomy.Protocol.add(acc, item)
    end)
  end
end
