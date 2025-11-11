import app/config.{type Config}
import app/rpc
import app/v1/constants
import app/v1/types/bad_request.{type BadRequestType}
import app/v1/types/invalid_reason.{type InvalidReason}
import app/v1/types/payment_network.{type PaymentNetwork}
import app/v1/types/payment_payload.{type PaymentPayload}
import app/v1/types/payment_requirements.{type PaymentRequirements}
import app/v1/types/payment_scheme.{type PaymentScheme}
import app/v1/types/verify_response.{type VerifyResponse}
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import nimiq/account/account_type
import nimiq/address.{type Address}
import nimiq/blake2b
import nimiq/key/signature
import nimiq/transaction/network_id
import nimiq/transaction/signature_proof
import nimiq/transaction/transaction.{type Transaction}
import wisp

pub type ErrorResponse {
  Bad(BadRequestType, message: String)
  Invalid(InvalidReason, payer: Option(Address))
}

pub fn validate_request_intrinsic(
  json: dynamic.Dynamic,
  config: Config,
  next: fn(VerifyRequest) -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  use request <- parse_request(json)

  use <- require_request_x402_version(
    request.x402_version,
    constants.x402_version,
  )

  use <- require_payment_x402_version(
    request.payment_payload.x402_version,
    request.x402_version,
  )

  use <- require_payment_scheme(
    request.payment_payload.scheme,
    request.payment_requirements.scheme,
  )

  use <- require_supported_network(
    request.payment_requirements.network,
    config.network,
  )

  use <- require_payment_network(
    request.payment_payload.network,
    request.payment_requirements.network,
  )

  next(request)
}

pub fn validate_transaction_intrinsic(
  request: VerifyRequest,
  config: Config,
  next: fn(Transaction) -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  use tx <- parse_payment_transaction(
    request.payment_payload.payload.transaction,
  )

  use <- require_valid_signature(tx)

  use <- require_recipient(tx, request.payment_requirements.pay_to)

  use <- require_recipient_account_type(tx, account_type.Basic)

  use <- require_network(tx, config.network)

  next(tx)
}

pub fn validate_transaction_onchain(
  tx: Transaction,
  config: Config,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  // Transaction is currently valid (validity start height < 60 seconds ago)
  let current_height = rpc.get_block_number(config)
  use <- require_validity_window(tx.validity_start_height, current_height)

  // Transaction not yet known
  let tx_hash =
    tx
    |> transaction.serialize_content()
    |> blake2b.hash()
    |> bit_array.base16_encode()
  let existing_tx = rpc.get_transaction_by_hash(tx_hash, config)
  use <- require_transaction_unknown(tx_hash, existing_tx)

  // Sender account (type and balance)
  let sender_account =
    rpc.get_account_by_address(
      tx.sender |> address.to_user_friendly_address(),
      config,
    )
  use <- require_sender_account_type(sender_account, tx.sender_type)
  use <- require_sender_balance(sender_account, tx.value.luna + tx.fee.luna)

  next()
}

fn parse_request(
  json: dynamic.Dynamic,
  next: fn(VerifyRequest) -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case decode.run(json, request_decoder()) {
    Ok(req) ->
      case req.x402_version {
        version if version == constants.x402_version -> next(req)
        _ -> Error(Bad(bad_request.InvalidRequest, "Invalid x402Version."))
      }
    Error(errors) ->
      Error(Bad(
        bad_request.InvalidRequest,
        errors
          |> list.map(fn(error) {
            "Expected "
            <> error.expected
            <> ", found "
            <> error.found
            <> " ("
            <> error.path
            |> list.fold("", fn(acc, path) { acc <> "/" <> path })
            <> ")."
          })
          |> list.fold("Invalid request. ", fn(acc, msg) { acc <> msg <> " " }),
      ))
  }
}

pub type VerifyRequest {
  VerifyRequest(
    x402_version: Int,
    payment_payload: PaymentPayload,
    payment_requirements: PaymentRequirements,
  )
}

fn request_decoder() -> decode.Decoder(VerifyRequest) {
  use x402_version <- decode.field("x402Version", decode.int)
  use payment_payload <- decode.field(
    "paymentPayload",
    payment_payload.decoder(),
  )
  use payment_requirements <- decode.field(
    "paymentRequirements",
    payment_requirements.decoder(),
  )
  decode.success(VerifyRequest(
    x402_version:,
    payment_payload:,
    payment_requirements:,
  ))
}

fn require_request_x402_version(
  version: Int,
  required_version: Int,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case version {
    version if version == required_version -> next()
    _ -> Error(Bad(bad_request.InvalidRequest, "Invalid root x402Version"))
  }
}

fn require_payment_x402_version(
  version: Int,
  required_version: Int,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case version {
    version if version == required_version -> next()
    _ -> Error(Invalid(invalid_reason.InvalidX402Version, None))
  }
}

fn require_payment_scheme(
  scheme: PaymentScheme,
  required_scheme: PaymentScheme,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case scheme {
    scheme if scheme == required_scheme -> next()
    _ -> Error(Invalid(invalid_reason.InvalidScheme, None))
  }
}

fn require_supported_network(
  network: PaymentNetwork,
  required_network: PaymentNetwork,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case network {
    network if network == required_network -> next()
    _ -> Error(Bad(bad_request.InvalidRequest, "Unsupported required network."))
  }
}

fn require_payment_network(
  network: PaymentNetwork,
  required_network: PaymentNetwork,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case network {
    network if network == required_network -> next()
    _ -> Error(Invalid(invalid_reason.InvalidNetwork, None))
  }
}

