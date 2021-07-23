defmodule Filtery.MixProject do
  use Mix.Project

  def project do
    [
      app: :filtery,
      version: "0.2.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "Filtery",
      description: description(),
      source_url: "https://github.com/bluzky/filtery",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      maintainers: ["Dung Nguyen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bluzky/filtery"}
    ]
  end

  defp description() do
    """
    Compose your dynamic query with Mongo like query syntax
    """
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ecto, "~> 3.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
