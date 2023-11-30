[![Hex.pm Version](http://img.shields.io/hexpm/v/libcluster_hcloud.svg?style=flat)](https://hex.pm/packages/libcluster_hcloud)

# ClusterHcloud

This is a [Hetzner Cloud](https://www.hetzner.de/cloud) clustering strategy for [libcluster](https://github.com/bitwalker/libcluster).

The `labels` strategy queries the [hcloud API](https://docs.hetzner.cloud/) using [HTTPoison](https://github.com/edgurgel/httpoison) and [Jason](https://github.com/michalmuskala/jason) to find nodes by given [label selectors](https://docs.hetzner.cloud/#label-selector).


## Quick example

```elixir
config :libcluster,
  topologies: [
    labels_example: [
      strategy: Elixir.ClusterHcloud.Strategy.Labels,
      config: [
        hcloud_api_access_token: "xxx",
        label_selector: "mylabel",
        app_prefix: "app",
        show_debug: false,
        private_network_name: "my-network",
        polling_interval: 10_000]]],
```

You can define your topologies in the location where you start the `Cluster.Supervisor` as well.
If you use the above, remember that you still have to add `Cluster.Supervisor` to the supervision tree.
You can get the configuration using `Application.get_env(:libcluster, :topologies)`.

For further details on configuration, see the [documentation](https://hexdocs.pm/libcluster_hcloud).

To practically use this on Hetzner Cloud, you need to make sure you run your
application appropriately, i.e., you have to make sure you run your nodes with
a `name` allowing for external connections. This means it has to be run with
the Erlang start parameter `--name {app_prefix}@{private_ip}` or `--name
{app_prefix}@{public_ip}`! If you are using Mix Releases, the [documentation of
mix-release](https://hexdocs.pm/mix/Mix.Tasks.Release.html) is a good read.

TL;DR e.g. for use with **mix release** you need to set the environment variables `RELEASE_DISTRIBUTION=name` and `RELEASE_NODE={app_prefix}@{private_ip|public_ip}` when running you release.


## Installation

The package can be installed by adding `libcluster_hcloud` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_hcloud, "~> 0.1.0"}
  ]
end
```

## Acknowledgments

This package is heavily based on [libcluster_ec2](https://github.com/kyleaa/libcluster_ec2) by [kyleaa](https://github.com/kyleaa).

