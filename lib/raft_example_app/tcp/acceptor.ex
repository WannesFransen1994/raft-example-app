defmodule RaftExampleApp.Tcp.Acceptor do
  use GenServer

  require Logger
  alias RaftExampleApp.TcpHandlerSupervisor
  alias RaftExampleApp.Tcp.Handler

  @me __MODULE__
  @port 4200

  def start_link(args) do
    GenServer.start_link(@me, args, name: @me)
  end

  def init(_args) do
    {:ok, socket} =
      :gen_tcp.listen(@port, [:binary, packet: :line, active: true, reuseaddr: true])

    state = %{socket: socket}
    {:ok, state, {:continue, :accept}}
  end

  def handle_continue(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.socket)

    child_specs = {Handler, [client_socket: client_socket]}
    {:ok, pid} = DynamicSupervisor.start_child(TcpHandlerSupervisor, child_specs)

    :ok = :gen_tcp.controlling_process(client_socket, pid)
    {:noreply, state, {:continue, :accept}}
  end
end
