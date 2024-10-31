# kong-http-log-extended-v3

A custom Kong plugin that extends the functionality of HTTP logging by adding request and response body logging. It integrates with external servers for logging and is compatible with Kong 3.8.0.

## Features

- Logs request and response bodies for detailed auditing.
- Forwards logs to a configurable external server.
- Allows unique request ID tracking for easier debugging and log correlation.

## Prerequisites

1. **Kong**: Version 3.8.0
2. **LuaRocks Dependencies**:
   - `lua-resty-uuid` for generating UUIDs
   - `kong-oidc-v3` for OpenID Connect support (if required by your setup)

## Installation

### Step 1: Clone the Plugin Repository

Clone this repository to your Kong setup.

git clone https://github.com/mhamasusmani/kong-http-log-extended-v3.git

### Step 2: Add Plugin to Docker Image

Copy the plugin code to the appropriate directory in your Kong Docker image. Here’s an example Dockerfile configuration:


FROM kong:ubi8-3.8.0-base

USER root

COPY plugins/http-log-extended /usr/local/share/lua/5.1/kong/plugins/http-log-extended

COPY start.sh .
RUN chmod +x start.sh
ENTRYPOINT ["/start.sh"]
CMD ["kong", "docker-start", "—vv"]

### Step 3: Configure kong.yml

Add the following configuration to kong.yml to activate and configure the plugin:


_format_version: "1.1"
plugins:
  - name: http-log-extended
    config:
      http_endpoint: "${SECURITY_URL}/auditlogs/mega-backend"
      log_request_body: true
      log_response_body: true

### Step 4: Configure docker-compose.yml

In docker-compose.yml, enable the plugin:

environment:
  - KONG_PLUGINS=bundled,http-log-extended
  - SECURITY_URL=http://security-server
#### Replace http://security-server with the actual URL of your external logging server.

### Step 5: Build and Run the Docker Image

Build and run the Docker image with the custom plugin.


docker-compose up –build

## Usage

Once installed and running, the plugin will log HTTP request and response bodies and forward them to the configured endpoint (http_endpoint). This plugin can help capture detailed request information, which is especially useful in auditing and debugging scenarios.

### Troubleshooting

### Common Errors
Module Not Found: Ensure all required Lua files (like serializer.lua) are in the correct directory and referenced correctly in handler.lua.
Missing Dependencies: Make sure you have installed dependencies like lua-resty-uuid and kong-oidc-v3 via LuaRocks.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.

Feel free to reach out if you have any questions or issues.
