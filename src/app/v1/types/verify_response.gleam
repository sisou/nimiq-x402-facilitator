import app/v1/types/invalid_reason.{type InvalidReason}
import gleam/json
import gleam/option.{type Option, None, Some}
import nimiq/address.{type Address}

pub type VerifyResponse {
  VerifyResponse(
    is_valid: Bool,
    payer: Option(Address),
    invalid_reason: Option(InvalidReason),
  )
}

pub fn to_json(response: VerifyResponse) -> json.Json {
  let VerifyResponse(is_valid:, payer:, invalid_reason:) = response
  json.object([
    #("isValid", json.bool(is_valid)),
    #(
      "payer",
      json.string(case payer {
        Some(address) -> address |> address.to_user_friendly_address()
        None -> ""
      }),
    ),
    #("invalidReason", case invalid_reason {
      None -> json.null()
      Some(value) -> invalid_reason.to_json(value)
    }),
  ])
}
