defmodule DeliveryLocationServiceWeb.AdminChannel do
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.LocationsManager

  def join("admin:locations", _params, socket) do
    send(self(), {:after_join})
    drivers = LocationsManager.get_list_of_driver_ids
    {:ok, socket |> assign(:drivers, []) |> set_drivers(drivers)}
  end

  def handle_info({:after_join}, socket) do
    #TODO check if being a struct instead of a map affects the sent data
    broadcast(socket, "drivers_location_update", LocationsManager.get_orders_for_all)
  end

  defp set_drivers(socket, drivers) do
    drivers
    |> Enum.map(fn driver_id ->
      DeliveryLocationServiceWeb.Endpoint.subscribe(driver_id)
    end)
  end

end
