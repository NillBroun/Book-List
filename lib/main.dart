import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookNotesApp());
}

String formatTimestamp(String isoString) {
  if (isoString.isEmpty) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(dt.year, dt.month, dt.day);
    final difference = today.difference(noteDay).inDays;

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    if (difference == 0) {
      return 'Today, $timeStr';
    } else if (difference == 1) {
      return 'Yesterday, $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.year} • $timeStr';
    }
  } catch (e) {
    return '';
  }
}

class NoteItem {
  String id;
  String title;
  String content;
  String updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt,
      };

  factory NoteItem.fromMap(Map<String, dynamic> map) => NoteItem(
        id: map['id'],
        title: map['title'] ?? 'Note',
        content: map['content'] ?? '',
        updatedAt: map['updatedAt'] ?? '',
      );
}

class Book {
  String id;
  String title;
  String author;
  String category;
  double rating;
  bool isFavorite;
  String createdAt;
  List<NoteItem> notes;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    this.rating = 0.0,
    this.isFavorite = false,
    String? createdAt,
    List<NoteItem>? notes,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'rating': rating,
        'isFavorite': isFavorite,
        'createdAt': createdAt,
        'notes': notes.map((n) => n.toMap()).toList(),
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'],
        title: map['title'],
        author: map['author'],
        category: map['category'],
        rating: (map['rating'] ?? 0.0).toDouble(),
        isFavorite: map['isFavorite'] ?? false,
        createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
        notes: map['notes'] != null
            ? (map['notes'] as List).map((n) => NoteItem.fromMap(n)).toList()
            : [],
      );
}

class BookNotesApp extends StatefulWidget {
  const BookNotesApp({super.key});

  static _BookNotesAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_BookNotesAppState>()!;

  @override
  State<BookNotesApp> createState() => _BookNotesAppState();
}

class _BookNotesAppState extends State<BookNotesApp> {
  double _fontSize = 16.0;
  String _sortOrder = 'newest';

