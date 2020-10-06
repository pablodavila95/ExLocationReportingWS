defmodule DeliveryLocationServiceWeb.DriverNotifications do
  use DeliveryLocationServiceWeb, :channel
  require Logger

  def join("notifications", _params, socket) do
    send(self(), {:after_join})
    {:ok, socket}
  end

  def handle_info({:after_join}, socket) do
    Logger.info("Connected succesfully to notifications channel.")
    push(socket, "logs", %{msg: "Connected succesfully to notifications channel."})
    {:noreply, socket}
  end

  def handle_in("notify_drivers", order, socket) do
    broadcast(socket, "new_order", order)
    {:noreply, socket}
  end

end
