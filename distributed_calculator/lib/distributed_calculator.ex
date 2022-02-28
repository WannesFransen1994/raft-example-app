defmodule DistributedCalculator do
  alias DistributedCalculator.{CalculatorsSupervisor, Calculator}

  def start_calc(name) do
    child_spec = {Calculator, [name: name]}
    DynamicSupervisor.start_child(CalculatorsSupervisor, child_spec)
  end
end
