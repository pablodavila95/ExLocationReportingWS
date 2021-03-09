defmodule DeliveryLocationServiceWeb.AdminChannel do
  @moduledoc """
  There is only one Channel in this module. admins, since all admins receive the same information.
  Any update from the drivers gets sent to the channel.
  """
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.Locations
  alias DeliveryLocationServiceWeb.Endpoint
  require Logger

  def join("admins:" <> customer_company, %{"adminID" => admin_id}, socket) do

    Logger.info(inspect(socket.assigns.admin_id))
    Logger.info(inspect(admin_id))

    if Integer.to_string(socket.assigns.admin_id) == admin_id do
      send(self(), {:after_join})
      {:ok, socket}
    end

    # send(self(), {:after_join})
    # {:ok, socket}
  end

  def handle_info({:after_join}, socket) do
    Locations.get_orders_for_all()
    |> Enum.each(fn driver_data -> push(socket, "driver_update", Map.from_struct(driver_data)) end)

    {:noreply, socket}
  end

  def handle_in("driver_update", %{"data" => data}, socket) do
    broadcast!(socket, "driver_update", data)
    {:noreply, socket}
  end

  def handle_in("driver_connected", %{"driver_id" => driver_id}, socket) do
    {:reply, :ok, put_new_driver(socket, driver_id)}
  end

  def handle_in("driver_disconnected", %{"driver_id" => driver_id}, socket) do
    Endpoint.unsubscribe("driver:#{driver_id}")
    {:reply, :ok, socket}
  end

  def handle_in("remove_order_from_driver_process", %{"driver_id" => driver_id}, socket) do
    Logger.info("Deleting order from the driver GenServer process #{driver_id}")

    Locations.reset_order(driver_id)
    Locations.reset_restaurant(driver_id)
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
