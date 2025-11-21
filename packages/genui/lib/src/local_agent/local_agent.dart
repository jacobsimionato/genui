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
// Unless required by applicable law_ or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import '../../genui.dart';
import 'model_adapter.dart';

/// A local agent that orchestrates the tool-calling loop.
class LocalAgent<TTool, TContent, TResponse> {
  final ModelAdapter<TTool, TContent, TResponse> _adapter;
  final ToolRegistry _toolRegistry;

  /// Creates a new [LocalAgent].
  LocalAgent({
    required ModelAdapter<TTool, TContent, TResponse> adapter,
    required ToolRegistry toolRegistry,
  }) : _adapter = adapter,
       _toolRegistry = toolRegistry;

  /// Executes the agent with the given messages.
  Future<String?> execute(Iterable<ChatMessage> messages) async {
    final List<ChatMessage> history = messages.toList();
    var stop = false;
    while (!stop) {
      final response = await _adapter.generateContent(
        _adapter.convertMessages(history),
        _adapter.adaptTools(_toolRegistry.tools),
      );
      final ModelTurnResult result = _adapter.processResponse(response);

      if (result.toolCalls.isNotEmpty) {
        final List<ToolResult> toolResults = await Future.wait(
          result.toolCalls.map(_toolRegistry.execute),
        );
        history.add(ChatMessage.toolResults(toolResults));
      } else {
        stop = true;
        return result.text;
      }
    }
    return null;
  }
}
