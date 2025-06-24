defmodule MqttSensors.Rotary do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  @topic "rotary_encoder"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    # interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_rotary)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      timer: nil,
      pid: pid
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    IO.puts("Handle Continue Rotary")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/rotary_encoder", 1})

    {:noreply, state}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received Rotary")
    dbg(publish)
    # topic = parse_topic(publish)
    time = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d %I:%M:%S %p")
    # topic = publish[:topic]
    # "Counter: %d; Dir: %u; Btn: %u"
    {:ok, ctr, dir, btn} = parse_string(publish[:payload])
    dbg(publish[:payload])

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: %{ctr: ctr, dir: dir, btn: btn}}}
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
        ctr = String.split(part1, ": ") |> Enum.at(1) |> parseInt()
        # [_str, centis] = String.split(part2, ": ")
        # cms = parseInt(centis)
        dir = String.split(part2, ": ") |> Enum.at(1) |> parseInt()
        btn = String.split(part3, ": ") |> Enum.at(1) |> parseInt()

        # {:ok, String.split(part1, ": ") |> Enum.at(1) |> parseInt(), String.split(part2, ": ") |> Enum.at(1) |> parseInt())
        {:ok, ctr, dir, btn}

      _ ->
        {:error, "Invalid string format. Expected 'In: X; Cm: Y'"}
    end
  end

  defp parseInt(str) do
    case String.to_integer(str) do
      # Handle cases where conversion fails, default to 0
      integer_val -> integer_val
      nil -> 0
    end
  end

  # defp handle_publish("esp32/sensor_data_hc_sr04", payload, st) do
  #   dbg(payload)
  #   IO.puts("Receiving Humidity")
  #   new_st = %{st | distance: parse_ultrasonic_payload(payload)}
  #   {:noreply, new_st}
  # end
  #
  # defp parse_ultrasonic_payload(payload) do
  #   IO.puts("Parsing Ultrasonic Payload")
  #   dbg(payload)
  #   "fake_payload"
  # end

  # Likely do not need this
  # defp set_timer(st) do
  #   if st.timer do
  #     Process.cancel_timer(st.timer)
  #   end
  #
  #   timer = Process.send_after(self(), :tick, st.interval)
  #   %{st | timer: timer}
  # end
end
