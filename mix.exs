defmodule Bloomy.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/YOUR_USERNAME/bloomy"

  def project do
    [
      app: :bloomy,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Bloomy",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.10.0"},
      {:exla, "~> 0.10.0", optional: true},
      {:scholar, "~> 0.4.0", optional: true},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    High-performance Bloom Filter library for Elixir with Nx tensor operations.
    Supports Standard, Counting, Scalable, and Learned filters with EXLA/GPU acceleration.
    """
  end

  defp package do
    [
      name: "bloomy",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "Bloomy",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
