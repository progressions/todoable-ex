defmodule TodoableBaseUrlTest do
  use ExUnit.Case

  doctest Todoable

  def lists do
    [
      %{
        "name" => "Urgent Things",
        "src" => "http://todoable.com/api/lists/123-abc",
        "id" => "123-abc"
      },
      %{
        "name" => "Shopping List",
        "src" => "http://todoable.com/api/lists/456-def",
        "id" => "456-def"
      }
    ]
  end

  def items do
    [
      %{
        "name" => "Milk",
        "src" => "http://todoable.com/api/lists/123-abc/items/987-zyx",
        "id" => "987-zyx",
        "finished_at" => nil
      },
      %{
        "name" => "Bread",
        "src" => "http://todoable.com/api/lists/456-def/items/654-wvu",
        "id" => "654-wvu",
        "finished_at" => "2018-01-02"
      }
    ]
  end

  setup do
    Tesla.Mock.mock(fn
      %{method: :post, url: "http://todoable.com/api/authenticate"} ->
        %Tesla.Env{status: 200, body: %{"token" => "abc123", "expires_at" => "123"}}

      %{method: :get, url: "http://todoable.com/api/lists"} ->
        %Tesla.Env{status: 200, body: %{"lists" => lists()}}

      %{method: :get, url: "http://todoable.com/api/lists/123-abc"} ->
        %Tesla.Env{status: 200, body: List.first(lists())}

      %{method: :post, url: "http://todoable.com/api/lists"} ->
        %Tesla.Env{status: 201, body: List.first(lists())}

      %{method: :patch, url: "http://todoable.com/api/lists/123-abc"} ->
        %Tesla.Env{status: 200, body: List.first(lists())}

      %{method: :delete, url: "http://todoable.com/api/lists/123-abc"} ->
        %Tesla.Env{status: 204, body: ""}

      %{method: :post, url: "http://todoable.com/api/lists/123-abc/items"} ->
        %Tesla.Env{status: 201, body: List.first(items())}

      %{method: :put, url: "http://todoable.com/api/lists/456-def/items/654-wvu/finish"} ->
        item = List.last(items())
        %Tesla.Env{status: 200, body: "#{item["name"]} finished"}

      %{method: :delete, url: "http://todoable.com/api/lists/123-abc/items/987-zyx"} ->
        %Tesla.Env{status: 204, body: ""}
    end)

    {:ok, client} =
      Todoable.build_client(base_url: "http://todoable.com/api")
      |> Todoable.authenticate("username", "password")

    {:ok, client: client}
  end

  test "builds a client" do
    assert Todoable.build_client() == %Todoable.Client{
             expires_at: nil,
             token: nil,
             base_url: "http://localhost:4000/api"
           }
  end

  test "builds a client with given base_url" do
    assert Todoable.build_client(base_url: "http://todoable.com/api") == %Todoable.Client{
             expires_at: nil,
             token: nil,
             base_url: "http://todoable.com/api"
           }
  end

  test "authenticates client against server" do
    {:ok, client} =
      Todoable.build_client(base_url: "http://todoable.com/api")
      |> Todoable.authenticate("username", "password")

    assert client == %Todoable.Client{
             expires_at: "123",
             token: "abc123",
             base_url: "http://todoable.com/api"
           }
  end

  test "requests authentication with invalid credentials" do
    Tesla.Mock.mock(fn %{method: :post, url: "http://todoable.com/api/authenticate"} ->
      %Tesla.Env{status: 401, body: "unauthorized"}
    end)

    {:error, client} =
      Todoable.build_client(base_url: "http://todoable.com/api")
      |> Todoable.authenticate("username", "password")

    assert client == %Todoable.Client{
             expires_at: nil,
             token: nil,
             base_url: "http://todoable.com/api"
           }
  end

  test "requests authentication when server is not available" do
    Tesla.Mock.mock(fn %{method: :post, url: "http://todoable.com/api/authenticate"} ->
      raise Tesla.Error
    end)

    {:error, client} =
      Todoable.build_client(base_url: "http://todoable.com/api")
      |> Todoable.authenticate("username", "password")

    assert client == %Todoable.Client{
             expires_at: nil,
             token: nil,
             base_url: "http://todoable.com/api"
           }
  end

  test "requests all lists", state do
    assert Todoable.lists(state.client) ==
             {:ok,
              [
                %Todoable.List{
                  id: "123-abc",
                  items: :not_loaded,
                  name: "Urgent Things",
                  src: "http://todoable.com/api/lists/123-abc"
                },
                %Todoable.List{
                  id: "456-def",
                  name: "Shopping List",
                  src: "http://todoable.com/api/lists/456-def",
                  items: :not_loaded
                }
              ]}
  end

  test "requests all lists when server is not available", state do
    Tesla.Mock.mock(fn %{method: :get, url: "http://todoable.com/api/lists"} ->
      raise Tesla.Error
    end)

    assert Todoable.lists(state.client) == {:error, "The server is not available."}
  end

  test "requests all lists with invalid credentials", state do
    Tesla.Mock.mock(fn %{method: :get, url: "http://todoable.com/api/lists"} ->
      %Tesla.Env{status: 401, body: "unauthorized"}
    end)

    assert Todoable.lists(state.client) == {:error, "You are not authenticated."}
  end

  test "requests a single list", state do
    assert Todoable.get_list(state.client, id: "123-abc") ==
             {:ok,
              %Todoable.List{
                id: "123-abc",
                name: "Urgent Things",
                src: "http://todoable.com/api/lists/123-abc",
                items: :not_loaded
              }}
  end

  test "requests a single list when server is not available", state do
    Tesla.Mock.mock(fn %{method: :get, url: "http://todoable.com/api/lists/123-abc"} ->
      raise Tesla.Error
    end)

    assert Todoable.get_list(state.client, id: "123-abc") ==
             {:error, "The server is not available."}
  end

  test "requests a single list which doesn't exist", state do
    Tesla.Mock.mock(fn %{method: :get, url: "http://todoable.com/api/lists/123-abc"} ->
      %Tesla.Env{status: 404, body: ""}
    end)

    assert Todoable.get_list(state.client, id: "123-abc") == {:error, "Could not find resource."}
  end

  test "creates a list", state do
    assert Todoable.create_list(state.client, name: "Shopping") ==
             {:ok,
              %Todoable.List{
                id: "123-abc",
                name: "Urgent Things",
                src: "http://todoable.com/api/lists/123-abc",
                items: :not_loaded
              }}
  end

  test "creates a list when server is not available", state do
    Tesla.Mock.mock(fn %{method: :post, url: "http://todoable.com/api/lists"} ->
      raise Tesla.Error
    end)

    assert Todoable.create_list(state.client, name: "Shopping") ==
             {:error, "The server is not available."}
  end

  test "updates list", state do
    assert Todoable.update_list(state.client, id: "123-abc", name: "Groceries") ==
             {:ok,
              %Todoable.List{
                id: "123-abc",
                name: "Urgent Things",
                src: "http://todoable.com/api/lists/123-abc",
                items: :not_loaded
              }}
  end

  test "updates list when server is not available", state do
    Tesla.Mock.mock(fn %{method: :patch, url: "http://todoable.com/api/lists/123-abc"} ->
      raise Tesla.Error
    end)

    assert Todoable.update_list(state.client, id: "123-abc", name: "Groceries") ==
             {:error, "The server is not available."}
  end

  test "deletes list", state do
    assert Todoable.delete_list(state.client, id: "123-abc") == {:ok, ""}
  end

  test "deletes list when server is not available", state do
    Tesla.Mock.mock(fn %{method: :delete, url: "http://todoable.com/api/lists/123-abc"} ->
      raise Tesla.Error
    end)

    assert Todoable.delete_list(state.client, id: "123-abc") ==
             {:error, "The server is not available."}
  end

  test "creates an item", state do
    assert Todoable.create_item(state.client, list_id: "123-abc", name: "Milk") ==
             {:ok,
              %Todoable.Item{
                finished_at: nil,
                id: "987-zyx",
                name: "Milk",
                src: "http://todoable.com/api/lists/123-abc/items/987-zyx",
                list_id: "123-abc"
              }}
  end

  test "creates an item when server is not available", state do
    Tesla.Mock.mock(fn %{method: :post, url: "http://todoable.com/api/lists/123-abc/items"} ->
      raise Tesla.Error
    end)

    assert Todoable.create_item(state.client, list_id: "123-abc", name: "Milk") ==
             {:error, "The server is not available."}
  end

  test "deletes an item", state do
    assert Todoable.delete_item(state.client, list_id: "123-abc", item_id: "987-zyx") == {:ok, ""}
  end

  test "deletes an item when server is not available", state do
    Tesla.Mock.mock(fn %{
                         method: :delete,
                         url: "http://todoable.com/api/lists/123-abc/items/987-zyx"
                       } ->
      raise Tesla.Error
    end)

    assert Todoable.delete_item(state.client, list_id: "123-abc", item_id: "987-zyx") ==
             {:error, "The server is not available."}
  end

  test "finishes an item", state do
    assert Todoable.finish_item(state.client, list_id: "456-def", item_id: "654-wvu") ==
             {:ok, "Bread finished"}
  end

  test "finishes an item when server is not available", state do
    Tesla.Mock.mock(fn %{
                         method: :put,
                         url: "http://todoable.com/api/lists/456-def/items/654-wvu/finish"
                       } ->
      raise Tesla.Error
    end)

    assert Todoable.finish_item(state.client, list_id: "456-def", item_id: "654-wvu") ==
             {:error, "The server is not available."}
  end
end
