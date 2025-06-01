defmodule MqttSensors.Sensor.Dh do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensor_dh_readings" do
    field :time, :naive_datetime
    field :humidity, :float
    field :temperature, :float

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(dh, attrs) do
    dh
    |> cast(attrs, [:time, :humidity, :temperature])
    |> validate_required([:time, :humidity, :temperature])
  end
end
