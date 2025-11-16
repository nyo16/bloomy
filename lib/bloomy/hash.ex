defmodule Bloomy.Hash do
  @moduledoc """
  Hash function utilities for bloom filters using Nx tensors.

  This module provides efficient hash functions using the double hashing technique:
  `h_i(x) = (h1(x) + i * h2(x)) mod m`

  This allows generating k hash values from only 2 base hash computations,
  which is both efficient and provides good distribution properties.

  ## Examples

      iex> item = "hello"
      iex> hashes = Bloomy.Hash.hash(item, 5, 1000)
      iex> Nx.shape(hashes)
      {5}
  """

  import Nx.Defn

  @doc """
  Generate k hash values for an item using double hashing.

  ## Parameters

    * `item` - The item to hash (will be converted to binary)
    * `k` - Number of hash values to generate
    * `m` - Size of the bit array (hash values will be in range 0..m-1)

  ## Returns

  An Nx tensor of shape {k} containing hash indices in range 0..m-1.

  ## Examples

      iex> hashes = Bloomy.Hash.hash("test", 3, 100)
      iex> Nx.shape(hashes)
      {3}
      iex> Nx.to_list(hashes) |> Enum.all?(&(&1 >= 0 and &1 < 100))
      true
  """
  def hash(item, k, m) do
    binary = to_binary(item)

    # Generate two base hashes using different algorithms
    h1 = murmur3_hash(binary)
    h2 = fnv1a_hash(binary)

    # Create indices tensor [0, 1, 2, ..., k-1]
    indices = Nx.iota({k}, type: :s64)

    # Use double hashing to generate k hash values
    # h_i(x) = (h1(x) + i * h2(x)) mod m
    double_hash(h1, h2, indices, m)
  end

  @doc """
  Generate k hash indices using double hashing technique.

  Given two base hash values, generates k unique hash indices using:
  `h_i = (h1 + i * h2) mod m` for i in 0..(k-1)

  ## Parameters

    * `h1` - First base hash value
    * `h2` - Second base hash value
    * `indices` - Tensor of indices [0, 1, 2, ..., k-1]
    * `m` - Size of the bit array (modulo value)

  ## Returns

  An Nx tensor of shape {k} containing hash indices.
  """
  defn double_hash(h1, h2, indices, m) do
    # Apply double hashing formula: (h1 + i * h2) mod m
    # Make sure h2 is non-zero to ensure proper distribution
    h2_safe = Nx.select(h2 == 0, 1, h2)

    # Compute hashes and ensure they're positive
    hashes = Nx.add(h1, Nx.multiply(indices, h2_safe))
    |> Nx.remainder(m)

    # Handle negative remainders by adding m
    hashes = Nx.select(Nx.less(hashes, 0), Nx.add(hashes, m), hashes)

    hashes
  end

  @doc """
  MurmurHash3 implementation for 32-bit hash values.

  This is a fast, non-cryptographic hash function with good distribution properties.

  ## Parameters

    * `binary` - Binary data to hash

  ## Returns

  A 32-bit unsigned integer hash value.
  """
  def murmur3_hash(binary) when is_binary(binary) do
    seed = 0x9747B28C
    murmur3_32(binary, seed)
  end

  defp murmur3_32(binary, seed) do
    # MurmurHash3 32-bit implementation
    len = byte_size(binary)

    # Process 4-byte chunks
    {h1, rest} = process_chunks(binary, seed, 0)

    # Process remaining bytes
    h1 = process_tail(rest, h1)

    # Finalization mix
    h1 = Bitwise.bxor(h1, len)
    h1 = fmix32(h1)

    h1
  end

  defp process_chunks(<<k1::little-unsigned-32, rest::binary>>, h1, _offset) do
    c1 = 0xCC9E2D51
    c2 = 0x1B873593

    k1 = Bitwise.band(k1 * c1, 0xFFFFFFFF)
    k1 = Bitwise.bor(Bitwise.bsl(k1, 15), Bitwise.bsr(k1, 17))
    k1 = Bitwise.band(k1 * c2, 0xFFFFFFFF)

    h1 = Bitwise.bxor(h1, k1)
    h1 = Bitwise.bor(Bitwise.bsl(h1, 13), Bitwise.bsr(h1, 19))
    h1 = Bitwise.band(h1 * 5 + 0xE6546B64, 0xFFFFFFFF)

    process_chunks(rest, h1, 0)
  end

  defp process_chunks(rest, h1, _offset), do: {h1, rest}

  defp process_tail(<<>>, h1), do: h1

  defp process_tail(rest, h1) do
    c1 = 0xCC9E2D51
    c2 = 0x1B873593

    k1 = tail_to_int(rest)
    k1 = Bitwise.band(k1 * c1, 0xFFFFFFFF)
    k1 = Bitwise.bor(Bitwise.bsl(k1, 15), Bitwise.bsr(k1, 17))
    k1 = Bitwise.band(k1 * c2, 0xFFFFFFFF)

    Bitwise.bxor(h1, k1)
  end

  defp tail_to_int(<<b1, b2, b3>>), do: Bitwise.bor(Bitwise.bor(b1, Bitwise.bsl(b2, 8)), Bitwise.bsl(b3, 16))
  defp tail_to_int(<<b1, b2>>), do: Bitwise.bor(b1, Bitwise.bsl(b2, 8))
  defp tail_to_int(<<b1>>), do: b1

  defp fmix32(h) do
    h = Bitwise.bxor(h, Bitwise.bsr(h, 16))
    h = Bitwise.band(h * 0x85EBCA6B, 0xFFFFFFFF)
    h = Bitwise.bxor(h, Bitwise.bsr(h, 13))
    h = Bitwise.band(h * 0xC2B2AE35, 0xFFFFFFFF)
    h = Bitwise.bxor(h, Bitwise.bsr(h, 16))
    h
  end

  @doc """
  FNV-1a hash function for 32-bit hash values.

  A simple, fast hash function with good distribution for hash tables.

  ## Parameters

    * `binary` - Binary data to hash

  ## Returns

  A 32-bit unsigned integer hash value.
  """
  def fnv1a_hash(binary) when is_binary(binary) do
    # FNV-1a constants for 32-bit
    offset_basis = 0x811C9DC5
    prime = 0x01000193

    fnv1a_32(binary, offset_basis, prime)
  end

  defp fnv1a_32(<<>>, hash, _prime), do: hash

  defp fnv1a_32(<<byte, rest::binary>>, hash, prime) do
    hash = Bitwise.bxor(hash, byte)
    hash = Bitwise.band(hash * prime, 0xFFFFFFFF)
    fnv1a_32(rest, hash, prime)
  end

  @doc """
  Convert various types to binary for hashing.

  Supports strings, atoms, numbers, and any term via :erlang.term_to_binary/1.

  ## Examples

      iex> Bloomy.Hash.to_binary("hello")
      "hello"

      iex> Bloomy.Hash.to_binary(:atom)
      "atom"

      iex> Bloomy.Hash.to_binary(123)
      <<123, 0, 0, 0, 0, 0, 0, 0>>
  """
  def to_binary(term) when is_binary(term), do: term
  def to_binary(term) when is_atom(term), do: Atom.to_string(term)
  def to_binary(term) when is_integer(term), do: <<term::little-64>>
  def to_binary(term) when is_float(term), do: <<term::float-64>>
  def to_binary(term), do: :erlang.term_to_binary(term)

  @doc """
  Calculate optimal number of hash functions given bit array size and expected item count.

  Uses the formula: k = (m/n) * ln(2)

  ## Parameters

    * `m` - Size of bit array
    * `n` - Expected number of items

  ## Returns

  Optimal number of hash functions (rounded to nearest integer, minimum 1).

  ## Examples

      iex> Bloomy.Hash.optimal_k(1000, 100)
      7
  """
  def optimal_k(m, n) when m > 0 and n > 0 do
    k = (m / n) * :math.log(2)
    max(1, round(k))
  end
end
