defmodule MqttSensors.IrReceiver do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub

  @topic "ir"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt_ir)

    {:ok, pid} = :emqtt.start_link(emqtt_opts)

    st = %{
      timer: nil,
      pid: pid
    }

    {:ok, st, {:continue, :start_emqtt}}
  end

  def handle_continue(:start_emqtt, %{pid: pid} = st) do
    IO.puts("Handle Continue IR")
    {:ok, _} = :emqtt.connect(pid)
    # IO.puts("Handle Continue on Start")
    emqtt_opts = Application.get_env(:mqtt_sensors, :emqtt)
    _clientid = emqtt_opts[:clientid]
    {:ok, _, _} = :emqtt.subscribe(pid, {"esp32/ir", 1})

    {:noreply, st}
  end

  def handle_info({:publish, publish}, state) do
    IO.puts("Received IR")
    dbg(publish)

    # Convert payload to key symbol

    PubSub.broadcast(
      MqttSensors.PubSub,
      @topic,
      {:update, %{topic: @topic, data: publish[:payload]}}
    )

    {:noreply, state}
  end

  defp parse_topic(%{topic: topic}) do
    String.split(topic, "/", trim: true)
  end
end
