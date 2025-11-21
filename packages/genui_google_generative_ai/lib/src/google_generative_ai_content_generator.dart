// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as google_ai;

import 'google_generative_service_interface.dart';
import 'google_model_adapter.dart';

/// A factory for creating a [GoogleGenerativeServiceInterface].
///
/// This is used to allow for custom service creation, for example, for testing.
typedef GenerativeServiceFactory =
    GoogleGenerativeServiceInterface Function({
      required GoogleGenerativeAiContentGenerator configuration,
    });

/// A [ContentGenerator] that uses the Google Cloud Generative Language API to
/// generate content.
class GoogleGenerativeAiContentGenerator implements ContentGenerator {
  /// Creates a [GoogleGenerativeAiContentGenerator] instance with specified
  /// configurations.
  GoogleGenerativeAiContentGenerator({
    required this.catalog,
    this.systemInstruction,
    this.outputToolName = 'provideFinalOutput',
    this.serviceFactory = defaultGenerativeServiceFactory,
    this.configuration = const GenUiConfiguration(),
    this.additionalTools = const [],
    this.modelName = 'models/gemini-1.5-flash',
    this.apiKey,
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

  /// A function to use for creating the service itself.
  ///
  /// This factory function is responsible for instantiating the
  /// [GoogleGenerativeServiceInterface] used for AI interactions. It allows for
  /// customization of the service setup, or for providing mock services during
  /// testing. The factory receives this [GoogleGenerativeAiContentGenerator]
  /// instance as configuration.
  ///
  /// Defaults to a wrapper for the regular [google_ai.GenerativeService]
  /// constructor, [defaultGenerativeServiceFactory].
  final GenerativeServiceFactory serviceFactory;

  /// Additional tools to make available to the AI model.
  final List<AiTool> additionalTools;

  /// The model name to use (e.g., 'models/gemini-1.5-flash').
  final String modelName;

  /// The API key to use for authentication.
  final String? apiKey;

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
    final service = serviceFactory(configuration: this);
    try {
      final messages = [...?history, message];
      final availableTools = [
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
      final adapter = GoogleModelAdapter(
        service: service,
        modelName: modelName,
      );
      final agent = LocalAgent(adapter: adapter, toolRegistry: toolRegistry);

      final response = await agent.execute(messages);

      if (response != null) {
        _textResponseController.add(response);
      }
    } catch (e, st) {
      genUiLogger.severe('Error generating content', e, st);
      _errorController.add(ContentGeneratorError(e, st));
    } finally {
      _isProcessing.value = false;
      service.close();
    }
  }

  /// The default factory function for creating a [google_ai.GenerativeService].
  ///
  /// This function instantiates a standard [google_ai.GenerativeService] using
  /// the `apiKey` from the provided [GoogleGenerativeAiContentGenerator]
  /// `configuration`.
  static GoogleGenerativeServiceInterface defaultGenerativeServiceFactory({
    required GoogleGenerativeAiContentGenerator configuration,
  }) {
    return GoogleGenerativeServiceWrapper(
      google_ai.GenerativeService.fromApiKey(configuration.apiKey),
    );
  }
}
