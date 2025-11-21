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

import 'package:genui/src/local_agent/model_adapter.dart';
import 'package:genui/src/model/chat_message.dart';
import 'package:genui/src/model/tools.dart';
import 'package:genui/src/primitives/logging.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as google_ai;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf;

import 'google_content_converter.dart';
import 'google_generative_service_interface.dart';
import 'google_schema_adapter.dart';

/// A [ModelAdapter] for the Google Cloud Generative Language API.
class GoogleModelAdapter
    implements
        ModelAdapter<
          google_ai.Tool,
          google_ai.Content,
          google_ai.GenerateContentResponse
        > {
  final GoogleContentConverter _converter = GoogleContentConverter();
  final GoogleSchemaAdapter _adapter = GoogleSchemaAdapter();
  final GoogleGenerativeServiceInterface _service;
  final String _modelName;

  /// Creates a new [GoogleModelAdapter].
  GoogleModelAdapter({
    required GoogleGenerativeServiceInterface service,
    required String modelName,
  }) : _service = service,
       _modelName = modelName;

  @override
  List<google_ai.Tool> adaptTools(List<AiTool> tools) {
    final functionDeclarations = <google_ai.FunctionDeclaration>[];
    for (final tool in tools) {
      google_ai.Schema? adaptedParameters;
      if (tool.parameters != null) {
        final result = _adapter.adapt(tool.parameters!);
        if (result.errors.isNotEmpty) {
          genUiLogger.warning(
            'Errors adapting parameters for tool ${tool.name}: '
            '${result.errors.join('\n')}',
          );
        }
        adaptedParameters = result.schema;
      }
      functionDeclarations.add(
        google_ai.FunctionDeclaration(
          name: tool.name,
          description: tool.description,
          parameters: adaptedParameters,
        ),
      );
    }

    return functionDeclarations.isNotEmpty
        ? [google_ai.Tool(functionDeclarations: functionDeclarations)]
        : [];
  }

  @override
  List<google_ai.Content> convertMessages(Iterable<ChatMessage> messages) {
    return _converter.toGoogleAiContent(messages);
  }

  @override
  Future<google_ai.GenerateContentResponse> generateContent(
    List<google_ai.Content> content,
    List<google_ai.Tool> tools,
  ) {
    final request = google_ai.GenerateContentRequest(
      model: _modelName,
      contents: content,
      tools: tools,
      toolConfig: google_ai.ToolConfig(
        functionCallingConfig: google_ai.FunctionCallingConfig(
          mode: google_ai.FunctionCallingConfig_Mode.auto,
        ),
      ),
    );
    return _service.generateContent(request);
  }

  @override
  ModelTurnResult processResponse(google_ai.GenerateContentResponse response) {
    if (response.candidates == null || response.candidates!.isEmpty) {
      genUiLogger.warning(
        'Response has no candidates: ${response.promptFeedback}',
      );
      return ModelTurnResult(toolCalls: [], text: '');
    }

    final candidate = response.candidates!.first;
    final functionCalls = <google_ai.FunctionCall>[];
    if (candidate.content?.parts != null) {
      for (final part in candidate.content!.parts!) {
        if (part.functionCall != null) {
          functionCalls.add(part.functionCall!);
        }
      }
    }

    final toolCalls = functionCalls
        .map(
          (fc) => ToolCall(
            id: fc.name!,
            name: fc.name!,
            arguments: fc.args?.toJson() as Map<String, Object?>? ?? {},
          ),
        )
        .toList();

    String? text;
    if (candidate.content?.parts != null) {
      final textParts = candidate.content!.parts!
          .where((google_ai.Part p) => p.text != null)
          .map((google_ai.Part p) => p.text!)
          .toList();
      text = textParts.join('');
    }

    return ModelTurnResult(toolCalls: toolCalls, text: text);
  }

  @override
  List<google_ai.Content> adaptToolResults(List<ToolResult> toolResults) {
    final functionResponseParts = toolResults
        .map(
          (tr) => google_ai.Part(
            functionResponse: google_ai.FunctionResponse(
              name: tr.toolCallId,
              response: protobuf.Struct.fromJson(tr.result),
            ),
          ),
        )
        .toList();
    return [google_ai.Content(role: 'tool', parts: functionResponseParts)];
  }
}
