import app/v1/types/payment_network.{type PaymentNetwork}
import app/v1/types/payment_scheme.{type PaymentScheme}
import gleam/dynamic/decode

pub opaque type PaymentPayload {
  PaymentPayload(
    x402_version: Int,
    scheme: PaymentScheme,
    network: PaymentNetwork,
    payload: Payload,
  )
}

pub fn decoder() -> decode.Decoder(PaymentPayload) {
  use x402_version <- decode.field("x402Version", decode.int)
  use scheme <- decode.field("scheme", payment_scheme.decoder())
  use network <- decode.field("network", payment_network.decoder())
  use payload <- decode.field("payload", payload_decoder())
  decode.success(PaymentPayload(x402_version:, scheme:, network:, payload:))
}

pub opaque type Payload {
  Payload(transaction: String)
}

fn payload_decoder() -> decode.Decoder(Payload) {
  use transaction <- decode.field("transaction", decode.string)
  decode.success(Payload(transaction:))
}
