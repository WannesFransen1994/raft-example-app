defmodule RaftExampleApp.Application do
  use Application

  alias RaftExampleApp.{AppRegistry, PlayerSupervisor, TcpHandlerSupervisor}

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: AppRegistry},
      RaftExampleApp.AreaSupervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: PlayerSupervisor},
      # {Task.Supervisor, name: RaftExampleApp.TcpAcceptorTaskSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: TcpHandlerSupervisor},
      {RaftExampleApp.Tcp.Acceptor, []}
    ]

    opts = [strategy: :one_for_one, name: RaftExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
