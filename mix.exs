defmodule OpentelemetryCommanded.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_commanded,
      version: "0.2.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      description: "Trace Commanded CRQS operations with OpenTelemetry",
      source_url: "https://github.com/SimpleBet/opentelemetry_commanded",
      homepage_url: "https://github.com/SimpleBet/opentelemetry_commanded"
    ]
  end

  defp elixirc_paths(env) when env in [:test],
    do: [
      "lib",
      "test/support",
      "test/dummy_app"
    ]

  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  defp package do
    [
      licenses: ["Apache-2"],
      links: %{"GitHub" => "https://github.com/SimpleBet/opentelemetry_commanded"}
    ]
  end

  defp deps do
    [
      {:commanded, "~> 1.3.1"},
      {:opentelemetry_telemetry, "~> 1.0.0-beta.7"},
      {:telemetry, "~> 1.0"},
      {:opentelemetry, "~> 1.0"},
      {:jason, "~> 1.2", only: :test},
      {:ecto, "~> 3.7.1", only: :test},
      {:ex_doc, "~> 0.23.0", only: [:dev], runtime: false}
    ]
  end
end
