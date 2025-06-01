defmodule MqttSensors.Repo.Migrations.CreateSensorKeypadReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_keypad_readings) do
      add :time, :naive_datetime
      add :key, :string
      add :created_at, :utc_datetime, default: fragment("now()")
    end
  end
end
