+++
title = "The Voice-First Agent: No Typing Required"
date = 2025-11-19
description = "Build voice-controlled AI agents with speech-to-text and text-to-speech. Tutorial for hands-free interaction with MCP tools and local commands."
image = "images/robot-billboard-10.webp"
draft = false
tags = ['tutorial', 'architecture', 'deep-dive']
+++


I built an agent I could talk to while cooking.

"Hey, what's the status of the deployment?"

"Deployment completed 10 minutes ago. All 47 tests passed. The API is live."

No keyboard. No screen. Just voice.

Here's how to build one.

## Why voice?

Typing requires:
- Hands free
- Eyes on screen
- Full attention

Voice works when:
- Your hands are busy (cooking, driving, building)
- You're away from your desk
- You want quick answers, not long sessions
- Accessibility needs

Different interface, different design.

## The architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Speech    │     │    Agent    │     │   Speech    │
│   to Text   │────▶│    Loop     │────▶│   to Text   │
│   (STT)     │     │             │     │   (TTS)     │
└─────────────┘     └─────────────┘     └─────────────┘
      ▲                   │                    │
      │                   ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Microphone  │     │   Tools     │     │   Speaker   │
└─────────────┘     └─────────────┘     └─────────────┘
```

Same agent loop you know. Just different I/O.

## Basic implementation

```python
import openai
import subprocess
from pathlib import Path

client = openai.OpenAI()

def speech_to_text(audio_file):
    """Convert speech to text using Whisper"""
    with open(audio_file, "rb") as f:
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=f
        )
    return transcript.text

def text_to_speech(text, output_file="response.mp3"):
    """Convert text to speech"""
    response = client.audio.speech.create(
        model="tts-1",
        voice="nova",
        input=text
    )
    response.stream_to_file(output_file)
    return output_file

def play_audio(file_path):
    """Play audio file"""
    subprocess.run(["afplay", file_path])  # macOS
    # subprocess.run(["aplay", file_path])  # Linux
    # subprocess.run(["start", file_path], shell=True)  # Windows

def agent_respond(user_text, tools):
    """Standard agent loop"""
    messages = [
        {"role": "system", "content": VOICE_SYSTEM_PROMPT},
        {"role": "user", "content": user_text}
    ]

    while True:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            tools=tools
        )

        message = response.choices[0].message

        if not message.tool_calls:
            return message.content

        # Execute tools
        for tool_call in message.tool_calls:
            result = execute_tool(tool_call)
            messages.append({"role": "tool", "content": result, ...})

        messages.append(message)

def voice_agent_loop():
    """Main voice loop"""
    while True:
        print("Listening...")
        audio_file = record_audio()  # Record until silence

        user_text = speech_to_text(audio_file)
        print(f"You: {user_text}")

        if "goodbye" in user_text.lower() or "exit" in user_text.lower():
            play_audio(text_to_speech("Goodbye!"))
            break

        response_text = agent_respond(user_text, tools)
        print(f"Agent: {response_text}")

        audio_response = text_to_speech(response_text)
        play_audio(audio_response)
```

## The voice system prompt

Voice needs different instructions:

```python
VOICE_SYSTEM_PROMPT = """
You are a voice-controlled coding assistant.

IMPORTANT - Your responses will be spoken aloud:
- Keep responses SHORT (1-3 sentences)
- Don't use markdown, code blocks, or formatting
- Don't use bullet points or numbered lists
- Speak naturally, like a conversation
- Don't spell out URLs or file paths character by character
- Round numbers ("about 50 files" not "47 files")
- Say "check mark" not "✓"

When reporting code or technical details:
- Summarize, don't read code verbatim
- "The function looks correct" not "def calculate_total..."
- "Line 47 has a syntax error" not the full line content
- For file contents, describe what you found

If the user needs to see details, say:
"I found the issue. Check your terminal for details."
Then output details to a file or clipboard.
"""
```

Compare:

```
Text agent:
"Here are the failing tests:
- test_login_valid: AssertionError on line 23
- test_logout: TimeoutError after 30s
- test_session: KeyError 'user_id'"

Voice agent:
"Three tests are failing. The login test has an assertion error,
logout is timing out, and there's a missing user ID in the session test.
Want me to look at any of them?"
```

Same information, different delivery.

## Handling latency

Voice users expect instant responses. But STT → Agent → TTS takes time.

### Strategy 1: Acknowledgment sounds

```python
def voice_agent_loop():
    while True:
        audio_file = record_audio()

        # Immediate acknowledgment
        play_audio("sounds/thinking.mp3")  # Short "hmm" sound

        user_text = speech_to_text(audio_file)
        response_text = agent_respond(user_text, tools)

        # Cancel thinking sound if still playing
        stop_audio()

        audio_response = text_to_speech(response_text)
        play_audio(audio_response)
