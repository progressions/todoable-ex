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

  test "requests authentication when server is not available" do
    Tesla.Mock.mock fn
          %{method: :post, url: "http://localhost:4000/api/authenticate"} ->
            raise Tesla.Error
    end

    {:error, client} = Todoable.build_client()
    |> Todoable.authenticate(username: "username", password: "password")

    assert client == %Todoable.Client{expires_at: nil, token: nil}
  end

  test "requests all lists" do
    {:ok, client} = Todoable.build_client()
    |> Todoable.authenticate(username: "username", password: "password")

    assert Todoable.lists(client) == {:ok, lists()}
  end

  test "requests all lists when server is not available" do
    {:ok, client} = Todoable.build_client()
    |> Todoable.authenticate(username: "username", password: "password")

    Tesla.Mock.mock fn
          %{method: :get, url: "http://localhost:4000/api/lists"} ->
            raise Tesla.Error
    end

    assert Todoable.lists(client) == {:error, "The server is not available."}
  end
end
