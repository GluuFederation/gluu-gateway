package httpapi.authz

# HTTP API request
import input

default allow = false

# Allow users to get their own salaries.
allow {
  input.method = "GET"
  input.path = ["folder", "command"]
  input.request_token_data.client_id = "0123456789"
}
