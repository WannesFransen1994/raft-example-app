defmodule DistributedCalculatorTest do
  use ExUnit.Case
  doctest DistributedCalculator

  test "greets the world" do
    assert DistributedCalculator.hello() == :world
  end
end
