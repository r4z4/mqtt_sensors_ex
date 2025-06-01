defmodule MqttSensors.UltrasonicSensor do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub
  alias MqttSensors.Sensor.Hc
  alias MqttSensors.Repo
  @topic "hc_sr04_data"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_hc)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{pid: pid, stream_data: []}

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    IO.puts("Handle Continue Ultrasonic")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/sensor_data_hc_sr04", 1})

    {:noreply, st}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received HCSR04")
    dbg(publish)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # topic = parse_topic(publish)
    time = Calendar.strftime(now, "%y-%m-%d %I:%M:%S %p")
    # topic = publish[:topic]
    {:ok, ins, cms} = parse_string(publish[:payload])

    # GenServer.call(MqttSensors.DhTemperature, :persist_stream)

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, time: time, data: %{ins: ins, cms: cms}}}
    )

    # Store in state to persist when it hits 20. But dont use Schema struct (which is dumb)
    stream_data = %{
      time: now,
      inches: ins,
      centimeters: cms
    }

    # handle_publish(topic, payload, st)
    {:noreply, Map.put(state, :stream_data, [stream_data | state[:stream_data]])}
  end

  def handle_cast(:persist_stream, state) do
    IO.puts("Ultrasonic Persisting Stream")

    # dbg(state[:stream_data])

    Repo.insert_all(Hc, state[:stream_data])

    {:noreply, Map.put(state, :stream_data, [])}
  end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
  end

  # Only getting Inches value for now - which is why two int
  defp parse_string(input_string) do
    case String.split(input_string, ";") do
      [part1, part2] ->
        # [_str, inches] = String.split(part1, ": ")
        # ins = parseInt(int)
        ins = String.split(part1, ": ") |> Enum.at(1) |> parseInt()
        # [_str, centis] = String.split(part2, ": ")
        # cms = parseInt(centis)
        cms = String.split(part2, ": ") |> Enum.at(1) |> parseInt()

        # {:ok, String.split(part1, ": ") |> Enum.at(1) |> parseInt(), String.split(part2, ": ") |> Enum.at(1) |> parseInt())
        {:ok, ins, cms}

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
