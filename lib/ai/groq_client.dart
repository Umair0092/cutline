import 'openai_compatible_client.dart';

// Groq speaks the OpenAI chat protocol, so it shares the generalised client.
// Re-exported so existing imports of this file keep working.
export 'openai_compatible_client.dart'
    show OpenAiCompatibleClient, toOpenAiMessages, toOpenAiTools;

/// Groq's free tier, through its OpenAI-compatible chat API.
class GroqClient extends OpenAiCompatibleClient {
  GroqClient({
    required super.apiKey,
    super.model = 'openai/gpt-oss-120b',
    super.httpClient,
  }) : super(endpoint: endpointUrl, serviceName: 'Groq');

  static const endpointUrl =
      'https://api.groq.com/openai/v1/chat/completions';
}
