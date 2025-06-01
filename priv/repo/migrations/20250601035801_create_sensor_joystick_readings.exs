defmodule MqttSensors.Repo.Migrations.CreateSensorJoystickReadings do
  use Ecto.Migration

  def change do
    create table(:sensor_joystick_readings) do
      add :time, :naive_datetime
      add :x_pos, :integer
      add :y_pos, :integer
      add :btn_pressed, :boolean, default: false, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
