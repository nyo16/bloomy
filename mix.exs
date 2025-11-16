defmodule Bloomy.MixProject do
  use Mix.Project

  def project do
    [
      app: :bloomy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.10.0"},
      {:exla, "~> 0.10.0"},
      {:scholar, "~> 0.4.0"},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end
end
