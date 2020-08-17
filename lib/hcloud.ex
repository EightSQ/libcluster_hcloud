defmodule ClusterHcloud.Hcloud do
  @moduledoc """
  Overloaded HTTPoison middleware to access the Hetzner Cloud API.
  """

  use HTTPoison.Base


  @api_baseurl "https://api.hetzner.cloud/v1"

  @impl true
  def process_url(url) do
    @api_baseurl <> url
  end

  @impl true
  def process_response_body(body) do
    Jason.decode!(body)
  end

  @doc """
  Fetches all servers of the [`/servers` endpoint](https://docs.hetzner.cloud/#servers-get-all-servers) and returns an array of server documents.
  """
  def servers(label_selector, access_token, page \\ 1, results \\ []) do
    headers = [
      authorization_header(access_token)
    ]
    params = %{
      label_selector: label_selector,
      per_page: 50,
      page: page
    }
    case get("/servers", headers, params: params) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        results =
          Enum.concat(results, body["servers"])
        case body["meta"]["pagination"]["next_page"] do
          nil ->
            {:ok, results}
          next_page when is_integer(next_page) ->
            servers(access_token, label_selector, next_page, results)
          _ ->
            {:error, "Malformed pagination information returned from hetzner."}
        end
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received status code #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Determines the network id for a given network name.
  Returning the first network with matching name in the result set returned by [`/networks`](https://docs.hetzner.cloud/#networks-get-all-networks).
  """
  def get_network_id(network_name, access_token) do
    headers = [
      authorization_header(access_token)
    ]
    params = %{
      name: network_name
    }
    case get("/networks", headers, params: params) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        case body["networks"] do
          [first_network | _rest ] ->
            {:ok, first_network["id"]}
          [] ->
            {:error, "Network \"#{network_name}\" not found."}
        end
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Received status code #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp authorization_header(access_token) do
    {"Authorization", "Bearer " <> access_token}
  end
end
