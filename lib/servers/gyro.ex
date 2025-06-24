defmodule MqttSensors.Gyro do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  @topic "gyro"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    # interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_gyro)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      timer: nil,
      pid: pid,
      cnt: 0
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    IO.puts("Handle Continue Rotary")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/gyro", 1})

    {:noreply, state}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received Gyro")
    dbg(publish)
    # topic = parse_topic(publish)
    time = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d %I:%M:%S %p")
    # topic = publish[:topic]
    # "Counter: %d; Dir: %u; Btn: %u"
    # {:ok, ctr, dir, btn} = parse_string(publish[:payload])
    # dbg(publish[:payload])

    new_state = Map.put(state, :cnt, state.cnt + 1)

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: %{id: new_state.cnt, data: publish[:payload]}}}
    )

    # handle_publish(topic, payload, st)
    {:noreply, new_state}
  end

  #   snprintf(full_message, sizeof(full_message), "AcX:%ld;AcY:%ld;AcZ:%ld||GyX:%ld;GyY:%ld;GyZ:%ld", AcX, AcY, AcZ, GyX, GyY, GyZ);
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
        {:error,
         "Invalid string format. Expected 'AcX:%ld;AcY:%ld;AcZ:%ld||GyX:%ld;GyY:%ld;GyZ:%ld'"}
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
