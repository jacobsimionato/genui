// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' hide Conversation;

import 'package:travel_app/src/widgets/conversation.dart';

void main() {
  group('Conversation', () {
    late SurfaceController surfaceController;

    setUp(() {
      surfaceController = SurfaceController(
        catalogs: [BasicCatalogItems.asCatalog()],
      );
    });

    testWidgets('renders a list of messages', (WidgetTester tester) async {
      const surfaceId = 's1';
      final messages = <ChatMessage>[
        ChatMessage.user('Hello'),
        ChatMessage.model(
          '',
          parts: [
            UiPart.create(
              definition: SurfaceDefinition(surfaceId: surfaceId),
              surfaceId: surfaceId,
            ),
          ],
        ),
      ];
      final components = [
        const Component(
          id: 'root',
          type: 'Text',
          properties: {'text': 'Hi there!'},
        ),
      ];
      surfaceController.handleMessage(
        UpdateComponents(surfaceId: surfaceId, components: components),
      );
      surfaceController.handleMessage(
        const CreateSurface(surfaceId: surfaceId, catalogId: basicCatalogId),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Conversation(
              messages: messages,
              surfaceController: surfaceController,
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Hi there!'), findsOneWidget);
    });
    testWidgets('renders UserPrompt correctly', (WidgetTester tester) async {
      final messages = [ChatMessage.user('Hello')];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Conversation(
              messages: messages,
              surfaceController: surfaceController,
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders UiResponse correctly', (WidgetTester tester) async {
      const surfaceId = 's1';
      final messages = [
        ChatMessage.model(
          '',
          parts: [
            UiPart.create(
              definition: SurfaceDefinition(surfaceId: surfaceId),
              surfaceId: surfaceId,
            ),
          ],
        ),
      ];
      final components = [
        const Component(
          id: 'root',
          type: 'Text',
          properties: {'text': 'UI Content'},
        ),
      ];
      surfaceController.handleMessage(
        UpdateComponents(surfaceId: surfaceId, components: components),
      );
      surfaceController.handleMessage(
        const CreateSurface(surfaceId: surfaceId, catalogId: basicCatalogId),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Conversation(
              messages: messages,
              surfaceController: surfaceController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Surface), findsOneWidget);
      expect(find.text('UI Content'), findsOneWidget);
    });

    testWidgets('uses custom userPromptBuilder', (WidgetTester tester) async {
      final messages = [ChatMessage.user('Hello')];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Conversation(
              messages: messages,
              surfaceController: surfaceController,
              userPromptBuilder: (context, message) =>
                  const Text('Custom User Prompt'),
            ),
          ),
        ),
      );
      expect(find.text('Custom User Prompt'), findsOneWidget);
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('renders user interaction correctly', (
      WidgetTester tester,
    ) async {
      final messages = [
        ChatMessage.user('', parts: [UiInteractionPart.create('{}')]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Conversation(
              messages: messages,
              surfaceController: surfaceController,
              userUiInteractionBuilder: (context, message) =>
                  const Text('User Interaction'),
            ),
          ),
        ),
      );
      expect(find.text('User Interaction'), findsOneWidget);
    });
  });
}
