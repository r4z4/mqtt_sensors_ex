defmodule MqttSensorsWeb.ErrorJSONTest do
  use MqttSensorsWeb.ConnCase, async: true

  test "renders 404" do
    assert MqttSensorsWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert MqttSensorsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
