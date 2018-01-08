defmodule Todoable do
  @moduledoc """
  Documentation for Todoable.
  """

  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  defmodule Client do
    defstruct token: nil,
              expires_at: nil
  end

  def lists(%Client{token: token}) do
    response = token_auth(token)
    |> get("/lists")

    case response.status do
      200 -> response.body["lists"]
      _ -> response.body
    end
  end

  def get_list(%Client{token: token}, id: list_id) do
    %{body: body} = token_auth(token)
    |> get("/lists/#{list_id}")

    body
  end

  def create_list(%Client{token: token}, name: name) do
    %{body: body} = token_auth(token)
    |> post("/lists", %{list: %{name: name}})

    body
  end

  def update_list(%Client{token: token}, id: list_id, name: name) do
    %{body: body} = token_auth(token)
    |> patch("/lists/#{list_id}", %{list: %{name: name}})

    body
  end

  def delete_list(%Client{token: token}, id: list_id) do
    %{body: body} = token_auth(token)
    |> delete("/lists/#{list_id}")

    body == ""
  end

  def create_item(%Client{token: token}, id: list_id, name: name) do
    %{body: body} = token_auth(token)
    |> post("/lists/#{list_id}/items", %{item: %{name: name}})

    body
  end

  def delete_item(%Client{token: token}, list_id: list_id, item_id: item_id) do
    %{body: body} = token_auth(token)
    |> delete("/lists/#{list_id}/items/#{item_id}")

    body
  end

  def finish_item(%Client{token: token}, list_id: list_id, item_id: item_id) do
    %{body: body} = token_auth(token)
    |> put("/lists/#{list_id}/items/#{item_id}/finish", %{})

    body
  end

  def build_client() do
    %Client{token: nil, expires_at: nil}
  end

  def authenticate(%Client{token: token, expires_at: expires_at}=client, username: username, password: password) do
    try do
      %{body: %{"token" => token, "expires_at" => expires_at}} = basic_auth(username: username, password: password)
      |> post("/authenticate", %{})

      {:ok, %Client{token: token, expires_at: expires_at}}
    rescue
      Tesla.Error -> {:error, client}
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
