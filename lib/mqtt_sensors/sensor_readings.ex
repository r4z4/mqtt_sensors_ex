defmodule MqttSensors.SensorReadings do
  @moduledoc false
  # This is Unused, but keeping for :tick e.g.
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    interval = Application.get_env(:mqtt_sensors, :interval)
    # dbg(interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_dh)
    dbg(emqtt_opts)
    report_topic = "reports/#{emqtt_opts[:clientid]}/temperature"
    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    st = %{
      interval: interval,
      timer: nil,
      report_topic: report_topic,
      pid: pid,
      humidity: nil
    }

    dbg(st)

    {:ok, set_timer(st), {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_dh)
    clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"commands/#{clientid}/humidity", 1})
    {:ok, _, _} = :emqtt.subscribe(pid, {"commands/#{clientid}/set_interval", 1})
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/sensor_data", 1})
    {:noreply, st}
  end

  def handle_cast({:publish, topic, data}, st) do
    IO.puts("Handle Cast")
    topic_map = %{topic: topic}
    parsed_topic = parse_topic(topic_map)
    dbg(parsed_topic)
    ending = Enum.at(parsed_topic, 2)
    handle_publish(ending, %{payload: data}, st)
  end

  def handle_info(:tick, %{report_topic: topic, pid: pid} = st) do
    report_temperature(pid, topic)
    {:noreply, set_timer(st)}
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

  # Have to receive from one PID. Receive each, then cast based on topic, then(
  # GenServers can take it from there

  def handle_info({:publish, publish}, st) do
    IO.puts("Handle Info")
    dbg(publish)
    _topic = publish[:topic]
    # if topic == "esp32/sensor_data"
    #   # GenServer.cast()
    # end
    # if topic == "esp32/sensor_data_hc_sr04"
    #   # GenServer.cast()
    # end
    handle_publish(parse_topic(publish), publish, st)
  end

  defp handle_publish(["commands", _, "set_interval"], %{payload: payload}, st) do
    IO.puts("Received Payload")
    new_st = %{st | interval: String.to_integer(payload)}
    {:noreply, set_timer(new_st)}
  end

  defp handle_publish("humidity", %{payload: payload}, st) do
    dbg(st[:humidity])
    IO.puts("Receiving Humidity")
    new_st = %{st | humidity: String.to_integer(payload)}
    {:noreply, new_st}
  end

  # data #=> %{
  #   dup: false,
  #   via: #Port<0.36>,
  #   payload: "Temp: 27.0; Humidity: 53.0",
  #   topic: "esp32/sensor_data",
  #   properties: :undefined,
  #   qos: 0,
  #   retain: false,
  #   packet_id: :undefined,
  #   client_pid: #PID<0.674.0>
  # }
  defp handle_publish(topic, data, st) do
    IO.puts("Handling Publish")
    dbg(topic)
    dbg(data)
    {:noreply, st}
  end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
  end

  defp set_timer(st) do
    if st.timer do
      Process.cancel_timer(st.timer)
    end

    timer = Process.send_after(self(), :tick, st.interval)
    %{st | timer: timer}
  end

  defp report_temperature(pid, topic) do
    temperature = 10.0 + 2.0 * :rand.normal()
    message = {System.system_time(:millisecond), temperature}
    payload = :erlang.term_to_binary(message)
    dbg(payload)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    client_id = emqtt_opts[:clientid]
    :emqtt.publish(pid, topic, payload)
    GenServer.cast(self(), {:publish, "commands/#{client_id}/humidity", "44"})
  end
end
