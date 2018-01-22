ExUnit.start()

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

  setup do
    {:ok, client} =
      Todoable.build_client(base_url: @base_url)
      |> Todoable.authenticate(@username, @password)

    {:ok, client: client}
  end

  test "acts on lists", state do
    {:ok, lists} = Todoable.lists(state.client)
    matches = Enum.filter(lists, fn list -> list.name == "Shopping List" end)
    Enum.each(matches, fn list -> Todoable.delete_list(state.client, list) end)

    # Create list
    #
    {:ok, list} = Todoable.create_list(state.client, name: "Shopping List")
    assert list.name == "Shopping List"
    assert list.id != nil

    # Check that new list is included in all lists
    #
    {:ok, lists} = Todoable.lists(state.client)
    matches = Enum.filter(lists, fn list -> list.name == "Shopping List" end)
    assert length(matches) > 0

    {:ok, list} = Todoable.get_list(state.client, id: list.id)
    Enum.each(list.items, fn item ->
      Todoable.delete_item(state.client, list_id: list.id, item_id: item.id)
    end)

    # Create an item
    #
    {:ok, item} = Todoable.create_item(state.client, list_id: list.id, name: "Get some milk")
    assert item.name == "Get some milk"
    assert item.finished_at == nil

    # Finish an item
    #
    {:ok, "Get some milk finished"} =
      Todoable.finish_item(state.client, list_id: list.id, item_id: item.id)

    # Get list, check that item exists on it
    #
    {:ok, list} = Todoable.get_list(state.client, id: list.id)
    items = Enum.filter(list.items, fn item -> item.name == "Get some milk" end)
    assert length(items) > 0

    # Delete item
    #
    {:ok, ""} = Todoable.delete_item(state.client, list_id: list.id, item_id: item.id)

    # Get list, check that delete item doesn't exist on it
    #
    {:ok, list} = Todoable.get_list(state.client, id: list.id)
    items = Enum.filter(list.items, fn item -> item.name == "Get some milk" end)
    assert length(items) == 0

    # Delete list
    #
    assert Todoable.delete_list(state.client, id: list.id) == {:ok, ""}

    # Check that the deleted list doesn't appear in all lists
    #
    {:ok, lists} = Todoable.lists(state.client)
    new_matches = Enum.filter(lists, fn list -> list.name == "Shopping List" end)
    assert length(new_matches) == length(matches) - 1
  end
end
