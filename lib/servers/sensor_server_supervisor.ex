defmodule MqttSensors.SensorServerSupervisor do
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    schedule_try_restart()
    # for start_number <- start_numbers do
    #   # We can't just use `{OurNewApp.Counter, start_number}`
    #   # because we need different ids for children
    #
    #   Supervisor.child_spec({OurNewApp.Counter, start_number}, id: start_number)
    # end
    children =
      [
        Supervisor.child_spec({MqttSensors.DhTemperature, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.KeypadSensor, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.UltrasonicSensor, []}, restart: :temporary)
      ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Periodically attempt to restart MQTT children if not started (Broker down)
  def handle_info(:try_restart, state) do
    %{active: active, workers: _workers, supervisors: _sups, specs: _specs} =
      Supervisor.count_children(self())

    cond do
      # TODO: Start whichever one(s) not there
      active == 3 ->
        IO.puts("All chlidren are active")

      active > 0 and active < 3 ->
        list = Supervisor.which_children(self())
        started = Enum.map(list, fn {name, _pid, _type, _list} -> name end)

      active == 0 ->
        Supervisor.start_child(MqttSensors.SensorServerSupervisor, MqttSensors.KeypadSensor)
        Supervisor.start_child(MqttSensors.SensorServerSupervisor, MqttSensors.DhTemperature)
        Supervisor.start_child(MqttSensors.SensorServerSupervisor, MqttSensors.UltrasonicSensor)
    end

    {:noreply, state}
  end

  defp schedule_try_restart do
    # Check every 5 minutes
    Process.send_after(self(), :try_restart, 300_000)
  end
end
