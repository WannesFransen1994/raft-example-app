defmodule RaftExampleApp.Player.PlayerInstance do
  use GenServer
  @me __MODULE__

  alias RaftExampleApp.AppRegistry

  defstruct location: {1, 1}

  def start_link(args) do
    case args[:player_name] do
      nil -> {:error, {:missing_option, :player_name}}
      player_name -> GenServer.start_link(@me, :ignore_args, name: via_tuple(player_name))
    end
  end

  def init(:ignore_args) do
    # Optional: restore location

    {:ok, %@me{}}
  end

  defp via_tuple(player_name) do
    {:via, Registry, {AppRegistry, {:player_instance, player_name}}}
  end
end

# INBOUND DATA DIAGRAM

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
