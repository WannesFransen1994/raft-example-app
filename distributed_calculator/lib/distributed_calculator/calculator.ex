defmodule DistributedCalculator.Calculator do
  use GenStateMachine
  @me __MODULE__
  @supported_ops [:*, :+, :-, :/]

  alias DistributedCalculator.CalculatorsRegistry

  @enforce_keys [:name]
  defstruct [:name, :value, :pending_operator]

  ###################################
  #             API                 #
  ###################################

  def start_link(args) do
    name = args[:name]
    start_state = {:clean, %@me{name: name}}
    outcome = name && GenStateMachine.start_link(@me, start_state, name: via_tuple(name))
    outcome || {:error, {:missing_arg, :name}}
  end

  def insert_operation(name, op) when op in @supported_ops do
    via_tuple(name) |> GenStateMachine.call({:add_operation, op})
  end

  def insert_value(name, value) when is_integer(value) do
    via_tuple(name) |> GenStateMachine.call({:add_value, value})
  end

  ###################################
  #          CALLBACKS              #
  ###################################
  # Personally I prefer to `:handle_event_function` callback mode instead of `:state_functions`.
  # This enables you to group function clauses on state -or- transition event.

  # Clean state transition. Only allow correct transitions, crash otherwise. Note the nil pattern matching.
  # State transition clean -> value
  @impl true
  def handle_event({:call, from}, {:add_value, value}, :clean, %@me{value: nil} = data) do
    {:next_state, :value, %{data | value: value}, [{:reply, from, value}]}
  end

  # State transition value -> operator
  @impl true
  def handle_event(
        {:call, from},
        {:add_operation, op},
        :value,
        %@me{pending_operator: nil} = data
      )
      when op in @supported_ops do
    {:next_state, :operator, %{data | pending_operator: op}, [{:reply, from, op}]}
  end

  # State transition operator -> value
  @impl true
  def handle_event({:call, from}, {:add_value, value}, :operator, %@me{} = data) do
    new_value =
      case data.pending_operator do
        :* -> data.value * value
        :/ -> data.value / value
        :+ -> data.value + value
        :- -> data.value - value
      end

    {:next_state, :value, %{data | pending_operator: nil, value: new_value},
     [{:reply, from, new_value}]}
  end

  ###################################
  #   HELPER FUNCTIONS              #
  ###################################

  defp via_tuple(name) do
    {:via, Registry, {CalculatorsRegistry, {:calculator, name}, nil}}
  end
end

# State (transition) diagram

# Clean
#   🠓
# Value🠐🠐🠐
#   🠓       🠑
# Operator  🠑
#   🠒🠒🠒🠒🠒 🠑
