defmodule RaftExampleApp.Player.PlayerInstance do
  use GenServer, restart: :transient
  @me __MODULE__
  @allowed_directions [:up, :down, :left, :right]
  # frequency in ms. Second param is in Hertz, e.g. 20hz = div(1000,20)
  @frequency div(1000, 10)
  # Idea is 1 grid / second
  @default_speed_per_s 1

  alias RaftExampleApp.AppRegistry
  alias RaftExampleApp.Area.AreaInstance

  @enforce_keys [:player_name]
  defstruct [
    :player_name,
    :movement,
    :tcp_conn,
    :frequency_timer,
    location: {1, 1},
    in_combat?: false
  ]

  # ################ #
  #       API        #
  # ################ #

  def start_link(args) do
    case args[:player_name] do
      nil -> {:error, {:missing_option, :player_name}}
      player_name -> GenServer.start_link(@me, args, name: via_tuple(player_name))
    end
  end

  def log_out(player), do: via_tuple(player) |> GenServer.call(:log_out)

  # The idea would be that a player can only exist after a TCP connection (or UDP - idea is the same) is made. We keep the PID, not sure if we'll need it. We monitor the process anyways to avoid disconnects. You could, if you'd want this, pass the connection when the player is made. Though this functionality is still recommended since disconnects can happen. If you don't pass it at creation time, beware of dangling player/ tcp connection processes.
  # Optional: heartbeats?
  def register_tcp_connection(player, tcp_conn_pid),
    do: via_tuple(player) |> GenServer.call({:register_tcp_connection, tcp_conn_pid})

  # * Later on this guard becomes obsolete if you use protobuf. You can define allowed messages there. This is just for prototyping
  # * For proof of concept, we'll only allow 4 directions. Of course you can extend this to a combination of sight orientation + pressed direction.
  # * This is for grid-based movement. If you want more "freedom" or granularity, allow multiple movements
  def start_move(player, direction) when direction in @allowed_directions do
    via_tuple(player) |> GenServer.cast({:start_move, direction})
  end

  def stop_move(player, direction) when direction in @allowed_directions do
    via_tuple(player) |> GenServer.cast({:stop_move, direction})
  end

  # ################ #
  #    Callbacks     #
  # ################ #

  # Startup / login.
  @impl true
  def init(args) do
    # Optional: restore location
    # Extra: you could do a performance benchmark of creating a timer as soon as movement / fighting occurs would be better. What's the tradeoff? Unnecessary timer creation vs unnecessary messages and callback invocation when not moving / fighting.
    {:ok, frequency_timer} = :timer.send_interval(@frequency, :update_player)
    {:ok, %@me{frequency_timer: frequency_timer, player_name: args[:player_name]}}
  end

  # Login procedure. Partly also the init callback...
  @impl true
  def handle_call({:register_tcp_connection, tcp_conn_pid}, _, state) do
    Process.monitor(tcp_conn_pid)
    {:reply, :ok, %@me{state | tcp_conn: tcp_conn_pid}}
  end

  # Logout procedure
  @impl true
  def handle_call(:log_out, _, state) do
    # Optional: verify whether you'd log out when in combat.
    {:stop, :normal, :ok, state}
  end

  # todo: handle disconnects / random crashes. NOT logout procedure

  # movement procedure single movement
  # When handling multiple movements, send early update and generate new timer.
  # If you only have 1 movement direction, this is easy since movement is overridden.
  @impl true
  def handle_cast({:start_move, direction}, %@me{movement: nil} = state) do
    start_time = :erlang.monotonic_time()
    {:noreply, %{state | movement: {direction, start_time}}}
  end

  @impl true
  def handle_cast({:start_move, _direction}, %@me{} = state), do: {:noreply, state}

  @impl true
  def handle_cast({:stop_move, direction}, %@me{movement: {direction, time}} = state) do
    _grids = div(time - :erlang.monotonic_time(), 1_000_000_000)
    # TODO: immediately update map if applicable. In academic example, not applicable
    {:noreply, %{state | movement: nil}}
  end

  @impl true
  def handle_cast({:stop_move, _direction}, %@me{} = state), do: {:noreply, state}

  # Periodic check
  @impl true
  def handle_info(:update_player, %@me{movement: nil} = state), do: {:noreply, state}

  @impl true
  def handle_info(
        :update_player,
        %@me{movement: {direction, offset_time}, location: {x, y}} = state
      ) do
    transferred_distance_in_grids =
      (offset_time - :erlang.monotonic_time())
      |> Kernel.*(@default_speed_per_s)
      |> div(-1_000_000_000)

    case transferred_distance_in_grids >= 1 do
      true ->
        new_loc =
          case direction do
            :up -> {x, y + 1}
            :down -> {x, y - 1}
            :left -> {x - 1, y}
            :right -> {x + 1, y}
          end

        :ok = AreaInstance.update_location(:main, state.player_name, new_loc)

        # In order to be correct, you should either allow continuous movement or subtract the remainder of the above calculation (which is lost with div) from the new monotonic time.
        {:noreply, %{state | movement: {direction, :erlang.monotonic_time()}, location: new_loc}}

      false ->
        {:noreply, state}
    end
  end

  # ################ #
  # Helper functions #
  # ################ #

  defp via_tuple(player_name) do
    {:via, Registry, {AppRegistry, {:player_instance, player_name}}}
  end
end

# INBOUND DATA DIAGRAM

# UDP => client application connection
# P_GS => Player genserver
# Map => the map genserver
# TCP / UDP => connection with client

# UDP              P_GS                   MAP
# 10hz    UP IN      |                      |
# -----------------> |                      |
#                    | updates new          |
# -----------------> | position every       |
#                    | 5ms/20hz             |
# -----------------> | -------------------> |
#                    | -------------------> |
# -----------------> | -------------------> |
#       UP OUT       | -------------------> |
# -----------------> | -------------------> |
#                    |
#                    |

# Note Matthew: from player to genserver -> do all inputs asap. Throttle / drop at Player genserver
# Note Bill: make code changeable. don't worry about peformance in the beginning

# BAD OUTBOUND DATA DIAGRAM

# MAP            TCP p1 + p2
# 10hz  changes      |
# -----------------> |
#       changes      |
# -----------------> |
#       changes      |
# -----------------> |
#                    |
#                    |
#                    |
#                    |
#                    |
#                    |
# Note: changes have to be sent twice by map - already busy and will have a delay.
#  + map logic becomes complexer since it'll cache the delta changes until iteration
# Better to use a dispatcher inbetween

# DECENT? OUTBOUND DATA DIAGRAM

# MAP             DISPATCH       TCP p1 + p2
# 10hz  changes      |                |
# -----------------> | -------------> |
#       changes      |                |
# -----------------> | -------------> |
#       changes      |                |
# -----------------> | -------------> |
#                    |                |
#                    |                |
#                    |                |
#                    |                |
#                    |                |
# Map can send changes immediately to dispatch, which get cached there

# #############################################################
#  Naive no overlap
# ############################# #
# +++++++++++++++++++++++++++++ #
# +                           + #
# +                           + #
# +++++++++++++++++++++++++++++ #
# ----------------------------- #
# -                           - #
# -                           - #
# ----------------------------- #
# ############################# #

# Naive with overlap
# ############################# #
# +++++++++++++++++++++++++++++ #
# +                           + #
# +                           + #
# *---------------------------* #
# *                           * #
# *+++++++++++++++++++++++++++* #
# -                           - #
# -                           - #
# ----------------------------- #
# ############################# #
# Note to the overlapping areas. This to avoid disappearing / appearing
