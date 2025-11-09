import app/types/payment_kind
import app/types/payment_network
import app/types/payment_scheme
import app/web
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/list
import gleam/result
import status_code
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> home_page(req)

    ["v1", "supported"] -> supported(req)

    // This matches `/person`.
    ["person"] -> create_person(req)

    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn home_page(req: Request) -> Response {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body("Nimiq x402 Facilitator")
}

fn supported(_req: Request) -> Response {
  let kinds = [
    payment_kind.PaymentKind(
      x402_version: 1,
      scheme: payment_scheme.Exact,
      // TODO: Make network configurable
      network: payment_network.NimiqTestnet,
    ),
  ]

  kinds
  |> list.map(payment_kind.to_json)
  |> json.preprocessed_array()
  |> json.to_string()
  |> wisp.json_response(status_code.ok)
}

// This type is going to be parsed and decoded from the request body.
pub type Person {
  Person(name: String, is_cool: Bool)
}

// To decode the type we need a dynamic decoder.
// See the standard library documentation for more information on decoding
// dynamic values [1].
//
// [1]: https://hexdocs.pm/gleam_stdlib/gleam/dynamic.html
fn person_decoder() -> decode.Decoder(Person) {
  use name <- decode.field("name", decode.string)
  use is_cool <- decode.field("is-cool", decode.bool)
  decode.success(Person(name:, is_cool:))
}

pub fn create_person(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  // This middleware parses a `Dynamic` value from the request body.
  // It returns an error response if the body is not valid JSON, or
  // if the content-type is not `application/json`, or if the body
  // is too large.
  use json <- wisp.require_json(req)

  let result = {
    // The JSON data can be decoded into a `Person` value.
    use person <- result.try(decode.run(json, person_decoder()))

    // And then a JSON response can be created from the person.
    let object =
      json.object([
        #("name", json.string(person.name)),
        #("is-cool", json.bool(person.is_cool)),
        #("saved", json.bool(True)),
      ])
    Ok(json.to_string(object))
  }

  // An appropriate response is returned depending on whether the JSON could be
  // successfully handled or not.
  case result {
    Ok(json) -> wisp.json_response(json, status_code.created)

    // In a real application we would probably want to return some JSON error
    // object, but for this example we'll just return an empty response.
    Error(_) -> wisp.unprocessable_content()
  }
}
