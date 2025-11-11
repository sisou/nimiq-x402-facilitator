import app/v1/types/payment_network.{type PaymentNetwork}
import gleam/option.{type Option}
import gleam/result
import gleam/uri.{type Uri}
import glenvy/dotenv
import glenvy/env

pub type Config {
  Config(
    host: String,
    port: Int,
    network: PaymentNetwork,
    rpc_url: Uri,
    rpc_username: Option(String),
    rpc_password: Option(String),
    // api_key: Option(String),
  )
}

pub fn load() -> Config {
  let _ = dotenv.load()

  let host = env.string("HOST") |> result.unwrap("localhost")
  let port = env.int("PORT") |> result.unwrap(8000)

  let assert Ok(rpc_url) = env.string("RPC_URL") as "RPC_URL is required"
  let assert Ok(rpc_url) = uri.parse(rpc_url) as "Invalid RPC_URL"

  let rpc_username = env.string("RPC_USERNAME") |> option.from_result()
  let rpc_password = env.string("RPC_PASSWORD") |> option.from_result()

  // let api_key = env.string("API_KEY") |> option.from_result()

  Config(
    host:,
    port:,
    network: payment_network.NimiqTestnet,
    rpc_url:,
    rpc_username:,
    rpc_password:,
    // api_key:,
  )
}
