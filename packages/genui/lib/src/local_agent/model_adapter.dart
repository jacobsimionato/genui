// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import '../../genui.dart';

/// The result of a single turn of a model.
class ModelTurnResult {
  /// The tool calls made by the model.
  final List<ToolCall> toolCalls;

  /// The text response from the model.
  final String? text;

  /// Creates a new [ModelTurnResult].
  ModelTurnResult({required this.toolCalls, this.text});
}

/// An adapter for a specific AI model.
abstract interface class ModelAdapter<TTool, TContent, TResponse> {
  /// Adapts the generic [AiTool]s to the backend-specific tool format.
  List<TTool> adaptTools(List<AiTool> tools);

  /// Converts the generic [ChatMessage]s to the backend-specific content
  /// format.
  List<TContent> convertMessages(Iterable<ChatMessage> messages);

  /// Calls the AI model to generate content.
  Future<TResponse> generateContent(
      List<TContent> content, List<TTool> tools);

  /// Processes the model's response to extract tool calls and text.
  ModelTurnResult processResponse(TResponse response);

  /// Adapts the generic [ToolResult]s to the backend-specific content format.
  List<TContent> adaptToolResults(List<ToolResult> toolResults);
}
