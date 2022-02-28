defmodule DistributedCalculator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias DistributedCalculator.{CalculatorsSupervisor, CalculatorsRegistry}

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: DistributedCalculator.Worker.start_link(arg)
      # {DistributedCalculator.Worker, arg}
      {DynamicSupervisor, strategy: :one_for_one, name: CalculatorsSupervisor},
      {Registry, keys: :unique, name: CalculatorsRegistry}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DistributedCalculator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
