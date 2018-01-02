defmodule BigQuery.AccessToken do
  @moduledoc """
  Retrieve a Google Cloud Access Token scoped to BigQuery
  """
  # Based on https://gist.github.com/plamb/8c8f39cfba9e69cb034a/871a9b8128117518cdfbbf46b4cd405b5353f6c6
  @spec get_token :: {:ok, String.t} | {:error, String.t}
  def get_token() do
    key_map =
      get_file_path()
      |> File.read!()
      |> JOSE.decode()

    jwk = JOSE.JWK.from_pem(key_map["private_key"])

    jws = %{"alg" => "RS256"}

    header = %{
      "alg" => "RS256",
      "typ" => "JWT"
    }

    iat = :os.system_time(:seconds)
    exp = iat + 3600

    claims = %{
      "iss" => key_map["client_email"],
      "scope" => "https://www.googleapis.com/auth/bigquery.readonly https://www.googleapis.com/auth/bigquery.insertdata https://www.googleapis.com/auth/bigquery",
      "aud" => "https://www.googleapis.com/oauth2/v3/token",
      "exp" => exp,
      "iat" => iat
    }
    encoded_claims = JOSE.encode(claims)

    {_alg, compacted} = JOSE.JWS.sign(jwk, encoded_claims, header, jws)
                        |> JOSE.JWS.compact

    token_auth_uri = "https://www.googleapis.com/oauth2/v3/token"
    headers = %{"Content-type" => "application/x-www-form-urlencoded"}
    form = {:form, [assertion: compacted, grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer"]}

    case HTTPoison.post(token_auth_uri, form, headers) do
      {:ok, response} ->
        body = JOSE.decode(response.body)
        {:ok, body["access_token"]}
      {:error, error} ->
        {:error, HTTPoison.Error.message(error)}
    end
  end

  defp get_file_path() do
    key_file_app = Application.get_env(:big_query, :bigquery_private_key_hosted_by_app)
    key_file = Application.get_env(:big_query, :bigquery_private_key_path)
    if key_file_app do
      Application.app_dir(key_file_app, key_file)
    else
      key_file
    end
  end

end
