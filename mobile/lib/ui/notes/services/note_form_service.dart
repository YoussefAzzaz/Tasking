import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// Application service handling note persistence, update logic,
/// and auto-registering custom categories.
class NoteFormService {
  final NoteRepository _noteRepo;
  final NoteCategoryRepository _categoryRepo;

  NoteFormService({
    NoteRepository? noteRepo,
    NoteCategoryRepository? categoryRepo,
  })  : _noteRepo = noteRepo ?? NoteRepository(),
        _categoryRepo = categoryRepo ?? NoteCategoryRepository();

  Future<Note> saveNote({
    Note? noteToEdit,
    required String rawTitle,
    required String rawBody,
    required String formatCategory, // 'note' or 'journal'
    required String categoryInput,
    required String selectedMood,
    required bool pinned,
    required String selectedCategoryIcon,
    required String selectedCategoryColor,
    required List<NoteCategory> existingCategories,
  }) async {
    final title = rawTitle.trim();
    final body = rawBody.trim();

    if (title.isEmpty && body.isEmpty) {
      throw ArgumentError('Please enter a title or note body');
    }

    final categoryName = categoryInput.trim();
    if (categoryName.isNotEmpty &&
        categoryName.toLowerCase() != 'general notes' &&
        categoryName.toLowerCase() != 'note' &&
        categoryName.toLowerCase() != 'all') {
      final exists = existingCategories.any(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      );
      if (!exists) {
        await _categoryRepo.addCategory(
          name: categoryName,
          icon: selectedCategoryIcon,
          color: selectedCategoryColor,
        );
      }
    }

    final effectiveCategory = categoryName.isNotEmpty
        ? categoryName
        : (formatCategory == 'journal' ? 'journal' : 'General');

    final now = DateTime.now();
    final defaultTitle = 'Untitled ${now.month}/${now.day}';

    if (noteToEdit != null) {
      final updatedNote = Note(
        id: noteToEdit.id,
        title: title.isEmpty ? defaultTitle : title,
        bodyMd: body,
        category: effectiveCategory,
        mood: formatCategory == 'journal' ? selectedMood : null,
        pinned: pinned,
        createdAt: noteToEdit.createdAt,
      );

      await _noteRepo.updateNote(updatedNote);
      return updatedNote;
    }

    final note = Note(
      id: IdGenerator.generateDeterministicId(
          'note_${now.microsecondsSinceEpoch}_$title'),
      title: title.isEmpty ? defaultTitle : title,
      bodyMd: body,
      category: effectiveCategory,
      mood: formatCategory == 'journal' ? selectedMood : null,
      pinned: pinned,
    );

    await _noteRepo.addNote(note);
    return note;
  }
}

