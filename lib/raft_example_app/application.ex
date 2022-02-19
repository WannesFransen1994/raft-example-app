defmodule RaftExampleApp.Application do
  use Application

  alias RaftExampleApp.{AppRegistry, PlayerSupervisor}

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: AppRegistry},
      RaftExampleApp.AreaSupervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: PlayerSupervisor}
    ]

    opts = [strategy: :one_for_one, name: RaftExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
