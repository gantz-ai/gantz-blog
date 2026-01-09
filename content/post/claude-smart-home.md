+++
title = "Let Claude control your smart home"
date = 2025-12-28
description = "Control smart home devices with Claude and MCP. Tutorial for lights, thermostats, and sensors using natural language through local shell scripts."
summary = "Tell Claude to 'dim the living room lights' and watch it happen. This tutorial shows how to control Hue lights, thermostats, and sensors through MCP tools. Create shell scripts that call device APIs, define them as MCP tools, and run the whole thing on a Raspberry Pi. Voice control your home through natural conversation."
image = "images/diner-exterior.webp"
draft = false
tags = ['tutorial', 'mcp', 'automation']
voice = true

[howto]
name = "Control Smart Home with Claude and MCP"
totalTime = 30
[[howto.steps]]
name = "Identify your devices"
text = "List smart home devices with API access: Hue lights, thermostats, sensors."
[[howto.steps]]
name = "Create control scripts"
text = "Write shell scripts or Python to control each device via their APIs."
[[howto.steps]]
name = "Define MCP tools"
text = "Create gantz.yaml mapping natural language commands to device controls."
[[howto.steps]]
name = "Set up the MCP server"
text = "Run Gantz on a device connected to your home network (Raspberry Pi works great)."
[[howto.steps]]
name = "Talk to Claude"
text = "Use natural language commands like 'dim the lights' through Claude."
+++


Last weekend I got Claude to turn off my lights. Not through some official integration - just MCP and a few shell scripts.

No Alexa. No Google Home. No proprietary app. Just Claude understanding natural language and executing commands on my local network.

The cool part? It actually understands context. "Make it cozy" dims the lights and maybe turns on a scene. "I'm leaving" turns everything off. It's not just mapping keywords to commands - it's reasoning about what you want.

Here's the complete setup.

## The goal

Talk to Claude naturally and have it control my home:

- "Turn off the living room lights"
- "Set the thermostat to 72"
- "Is the garage door open?"
- "Dim the bedroom lights to 30%"

No special apps. No voice assistant. Just Claude with access to my local tools.

## How it works

Most smart home devices have APIs or CLI tools. Philips Hue has a local REST API. Home Assistant has a REST API and CLI. Even cheap WiFi plugs often have local control if you flash them with Tasmota.

The key insight: **if you can control it from terminal, Claude can control it through MCP.**

```text
You → Claude → MCP Server (your machine) → Smart home API → Device
         │                 │                      │
    Natural language   Gantz tunnel      curl/API calls
```

The MCP server runs on your home network (or any machine that can reach your devices). Gantz creates a tunnel so Claude can reach it. Claude figures out which tools to call based on your request.

## What you'll need

