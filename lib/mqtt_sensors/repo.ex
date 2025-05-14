defmodule MqttSensors.Repo do
  use Ecto.Repo,
    otp_app: :mqtt_sensors,
    adapter: Ecto.Adapters.Postgres
end
