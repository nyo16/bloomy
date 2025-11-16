defmodule BloomyTest do
  use ExUnit.Case
  doctest Bloomy

  test "greets the world" do
    assert Bloomy.hello() == :world
  end
end
