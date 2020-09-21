defmodule DeliveryLocationServiceWeb.AdminChannel do
  @moduledoc """
  There is only one Channel in this module. admins, since all admins receive the same information.
  Any update from the drivers gets sent to the channel.
  """
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.LocationsHelper
  alias DeliveryLocationServiceWeb.Presence

  def join("admins", _params, socket) do
    send(self(), {:after_join})
    {:ok, socket}
  end

  def handle_info({:after_join}, socket) do
    LocationsHelper.get_orders_for_all()
    |> Enum.each(fn driver_data -> push(socket, "driver_update", Map.from_struct(driver_data)) end)

    {:noreply, socket}
  end

  def handle_in("driver_update", %{"data" => data}, socket) do
    # Or send all the orders with LocationHelper.get_orders_for_all?
    # If I do that I don't have to send the data, but it might use more bandwidth since it's a complete update
    # This is only one
    broadcast!(socket, "driver_update", data)
    {:noreply, socket}
  end
end
