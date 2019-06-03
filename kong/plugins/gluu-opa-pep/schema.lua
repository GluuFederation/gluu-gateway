return {
    no_consumer = true,
    fields = {
        opa_url = { required = true, type = "url" },
        forward_request_body = { type = "boolean", default = false },
    }
}

