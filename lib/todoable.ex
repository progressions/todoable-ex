defmodule Todoable do
  @moduledoc """
  Create, delete, and manage todo lists and items on a remote server.

  """

  use Tesla

  plug Tesla.Middleware.Tuples
  plug Tesla.Middleware.JSON

  @default_base_url "http://localhost:4000/api"

  defmodule Client do
    defstruct [:token, :expires_at, :base_url]
  end
  @type client :: %Todoable.Client{}

  @type uuid :: String.t()
  @type todo_list :: %{id: uuid, name: String.t(), src: String.t()}
  @type todo_item :: %{id: uuid, name: String.t(), src: String.t(), finished_at: String.t(), list_id: uuid}

  @doc """
  Returns all the lists for the authenticated user on the Todo server.

  {:ok, client} = Todoable.build_client() |> Todoable.authenticate(username: "username", password: "password")
  {:ok,
   %Todoable.Client{base_url: "http://localhost:4000/api",
    expires_at: "2018-01-09 23:33:49.843257",
    token: "98ad1863-19b0-4de1-9d85-cf27d53423f0"}}

  Todoable.lists(client)
  {:ok,
   [%{"id" => "9797e12e-32c4-4b3b-b68f-c534fbac5097", "name" => "SHOP",
      "src" => "http://localhost:4000/lists/9797e12e-32c4-4b3b-b68f-c534fbac5097"},
    %{"id" => "49e85b14-e6b6-4c4d-87b9-738f3b69423d", "name" => "SHOPPING",
      "src" => "http://localhost:4000/lists/49e85b14-e6b6-4c4d-87b9-738f3b69423d"}]}

  """
  @spec lists(client :: client) :: {atom, [todo_list]}
  def lists(%Client{token: token, base_url: base_url}) do
    req(fn () ->
      token_auth(token, base_url)
      |> get("/lists")
    end)

    |> case do
      {:ok, body}     -> {:ok, body["lists"]}
      {:error, body}  -> {:error, body}
    end
  end

  @doc """
  Returns a specific list item from the Todo server.
  """
  @spec get_list(client, id :: uuid) :: {atom, todo_list}
  def get_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> get("/lists/#{list_id}")
    end)
  end

  @doc """
  Creates a list with the given name on the Todo server.
  """
  @spec create_list(client, name: String.t()) :: {atom, todo_list}
  def create_list(%Client{token: token, base_url: base_url}, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> post("/lists", %{list: %{name: name}})
    end)
  end

  @doc """
  Updates the name of a list on the Todo server.
  """
  @spec update_list(client, id: uuid, name: String.t()) :: {atom, todo_list}
  def update_list(%Client{token: token, base_url: base_url}, id: list_id, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> patch("/lists/#{list_id}", %{list: %{name: name}})
    end)
  end

  @doc """
  Deletes a list from the Todo server.
  """
  @spec delete_list(client, id: uuid) :: {atom, String.t()}
  def delete_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}")
    end)
  end

  @doc """
  Creates an item for a given list on the Todo server.
  """
  @spec create_item(client, list_id: uuid, name: String.t()) :: {atom, todo_item}
  def create_item(%Client{token: token, base_url: base_url}, list_id: list_id, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> post("/lists/#{list_id}/items", %{item: %{name: name}})
    end)
  end

  @doc """
  Deletes an item from a given list on the Todo server.
  """
  @spec delete_item(client, list_id: uuid, item_id: uuid) :: {atom, String.t()}
  def delete_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}/items/#{item_id}")
    end)
  end

  @doc """
  Marks an item as finished on the Todo server.
  """
  @spec finish_item(client, list_id: uuid, item_id: uuid) :: {atom, todo_item}
  def finish_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> put("/lists/#{list_id}/items/#{item_id}/finish", %{})
    end)
  end

  @doc """
  Returns a new client, ready for authentication.
  """
  @spec build_client() :: client
  def build_client(), do: build_client(base_url: @default_base_url)
  def build_client(base_url: base_url) do
    %Client{token: nil, expires_at: nil, base_url: base_url}
  end

  @spec authenticate(client, username: String.t(), password: String.t()) :: client
  @spec authenticate(client, username: String.t(), password: String.t(), base_url: String.t()) :: client
  def authenticate(%Client{base_url: base_url}=client, username: username, password: password), do: authenticate(client, username: username, password: password, base_url: base_url)
  def authenticate(%Client{token: _token, expires_at: _expires_at}, username: username, password: password, base_url: base_url) do
    basic_auth(username: username, password: password, base_url: base_url)
    |> post("/authenticate", %{})
    |> case do
      {:ok, %{body: %{"token" => token, "expires_at" => expires_at}}} -> {:ok, %Client{token: token, expires_at: expires_at, base_url: base_url}}
      _                                                               -> {:error, build_client(base_url: base_url)}
    end
  end

  @spec req(fun) :: {atom, [list]|list|String.t()}
  defp req(fun) do
    with {:ok, response}  <- fun.() do

      case response.status do
        code when code in 200..300 -> {:ok, parsed_body(response)}
        401                        -> {:error, "You are not authenticated."}
        404                        -> {:error, "Could not find resource."}
        _                          -> {:error, parsed_body(response)}
      end
    else
      {:error, _}                  -> {:error, "The server is not available."}
    end
  end

  @spec parsed_body(response :: struct) :: any
  defp parsed_body(response) do
    case response.headers["content-type"] do
      "text/html;charset=utf-8"    -> with {:ok, body} <- Poison.decode(response.body), do: body
      _                            -> response.body
    end
  end

  @spec token_auth(token :: uuid, base_url :: String.t()) :: client
  defp token_auth(token, base_url) do
    Tesla.build_client([
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, %{"Accept" => "application/json", "Content-Type" => "application/json", "Authorization" => "Token token=\"#{token}\""}},
    ])
  end

  @spec basic_auth(username: String.t(), password: String.t()) :: client
  @spec basic_auth(username: String.t(), password: String.t(), base_url: String.t()) :: client
  defp basic_auth(username: username, password: password), do:
    basic_auth(username: username, password: password, base_url: @default_base_url)
  defp basic_auth(username: username, password: password, base_url: base_url) do
    Tesla.build_client([
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, %{"Accept" => "application/json", "Content-Type" => "application/json"}},
      {Tesla.Middleware.BasicAuth, Map.merge(%{username: username, password: password}, %{})},
    ])
  end
end
