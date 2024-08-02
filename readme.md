# Summary
These scripts are intended to assist in deploying the fully self-hossted Open-WebUI LLM frontend service in full multi-model configuration. They assume at least one Nvidia GPU is present.

This configuration supports:
- ChatGPT-like responsive web app.
- HTTPS upgrade using Nginx proxy.
- Ollama LLM backend.
- Speech-To-Text and Text-To-Speech allows for interactive voice chat.
- Image Generation using Stable Diffusion 3.
- Image analysis using LLAVA models.
- Multi-User capability.
- Persistent data and configuration using external volume mounts.

# Architecture

```
+------------+     +-----------+     +----------------+     +-----------------+
|            |     |           |     |                |     |                 |
|   Client   +---->+   Nginx   +---->+   Open-WebUI   +---->+     Ollama      |
| (External) |     | (443/tcp  |     | (8080/tcp      |     | (11434/tcp      |
|            |     | Public)   |     | Internal Only) |     | Internal Only)  |
+------------+     +-----------+     +---+-------+----+     +-----------------+
                                         |       |
                                         |       |         +------------------+
                                         |       |         |                  |
                                         |       +-------->+ OpenedAI-Speech  |
                                         |                 | (8000/tcp        |
                                         |                 | Internal only)   |
                                         |                 +------------------+
                                         |
                                         |                 +------------------+
                                         |                 |                  |
                                         +---------------->+ Stable-Diffusion |
                                                           | (7860/tcp        |
                                                           | Internal Only)   |
                                                           +------------------+
```

# Explanation of Components:
- **Client**: Connects from outside to Nginx, aka MyGPT.
- **Nginx**: Acts as a TLS proxy on port 443/tcp and forwards traffic to Open-WebUI.
- **Open-WebUI**: Interfaces with the Nginx service and communicates with the Ollama backend. Also provides Ollama API and basic OpenAI API functionality.
- **Ollama**: Processes LLM  requests and provides backend services to Open-WebUI.
- **OpenedAI-Speech**: Provides local TTS via Piper or Coqui. (STT is hosted within Open-WebUI using Whisper)
- **Stable-Diffusion**: Provides image generation capability using Automatic1111's Stable-Diffusion-WebUI.

# Usage
The path to the user data directory should be specified at launch.

`./run-docker-compose.sh --data[folder=/mnt/data] # Starts the services`

`./run-docker-compose.sh --drop # Stops the services`

Point browser to https://127.0.0.1:443
Create an admin account and a user account. Use the user account for most tasks and save the admin account for admin tasks like account activation and recovery.

Navigate to User -> Settings -> Admin Settings -> Connections
Ensure the Ollama backend is set to http://ollama:11434

Navigate to User -> Settings -> Admin Settings -> Models
Download at least one LLM. A good start is `llama3.1:8b`.

# API
Navigate to User -> Settings -> Account and create an API key.
Test the OpenAI API using:
```bash
curl -k -X POST https://127.0.0.1:443/ollama/v1/chat/completions \
-H "Authorization: Bearer INSERT-OPEN-WEBUI-API-KEY" \
-H "Content-Type: application/json" -H "Accept: application/json" \
-d '{  "model": "llama3.1:8b",  "messages": [{"role": "user", "content": "Introduce yourself"}] }'
```
Or with Python...
```python
from openai import OpenAI
import httpx
http_client = httpx.Client(verify=False)

# Initialize OpenAI client with API key
client = OpenAI(base_url='http://127.0.0.1:443/ollama/v1/', 
                api_key='INSERT-OPEN-WEBUI-API-KEY',
                http_client=http_client)

def query_local_api(prompt):
    try:
        # Perform the query using the specified model
        response = client.chat.completions.create(
        model="llama3.1:8b",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt}
        ])
        return response.choices[0].message.content
    except Exception as e:
        return f"An error occurred: {str(e)}"

# The query to send to the model
prompt = "Introduce yourself."
result = query_local_api(prompt)
print(f"Response from the model: {result}")
```

# References
- https://github.com/open-webui/open-webui
- https://ollama.com/
