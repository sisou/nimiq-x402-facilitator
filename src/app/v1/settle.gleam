import app/config.{type Config}
import app/v1/types/bad_request.{BadRequest}
import app/v1/types/settle_response.{type SettleResponse, SettleResponse}
import app/v1/validation.{type ErrorResponse, Bad, Invalid}
import app/web
import gleam/http.{Post}
import gleam/json
import gleam/option.{None, Some}
import status_code
import wisp.{type Request, type Response}

pub fn handle(req: Request, config: Config) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  // This middleware parses a `Dynamic` value from the request body.
  // It returns an error response if the body is not valid JSON, or
  // if the content-type is not `application/json`, or if the body
  // is too large.
  use json <- wisp.require_json(req)

  {
    use request <- validation.validate_request_intrinsic(json, config)
    use tx <- validation.validate_transaction_intrinsic(request, config)
    use hash <- validation.require_broadcast_transaction(tx, config)
    Ok(SettleResponse(
      success: True,
      payer: Some(tx.sender),
      transaction: Some(hash),
      network: Some(request.payment_payload.network),
      error_reason: None,
    ))
  }
  |> into_response()
}

fn into_response(res: Result(SettleResponse, ErrorResponse)) -> Response {
  case res {
    Ok(ok_response) ->
      wisp.json_response(
        ok_response
          |> settle_response.to_json()
          |> json.to_string(),
        status_code.ok,
      )
    Error(error_response) ->
      case error_response {
        Bad(error_type, error_message) ->
          wisp.json_response(
            bad_request.to_json(BadRequest(error_type, error_message))
              |> json.to_string(),
            status_code.bad_request,
          )
        Invalid(error_reason, payer) ->
          wisp.json_response(
            SettleResponse(
              success: False,
              payer:,
              transaction: None,
              network: None,
              error_reason: Some(error_reason),
            )
              |> settle_response.to_json()
              |> json.to_string(),
            status_code.ok,
          )
      }
  }
}
