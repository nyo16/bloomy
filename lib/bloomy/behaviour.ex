defmodule Bloomy.Behaviour do
  @moduledoc """
  Behaviour definition for bloom filter implementations.

  This module defines the protocol that all bloom filter types must implement,
  ensuring a consistent API across Standard, Counting, and Scalable bloom filters.

  ## Callbacks

  All bloom filter implementations must implement:

  - `new/2` - Create a new bloom filter
  - `add/2` - Add an item to the filter
  - `member?/2` - Check if an item might be in the filter
  - `info/1` - Get filter statistics and metadata

  Optional callbacks:

  - `remove/2` - Remove an item (for counting bloom filters)
  - `clear/1` - Reset the filter to empty state
  """

  @doc """
  Create a new bloom filter.

  ## Parameters

    * `capacity` - Expected number of items
    * `opts` - Keyword list of options:
      * `:false_positive_rate` - Desired false positive rate (default: 0.01)
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new bloom filter struct.
  """
  @callback new(capacity :: pos_integer(), opts :: keyword()) :: struct()

  @doc """
  Add an item to the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to add (any term that can be hashed)

  ## Returns

  Updated bloom filter struct.
  """
  @callback add(filter :: struct(), item :: term()) :: struct()

  @doc """
  Check if an item might be in the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to check

  ## Returns

  Boolean indicating possible membership:
  - `true` - Item might be in the set (or false positive)
  - `false` - Item is definitely not in the set
  """
  @callback member?(filter :: struct(), item :: term()) :: boolean()

  @doc """
  Get information about the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Map with filter statistics including:
  - `:type` - Type of bloom filter
  - `:capacity` - Expected capacity
  - `:size` - Bit array size
  - `:hash_functions` - Number of hash functions
  - `:items_count` - Number of items added
  - `:fill_ratio` - Proportion of bits set
  - `:false_positive_rate` - Expected false positive rate
  """
  @callback info(filter :: struct()) :: map()

  @doc """
  Remove an item from the bloom filter.

  Optional callback - only supported by counting bloom filters.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to remove

  ## Returns

  Updated bloom filter struct.
  """
  @callback remove(filter :: struct(), item :: term()) :: struct()

  @doc """
  Clear the bloom filter (reset to empty state).

  Optional callback.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Cleared bloom filter struct.
  """
  @callback clear(filter :: struct()) :: struct()

  @optional_callbacks remove: 2, clear: 1

  @doc """
  Check if a module implements the Bloomy.Behaviour protocol.

  ## Parameters

    * `module` - Module to check

  ## Returns

  Boolean indicating if module implements the behaviour.
  """
  def implements?(module) when is_atom(module) do
    :attributes
    |> module.module_info()
    |> Keyword.get_values(:behaviour)
    |> List.flatten()
    |> Enum.member?(__MODULE__)
  rescue
    _ -> false
  end
end

defprotocol Bloomy.Protocol do
  @moduledoc """
  Protocol for bloom filter operations.

  This protocol provides a polymorphic interface for different bloom filter types,
  allowing generic functions to work with any bloom filter implementation.
  """

  @doc """
  Add an item to the bloom filter.
  """
  @spec add(t(), term()) :: t()
  def add(filter, item)

  @doc """
  Check if an item might be in the bloom filter.
  """
  @spec member?(t(), term()) :: boolean()
  def member?(filter, item)

  @doc """
  Get information about the bloom filter.
  """
  @spec info(t()) :: map()
  def info(filter)

  @doc """
  Clear the bloom filter.
  """
  @spec clear(t()) :: t()
  def clear(filter)
end

defmodule Bloomy.Stats do
  @moduledoc """
  Statistics tracking for bloom filters.

  Provides functionality to track and report statistics about bloom filter
  usage and performance.
  """

  @type t :: %__MODULE__{
          adds: non_neg_integer(),
          queries: non_neg_integer(),
          true_positives: non_neg_integer(),
          false_positives: non_neg_integer(),
          true_negatives: non_neg_integer()
        }

  defstruct adds: 0,
            queries: 0,
            true_positives: 0,
            false_positives: 0,
            true_negatives: 0

  @doc """
  Create a new stats tracker.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Record an add operation.
  """
  def record_add(%__MODULE__{} = stats) do
    %{stats | adds: stats.adds + 1}
  end

  @doc """
  Record a query operation.
  """
  def record_query(%__MODULE__{} = stats, result) when is_boolean(result) do
    %{stats | queries: stats.queries + 1}
  end

  @doc """
  Get statistics summary.
  """
  def summary(%__MODULE__{} = stats) do
    total_results = stats.true_positives + stats.false_positives + stats.true_negatives

    fp_rate =
      if total_results > 0 do
        stats.false_positives / total_results
      else
        0.0
      end

    %{
      total_adds: stats.adds,
      total_queries: stats.queries,
      true_positives: stats.true_positives,
      false_positives: stats.false_positives,
      true_negatives: stats.true_negatives,
      false_positive_rate: Float.round(fp_rate * 100, 4)
    }
  end
end
