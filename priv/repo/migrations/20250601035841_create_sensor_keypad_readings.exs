defmodule MqttSensors.Repo.Migrations.CreateSensorKeypadReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_keypad_readings) do
      add :time, :naive_datetime
      add :key, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
