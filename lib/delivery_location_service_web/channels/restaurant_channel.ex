defmodule DeliveryLocationServiceWeb.RestaurantChannel do
  @moduledoc """
  This module provides the channel for a restaurant that will monitor orders assigned to it.
  """
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationsHelper
  alias DeliveryLocationServiceWeb.Endpoint
  require Logger

  def join("restaurant:" <> restaurant_id, _params, socket) do
    Logger.info(inspect(socket.assigns.restaurant_id))
    Logger.info(inspect(restaurant_id))

    if Integer.to_string(socket.assigns.restaurant_id) == restaurant_id do
      send(self(), {:after_join})
      {:ok, socket |> assign(:drivers, []) |> assign(:restaurant_id, restaurant_id)}
    end
  end

  def handle_info({:after_join}, socket) do
    "restaurant:" <> restaurant_id = socket.topic

    LocationsHelper.get_orders_for(restaurant_id)
    |> Enum.map(fn driver_data -> driver_data.driver_id end)
    |> Enum.each(fn driver_id ->
      Endpoint.broadcast!("driver:#{driver_id}", "subscription_request", %{
        restaurant_id: restaurant_id
      })
    end)

    {:noreply, socket}
  end

  def handle_in("driver_delivering", %{"driver_id" => driver_id}, socket) do
    {:reply, :ok, put_new_driver(socket, driver_id)}
  end

  def handle_in("driver_update", %Location{} = location_data, socket) do
    push(socket, "driver_update", Map.from_struct(location_data))
    {:noreply, socket}
  end

  def handle_in("finished_delivering", %{"driver_id" => driver_id}, socket) do
    Endpoint.unsubscribe("driver:#{driver_id}")
    {:reply, :ok, socket}
  end

  def handle_in("notify_new_order", %{"order_details" => order_details}, socket) do
    Endpoint.broadcast!("notifications", "notify_drivers", order_details)
    {:noreply, socket}
  end

  defp put_new_driver(socket, driver) do
    Enum.reduce(driver, socket, fn driver, acc ->
      drivers = acc.assigns.drivers

      if driver in drivers do
        acc
      else
        :ok = Endpoint.subscribe("driver:#{driver}")
        assign(acc, :topics, [driver | drivers])
      end
    end)
  end
end
