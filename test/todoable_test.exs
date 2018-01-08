defmodule TodoableTest do
  use ExUnit.Case

  doctest Todoable

  def lists do
    [
      %{
        "name" => "Urgent Things",
        "src" => "http://localhost:4000/api/lists/123-abc",
        "id" => "123-abc"
      }, %{
        "name" => "Shopping List",
        "src" => "http://localhost:4000/api/lists/456-def",
        "id" => "456-def"
      },
    ]
  end

  setup do
    Tesla.Mock.mock fn
          %{method: :post, url: "http://localhost:4000/api/authenticate"} ->
            %Tesla.Env{status: 200, body: %{"token" => "abc123", "expires_at" => "123"}}
          %{method: :get, url: "http://localhost:4000/api/lists"} ->
            %Tesla.Env{status: 200, body: %{"lists" => lists()}}
    end

    :ok
  end

  test "builds a client" do
    assert Todoable.build_client() == %Todoable.Client{expires_at: nil, token: nil}
  end

  test "authenticates client against server" do
    {:ok, client} = Todoable.build_client()
    |> Todoable.authenticate(username: "username", password: "password")

    assert client == %Todoable.Client{expires_at: "123", token: "abc123"}
  end

  test "requests all lists" do
    {:ok, client} = Todoable.build_client()
    |> Todoable.authenticate(username: "username", password: "password")

    assert Todoable.lists(client) == lists()
  end
end
