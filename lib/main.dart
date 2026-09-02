import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BookListApp());
}

class Book {
  String id;
  String title;
  String author;
  String category;
  String notes;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'notes': notes,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'],
        title: map['title'],
        author: map['author'],
        category: map['category'],
        notes: map['notes'] ?? '',
      );
}

class BookListApp extends StatelessWidget {
  const BookListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Book List',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
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

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_filterBooks);
  }

  Future<void> _loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? booksString = prefs.getString('saved_books');
    if (booksString != null) {
      final List decoded = jsonDecode(booksString);
      setState(() {
        _books = decoded.map((item) => Book.fromMap(item)).toList();
        _filteredBooks = _books;
      });
    }
  }

  Future<void> _saveBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_books.map((b) => b.toMap()).toList());
    await prefs.setString('saved_books', encoded);
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBooks = _books.where((book) {
        return book.title.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            book.category.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showAddOrEditBookDialog({Book? book}) {
    final titleController = TextEditingController(text: book?.title ?? '');
    final authorController = TextEditingController(text: book?.author ?? '');
    final categoryController = TextEditingController(text: book?.category ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book == null ? '➕ Add New Book' : '✏️ Edit Book Info',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: 'Author Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (e.g. Novel, History, Science)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
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
                _filterBooks();
                Navigator.pop(ctx);
              },
              child: Text(book == null ? 'Save Book' : 'Update Book', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenNote(Book book) async {
    final updatedNote = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          bookTitle: book.title,
          initialNote: book.notes,
        ),
      ),
    );

    if (updatedNote != null) {
      setState(() {
        book.notes = updatedNote;
      });
      _saveBooks();
      _filterBooks();
    }
  }

  void _deleteBook(String id) {
    setState(() {
      _books.removeWhere((b) => b.id == id);
    });
    _saveBooks();
    _filterBooks();
  }

  void _showBackupDialog() {
    final jsonString = jsonEncode(_books.map((b) => b.toMap()).toList());
    final textController = TextEditingController(text: jsonString);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('☁️ Backup / Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy the backup code below and save it safely:'),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 4,
              readOnly: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup code copied!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('📥 Restore / Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste your saved backup code:'),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Paste JSON code here...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              try {
                final List decoded = jsonDecode(textController.text.trim());
                setState(() {
                  _books = decoded.map((item) => Book.fromMap(item)).toList();
                  _filteredBooks = _books;
                });
                _saveBooks();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data restored successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid backup code!')),
                );
              }
            },
            child: const Text('Restore'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('About Book List'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 12),
            Text('Developed by:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('AHM', style: TextStyle(fontSize: 20, color: Colors.amber, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Facebook Profile:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(
              'https://www.facebook.com/profile.php?id=61581691871822',
              style: TextStyle(color: Colors.blueAccent, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text('Personal Book Library & Reading Notes Manager.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Book List (${_books.length})'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _showBackupDialog();
              } else if (value == 'import') {
                _showRestoreDialog();
              } else if (value == 'about') {
                _showAboutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Backup Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Restore Data'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('About App'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search books, authors, categories...',
                prefixIcon: const Icon(Icons.search, color: Colors.amber),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredBooks.isEmpty
                ? const Center(
                    child: Text('No books added yet. Click + to add one!',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (ctx, index) {
                      final item = _filteredBooks[index];
                      final serialNumber = index + 1;
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Text(
                              '$serialNumber',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            '$serialNumber. ${item.title}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            'Author: ${item.author.isEmpty ? "Unknown" : item.author} • ${item.category.isEmpty ? "General" : item.category}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              decoration: const BoxDecoration(
                                color: Color(0xFF252525),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.sticky_note_2, color: Colors.amber, size: 20),
                                          SizedBox(width: 6),
                                          Text('Book Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 15)),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: () => _openFullScreenNote(item),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: Text(item.notes.isEmpty ? 'Write Note' : 'Open Note'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _openFullScreenNote(item),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        item.notes.isEmpty
                                            ? 'No notes yet. Tap here to write details...'
                                            : item.notes,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: item.notes.isEmpty ? Colors.grey : Colors.white,
                                          fontStyle: item.notes.isEmpty ? FontStyle.italic : FontStyle.normal,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 24, color: Colors.grey),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showAddOrEditBookDialog(book: item),
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                        label: const Text('Edit Book', style: TextStyle(color: Colors.blueAccent)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _deleteBook(item.id),
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                        label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () => _showAddOrEditBookDialog(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final String bookTitle;
  final String initialNote;

  const NoteEditorScreen({
    super.key,
    required this.bookTitle,
    required this.initialNote,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber, size: 28),
            onPressed: () {
              Navigator.pop(context, _noteController.text.trim());
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _noteController,
          maxLines: null,
          expands: true,
          autofocus: true,
          style: const TextStyle(fontSize: 16, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'Start typing your detailed notes, summaries, or thoughts here...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
