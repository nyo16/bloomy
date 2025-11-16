defmodule Bloomy.Counting do
  @moduledoc """
  Counting bloom filter implementation using Nx tensors.

  A counting bloom filter extends the standard bloom filter by using counters
  instead of bits. This allows for deletion operations while maintaining the
  probabilistic properties of bloom filters.

  ## Features

  - Supports deletion (remove operation)
  - Uses Nx tensors for counter storage
  - Configurable counter bit width
  - Overflow detection and handling
  - EXLA backend support

  ## Trade-offs

  - Uses more memory than standard bloom filter (counters vs bits)
  - Slightly slower operations due to counter arithmetic
  - Enables deletion, which standard bloom filters cannot do

  ## Examples

      iex> # Create a counting bloom filter
      iex> filter = Bloomy.Counting.new(1000, false_positive_rate: 0.01)
      iex>
      iex> # Add items
      iex> filter = filter
      iex>   |> Bloomy.Counting.add("apple")
      iex>   |> Bloomy.Counting.add("banana")
      iex>
      iex> # Check membership
      iex> Bloomy.Counting.member?(filter, "apple")
      true
      iex>
      iex> # Remove items
      iex> filter = Bloomy.Counting.remove(filter, "apple")
      iex> Bloomy.Counting.member?(filter, "apple")
      false
  """

  @behaviour Bloomy.Behaviour

  alias Bloomy.{Hash, Params}

  import Nx.Defn

  @type t :: %__MODULE__{
          counters: Nx.Tensor.t(),
          params: Params.t(),
          items_count: non_neg_integer(),
          counter_width: 8 | 16 | 32,
          backend: atom()
        }

  defstruct [:counters, :params, :items_count, :counter_width, :backend]

  @doc """
  Create a new counting bloom filter.

  ## Parameters

    * `capacity` - Expected number of items to store
    * `opts` - Keyword list of options:
      * `:false_positive_rate` - Desired false positive rate (default: 0.01)
      * `:counter_width` - Bits per counter: 8, 16, or 32 (default: 8)
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new `Bloomy.Counting` struct.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter.params.capacity
      1000

      iex> filter = Bloomy.Counting.new(1000, counter_width: 16)
      iex> filter.counter_width
      16
  """
  @impl true
  def new(capacity, opts \\ []) when is_integer(capacity) and capacity > 0 do
    false_positive_rate = Keyword.get(opts, :false_positive_rate, 0.01)
    counter_width = Keyword.get(opts, :counter_width, 8)
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    unless counter_width in [8, 16, 32] do
      raise ArgumentError, "counter_width must be 8, 16, or 32, got: #{counter_width}"
    end

    # Calculate optimal parameters
    params = Params.calculate(capacity, false_positive_rate)

    # Validate parameters
    case Params.validate(params) do
      {:ok, params} ->
        # Create counter array (all zeros)
        counter_type = counter_type(counter_width)

        counters =
          Nx.broadcast(0, {params.size})
          |> Nx.as_type(counter_type)
          |> Nx.backend_transfer(backend)

        %__MODULE__{
          counters: counters,
          params: params,
          items_count: 0,
          counter_width: counter_width,
          backend: backend
        }

      {:error, reason} ->
        raise ArgumentError, "Invalid bloom filter parameters: #{reason}"
    end
  end

  @doc """
  Add an item to the counting bloom filter.

  Increments counters at hash positions. Detects and prevents counter overflow.

  ## Parameters

    * `filter` - The counting bloom filter struct
    * `item` - Item to add

  ## Returns

  Updated counting bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter = Bloomy.Counting.add(filter, "hello")
      iex> filter.items_count
      1
  """
  @impl true
  def add(%__MODULE__{} = filter, item) do
    # Get hash indices
    indices = Hash.hash(item, filter.params.hash_functions, filter.params.size)

    # Increment counters at indices
    counters = increment_counters(filter.counters, indices, filter.counter_width)

    %{filter | counters: counters, items_count: filter.items_count + 1}
  end

  @doc """
  Add multiple items to the counting bloom filter.

  ## Parameters

    * `filter` - The counting bloom filter struct
    * `items` - List of items to add

  ## Returns

  Updated counting bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter = Bloomy.Counting.add_all(filter, ["a", "b", "c"])
      iex> filter.items_count
      3
  """
  def add_all(%__MODULE__{} = filter, items) when is_list(items) do
    Enum.reduce(items, filter, fn item, acc -> add(acc, item) end)
  end

  @doc """
  Remove an item from the counting bloom filter.

  Decrements counters at hash positions. Will not decrement below zero.

  ## Parameters

    * `filter` - The counting bloom filter struct
    * `item` - Item to remove

  ## Returns

  Updated counting bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter = Bloomy.Counting.add(filter, "hello")
      iex> Bloomy.Counting.member?(filter, "hello")
      true
      iex> filter = Bloomy.Counting.remove(filter, "hello")
      iex> Bloomy.Counting.member?(filter, "hello")
      false
  """
  @impl true
  def remove(%__MODULE__{} = filter, item) do
    # Get hash indices
    indices = Hash.hash(item, filter.params.hash_functions, filter.params.size)

    # Decrement counters at indices
    counters = decrement_counters(filter.counters, indices)

    %{filter | counters: counters, items_count: max(0, filter.items_count - 1)}
  end

  @doc """
  Check if an item might be in the counting bloom filter.

  ## Parameters

    * `filter` - The counting bloom filter struct
    * `item` - Item to check

  ## Returns

  Boolean - true if item might be present, false if definitely not present.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter = Bloomy.Counting.add(filter, "hello")
      iex> Bloomy.Counting.member?(filter, "hello")
      true
      iex> Bloomy.Counting.member?(filter, "world")
      false
  """
  @impl true
  def member?(%__MODULE__{} = filter, item) do
    # Get hash indices
    indices = Hash.hash(item, filter.params.hash_functions, filter.params.size)

    # Check if all counters at indices are non-zero
    check_all_nonzero(filter.counters, indices)
    |> Nx.to_number()
    |> then(&(&1 == 1))
  end

  @doc """
  Get information and statistics about the counting bloom filter.

  ## Parameters

    * `filter` - The counting bloom filter struct

  ## Returns

  Map containing filter statistics.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> info = Bloomy.Counting.info(filter)
      iex> info.type
      :counting
      iex> info.counter_width
      8
  """
  @impl true
  def info(%__MODULE__{} = filter) do
    nonzero_count = count_nonzero(filter.counters) |> Nx.to_number()
    fill_ratio = nonzero_count / filter.params.size

    actual_fp_rate =
      Params.calculate_false_positive_rate(
        filter.params.size,
        filter.params.hash_functions,
        filter.items_count
      )

    # Get max counter value to detect potential overflow
    max_counter = Nx.reduce_max(filter.counters) |> Nx.to_number()
    max_possible = max_counter_value(filter.counter_width)

    %{
      type: :counting,
      capacity: filter.params.capacity,
      size: filter.params.size,
      hash_functions: filter.params.hash_functions,
      items_count: filter.items_count,
      nonzero_counters: nonzero_count,
      fill_ratio: Float.round(fill_ratio, 4),
      false_positive_rate: filter.params.false_positive_rate,
      actual_false_positive_rate: Float.round(actual_fp_rate, 6),
      counter_width: filter.counter_width,
      max_counter: max_counter,
      max_possible_counter: max_possible,
      overflow_risk: max_counter >= max_possible * 0.9,
      backend: filter.backend,
      memory_bytes: filter.params.size * (filter.counter_width / 8)
    }
  end

  @doc """
  Clear the counting bloom filter (reset all counters to zero).

  ## Parameters

    * `filter` - The counting bloom filter struct

  ## Returns

  Cleared counting bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Counting.new(1000)
      iex> filter = Bloomy.Counting.add(filter, "test")
      iex> filter.items_count
      1
      iex> filter = Bloomy.Counting.clear(filter)
      iex> filter.items_count
      0
  """
  @impl true
  def clear(%__MODULE__{} = filter) do
    counter_type = counter_type(filter.counter_width)

    counters =
      Nx.broadcast(0, {filter.params.size})
      |> Nx.as_type(counter_type)
      |> Nx.backend_transfer(filter.backend)

    %{filter | counters: counters, items_count: 0}
  end

  @doc """
  Union (merge) two counting bloom filters.

  Takes the maximum counter value at each position.

  ## Parameters

    * `filter1` - First counting bloom filter
    * `filter2` - Second counting bloom filter

  ## Returns

  New counting bloom filter containing union.

  ## Examples

      iex> f1 = Bloomy.Counting.new(1000) |> Bloomy.Counting.add("a")
      iex> f2 = Bloomy.Counting.new(1000) |> Bloomy.Counting.add("b")
      iex> f_union = Bloomy.Counting.union(f1, f2)
      iex> Bloomy.Counting.member?(f_union, "a") and Bloomy.Counting.member?(f_union, "b")
      true
  """
  def union(
        %__MODULE__{params: params1, counter_width: cw} = filter1,
        %__MODULE__{params: params2, counter_width: cw} = filter2
      ) do
    if params1.size != params2.size or params1.hash_functions != params2.hash_functions do
      raise ArgumentError, "Cannot union counting bloom filters with different parameters"
    end

    # Take maximum of counters at each position
    counters = Nx.max(filter1.counters, filter2.counters)

    %{
      filter1
      | counters: counters,
        items_count: filter1.items_count + filter2.items_count
    }
  end

  def union(%__MODULE__{counter_width: cw1}, %__MODULE__{counter_width: cw2}) do
    raise ArgumentError,
          "Cannot union counting bloom filters with different counter widths: #{cw1} vs #{cw2}"
  end

  # Private helper functions

  defp counter_type(8), do: :u8
  defp counter_type(16), do: :u16
  defp counter_type(32), do: :u32

  defp max_counter_value(8), do: 255
  defp max_counter_value(16), do: 65535
  defp max_counter_value(32), do: 4_294_967_295

  defnp increment_counters(counters, indices, counter_width) do
    # Get current values at indices
    current = Nx.take(counters, indices)

    # Increment by 1, with overflow protection
    max_val = get_max_value(counter_width)
    incremented = Nx.min(Nx.add(current, 1), max_val)

    # Update counters at indices
    Nx.indexed_put(counters, Nx.new_axis(indices, -1), incremented)
  end

  defnp decrement_counters(counters, indices) do
    # Get current values at indices
    current = Nx.take(counters, indices)

    # Decrement by 1, with underflow protection (min 0)
    decremented = Nx.max(Nx.subtract(current, 1), 0)

    # Update counters at indices
    Nx.indexed_put(counters, Nx.new_axis(indices, -1), decremented)
  end

  defnp check_all_nonzero(counters, indices) do
    # Get counter values at indices
    values = Nx.take(counters, indices)

    # Check if all are greater than 0
    Nx.all(Nx.greater(values, 0))
    |> Nx.as_type(:u8)
  end

  defnp count_nonzero(counters) do
    # Count how many counters are non-zero
    Nx.sum(Nx.greater(counters, 0))
  end

  defnp get_max_value(counter_width) do
    Nx.select(
      counter_width == 8,
      255,
      Nx.select(counter_width == 16, 65535, 4_294_967_295)
    )
  end
end

# Implement the Bloomy.Protocol for Counting bloom filter
defimpl Bloomy.Protocol, for: Bloomy.Counting do
  def add(filter, item), do: Bloomy.Counting.add(filter, item)
  def member?(filter, item), do: Bloomy.Counting.member?(filter, item)
  def info(filter), do: Bloomy.Counting.info(filter)
  def clear(filter), do: Bloomy.Counting.clear(filter)
end
