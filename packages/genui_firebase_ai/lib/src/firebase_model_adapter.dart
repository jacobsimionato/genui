// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

import 'package:firebase_ai/firebase_ai.dart';
import 'package:genui/src/local_agent/model_adapter.dart';
import 'package:genui/src/model/chat_message.dart';
import 'package:genui/src/model/tools.dart';
import 'package:genui/src/primitives/logging.dart';

import 'gemini_content_converter.dart';
import 'gemini_generative_model.dart';
import 'gemini_schema_adapter.dart';

/// A [ModelAdapter] for the Firebase AI API.
class FirebaseModelAdapter
    implements ModelAdapter<Tool, Content, GenerateContentResponse> {
  final GeminiContentConverter _converter = GeminiContentConverter();
  final GeminiSchemaAdapter _adapter = GeminiSchemaAdapter();
  final GeminiGenerativeModelInterface _model;

  /// Creates a new [FirebaseModelAdapter].
  FirebaseModelAdapter({required GeminiGenerativeModelInterface model})
    : _model = model;

  @override
  List<Tool> adaptTools(List<AiTool> tools) {
    final functionDeclarations = <FunctionDeclaration>[];
    for (final tool in tools) {
      Schema? adaptedParameters;
      if (tool.parameters != null) {
        final GeminiSchemaAdapterResult result = _adapter.adapt(
          tool.parameters!,
        );
        if (result.errors.isNotEmpty) {
          genUiLogger.warning(
            'Errors adapting parameters for tool ${tool.name}: '
            '${result.errors.join('\n')}',
          );
        }
        adaptedParameters = result.schema;
      }
      final Map<String, Schema>? parameters = adaptedParameters?.properties;
      functionDeclarations.add(
        FunctionDeclaration(
          tool.name,
          tool.description,
          parameters: parameters ?? const {},
        ),
      );
    }

    final List<Tool>? generativeAiTools = functionDeclarations.isNotEmpty
        ? [Tool.functionDeclarations(functionDeclarations)]
        : null;

    return generativeAiTools ?? [];
  }

  @override
  List<Content> convertMessages(Iterable<ChatMessage> messages) {
    return _converter.toFirebaseAiContent(messages);
  }

  @override
  Future<GenerateContentResponse> generateContent(
    List<Content> content,
    List<Tool> tools,
  ) {
    return _model.generateContent(content);
  }

  @override
  ModelTurnResult processResponse(GenerateContentResponse response) {
    if (response.candidates.isEmpty) {
      genUiLogger.warning(
        'Response has no candidates: ${response.promptFeedback}',
      );
      return ModelTurnResult(toolCalls: [], text: '');
    }

    final Candidate candidate = response.candidates.first;
    final List<FunctionCall> functionCalls = candidate.content.parts
        .whereType<FunctionCall>()
        .toList();

    final List<ToolCall> toolCalls = functionCalls
        .map((fc) => ToolCall(id: fc.name, name: fc.name, arguments: fc.args))
        .toList();

    return ModelTurnResult(toolCalls: toolCalls, text: candidate.text);
  }

  @override
  List<Content> adaptToolResults(List<ToolResult> toolResults) {
    final List<FunctionResponse> functionResponses = toolResults
        .map((tr) => FunctionResponse(tr.toolCallId, tr.result))
        .toList();
    return [Content.functionResponses(functionResponses)];
  }
}
