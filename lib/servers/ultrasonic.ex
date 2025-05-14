defmodule MqttSensors.UltrasonicSensor do
  @moduledoc false

  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_hc)
    # Connect as different client? Can I connect as same client?
    # emqtt_opts[:clientid] = "ultrasonic_client"
    # report_topic = "reports/#{emqtt_opts[:clientid]}/temperature"
    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    st = %{
      interval: interval,
      timer: nil,
      pid: pid,
      distance: nil
    }

    {:ok, st, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/sensor_data_hc_sr04", 1})
    {:noreply, st}
  end

  def handle_info({:publish, publish}, st) do
    IO.puts("Received Message")
    dbg(publish)
    topic = publish[:topic]
    payload = publish[:payload]
    handle_publish(topic, payload, st)
  end

  defp handle_publish("esp32/sensor_data_hc_sr04", payload, st) do
    dbg(payload)
    IO.puts("Receiving Humidity")
    new_st = %{st | distance: parse_ultrasonic_payload(payload)}
    {:noreply, new_st}
  end

  defp parse_ultrasonic_payload(payload) do
    IO.puts("Parsing Ultrasonic Payload")
    dbg(payload)
    "fake_payload"
  end

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
