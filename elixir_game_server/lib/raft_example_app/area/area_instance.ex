defmodule RaftExampleApp.Area.AreaInstance do
  use GenServer
  @me __MODULE__

  alias RaftExampleApp.AppRegistry

  @enforce_keys [:locations]
  defstruct [:locations]

  # ################ #
  #       API        #
  # ################ #
  def start_link(_args), do: GenServer.start_link(@me, :temp_state, name: via_tuple(:main))

  # Default to main, prepare for chunking
  def update_location(:main, player_name, location) when player_name != nil,
    do: via_tuple(:main) |> GenServer.cast({:update_location, player_name, location})

  # ################ #
  #    Callbacks     #
  # ################ #
  @impl true
  def init(_), do: {:ok, %@me{locations: %{}}}

  @impl true
  def handle_cast({:update_location, player_name, location}, %@me{} = state) do
    # TODO: implement logic for maps. E.g. wall detection or player character blocking.
    new_locations = Map.put(state.locations, player_name, location)
    action = {:new_loc, player_name, location}
    {:noreply, %{state | locations: new_locations}, {:continue, {:dispatch, action}}}
  end

  # Note 1: optimization problem here. Network traffic costs money, roughly 80b tcp/ip pckage overhead for each packet. Use dispatching wisely with periodic updates. Updates can be cached and reset after send.
  # Note 2: map cpu optimization problem here. Use a dispatcher process
  # Keeping it instant and academical of course.
  @impl true
  def handle_continue({:dispatch, action}, %@me{} = state) do
    # Assuming the action would be a location update. Can be multiple things (e.g. aoe attack)
    # Suggest to serialize into protobuf msg here (dispatcher). This to avoid multiple pointless serialization.
    {:new_loc, _action_player_name, {_new_x, _new_y}} = action

    Enum.each(state.locations, fn {player_name, {_x, _y}} ->
      RaftExampleApp.Tcp.Handler.inform(player_name, action)
    end)

    {:noreply, state}
  end

  # ################ #
  # Helper functions #
  # ################ #

  defp via_tuple(chunk_name) do
    {:via, Registry, {AppRegistry, {@me, chunk_name}}}
  end
end
