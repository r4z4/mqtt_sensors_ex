# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Load ENV var script
if config_env() in [:dev, :test] do
  import_config ".env.exs"
end

mqtt_username = System.get_env("MQTT_USERNAME")
mqtt_password = System.get_env("MQTT_PASSWORD")
# Phone IP - Or whatever Broker is
mqtt_host = System.get_env("MQTT_HOST")
mqtt_port = 1883

config :mqtt_sensors,
  ecto_repos: [MqttSensors.Repo],
  generators: [timestamp_type: :utc_datetime]

config :mqtt_sensors, :emqtt_dh,
  host: mqtt_host,
  port: mqtt_port,
  clientid: "sensor_readings",
  clean_start: false,
  username: mqtt_username,
  password: mqtt_password,
  name: :emqtt_dh

config :mqtt_sensors, :emqtt_hc,
  host: mqtt_host,
  port: mqtt_port,
  clientid: "sensor_readings_ultrasonic",
  clean_start: false,
  username: mqtt_username,
  password: mqtt_password,
  name: :emqtt_hc

config :mqtt_sensors, :emqtt_keypad,
  host: mqtt_host,
  port: mqtt_port,
  clientid: "sensor_readings_keypad",
  clean_start: false,
  username: mqtt_username,
  password: mqtt_password,
  name: :emqtt_keypad

config :mqtt_sensors, :emqtt_photoresistor,
  host: mqtt_host,
  port: mqtt_port,
  clientid: "sensor_readings_photoresistor",
  clean_start: false,
  username: mqtt_username,
  password: mqtt_password,
  name: :emqtt_photoresistor

config :mqtt_sensors, :interval, 1000

# Configures the endpoint
config :mqtt_sensors, MqttSensorsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MqttSensorsWeb.ErrorHTML, json: MqttSensorsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MqttSensors.PubSub,
  live_view: [signing_salt: "onlfC6jr"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mqtt_sensors, MqttSensors.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  mqtt_sensors: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  mqtt_sensors: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
