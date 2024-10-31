local cjson = require "cjson"

local serializer = {}

function serializer.serialize(ngx)
  return {
    request = {
      method = ngx.req.get_method(),
      uri = ngx.var.request_uri,
      headers = ngx.req.get_headers(),
      body = ngx.ctx.http_log_extended.req_body
    },
    response = {
      status = ngx.status,
      headers = ngx.resp.get_headers(),
      body = ngx.ctx.http_log_extended.res_body
    }
  }
end

return serializer

