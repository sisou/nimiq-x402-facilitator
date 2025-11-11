import app/v1/types/bad_request.{BadRequest}
import app/v1/types/verify_response.{type VerifyResponse, VerifyResponse}
import app/v1/validation.{type ErrorResponse, Bad, Invalid}
import app/web
import gleam/http.{Post}
import gleam/json
import gleam/option.{None, Some}
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

  {
    use request <- validation.validate_request_intrinsic(json)
    use tx <- validation.validate_transaction_intrinsic(request)
    use <- validation.validate_transaction_onchain(tx)
    Ok(VerifyResponse(True, Some(tx.sender), None))
  }
  |> into_response()
}

fn into_response(res: Result(VerifyResponse, ErrorResponse)) -> Response {
  case res {
    Ok(ok_response) ->
      wisp.json_response(
        ok_response
          |> verify_response.to_json()
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
        Invalid(invalid_reason, payer) ->
          wisp.json_response(
            VerifyResponse(
              is_valid: False,
              payer:,
              invalid_reason: Some(invalid_reason),
            )
              |> verify_response.to_json()
              |> json.to_string(),
            status_code.ok,
          )
      }
  }
}
