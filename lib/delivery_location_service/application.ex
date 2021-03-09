defmodule DeliveryLocationService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: DeliveryLocationService.LocationRegistry},
      DeliveryLocationService.LocationSupervisor,
      # Start the Telemetry supervisor
      DeliveryLocationServiceWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: DeliveryLocationService.PubSub},
      # Start the Endpoint (http/https)
      DeliveryLocationServiceWeb.Endpoint,
      DeliveryLocationServiceWeb.Presence,
      # Start a worker by calling: DeliveryLocationService.Worker.start_link(arg)
      # {DeliveryLocationService.Worker, arg}
    ]

    :ets.new(:locations_table, [:public, :named_table, :set, read_concurrency: true, write_concurrency: true])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DeliveryLocationService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DeliveryLocationServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
