defmodule DeliveryLocationService.LocationsHelper do
  @moduledoc """
  Provides a set of helper functions to work with the Location GenServer's state.
  """
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationServer
  alias DeliveryLocationService.LocationSupervisor

  def get_orders_for_all do
    Supervisor.which_children(LocationSupervisor)
    |> Enum.map(fn driver ->
      {_, pid, _, _} = driver
      :sys.get_state(pid)
    end)
  end

  def get_list_of_driver_ids do
    get_orders_for_all()
    |> Enum.map(fn location_data -> location_data.driver_id end)
  end

  def get_orders_for(restaurant_id) when is_nil(restaurant_id) == false do
    get_orders_for_all()
    |> Enum.filter(fn location_data ->
      Location.is_owned_by_restaurant?(location_data, restaurant_id) == true
    end)
  end

  def is_delivering?(driver_id) do
    LocationServer.view(driver_id)
    |> Map.get(:restaurant_id) != nil
  end

  #TODO use the following functions in the DriverChannel

  def reset_restaurant(driver_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, nil)
    :ok
  end

  def set_restaurant(driver_id, restaurant_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, restaurant_id)
  end

  def reset_order(driver_id) do
    DeliveryLocationService.LocationServer.update_order(driver_id, nil)
  end

  def set_order(driver_id, order_id) do
    DeliveryLocationService.LocationServer.update_order(driver_id, order_id)
  end
end
