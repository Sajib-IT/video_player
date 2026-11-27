/// Normalized storage/media permission state across Android & iOS versions.
enum LibraryPermissionStatus {
  unknown,
  granted,
  limited,
  denied,
  permanentlyDenied;

  bool get hasAccess =>
      this == LibraryPermissionStatus.granted ||
      this == LibraryPermissionStatus.limited;
}
