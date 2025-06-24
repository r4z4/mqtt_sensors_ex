defmodule MqttSensors.Rgb do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  @topic "rgb"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    # interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_rgb)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      timer: nil,
      pid: pid
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    IO.puts("Handle Continue RGB")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/rgb", 1})

    {:noreply, state}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received RGB")
    dbg(publish)
    {:ok, r, g, b} = parse_string(publish[:payload])
    dbg(publish[:payload])

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: %{r: r, g: g, b: b}}}
    )

    # handle_publish(topic, payload, st)
    {:noreply, state}
  end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
  end

  defp parse_string(input_string) do
    case String.split(input_string, ";") do
      [part1, part2, part3] ->
        # [_str, inches] = String.split(part1, ": ")
        # ins = parseInt(int)
        r = String.split(part1, ": ") |> Enum.at(1) |> parseInt()
        # [_str, centis] = String.split(part2, ": ")
        # cms = parseInt(centis)
        g = String.split(part2, ": ") |> Enum.at(1) |> parseInt()
        b = String.split(part3, ": ") |> Enum.at(1) |> parseInt()

        # {:ok, String.split(part1, ": ") |> Enum.at(1) |> parseInt(), String.split(part2, ": ") |> Enum.at(1) |> parseInt())
        {:ok, r, g, b}

      _ ->
        {:error, "Invalid string format. Expected 'r: r; g: g; b: b'"}
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
