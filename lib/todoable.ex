defmodule Todoable do
  @moduledoc """
  Create, delete, and manage todo lists and items on a remote server.

  """

  use Tesla

  plug(Tesla.Middleware.Tuples)
  plug(Tesla.Middleware.JSON)

  @default_base_url "http://localhost:4000/api"

  defmodule Client do
    defstruct [:token, :expires_at, :base_url]
  end

  defmodule List do
    defstruct [:id, :name, :src, :user_id, items: :not_loaded]
  end

  defmodule Item do
    defstruct [:id, :name, :src, :finished_at, :list_id]
  end

  @type client :: %Todoable.Client{}
  @type todo_list :: %Todoable.List{}
  @type todo_item :: %Todoable.Item{}
  @type uuid :: String.t()

  @doc """
  Returns all the lists for the authenticated user on the Todo server.
  """
  @spec lists(client :: client) :: {atom, [todo_list]}
  def lists(%Client{token: token, base_url: base_url}) do
    req(fn ->
      token_auth(token, base_url)
      |> get("/lists")
    end)
    |> case do
      {:ok, body} -> {:ok, Enum.map(body["lists"], &build_list(&1))}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Returns a specific list item from the Todo server.

  If passed a List struct, the List struct will be fetched, including all its Items.
  """
  @spec get_list(client, todo_list) :: {atom, todo_list}
  def get_list(client, %List{id: list_id}), do: get_list(client, id: list_id)
  @spec get_list(client, id :: uuid) :: {atom, todo_list}
  def get_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn ->
      token_auth(token, base_url)
      |> get("/lists/#{list_id}")
    end)
    |> case do
      {:ok, body} -> {:ok, build_list(body, id: list_id)}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Creates a list with the given name on the Todo server.
  """
  @spec create_list(client, name: String.t()) :: {atom, todo_list}
  def create_list(%Client{token: token, base_url: base_url}, name: name) do
    req(fn ->
      token_auth(token, base_url)
      |> post("/lists", %{list: %{name: name}})
    end)
    |> case do
      {:ok, body} -> {:ok, build_list(body)}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Updates the name of a list on the Todo server.
  """
  @spec update_list(client, list) :: {atom, todo_list}
  def update_list(client, %List{id: list_id, name: name}),
    do: update_list(client, id: list_id, name: name)

  @spec update_list(client, id: uuid, name: String.t()) :: {atom, todo_list}
  def update_list(%Client{token: token, base_url: base_url}, id: list_id, name: name) do
    req(fn ->
      token_auth(token, base_url)
      |> patch("/lists/#{list_id}", %{list: %{name: name}})
    end)
    |> case do
      {:ok, body} -> {:ok, build_list(body)}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Deletes a list from the Todo server.
  """
  @spec delete_list(client, todo_list) :: {atom, String.t()}
  def delete_list(client, %List{id: list_id}), do: delete_list(client, id: list_id)
  @spec delete_list(client, id: uuid) :: {atom, String.t()}
  def delete_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}")
    end)
  end

  @doc """
  Creates an item for a given list on the Todo server.
  """
  @spec create_item(client, todo_list, name: String.t()) :: {atom, todo_item}
  def create_item(client, %List{id: list_id}, name: name),
    do: create_item(client, list_id: list_id, name: name)

  @spec create_item(client, list_id: uuid, name: String.t()) :: {atom, todo_item}
  def create_item(%Client{token: token, base_url: base_url}, list_id: list_id, name: name) do
    req(fn ->
      token_auth(token, base_url)
      |> post("/lists/#{list_id}/items", %{item: %{name: name}})
    end)
    |> case do
      {:ok, body} -> {:ok, build_item(list_id, body)}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Deletes an item from a given list on the Todo server.
  """
  @spec delete_item(client, todo_item) :: {atom, String.t()}
  def delete_item(client, %Item{list_id: list_id, id: item_id}),
    do: delete_item(client, list_id: list_id, item_id: item_id)

  @spec delete_item(client, list_id: uuid, item_id: uuid) :: {atom, String.t()}
  def delete_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}/items/#{item_id}")
    end)
  end

  @doc """
  Marks an item as finished on the Todo server.
  """
  @spec finish_item(client, todo_item) :: {atom, todo_item}
  def finish_item(client, %Item{list_id: list_id, id: item_id}),
    do: finish_item(client, list_id: list_id, item_id: item_id)

  @spec finish_item(client, list_id: uuid, item_id: uuid) :: {atom, todo_item}
  def finish_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn ->
      token_auth(token, base_url)
      |> put("/lists/#{list_id}/items/#{item_id}/finish", %{})
    end)
    |> case do
      {:ok, body} -> {:ok, body}
      {:error, body} -> {:error, body}
    end
  end

  @doc """
  Returns a new client, ready for authentication.
  """
  @spec build_client() :: client
  def build_client(), do: build_client(base_url: @default_base_url)

  def build_client(base_url: base_url) do
    %Client{token: nil, expires_at: nil, base_url: base_url}
  end

  @spec authenticate(client, String.t(), String.t()) :: {atom, client}
  def authenticate(%Client{} = client, username, password) do
    basic_auth(username: username, password: password, base_url: client.base_url)
    |> post("/authenticate", %{})
    |> case do
      {:ok, %{body: %{"token" => token, "expires_at" => expires_at}}} ->
        {:ok, %Client{token: token, expires_at: expires_at, base_url: client.base_url}}

      _ ->
        {:error, build_client(base_url: client.base_url)}
    end
  end

  @spec req(fun) :: {atom, [list] | list | String.t()}
  defp req(fun) do
    with {:ok, response} <- fun.() do
      case response.status do
        code when code in 200..300 -> {:ok, parsed_body(response)}
        401 -> {:error, "You are not authenticated."}
        404 -> {:error, "Could not find resource."}
        _ -> {:error, parsed_body(response)}
      end
    else
      {:error, _} -> {:error, "The server is not available."}
    end
  end

  defp build_list(%{"items" => items} = list, id: list_id) when not is_nil(items) do
    %List{
      id: list["id"] || list_id,
      items: Enum.map(list["items"], &build_item(list["id"] || list_id, &1)),
      name: list["name"],
      src: list["src"],
      user_id: list["user_id"]
    }
  end

  defp build_list(list, id: list_id), do: %List{id: list["id"] || list_id, name: list["name"], src: list["src"]}
  defp build_list(list), do: %List{id: list["id"], name: list["name"], src: list["src"]}

  defp build_item(list_id, item) do
    %Item{
      id: item["id"],
      name: item["name"],
      src: item["src"],
      finished_at: item["finished_at"],
      list_id: list_id
    }
  end

  @spec parsed_body(response :: struct) :: any
  defp parsed_body(response) do
    case response.headers["content-type"] do
      "text/html;charset=utf-8" ->
        with {:ok, body} <- Poison.decode(response.body) do
          body
        else
          {:error, _} -> response.body
        end

      _ ->
        response.body
    end
  end

  @spec token_auth(token :: uuid, base_url :: String.t()) :: client
  defp token_auth(token, base_url) do
    Tesla.build_client([
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers,
       %{
         "Accept" => "application/json",
         "Content-Type" => "application/json",
         "Authorization" => "Token token=\"#{token}\""
       }}
    ])
  end

  @spec basic_auth(username: String.t(), password: String.t()) :: client
  @spec basic_auth(username: String.t(), password: String.t(), base_url: String.t()) :: client
  defp basic_auth(username: username, password: password),
    do: basic_auth(username: username, password: password, base_url: @default_base_url)

  defp basic_auth(username: username, password: password, base_url: base_url) do
    Tesla.build_client([
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers,
       %{"Accept" => "application/json", "Content-Type" => "application/json"}},
      {Tesla.Middleware.BasicAuth, Map.merge(%{username: username, password: password}, %{})}
    ])
  end
end
