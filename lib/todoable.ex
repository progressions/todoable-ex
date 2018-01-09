defmodule Todoable do
  @moduledoc """
  Documentation for Todoable.
  """

  use Tesla

  plug Tesla.Middleware.Tuples
  plug Tesla.Middleware.JSON

  @default_base_url "http://localhost:4000/api"

  defmodule Client do
    defstruct [:token, :expires_at, :base_url]
  end

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

  def get_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> get("/lists/#{list_id}")
    end)
  end

  def create_list(%Client{token: token, base_url: base_url}, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> post("/lists", %{list: %{name: name}})
    end)
  end

  def update_list(%Client{token: token, base_url: base_url}, id: list_id, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> patch("/lists/#{list_id}", %{list: %{name: name}})
    end)
  end

  def delete_list(%Client{token: token, base_url: base_url}, id: list_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}")
    end)
  end

  def create_item(%Client{token: token, base_url: base_url}, list_id: list_id, name: name) do
    req(fn () ->
      token_auth(token, base_url)
      |> post("/lists/#{list_id}/items", %{item: %{name: name}})
    end)
  end

  def delete_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> delete("/lists/#{list_id}/items/#{item_id}")
    end)
  end

  def finish_item(%Client{token: token, base_url: base_url}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token, base_url)
      |> put("/lists/#{list_id}/items/#{item_id}/finish", %{})
    end)
  end

  def build_client() do
    %Client{token: nil, expires_at: nil, base_url: nil}
  end

  def authenticate(client, username: username, password: password), do: authenticate(client, username: username, password: password, base_url: @default_base_url)
  def authenticate(%Client{token: _token, expires_at: _expires_at}, username: username, password: password, base_url: base_url) do
    basic_auth(username: username, password: password, base_url: base_url)
    |> post("/authenticate", %{})
    |> case do
      {:ok, %{body: %{"token" => token, "expires_at" => expires_at}}} -> {:ok, %Client{token: token, expires_at: expires_at, base_url: base_url}}
      _                                                               -> {:error, build_client()}
    end
  end

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

  defp parsed_body(response) do
    case response.headers["content-type"] do
      "text/html;charset=utf-8"    -> with {:ok, body} <- Poison.decode(response.body), do: body
      _                            -> response.body
    end
  end

  defp token_auth(token, base_url) do
    Tesla.build_client([
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, %{"Accept" => "application/json", "Content-Type" => "application/json", "Authorization" => "Token token=\"#{token}\""}},
    ])
  end

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
