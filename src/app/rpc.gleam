import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/uri
import jsonrpcx
import nimiq/account/account_type

pub fn get_block_number() -> Int {
  let http_request =
    jsonrpcx.request(method: "getBlockNumber", id: jsonrpcx.id(42))
    |> make_request()

  let response: jsonrpcx.Response(NimiqRpcResult(Int)) =
    httpc.send(http_request)
    |> unwrap()
    |> fn(resp) { resp.body }
    |> json.parse(
      jsonrpcx.response_decoder(nimiq_rpc_result_decoder(decode.int)),
    )
    |> unwrap()

  response.result.data
}

pub type RpcTransaction {
  RpcTransaction(
    hash: String,
    block_number: Int,
    timestamp: Int,
    confirmations: Int,
    size: Int,
    related_addresses: List(String),
    from: String,
    from_type: Int,
    to: String,
    to_type: Int,
    value: Int,
    fee: Int,
    sender_data: String,
    recipient_data: String,
    flags: Int,
    validity_start_height: Int,
    proof: String,
    network_id: Int,
    execution_result: Bool,
  )
}

fn rpc_transaction_decoder() -> decode.Decoder(RpcTransaction) {
  use hash <- decode.field("hash", decode.string)
  use block_number <- decode.field("blockNumber", decode.int)
  use timestamp <- decode.field("timestamp", decode.int)
  use confirmations <- decode.field("confirmations", decode.int)
  use size <- decode.field("size", decode.int)
  use related_addresses <- decode.field(
    "relatedAddresses",
    decode.list(decode.string),
  )
  use from <- decode.field("from", decode.string)
  use from_type <- decode.field("fromType", decode.int)
  use to <- decode.field("to", decode.string)
  use to_type <- decode.field("toType", decode.int)
  use value <- decode.field("value", decode.int)
  use fee <- decode.field("fee", decode.int)
  use sender_data <- decode.field("senderData", decode.string)
  use recipient_data <- decode.field("recipientData", decode.string)
  use flags <- decode.field("flags", decode.int)
  use validity_start_height <- decode.field("validityStartHeight", decode.int)
  use proof <- decode.field("proof", decode.string)
  use network_id <- decode.field("networkId", decode.int)
  use execution_result <- decode.field("executionResult", decode.bool)
  decode.success(RpcTransaction(
    hash:,
    block_number:,
    timestamp:,
    confirmations:,
    size:,
    related_addresses:,
    from:,
    from_type:,
    to:,
    to_type:,
    value:,
    fee:,
    sender_data:,
    recipient_data:,
    flags:,
    validity_start_height:,
    proof:,
    network_id:,
    execution_result:,
  ))
}

pub fn get_transaction_by_hash(hash: String) -> Result(RpcTransaction, Nil) {
  let http_request =
    jsonrpcx.request(method: "getTransactionByHash", id: jsonrpcx.id(42))
    |> jsonrpcx.request_params([hash |> json.string])
    |> make_request()

  let response: jsonrpcx.Message =
    httpc.send(http_request)
    |> unwrap()
    |> fn(resp) { resp.body }
    |> json.parse(jsonrpcx.message_decoder())
    |> unwrap()

  case response {
    jsonrpcx.ResponseMessage(jsonrpcx.Response(result:, ..)) ->
      result
      |> decode.run(nimiq_rpc_result_decoder(rpc_transaction_decoder()))
      |> result.map(fn(result) { result.data })
      |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}

fn rpc_account_type_decoder() -> decode.Decoder(account_type.AccountType) {
  use variant <- decode.then(decode.string)
  case variant {
    "basic" -> decode.success(account_type.Basic)
    "vesting" -> decode.success(account_type.Vesting)
    "htlc" -> decode.success(account_type.Htlc)
    "staking" -> decode.success(account_type.Staking)
    _ -> decode.failure(account_type.Basic, "RpcAccountType")
  }
}

pub type RpcAccount {
  RpcAccount(address: String, balance: Int, typ: account_type.AccountType)
}

fn rpc_account_decoder() -> decode.Decoder(RpcAccount) {
  use address <- decode.field("address", decode.string)
  use balance <- decode.field("balance", decode.int)
  use typ <- decode.field("typ", rpc_account_type_decoder())
  decode.success(RpcAccount(address:, balance:, typ:))
}

pub fn get_account_by_address(address: String) -> Result(RpcAccount, Nil) {
  let http_request =
    jsonrpcx.request(method: "getAccountByAddress", id: jsonrpcx.id(42))
    |> jsonrpcx.request_params([address |> json.string])
    |> make_request()

  let response: jsonrpcx.Message =
    httpc.send(http_request)
    |> unwrap()
    |> fn(resp) { resp.body }
    |> json.parse(jsonrpcx.message_decoder())
    |> unwrap()

  case response {
    jsonrpcx.ResponseMessage(jsonrpcx.Response(result:, ..)) ->
      result
      |> decode.run(nimiq_rpc_result_decoder(rpc_account_decoder()))
      |> result.map(fn(result) { result.data })
      |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}

fn make_request(
  payload: jsonrpcx.Request(List(json.Json)),
) -> request.Request(String) {
  let http_request =
    request.from_uri(uri.parse("") |> unwrap())
    |> unwrap()
    |> request.set_method(Post)
    |> request.set_header("content-type", "application/json")

  payload
  |> jsonrpcx.request_to_json(json.preprocessed_array)
  |> json.to_string()
  |> request.set_body(http_request, _)
}

type NimiqRpcResult(result) {
  NimiqRpcResult(data: result, metadata: Option(dynamic.Dynamic))
}

fn nimiq_rpc_result_decoder(
  data_decoder: decode.Decoder(a),
) -> decode.Decoder(NimiqRpcResult(a)) {
  use data <- decode.field("data", data_decoder)
  use metadata <- decode.field("metadata", decode.optional(decode.dynamic))
  decode.success(NimiqRpcResult(data:, metadata:))
}

fn unwrap(res: Result(a, b)) -> a {
  case res {
    Ok(value) -> value
    Error(_) -> {
      panic as "Expected Ok value"
    }
  }
}
