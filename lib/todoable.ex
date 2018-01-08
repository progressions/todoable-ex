defmodule Todoable do
  @moduledoc """
  Documentation for Todoable.
  """

  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  def lists(%{token: token}) do
    %{body: body} = token_auth(token)
    |> get("/lists")

    body
  end

  def get_list(%{token: token}, id: list_id) do
    %{body: body} = token_auth(token)
    |> get("/lists/#{list_id}")

    body
  end

  def create_list(%{token: token}, name: name) do
    %{body: body} = token_auth(token)
    |> post("/lists", %{list: %{name: name}})

    body
  end

  def token_auth(token) do
    Tesla.build_client([
      {Tesla.Middleware.Headers, %{"Authorization" => "Token token=\"#{token}\""}}
    ])
  end

  def basic_auth(username: username, password: password) do
    Tesla.build_client([
      {Tesla.Middleware.BasicAuth, Map.merge(%{username: username, password: password}, %{})}
    ])
    |> post("/authenticate", %{})
  end

  def build_client do
    %{body: %{"token" => token, "expires_at" => expires_at}} = basic_auth(username: "username", password: "password")

    %{token: token, expires_at: expires_at}
  end
end
