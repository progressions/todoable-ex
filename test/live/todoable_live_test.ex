ExUnit.start()
require IEx

defmodule TodoableBaseUrlTest do
  use ExUnit.Case

  case System.get_env("API") do
    "teachable" ->
      IO.puts("Running live tests against Teachable API")

      @base_url "http://todoable.teachable.tech/api/"
      @username "progressions@gmail.com"
      @password "todoable"

    "heroku" ->
      IO.puts("Running live tests against Heroku API")

      @base_url "https://intense-hamlet-87296.herokuapp.com/api"
      @username "username"
      @password "password"

    _ ->
      IO.puts("Running live tests against local API")

      @base_url "http://localhost:4000/api"
      @username "username"
      @password "password"
  end

  def puts(message) do
    if System.get_env("VERBOSE") == "true", do: IO.puts(message)
  end

  test "acts on lists" do
    client = Todoable.build_client(base_url: @base_url)
    {:ok, client} = Todoable.authenticate(client, @username, @password)

    {:ok, lists} = Todoable.lists(client)

    lists
    |> Enum.filter(fn list -> list.name == "Shopping List" end)
    |> Enum.each(fn list -> Todoable.delete_list(client, list) end)

    puts("Create list")

    {:ok, list} = Todoable.create_list(client, name: "Shopping List")
    assert list.name == "Shopping List"
    assert list.id != nil

    puts("Check that new list is included in all lists")

    {:ok, lists} = Todoable.lists(client)
    matches = Enum.filter(lists, &(&1.name == "Shopping List"))
    assert length(matches) == 1

    puts("Check that you can't create a list with the same name")

    {:error, result} = Todoable.create_list(client, name: "Shopping List")
    assert result == %{"name" => ["has already been taken"]}

    puts("Create an item")

    {:ok, item} = Todoable.create_item(client, list_id: list.id, name: "Get some milk")
    assert item.name == "Get some milk"
    assert item.finished_at == nil
    assert item.list_id == list.id

    puts("Finish an item")

    {:ok, "Get some milk finished"} =
      Todoable.finish_item(client, list_id: list.id, item_id: item.id)

    puts("Get list, check that item exists on it")

    {:ok, list} = Todoable.get_list(client, id: list.id)
    items = Enum.filter(list.items, fn item -> item.name == "Get some milk" end)
    assert length(items) > 0

    puts("Delete item")

    {:ok, ""} = Todoable.delete_item(client, list_id: list.id, item_id: item.id)

    puts("Get list, check that delete item doesn't exist on it")

    {:ok, list} = Todoable.get_list(client, id: list.id)
    items = Enum.filter(list.items, fn item -> item.name == "Get some milk" end)
    assert length(items) == 0

    puts("Delete list")

    assert Todoable.delete_list(client, id: list.id) == {:ok, ""}

    puts("Check that the deleted list doesn't appear in all lists")

    {:ok, lists} = Todoable.lists(client)
    new_matches = Enum.filter(lists, fn list -> list.name == "Shopping List" end)
    assert length(new_matches) == 0

    puts("Check that nonexistent list can't be found")

    {:error, "Could not find resource."} = Todoable.get_list(client, id: list.id)
  end
end
