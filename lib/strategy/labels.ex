defmodule ClusterHcloud.Strategy.Labels do
  @moduledoc """
  This clustering strategy works by loading all instances of the project matching the given label selector.
  See the [hcloud docs](https://docs.hetzner.cloud/#label-selector) for further details.

  All instances must be started with the same app name and have security groups
  configured to allow inter-node communication.

      config :libcluster,
        topologies: [
          labels_example: [
            strategy: #{__MODULE__},
            config: [
              hcloud_api_access_token: "xxx",
              label_selector: "mylabel",
              app_prefix: "app",
              private_network_name: "my-network",
              show_debug: false,
              polling_interval: 10_000]]],

  ## Configuration Options
  | Key | Required | Description |
  | --- | -------- | ----------- |
  | `:hcloud_api_access_token` | yes | Access token for the hcloud project. |
  | `:label_selector` | yes | Label selector matching for the servers to be clustered. |
  | `:app_prefix` | no | Will be prepended to the node's IP address to create the node name. |
  | `:private_network_name` | no | Allows to use a specific internal hcloud network to determine the IP address. If not specified, the public IP address will be used. |
  | `:polling_interval` | no | Number of milliseconds to wait between polls to the hcloud api. Defaults to `5000`. |
  | `:show_debug` | no | True or false, whether or not to show the debug log. Defaults to `true`. |
  """

  use GenServer
  use Cluster.Strategy
  import Cluster.Logger

  alias Cluster.Strategy.State

  @default_polling_interval 5_000
  @default_app_prefix "app"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init([%State{} = state]) do
    state = state |> Map.put(:meta, MapSet.new())

    {:ok, load(state)}
  end

  @impl GenServer
  def handle_info(:timeout, state), do: handle_info(:load, state)
  def handle_info(:load, %State{} = state), do: {:noreply, load(state)}
  def handle_info(_, state), do: {:noreply, state}

  defp load(%State{topology: topology, connect: connect, disconnect: disconnect, list_nodes: list_nodes} = state) do
    case get_nodes(state) do
      {:ok, new_nodelist} ->
        added = MapSet.difference(new_nodelist, state.meta)
        removed = MapSet.difference(state.meta, new_nodelist)

        new_nodelist =
          case Cluster.Strategy.disconnect_nodes(topology, disconnect, list_nodes, MapSet.to_list(removed)) do
            :ok ->
              new_nodelist

            {:error, bad_nodes} ->
              # Add back the nodes which should have been removed, but which couldn't be for some reason
              Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
                MapSet.put(acc, n)
              end)
          end

        new_nodelist =
          case Cluster.Strategy.connect_nodes(topology, connect, list_nodes, MapSet.to_list(added)) do
            :ok ->
              new_nodelist

            {:error, bad_nodes} ->
              # Remove the nodes which should have been added, but which couldn't be for some reason
              Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
                MapSet.delete(acc, n)
              end)
          end

        Process.send_after(self(), :load, Keyword.get(state.config, :polling_interval, @default_polling_interval))
        %{state | :meta => new_nodelist}
      _ ->
        Process.send_after(self(), :load, Keyword.get(state.config, :polling_interval, @default_polling_interval))
        state
    end
  end

  @spec get_nodes(State.t()) :: {:ok, [atom()]} | {:error, []}
  defp get_nodes(%State{topology: topology, config: config}) do

    # Get config variables
    access_token = Keyword.fetch!(config, :hcloud_api_access_token)
    label_selector = Keyword.fetch!(config, :label_selector)
    app_prefix = Keyword.get(config, :app_prefix, @default_app_prefix)
    private_network_name = Keyword.get(config, :private_network_name, nil)
    use_private_network? = not(is_nil(private_network_name))
    show_debug? = Keyword.get(config, :show_debug, true)

    # Try to get id of network
    private_network_id =
      case ClusterHcloud.Hcloud.get_network_id(private_network_name, access_token) do
        {:ok, network_id} ->
          network_id
        {:error, reason} ->
          error(topology, "Could not fetch network information from hcloud api (#{reason})")
          nil
      end

    require Logger
    cond do
      use_private_network? and private_network_id == nil ->
        warn(topology, "Do not know network id of network with name #{private_network_name}")
        {:error, []}
      access_token != nil and label_selector != nil and app_prefix != nil ->
        if show_debug?, do: Logger.debug("Calling hcloud api for topology \"#{topology}\"...")
        case ClusterHcloud.Hcloud.servers(label_selector, access_token) do
          {:ok, servers} ->
            ips =
              if use_private_network? do
                Enum.map(servers, &extract_private_ip(&1, private_network_id))
                |> Enum.filter(fn ip ->
                  ok? = not(is_nil(ip))
                  if show_debug? and not ok? do
                    Logger.debug("Found a server with matching selector \"#{label_selector}\" but not in private network #{private_network_id}")
                  end
                  ok?
                end)
              else
                Enum.map(servers, &extract_public_ip(&1))
              end
            node_names = ip_to_nodename(ips, app_prefix)
            if show_debug?, do: Logger.debug("Identified nodes: #{Enum.join(Enum.map(node_names, &Atom.to_string/1), " ")}")
            {:ok, MapSet.new(node_names)}
          {:error, reason} ->
            error(topology, "Could not fetch data from hcloud api (#{reason})")
            {:error, []}
        end
    end
  end

  defp extract_public_ip(server_document) do
    server_document["public_net"]["ipv4"]["ip"]
  end

  defp extract_private_ip(server_document, private_network_id) do
    net =
      server_document["private_net"]
      |> Enum.find(fn net -> net["network"] == private_network_id end)
    unless is_nil(net) do
      net["ip"]
    else
      nil
    end
  end

  defp ip_to_nodename(list, app_prefix) when is_list(list) do
    list
    |> Enum.map(fn ip ->
      :"#{app_prefix}@#{ip}"
    end)
  end
end
