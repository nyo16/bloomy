defmodule Bloomy.Serialization do
  @moduledoc """
  Serialization and deserialization for bloom filters.

  This module provides functionality to save bloom filters to binary format
  and load them back. Supports all bloom filter types (Standard, Counting, Scalable).

  ## Binary Format

  The binary format includes:
  - Magic bytes for identification (4 bytes): "BLMY"
  - Version (4 bytes): Format version number
  - Type (1 byte): Filter type (0=standard, 1=counting, 2=scalable)
  - Metadata: Parameters and configuration
  - Data: Serialized tensor data

  ## Features

  - Efficient binary serialization
  - Version compatibility checks
  - Preserves all filter parameters
  - File I/O operations
  - Compression support (optional)

  ## Examples

      iex> # Serialize a bloom filter
      iex> filter = Bloomy.Standard.new(1000)
      iex> filter = Bloomy.Standard.add(filter, "test")
      iex> binary = Bloomy.Serialization.to_binary(filter)
      iex>
      iex> # Deserialize back
      iex> {:ok, loaded_filter} = Bloomy.Serialization.from_binary(binary)
      iex> Bloomy.Standard.member?(loaded_filter, "test")
      true
  """

  alias Bloomy.{Standard, Counting, Scalable}

  @magic_bytes "BLMY"
  @version 1

  @type_standard 0
  @type_counting 1
  @type_scalable 2

  @doc """
  Serialize a bloom filter to binary format.

  ## Parameters

    * `filter` - A bloom filter struct (Standard, Counting, or Scalable)
    * `opts` - Keyword list of options:
      * `:compress` - Enable compression (default: false)

  ## Returns

  Binary data representing the serialized filter.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> binary = Bloomy.Serialization.to_binary(filter)
      iex> is_binary(binary)
      true
  """
  def to_binary(filter, opts \\ [])

  def to_binary(%Standard{} = filter, opts) do
    compress = Keyword.get(opts, :compress, false)

    metadata = %{
      capacity: filter.params.capacity,
      false_positive_rate: filter.params.false_positive_rate,
      size: filter.params.size,
      hash_functions: filter.params.hash_functions,
      items_count: filter.items_count
    }

    # Serialize tensor data
    tensor_data = Nx.to_binary(filter.bit_array.bits)

    # Build binary
    data = build_binary(@type_standard, metadata, tensor_data, compress)
    data
  end

  def to_binary(%Counting{} = filter, opts) do
    compress = Keyword.get(opts, :compress, false)

    metadata = %{
      capacity: filter.params.capacity,
      false_positive_rate: filter.params.false_positive_rate,
      size: filter.params.size,
      hash_functions: filter.params.hash_functions,
      items_count: filter.items_count,
      counter_width: filter.counter_width
    }

    # Serialize tensor data
    tensor_data = Nx.to_binary(filter.counters)

    # Build binary
    data = build_binary(@type_counting, metadata, tensor_data, compress)
    data
  end

  def to_binary(%Scalable{} = filter, opts) do
    compress = Keyword.get(opts, :compress, false)

    # Serialize each slice
    slices_data = Enum.map(filter.slices, fn slice ->
      %{
        capacity: slice.params.capacity,
        false_positive_rate: slice.params.false_positive_rate,
        size: slice.params.size,
        hash_functions: slice.params.hash_functions,
        items_count: slice.items_count,
        tensor_data: Nx.to_binary(slice.bit_array.bits)
      }
    end)

    metadata = %{
      initial_capacity: filter.initial_capacity,
      target_false_positive_rate: filter.target_false_positive_rate,
      growth_factor: filter.growth_factor,
      error_tightening_ratio: filter.error_tightening_ratio,
      items_count: filter.items_count,
      slices: slices_data
    }

    # Build binary (no tensor data at top level for scalable)
    data = build_binary(@type_scalable, metadata, <<>>, compress)
    data
  end

  @doc """
  Deserialize a bloom filter from binary format.

  ## Parameters

    * `binary` - Binary data from `to_binary/2`
    * `opts` - Keyword list of options:
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  `{:ok, filter}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> binary = Bloomy.Serialization.to_binary(filter)
      iex> {:ok, loaded} = Bloomy.Serialization.from_binary(binary)
      iex> loaded.params.capacity
      1000
  """
  def from_binary(binary, opts \\ []) when is_binary(binary) do
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    case parse_binary(binary) do
      {:ok, type, metadata, tensor_data} ->
        reconstruct_filter(type, metadata, tensor_data, backend)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Save a bloom filter to a file.

  ## Parameters

    * `filter` - A bloom filter struct
    * `path` - File path to save to
    * `opts` - Options passed to `to_binary/2`

  ## Returns

  `:ok` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> filter = Bloomy.Standard.new(1000)
      iex> Bloomy.Serialization.save(filter, "/tmp/my_filter.bloom")
      :ok
  """
  def save(filter, path, opts \\ []) do
    binary = to_binary(filter, opts)
    File.write(path, binary)
  end

  @doc """
  Load a bloom filter from a file.

  ## Parameters

    * `path` - File path to load from
    * `opts` - Options passed to `from_binary/2`

  ## Returns

  `{:ok, filter}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> {:ok, filter} = Bloomy.Serialization.load("/tmp/my_filter.bloom")
      iex> Bloomy.Standard.member?(filter, "test")
      true
  """
  def load(path, opts \\ []) do
    case File.read(path) do
      {:ok, binary} ->
        from_binary(binary, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp build_binary(type, metadata, tensor_data, compress) do
    # Encode metadata as Erlang term
    metadata_binary = :erlang.term_to_binary(metadata)
    metadata_size = byte_size(metadata_binary)

    # Optionally compress tensor data
    {tensor_data, compressed_flag} =
      if compress and byte_size(tensor_data) > 1024 do
        {:zlib.compress(tensor_data), 1}
      else
        {tensor_data, 0}
      end

    tensor_size = byte_size(tensor_data)

    # Build binary format:
    # - Magic bytes (4)
    # - Version (4)
    # - Type (1)
    # - Compressed flag (1)
    # - Metadata size (4)
    # - Tensor data size (4)
    # - Metadata (variable)
    # - Tensor data (variable)
    <<
      @magic_bytes,
      @version::32,
      type::8,
      compressed_flag::8,
      metadata_size::32,
      tensor_size::32,
      metadata_binary::binary,
      tensor_data::binary
    >>
  end

  defp parse_binary(binary) do
    case binary do
      <<
        @magic_bytes,
        version::32,
        type::8,
        compressed_flag::8,
        metadata_size::32,
        tensor_size::32,
        rest::binary
      >> ->
        if version != @version do
          {:error, "Unsupported version: #{version}, expected: #{@version}"}
        else
          <<metadata_binary::binary-size(metadata_size), tensor_data::binary-size(tensor_size)>> = rest

          metadata = :erlang.binary_to_term(metadata_binary)

          # Decompress if needed
          tensor_data =
            if compressed_flag == 1 do
              :zlib.uncompress(tensor_data)
            else
              tensor_data
            end

          {:ok, type, metadata, tensor_data}
        end

      _ ->
        {:error, "Invalid binary format"}
    end
  end

  defp reconstruct_filter(@type_standard, metadata, tensor_data, backend) do
    # Reconstruct params
    params = %Bloomy.Params{
      size: metadata.size,
      hash_functions: metadata.hash_functions,
      capacity: metadata.capacity,
      false_positive_rate: metadata.false_positive_rate,
      actual_false_positive_rate: metadata.false_positive_rate
    }

    # Reconstruct bit array
    bits =
      Nx.from_binary(tensor_data, :u8)
      |> Nx.reshape({metadata.size})
      |> Nx.backend_transfer(backend)

    bit_array = %Bloomy.BitArray{
      bits: bits,
      size: metadata.size,
      backend: backend
    }

    filter = %Standard{
      bit_array: bit_array,
      params: params,
      items_count: metadata.items_count,
      backend: backend
    }

    {:ok, filter}
  end

  defp reconstruct_filter(@type_counting, metadata, tensor_data, backend) do
    # Reconstruct params
    params = %Bloomy.Params{
      size: metadata.size,
      hash_functions: metadata.hash_functions,
      capacity: metadata.capacity,
      false_positive_rate: metadata.false_positive_rate,
      actual_false_positive_rate: metadata.false_positive_rate
    }

    # Determine counter type
    counter_type =
      case metadata.counter_width do
        8 -> :u8
        16 -> :u16
        32 -> :u32
      end

    # Reconstruct counters
    counters =
      Nx.from_binary(tensor_data, counter_type)
      |> Nx.reshape({metadata.size})
      |> Nx.backend_transfer(backend)

    filter = %Counting{
      counters: counters,
      params: params,
      items_count: metadata.items_count,
      counter_width: metadata.counter_width,
      backend: backend
    }

    {:ok, filter}
  end

  defp reconstruct_filter(@type_scalable, metadata, _tensor_data, backend) do
    # Reconstruct each slice
    slices =
      Enum.map(metadata.slices, fn slice_data ->
        params = %Bloomy.Params{
          size: slice_data.size,
          hash_functions: slice_data.hash_functions,
          capacity: slice_data.capacity,
          false_positive_rate: slice_data.false_positive_rate,
          actual_false_positive_rate: slice_data.false_positive_rate
        }

        bits =
          Nx.from_binary(slice_data.tensor_data, :u8)
          |> Nx.reshape({slice_data.size})
          |> Nx.backend_transfer(backend)

        bit_array = %Bloomy.BitArray{
          bits: bits,
          size: slice_data.size,
          backend: backend
        }

        %Standard{
          bit_array: bit_array,
          params: params,
          items_count: slice_data.items_count,
          backend: backend
        }
      end)

    filter = %Scalable{
      slices: slices,
      initial_capacity: metadata.initial_capacity,
      target_false_positive_rate: metadata.target_false_positive_rate,
      growth_factor: metadata.growth_factor,
      error_tightening_ratio: metadata.error_tightening_ratio,
      items_count: metadata.items_count,
      backend: backend
    }

    {:ok, filter}
  end

  defp reconstruct_filter(type, _metadata, _tensor_data, _backend) do
    {:error, "Unknown filter type: #{type}"}
  end
end
