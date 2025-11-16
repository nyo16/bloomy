defmodule Bloomy do
  @moduledoc """
  Bloomy - High-performance Bloom Filter library for Elixir using Nx.

  Bloomy provides probabilistic data structures for efficient set membership testing
  with minimal memory usage. Built on Nx tensors for high performance and EXLA
  acceleration support.

  ## Features

  - **Multiple Filter Types**:
    - Standard Bloom Filter - Classic space-efficient probabilistic filter
    - Counting Bloom Filter - Supports deletion operations
    - Scalable Bloom Filter - Automatically grows with your data
    - Learned Bloom Filter - ML-enhanced for lower false positives

  - **High Performance**:
    - Nx tensor-based operations
    - EXLA backend support for GPU/CPU acceleration
    - Vectorized hash computations
    - Efficient batch operations

  - **Production Ready**:
    - Serialization and persistence
    - Merge operations (union/intersection)
    - Comprehensive statistics and monitoring
    - Optimal parameter calculation

  ## Quick Start

      # Create a standard bloom filter for 1000 items with 1% false positive rate
      filter = Bloomy.new(1000, false_positive_rate: 0.01)

      # Add items
      filter = filter
        |> Bloomy.add("apple")
        |> Bloomy.add("banana")
        |> Bloomy.add("orange")

      # Check membership
      Bloomy.member?(filter, "apple")    # => true
      Bloomy.member?(filter, "grape")    # => false

      # Get statistics
      Bloomy.info(filter)

  ## Bloom Filter Types

  ### Standard Bloom Filter

      filter = Bloomy.new(10000)
      filter = Bloomy.add(filter, "user@example.com")
      Bloomy.member?(filter, "user@example.com")  # => true

  ### Counting Bloom Filter (supports deletion)

      filter = Bloomy.new(10000, type: :counting)
      filter = Bloomy.add(filter, "item")
      filter = Bloomy.remove(filter, "item")
      Bloomy.member?(filter, "item")  # => false

  ### Scalable Bloom Filter (auto-grows)

      filter = Bloomy.new(1000, type: :scalable)
      # Add millions of items - it will automatically scale
      filter = Enum.reduce(1..1_000_000, filter, fn i, f ->
        Bloomy.add(f, "item_\#{i}")
      end)

  ### Learned Bloom Filter (ML-enhanced)

      filter = Bloomy.new(10000, type: :learned)

      # Train with examples
      training_data = %{
        positive: ["valid_1", "valid_2", "valid_3"],
        negative: ["invalid_1", "invalid_2", "invalid_3"]
      }
      filter = Bloomy.train(filter, training_data)

      # Use as normal
      filter = Bloomy.add(filter, "valid_1")
      Bloomy.member?(filter, "valid_1")  # => true

  ## Persistence

      # Save to file
      Bloomy.save(filter, "my_filter.bloom")

      # Load from file
      {:ok, filter} = Bloomy.load("my_filter.bloom")

  ## Operations

      # Union multiple filters
      filters = [filter1, filter2, filter3]
      merged = Bloomy.union_all(filters)

      # Create from list
      filter = Bloomy.from_list(["a", "b", "c"])

      # Batch membership test
      results = Bloomy.batch_member?(filter, ["a", "b", "z"])

  ## Performance

  For optimal performance, consider using the EXLA backend:

      # In your application or config
      Nx.default_backend(EXLA.Backend)

      filter = Bloomy.new(1_000_000, backend: EXLA.Backend)
  """

  alias Bloomy.{Standard, Counting, Scalable, Learned, Operations, Serialization}

  @type bloom_filter :: Standard.t() | Counting.t() | Scalable.t() | Learned.t()

  @doc """
  Create a new bloom filter.

  ## Parameters

    * `capacity` - Expected number of items
    * `opts` - Keyword list of options:
      * `:type` - Filter type: `:standard`, `:counting`, `:scalable`, `:learned` (default: `:standard`)
      * `:false_positive_rate` - Desired false positive rate (default: 0.01)
      * `:backend` - Nx backend to use (default: Nx.default_backend())
      * For counting filters:
        * `:counter_width` - Bits per counter: 8, 16, or 32 (default: 8)
      * For scalable filters:
        * `:growth_factor` - Capacity multiplier for new slices (default: 2)
        * `:error_tightening_ratio` - Error rate multiplier (default: 0.8)
      * For learned filters:
        * `:confidence_threshold` - Model confidence threshold (default: 0.7)

  ## Returns

  A new bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> filter = Bloomy.new(1000, type: :counting)
      iex> filter = Bloomy.new(1000, type: :scalable, false_positive_rate: 0.001)
  """
  def new(capacity, opts \\ []) do
    type = Keyword.get(opts, :type, :standard)

    case type do
      :standard -> Standard.new(capacity, opts)
      :counting -> Counting.new(capacity, opts)
      :scalable -> Scalable.new(capacity, opts)
      :learned -> Learned.new(capacity, opts)
      _ -> raise ArgumentError, "Unknown bloom filter type: #{type}"
    end
  end

  @doc """
  Add an item to the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to add (any term)

  ## Returns

  Updated bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> filter = Bloomy.add(filter, "hello")
  """
  def add(filter, item) do
    Bloomy.Protocol.add(filter, item)
  end

  @doc """
  Add multiple items to the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct
    * `items` - List of items to add

  ## Returns

  Updated bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> filter = Bloomy.add_all(filter, ["a", "b", "c"])
  """
  def add_all(%Standard{} = filter, items), do: Standard.add_all(filter, items)
  def add_all(%Counting{} = filter, items), do: Counting.add_all(filter, items)
  def add_all(%Scalable{} = filter, items), do: Scalable.add_all(filter, items)

  def add_all(filter, items) do
    Enum.reduce(items, filter, &add(&2, &1))
  end

  @doc """
  Remove an item from a counting bloom filter.

  Only works with counting bloom filters. Raises for other types.

  ## Parameters

    * `filter` - The counting bloom filter struct
    * `item` - Item to remove

  ## Returns

  Updated counting bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000, type: :counting)
      iex> filter = Bloomy.add(filter, "hello")
      iex> filter = Bloomy.remove(filter, "hello")
  """
  def remove(%Counting{} = filter, item) do
    Counting.remove(filter, item)
  end

  def remove(_filter, _item) do
    raise ArgumentError, "Remove operation only supported for counting bloom filters"
  end

  @doc """
  Check if an item might be in the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct
    * `item` - Item to check

  ## Returns

  Boolean - `true` if item might be present (or false positive), `false` if definitely not present.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> filter = Bloomy.add(filter, "hello")
      iex> Bloomy.member?(filter, "hello")
      true
      iex> Bloomy.member?(filter, "world")
      false
  """
  def member?(filter, item) do
    Bloomy.Protocol.member?(filter, item)
  end

  @doc """
  Get information and statistics about the bloom filter.

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Map with filter statistics.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> info = Bloomy.info(filter)
      iex> info.capacity
      1000
  """
  def info(filter) do
    Bloomy.Protocol.info(filter)
  end

  @doc """
  Clear the bloom filter (reset to empty state).

  ## Parameters

    * `filter` - The bloom filter struct

  ## Returns

  Cleared bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> filter = Bloomy.add(filter, "test")
      iex> filter = Bloomy.clear(filter)
      iex> Bloomy.member?(filter, "test")
      false
  """
  def clear(filter) do
    Bloomy.Protocol.clear(filter)
  end

  @doc """
  Train a learned bloom filter.

  Only works with learned bloom filters. Raises for other types.

  ## Parameters

    * `filter` - The learned bloom filter struct
    * `training_data` - Map with `:positive` and `:negative` example lists
    * `opts` - Training options (epochs, learning_rate)

  ## Returns

  Trained bloom filter struct.

  ## Examples

      iex> filter = Bloomy.new(1000, type: :learned)
      iex> training_data = %{
      iex>   positive: ["item1", "item2"],
      iex>   negative: ["other1", "other2"]
      iex> }
      iex> filter = Bloomy.train(filter, training_data)
  """
  def train(filter, training_data, opts \\ [])

  def train(%Learned{} = filter, training_data, opts) do
    Learned.train(filter, training_data, opts)
  end

  def train(_filter, _training_data, _opts) do
    raise ArgumentError, "Train operation only supported for learned bloom filters"
  end

  @doc """
  Save a bloom filter to a file.

  ## Parameters

    * `filter` - The bloom filter struct
    * `path` - File path
    * `opts` - Options for serialization

  ## Returns

  `:ok` on success, `{:error, reason}` on failure.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> Bloomy.save(filter, "/tmp/my_filter.bloom")
      :ok
  """
  def save(filter, path, opts \\ []) do
    Serialization.save(filter, path, opts)
  end

  @doc """
  Load a bloom filter from a file.

  ## Parameters

    * `path` - File path
    * `opts` - Options for deserialization

  ## Returns

  `{:ok, filter}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> {:ok, filter} = Bloomy.load("/tmp/my_filter.bloom")
  """
  def load(path, opts \\ []) do
    Serialization.load(path, opts)
  end

  @doc """
  Serialize a bloom filter to binary.

  ## Parameters

    * `filter` - The bloom filter struct
    * `opts` - Serialization options

  ## Returns

  Binary data.

  ## Examples

      iex> filter = Bloomy.new(1000)
      iex> binary = Bloomy.to_binary(filter)
  """
  def to_binary(filter, opts \\ []) do
    Serialization.to_binary(filter, opts)
  end

  @doc """
  Deserialize a bloom filter from binary.

  ## Parameters

    * `binary` - Binary data
    * `opts` - Deserialization options

  ## Returns

  `{:ok, filter}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> {:ok, filter} = Bloomy.from_binary(binary)
  """
  def from_binary(binary, opts \\ []) do
    Serialization.from_binary(binary, opts)
  end

  @doc """
  Union (merge) multiple bloom filters.

  ## Parameters

    * `filters` - List of bloom filters (must be compatible)

  ## Returns

  New bloom filter containing union of all filters.

  ## Examples

      iex> filters = [filter1, filter2, filter3]
      iex> merged = Bloomy.union_all(filters)
  """
  def union_all(filters) when is_list(filters) do
    Operations.union_all(filters)
  end

  @doc """
  Union two bloom filters.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  New bloom filter containing union.

  ## Examples

      iex> merged = Bloomy.union(filter1, filter2)
  """
  def union(filter1, filter2) do
    union_all([filter1, filter2])
  end

  @doc """
  Intersection of multiple bloom filters.

  ## Parameters

    * `filters` - List of bloom filters (must be compatible)

  ## Returns

  New bloom filter containing intersection.

  ## Examples

      iex> intersect = Bloomy.intersect_all([filter1, filter2, filter3])
  """
  def intersect_all(filters) when is_list(filters) do
    Operations.intersect_all(filters)
  end

  @doc """
  Create a bloom filter from a list of items.

  ## Parameters

    * `items` - List of items
    * `opts` - Options for filter creation

  ## Returns

  New bloom filter containing all items.

  ## Examples

      iex> filter = Bloomy.from_list(["a", "b", "c"])
  """
  def from_list(items, opts \\ []) do
    Operations.from_list(items, opts)
  end

  @doc """
  Test multiple items for membership in batch.

  ## Parameters

    * `filter` - The bloom filter struct
    * `items` - List of items to test

  ## Returns

  Map with items as keys and membership results as values.

  ## Examples

      iex> results = Bloomy.batch_member?(filter, ["a", "b", "c"])
      iex> results["a"]
      true
  """
  def batch_member?(filter, items) do
    Operations.batch_member?(filter, items)
  end

  @doc """
  Calculate Jaccard similarity between two bloom filters.

  ## Parameters

    * `filter1` - First bloom filter
    * `filter2` - Second bloom filter

  ## Returns

  Float between 0.0 and 1.0.

  ## Examples

      iex> similarity = Bloomy.jaccard_similarity(filter1, filter2)
  """
  def jaccard_similarity(%Standard{} = filter1, %Standard{} = filter2) do
    Operations.jaccard_similarity(filter1, filter2)
  end
end
