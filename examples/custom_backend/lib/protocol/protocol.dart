// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_genui/flutter_genui.dart';
import 'package:flutter_genui/src/model/a2ui_message.dart';
import 'package:flutter_genui/src/model/a2ui_schemas.dart';

import '../backend/api.dart';
import '../backend/model.dart';
import '../debug_utils.dart';
import '../main.dart';

class Protocol {
  Future<List<A2uiMessage>?> sendRequest(
    String request, {
    required String? savedResponse,
  }) async {
    final tools = [_functionDeclaration()];

    final toolCall = await Backend.sendRequest(
      tools,
      _prompt(request),
      savedResponse: savedResponse,
    );

    if (toolCall == null || toolCall.name != _toolName) {
      return null;
    }

    debugSaveToFileObject('toolCall', toolCall);

    final messageJson = {'surfaceUpdate': toolCall.args};
    final surfaceUpdateMessage = A2uiMessage.fromJson(messageJson);

    final beginRenderingMessage = BeginRendering(
      surfaceId: kSurfaceId,
      root: 'root',
    );

    return [surfaceUpdateMessage, beginRenderingMessage];
  }

  Catalog get catalog => _catalog;
}

const _toolName = 'surfaceUpdate';

final _catalog = CoreCatalogItems.asCatalog();

String _prompt(String request) =>
    '''
You are a helpful assistant that provides concise and relevant information.
Always respond in a clear and structured manner.
Always respond with generated UI.
Use the tool $_toolName to generate UI code snippets to satisfy user request.
Ensure one of the generated components has an id of 'root'.

Use the surfaceId: '$kSurfaceId'

Use the root component ID: 'root'

User request: $request
''';

FunctionDeclaration _functionDeclaration() {
  return FunctionDeclaration(
    description: 'Generates UI.',
    name: _toolName,
    parameters: A2uiSchemas.surfaceUpdateSchema(_catalog),
  );
}
