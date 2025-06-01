defmodule MqttSensors.Repo.Migrations.CreateSensorDhReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_dh_readings) do
      add :time, :naive_datetime
      add :humidity, :float
      add :temperature, :float
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
