defmodule Bloomy.BitArray do
  @moduledoc """
  Efficient bit array implementation using Nx tensors.

  This module provides a high-performance bit array using Nx tensors,
  enabling vectorized operations and EXLA acceleration for GPU/CPU computing.

  ## Examples

      iex> bit_array = Bloomy.BitArray.new(1000)
      iex> bit_array = Bloomy.BitArray.set(bit_array, [10, 20, 30])
      iex> Bloomy.BitArray.get(bit_array, 10)
      true
      iex> Bloomy.BitArray.get(bit_array, 15)
      false
  """

  import Nx.Defn

  @type t :: %__MODULE__{
          bits: Nx.Tensor.t(),
          size: non_neg_integer(),
          backend: atom()
        }

  defstruct [:bits, :size, :backend]

  @doc """
  Create a new bit array of given size.

  All bits are initialized to 0.

  ## Parameters

    * `size` - Number of bits in the array
    * `opts` - Optional keyword list with:
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new BitArray struct.

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba.size
      100
  """
  def new(size, opts \\ []) when is_integer(size) and size > 0 do
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    bits = Nx.broadcast(0, {size})
    |> Nx.as_type(:u8)
    |> Nx.backend_transfer(backend)

    %__MODULE__{
      bits: bits,
      size: size,
      backend: backend
    }
  end

  @doc """
  Set bits at given indices to 1.

  ## Parameters

    * `bit_array` - The BitArray struct
    * `indices` - Single index (integer) or list of indices, or Nx tensor of indices

  ## Returns

  Updated BitArray struct with specified bits set.

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, 42)
      iex> Bloomy.BitArray.get(ba, 42)
      true

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, [10, 20, 30])
      iex> Bloomy.BitArray.get(ba, [10, 20, 30])
      [true, true, true]
  """
  def set(%__MODULE__{bits: bits, size: size, backend: backend} = bit_array, indices) do
    indices_tensor = normalize_indices(indices, size)

    # Use put_slice for efficient batch updates
    new_bits = set_bits_at_indices(bits, indices_tensor)

    %{bit_array | bits: new_bits}
  end

  @doc """
  Check if bits at given indices are set (value is 1).

  ## Parameters

    * `bit_array` - The BitArray struct
    * `indices` - Single index (integer) or list of indices, or Nx tensor of indices

  ## Returns

  Boolean (for single index) or list of booleans (for multiple indices).

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, [10, 20])
      iex> Bloomy.BitArray.get(ba, 10)
      true
      iex> Bloomy.BitArray.get(ba, 11)
      false
      iex> Bloomy.BitArray.get(ba, [10, 11, 20])
      [true, false, true]
  """
  def get(%__MODULE__{bits: bits}, indices) when is_integer(indices) do
    value = bits[indices] |> Nx.to_number()
    value == 1
  end

  def get(%__MODULE__{bits: bits, size: size}, indices) when is_list(indices) do
    indices_tensor = normalize_indices(indices, size)
    values = get_bits_at_indices(bits, indices_tensor)

    values
    |> Nx.to_flat_list()
    |> Enum.map(&(&1 == 1))
  end

  def get(%__MODULE__{bits: bits}, %Nx.Tensor{} = indices) do
    values = get_bits_at_indices(bits, indices)

    values
    |> Nx.to_flat_list()
    |> Enum.map(&(&1 == 1))
  end

  @doc """
  Check if all bits at given indices are set to 1.

  Useful for bloom filter membership tests.

  ## Parameters

    * `bit_array` - The BitArray struct
    * `indices` - Nx tensor or list of indices

  ## Returns

  Boolean indicating if all specified bits are set.

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, [10, 20, 30])
      iex> Bloomy.BitArray.all_set?(ba, [10, 20, 30])
      true
      iex> Bloomy.BitArray.all_set?(ba, [10, 20, 40])
      false
  """
  def all_set?(%__MODULE__{bits: bits, size: size}, indices) do
    indices_tensor = normalize_indices(indices, size)
    check_all_bits_set(bits, indices_tensor)
    |> Nx.to_number()
    |> then(&(&1 == 1))
  end

  @doc """
  Count the number of bits set to 1.

  ## Parameters

    * `bit_array` - The BitArray struct

  ## Returns

  Number of bits set to 1.

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, [10, 20, 30])
      iex> Bloomy.BitArray.count(ba)
      3
  """
  def count(%__MODULE__{bits: bits}) do
    count_set_bits(bits)
    |> Nx.to_number()
  end

  @doc """
  Calculate the fill ratio (proportion of bits set to 1).

  ## Parameters

    * `bit_array` - The BitArray struct

  ## Returns

  Float between 0.0 and 1.0 representing the fill ratio.

  ## Examples

      iex> ba = Bloomy.BitArray.new(100)
      iex> ba = Bloomy.BitArray.set(ba, [10, 20, 30])
      iex> Bloomy.BitArray.fill_ratio(ba)
      0.03
  """
  def fill_ratio(%__MODULE__{bits: bits, size: size}) do
    count = count_set_bits(bits) |> Nx.to_number()
    count / size
  end

  @doc """
  Perform bitwise OR with another bit array (union operation).

  Both bit arrays must have the same size.

  ## Parameters

    * `bit_array1` - First BitArray
    * `bit_array2` - Second BitArray

  ## Returns

  New BitArray containing the union (OR) of both arrays.

  ## Examples

      iex> ba1 = Bloomy.BitArray.new(100) |> Bloomy.BitArray.set([10, 20])
      iex> ba2 = Bloomy.BitArray.new(100) |> Bloomy.BitArray.set([20, 30])
      iex> ba_union = Bloomy.BitArray.union(ba1, ba2)
      iex> Bloomy.BitArray.count(ba_union)
      3
  """
  def union(
        %__MODULE__{bits: bits1, size: size, backend: backend},
        %__MODULE__{bits: bits2, size: size}
      ) do
    new_bits = bitwise_or(bits1, bits2)

    %__MODULE__{
      bits: new_bits,
      size: size,
      backend: backend
    }
  end

  def union(%__MODULE__{size: size1}, %__MODULE__{size: size2}) do
    raise ArgumentError,
          "Cannot union bit arrays of different sizes: #{size1} and #{size2}"
  end

  @doc """
  Perform bitwise AND with another bit array (intersection operation).

  Both bit arrays must have the same size.

  ## Parameters

    * `bit_array1` - First BitArray
    * `bit_array2` - Second BitArray

  ## Returns

  New BitArray containing the intersection (AND) of both arrays.

  ## Examples

      iex> ba1 = Bloomy.BitArray.new(100) |> Bloomy.BitArray.set([10, 20, 30])
      iex> ba2 = Bloomy.BitArray.new(100) |> Bloomy.BitArray.set([20, 30, 40])
      iex> ba_intersect = Bloomy.BitArray.intersect(ba1, ba2)
      iex> Bloomy.BitArray.count(ba_intersect)
      2
  """
  def intersect(
        %__MODULE__{bits: bits1, size: size, backend: backend},
        %__MODULE__{bits: bits2, size: size}
      ) do
    new_bits = bitwise_and(bits1, bits2)

    %__MODULE__{
      bits: new_bits,
      size: size,
      backend: backend
    }
  end

  def intersect(%__MODULE__{size: size1}, %__MODULE__{size: size2}) do
    raise ArgumentError,
          "Cannot intersect bit arrays of different sizes: #{size1} and #{size2}"
  end

  @doc """
  Clear all bits (set to 0).

  ## Parameters

    * `bit_array` - The BitArray struct

  ## Returns

  New BitArray with all bits set to 0.
  """
  def clear(%__MODULE__{size: size, backend: backend}) do
    new(size, backend: backend)
  end

  # Private helper functions using Nx.Defn for JIT compilation

  defnp set_bits_at_indices(bits, indices) do
    # Create a tensor of ones with the same shape as indices
    ones = Nx.broadcast(1, Nx.shape(indices)) |> Nx.as_type(:u8)

    # Use indexed_put to set bits at indices
    Nx.indexed_put(bits, Nx.new_axis(indices, -1), ones)
  end

  defnp get_bits_at_indices(bits, indices) do
    # Use indexed_add to gather values at indices
    Nx.take(bits, indices)
  end

  defnp check_all_bits_set(bits, indices) do
    # Get all bits at indices and check if all are 1
    values = Nx.take(bits, indices)
    Nx.all(Nx.equal(values, 1))
    |> Nx.as_type(:u8)
  end

  defnp count_set_bits(bits) do
    Nx.sum(bits)
  end

  defnp bitwise_or(bits1, bits2) do
    # Bitwise OR using logical_or and conversion
    Nx.logical_or(Nx.greater(bits1, 0), Nx.greater(bits2, 0))
    |> Nx.as_type(:u8)
  end

  defnp bitwise_and(bits1, bits2) do
    # Bitwise AND using logical_and and conversion
    Nx.logical_and(Nx.greater(bits1, 0), Nx.greater(bits2, 0))
    |> Nx.as_type(:u8)
  end

  # Helper to normalize indices to Nx tensor
  defp normalize_indices(indices, _size) when is_integer(indices) do
    Nx.tensor([indices], type: :s64)
  end

  defp normalize_indices(indices, _size) when is_list(indices) do
    Nx.tensor(indices, type: :s64)
  end

  defp normalize_indices(%Nx.Tensor{} = indices, _size) do
    Nx.as_type(indices, :s64)
  end
end