  double get fontSize => _fontSize;
  String get sortOrder => _sortOrder;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('pref_font_size') ?? 16.0;
      _sortOrder = prefs.getString('pref_sort_order') ?? 'newest';
    });
  }

  Future<void> updateSettings({double? newFontSize, String? newSortOrder}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (newFontSize != null) {
        _fontSize = newFontSize;
        prefs.setDouble('pref_font_size', newFontSize);
      }
      if (newSortOrder != null) {
        _sortOrder = newSortOrder;
        prefs.setString('pref_sort_order', newSortOrder);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookNotes',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1110),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF181B19),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181B19),
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFF00E676), fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF00E676)),
        ),
      ),
      home: const BookListScreen(),
    );
  }
}

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_filterAndSortBooks);
  }

  Future<void> _loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? booksString = prefs.getString('saved_books_data');
    if (booksString != null) {
      final List decoded = jsonDecode(booksString);
      setState(() {
        _books = decoded.map((item) => Book.fromMap(item)).toList();
        _filterAndSortBooks();
      });
    }
  }

  Future<void> _saveBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_books.map((b) => b.toMap()).toList());
    await prefs.setString('saved_books_data', encoded);
  }

  void _filterAndSortBooks() {
    final query = _searchController.text.toLowerCase();
    final sort = BookNotesApp.of(context).sortOrder;

    List<Book> temp = _books.where((book) {
      final matchesQuery = book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query) ||
          book.category.toLowerCase().contains(query);
      final matchesFavorite = _showOnlyFavorites ? book.isFavorite : true;
      return matchesQuery && matchesFavorite;
    }).toList();

    if (sort == 'newest') {
      temp.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (sort == 'oldest') {
      temp.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (sort == 'az') {
      temp.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sort == 'rating') {
      temp.sort((a, b) => b.rating.compareTo(a.rating));
    }

    setState(() {
      _filteredBooks = temp;
    });
  }

  void _toggleFavorite(Book book) {
    setState(() {
      book.isFavorite = !book.isFavorite;
    });
    _saveBooks();
    _filterAndSortBooks();
  }

  void _updateRating(Book book, double rating) {
    setState(() {
      book.rating = rating;
    });
    _saveBooks();
    _filterAndSortBooks();
  }

  Future<void> _exportBackupFile() async {
    try {
      final jsonString = jsonEncode(_books.map((b) => b.toMap()).toList());
      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${directory.path}/BookNotes_Backup_$dateStr.json');
      await file.writeAsString(jsonString);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved: ${file.path}'),
          backgroundColor: const Color(0xFF10B981),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.black,
            onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'My BookNotes Backup Data'),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export backup!'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _importBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final List decoded = jsonDecode(content);

        setState(() {
          _books = decoded.map((item) => Book.fromMap(item)).toList();
          _filterAndSortBooks();
        });
        await _saveBooks();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid backup file!'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showAddOrEditBookDialog({Book? book}) {
    final titleController = TextEditingController(text: book?.title ?? '');
    final authorController = TextEditingController(text: book?.author ?? '');
    final categoryController = TextEditingController(text: book?.category ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181B19),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book == null ? '➕ Add Book' : '✏️ Edit Book',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title *',
                prefixIcon: Icon(Icons.book, color: Color(0xFF00E676)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: 'Author Name',
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFF00E676)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF00E676)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                if (book == null) {
                  final newBook = Book(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    author: authorController.text.trim(),
                    category: categoryController.text.trim(),
                  );
                  setState(() => _books.add(newBook));
                } else {
                  setState(() {
                    book.title = titleController.text.trim();
                    book.author = authorController.text.trim();
                    book.category = categoryController.text.trim();
                  });
                }
                _saveBooks();
                _filterAndSortBooks();
                Navigator.pop(ctx);
              },
              child: Text(book == null ? 'Save Book' : 'Update Book', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    final appState = BookNotesApp.of(context);
    String selectedSort = appState.sortOrder;
    double selectedFont = appState.fontSize;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181B19),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Color(0xFF00E676)),
              SizedBox(width: 8),
              Text('Settings', style: TextStyle(color: Color(0xFF00E676))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort Books By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: selectedSort,
                dropdownColor: const Color(0xFF181B19),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                  DropdownMenuItem(value: 'az', child: Text('Name (A to Z)')),
                  DropdownMenuItem(value: 'rating', child: Text('Highest Rated')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedSort = val);
                    appState.updateSettings(newSortOrder: val);
                    _filterAndSortBooks();
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Reading Font Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              DropdownButton<double>(
                value: selectedFont,
                dropdownColor: const Color(0xFF181B19),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 14.0, child: Text('Small (14px)')),
                  DropdownMenuItem(value: 16.0, child: Text('Medium (16px)')),
                  DropdownMenuItem(value: 18.0, child: Text('Large (18px)')),
                  DropdownMenuItem(value: 20.0, child: Text('Extra Large (20px)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedFont = val);
                    appState.updateSettings(newFontSize: val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF00E676))),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B19),
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Color(0xFF00E676)),
            SizedBox(width: 8),
            Text('About BookNotes', style: TextStyle(color: Color(0xFF00E676))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
            SizedBox(height: 10),
            Text('Developer: AHM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00E676))),
            SizedBox(height: 6),
            Text('Facebook Profile:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(
              'https://www.facebook.com/profile.php?id=61581691871822',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
            ),
            SizedBox(height: 16),
            Divider(color: Colors.white24),
            SizedBox(height: 10),
            Text(
              '"People change, time fades, but the memories and thoughts left on the pages of a book stay forever. Designed to be your quiet companion on every reading journey."',
              style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFB0BEC5), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00E676))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BookNotes'),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.redAccent : const Color(0xFF00E676),
            ),
            tooltip: 'Filter Favorites',
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
                _filterAndSortBooks();
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') _openSettingsDialog();
              if (value == 'export') _exportBackupFile();
              if (value == 'import') _importBackupFile();
              if (value == 'about') _showAboutDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, color: Color(0xFF00E676)), SizedBox(width: 8), Text('Settings')])),
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_upload_outlined, color: Color(0xFF00E676)), SizedBox(width: 8), Text('Backup (File)')])),
              const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_download_outlined, color: Colors.blueAccent), SizedBox(width: 8), Text('Restore (File)')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'about', child: Row(children: [Icon(Icons.info_outline, color: Colors.grey), SizedBox(width: 8), Text('About App')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title, author, category...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676)),
                filled: true,
                fillColor: const Color(0xFF181B19),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _filteredBooks.isEmpty
                ? const Center(child: Text('No books found. Tap + to add.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (ctx, index) {
                      final item = _filteredBooks[index];
                      return Card(
                        color: const Color(0xFF181B19),
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => BookNotesScreen(book: item)),
                            );
                            _saveBooks();
                            _filterAndSortBooks();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF00E676),
                                      foregroundColor: Colors.black,
                                      radius: 18,
                                      child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.author.isEmpty ? "Unknown" : item.author} • ${item.category.isEmpty ? "General" : item.category}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        item.isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: item.isFavorite ? Colors.redAccent : Colors.grey,
                                      ),
                                      onPressed: () => _toggleFavorite(item),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: List.generate(5, (starIdx) {
                                        return GestureDetector(
                                          onTap: () => _updateRating(item, (starIdx + 1).toDouble()),
                                          child: Icon(
                                            starIdx < item.rating ? Icons.star : Icons.star_border,
                                            color: const Color(0xFF00E676),
                                            size: 20,
                                          ),
                                        );
                                      }),
                                    ),
                                    Text(
                                      '${item.notes.length} notes',
                                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        onPressed: () => _showAddOrEditBookDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class BookNotesScreen extends StatefulWidget {
  final Book book;
  const BookNotesScreen({super.key, required this.book});

  @override
  State<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends State<BookNotesScreen> {
  void _openNoteViewer(NoteItem note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NoteDetailScreen(
          bookTitle: widget.book.title,
          note: note,
          onDelete: () {
            setState(() {
              widget.book.notes.removeWhere((n) => n.id == note.id);
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
    setState(() {});
  }

  void _addNewNote() async {
    final defaultTitle = 'Note ${widget.book.notes.length + 1}';
    final result = await Navigator.push<NoteItem>(
      context,
      MaterialPageRoute(
        builder: (ctx) => NoteEditorScreen(
          pageTitle: 'Add Note',
          initialTitle: defaultTitle,
          initialContent: '',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        widget.book.notes.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: widget.book.notes.isEmpty
          ? const Center(
              child: Text(
                'No notes yet. Tap + to add thoughts, quotes or summaries.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.book.notes.length,
              itemBuilder: (ctx, idx) {
                final note = widget.book.notes[idx];
                final timeLabel = formatTimestamp(note.updatedAt);
                return Card(
                  color: const Color(0xFF181B19),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.edit_note, color: Color(0xFF00E676), size: 28),
                    title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.content.isNotEmpty)
                          Text(
                            note.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(timeLabel, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () => _openNoteViewer(note),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        onPressed: _addNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteDetailScreen extends StatefulWidget {
  final String bookTitle;
  final NoteItem note;
  final VoidCallback onDelete;

  const NoteDetailScreen({
    super.key,
    required this.bookTitle,
    required this.note,
    required this.onDelete,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  void _editNote() async {
    final updated = await Navigator.push<NoteItem>(
      context,
      MaterialPageRoute(
        builder: (ctx) => NoteEditorScreen(
          pageTitle: 'Edit Note',
          initialTitle: widget.note.title,
          initialContent: widget.note.content,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        widget.note.title = updated.title;
        widget.note.content = updated.content;
        widget.note.updatedAt = updated.updatedAt;
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B19),
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFontSize = BookNotesApp.of(context).fontSize;
    final timeLabel = formatTimestamp(widget.note.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Note',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${widget.note.title}\n\n${widget.note.content}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note copied to clipboard!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Note',
            onPressed: () {
              Share.share('${widget.note.title}\nBook: ${widget.bookTitle}\n\n${widget.note.content}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Note',
            onPressed: _editNote,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Note',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.note.title,
              style: TextStyle(fontSize: currentFontSize + 6, fontWeight: FontWeight.bold, color: const Color(0xFF00E676)),
            ),
            if (timeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Last edited: $timeLabel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              widget.note.content.isEmpty ? 'No text in this note.' : widget.note.content,
              style: TextStyle(fontSize: currentFontSize, height: 1.6, color: const Color(0xFFE0E0E0)),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final String pageTitle;
  final String initialTitle;
  final String initialContent;

  const NoteEditorScreen({
    super.key,
    required this.pageTitle,
    required this.initialTitle,
    required this.initialContent,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveAndExit(closeScreen: false);
    }
  }

  void _saveAndExit({bool closeScreen = true}) {
    if (_isSaved && closeScreen) return;

    final title = _titleController.text.trim().isEmpty 
        ? widget.initialTitle 
        : _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (closeScreen) Navigator.pop(context, null);
      return;
    }

    final result = NoteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (closeScreen) {
      _isSaved = true;
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFontSize = BookNotesApp.of(context).fontSize;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _saveAndExit(closeScreen: true);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _saveAndExit(closeScreen: true),
          ),
          title: Text(widget.pageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, size: 28, color: Color(0xFF00E676)),
              tooltip: 'Save & Exit',
              onPressed: () => _saveAndExit(closeScreen: true),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                decoration: const InputDecoration(
                  hintText: 'Note Subject / Title',
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(fontSize: currentFontSize, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Start writing your thoughts, notes or quotes...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
