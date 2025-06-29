defmodule MqttSensors.SensorSupervisor do
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children =
      [
        Supervisor.child_spec({MqttSensors.DhTemperature, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.KeypadSensor, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.Joystick, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.Rotary, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.Photoresistor, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.Rgb, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.IrReceiver, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.Gyro, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.LD2410, []}, restart: :temporary),
        Supervisor.child_spec({MqttSensors.UltrasonicSensor, []}, restart: :temporary)
      ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Periodically attempt to restart MQTT children if not started (Broker down)
  # def handle_info(:try_restart, state) do
  #   IO.puts("Checking GenServer Children")
  #
  #   %{active: active, workers: _workers, supervisors: _sups, specs: _specs} =
  #     Supervisor.count_children(self())
  #
  #   cond do
  #     # TODO: Start whichever one(s) not there
  #     active == 3 ->
  #       IO.puts("All chlidren are active")
  #
  #     active > 0 and active < 3 ->
  #       IO.puts("#{active} Children Started")
  #       list = Supervisor.which_children(self())
  #       started = Enum.map(list, fn {name, _pid, _type, _list} -> name end)
  #
  #     active == 0 ->
  #       Supervisor.start_child(__MODULE__, MqttSensors.KeypadSensor)
  #       Supervisor.start_child(__MODULE__, MqttSensors.DhTemperature)
  #       Supervisor.start_child(__MODULE__, MqttSensors.UltrasonicSensor)
  #   end
  #
  #   {:noreply, state}
  # end
end
