# Implementation Plan: CatalogItem Example Cleanup and Validation

This plan outlines the steps to refactor `CatalogItem` example data to a new, standardized JSON format and to introduce validation tests to ensure data integrity.

## 1. Core Model and API Updates (`flutter_genui`)

### 1.1. Update `CatalogItem` Class

File: `packages/flutter_genui/lib/src/model/catalog_item.dart`

-   **Update `ExampleBuilderCallback` typedef**: Modify the existing `ExampleBuilderCallback` from `JsonMap Function()` to `String Function()`.
-   **Update `exampleData` type**: Ensure `exampleData` is of type `List<ExampleBuilderCallback>`.
-   **Update Constructor**: Adjust the constructor to accept `List<ExampleBuilderCallback>`.
-   **Update Documentation**: Update the class and field documentation to reflect the new format, specifying that each example builder must return a JSON string representing a list of components, including one with `id: 'root'`.

### 1.2. Add `toJson` to `SurfaceUpdate`

File: `packages/flutter_genui/lib/src/model/a2ui_message.dart`

-   Add a `toJson()` method to the `SurfaceUpdate` class. This method will serialize the `SurfaceUpdate` instance into a `JsonMap` suitable for validation against the JSON schema. The map should contain `surfaceId` and `components` keys.

## 2. Create Validation Test Helper (`flutter_genui`)

### 2.1. Create New Test Utility File

File: `packages/flutter_genui/test/validation_test_utils.dart` (new file)

-   Create this file to house the new validation logic.

### 2.2. Implement `validateCatalogExamples`

-   Define the function `validateCatalogExamples(Catalog catalog, [List<Catalog> additionalCatalogs = const []])`.
-   Inside, merge the provided `catalog` and `additionalCatalogs`.
-   Generate the `surfaceUpdateSchema` from the merged catalog.
-   Iterate through each `CatalogItem` in the primary `catalog`.
-   For each item, create a `group()`.
-   Inside the group, iterate through each example builder function in `exampleData`.
-   For each example, create a `test()` that:
    1.  Executes the builder function to get the JSON string.
    2.  Parses the JSON string into a `List<Component>`.
    3.  Asserts that a component with `id: 'root'` exists.
    4.  Creates a `SurfaceUpdate` object with the components.
    5.  Serializes the `SurfaceUpdate` object to JSON using the new `toJson()` method.
    6.  Validates the resulting JSON against the `surfaceUpdateSchema`.
    7.  Asserts that there are no validation errors.

## 3. Update `DebugCatalogView`

File: `packages/flutter_genui/lib/src/development_utilities/catalog_view.dart`

-   Refactor the `initState` method to handle the `List<ExampleBuilderCallback>` format of `exampleData`.
-   Remove the old logic that handles the outdated `JsonMap` format.
-   The new logic should:
    1.  Iterate through catalog items and their `exampleData` builder functions.
    2.  For each example, execute the builder to get the JSON string.
    3.  Decode the JSON string to get the list of components.
    4.  Find the root component (where `id == 'root'`).
    5.  Create `SurfaceUpdate` and `BeginRendering` messages and send them to the `GenUiManager`.

## 4. Update All `CatalogItem` Examples

I will search the codebase for all `CatalogItem` definitions and update their `exampleData`.

**Search query:** `CatalogItem(` in `*.dart` files.

For each found `CatalogItem`:

1.  Convert the existing `exampleData` functions (which return `JsonMap`) to functions that return a JSON string.
2.  For static examples, this will involve wrapping a multi-line raw string in a builder: `() => r'''[ ... ]'''`.
3.  For dynamic examples (like in `listings_booker.dart`), the builder function will construct the data as a Dart `Map` or `List`, and then return `jsonEncode(...)` on the final structure.
4.  The structure of the data needs to be changed from `{'root': '...', 'widgets': [...]}` to a simple list of components `[...]`.
5.  In the list of components, rename the `widget` key to `component`.
6.  Identify the root component (indicated by the old `root` key) and change its `id` to `'root'`.

**Files expected to be modified (exhaustive list):**
-   `examples/travel_app/lib/src/catalog/date_input_chip.dart`
-   `examples/travel_app/lib/src/catalog/input_group.dart`
-   `examples/travel_app/lib/src/catalog/travel_carousel.dart`
-   `examples/travel_app/lib/src/catalog/trailhead.dart`
-   `examples/travel_app/lib/src/catalog/information_card.dart`
-   `examples/travel_app/lib/src/catalog/options_filter_chip_input.dart`
-   `examples/travel_app/lib/src/catalog/text_input_chip.dart`
-   `examples/travel_app/lib/src/catalog/tabbed_sections.dart`
-   `examples/travel_app/lib/src/catalog/listings_booker.dart`
-   `examples/travel_app/lib/src/catalog/checkbox_filter_chips_input.dart`
-   `examples/travel_app/lib/src/catalog/itinerary.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/multiple_choice.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/modal.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/column.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/row.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/slider.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/check_box.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/divider.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/video.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/list.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/audio_player.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/tabs.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/button.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/image.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/card.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/text.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/text_field.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/date_time_input.dart`
-   `packages/flutter_genui/lib/src/catalog/core_widgets/heading.dart`
-   `examples/custom_backend/lib/backend/custom_catalog.dart`

## 5. Implement Validation Tests

Create new test files to consume the `validateCatalogExamples` helper.

### 5.1. `flutter_genui` Core Catalog Test

File: `packages/flutter_genui/test/core_catalog_validation_test.dart` (new file)

-   Import `core_catalog.dart`.
-   Call `validateCatalogExamples(coreCatalog)`.

### 5.2. `travel_app` Catalog Test

File: `examples/travel_app/test/catalog_validation_test.dart` (new file)

-   Import the `travelAppCatalog` and `coreCatalog`.
-   Call `validateCatalogExamples(travelAppCatalog, [coreCatalog])`.

### 5.3. `custom_backend` Catalog Test

File: `examples/custom_backend/test/catalog_validation_test.dart` (new file)

-   Import the `customCatalog` and `coreCatalog`.
-   Call `validateCatalogExamples(customCatalog, [coreCatalog])`.
