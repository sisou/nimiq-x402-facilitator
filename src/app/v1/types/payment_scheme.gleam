import gleam/dynamic/decode
import gleam/json

pub type PaymentScheme {
  Exact
}

pub fn decoder() -> decode.Decoder(PaymentScheme) {
  use variant <- decode.then(decode.string)
  case variant {
    "exact" -> decode.success(Exact)
    _ -> decode.failure(Exact, "PaymentScheme")
  }
}

pub fn to_json(payment_scheme: PaymentScheme) -> json.Json {
  case payment_scheme {
    Exact -> json.string("exact")
  }
}
