defmodule Jennie.MixProject do
  use Mix.Project

  def project do
    [
      app: :jennie,
      description: description(),
      package: package(),
      version: "0.8.0",
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

  defp description() do
    "Logic-less templates"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "jennie",
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/anthrodontics/jennie"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
