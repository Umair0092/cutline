# Getting and adding API keys

Cutline works out of the box with a built-in Groq key, but you can add your own
keys to raise limits, switch AI providers, enable GIF search, or use ElevenLabs
voices. Every key is stored in your operating system's keychain — never in the
project file and never sent anywhere except the service it belongs to.

There are three places keys are used:

| Service | What it unlocks | Settings page |
|---------|-----------------|---------------|
| **AI provider** (Groq, Gemini, xAI Grok, Claude, or a custom one) | The assistant that turns your words into edits | **AI assistant** |
| **GIPHY** | Searching GIFs and stickers to drop on the video | **Memes** |
| **ElevenLabs** | Lifelike voices for written voiceovers | **Voiceover** |

To open settings: **Cutline → Settings** (macOS `⌘,`), then pick the page in the
sidebar. Each key page has a **Get a key** link that opens the right signup page
in your browser, a field to paste the key, and a **Save key** button.

---

## Groq (the AI assistant — free to start)

Cutline ships with a shared Groq key, so the assistant works immediately. Add
your own to get your own rate limits.

1. Go to **https://console.groq.com/keys** and sign in (Google/GitHub/email).
2. Click **Create API Key**, give it a name (e.g. "Cutline"), and **Submit**.
3. **Copy the key** — it starts with `gsk_` and is shown only once.
4. In Cutline: **Settings → AI assistant**, make sure **Groq (free)** is the
   selected service, paste the key in the **Groq API key** field, click
   **Save key**. The status dot turns green.

> Keep the key somewhere safe. If you lose it, just create another and delete
> the old one in the Groq console.

## Other AI providers

In **Settings → AI assistant** you can switch the service. Each needs its own
key from its own console:

| Provider | Key starts with | Get a key |
|----------|-----------------|-----------|
| **Google Gemini** | `AIza` | https://aistudio.google.com/apikey |
| **xAI Grok** | `xai-` | https://console.x.ai |
| **Claude** | `sk-ant-` | https://console.anthropic.com |
| **Custom** (any OpenAI-compatible API) | — | your provider's dashboard |

Steps are the same: create the key in the provider's console, copy it, pick that
provider's card in **Settings → AI assistant**, paste, **Save key**. For a
**Custom** provider you also enter the endpoint URL and model id.

---

## GIPHY (GIF and sticker search)

Optional. Without it you can still use your own memes folder; with it you can
search GIPHY from the Memes panel.

1. Go to **https://developers.giphy.com/dashboard/** and sign in or create a
   free account.
2. Click **Create an App** → choose **API** (not SDK) → agree to the terms →
   give it a name → **Create App**.
3. Copy the **API Key** shown for your new app.
4. In Cutline: **Settings → Memes**, paste the key, click **Save key**.

---

## ElevenLabs (lifelike voiceover voices)

Optional. Adds ElevenLabs voices to the voiceover window alongside the system
and Groq voices. ElevenLabs has a free tier with a monthly character limit.

1. Go to **https://elevenlabs.io** and create an account (or sign in).
2. Open **https://elevenlabs.io/app/settings/api-keys** (your name →
   **API Keys**).
3. Click **Create API Key**, name it (e.g. "Cutline"), and copy it — it starts
   with `sk_`.
4. In Cutline: **Settings → Voiceover**, paste the key, click **Save key**.
5. When you **write a voiceover**, pick the **ElevenLabs** tab and choose one of
   your account's voices. Your script text is sent to ElevenLabs to be spoken.

---

## Removing or replacing a key

On any key page, once a key is saved you'll see a **Remove key** (or trash)
button. Removing a key falls back to the built-in one where there is one (Groq),
or turns the feature off (GIPHY, ElevenLabs). To replace a key, just paste a new
one and **Save key** again.

## Where keys are stored

Keys live in your OS keychain (Keychain Access on macOS, Credential Manager on
Windows) under names like `groq_api_key`, `giphy_api_key`, `elevenlabs_api_key`.
They are **not** written into `.cutline` project files, so sharing a project
never shares your keys.
