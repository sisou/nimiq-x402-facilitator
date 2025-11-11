import gleam/json

pub type BadRequestType {
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

fn type_to_json(bad_request_type: BadRequestType) -> json.Json {
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

pub type BadRequest {
  BadRequest(error_type: BadRequestType, error_message: String)
}

pub fn to_json(bad_request: BadRequest) -> json.Json {
  let BadRequest(error_type:, error_message:) = bad_request
  json.object([
    #("error_type", type_to_json(error_type)),
    #("error_message", json.string(error_message)),
  ])
}
