# Zero to A2A

## 1. Antigravity
You'll need at least one Antigravity tool (Antigravity 2.0, Antigravity CLI, or Antigravity Extensions for IDE). Visit [antigravity.google](https://antigravity.google) to install. Then log in. (If using Antigravity as part of Gemini Enterprise, be sure to login using "Use business account" / "Continue with Google Cloud")

#### Install helper packages

* **Agents skills:** `uvx google-agents-cli setup`
* **Antigravity plugin for GCP:** `agy plugin install https://github.com/google/skills/plugins/cloud/google-cloud-developer`

## 2. Verify required system packages, roles, and authentication to GCP
```
./verify.sh
```

On your GCP project...

* Ensure that your user has the roles `roles/discoveryengine.admin` and `roles/aiplatform.user`
* Ensure that the following APIs are enabled: 

```
gcloud auth application-default login
```

## 3. Let's agent!

Use the following series of prompts to create an agent, enhance it with features like memory, and deploy it to GCP Agent Runtime. 

### Basic agent bootstrapping
Start a `/grill-me` session, then paste the following prompt and answer the questions; review the implementation plan and revise as needed, then proceed.

```
Create an agent named **Me Time**, in folder `agents/me-time`. Its purpose is to help the user make the best use of their time throughout the day. In its initial formulation, it should not attempt to retrieve any external information or ask any details about the user. It should simply return a generic message that encourages the user to be mindful and goal oriented. 

Use ADK to bootstrap the agent, and prepare it to deploy to Agent Runtime, but do not deploy it. Do not create evaluations. Use Gemini 3.8 Flash with Medium thinking for all LLM calls. Use Application Default Credentials (not an API Key) to authenticate to Google Cloud. Run the agent locally, using `agents-cli`.
```

_Open the agent on localhost and test it_

### Add sub-agents
Start a `/grill-me` session, then paste the following prompt and answer the questions; review the implementation plan and revise as needed, then proceed.

```
Add functionality using the ADK workflow mechanism:
- first, prompt for the user's location if you don't already know it
- then pass this information to two subagents in parallel:
  1. Outdoor optimizer: based on the user's location, use a Google Search tool to identify what time of day would offer the best weather to get outside and take a rejuvenating walk.
  2. Local events: based on the user's location, use a Google Search tool to suggest events (cultural events, interesting sights to see, etc.) that the user might want to visit
- when both subagents have completed, return a brief suggested itinerary for the day. Restart the agent locally.
```

_Open the agent on localhost and test it_

### Deploy to Agent Runtime
```
Deploy to Agent Runtime
```

_Open Google Cloud Console, then navigate to Agent Runtime, and test it out_

### Add memory
Start a `/grill-me` session, then paste the following prompt and answer the questions; review the implementation plan and revise as needed, then proceed.

```
Add memory to the agent: use a memory service to remember the following information:
- the user's location
- any preferences about activities that they provide

When returning the user's daily agenda, add a note to let the user know that they can provide feedback about the proposed agenda. If the user provides feedback, store it as a memory and use it to inform subsequent agent invocations.

When running the agent locally, use an in-memory Memory service. When running on Agent Runtime, use the Memory Bank service. Restart the agent locally.
```

_Open the agent on localhost and test it_

### Deploy to Agent Runtime
```
Deploy to Agent Runtime
```

_Open Google Cloud Console, then navigate to Agent Runtime, and test it out_

### Add a schedule agent via A2A
Start a `/grill-me` session, then paste the following prompt and answer the questions; review the implementation plan and revise as needed, then proceed.
```
Create another agent, in folder `agents/schedule`. Its purpose is to provide the me-time agent with information about the user's schedule. Use a mock schedule with three events: {"10:30":"standup meeting","12:30":"lunch with D","4:30":"File expenses"}. Make this agent available via A2A.

Update the me-time agent to accept an environment variable which contains the URL of the sechedule agent's Agent Card. Update the me-time agent to invoke the schedule agent via A2A in parallel with the "outdoor optimizer" and "local events" agents. Use the information about the user's schedule to inform their daily agenda.

Run the schedule agent locally using `agents-cli`, and restart the schedule agent.
```

### Deploy to Agent Runtime
```
Deploy the schedule agent to Agent Runtime. Retrieve its A2A card, then redeploy the me-time agent, passing the Agent Card URL of the schedule agent to the me-time agent.
```

_Open Google Cloud Console, then navigate to Agent Runtime, and test it out_

### Add evaluations
Start a `/grill-me` session, then paste the following prompt and answer the questions; review the implementation plan and revise as needed, then proceed.
```
Create evaluations for the me-time agent. Run the evaluation suite and report its success.
```

### Optional: Register with Gemini Enterprise

1. Determine your Gemini Enterprise App ID -- find it in the cloud console. 

2. Run the following prompt in Antigravity, and follow any instructions it provides:
```
Register the `me-time` agent with the Gemini Enterprise app `<APP_ID>`
```

### Optional: optimize performance

1. Nativate to the "Traces" tab panel in the Agent Runtime Deployments page for `me-time`. Open a trace and copy the Trace JSON data.

2. Start a `/grill-me` session in Antigravity, run the following prompt, and answer any questions:
```
Review the following trace data and recommend performance improvements: `<TRACE_DATA>`
```