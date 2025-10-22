// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_genui/flutter_genui.dart';
import 'package:travel_app/src/catalog.dart';

void main() {
  validateCatalogExamples(travelAppCatalog, [CoreCatalogItems.asCatalog()]);
}
