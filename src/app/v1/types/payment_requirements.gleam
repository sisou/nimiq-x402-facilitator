import app/v1/types/payment_network.{type PaymentNetwork}
import app/v1/types/payment_scheme.{type PaymentScheme}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None}

pub opaque type PaymentRequirements {
  PaymentRequirements(
    scheme: PaymentScheme,
    network: PaymentNetwork,
    max_amount_required: Int,
    resource: String,
    description: String,
    mime_type: String,
    pay_to: String,
    max_timeout_seconds: Int,
    asset: String,
    output_schema: Option(dynamic.Dynamic),
    extra: Option(dynamic.Dynamic),
  )
}

pub fn decoder() -> decode.Decoder(PaymentRequirements) {
  use scheme <- decode.field("scheme", payment_scheme.decoder())
  use network <- decode.field("network", payment_network.decoder())
  use max_amount_required <- decode.field(
    "maxAmountRequired",
    max_amount_required_decoder(),
  )
  use resource <- decode.field("resource", decode.string)
  use description <- decode.field("description", decode.string)
  use mime_type <- decode.field("mimeType", decode.string)
  use pay_to <- decode.field("payTo", decode.string)
  use max_timeout_seconds <- decode.field("maxTimeoutSeconds", decode.int)
  use asset <- decode.field("asset", decode.string)
  use output_schema <- decode.optional_field(
    "outputSchema",
    None,
    decode.optional(decode.dynamic),
  )
  use extra <- decode.optional_field(
    "extra",
    None,
    decode.optional(decode.dynamic),
  )

  decode.success(PaymentRequirements(
    scheme:,
    network:,
    max_amount_required:,
    resource:,
    description:,
    mime_type:,
    pay_to:,
    max_timeout_seconds:,
    asset:,
    output_schema:,
    extra:,
  ))
}

pub fn max_amount_required_decoder() -> decode.Decoder(Int) {
  let default = 0
  decode.new_primitive_decoder("StringInt", fn(data) {
    case decode.run(data, decode.string) {
      Ok(x) ->
        case int.parse(x) {
          Ok(value) -> Ok(value)
          Error(_) -> Error(default)
        }
      Error(_) -> Error(default)
    }
  })
}
