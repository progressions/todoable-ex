defmodule TodoableTest do
  use ExUnit.Case
  doctest Todoable

  test "greets the world" do
    assert Todoable.hello() == :world
  end
end
