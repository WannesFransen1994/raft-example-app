defmodule RaftExampleApp.Area.AreaInstance do
  use GenServer
  @me __MODULE__

  alias RaftExampleApp.AppRegistry

  def start_link(_args) do
    GenServer.start_link(@me, :temp_state, name: via_tuple())
  end

  @impl true
  def init(:temp_state) do
    {:ok, :temp_state}
  end

  defp via_tuple() do
    {:via, Registry, {AppRegistry, {@me, :main}}}
  end
end
