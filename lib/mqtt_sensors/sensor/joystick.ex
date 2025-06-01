defmodule MqttSensors.Sensor.Joystick do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensor_joystick_readings" do
    field :time, :naive_datetime
    field :x_pos, :integer
    field :y_pos, :integer
    field :btn_pressed, :boolean, default: false

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(joystick, attrs) do
    joystick
    |> cast(attrs, [:time, :x_pos, :y_pos, :btn_pressed])
    |> validate_required([:time, :x_pos, :y_pos, :btn_pressed])
  end
end
