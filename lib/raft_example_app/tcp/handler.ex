defmodule RaftExampleApp.Tcp.Handler do
  use GenServer, restart: :temporary
  require Logger
  @me __MODULE__

  alias RaftExampleApp.Player.{PlayerInstance, PlayerOperations}
  alias RaftExampleApp.AppRegistry

  @enforce_keys [:client_socket]
  defstruct [:client_socket, :username]

  def start_link(args), do: GenServer.start_link(@me, args)

  def init(args) do
    socket = args[:client_socket] || raise "missing_arg"
    {:ok, %@me{client_socket: socket}}
  end

  def inform(username, msg) do
    {:via, Registry, {AppRegistry, {:tcp_handler, username}}} |> GenServer.cast({:report, msg})
  end

  # #####################################

  def handle_cast({:report, msg}, %@me{} = state) do
    case msg do
      {:new_loc, player_name, {new_x, new_y}} ->
        :gen_tcp.send(state.client_socket, "new_location;#{player_name};#{new_x};#{new_y}\n")
    end

    {:noreply, state}
  end

  def handle_info({:tcp, socket, packet}, %@me{client_socket: socket} = state) do
    binary_packet = if String.valid?(packet), do: String.to_charlist(packet), else: packet
    binary_packet |> Enum.drop(-2) |> handle_packet(state)
  end

  def handle_info({:tcp_closed, socket}, %@me{client_socket: socket} = state) do
    IO.inspect("Socket has been closed")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %@me{client_socket: socket} = state) do
    IO.inspect(socket, label: "connection closed due to #{reason}")
    {:stop, :normal, state}
  end

  # #####################################

  defp handle_packet('exit', state), do: {:stop, :normal, state}

  # [login username] callback
  defp handle_packet([108, 111, 103, 105, 110, 32 | username], %@me{username: nil} = state) do
    username = to_string(username)

    case PlayerOperations.log_in(username) do
      {:ok, _} ->
        :ok = PlayerInstance.register_tcp_connection(username, self())
        # Don't like doing things like this, lot of tcp logic mashed together in one module.
        # Think it's normal to have multiple connections. One for general / login logic, one for game logic. Game logic one can be registry name registred and general/ login one can be closed?
        {:ok, _pid} = Registry.register(RaftExampleApp.AppRegistry, {:tcp_handler, username}, nil)
        {:noreply, %{state | username: username}}

      {:error, reason} ->
        Logger.debug(inspect(reason))
        :gen_tcp.send(state.client_socket, "Could not log you in.")
        {:noreply, state}
    end
  end

  defp handle_packet([108, 111, 103, 105, 110, 32 | _username], %@me{username: _u} = state) do
    :gen_tcp.send(state.client_socket, "Already logged in.")
    {:noreply, state}
  end

  # [logout] callback
  defp handle_packet([108, 111, 103, 111, 117, 116], %@me{username: nil} = state) do
    :gen_tcp.send(state.client_socket, "You're not logged in...")
    {:noreply, state}
  end

  defp handle_packet([108, 111, 103, 111, 117, 116], %@me{username: uname} = state) do
    case RaftExampleApp.Player.PlayerOperations.log_out(uname) do
      :ok ->
        Registry.unregister(RaftExampleApp.AppRegistry, {:tcp_handler, state.username})
        {:noreply, %{state | username: nil}}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp handle_packet(packet, %@me{} = state) do
    # TODO: use protobuf here for deserialization
    # This is throwaway code. Ignore this part until protobuf impl is finished.
    if String.valid?(:erlang.list_to_binary(packet)) do
      case to_string(packet) do
        "UP IN" -> PlayerInstance.start_move(state.username, :up)
        "DOWN IN" -> PlayerInstance.start_move(state.username, :down)
        "LEFT IN" -> PlayerInstance.start_move(state.username, :left)
        "RIGHT IN" -> PlayerInstance.start_move(state.username, :right)
        "UP OUT" -> PlayerInstance.stop_move(state.username, :up)
        "DOWN OUT" -> PlayerInstance.stop_move(state.username, :down)
        "LEFT OUT" -> PlayerInstance.stop_move(state.username, :left)
        "RIGHT OUT" -> PlayerInstance.stop_move(state.username, :right)
        invalid -> IO.inspect("Invalid msg #{invalid}")
      end
    else
      IO.inspect(packet)
    end

    {:noreply, state}
  end
end
