defmodule DeliveryLocationService.UserValidation do
  defp backend_verify(), do: "https://bcf26522eae5.ngrok.io/verify/token"

  def user_json(token) do
    # TODO fix validation. A reply might be :ok but not have the stuff I need
    {:ok, %{status: 200, headers: _headers, body: body}} =
      Peppermint.get(backend_verify(), params: %{cookie2: token})

    %{"data" => data} = Jason.decode!(body)
    extract(data)
  end

  defp extract(data) do
    # Roles: SUPER_ADMIN | ADMIN_COMPANY | RESTAURANT | DRIVER
    if Map.get(data, "customerCompany") != nil do
      %{"roleAccess" => role_access, "customerCompany" => %{"id" => user_id}} = data
      %{"user_id" => user_id, "role_access" => role_access}
    else
      %{"id" => user_id, "roleAccess" => role_access} = data
      %{"user_id" => user_id, "role_access" => role_access}
    end
  end
end
