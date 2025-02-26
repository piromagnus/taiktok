class PaperAnalysisPrompts {
  static const Map<String, Map<String, String>> prompts = {
    'contributions': {
      'prompt':
          '<format>{contribution 1};{contribution 2};{contribution 3}</format>\n You will answer ONLY the contributions. You will just output the text without any special characters at the beginning or end. Summarize the following research paper abstract into exactly 3 main contributions:\n\n\$abstract',
      'description':
          'Extracts the key contributions of the paper as bullet points'
    },
    'tags': {
      'prompt':
          'You are a specialist of Machine Learning and computer science in general. Generate 3 relevant technical tags for this research paper abstract. Return ONLY the tags separated by semi-commas, without any additional text or formatting: \$abstract',
      'description': 'Generates relevant tags and keywords for the paper'
    },
    'problem': {
      'prompt':
          'What is the main problem this paper is trying to solve? Answer in one sentence:',
      'description': 'Identifies the core problem addressed by the paper'
    },
    'task_type': {
      'prompt':
          'What type of machine learning task does this paper address? Answer in one expression (e.g., classification, detection, generation, pose estimation, NLP):',
      'description': 'Determines the primary ML task type'
    }
  };
}

class GeminiConfig {
  static const Map<String, double> config = {
    'temperature': 0.3,
    'topK': 1.0,
    'topP': 1.0
  };
}

/// Function to format the prompt with the abstract
String formatPrompt(String promptType, String abstract) {
  if (!PaperAnalysisPrompts.prompts.containsKey(promptType)) {
    throw ArgumentError('Unknown prompt type: $promptType');
  }

  return '${PaperAnalysisPrompts.prompts[promptType]!['prompt']}\n$abstract';
}