```

### Strategy 2: Streaming TTS

```python
def stream_response(text):
    """Start speaking before full response is ready"""
    sentences = split_into_sentences(text)

    for sentence in sentences:
        audio = text_to_speech(sentence)
        play_audio(audio)  # Speak while generating next
```

### Strategy 3: Chunked responses

```python
VOICE_SYSTEM_PROMPT += """
For complex answers, give a quick summary first, then ask if they want details.

Good: "The build failed. Type error in the auth module. Want me to explain?"
Bad: "The build failed because on line 47 of auth.ts there's a type error where..."
"""
```

Quick answer first, details on request.

## Tools for voice

Some tools work great for voice. Others don't.

### Voice-friendly tools

```yaml
# Good for voice - returns simple status
- name: check_status
  description: Check if services are running
  # Returns: "API is up, database is up, cache is down"

- name: run_tests
  description: Run tests and report pass/fail count
  # Returns: "23 passed, 2 failed"

- name: deploy_status
  description: Check deployment status
  # Returns: "Deployed 10 minutes ago, healthy"

- name: count_files
  description: Count files matching pattern
  # Returns: "47 Python files"
```

### Voice-unfriendly tools (need adaptation)

```yaml
# Bad for voice - returns too much text
- name: read_file
  # Returns 500 lines of code - can't speak that

# Adapted version
- name: summarize_file
  description: Describe what a file does
  # Returns: "This is the main entry point. It sets up the server and routes."

# Bad for voice - returns structured data
- name: git_log
  # Returns commit hashes, dates, messages

# Adapted version
- name: recent_changes
  description: Summarize recent git activity
  # Returns: "3 commits today. Last one fixed the login bug."
```

### Voice-specific tools

```yaml
- name: save_to_clipboard
  description: Save detailed output to clipboard so user can paste later
  # Voice: "Saved to your clipboard"

- name: open_file
  description: Open a file in the default editor
  # Voice: "Opened auth.ts in your editor"

- name: send_details
  description: Send detailed output to terminal/file for later review
  # Voice: "Details are in your terminal"
```

## Handling transcription errors

Speech-to-text isn't perfect. Design for errors.

### Common mishears

```python
CORRECTIONS = {
    "cash": "cache",
    "get": "git",
    "jason": "JSON",
    "sequel": "SQL",
    "no js": "Node.js",
    "pie test": "pytest",
    "just": "Jest",
    "doctor": "Docker",
    "cube control": "kubectl",
}

def fix_transcription(text):
    for wrong, right in CORRECTIONS.items():
        text = text.replace(wrong, right)
    return text
```

### Confirmation for destructive actions

```python
def agent_respond(user_text, tools):
    response = get_agent_response(user_text, tools)

    # Always confirm destructive actions by voice
    if needs_voice_confirmation(response):
        return f"I'm about to {response['action']}. Say 'yes' to confirm or 'no' to cancel."

    return response

def needs_voice_confirmation(response):
    destructive = ["delete", "remove", "drop", "reset", "push --force"]
    return any(d in str(response).lower() for d in destructive)
```

Mishearing "delete the log" as "delete the blog" would be bad.

### Ask for clarification

```python
VOICE_SYSTEM_PROMPT += """
If the request is ambiguous or you're unsure what was said, ask for clarification.

Good: "Did you say 'cache' or 'catch'?"
Good: "Delete what files? The logs or the tests?"
Bad: *assumes and deletes wrong thing*
"""
```

## Wake word detection

For hands-free, always-on mode:

```python
import pvporcupine
import pyaudio
import struct

def listen_for_wake_word():
    """Listen for 'Hey computer' wake word"""
    porcupine = pvporcupine.create(keywords=["computer"])

    pa = pyaudio.PyAudio()
    stream = pa.open(
        rate=porcupine.sample_rate,
        channels=1,
        format=pyaudio.paInt16,
        input=True,
        frames_per_buffer=porcupine.frame_length
    )

    print("Listening for wake word...")

    while True:
        pcm = stream.read(porcupine.frame_length)
        pcm = struct.unpack_from("h" * porcupine.frame_length, pcm)

        if porcupine.process(pcm) >= 0:
            print("Wake word detected!")
            return True

def always_on_voice_agent():
    """Always listening, activates on wake word"""
    while True:
        listen_for_wake_word()
        play_audio("sounds/ready.mp3")

        audio = record_until_silence()
        response = process_voice_command(audio)

        play_audio(response)
        # Go back to listening for wake word
