defmodule DeliveryLocationService.UserValidation do
  defp backend_verify() do
    api_url = System.get_env("API_URL") || "https://localhost:9000"
    api_url <> "/verify/token"
  end

  def validate(:admin, token) do
    roles = ["SUPER_ADMIN", "ADMIN_COMPANY"]
    %{"user_id" => user_id, "role_access" => role_access} = user_json(token)

    case Enum.member?(roles, role_access) do
      true -> {:ok, user_id}
      false -> {:error, "Role is not valid."}
    end
  end

  def validate(:driver, token) do
    roles = ["DRIVER"]
    %{"user_id" => user_id, "role_access" => role_access} = user_json(token)

    case Enum.member?(roles, role_access) do
      true -> {:ok, user_id}
      false -> {:error, "Role is not valid."}
    end
  end

  def validate(:restaurant, token) do
    roles = ["RESTAURANT"]
    %{"user_id" => user_id, "role_access" => role_access} = user_json(token)

    case Enum.member?(roles, role_access) do
      true -> {:ok, user_id}
      false -> {:error, "Role is not valid."}
    end
  end

  defp user_json(token) do
    # TODO fix validation. A reply might be :ok but not have the stuff I need
    {:ok, %{status: 200, headers: _headers, body: body}} =
      Peppermint.get(backend_verify(), params: %{cookie2: token})

    %{"data" => data} = Jason.decode!(body)
    extract(data)
  end

  defp extract(data) do
    # Roles: SUPER_ADMIN | ADMIN_COMPANY | RESTAURANT | DRIVER

    # case Map.get(data, "customerCompany") do
    #   nil ->
    #     %{"roleAccess" => role_access, "customerCompany" => %{"id" => user_id}} = data
    #     %{"user_id" => user_id, "role_access" => role_access}

    #   _ ->
    #     %{"id" => user_id, "roleAccess" => role_access} = data
    #     %{"user_id" => user_id, "role_access" => role_access}
    # end

    if Map.get(data, "customerCompany") != nil do
      %{"roleAccess" => role_access, "customerCompany" => %{"id" => user_id}} = data
      %{"user_id" => user_id, "role_access" => role_access}
    else
      %{"id" => user_id, "roleAccess" => role_access} = data
      %{"user_id" => user_id, "role_access" => role_access}
    end
  end
end
