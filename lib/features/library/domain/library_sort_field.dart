/// Sort fields supported in the local video library and folder views.
enum LibrarySortField {
  name('name', 'Name'),
  date('date', 'Date Modified'),
  size('size', 'File Size'),
  duration('duration', 'Duration');

  final String id;
  final String label;

  const LibrarySortField(this.id, this.label);

  static LibrarySortField fromId(String? raw) {
    for (final field in LibrarySortField.values) {
      if (field.id == raw) return field;
    }
    return LibrarySortField.date;
  }
}
