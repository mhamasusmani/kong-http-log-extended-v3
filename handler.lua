local cjson = require "cjson"
local uuid = require "resty.uuid"  -- UUID library for unique IDs
local url = require "socket.url"
local serializer = require "kong.plugins.http-log-extended.serializer"

local CustomHttpLogHandler = {}

CustomHttpLogHandler.PRIORITY = 10
CustomHttpLogHandler.VERSION = "1.0"

local function get_request_body()
  ngx.req.read_body()
  return ngx.req.get_body_data()
end

local function generate_post_payload(parsed_url, body)
  local url_path = parsed_url.path or "/"
  if parsed_url.query then
    url_path = url_path .. "?" .. parsed_url.query
  end

  local headers = string.format(
    "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n",
    url_path, parsed_url.host, #body
  )
  return headers .. body
end

local function parse_url(endpoint)
  local parsed = url.parse(endpoint)
  parsed.port = parsed.port or (parsed.scheme == "http" and 80 or 443)
  parsed.path = parsed.path or "/"
  return parsed
end

local function log_data(premature, conf, log_body)
  if premature then return end
  local parsed_url = parse_url(conf.http_endpoint)
  
  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  local ok, err = sock:connect(parsed_url.host, tonumber(parsed_url.port))
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to connect to " .. parsed_url.host .. ": ", err)
    return
  end

  if parsed_url.scheme == "https" then
    local _, ssl_err = sock:sslhandshake(true, parsed_url.host, false)
    if ssl_err then
      ngx.log(ngx.ERR, "[http-log-extended] SSL handshake failed: ", ssl_err)
      return
    end
  end

  ok, err = sock:send(generate_post_payload(parsed_url, log_body))
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to send data: ", err)
  end

  ok, err = sock:setkeepalive(conf.keepalive)
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to set keepalive: ", err)
  end
end

function CustomHttpLogHandler:access(conf)
  ngx.ctx.http_log_extended = {
    req_body = conf.log_request_body and get_request_body() or "",
    unique_id = uuid.generate_v4()  -- Assign a unique ID to track the request
  }
end

function CustomHttpLogHandler:body_filter(conf)
  if conf.log_response_body then
    local chunk = ngx.arg[1]
    ngx.ctx.http_log_extended.res_body = (ngx.ctx.http_log_extended.res_body or "") .. (chunk or "")
  end
end

function CustomHttpLogHandler:log(conf)
  local serialized_data = serializer.serialize(ngx)
  serialized_data.unique_id = ngx.ctx.http_log_extended.unique_id  -- Add unique ID for tracing
  local log_body = cjson.encode(serialized_data)

  local ok, err = ngx.timer.at(0, log_data, conf, log_body)
  if not ok then
    ngx.log(ngx.ERR, "[http-log-extended] Failed to create timer: ", err)
  end
end

return CustomHttpLogHandler

