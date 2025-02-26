import 'dart:math';

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;

  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  normA = sqrt(normA);
  normB = sqrt(normB);

  if (normA == 0.0 || normB == 0.0) return 0.0;

  return dotProduct / (normA * normB);
}
