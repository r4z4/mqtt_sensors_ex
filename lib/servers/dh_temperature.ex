defmodule MqttSensors.DhTemperature do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub
  alias MqttSensors.Sensors.Dh

  @topic "dh_data"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
    # Process.flag(:trap_exit, true)
  end

  def init([]) do
    interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_dh)
    # dbg(emqtt_opts)
    report_topic = "reports/#{emqtt_opts[:clientid]}/temperature"
    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      pid: pid,
      stream_data: []
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    IO.puts("Handle Continue DH")
    {:ok, _} = :emqtt.connect(pid)
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/sensor_data", 1})

    {:noreply, st}
  end

  # def handle_cast({:publish, topic, data}, st) do
  #   IO.puts("Handle Cast")
  #   topic_map = %{topic: topic}
  #   parsed_topic = parse_topic(topic_map)
  #   dbg(parsed_topic)
  #   ending = Enum.at(parsed_topic, 2)
  #   handle_publish(ending, %{payload: data}, st)
  # end

  def handle_cast(:persist_stream, state) do
    IO.puts("Dh Persisting Stream")
    Repo.insert_all(Dh, state[:stream_data])
    {:noreply, state}
  end

  # publish #=> %{
  #   dup: false,
  #   via: #Port<0.37>,
  #   payload: "Temp: 27.0; Humidity: 54.0",
  #   topic: "esp32/sensor_data",
  #   properties: :undefined,
  #   qos: 0,
  #   retain: false,
  #   packet_id: :undefined,
  #   client_pid: #PID<0.674.0>
  # }

  def handle_info({:publish, publish}, state) do
    IO.puts("Dh Handle Info")
    # dbg(publish)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    time = Calendar.strftime(now, "%y-%m-%d %I:%M:%S %p")
    {:ok, temp, hum} = parse_string(publish[:payload])
    dbg(temp)

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, time: time, data: %{temp: temp, hum: hum}}}
    )

    # Store in state to persist when it hits 20. But dont use Schema struct (which is dumb)
    stream_data = %{
      time: now,
      temp: temp,
      hum: hum
    }

    # handle_publish(parse_topic(publish), publish, st)
    {:noreply, Map.put(state, :stream_data, [stream_data | state[:stream_data]])}
  end

  def handle_info({:DOWN, _, :process, pid, reason}, state) do
    IO.puts("KILLED PROCESS #{pid}, #{reason}, #{state}")
  end

  # defp handle_publish("humidity", %{payload: payload}, st) do
  #   dbg(st[:humidity])
  #   IO.puts("Receiving Humidity")
  #   new_st = %{st | humidity: String.to_integer(payload)}
  #   {:noreply, new_st}
  # end
  #
  # # Cannot test private functions. Test implementation, or make public
  # defp handle_publish(topic, data, st) do
  #   IO.puts("Handling Publish")
  #   dbg(topic)
  #   dbg(data)
  #   # GenServer.cast(SensorsLive, {:publish, data})
  #   time = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d %I:%M:%S %p")
  #
  #   PubSub.broadcast(
  #     MqttSensors.PubSub,
  #     @topic,
  #     {:update, %{topic: @topic, time: time, data: data}}
  #   )
  #
  #   {:noreply, st}
  # end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
  end

  defp parse_string(input_string) do
    case String.split(input_string, ";") do
      [part1, part2] ->
        # [_str, inches] = String.split(part1, ": ")
        # ins = parseInt(int)
        ins = String.split(part1, ": ") |> Enum.at(1) |> parseFloat()
        # [_str, centis] = String.split(part2, ": ")
        # cms = parseInt(centis)
        cms = String.split(part2, ": ") |> Enum.at(1) |> parseFloat()

        # {:ok, String.split(part1, ": ") |> Enum.at(1) |> parseInt(), String.split(part2, ": ") |> Enum.at(1) |> parseInt())
        {:ok, ins, cms}

      _ ->
        {:error, "Invalid string format. Expected 'Temp: X; Hum: Y'"}
    end
  end

  defp parseFloat(str) do
    case String.to_float(str) do
      # Handle cases where conversion fails, default to 0
      # Scaling down
      float_val -> float_val / 10
      nil -> 0
    end
  end
end
