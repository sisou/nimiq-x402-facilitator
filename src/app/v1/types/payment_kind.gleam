import app/v1/types/payment_network.{type PaymentNetwork}
import app/v1/types/payment_scheme.{type PaymentScheme}
import gleam/json

pub type PaymentKind {
  PaymentKind(x402_version: Int, scheme: PaymentScheme, network: PaymentNetwork)
}

pub fn to_json(payment_kind: PaymentKind) -> json.Json {
  let PaymentKind(x402_version:, scheme:, network:) = payment_kind
  json.object([
    #("x402Version", json.int(x402_version)),
    #("scheme", payment_scheme.to_json(scheme)),
    #("network", payment_network.to_json(network)),
  ])
}
