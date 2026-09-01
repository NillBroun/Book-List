import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BookTrackerApp());
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
    required this.notes,
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

class BookTrackerApp extends StatelessWidget {
  const BookTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'বুক ট্র্যাকার',
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

  void _addOrEditBook({Book? book}) {
    final titleController = TextEditingController(text: book?.title ?? '');
    final authorController = TextEditingController(text: book?.author ?? '');
    final categoryController = TextEditingController(text: book?.category ?? '');
    final notesController = TextEditingController(text: book?.notes ?? '');

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                book == null ? '➕ নতুন বই যোগ করুন' : '✏️ বই সম্পাদনা',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'বইয়ের নাম *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(labelText: '👤 লেখকের নাম', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: '📂 বইয়ের ধরন (যেমন: উপন্যাস, বিজ্ঞান)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '📝 নোট / মন্তব্য', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;

                  if (book == null) {
                    final newBook = Book(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      author: authorController.text.trim(),
                      category: categoryController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                    setState(() => _books.add(newBook));
                  } else {
                    setState(() {
                      book.title = titleController.text.trim();
                      book.author = authorController.text.trim();
                      book.category = categoryController.text.trim();
                      book.notes = notesController.text.trim();
                    });
                  }
                  _saveBooks();
                  _filterBooks();
                  Navigator.pop(ctx);
                },
                child: Text(book == null ? 'সংরক্ষণ করুন' : 'আপডেট করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteBook(String id) {
    setState(() {
      _books.removeWhere((b) => b.id == id);
    });
    _saveBooks();
    _filterBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 আমার বইয়ের তালিকা'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '🔎 বই, লেখক বা ক্যাটাগরি খুঁজুন...',
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
                ? const Center(child: Text('কোনো বই পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (ctx, index) {
                      final item = _filteredBooks[index];
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.book, color: Colors.black),
                          ),
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('👤 ${item.author.isEmpty ? "অজানা লেখক" : item.author} | 📂 ${item.category.isEmpty ? "সাধারণ" : item.category}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.notes.isNotEmpty) ...[
                                    const Text('📝 নোট:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                    const SizedBox(height: 4),
                                    Text(item.notes),
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                        onPressed: () => _addOrEditBook(book: item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _deleteBook(item.id),
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
        onPressed: () => _addOrEditBook(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
