defmodule RaftExampleAppTest do
  use ExUnit.Case
  doctest RaftExampleApp

  test "greets the world" do
    assert RaftExampleApp.hello() == :world
  end
end