- Smart home devices with API access (Hue, Home Assistant, MQTT, etc.)
- A computer on your home network (Raspberry Pi works great)
- [Gantz CLI](https://gantz.run) installed
- About 30 minutes for initial setup

I'll show examples for Philips Hue and Home Assistant, but this works with any device that has an API. The pattern is always the same: wrap the API call in a Gantz tool.

## Before you start

Make sure you can control your devices from the command line first. Try:

```bash
# For Hue (after getting token)
curl http://192.168.1.100/api/YOUR_TOKEN/lights

# For Home Assistant
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://homeassistant.local:8123/api/states
```

If these work, you're ready to wrap them in MCP tools.

## Option 1: Philips Hue

Hue has a local API. First, get your bridge IP and create a user token.

```bash
# Find your bridge
curl -s https://discovery.meethue.com | jq

# Create a user (press the bridge button first)
curl -X POST http://<bridge-ip>/api \
  -d '{"devicetype":"claude-home"}'
```

Now create your `gantz.yaml`:

```yaml
name: smart-home
description: Control my smart home

tools:
  - name: list_lights
    description: List all lights and their current state
    parameters: []
    script:
      shell: |
        curl -s http://192.168.1.100/api/${HUE_TOKEN}/lights | jq -r 'to_entries[] | "\(.key): \(.value.name) - \(if .value.state.on then "ON" else "OFF" end)"'

  - name: turn_on_light
    description: Turn on a light by ID or name
    parameters:
      - name: light_id
        type: string
        required: true
    script:
      shell: |
        curl -X PUT http://192.168.1.100/api/${HUE_TOKEN}/lights/{{light_id}}/state \
          -d '{"on": true}'

  - name: turn_off_light
    description: Turn off a light by ID or name
    parameters:
      - name: light_id
        type: string
        required: true
    script:
      shell: |
        curl -X PUT http://192.168.1.100/api/${HUE_TOKEN}/lights/{{light_id}}/state \
          -d '{"on": false}'

  - name: set_brightness
    description: Set light brightness (0-254)
    parameters:
      - name: light_id
        type: string
        required: true
      - name: brightness
        type: integer
        required: true
    script:
      shell: |
        curl -X PUT http://192.168.1.100/api/${HUE_TOKEN}/lights/{{light_id}}/state \
          -d '{"on": true, "bri": {{brightness}}}'

  - name: set_color
    description: Set light color using hue (0-65535) and saturation (0-254)
    parameters:
      - name: light_id
        type: string
        required: true
      - name: hue
        type: integer
        required: true
      - name: saturation
        type: integer
        required: true
    script:
      shell: |
        curl -X PUT http://192.168.1.100/api/${HUE_TOKEN}/lights/{{light_id}}/state \
          -d '{"on": true, "hue": {{hue}}, "sat": {{saturation}}}'
```

Set your token as an environment variable:

```bash
export HUE_TOKEN="your-token-here"
gantz run
```

## Option 2: Home Assistant

If you use Home Assistant, even easier. HA has a REST API and CLI.

```yaml
name: home-assistant
description: Control Home Assistant

tools:
  - name: get_states
    description: Get state of all entities or filter by domain (light, switch, sensor, etc.)
    parameters:
      - name: domain
        type: string
        default: ""
    script:
      shell: |
        curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
          http://homeassistant.local:8123/api/states | \
          jq -r '.[] | select(.entity_id | contains("{{domain}}")) | "\(.entity_id): \(.state)"'

  - name: turn_on
    description: Turn on any entity (light, switch, etc.)
    parameters:
      - name: entity_id
        type: string
        required: true
    script:
      shell: |
        curl -X POST -H "Authorization: Bearer ${HA_TOKEN}" \
          -H "Content-Type: application/json" \
          http://homeassistant.local:8123/api/services/homeassistant/turn_on \
          -d '{"entity_id": "{{entity_id}}"}'

  - name: turn_off
    description: Turn off any entity
    parameters:
      - name: entity_id
        type: string
        required: true
    script:
      shell: |
        curl -X POST -H "Authorization: Bearer ${HA_TOKEN}" \
          -H "Content-Type: application/json" \
          http://homeassistant.local:8123/api/services/homeassistant/turn_off \
          -d '{"entity_id": "{{entity_id}}"}'

  - name: set_thermostat
    description: Set thermostat temperature
    parameters:
      - name: entity_id
        type: string
        required: true
      - name: temperature
        type: number
        required: true
    script:
      shell: |
        curl -X POST -H "Authorization: Bearer ${HA_TOKEN}" \
          -H "Content-Type: application/json" \
          http://homeassistant.local:8123/api/services/climate/set_temperature \
          -d '{"entity_id": "{{entity_id}}", "temperature": {{temperature}}}'

  - name: run_scene
    description: Activate a scene
    parameters:
      - name: scene_id
        type: string
        required: true
    script:
      shell: |
        curl -X POST -H "Authorization: Bearer ${HA_TOKEN}" \
          -H "Content-Type: application/json" \
          http://homeassistant.local:8123/api/services/scene/turn_on \
          -d '{"entity_id": "scene.{{scene_id}}"}'

  - name: garage_door_status
    description: Check if garage door is open or closed
    parameters: []
    script:
      shell: |
        curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
          http://homeassistant.local:8123/api/states/cover.garage_door | jq -r '.state'
```

## Running it

Start your MCP server:

```bash
gantz run --auth
```

Now you can connect Claude to it. Here's a quick Python script:

```python
import anthropic

client = anthropic.Anthropic()

response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    system="You control a smart home. Use the available tools to help the user. Always confirm what you did.",
    messages=[{"role": "user", "content": "Turn off all the lights in the living room"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://your-tunnel.gantz.run/sse",
        "name": "home",
        "authorization_token": "your-auth-token"
    }],
    tools=[{"type": "mcp_toolset", "mcp_server_name": "home"}],
    betas=["mcp-client-2025-11-20"]
)

for block in response.content:
    if hasattr(block, "text"):
        print(block.text)
```

## What you can ask

Once it's running, Claude understands context:

```text
"Turn off the living room lights"
→ Claude lists lights, finds living room ones, turns them off

"Make it cozy in here"
→ Dims lights, maybe activates a scene

"Is anything left on downstairs?"
→ Checks all lights/switches on first floor

"Set the house to away mode"
→ Turns off lights, adjusts thermostat, checks doors

"It's too hot"
→ Lowers thermostat
```

Claude figures out which tools to use based on what you ask.

## Taking it further

Some ideas:

**Routines:**
- "Goodnight" → Turn off all lights, lock doors, set thermostat
- "Movie time" → Dim lights, turn on TV

**Monitoring:**
- "Alert me if the garage is open for more than 10 minutes"
- Add a sensor checking tool

**Multi-room:**
- "Turn off everything except the bedroom"
- Claude loops through devices

**Voice:**
- Pipe speech-to-text into your script
- Now you have a custom voice assistant

## Why this is cool

You're not locked into Alexa or Google's ecosystem. Any device with an API works. Mix and match however you want.

And because it's Claude, you can ask things naturally:

- "The baby is sleeping, make sure her room stays quiet"
- "I'm leaving in 10 minutes, start warming up the car"
- "Something feels wrong, check all the sensors"

It's not just on/off commands - it's reasoning about your home.

## Troubleshooting

### "Connection refused" or "No route to host"

Your MCP server can't reach the smart home device. Check:
- Is the device on the same network as your MCP server?
- Is the IP address correct? (Devices sometimes change IPs)
- Is there a firewall blocking local traffic?

### Claude uses wrong tool

Your tool descriptions might be ambiguous. Be specific:

```yaml
# Bad - Claude might confuse these
- name: turn_on
  description: Turn on

# Good - Clear when to use each
- name: turn_on_light
  description: Turn on a light. Use when user asks to turn on, switch on, or enable a light.

- name: turn_on_outlet
  description: Turn on a smart outlet/plug. Use for non-light devices like fans or appliances.
```

### Hue bridge not responding

Hue bridges sometimes go to sleep. Try:
1. Access the bridge directly: `curl http://BRIDGE_IP/api`
2. Check your token is still valid
3. Press the bridge button and regenerate token if needed

### Home Assistant "401 Unauthorized"

Your long-lived access token might have expired. Generate a new one:
1. Go to your HA profile
2. Scroll to "Long-Lived Access Tokens"
3. Create new token and update your environment variable

## Running 24/7

For a permanent setup, run Gantz as a service.

### On Raspberry Pi / Linux

Create `/etc/systemd/system/smart-home-mcp.service`:

```ini
[Unit]
Description=Smart Home MCP Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/smart-home
EnvironmentFile=/home/pi/smart-home/.env
ExecStart=/usr/local/bin/gantz run --auth
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable smart-home-mcp
sudo systemctl start smart-home-mcp
```

### Using Docker

```dockerfile
FROM golang:alpine AS builder
RUN go install github.com/gantz-ai/gantz-cli/cmd/gantz@latest

FROM alpine
COPY --from=builder /go/bin/gantz /usr/local/bin/
COPY gantz.yaml /app/
WORKDIR /app
CMD ["gantz", "run", "--auth"]
```

## Security notes

Smart home control requires extra care. You're exposing physical device control.

### Do this:
- **Always use `--auth` flag** - Don't let random people control your home
- **Keep your tunnel URL private** - Don't share it publicly
- **Start with read-only tools** - Get states before controlling
- **Limit destructive actions** - Maybe don't expose "unlock front door"
- **Run on isolated network** - Consider a separate VLAN for IoT devices

### Don't do this:
- Don't expose garage door or lock controls without careful thought
- Don't share your tunnel URL in public channels
- Don't run without authentication
- Don't use this for security-critical automation (alarms, etc.)

## Related reading

- [Let AI Agents Read and Respond to Your Emails](/post/ai-email-assistant/) - Another automation tutorial
- [Build a Slack Bot with MCP](/post/slack-bot-mcp/) - Team communication automation
- [Your First AI Agent in 15 Minutes](/post/first-agent/) - Getting started with agents

---

*What would you connect Claude to? I'm thinking coffee machine next.*
