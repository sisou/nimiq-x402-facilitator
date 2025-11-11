import app/config.{type Config}
import app/v1/constants
import app/v1/types/payment_kind
import app/v1/types/payment_scheme
import gleam/http.{Get}
import gleam/json
import gleam/list
import status_code
import wisp.{type Request, type Response}

pub fn handle(req: Request, config: Config) -> Response {
  use <- wisp.require_method(req, Get)

  let kinds = [
    payment_kind.PaymentKind(
      x402_version: constants.x402_version,
      scheme: payment_scheme.Exact,
      network: config.network,
    ),
  ]

  kinds
  |> list.map(payment_kind.to_json)
  |> json.preprocessed_array()
  |> json.to_string()
  |> wisp.json_response(status_code.ok)
}
