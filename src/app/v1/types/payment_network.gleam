import gleam/dynamic/decode
import gleam/json

pub type PaymentNetwork {
  Nimiq
  NimiqTestnet
}

pub fn decoder() -> decode.Decoder(PaymentNetwork) {
  use variant <- decode.then(decode.string)
  case variant {
    "nimiq" -> decode.success(Nimiq)
    "nimiq-testnet" -> decode.success(NimiqTestnet)
    _ -> decode.failure(Nimiq, "PaymentNetwork")
  }
}

pub fn to_json(payment_network: PaymentNetwork) -> json.Json {
  case payment_network {
    Nimiq -> json.string("nimiq")
    NimiqTestnet -> json.string("nimiq-testnet")
  }
}
