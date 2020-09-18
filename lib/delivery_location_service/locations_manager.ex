defmodule DeliveryLocationService.LocationsManager do
  alias DeliveryLocationService.Locationerver
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationSupervisor

  def get_orders_for_all do
    all_current_drivers = Supervisor.which_children(LocationSupervisor)
    |> Enum.map(fn driver ->
      {_, pid, _, _} = driver
      :sys.get_state(pid)
    end)
  end

  def get_list_of_driver_ids do
    all_orders = get_orders_for_all
    |> Enum.map(fn location_data -> location_data.driver_id)
  end

  def get_orders_for(restaurant_id) when is_nil(restaurant_id) == false do
    get_orders_for_all
    |> Enum.filter(fn location_data ->
      Location.is_owned_by_restaurant?(location_data, restaurant_id) == true
    end)
  end

  def reset_restaurant(driver_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, nil)
    :ok
  end

  def set_restaurant(driver_id, restaurant_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, restaurant_id)
  end

  def update_coordinates(driver_id, new_coordinates) do
    DeliveryLocationServicel.LocationServer.update_coordinates(driver_id, new_coordinates)
  end
end
