defmodule Bloomy.Params do
  @moduledoc """
  Parameter calculation utilities for bloom filters.

  This module provides functions to calculate optimal bloom filter parameters
  based on expected number of items and desired false positive rate.

  ## Key Formulas

  - **Bit array size**: `m = -(n * ln(p)) / (ln(2)^2)`
  - **Number of hash functions**: `k = (m / n) * ln(2)`
  - **Actual false positive rate**: `p = (1 - e^(-kn/m))^k`

  Where:
  - `n` = expected number of items
  - `p` = desired false positive rate
  - `m` = size of bit array
  - `k` = number of hash functions

  ## Examples

      iex> params = Bloomy.Params.calculate(1000, 0.01)
      iex> params.size > 0
      true
      iex> params.hash_functions > 0
      true
  """

  @type t :: %__MODULE__{
          size: pos_integer(),
          hash_functions: pos_integer(),
          capacity: pos_integer(),
          false_positive_rate: float(),
          actual_false_positive_rate: float()
        }

  defstruct [
    :size,
    :hash_functions,
    :capacity,
    :false_positive_rate,
    :actual_false_positive_rate
  ]

  @doc """
  Calculate optimal bloom filter parameters.

  Given expected capacity and desired false positive rate, calculates
  the optimal bit array size and number of hash functions.

  ## Parameters

    * `capacity` - Expected number of items to store
    * `false_positive_rate` - Desired false positive rate (e.g., 0.01 for 1%)

  ## Returns

  A `Bloomy.Params` struct with calculated parameters.

  ## Examples

      iex> params = Bloomy.Params.calculate(1000, 0.01)
      iex> params.capacity
      1000
      iex> params.false_positive_rate
      0.01

      iex> params = Bloomy.Params.calculate(10000, 0.001)
      iex> params.size > 10000
      true
  """
  def calculate(capacity, false_positive_rate)
      when is_integer(capacity) and capacity > 0 and
             is_float(false_positive_rate) and false_positive_rate > 0 and
             false_positive_rate < 1 do
    # Calculate optimal size: m = -(n * ln(p)) / (ln(2)^2)
    size = optimal_size(capacity, false_positive_rate)

    # Calculate optimal number of hash functions: k = (m / n) * ln(2)
    hash_functions = optimal_hash_functions(size, capacity)

    # Calculate actual false positive rate
    actual_fp_rate = calculate_false_positive_rate(size, hash_functions, capacity)

    %__MODULE__{
      size: size,
      hash_functions: hash_functions,
      capacity: capacity,
      false_positive_rate: false_positive_rate,
      actual_false_positive_rate: actual_fp_rate
    }
  end

  @doc """
  Calculate optimal bit array size given capacity and false positive rate.

  Uses the formula: `m = -(n * ln(p)) / (ln(2)^2)`

  ## Parameters

    * `capacity` - Expected number of items
    * `false_positive_rate` - Desired false positive rate

  ## Returns

  Optimal bit array size (positive integer).

  ## Examples

      iex> Bloomy.Params.optimal_size(1000, 0.01)
      9586

      iex> Bloomy.Params.optimal_size(10000, 0.001)
      143776
  """
  def optimal_size(capacity, false_positive_rate)
      when capacity > 0 and false_positive_rate > 0 and false_positive_rate < 1 do
    # m = -(n * ln(p)) / (ln(2)^2)
    ln2_squared = :math.log(2) * :math.log(2)
    size = -(capacity * :math.log(false_positive_rate)) / ln2_squared

    # Round up and ensure minimum size
    max(1, ceil(size))
  end

  @doc """
  Calculate optimal number of hash functions.

  Uses the formula: `k = (m / n) * ln(2)`

  ## Parameters

    * `size` - Bit array size
    * `capacity` - Expected number of items

  ## Returns

  Optimal number of hash functions (positive integer).

  ## Examples

      iex> Bloomy.Params.optimal_hash_functions(9586, 1000)
      7

      iex> Bloomy.Params.optimal_hash_functions(143776, 10000)
      10
  """
  def optimal_hash_functions(size, capacity) when size > 0 and capacity > 0 do
    # k = (m / n) * ln(2)
    k = (size / capacity) * :math.log(2)

    # Round to nearest integer, ensure at least 1
    max(1, round(k))
  end

  @doc """
  Calculate expected false positive rate.

  Uses the formula: `p = (1 - e^(-kn/m))^k`

  ## Parameters

    * `size` - Bit array size
    * `hash_functions` - Number of hash functions
    * `items_count` - Number of items stored

  ## Returns

  Expected false positive rate as a float.

  ## Examples

      iex> rate = Bloomy.Params.calculate_false_positive_rate(9586, 7, 1000)
      iex> rate < 0.011
      true

      iex> rate = Bloomy.Params.calculate_false_positive_rate(9586, 7, 2000)
      iex> rate > 0.01
      true
  """
  def calculate_false_positive_rate(size, hash_functions, items_count)
      when size > 0 and hash_functions > 0 and items_count >= 0 do
    # p = (1 - e^(-kn/m))^k
    exponent = -(hash_functions * items_count) / size
    base = 1 - :math.exp(exponent)
    :math.pow(base, hash_functions)
  end

  @doc """
  Calculate the capacity for a given size and false positive rate.

  Inverse of `optimal_size/2`.

  ## Parameters

    * `size` - Bit array size
    * `false_positive_rate` - Desired false positive rate

  ## Returns

  Maximum recommended capacity (positive integer).

  ## Examples

      iex> capacity = Bloomy.Params.capacity_for_size(9586, 0.01)
      iex> capacity >= 900 and capacity <= 1100
      true
  """
  def capacity_for_size(size, false_positive_rate)
      when size > 0 and false_positive_rate > 0 and false_positive_rate < 1 do
    # Derived from: m = -(n * ln(p)) / (ln(2)^2)
    # Therefore: n = -(m * ln(2)^2) / ln(p)
    ln2_squared = :math.log(2) * :math.log(2)
    capacity = -(size * ln2_squared) / :math.log(false_positive_rate)

    max(1, floor(capacity))
  end

  @doc """
  Calculate fill ratio (proportion of bits set) given number of items.

  Uses the formula: `fill_ratio = 1 - e^(-kn/m)`

  ## Parameters

    * `size` - Bit array size
    * `hash_functions` - Number of hash functions
    * `items_count` - Number of items stored

  ## Returns

  Expected fill ratio as a float between 0 and 1.

  ## Examples

      iex> ratio = Bloomy.Params.expected_fill_ratio(1000, 7, 100)
      iex> ratio > 0 and ratio < 1
      true
  """
  def expected_fill_ratio(size, hash_functions, items_count)
      when size > 0 and hash_functions > 0 and items_count >= 0 do
    # fill_ratio = 1 - e^(-kn/m)
    exponent = -(hash_functions * items_count) / size
    1 - :math.exp(exponent)
  end

  @doc """
  Estimate number of items in a bloom filter based on fill ratio.

  Uses the formula derived from fill ratio calculation.

  ## Parameters

    * `size` - Bit array size
    * `hash_functions` - Number of hash functions
    * `fill_ratio` - Observed fill ratio (0.0 to 1.0)

  ## Returns

  Estimated number of items (integer).

  ## Examples

      iex> count = Bloomy.Params.estimate_item_count(1000, 7, 0.5)
      iex> count > 0
      true
  """
  def estimate_item_count(size, hash_functions, fill_ratio)
      when size > 0 and hash_functions > 0 and fill_ratio >= 0 and fill_ratio <= 1 do
    # Derived from: fill_ratio = 1 - e^(-kn/m)
    # Therefore: n = -(m/k) * ln(1 - fill_ratio)
    if fill_ratio >= 1.0 do
      # Fully saturated
      round(size / hash_functions)
    else
      count = -(size / hash_functions) * :math.log(1 - fill_ratio)
      max(0, round(count))
    end
  end

  @doc """
  Validate if parameters are reasonable for a bloom filter.

  Checks if the parameters will result in acceptable performance
  and memory usage.

  ## Parameters

    * `params` - A `Bloomy.Params` struct

  ## Returns

  `{:ok, params}` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> params = Bloomy.Params.calculate(1000, 0.01)
      iex> {:ok, _} = Bloomy.Params.validate(params)

      iex> params = %Bloomy.Params{size: 0, hash_functions: 0, capacity: 0, false_positive_rate: 0.5, actual_false_positive_rate: 0.5}
      iex> {:error, _} = Bloomy.Params.validate(params)
  """
  def validate(%__MODULE__{} = params) do
    cond do
      params.size <= 0 ->
        {:error, "Size must be positive"}

      params.hash_functions <= 0 ->
        {:error, "Number of hash functions must be positive"}

      params.capacity <= 0 ->
        {:error, "Capacity must be positive"}

      params.false_positive_rate <= 0 or params.false_positive_rate >= 1 ->
        {:error, "False positive rate must be between 0 and 1"}

      params.hash_functions > 100 ->
        {:error, "Too many hash functions (>100), may indicate invalid parameters"}

      params.size > 1_000_000_000 ->
        {:error, "Bit array size too large (>1GB), may cause memory issues"}

      true ->
        {:ok, params}
    end
  end

  @doc """
  Get a summary of the bloom filter parameters as a readable map.

  ## Parameters

    * `params` - A `Bloomy.Params` struct

  ## Returns

  A map with human-readable parameter descriptions.

  ## Examples

      iex> params = Bloomy.Params.calculate(1000, 0.01)
      iex> summary = Bloomy.Params.summary(params)
      iex> summary.capacity
      1000
  """
  def summary(%__MODULE__{} = params) do
    memory_bytes = params.size / 8
    memory_kb = memory_bytes / 1024
    memory_mb = memory_kb / 1024

    memory_str =
      cond do
        memory_mb >= 1 -> "#{Float.round(memory_mb, 2)} MB"
        memory_kb >= 1 -> "#{Float.round(memory_kb, 2)} KB"
        true -> "#{Float.round(memory_bytes, 2)} bytes"
      end

    %{
      capacity: params.capacity,
      size: params.size,
      hash_functions: params.hash_functions,
      false_positive_rate: "#{Float.round(params.false_positive_rate * 100, 4)}%",
      actual_false_positive_rate: "#{Float.round(params.actual_false_positive_rate * 100, 4)}%",
      memory: memory_str,
      bits_per_item: Float.round(params.size / params.capacity, 2)
    }
  end
end
