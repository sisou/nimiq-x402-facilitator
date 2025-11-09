import app/v1/constants
import app/v1/types/payment_network.{type PaymentNetwork}
import app/v1/types/payment_payload.{type PaymentPayload}
import app/v1/types/payment_requirements.{type PaymentRequirements}
import app/v1/types/payment_scheme.{type PaymentScheme}
import app/web
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import nimiq/account/account_type
import nimiq/account/address.{type Address}
import nimiq/transaction/transaction.{type Transaction}
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

  use request <- parse_request(json)

  let result: Result(String, InvalidReason) = {
    // TODO: Verify the request

    use <- require_payment_x402_version(
      request.payment_payload.x402_version,
      constants.x402_version,
    )

    use <- require_payment_scheme(
      request.payment_payload.scheme,
      request.payment_requirements.scheme,
    )

    use <- require_payment_network(
      request.payment_payload.network,
      request.payment_requirements.network,
    )

    use tx <- parse_payment_transaction(
      request.payment_payload.payload.transaction,
    )

    // Check transaction properties
    use <- require_recipient(tx.recipient, request.payment_requirements.pay_to)
    use <- require_recipient_type(tx.recipient_type, account_type.Basic)

    // TODO: Check maxAmountRequired

    // TODO: Check on-chain properties
    // Transaction is currently valid (validity start height < 60 seconds ago)
    // Transaction not yet known
    // Sender account (type and balance)

    Ok(tx.sender |> address.to_user_friendly_address())
  }

  // An appropriate response is returned depending on whether the JSON could be
  // successfully handled or not.
  wisp.json_response(
    case result {
      Ok(payer) -> VerifyResponse(is_valid: True, payer:, invalid_reason: None)
      Error(invalid_reason) ->
        VerifyResponse(
          is_valid: False,
          payer: "",
          invalid_reason: Some(invalid_reason),
        )
    }
      |> response_to_json()
      |> json.to_string(),
    status_code.ok,
  )
}

type BadRequestType {
  AlreadyExists
  BadGateway
  IdempotencyError
  InternalServerError
  InvalidRequest
  InvalidSignature
  MalformedTransaction
  NotFound
  Unauthorized
}

fn bad_request_type_to_json(bad_request_type: BadRequestType) -> json.Json {
  case bad_request_type {
    AlreadyExists -> json.string("already_exists")
    BadGateway -> json.string("bad_gateway")
    IdempotencyError -> json.string("idempotency_error")
    InternalServerError -> json.string("internal_server_error")
    InvalidRequest -> json.string("invalid_request")
    InvalidSignature -> json.string("invalid_signature")
    MalformedTransaction -> json.string("malformed_transaction")
    NotFound -> json.string("not_found")
    Unauthorized -> json.string("unauthorized")
  }
}

type BadRequest {
  BadRequest(error_type: BadRequestType, error_message: String)
}

fn bad_request_to_json(bad_request: BadRequest) -> json.Json {
  let BadRequest(error_type:, error_message:) = bad_request
  json.object([
    #("error_type", bad_request_type_to_json(error_type)),
    #("error_message", json.string(error_message)),
  ])
}

fn parse_request(
  json: dynamic.Dynamic,
  next: fn(VerifyRequest) -> Response,
) -> Response {
  case decode.run(json, request_decoder()) {
    Ok(req) ->
      case req.x402_version {
        version if version == constants.x402_version -> next(req)
        _ ->
          wisp.json_response(
            BadRequest(InvalidRequest, "Invalid x402Version.")
              |> bad_request_to_json()
              |> json.to_string(),
            status_code.bad_request,
          )
      }
    Error(errors) ->
      wisp.json_response(
        BadRequest(
          InvalidRequest,
          errors
            |> list.map(fn(error) {
              "Expected "
              <> error.expected
              <> ", found "
              <> error.found
              <> " ("
              <> error.path
              |> list.fold("", fn(acc, path) { acc <> "/" <> path })
              <> ")."
            })
            |> list.fold("Invalid request. ", fn(acc, msg) { acc <> msg <> " " }),
        )
          |> bad_request_to_json()
          |> json.to_string(),
        status_code.bad_request,
      )
  }
}

type VerifyRequest {
  VerifyRequest(
    x402_version: Int,
    payment_payload: PaymentPayload,
    payment_requirements: PaymentRequirements,
  )
}

fn request_decoder() -> decode.Decoder(VerifyRequest) {
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
    x402_version:,
    payment_payload:,
    payment_requirements:,
  ))
}

type InvalidReason {
  InsufficientFunds
  InvalidScheme
  InvalidNetwork
  InvalidX402Version
  InvalidPaymentRequirements
  InvalidPayload
}

fn invalid_reason_to_json(invalid_reason: InvalidReason) -> json.Json {
  case invalid_reason {
    InsufficientFunds -> json.string("insufficient_funds")
    InvalidScheme -> json.string("invalid_scheme")
    InvalidNetwork -> json.string("invalid_network")
    InvalidX402Version -> json.string("invalid_x402_version")
    InvalidPaymentRequirements -> json.string("invalid_payment_requirements")
    InvalidPayload -> json.string("invalid_payload")
  }
}

fn require_payment_x402_version(
  version: Int,
  required_version: Int,
  next: fn() -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case version {
    version if version == required_version -> next()
    _ -> Error(InvalidX402Version)
  }
}

fn require_payment_scheme(
  scheme: PaymentScheme,
  required_scheme: PaymentScheme,
  next: fn() -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case scheme {
    scheme if scheme == required_scheme -> next()
    _ -> Error(InvalidScheme)
  }
}

fn require_payment_network(
  network: PaymentNetwork,
  required_network: PaymentNetwork,
  next: fn() -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case network {
    network if network == required_network -> next()
    _ -> Error(InvalidNetwork)
  }
}

fn parse_payment_transaction(
  tx: String,
  next: fn(Transaction) -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case transaction.from_hex(tx) {
    Ok(tx) -> next(tx)
    _ -> Error(InvalidPayload)
  }
}

fn require_recipient(
  recipient: Address,
  required_recipient: Address,
  next: fn() -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case recipient {
    recipient if recipient == required_recipient -> next()
    _ -> Error(InvalidPayload)
  }
}

fn require_recipient_type(
  recipient_type: account_type.AccountType,
  required_type: account_type.AccountType,
  next: fn() -> Result(String, InvalidReason),
) -> Result(String, InvalidReason) {
  case recipient_type {
    recipient_type if recipient_type == required_type -> next()
    _ -> Error(InvalidPayload)
  }
}

type VerifyResponse {
  VerifyResponse(
    is_valid: Bool,
    payer: String,
    invalid_reason: Option(InvalidReason),
  )
}

fn response_to_json(response: VerifyResponse) -> json.Json {
  let VerifyResponse(is_valid:, payer:, invalid_reason:) = response
  json.object([
    #("isValid", json.bool(is_valid)),
    #("payer", json.string(payer)),
    #("invalidReason", case invalid_reason {
      None -> json.null()
      Some(value) -> invalid_reason_to_json(value)
    }),
  ])
}
