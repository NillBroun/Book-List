import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookNoteApp());
}

class BookNoteApp extends StatelessWidget {
  const BookNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF1E2024),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1C1E),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class NoteItem {
  String id;
  String content;
  String createdAt;

  NoteItem({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
        id: json['id'] ?? '',
        content: json['content'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}

class BookItem {
  String id;
  String title;
  String author;
  String category;
  int rating;
  List<NoteItem> notes;

  BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    this.rating = 0,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'rating': rating,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory BookItem.fromJson(Map<String, dynamic> json) => BookItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        author: json['author'] ?? 'Unknown',
        category: json['category'] ?? 'General',
        rating: json['rating'] ?? 0,
        notes: (json['notes'] as List<dynamic>?)
                ?.map((n) => NoteItem.fromJson(n))
                .toList() ??
            [],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BookItem> books = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('saved_books');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        books = decoded.map((b) => BookItem.fromJson(b)).toList();
      });
    } else {
      // প্রাথমিক ডেমো বই
      books = [
        BookItem(
          id: '1',
          title: 'পরকবন',
          author: 'Unknown',
          category: 'General',
          rating: 4,
          notes: [
            NoteItem(
                id: 'n1',
                content: 'বইটির সূচনা অনেক আকর্ষণীয় ছিল।',
                createdAt: 'Today'),
          ],
        ),
      ];
      _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(books.map((b) => b.toJson()).toList());
    await prefs.setString('saved_books', encoded);
  }

  List<BookItem> get _filteredBooks {
    if (_searchController.text.trim().isEmpty) return books;
    final query = _searchController.text.toLowerCase();
    return books.where((book) {
      return book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query) ||
          book.category.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddBookDialog() {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('নতুন বই যোগ করুন', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'বইয়ের নাম *',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authorController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'লেখক',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'ক্যাটাগরি (যেমন: উপন্যাস, দর্শন)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              setState(() {
                books.add(
                  BookItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    author: authorController.text.trim().isEmpty
                        ? 'Unknown'
                        : authorController.text.trim(),
                    category: categoryController.text.trim().isEmpty
                        ? 'General'
                        : categoryController.text.trim(),
                    notes: [],
                  ),
                );
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BookItem book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('বইটি মুছে ফেলতে চান?', style: TextStyle(color: Colors.white)),
        content: Text(
          '\'${book.title}\' বইটি তালিকা থেকে স্থায়ীভাবে মুছে যাবে।',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                books.removeWhere((b) => b.id == book.id);
              });
              _saveData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('\'${book.title}\' মুছে ফেলা হয়েছে')),
              );
            },
            child: const Text('ডিলিট', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E2024),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About BookNote',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A personal reading companion designed to effortlessly organize your books, track reading progress, and preserve thoughts.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E), height: 1.4),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2E3238), thickness: 1),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    text: 'Developer: ',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    children: [
                      TextSpan(
                        text: 'AHM',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2).withOpacity(0.2),
                      foregroundColor: const Color(0xFF4C9EEB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.facebook, size: 20, color: Color(0xFF4C9EEB)),
                    label: const Text(
                      'Follow Facebook Page',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('https://www.facebook.com/ahm.79316');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search title, author...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() {}),
              )
            : const Text(
                'BookNote',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'about') _showAboutDialog();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
        ],
      ),
      body: displayList.isEmpty
          ? Center(
              child: Text(
                _isSearching ? 'কোনো বই পাওয়া যায়নি' : 'কোনো বই যোগ করা হয়নি\nনিচের + বাটনে চাপ দিন',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final book = displayList[index];
                return Card(
                  color: const Color(0xFF1E2024),
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => BookDetailScreen(book: book),
                        ),
                      );
                      _saveData();
                      setState(() {});
                    },
                    onLongPress: () => _showDeleteDialog(book),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF00E676),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${book.author} • ${book.category}',
                                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${book.notes.length} notes',
                            style: const TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        onPressed: _showAddBookDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class BookDetailScreen extends StatefulWidget {
  final BookItem book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  void _addNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('নতুন নোট লিখুন', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'আপনার চিন্তা বা বইয়ের অংশবিশেষ লিখুন...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (noteController.text.trim().isEmpty) return;
              setState(() {
                widget.book.notes.add(
                  NoteItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    content: noteController.text.trim(),
                    createdAt: DateTime.now().toString().substring(0, 10),
                  ),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('সংরক্ষণ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E2024),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'লেখক: ${widget.book.author}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  'ক্যাটাগরি: ${widget.book.category}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'নোটসমূহ (Notes)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E676),
              ),
            ),
          ),
          Expanded(
            child: widget.book.notes.isEmpty
                ? const Center(
                    child: Text(
                      'এখনও কোনো নোট নেই। নিচে + বাটনে ট্যাপ করুন।',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: widget.book.notes.length,
                    itemBuilder: (ctx, i) {
                      final n = widget.book.notes[i];
                      return Card(
                        color: const Color(0xFF1E2024),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(n.content, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            n.createdAt,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              setState(() {
                                widget.book.notes.removeAt(i);
                              });
                            },
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
        onPressed: _addNoteDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
