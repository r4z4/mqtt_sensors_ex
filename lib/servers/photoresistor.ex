defmodule MqttSensors.Photoresistor do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  @topic "photoresistor"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    # interval = Application.get_env(:mqtt_sensors, :interval)
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_photoresistor)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    state = %{
      timer: nil,
      pid: pid
    }

    {:ok, state, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    IO.puts("Handle Continue Keypad")
    {:ok, _} = :emqtt.connect(pid)
    IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/photoresistor", 1})

    {:noreply, state}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received Photoresistor")
    dbg(publish)
    # topic = parse_topic(publish)
    time = Calendar.strftime(DateTime.utc_now(), "%y-%m-%d %I:%M:%S %p")
    # topic = publish[:topic]
    {int, _rest} = Integer.parse(publish[:payload])

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: int}}
    )

    # handle_publish(topic, payload, st)
    {:noreply, state}
  end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
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
