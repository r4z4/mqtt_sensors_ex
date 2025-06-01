defmodule MqttSensors.Sensor.Keypad do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensor_keypad_readings" do
    field :time, :naive_datetime
    field :key, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(keypad, attrs) do
    keypad
    |> cast(attrs, [:time, :key])
    |> validate_required([:time, :key])
  end
end
