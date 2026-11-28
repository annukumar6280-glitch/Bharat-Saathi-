# AI Teacher Academy setup

The Flutter screen calls the authenticated Supabase Edge Function `ai-teacher-assistant`. Its deployed source is tracked at `supabase/functions/ai-teacher-assistant/index.ts`.

## Provider configuration

1. Deploy the function as `ai-teacher-assistant` with JWT verification enabled.
2. Set `OPENAI_API_KEY` in Supabase Edge Function Secrets. The current function uses `gpt-4o-mini` as its primary tutor model.
3. The currently deployed function also supports an optional `GEMINI_API_KEY` fallback if OpenAI fails. If the product decision is to run OpenAI only, remove the Gemini fallback from the function before removing that secret.
4. Never put provider keys in Flutter source, Remote Config or the Android APK.

## Voice usage

- Android speech recognition converts the learner's speech to text on the device.
- The recognized text is sent to `ai-teacher-assistant`; spoken answers use Android Text-to-Speech.
- Voice usage is limited to 300 seconds per account per UTC day through `consume_ai_teacher_voice_seconds` and `get_ai_teacher_voice_usage`.
- The session RPC accepts a unique session ID so a pending usage report can be retried without charging the same session twice.

## Release checks

- Verify the Edge Function is active and `OPENAI_API_KEY` is configured.
- Test Hindi and English responses, invalid/oversized prompts, signed-out requests, microphone denial, speech recognition unavailable, and TTS unavailable.
- Do not promise that the AI answer is guaranteed correct; learners should verify important legal, tax, medical or financial information with an appropriate authoritative source.
