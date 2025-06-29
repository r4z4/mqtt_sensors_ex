defmodule MqttSensors.LD2410 do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  # @topic "mmWave"
  @topic "ld2410"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_ld2410)
    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      timer: nil,
      pid: pid
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    IO.puts("Handle Continue LD2410")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/ld2410", 1})

    {:noreply, state}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received LD2410")
    dbg(publish)
    # topic = parse_topic(publish)
    # time = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d %I:%M:%S %p")
    # topic = publish[:topic]
    {:ok, mv, dist, energy} = parse_string(publish[:payload])

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: %{mv: mv, dist: dist, energy: energy}}}
    )

    # handle_publish(topic, payload, st)
    {:noreply, state}
  end

  # "Mv: %d; Dist: %d; Energy: %d"

  # defp parse_topic(%{topic: topic}) do
  #   String.split(topic, "/", trim: true)
  # end

  defp parse_string(input_string) do
    case String.split(input_string, "; ") do
      [part1, part2, part3] ->
        mv = String.split(part1, ": ") |> Enum.at(1) |> parseInt()
        dist = String.split(part2, ": ") |> Enum.at(1) |> parseInt()
        energy = String.split(part3, ": ") |> Enum.at(1) |> parseInt()
        # {:ok, 
        #   String.split(part1, ": ") |> Enum.at(1) |> parseInt(), 
        #   String.split(part2, ": ") |> Enum.at(1) |> parseInt(), 
        #   String.split(part3, ": ") |> Enum.at(1) |> parseInt()
        # }
        {:ok, mv, dist, energy}

      _ ->
        {:error, "Invalid string format. Expected 'Mv: %d; Dist: %d; Energy: %d'"}
    end
  end

  defp parseInt(str) do
    case String.to_integer(str) do
      # Handle cases where conversion fails, default to 0
      integer_val -> integer_val
      nil -> 0
    end
  end
end
