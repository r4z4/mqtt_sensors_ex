defmodule MqttSensors.SensorServerSupervisor do
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
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
end
