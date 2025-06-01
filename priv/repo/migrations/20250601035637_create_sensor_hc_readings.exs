defmodule MqttSensors.Repo.Migrations.CreateSensorHcReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_hc_readings) do
      add :time, :naive_datetime
      add :inches, :integer
      add :centimeters, :integer
      add :created_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
