// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart' hide TextPart;
import 'package:flutter/foundation.dart';
import 'package:genui/src/content_generator.dart';
import 'package:genui/src/core/genui_configuration.dart';
import 'package:genui/src/core/ui_tools.dart';
import 'package:genui/src/local_agent/local_agent.dart';
import 'package:genui/src/model/a2ui_message.dart';
import 'package:genui/src/model/catalog.dart';
import 'package:genui/src/model/chat_message.dart';
import 'package:genui/src/model/tools.dart';
import 'package:genui/src/primitives/logging.dart';

import 'firebase_model_adapter.dart';
import 'gemini_generative_model.dart';

/// A factory for creating a [GeminiGenerativeModelInterface].
///
/// This is used to allow for custom model creation, for example, for testing.
typedef GenerativeModelFactory =
    GeminiGenerativeModelInterface Function({
      required FirebaseAiContentGenerator configuration,
      Content? systemInstruction,
      List<Tool>? tools,
      ToolConfig? toolConfig,
    });

/// A [ContentGenerator] that uses the Firebase AI API to generate content.
///
/// This generator utilizes a [GeminiGenerativeModelInterface] to interact with
/// the Firebase AI API. The actual model instance is created by the
/// [modelCreator] function, which defaults to [defaultGenerativeModelFactory].
class FirebaseAiContentGenerator implements ContentGenerator {
  /// Creates a [FirebaseAiContentGenerator] instance with specified
  /// configurations.
  FirebaseAiContentGenerator({
    required this.catalog,
    this.systemInstruction,
    this.outputToolName = 'provideFinalOutput',
    this.modelCreator = defaultGenerativeModelFactory,
    this.configuration = const GenUiConfiguration(),
    this.additionalTools = const [],
  });

  final GenUiConfiguration configuration;

  /// The catalog of UI components available to the AI.
  final Catalog catalog;

  /// The system instruction to use for the AI model.
  final String? systemInstruction;

  /// The name of an internal pseudo-tool used to retrieve the final structured
  /// output from the AI.
  ///
  /// This only needs to be provided in case of name collision with another
  /// tool.
  ///
  /// Defaults to 'provideFinalOutput'.
  final String outputToolName;

  /// A function to use for creating the model itself.
  ///
  /// This factory function is responsible for instantiating the
  /// [GeminiGenerativeModelInterface] used for AI interactions. It allows for
  /// customization of the model setup, such as using different HTTP clients, or
  /// for providing mock models during testing. The factory receives this
  /// [FirebaseAiContentGenerator] instance as configuration.
  ///
  /// Defaults to a wrapper for the regular [GenerativeModel] constructor,
  /// [defaultGenerativeModelFactory].
  final GenerativeModelFactory modelCreator;

  /// Additional tools to make available to the AI model.
  final List<AiTool> additionalTools;

  /// The total number of input tokens used by this client.
  int inputTokenUsage = 0;

  /// The total number of output tokens used by this client
  int outputTokenUsage = 0;

  final _a2uiMessageController = StreamController<A2uiMessage>.broadcast();
  final _textResponseController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiMessageController.stream;

  @override
  Stream<String> get textResponseStream => _textResponseController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  void dispose() {
    _a2uiMessageController.close();
    _textResponseController.close();
    _errorController.close();
    _isProcessing.dispose();
  }

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
  }) async {
    _isProcessing.value = true;
    try {
      final messages = [...?history, message];
      final List<AiTool> availableTools = [
        if (configuration.actions.allowCreate ||
            configuration.actions.allowUpdate) ...[
          SurfaceUpdateTool(
            handleMessage: _a2uiMessageController.add,
            catalog: catalog,
            configuration: configuration,
          ),
          BeginRenderingTool(handleMessage: _a2uiMessageController.add),
        ],
        if (configuration.actions.allowDelete)
          DeleteSurfaceTool(handleMessage: _a2uiMessageController.add),
        ...additionalTools,
      ];

      final toolRegistry = ToolRegistry(tools: availableTools);

      final GeminiGenerativeModelInterface model = modelCreator(
        configuration: this,
        systemInstruction: systemInstruction == null
            ? null
            : Content.system(systemInstruction!),
        tools: const [], // The adapter will handle this.
        toolConfig: ToolConfig(
          functionCallingConfig: FunctionCallingConfig.auto(),
        ),
      );

      final adapter = FirebaseModelAdapter(model: model);
      final LocalAgent<Tool, Content, GenerateContentResponse> agent =
          LocalAgent(adapter: adapter, toolRegistry: toolRegistry);

      final String? response = await agent.execute(messages);

      if (response != null) {
        _textResponseController.add(response);
      }
    } catch (e, st) {
      genUiLogger.severe('Error generating content', e, st);
      _errorController.add(ContentGeneratorError(e, st));
    } finally {
      _isProcessing.value = false;
    }
  }

  /// The default factory function for creating a [GenerativeModel].
  ///
  /// This function instantiates a standard [GenerativeModel] using the `model`
  /// from the provided [FirebaseAiContentGenerator] `configuration`.
  static GeminiGenerativeModelInterface defaultGenerativeModelFactory({
    required FirebaseAiContentGenerator configuration,
    Content? systemInstruction,
    List<Tool>? tools,
    ToolConfig? toolConfig,
  }) {
    return GeminiGenerativeModel(
      FirebaseAI.googleAI().generativeModel(
        model: 'gemini-1.5-flash',
        systemInstruction: systemInstruction,
        tools: tools,
        toolConfig: toolConfig,
      ),
    );
  }
}
