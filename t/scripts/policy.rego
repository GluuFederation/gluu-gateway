package httpapi.authz

# HTTP API request
import input

default allow = false

# Allow users to get their own salaries.
allow {
  input.method = "GET"
  input.path = ["posts", "1"]
}
