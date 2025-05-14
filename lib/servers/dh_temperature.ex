defmodule MqttSensors.DhTemperature do
  @moduledoc false

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

    {:ok, st, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    {:ok, _} = :emqtt.connect(pid)
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
    handle_publish(parse_topic(publish), publish, st)
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
end
