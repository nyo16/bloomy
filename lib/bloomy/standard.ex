defmodule Bloomy.Standard do
  @moduledoc """
  Standard (classic) bloom filter implementation using Nx tensors.

  A bloom filter is a space-efficient probabilistic data structure used to test
  whether an element is a member of a set. False positive matches are possible,
  but false negatives are not.

  This implementation uses Nx tensors for high-performance vectorized operations
  and supports EXLA acceleration.

  ## Features

  - O(k) add and query operations where k is the number of hash functions
  - Vectorized bit operations using Nx
  - EXLA backend support for GPU/CPU acceleration
  - Optimal parameter calculation
  - Statistics and monitoring

  ## Examples

      iex> # Create a bloom filter for 1000 items with 1% false positive rate
      iex> filter = Bloomy.Standard.new(1000, false_positive_rate: 0.01)
      iex>
      iex> # Add items
      iex> filter = Bloomy.Standard.add(filter, "apple")
      iex> filter = Bloomy.Standard.add(filter, "banana")
      iex> filter = Bloomy.Standard.add(filter, "orange")
      iex>
      iex> # Query membership
      iex> Bloomy.Standard.member?(filter, "apple")
      true
      iex> Bloomy.Standard.member?(filter, "grape")
      false
      iex>
      iex> # Get statistics
      iex> info = Bloomy.Standard.info(filter)
      iex> info.items_count
      3
  """

  @behaviour Bloomy.Behaviour

  alias Bloomy.{BitArray, Hash, Params}

  @type t :: %__MODULE__{
          bit_array: BitArray.t(),
          params: Params.t(),
          items_count: non_neg_integer(),
          backend: atom()
        }

  defstruct [:bit_array, :params, :items_count, :backend]

  @doc """
  Create a new standard bloom filter.

  ## Parameters

    * `capacity` - Expected number of items to store
    * `opts` - Keyword list of options:
      * `:false_positive_rate` - Desired false positive rate (default: 0.01 or 1%)
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new `Bloomy.Standard` struct.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter.params.capacity
      1000

      iex> filter = Bloomy.Standard.new(10000, false_positive_rate: 0.001)
      iex> filter.params.false_positive_rate
      0.001
  """
  @impl true
  def new(capacity, opts \\ []) when is_integer(capacity) and capacity > 0 do
    false_positive_rate = Keyword.get(opts, :false_positive_rate, 0.01)
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    # Calculate optimal parameters
    params = Params.calculate(capacity, false_positive_rate)

    # Validate parameters
    case Params.validate(params) do
      {:ok, params} ->
        # Create bit array
        bit_array = BitArray.new(params.size, backend: backend)

        %__MODULE__{
          bit_array: bit_array,
          params: params,
          items_count: 0,
          backend: backend
        }

      {:error, reason} ->
        raise ArgumentError, "Invalid bloom filter parameters: #{reason}"
    end
  end

  @doc """
  Add an item to the bloom filter.

  The item will be hashed using multiple hash functions and the corresponding
  bits will be set in the underlying bit array.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to add (any term that can be converted to binary)

  ## Returns

  Updated bloom filter struct with the item added.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add(filter, "hello")
      iex> filter.items_count
      1

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = filter |> Bloomy.Standard.add("a") |> Bloomy.Standard.add("b")
      iex> filter.items_count
      2
  """
  @impl true
  def add(%__MODULE__{} = filter, item) do
    # Get hash indices for the item
    indices = Hash.hash(item, filter.params.hash_functions, filter.params.size)

    # Set bits at hash indices
    bit_array = BitArray.set(filter.bit_array, indices)

    %{filter | bit_array: bit_array, items_count: filter.items_count + 1}
  end

  @doc """
  Add multiple items to the bloom filter at once.

  More efficient than calling `add/2` multiple times.

  ## Parameters

    * `filter` - The bloom filter struct
    * `items` - List of items to add

  ## Returns

  Updated bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add_all(filter, ["a", "b", "c", "d"])
      iex> filter.items_count
      4
  """
  def add_all(%__MODULE__{} = filter, items) when is_list(items) do
    Enum.reduce(items, filter, fn item, acc -> add(acc, item) end)
  end

  @doc """
  Check if an item might be in the bloom filter.

  ## Returns

    * `true` - The item might be in the set (or could be a false positive)
    * `false` - The item is definitely not in the set

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to check

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add(filter, "hello")
      iex> Bloomy.Standard.member?(filter, "hello")
      true
      iex> Bloomy.Standard.member?(filter, "world")
      false
  """
  @impl true
  def member?(%__MODULE__{} = filter, item) do
    # Get hash indices for the item
    indices = Hash.hash(item, filter.params.hash_functions, filter.params.size)

    # Check if all bits at hash indices are set
    BitArray.all_set?(filter.bit_array, indices)
  end

  @doc """
  Get information and statistics about the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Map containing:
    * `:type` - Type of bloom filter (`:standard`)
    * `:capacity` - Expected capacity
    * `:size` - Bit array size
    * `:hash_functions` - Number of hash functions used
    * `:items_count` - Number of items added
    * `:fill_ratio` - Proportion of bits set (0.0 to 1.0)
    * `:false_positive_rate` - Desired false positive rate
    * `:actual_false_positive_rate` - Actual false positive rate based on fill
    * `:backend` - Nx backend in use

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add(filter, "test")
      iex> info = Bloomy.Standard.info(filter)
      iex> info.type
      :standard
      iex> info.items_count
      1
  """
  @impl true
  def info(%__MODULE__{} = filter) do
    fill_ratio = BitArray.fill_ratio(filter.bit_array)

    actual_fp_rate =
      Params.calculate_false_positive_rate(
        filter.params.size,
        filter.params.hash_functions,
        filter.items_count
      )

    %{
      type: :standard,
      capacity: filter.params.capacity,
      size: filter.params.size,
      hash_functions: filter.params.hash_functions,
      items_count: filter.items_count,
      fill_ratio: Float.round(fill_ratio, 4),
      false_positive_rate: filter.params.false_positive_rate,
      actual_false_positive_rate: Float.round(actual_fp_rate, 6),
      backend: filter.backend,
      bits_per_item: Float.round(filter.params.size / filter.params.capacity, 2)
    }
  end

  @doc """
  Clear the bloom filter (reset to empty state).

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Cleared bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add(filter, "test")
      iex> filter.items_count
      1
      iex> filter = Bloomy.Standard.clear(filter)
      iex> filter.items_count
      0
  """
  @impl true
  def clear(%__MODULE__{} = filter) do
    bit_array = BitArray.clear(filter.bit_array)
    %{filter | bit_array: bit_array, items_count: 0}
  end

  @doc """
  Union (merge) two bloom filters.

  Creates a new bloom filter containing all items from both filters.
  Both filters must have the same parameters (size and hash functions).

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  New bloom filter containing union of both filters.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add("a")
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add("b")
      iex> f_union = Bloomy.Standard.union(f1, f2)
      iex> Bloomy.Standard.member?(f_union, "a") and Bloomy.Standard.member?(f_union, "b")
      true
  """
  def union(
        %__MODULE__{params: params1} = filter1,
        %__MODULE__{params: params2} = filter2
      ) do
    if params1.size != params2.size or params1.hash_functions != params2.hash_functions do
      raise ArgumentError,
            "Cannot union bloom filters with different parameters. " <>
              "Both must have same size (#{params1.size} vs #{params2.size}) " <>
              "and hash functions (#{params1.hash_functions} vs #{params2.hash_functions})"
    end

    bit_array = BitArray.union(filter1.bit_array, filter2.bit_array)

    %{
      filter1
      | bit_array: bit_array,
        items_count: filter1.items_count + filter2.items_count
    }
  end

  @doc """
  Intersection of two bloom filters.

  Creates a new bloom filter that only contains items present in both filters.
  Both filters must have the same parameters.

  Note: The intersection may have false positives and the items_count
  is an estimate.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  New bloom filter containing intersection of both filters.

  ## Examples

      iex> f1 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["a", "b", "c"])
      iex> f2 = Bloomy.Standard.new(1000) |> Bloomy.Standard.add_all(["b", "c", "d"])
      iex> f_intersect = Bloomy.Standard.intersect(f1, f2)
      iex> Bloomy.Standard.member?(f_intersect, "b")
      true
  """
  def intersect(
        %__MODULE__{params: params1} = filter1,
        %__MODULE__{params: params2} = filter2
      ) do
    if params1.size != params2.size or params1.hash_functions != params2.hash_functions do
      raise ArgumentError,
            "Cannot intersect bloom filters with different parameters"
    end

    bit_array = BitArray.intersect(filter1.bit_array, filter2.bit_array)

    # Estimate items count based on fill ratio
    fill_ratio = BitArray.fill_ratio(bit_array)

    items_count =
      Params.estimate_item_count(params1.size, params1.hash_functions, fill_ratio)

    %{filter1 | bit_array: bit_array, items_count: items_count}
  end

  @doc """
  Check if the bloom filter is at or over capacity.

  Returns true if the number of items added meets or exceeds the expected capacity.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Boolean indicating if filter is at capacity.

  ## Examples

      iex> filter = Bloomy.Standard.new(10)
      iex> Bloomy.Standard.at_capacity?(filter)
      false
      iex> filter = Bloomy.Standard.add_all(filter, Enum.to_list(1..10))
      iex> Bloomy.Standard.at_capacity?(filter)
      true
  """
  def at_capacity?(%__MODULE__{} = filter) do
    filter.items_count >= filter.params.capacity
  end

  @doc """
  Estimate the actual number of items in the filter based on fill ratio.

  Uses the fill ratio to estimate item count, which may be more accurate
  than the tracked count if items have been added multiple times.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Estimated number of unique items.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add_all(filter, ["a", "b", "c"])
      iex> Bloomy.Standard.estimate_count(filter) > 0
      true
  """
  def estimate_count(%__MODULE__{} = filter) do
    fill_ratio = BitArray.fill_ratio(filter.bit_array)

    Params.estimate_item_count(
      filter.params.size,
      filter.params.hash_functions,
      fill_ratio
    )
  end
end

# Implement the Bloomy.Protocol for Standard bloom filter
defimpl Bloomy.Protocol, for: Bloomy.Standard do
  def add(filter, item), do: Bloomy.Standard.add(filter, item)
  def member?(filter, item), do: Bloomy.Standard.member?(filter, item)
  def info(filter), do: Bloomy.Standard.info(filter)
  def clear(filter), do: Bloomy.Standard.clear(filter)
end
