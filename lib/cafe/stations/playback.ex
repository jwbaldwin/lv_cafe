defmodule Cafe.Stations.Playback do
  @moduledoc "The pure playback choice for one position in a station."

  @enforce_keys [:video_id, :position, :start_seconds]
  defstruct [:video_id, :position, :start_seconds]

  @type t :: %__MODULE__{
          video_id: String.t(),
          position: non_neg_integer(),
          start_seconds: non_neg_integer()
        }
end
