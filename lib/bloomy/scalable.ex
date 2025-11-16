defmodule Bloomy.Scalable do
  @moduledoc """
  Scalable bloom filter that dynamically grows to maintain target false positive rate.

  A scalable bloom filter automatically adds new bloom filter slices as capacity
  is reached. Each new slice has a tighter error rate and larger capacity,
  maintaining the overall target false positive rate even as the data grows.

  ## Growth Strategy

  - **Initial capacity**: Configurable starting capacity
  - **Growth factor**: Each new slice is 2x the previous capacity (configurable)
  - **Error tightening**: Each slice has 0.8x the error rate of the previous (configurable)
  - **Combined error rate**: Approximately equal to the target rate

  ## Features

  - Automatic expansion without manual intervention
  - Maintains target false positive rate as data grows
  - Optimal for unknown dataset sizes
  - EXLA backend support for all slices

  ## Examples

      iex> # Create a scalable bloom filter starting with capacity 1000
      iex> filter = Bloomy.Scalable.new(1000, false_positive_rate: 0.01)
      iex>
      iex> # Add many items - it will automatically grow
      iex> filter = Enum.reduce(1..5000, filter, fn i, f ->
      iex>   Bloomy.Scalable.add(f, "item_\#{i}")
      iex> end)
      iex>
      iex> # Check info - multiple slices created
      iex> info = Bloomy.Scalable.info(filter)
      iex> info.slices_count > 1
      true
  """

  @behaviour Bloomy.Behaviour

  alias Bloomy.Standard

  @type t :: %__MODULE__{
          slices: [Standard.t()],
          initial_capacity: pos_integer(),
          target_false_positive_rate: float(),
          growth_factor: pos_integer(),
          error_tightening_ratio: float(),
          items_count: non_neg_integer(),
          backend: atom()
        }

  defstruct [
    :slices,
    :initial_capacity,
    :target_false_positive_rate,
    :growth_factor,
    :error_tightening_ratio,
    :items_count,
    :backend
  ]

  @default_growth_factor 2
  @default_error_tightening 0.8

  @doc """
  Create a new scalable bloom filter.

  ## Parameters

    * `initial_capacity` - Starting capacity for the first slice
    * `opts` - Keyword list of options:
      * `:false_positive_rate` - Target false positive rate (default: 0.01)
      * `:growth_factor` - Capacity multiplier for new slices (default: 2)
      * `:error_tightening_ratio` - Error rate multiplier for new slices (default: 0.8)
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new `Bloomy.Scalable` struct.

  ## Examples

      iex> filter = Bloomy.Scalable.new(1000)
      iex> filter.initial_capacity
      1000

      iex> filter = Bloomy.Scalable.new(1000, growth_factor: 3, error_tightening_ratio: 0.5)
      iex> filter.growth_factor
      3
  """
  @impl true
  def new(initial_capacity, opts \\ []) when is_integer(initial_capacity) and initial_capacity > 0 do
    false_positive_rate = Keyword.get(opts, :false_positive_rate, 0.01)
    growth_factor = Keyword.get(opts, :growth_factor, @default_growth_factor)
    error_tightening_ratio = Keyword.get(opts, :error_tightening_ratio, @default_error_tightening)
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    # Create initial slice
    initial_slice = Standard.new(initial_capacity, false_positive_rate: false_positive_rate, backend: backend)

    %__MODULE__{
      slices: [initial_slice],
      initial_capacity: initial_capacity,
      target_false_positive_rate: false_positive_rate,
      growth_factor: growth_factor,
      error_tightening_ratio: error_tightening_ratio,
      items_count: 0,
      backend: backend
    }
  end

  @doc """
  Add an item to the scalable bloom filter.

  Automatically creates a new slice if the current slice is at capacity.

  ## Parameters

    * `filter` - The scalable bloom filter struct
    * `item` - Item to add

  ## Returns

  Updated scalable bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Scalable.new(10)
      iex> filter = Enum.reduce(1..50, filter, fn i, f ->
      iex>   Bloomy.Scalable.add(f, i)
      iex> end)
      iex> info = Bloomy.Scalable.info(filter)
      iex> info.slices_count > 1
      true
  """
  @impl true
  def add(%__MODULE__{} = filter, item) do
    # Get current (most recent) slice
    [current_slice | rest] = filter.slices

    # Check if current slice is at capacity
    if Standard.at_capacity?(current_slice) do
      # Create new slice and add item to it
      new_slice = create_next_slice(filter)
      new_slice = Standard.add(new_slice, item)

      %{filter | slices: [new_slice, current_slice | rest], items_count: filter.items_count + 1}
    else
      # Add to current slice
      updated_slice = Standard.add(current_slice, item)
      %{filter | slices: [updated_slice | rest], items_count: filter.items_count + 1}
    end
  end

  @doc """
  Add multiple items to the scalable bloom filter.

  ## Parameters

    * `filter` - The scalable bloom filter struct
    * `items` - List of items to add

  ## Returns

  Updated scalable bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Scalable.new(1000)
      iex> filter = Bloomy.Scalable.add_all(filter, ["a", "b", "c"])
      iex> filter.items_count
      3
  """
  def add_all(%__MODULE__{} = filter, items) when is_list(items) do
    Enum.reduce(items, filter, fn item, acc -> add(acc, item) end)
  end

  @doc """
  Check if an item might be in the scalable bloom filter.

  Checks all slices - returns true if any slice contains the item.

  ## Parameters

    * `filter` - The scalable bloom filter struct
    * `item` - Item to check

  ## Returns

  Boolean - true if item might be present, false if definitely not present.

  ## Examples

      iex> filter = Bloomy.Scalable.new(1000)
      iex> filter = Bloomy.Scalable.add(filter, "hello")
      iex> Bloomy.Scalable.member?(filter, "hello")
      true
      iex> Bloomy.Scalable.member?(filter, "world")
      false
  """
  @impl true
  def member?(%__MODULE__{} = filter, item) do
    # Check if item is in any slice
    Enum.any?(filter.slices, fn slice ->
      Standard.member?(slice, item)
    end)
  end

  @doc """
  Get information and statistics about the scalable bloom filter.

  ## Parameters

    * `filter` - The scalable bloom filter struct

  ## Returns

  Map containing filter statistics including per-slice information.

  ## Examples

      iex> filter = Bloomy.Scalable.new(1000)
      iex> info = Bloomy.Scalable.info(filter)
      iex> info.type
      :scalable
      iex> info.slices_count
      1
  """
  @impl true
  def info(%__MODULE__{} = filter) do
    slices_info = Enum.map(filter.slices, &Standard.info/1)

    total_size = Enum.sum(Enum.map(slices_info, & &1.size))
    total_capacity = Enum.sum(Enum.map(slices_info, & &1.capacity))
    avg_fill_ratio = Enum.sum(Enum.map(slices_info, & &1.fill_ratio)) / length(slices_info)

    # Calculate combined false positive rate
    combined_fp_rate = calculate_combined_error_rate(filter)

    %{
      type: :scalable,
      slices_count: length(filter.slices),
      items_count: filter.items_count,
      total_size: total_size,
      total_capacity: total_capacity,
      average_fill_ratio: Float.round(avg_fill_ratio, 4),
      target_false_positive_rate: filter.target_false_positive_rate,
      combined_false_positive_rate: Float.round(combined_fp_rate, 6),
      initial_capacity: filter.initial_capacity,
      growth_factor: filter.growth_factor,
      error_tightening_ratio: filter.error_tightening_ratio,
      backend: filter.backend,
      slices: slices_info,
      total_memory_bytes: Float.round(total_size / 8, 2)
    }
  end

  @doc """
  Clear the scalable bloom filter.

  Resets to initial state with a single empty slice.

  ## Parameters

    * `filter` - The scalable bloom filter struct

  ## Returns

  Cleared scalable bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Scalable.new(1000)
      iex> filter = Bloomy.Scalable.add_all(filter, Enum.to_list(1..2000))
      iex> filter.items_count > 0
      true
      iex> filter = Bloomy.Scalable.clear(filter)
      iex> filter.items_count
      0
      iex> info = Bloomy.Scalable.info(filter)
      iex> info.slices_count
      1
  """
  @impl true
  def clear(%__MODULE__{} = filter) do
    # Reset to initial state with one empty slice
    initial_slice = Standard.new(
      filter.initial_capacity,
      false_positive_rate: filter.target_false_positive_rate,
      backend: filter.backend
    )

    %{filter | slices: [initial_slice], items_count: 0}
  end

  @doc """
  Get the current slice (most recent bloom filter).

  ## Parameters

    * `filter` - The scalable bloom filter struct

  ## Returns

  The current active slice.
  """
  def current_slice(%__MODULE__{slices: [current | _]}), do: current

  @doc """
  Get all slices in the scalable bloom filter.

  ## Parameters

    * `filter` - The scalable bloom filter struct

  ## Returns

  List of all bloom filter slices (most recent first).
  """
  def all_slices(%__MODULE__{slices: slices}), do: slices

  @doc """
  Force creation of a new slice even if current is not at capacity.

  Useful for manual capacity management or testing.

  ## Parameters

    * `filter` - The scalable bloom filter struct

  ## Returns

  Updated scalable bloom filter struct with a new slice.
  """
  def add_slice(%__MODULE__{} = filter) do
    new_slice = create_next_slice(filter)
    %{filter | slices: [new_slice | filter.slices]}
  end

  # Private helper functions

  defp create_next_slice(%__MODULE__{} = filter) do
    slice_index = length(filter.slices)

    # Calculate capacity for new slice: growth_factor^slice_index * initial_capacity
    new_capacity = round(filter.initial_capacity * :math.pow(filter.growth_factor, slice_index))

    # Calculate error rate for new slice: error_tightening_ratio^slice_index * target_rate
    new_error_rate = filter.target_false_positive_rate * :math.pow(filter.error_tightening_ratio, slice_index)

    # Ensure error rate doesn't get too small
    new_error_rate = max(new_error_rate, 0.0001)

    Standard.new(new_capacity, false_positive_rate: new_error_rate, backend: filter.backend)
  end

  defp calculate_combined_error_rate(%__MODULE__{} = filter) do
    # For a scalable bloom filter, the combined error rate is approximately
    # the sum of error rates weighted by the probability of checking each slice
    #
    # P_total ≈ Σ (P_i * (1 - P_j for all j < i))
    #
    # For simplicity, we approximate using the formula:
    # P_total ≈ Σ P_i where P_i is tightened appropriately

    filter.slices
    |> Enum.with_index()
    |> Enum.map(fn {_slice, index} ->
      filter.target_false_positive_rate * :math.pow(filter.error_tightening_ratio, index)
    end)
    |> Enum.sum()
    |> min(1.0)
  end
end

# Implement the Bloomy.Protocol for Scalable bloom filter
defimpl Bloomy.Protocol, for: Bloomy.Scalable do
  def add(filter, item), do: Bloomy.Scalable.add(filter, item)
  def member?(filter, item), do: Bloomy.Scalable.member?(filter, item)
  def info(filter), do: Bloomy.Scalable.info(filter)
  def clear(filter), do: Bloomy.Scalable.clear(filter)
end
