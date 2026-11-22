/// Les bornes du nom d'un aperçu, celles de l'API (`@NotBlank
/// @Size(min = 3, max = 200)`), jugées comme elle sur le nom rogné.
const int kGpxPreviewNameMin = 3;
const int kGpxPreviewNameMax = 200;

bool gpxPreviewNameValid(String name) {
  final int length = name.trim().length;
  return length >= kGpxPreviewNameMin && length <= kGpxPreviewNameMax;
}

/// « Copie de {name} », coupé à la borne de l'API.
String cappedPreviewName(String name) => name.length <= kGpxPreviewNameMax
    ? name
    : name.substring(0, kGpxPreviewNameMax);
