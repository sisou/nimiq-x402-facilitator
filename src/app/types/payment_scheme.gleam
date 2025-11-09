import gleam/json

pub type PaymentScheme {
  Exact
}

pub fn to_json(payment_scheme: PaymentScheme) -> json.Json {
  case payment_scheme {
    Exact -> json.string("exact")
  }
}
