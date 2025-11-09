import gleam/json

pub type PaymentNetwork {
  Nimiq
  NimiqTestnet
}

pub fn to_json(payment_network: PaymentNetwork) -> json.Json {
  case payment_network {
    Nimiq -> json.string("nimiq")
    NimiqTestnet -> json.string("nimiq-testnet")
  }
}
