import app/v1/types/payment_payload.{type PaymentPayload}
import app/v1/types/payment_requirements.{type PaymentRequirements}
import app/web
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import status_code
import wisp.{type Request, type Response}

pub fn handle(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  // This middleware parses a `Dynamic` value from the request body.
  // It returns an error response if the body is not valid JSON, or
  // if the content-type is not `application/json`, or if the body
  // is too large.
  use json <- wisp.require_json(req)

  let result = {
    // The JSON data can be decoded into a `Person` value.
    use _request <- result.try(decode.run(json, verify_request_decoder()))

    // TODO: Verify the request

    VerifyResponse(
      is_valid: False,
      payer: "NQ07 0000 0000 0000 0000 0000 0000 0000 0000 0000",
      invalid_reason: Some(InvalidPayload),
    )
    |> verify_response_to_json()
    |> json.to_string()
    |> Ok()
  }

  // An appropriate response is returned depending on whether the JSON could be
  // successfully handled or not.
  case result {
    Ok(json) -> wisp.json_response(json, status_code.created)

    // In a real application we would probably want to return some JSON error
    // object, but for this example we'll just return an empty response.
    Error(_) -> wisp.unprocessable_content()
  }
}

type VerifyRequest {
  VerifyRequest(
    x402_version: Int,
    payment_payload: PaymentPayload,
    payment_requirements: PaymentRequirements,
  )
}

fn verify_request_decoder() -> decode.Decoder(VerifyRequest) {
  use x402_version <- decode.field("x402Version", decode.int)
  use payment_payload <- decode.field(
    "paymentPayload",
    payment_payload.decoder(),
  )
  use payment_requirements <- decode.field(
    "paymentRequirements",
    payment_requirements.decoder(),
  )
  decode.success(VerifyRequest(
    x402_version,
    payment_payload:,
    payment_requirements:,
  ))
}

type VerifyInvalidReason {
  InsufficientFunds
  InvalidScheme
  InvalidNetwork
  InvalidX402Version
  InvalidPaymentRequirements
  InvalidPayload
}

fn verify_invalid_reason_to_json(
  verify_invalid_reason: VerifyInvalidReason,
) -> json.Json {
  case verify_invalid_reason {
    InsufficientFunds -> json.string("insufficient_funds")
    InvalidScheme -> json.string("invalid_scheme")
    InvalidNetwork -> json.string("invalid_network")
    InvalidX402Version -> json.string("invalid_x402_version")
    InvalidPaymentRequirements -> json.string("invalid_payment_requirements")
    InvalidPayload -> json.string("invalid_payload")
  }
}

type VerifyResponse {
  VerifyResponse(
    is_valid: Bool,
    payer: String,
    invalid_reason: Option(VerifyInvalidReason),
  )
}

fn verify_response_to_json(verify_response: VerifyResponse) -> json.Json {
  let VerifyResponse(is_valid:, payer:, invalid_reason:) = verify_response
  json.object([
    #("isValid", json.bool(is_valid)),
    #("payer", json.string(payer)),
    #("invalidReason", case invalid_reason {
      None -> json.null()
      Some(value) -> verify_invalid_reason_to_json(value)
    }),
  ])
}