```

Now you can say "Hey computer, run the tests" from across the room.

## Conversation context

Voice conversations are short but need context:

```python
class VoiceAgent:
    def __init__(self):
        self.context = []
        self.max_context = 5  # Keep last 5 exchanges

    def respond(self, user_text):
        self.context.append({"role": "user", "content": user_text})

        # Trim context
        if len(self.context) > self.max_context * 2:
            self.context = self.context[-self.max_context * 2:]

        response = self.get_response(self.context)

        self.context.append({"role": "assistant", "content": response})
        return response
```

Allows follow-ups:

```
User: "Run the tests"
Agent: "2 tests failed. The login tests."

User: "What's wrong with them?"  # References previous
Agent: "The login test expects a 200 but gets 401. Looks like auth is failing."

User: "Fix it"  # Still in context
Agent: "Fixed. The API key was missing from the test environment."
```

## Full working example

```python
import openai
import pyaudio
import wave
import io

client = openai.OpenAI()

# Tools simplified for voice
tools = [
    {
        "type": "function",
        "function": {
            "name": "check_tests",
            "description": "Run tests and report results",
            "parameters": {}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "check_status",
            "description": "Check if the app is running",
            "parameters": {}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "recent_changes",
            "description": "What changed recently in git",
            "parameters": {}
        }
    }
]

SYSTEM = """
You are a voice assistant for developers.
Keep responses under 2 sentences.
Be conversational and concise.
"""

def record_audio(duration=5):
    """Record audio from microphone"""
    p = pyaudio.PyAudio()
    stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000,
                    input=True, frames_per_buffer=1024)

    print("🎤 Recording...")
    frames = []
    for _ in range(0, int(16000 / 1024 * duration)):
        frames.append(stream.read(1024))

    stream.stop_stream()
    stream.close()
    p.terminate()

    # Save to buffer
    buffer = io.BytesIO()
    wf = wave.open(buffer, 'wb')
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    wf.writeframes(b''.join(frames))
    wf.close()
    buffer.seek(0)
    buffer.name = "audio.wav"

    return buffer

def main():
    print("Voice Agent Ready. Speak after the beep.")
    context = []

    while True:
        audio = record_audio()

        # STT
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio
        ).text

        print(f"You: {transcript}")

        if "goodbye" in transcript.lower():
            break

        # Agent
        context.append({"role": "user", "content": transcript})
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "system", "content": SYSTEM}] + context,
            tools=tools
        )

        reply = response.choices[0].message.content or "Done."
        context.append({"role": "assistant", "content": reply})

        print(f"Agent: {reply}")

        # TTS
        speech = client.audio.speech.create(
            model="tts-1",
            voice="nova",
            input=reply
        )
        speech.stream_to_file("response.mp3")
        subprocess.run(["afplay", "response.mp3"])

if __name__ == "__main__":
    main()
```

## Voice + Gantz

You can build voice-controlled tools with [Gantz](https://gantz.run):

```yaml
# gantz.yaml - Voice-friendly tools
tools:
  - name: status
    description: Quick status check. Returns one sentence.
    script:
      shell: |
        if curl -s localhost:3000/health > /dev/null; then
          echo "App is running"
        else
          echo "App is down"
        fi

  - name: tests
    description: Run tests. Returns pass/fail summary.
    script:
      shell: |
        result=$(npm test 2>&1)
        passed=$(echo "$result" | grep -c "✓" || echo "0")
        failed=$(echo "$result" | grep -c "✗" || echo "0")
        echo "$passed passed, $failed failed"

  - name: changes
    description: Recent git changes. Returns brief summary.
    script:
      shell: |
        count=$(git log --oneline -24h | wc -l)
        last=$(git log -1 --format="%s")
        echo "$count commits today. Last one: $last"
```

Short outputs designed for voice.

## Summary

Voice agents need different design:

| Aspect | Text Agent | Voice Agent |
|--------|-----------|-------------|
| Response length | Any length | 1-3 sentences |
| Formatting | Markdown, code blocks | Plain speech |
| Numbers | Exact (47 files) | Rounded (about 50) |
| Tool output | Full details | Summaries |
| Confirmation | Type 'yes' | Say 'yes' |
| Errors | Show stack trace | "Something went wrong with auth" |
| Details | Inline | "Check your terminal" |

The same agent loop, different I/O, different UX.

Talk to your code.

## Related reading

- [Let AI Agents Read and Respond to Your Emails](/post/ai-email-assistant/) - Another automation interface
- [Your First AI Agent in 15 Minutes](/post/first-agent/) - Getting started with agents
- [When to Use Human-in-the-Loop](/post/human-in-the-loop/) - Adding confirmations

---

*Have you built a voice interface for development tools? What worked?*
