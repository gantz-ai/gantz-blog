+++
title = 'Let Claude control your smart home'
date = 2025-12-28
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Last weekend I got Claude to turn off my lights. Not through some official integration — just MCP and a few shell scripts.

Here's the setup.

## The goal

Talk to Claude naturally and have it control my home:

- "Turn off the living room lights"
- "Set the thermostat to 72"
- "Is the garage door open?"
- "Dim the bedroom lights to 30%"

No special apps. No voice assistant. Just Claude with access to my local tools.

## How it works

Most smart home stuff has APIs or CLI tools. If you can control it from terminal, Claude can control it through MCP.

```
You → Claude → MCP Server (your machine) → Smart home API → Device
```

## What you'll need

- Smart home devices with API access (Hue, Home Assistant, etc.)
- [Gantz CLI](https://gantz.run)
- 30 minutes

I'll show examples for Philips Hue and Home Assistant, but this works with anything that has an API.

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

```
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

It's not just on/off commands — it's reasoning about your home.

## Security notes

- Always use `--auth` flag
- Keep your tunnel URL private
- Consider read-only tools first
- Be careful with locks/garage doors

---

*What would you connect Claude to? I'm thinking coffee machine next.*
