defmodule Todoable do
  @moduledoc """
  Documentation for Todoable.
  """

  use Tesla

  plug Tesla.Middleware.Tuples
  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  defmodule Client do
    defstruct token: nil,
              expires_at: nil
  end

  def lists(%Client{token: token}) do
    req(fn () ->
      token_auth(token)
      |> get("/lists")
    end)

    |> case do
      {:ok, body} -> {:ok, body["lists"]}
      {:error, body} -> {:error, body}
    end
  end

  def get_list(%Client{token: token}, id: list_id) do
    req(fn () ->
      token_auth(token)
      |> get("/lists/#{list_id}")
    end)
  end

  def create_list(%Client{token: token}, name: name) do
    req(fn () ->
      token_auth(token)
      |> post("/lists", %{list: %{name: name}})
    end)
  end

  def update_list(%Client{token: token}, id: list_id, name: name) do
    req(fn () ->
      token_auth(token)
      |> patch("/lists/#{list_id}", %{list: %{name: name}})
    end)
  end

  def delete_list(%Client{token: token}, id: list_id) do
    req(fn () ->
      token_auth(token)
      |> delete("/lists/#{list_id}")
    end)
  end

  def create_item(%Client{token: token}, list_id: list_id, name: name) do
    req(fn () ->
      token_auth(token)
      |> post("/lists/#{list_id}/items", %{item: %{name: name}})
    end)
  end

  def delete_item(%Client{token: token}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token)
      |> delete("/lists/#{list_id}/items/#{item_id}")
    end)
  end

  def finish_item(%Client{token: token}, list_id: list_id, item_id: item_id) do
    req(fn () ->
      token_auth(token)
      |> put("/lists/#{list_id}/items/#{item_id}/finish", %{})
    end)
  end

  def build_client() do
    %Client{token: nil, expires_at: nil}
  end

  def authenticate(%Client{token: _token, expires_at: _expires_at}, username: username, password: password) do
    basic_auth(username: username, password: password)
    |> post("/authenticate", %{})
    |> case do
      {:ok, %{body: %{"token" => token, "expires_at" => expires_at}}} -> {:ok, %Client{token: token, expires_at: expires_at}}
      _ -> {:error, %Client{token: nil, expires_at: nil}}
    end
  end

  defp req(fun) do
    with {:ok, response} <- fun.() do
      case response.status do
        200 -> {:ok, response.body}
        201 -> {:ok, response.body}
        204 -> {:ok, response.body}
        _ -> {:error, response.body}
      end
    else
      {:error, _} -> {:error, "The server is not available."}
    end
  end

  defp token_auth(token) do
    Tesla.build_client([
      {Tesla.Middleware.Headers, %{"Authorization" => "Token token=\"#{token}\""}}
    ])
  end

  defp basic_auth(username: username, password: password) do
    Tesla.build_client([
      {Tesla.Middleware.BasicAuth, Map.merge(%{username: username, password: password}, %{})}
    ])
  end
end
