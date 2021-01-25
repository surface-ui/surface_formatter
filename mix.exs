defmodule SurfaceFormatter.MixProject do
  use Mix.Project

  @source_url "https://github.com/surface-ui/surface_formatter"
  @version "0.1.0"

  def project do
    [
      app: :surface_formatter,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description:
        "A code formatter for Surface, the component based library for Phoenix LiveView",
      package: package(),

      # Docs
      name: "SurfaceFormatter",
      docs: docs()
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
      {:surface, "~> 0.1.1"},
      {:ex_doc, ">= 0.19.0", only: :docs}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    }
  end
end
