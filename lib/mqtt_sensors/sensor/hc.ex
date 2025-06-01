defmodule MqttSensors.Sensor.Hc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensor_hc_readings" do
    field :time, :naive_datetime
    field :inches, :integer
    field :centimeters, :integer

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(hc, attrs) do
    hc
    |> cast(attrs, [:time, :inches, :centimeters])
    |> validate_required([:time, :inches, :centimeters])
  end
end
