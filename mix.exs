defmodule ClusterHcloud.MixProject do
  use Mix.Project

  @version "0.1.0"

  @source_url "https://github.com/EightSQ/libcluster_hcloud"
  def project do
    [
      app: :libcluster_hcloud,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "libcluster_hcloud",
      docs: [
        source_url: @source_url,
        homepage_url: @source_url,
        source_ref: "v#{@version}",
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 3.3"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.22", only: :dev}
    ]
  end

  defp description do
    """
    Hetzner Cloud clustering strategy for libcluster.
    """
  end

  defp package do
    [
      maintainers: ["Otto Kissig"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
