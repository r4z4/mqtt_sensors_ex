defmodule SensorsTest do
  use ExUnit.Case
  import Plug.Conn
  import Phoenix.ConnTest
  use MqttSensorsWeb.ConnCase

  @endpoint MqttSensorsWeb.Endpoint
  setup :register_and_log_in_user

  test "says welcome on the home page" do
    conn = get(build_conn(), "/")
    assert conn.status == 200
  end

  # test "logs in" do
  #   conn = post(build_conn(), "/users/log_in", username: "admin", password: "password")
  #   assert conn.status == 200
  # end

  test "truth" do
    assert 1 + 1 == 2
  end

  test "handle_publish" do
    # MqttSensors.DhTemperature.start_link([])

    res =
      MqttSensors.DhTemperature.handle_info(
        {:publish, %{topic: "topic", data: %{}, time: "2022-02-22T12:12:12"}},
        {}
      )

    assert res = {}
  end
end
