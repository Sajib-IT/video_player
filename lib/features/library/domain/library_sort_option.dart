import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

/// Immutable sort field + direction pair for the video library.
class LibrarySortOption {
  final LibrarySortField field;
  final bool ascending;

  const LibrarySortOption({
    this.field = LibrarySortField.date,
    this.ascending = false,
  });

  LibrarySortOption copyWith({
    LibrarySortField? field,
    bool? ascending,
  }) {
    return LibrarySortOption(
      field: field ?? this.field,
      ascending: ascending ?? this.ascending,
    );
  }

  int compare(VideoItem a, VideoItem b) {
    int cmp;
    switch (field) {
      case LibrarySortField.name:
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case LibrarySortField.date:
        cmp = a.modifiedAt.compareTo(b.modifiedAt);
      case LibrarySortField.size:
        cmp = a.sizeBytes.compareTo(b.sizeBytes);
      case LibrarySortField.duration:
        cmp = a.duration.compareTo(b.duration);
    }
    if (cmp == 0) {
      cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
    return ascending ? cmp : -cmp;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibrarySortOption &&
        other.field == field &&
        other.ascending == ascending;
  }

  @override
  int get hashCode => Object.hash(field, ascending);
}
