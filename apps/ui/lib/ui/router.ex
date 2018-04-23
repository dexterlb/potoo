defmodule Ui.Router do
  use Plug.Router
  alias Ui.Api
  alias Mesh.ServerUtils.Json

  alias Mesh.ServerUtils.PidCache
  require Logger

  plug :match
  plug Plug.Parsers, parsers: [:json],
                     pass:  ["application/json"],
                     json_decoder: Poison
  plug :dispatch

  get "/hello" do
    conn |> send_resp(200, "hi\n")
  end

  post "/get_contract" do
    conn |> reply_json(Api.get_contract(unjsonify(conn.body_params)))
  end

  post "/call" do
    conn |> reply_json(Api.call(unjsonify(conn.body_params)))
  end

  forward "/", to: ReverseProxy, upstream: ["localhost:8000"]

  # match _ do
  #   conn |> send_resp(404, "404\n")
  # end

  defp reply_json(conn, data) do
    Logger.debug(fn -> ["http <- ", inspect(data)] end)

    conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, encode_json(data))
  end

  defp encode_json(data) do
    Poison.encode!(jsonify(data), pretty: Application.get_env(:ui, :json_pretty, false))
  end

  def jsonify(data) do
    Json.jsonify(data, PidCache)
  end

  def unjsonify(json) do
    {:ok, data} = Json.unjsonify(json, PidCache)
    data
  end
end