import 'dart:async';

/// Exceptions thrown during on-device model lifecycle.
class ModelLoadException implements Exception {
  ModelLoadException(this.message);
  final String message;
  @override
  String toString() => 'ModelLoadException: $message';
}

class InsufficientMemoryException implements Exception {
  InsufficientMemoryException(this.requiredBytes, this.availableBytes);
  final int requiredBytes;
  final int availableBytes;
  @override
  String toString() =>
      'InsufficientMemoryException: Required ${(requiredBytes / (1024 * 1024)).toStringAsFixed(1)} MB, but only ${(availableBytes / (1024 * 1024)).toStringAsFixed(1)} MB available.';
}

/// Abstract contract for local on-device LLM inference engines (llama.cpp, LiteRT-LM, etc.).
abstract interface class ILocalLlmRuntime {
  /// Loads model weights from the local filesystem path.
  Future<void> loadModel({
    required String modelPath,
    int contextSize = 2048,
    int threadCount = 4,
    int maxAvailableMemoryBytes = 1024 * 1024 * 1024 * 4, // 4 GB default limit
  });

  /// Evaluates prompt and generates text response offline.
  Future<(String, int, double)> generate({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
    int maxTokens = 256,
  });

  /// Releases model weights, context buffer, and KV cache from memory.
  Future<void> unload();

  /// True if weights are loaded and ready for inference.
  bool get isLoaded;

  /// Current memory footprint of model weights and KV cache in bytes.
  int get memoryAllocatedBytes;
}
