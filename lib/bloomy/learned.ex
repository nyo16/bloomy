defmodule Bloomy.Learned do
  @moduledoc """
  Learned Bloom Filter using machine learning to reduce false positives.

  A learned bloom filter combines a machine learning model with a traditional
  bloom filter to achieve lower false positive rates. The ML model learns to
  predict set membership, and the backup bloom filter handles uncertain cases.

  ## Concept

  Based on research from "The Case for Learned Index Structures":

  1. **Model**: Neural network predicts if item is in the set
  2. **Backup Filter**: Standard bloom filter for uncertain predictions
  3. **Query Process**:
     - Model predicts membership with confidence score
     - If confident "not present" -> return false (skip filter)
     - If present or uncertain -> check backup filter

  ## Benefits

  - Lower false positive rate than standard bloom filters
  - Adapts to data patterns
  - Can be more space-efficient for structured data

  ## Trade-offs

  - Requires training data
  - Higher query latency (model inference)
  - More complex implementation
  - Best for static or slowly-changing sets

  ## Examples

      iex> # Create and train a learned bloom filter
      iex> training_data = %{
      iex>   positive: ["user_123", "user_456", "user_789"],
      iex>   negative: ["user_000", "user_111", "user_222"]
      iex> }
      iex>
      iex> filter = Bloomy.Learned.new(1000)
      iex>   |> Bloomy.Learned.train(training_data)
      iex>   |> Bloomy.Learned.add("user_123")
      iex>
      iex> Bloomy.Learned.member?(filter, "user_123")
      true
  """

  @behaviour Bloomy.Behaviour

  alias Bloomy.{Standard, Hash}

  @type model :: %{
          weights: Nx.Tensor.t(),
          bias: Nx.Tensor.t(),
          feature_size: pos_integer()
        }

  @type t :: %__MODULE__{
          model: model() | nil,
          backup_filter: Standard.t(),
          trained: boolean(),
          confidence_threshold: float(),
          items_count: non_neg_integer(),
          backend: atom()
        }

  defstruct [
    :model,
    :backup_filter,
    :trained,
    :confidence_threshold,
    :items_count,
    :backend
  ]

  @feature_size 128
  @default_confidence_threshold 0.7

  @doc """
  Create a new learned bloom filter.

  ## Parameters

    * `capacity` - Expected number of items
    * `opts` - Keyword list of options:
      * `:false_positive_rate` - Desired false positive rate (default: 0.01)
      * `:confidence_threshold` - Model confidence threshold (default: 0.7)
      * `:feature_size` - Size of feature vector (default: 128)
      * `:backend` - Nx backend to use (default: Nx.default_backend())

  ## Returns

  A new `Bloomy.Learned` struct (untrained).

  ## Examples

      iex> filter = Bloomy.Learned.new(1000)
      iex> filter.trained
      false
  """
  @impl true
  def new(capacity, opts \\ []) when is_integer(capacity) and capacity > 0 do
    false_positive_rate = Keyword.get(opts, :false_positive_rate, 0.01)
    confidence_threshold = Keyword.get(opts, :confidence_threshold, @default_confidence_threshold)
    feature_size = Keyword.get(opts, :feature_size, @feature_size)
    backend = Keyword.get(opts, :backend, Nx.default_backend())

    # Create backup filter with tighter error rate (since model handles most queries)
    backup_rate = false_positive_rate * 0.1
    backup_filter = Standard.new(capacity, false_positive_rate: backup_rate, backend: backend)

    # Initialize model with random weights
    model = initialize_model(feature_size, backend)

    %__MODULE__{
      model: model,
      backup_filter: backup_filter,
      trained: false,
      confidence_threshold: confidence_threshold,
      items_count: 0,
      backend: backend
    }
  end

  @doc """
  Train the learned bloom filter on labeled data.

  ## Parameters

    * `filter` - The learned bloom filter struct
    * `training_data` - Map with `:positive` and `:negative` example lists
    * `opts` - Training options:
      * `:epochs` - Number of training epochs (default: 10)
      * `:learning_rate` - Learning rate (default: 0.01)

  ## Returns

  Updated filter with trained model.

  ## Examples

      iex> training_data = %{
      iex>   positive: ["item1", "item2", "item3"],
      iex>   negative: ["other1", "other2", "other3"]
      iex> }
      iex> filter = Bloomy.Learned.new(1000)
      iex> filter = Bloomy.Learned.train(filter, training_data)
      iex> filter.trained
      true
  """
  def train(%__MODULE__{} = filter, training_data, opts \\ []) do
    epochs = Keyword.get(opts, :epochs, 10)
    learning_rate = Keyword.get(opts, :learning_rate, 0.01)

    positive_items = Map.get(training_data, :positive, [])
    negative_items = Map.get(training_data, :negative, [])

    if length(positive_items) == 0 or length(negative_items) == 0 do
      raise ArgumentError, "Training data must include both positive and negative examples"
    end

    # Convert items to features
    positive_features = Enum.map(positive_items, &item_to_features(&1, filter.model.feature_size))
    negative_features = Enum.map(negative_items, &item_to_features(&1, filter.model.feature_size))

    # Combine and create tensors
    all_features = positive_features ++ negative_features
    all_labels = List.duplicate(1.0, length(positive_items)) ++ List.duplicate(0.0, length(negative_items))

    features_tensor = Nx.tensor(all_features) |> Nx.backend_transfer(filter.backend)
    labels_tensor = Nx.tensor(all_labels) |> Nx.reshape({length(all_labels), 1}) |> Nx.backend_transfer(filter.backend)

    # Train model
    trained_model = train_model(filter.model, features_tensor, labels_tensor, epochs, learning_rate)

    %{filter | model: trained_model, trained: true}
  end

  @doc """
  Add an item to the learned bloom filter.

  Adds the item to the backup bloom filter.

  ## Parameters

    * `filter` - The learned bloom filter struct
    * `item` - Item to add

  ## Returns

  Updated learned bloom filter struct.

  ## Examples

      iex> filter = Bloomy.Learned.new(1000)
      iex> filter = Bloomy.Learned.add(filter, "hello")
      iex> filter.items_count
      1
  """
  @impl true
  def add(%__MODULE__{} = filter, item) do
    backup_filter = Standard.add(filter.backup_filter, item)
    %{filter | backup_filter: backup_filter, items_count: filter.items_count + 1}
  end

  @doc """
  Check if an item might be in the learned bloom filter.

  Uses the ML model to make an initial prediction, then checks backup filter if needed.

  ## Parameters

    * `filter` - The learned bloom filter struct
    * `item` - Item to check

  ## Returns

  Boolean indicating possible membership.

  ## Examples

      iex> filter = Bloomy.Learned.new(1000)
      iex> filter = Bloomy.Learned.add(filter, "hello")
      iex> Bloomy.Learned.member?(filter, "hello")
      true
  """
  @impl true
  def member?(%__MODULE__{trained: false} = filter, item) do
    # If not trained, just use backup filter
    Standard.member?(filter.backup_filter, item)
  end

  def member?(%__MODULE__{trained: true} = filter, item) do
    # Get model prediction
    features = item_to_features(item, filter.model.feature_size)
    features_tensor = Nx.tensor([features]) |> Nx.backend_transfer(filter.backend)

    prediction = predict(filter.model, features_tensor) |> Nx.to_number()

    # If model is confident item is NOT present, return false
    if prediction < (1.0 - filter.confidence_threshold) do
      false
    else
      # Otherwise check backup filter
      Standard.member?(filter.backup_filter, item)
    end
  end

  @doc """
  Get information about the learned bloom filter.

  ## Parameters

    * `filter` - The learned bloom filter struct

  ## Returns

  Map with filter statistics.

  ## Examples

      iex> filter = Bloomy.Learned.new(1000)
      iex> info = Bloomy.Learned.info(filter)
      iex> info.type
      :learned
  """
  @impl true
  def info(%__MODULE__{} = filter) do
    backup_info = Standard.info(filter.backup_filter)

    %{
      type: :learned,
      trained: filter.trained,
      confidence_threshold: filter.confidence_threshold,
      items_count: filter.items_count,
      backup_filter: backup_info,
      model_feature_size: filter.model.feature_size,
      backend: filter.backend
    }
  end

  @doc """
  Clear the learned bloom filter.

  Clears the backup filter but keeps the trained model.

  ## Parameters

    * `filter` - The learned bloom filter struct

  ## Returns

  Cleared learned bloom filter struct.
  """
  @impl true
  def clear(%__MODULE__{} = filter) do
    backup_filter = Standard.clear(filter.backup_filter)
    %{filter | backup_filter: backup_filter, items_count: 0}
  end

  # Private helper functions

  defp initialize_model(feature_size, backend) do
    # Simple single-layer neural network
    # Initialize weights with small random values
    key = Nx.Random.key(System.system_time(:nanosecond))
    {weights, _new_key} = Nx.Random.normal(key, 0.0, 0.1, shape: {feature_size, 1})
    bias = Nx.tensor([0.0])

    %{
      weights: Nx.backend_transfer(weights, backend),
      bias: Nx.backend_transfer(bias, backend),
      feature_size: feature_size
    }
  end

  defp item_to_features(item, feature_size) do
    # Convert item to feature vector using multiple hash functions
    # This creates a distributed representation of the item
    binary = Hash.to_binary(item)

    for i <- 0..(feature_size - 1) do
      # Use different seeds for each feature
      hash1 = Hash.murmur3_hash(<<binary::binary, i::32>>)
      hash2 = Hash.fnv1a_hash(<<binary::binary, i::32>>)

      # Combine hashes and normalize to [-1, 1]
      combined = rem(hash1 + hash2, 1000) / 500.0 - 1.0
      combined
    end
  end

  defp predict(model, features) do
    # Forward pass: features * weights + bias, then sigmoid
    logits = Nx.dot(features, model.weights) |> Nx.add(model.bias)
    sigmoid(logits)
  end

  defp sigmoid(x) do
    Nx.divide(1.0, Nx.add(1.0, Nx.exp(Nx.negate(x))))
  end

  defp train_model(model, features, labels, epochs, learning_rate) do
    # Simple gradient descent training
    Enum.reduce(1..epochs, model, fn _epoch, current_model ->
      # Forward pass
      predictions = predict(current_model, features)

      # Compute loss (binary cross-entropy)
      errors = Nx.subtract(predictions, labels)

      # Compute gradients
      weights_grad = Nx.dot(Nx.transpose(features), errors) |> Nx.divide(Nx.axis_size(features, 0))
      bias_grad = Nx.mean(errors)

      # Update weights
      new_weights = Nx.subtract(current_model.weights, Nx.multiply(weights_grad, learning_rate))
      new_bias = Nx.subtract(current_model.bias, Nx.multiply(bias_grad, learning_rate))

      %{current_model | weights: new_weights, bias: new_bias}
    end)
  end
end

# Implement the Bloomy.Protocol for Learned bloom filter
defimpl Bloomy.Protocol, for: Bloomy.Learned do
  def add(filter, item), do: Bloomy.Learned.add(filter, item)
  def member?(filter, item), do: Bloomy.Learned.member?(filter, item)
  def info(filter), do: Bloomy.Learned.info(filter)
  def clear(filter), do: Bloomy.Learned.clear(filter)
end
