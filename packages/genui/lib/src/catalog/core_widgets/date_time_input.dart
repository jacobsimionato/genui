// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../core/widget_utilities.dart';
import '../../model/a2ui_schemas.dart';
import '../../model/catalog_item.dart';
import '../../model/data_model.dart';
import '../../primitives/simple_items.dart';

final _schema = S.object(
  properties: {
    'value': A2uiSchemas.stringReference(
      description: 'The selected date and/or time.',
    ),
    'enableDate': S.boolean(),
    'enableTime': S.boolean(),
    'outputFormat': S.string(),
  },
  required: ['value'],
);

extension type _DateTimeInputData.fromMap(JsonMap _json) {
  factory _DateTimeInputData({
    required JsonMap value,
    bool? enableDate,
    bool? enableTime,
    String? outputFormat,
  }) => _DateTimeInputData.fromMap({
    'value': value,
    'enableDate': enableDate,
    'enableTime': enableTime,
    'outputFormat': outputFormat,
  });

  JsonMap get value => _json['value'] as JsonMap;
  bool get enableDate => (_json['enableDate'] as bool?) ?? true;
  bool get enableTime => (_json['enableTime'] as bool?) ?? true;
  String? get outputFormat => _json['outputFormat'] as String?;
}

/// A catalog item representing a Material Design date and/or time input field.
///
/// This widget displays a field that, when tapped, opens the native date and/or
/// time pickers. The selected value is stored as a string in the data model
/// path specified by the `value` parameter.
///
/// ## Parameters:
///
/// - `value`: The selected date and/or time, as a string.
/// - `enableDate`: Whether to allow the user to select a date. Defaults to
///   `true`.
/// - `enableTime`: Whether to allow the user to select a time. Defaults to
///   `true`.
/// - `outputFormat`: The format to use for the output string.
final dateTimeInput = CatalogItem(
  name: 'DateTimeInput',
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    final dateTimeInputData = _DateTimeInputData.fromMap(
      itemContext.data as JsonMap,
    );
    final ValueNotifier<String?> valueNotifier = itemContext.dataContext
        .subscribeToString(dateTimeInputData.value);

    return ValueListenableBuilder<String?>(
      valueListenable: valueNotifier,
      builder: (context, value, child) {
        return ListTile(
          title: Text(value ?? 'Select a date/time'),
          onTap: () async {
            final path = dateTimeInputData.value['path'] as String?;
            if (path == null) {
              return;
            }

            DateTime? selectedDate;
            TimeOfDay? selectedTime;

            if (dateTimeInputData.enableDate) {
              selectedDate = await showDatePicker(
                context: itemContext.buildContext,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selectedDate == null) {
                // User dismissed the date picker.
                return;
              }
            }

            if (dateTimeInputData.enableTime) {
              selectedTime = await showTimePicker(
                context: itemContext.buildContext,
                initialTime: TimeOfDay.now(),
              );
              if (selectedTime == null) {
                // User dismissed the time picker.
                return;
              }
            }

            String formattedValue;
            final String? outputFormat = dateTimeInputData.outputFormat;
            if (selectedDate != null && selectedTime != null) {
              final dateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              formattedValue =
                  (outputFormat != null
                          ? DateFormat(outputFormat)
                          : DateFormat.yMd().add_jm())
                      .format(dateTime);
            } else if (selectedDate != null) {
              formattedValue =
                  (outputFormat != null
                          ? DateFormat(outputFormat)
                          : DateFormat.yMd())
                      .format(selectedDate);
            } else if (selectedTime != null) {
              final now = DateTime.now();
              final time = DateTime(
                now.year,
                now.month,
                now.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              formattedValue =
                  (outputFormat != null
                          ? DateFormat(outputFormat)
                          : DateFormat.jm())
                      .format(time);
            } else {
              return;
            }

            itemContext.dataContext.update(DataPath(path), formattedValue);
          },
        );
      },
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": {
            "DateTimeInput": {
              "value": {
                "path": "/myDateTime"
              }
            }
          }
        }
      ]
    ''',
  ],
);