fn parse_payment_transaction(
  tx: String,
  next: fn(Transaction) -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case transaction.from_hex(tx) {
    Ok(tx) -> next(tx)
    Error(error) ->
      Error(Bad(
        bad_request.MalformedTransaction,
        "Malformed transaction: " <> error,
      ))
  }
}

fn require_valid_signature(
  tx: Transaction,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  use proof <- result.try(
    tx.proof
    |> signature_proof.deserialize_all()
    |> result.map_error(fn(error) {
      Bad(
        bad_request.MalformedTransaction,
        "Malformed signature proof: " <> error,
      )
    }),
  )

  case
    proof.signature
    |> signature.verify(proof.public_key, tx |> transaction.serialize_content())
  {
    True -> next()
    False ->
      Error(Bad(bad_request.InvalidSignature, "Invalid transaction signature."))
  }
}

fn require_recipient(
  tx: Transaction,
  required_recipient: Address,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case tx.recipient {
    recipient if recipient == required_recipient -> next()
    _ -> {
      wisp.log_debug(
        "Recipient mismatch: expected "
        <> required_recipient |> address.to_user_friendly_address()
        <> ", found "
        <> tx.recipient |> address.to_user_friendly_address(),
      )
      Error(Invalid(invalid_reason.InvalidPayload, Some(tx.sender)))
    }
  }
}

fn require_recipient_account_type(
  tx: Transaction,
  required_type: account_type.AccountType,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case tx.recipient_type {
    recipient_type if recipient_type == required_type -> next()
    _ -> {
      wisp.log_debug(
        "Recipient account type mismatch: expected "
        <> case required_type {
          account_type.Basic -> "Basic"
          account_type.Vesting -> "Vesting"
          account_type.Htlc -> "HTLC"
          account_type.Staking -> "Staking"
        }
        <> ", found "
        <> case tx.recipient_type {
          account_type.Basic -> "Basic"
          account_type.Vesting -> "Vesting"
          account_type.Htlc -> "HTLC"
          account_type.Staking -> "Staking"
        },
      )
      Error(Invalid(invalid_reason.InvalidPayload, Some(tx.sender)))
    }
  }
}

fn require_network(
  tx: Transaction,
  required_network: PaymentNetwork,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  let required_network_id = case required_network {
    payment_network.Nimiq -> network_id.MainAlbatross
    payment_network.NimiqTestnet -> network_id.TestAlbatross
  }

  case tx.network_id {
    network if network == required_network_id -> next()
    _ -> {
      wisp.log_debug(
        "Network mismatch: expected "
        <> case required_network {
          payment_network.Nimiq -> "Nimiq Mainnet"
          payment_network.NimiqTestnet -> "Nimiq Testnet"
        }
        <> ", found "
        <> case tx.network_id {
          network_id.MainAlbatross -> "Nimiq Mainnet"
          network_id.TestAlbatross -> "Nimiq Testnet"
          _ -> "Unknown Network"
        },
      )
      Error(Invalid(invalid_reason.InvalidPayload, Some(tx.sender)))
    }
  }
}

fn require_validity_window(
  validity_start_height: Int,
  current_height: Int,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  // The validity window starts 2 hours into the past
  let window_start = current_height - 2 * 60 * 60
  // Add 60 blocks (1 minute) to ensure the transaction doesn't expire in the next minute
  let window_start = window_start + 60

  case validity_start_height {
    height if height >= window_start && height <= current_height + 1 -> next()
    _ -> {
      wisp.log_debug(
        "Validity window invalid: expected between "
        <> window_start |> int.to_string()
        <> " and "
        <> current_height + 1 |> int.to_string()
        <> ", found "
        <> validity_start_height |> int.to_string(),
      )
      Error(Invalid(invalid_reason.InvalidPayload, None))
    }
  }
}

fn require_transaction_unknown(
  hash: String,
  existing_tx: Result(rpc.RpcTransaction, Nil),
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) {
  case existing_tx {
    Error(Nil) -> next()
    Ok(_) ->
      Error(Bad(
        bad_request.AlreadyExists,
        "Transaction with hash " <> hash <> " already exists.",
      ))
  }
}

fn require_sender_account_type(
  sender_account: Result(rpc.RpcAccount, Nil),
  required_type: account_type.AccountType,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case sender_account {
    Error(Nil) -> Error(Invalid(invalid_reason.InsufficientFunds, None))
    Ok(account) ->
      case account.typ {
        typ if typ == required_type -> next()
        _ -> {
          wisp.log_debug(
            "Sender account type mismatch: expected "
            <> case required_type {
              account_type.Basic -> "Basic"
              account_type.Vesting -> "Vesting"
              account_type.Htlc -> "HTLC"
              account_type.Staking -> "Staking"
            }
            <> ", found "
            <> case account.typ {
              account_type.Basic -> "Basic"
              account_type.Vesting -> "Vesting"
              account_type.Htlc -> "HTLC"
              account_type.Staking -> "Staking"
            },
          )
          Error(Invalid(invalid_reason.InvalidPayload, None))
        }
      }
  }
}

fn require_sender_balance(
  sender_account: Result(rpc.RpcAccount, Nil),
  required_balance: Int,
  next: fn() -> Result(VerifyResponse, ErrorResponse),
) -> Result(VerifyResponse, ErrorResponse) {
  case sender_account {
    Error(Nil) -> Error(Invalid(invalid_reason.InsufficientFunds, None))
    Ok(account) -> {
      case account.balance {
        balance if balance >= required_balance -> next()
        _ -> Error(Invalid(invalid_reason.InsufficientFunds, None))
      }
    }
  }
}
