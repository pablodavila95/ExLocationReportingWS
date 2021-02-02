defmodule DeliveryLocationService.UserValidation do
  require Logger

  defp backend_verify do
    api_url = System.get_env("API_URL") || "https://delivery.aztlansoft.com"
    api_url <> "/verify/token"
  end

  def validate(user_role, token) do
    available_roles = %{
      admin: ["SUPER_ADMIN", "ADMIN_COMPANY"],
      driver: ["DRIVER"],
      restaurant: ["RESTAURANT"],
      test: [nil]
    }

    roles = Map.get(available_roles, user_role)
    Logger.info("Validating with any of these roles: #{roles}")

    case user_json(token) do
      %{"user_id" => user_id, "role_access" => role_access, "customer_company" => customer_company} ->
        case Enum.member?(roles, role_access) do
          true -> {:ok, %{user_id: user_id, customer_company: customer_company}}
          false -> {:error, "Role is not valid."}
        end

      %{"user_id" => user_id, "role_access" => role_access} ->
        case Enum.member?(roles, role_access) do
          true -> {:ok, user_id}
          false -> {:error, "Role is not valid."}
        end

      error ->
        error
    end
  end


  def user_json(token) do
    # TODO fix validation. A reply might be :ok but not have the stuff I need
    case Peppermint.get(backend_verify(), params: %{cookie2: token}) do
      {:ok, %{status: 200, headers: _headers, body: body}} ->
        %{"data" => data} = Jason.decode!(body)

        Logger.info(inspect(data))
        extract(data)

      response ->
        {:error, response}
    end
  end

  defp extract(data) do
    # Roles: SUPER_ADMIN | ADMIN_COMPANY | RESTAURANT | DRIVER

    case Map.get(data, "customerClient") do
      nil ->
        %{"id" => user_id, "roleAccess" => role_access, "customerCompany" => %{"id" => customer_company}} = data
        %{"user_id" => user_id, "role_access" => role_access, "customer_company" => customer_company}

      _ ->
        %{"roleAccess" => role_access, "customerClient" => %{"id" => user_id}} = data
        %{"user_id" => user_id, "role_access" => role_access}
    end
  end
end
