defmodule MqttSensors.Repo.Migrations.CreateSensorDhReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_dh_readings) do
      add :time, :naive_datetime
      add :humidity, :float
      add :temperature, :float

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
