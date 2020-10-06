defmodule DeliveryLocationServiceWeb.AdminSocket do
  use Phoenix.Socket
  require Logger
  alias DeliveryLocationService.UserValidation

  ## Channels
  channel "admins", DeliveryLocationServiceWeb.AdminChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token, "vsn" => _}, socket) do
    # {:ok, assign(socket, :admin_id, token)}

    case UserValidation.validate(:admin, token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :admin_id, user_id)}

      {:error, _} ->
        Logger.info("Couldn't connect to socket.")
        :error
    end

    # %{"user_id" => user_id, "role_access" => role_access} = UserValidation.user_json(token)

    # if role_access == "SUPER_ADMIN" or role_access == "ADMIN_COMPANY" do
    #   {:ok, assign(socket, :admin_id, user_id)}
    # else
    #   :error
    # end

    # Refactor so it looks like traditional Phoenix auth validation
    # case Phoenix.Token.verify(socket, "player auth", token, max_age: 86400) do
    #   {:ok, player} ->
    #     {:ok, assign(socket, :current_player, player)}
    #   {:error, _reason} ->
    #     :error
    # end
  end

  def connect(_params, _socket), do: :error
  # def connect(_params, socket, _connect_info) do
  #  {:ok, socket}
  # end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     DeliveryLocationServiceWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil

  # Terminate with
  # DeliveryLocationServiceWeb.Endpoint.broadcast("driver_socket:#{driver.id}", "disconnect", %{})
end
