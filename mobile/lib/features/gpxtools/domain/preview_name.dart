import '../../../core/widgets/duplicate_name_sheet.dart';

/// Les bornes du nom d'un aperçu, celles de l'API (`@NotBlank
/// @Size(min = 3, max = 200)`), jugées comme elle sur le nom rogné.
const int kGpxPreviewNameMin = kCopyNameMin;
const int kGpxPreviewNameMax = kCopyNameMax;

bool gpxPreviewNameValid(String name) {
  final int length = name.trim().length;
  return length >= kGpxPreviewNameMin && length <= kGpxPreviewNameMax;
}

/// « Copie de {name} », coupé à la borne de l'API.
String cappedPreviewName(String name) => name.length <= kGpxPreviewNameMax
    ? name
    : name.substring(0, kGpxPreviewNameMax);
