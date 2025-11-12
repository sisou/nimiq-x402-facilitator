import app/v1/types/invalid_reason.{type InvalidReason}
import app/v1/types/payment_network.{type PaymentNetwork}
import gleam/json
import gleam/option.{type Option, None, Some}
import nimiq/address.{type Address}

pub type SettleResponse {
  SettleResponse(
    success: Bool,
    payer: Option(Address),
    transaction: Option(String),
    network: Option(PaymentNetwork),
    error_reason: Option(InvalidReason),
  )
}

pub fn to_json(settle_response: SettleResponse) -> json.Json {
  let SettleResponse(success:, payer:, transaction:, network:, error_reason:) =
    settle_response
  json.object([
    #("success", json.bool(success)),
    #(
      "payer",
      json.string(
        payer
        |> option.map(address.to_user_friendly_address)
        |> option.unwrap(""),
      ),
    ),
    #("transaction", json.string(transaction |> option.unwrap(""))),
    #(
      "network",
      network
        |> option.map(payment_network.to_json)
        |> option.unwrap(json.string("")),
    ),
    #("error_reason", case error_reason {
      Some(value) -> invalid_reason.to_json(value)
      None -> json.null()
    }),
  ])
}
