local typedefs = require "kong.db.schema.typedefs"

return {
  name = "http-log-extended",
  fields = {
    { config = {
        type = "record",
        fields = {
          { http_endpoint = typedefs.url { required = true } },
          { log_request_body = { type = "boolean", default = true } },
          { log_response_body = { type = "boolean", default = true } },
          { timeout = { type = "number", default = 10000 } },
          { keepalive = { type = "number", default = 60000 } },
        },
    }},
  },
}

