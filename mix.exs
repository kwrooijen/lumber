defmodule Lumber.Mixfile do
  use Mix.Project

  def project do
    [app: :lumber,
     version: "0.1.8",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    []
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev},
     {:murk, ">= 0.0.0"}]
  end

  defp description do
    """
    Phoenix Channel interface builder, input / output type checker, and Elm Channel code generator.
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE", "config", "priv"],
     maintainers: ["Kevin W. van Rooijen"],
     licenses: ["GPL3"],
     links: %{"GitHub": "https://github.com/kwrooijen/lumber"}]
  end
end
