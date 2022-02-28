defmodule RaftExampleApp.Area.AreaFSM do
  use GenStateMachine

  @me __MODULE__

  alias RaftExampleApp.AppRegistry

  defstruct connections: 0

  def start_link(_args \\ []) do
    GenStateMachine.start_link(@me, {{:accepting, :low}, %@me{}}, name: via_tuple())
  end

  def handle_event(:cast, {:report, :new_conns}, {:accepting, :low}, state_data) do
    {:next_state, {:accepting, :low}, state_data}
  end

  defp via_tuple() do
    {:via, Registry, {AppRegistry, {@me, :main}}}
  end
end
