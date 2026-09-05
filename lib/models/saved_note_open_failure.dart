/// Persistence succeeded, but the native editor window could not be created.
/// Retrying the save would create a duplicate; open the saved note instead.
class SavedNoteOpenFailure implements Exception {
  const SavedNoteOpenFailure(this.noteId);
  final String noteId;
}
