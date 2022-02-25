defmodule RaftExampleApp.Player.PlayerOperations do
  alias RaftExampleApp.Player.PlayerInstance
  alias RaftExampleApp.{PlayerSupervisor, AppRegistry}

  def log_in(player_name) do
    child_spec = {PlayerInstance, [player_name: player_name]}

    case DynamicSupervisor.start_child(PlayerSupervisor, child_spec) do
      {:error, {:already_started, _}} -> {:error, :already_logged_in}
      {:error, reason} -> {:error, reason}
      success -> success
    end
  end

  def log_out(player_name) do
    PlayerInstance.log_out(player_name)
  end

  def list_logged_in_players() do
    Registry.select(AppRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
