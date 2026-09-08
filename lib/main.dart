import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

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
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.year} • $timeStr';
    }
  } catch (e) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// TYPEWRITER ANIMATION COMPONENT
// ---------------------------------------------------------------------------

class TypewriterGuide extends StatefulWidget {
  final List<String> texts;
  final IconData icon;

  const TypewriterGuide({
    super.key,
    required this.texts,
    required this.icon,
  });

  @override
  State<TypewriterGuide> createState() => _TypewriterGuideState();
}

class _TypewriterGuideState extends State<TypewriterGuide> {
  int _textIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  Timer? _timer;
  String _displayedText = '';

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
      if (!mounted) return;
      final currentFullText = widget.texts[_textIndex];

      setState(() {
        if (!_isDeleting) {
          if (_charIndex < currentFullText.length) {
            _charIndex++;
            _displayedText = currentFullText.substring(0, _charIndex);
          } else {
            _isDeleting = true;
            _timer?.cancel();
            Future.delayed(const Duration(milliseconds: 1600), () {
              if (mounted) _startTyping();
            });
          }
        } else {
          if (_charIndex > 0) {
            _charIndex--;
            _displayedText = currentFullText.substring(0, _charIndex);
          } else {
            _isDeleting = false;
            _textIndex = (_textIndex + 1) % widget.texts.length;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181B19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 36, color: const Color(0xFF00E676)),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: Center(
              child: Text(
                '$_displayedText|',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 15, color: Color(0xFF00E676)),
              SizedBox(width: 6),
              Text(
                'Tap + below to start',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ROOT APP
// ---------------------------------------------------------------------------

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
      title: 'BookNote',
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
          titleTextStyle: TextStyle(
            color: Color(0xFF00E676),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00E676)),
        ),
      ),
      home: const BookListScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// BOOK LIST SCREEN
// ---------------------------------------------------------------------------

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List<Book> _books = [];
  List<Book> _filteredBooks = [];

  final TextEditingController _bookSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showOnlyFavorites = false;
  bool _isSearchingBooks = false;

  final List<String> _homePrompts = [
    'Add your currently reading books...',
    'Save your favorite book summaries & thoughts...',
    'Organize study topics, articles, or lecture notes...',
    'Track reading goals, authors, and ratings...',
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _bookSearchController.addListener(_filterAndSortBooks);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  @override
  void dispose() {
    _bookSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool('has_seen_onboarding_guide') ?? false;
    if (!hasSeen && mounted) {
      _showOnboardingGuideDialog();
    }
  }

  void _showOnboardingGuideDialog() {
    bool doNotShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181B19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E676), width: 0.8),
          ),
          title: const Text(
            'Welcome to BookNote! 👋',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How to get started:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  '1. Create a Book',
                  'Tap the + button below to add your first book or notebook.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  '2. Add Your Notes',
                  'Tap on any book to open it and start writing your thoughts, summaries, or quotes.',
                ),
                const Divider(color: Colors.white24, height: 22),
                const Text(
                  'Quick Tips:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  '🔍 Search (Top Bar)',
                  'Quickly filter books by title, author, or category.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  '⚙️ Find in Notes (Settings)',
                  'Search for specific words or lines inside all your notes.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  '🔒 Backup & Restore (Settings)',
                  'Export password-protected ZIP backups to keep your data safe offline.',
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      doNotShowAgain = !doNotShowAgain;
                    });
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        value: doNotShowAgain,
                        activeColor: const Color(0xFF00E676),
                        checkColor: Colors.black,
                        onChanged: (val) {
                          setDialogState(() {
                            doNotShowAgain = val ?? false;
                          });
                        },
                      ),
                      const Text(
                        "Don't show this again",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (doNotShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_seen_onboarding_guide', true);
                }
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          desc,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    );
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
    final query = _bookSearchController.text.toLowerCase().trim();
    final sort = BookNotesApp.of(context).sortOrder;

    List<Book> temp = _books.where((book) {
      final matchesQuery = query.isEmpty ||
          book.title.toLowerCase().contains(query) ||
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

  void _showCleanSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? Colors.red.shade900 : const Color(0xFF181B19),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isError ? Colors.redAccent : const Color(0xFF00E676),
            width: 0.8,
          ),
        ),
      ),
    );
  }

  void _showDeleteBookDialog(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Book?', style: TextStyle(color: Colors.white)),
        content: Text(
          '\'${book.title}\' and all of its notes will be permanently deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _books.removeWhere((b) => b.id == book.id);
                _filterAndSortBooks();
              });
              _saveBooks();
              Navigator.pop(ctx);
              _showCleanSnackBar('\'${book.title}\' deleted successfully');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openFindInNotesDialog() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final List<Map<String, dynamic>> results = [];

          if (q.isNotEmpty) {
            for (var b in _books) {
              for (var n in b.notes) {
                if (n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)) {
                  results.add({'book': b, 'note': n});
                }
              }
            }
          }
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.find_in_page_outlined, color: Color(0xFF00E676)),
                      SizedBox(width: 8),
                      Text(
                        'Find in Notes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search words across all notes...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676)),
                      filled: true,
                      fillColor: const Color(0xFF0F1110),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: q.isEmpty
                        ? const Center(
                            child: Text(
                              'Type keywords to search inside your reading notes.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : results.isEmpty
                            ? const Center(
                                child: Text('No notes matched your search.', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, i) {
                                  final b = results[i]['book'] as Book;
                                  final n = results[i]['note'] as NoteItem;
                                  return Card(
                                    color: const Color(0xFF0F1110),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                                      subtitle: Text(
                                        'Book: ${b.title}\n${n.content}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => NoteDetailScreen(
                                              book: b,
                                              note: n,
                                              onDelete: () {
                                                setState(() {
                                                  b.notes.removeWhere((item) => item.id == n.id);
                                                });
                                                _saveBooks();
                                              },
                                              onDirectSave: _saveBooks,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECURE ZIP BACKUP & RESTORE WITH PASSWORD ENCRYPTION
  // ---------------------------------------------------------------------------

  Uint8List _deriveKey(String password) {
    return Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes);
  }

  Uint8List _xorCipher(List<int> bytes, Uint8List key) {
    final Uint8List result = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ key[i % key.length];
    }
    return result;
  }

  Future<void> _exportBackupFile() async {
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B19),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF00E676), width: 0.8),
        ),
        title: const Text('Export ZIP Backup', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a password to protect your backup archive (.zip).',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter Password *',
                labelStyle: TextStyle(color: Color(0xFF00E676)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password *',
                labelStyle: TextStyle(color: Color(0xFF00E676)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final p1 = passCtrl.text;
              final p2 = confirmPassCtrl.text;
              if (p1.isEmpty) {
                _showCleanSnackBar('Password cannot be empty!', isError: true);
                return;
              }
              if (p1 != p2) {
                _showCleanSnackBar('Passwords do not match!', isError: true);
                return;
              }

              Navigator.pop(ctx);

              try {
                final jsonString = jsonEncode(_books.map((b) => b.toMap()).toList());
                final jsonBytes = utf8.encode(jsonString);
                final key = _deriveKey(p1);
                final encrypted = _xorCipher(jsonBytes, key);

                final archive = Archive();
                archive.addFile(ArchiveFile('vault.bin', encrypted.length, encrypted));
                final zipData = ZipEncoder().encode(archive);

                if (zipData == null) {
                  _showCleanSnackBar('Failed to generate ZIP!', isError: true);
                  return;
                }

                final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
                final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
                final file = File('${directory.path}/BookNote_Backup_$timestamp.zip');
                await file.writeAsBytes(zipData);

                if (!mounted) return;

                _showCleanSnackBar('ZIP backup created successfully.');
                await Share.shareXFiles([XFile(file.path, mimeType: 'application/zip')], text: 'BookNote Password-Protected Backup');
              } catch (e) {
                _showCleanSnackBar('Failed to export backup!', isError: true);
              }
            },
            child: const Text('Export ZIP'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final zipBytes = await file.readAsBytes();

      if (!mounted) return;

      final passCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF181B19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF00E676), width: 0.8),
          ),
          title: const Text('Enter Backup Password', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This ZIP archive is protected. Enter the correct password to restore.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color(0xFF00E676)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final password = passCtrl.text;
                Navigator.pop(ctx);

                try {
                  final archive = ZipDecoder().decodeBytes(zipBytes);
                  final vaultFile = archive.findFile('vault.bin');

                  if (vaultFile == null) {
                    _showCleanSnackBar('Invalid BookNote ZIP backup!', isError: true);
                    return;
                  }

                  final encrypted = vaultFile.content as List<int>;
                  final key = _deriveKey(password);
                  final decrypted = _xorCipher(encrypted, key);

                  final content = utf8.decode(decrypted);
                  final List decoded = jsonDecode(content);

                  setState(() {
                    _books = decoded.map((item) => Book.fromMap(item)).toList();
                    _filterAndSortBooks();
                  });
                  await _saveBooks();

                  _showCleanSnackBar('Data restored successfully!');
                } catch (_) {
                  _showCleanSnackBar('Wrong password or corrupted file!', isError: true);
                }
              },
              child: const Text('Unlock & Restore'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showCleanSnackBar('Failed to read file!', isError: true);
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
              Icon(Icons.tune, color: Color(0xFF00E676)),
              SizedBox(width: 8),
              Text('Preferences', style: TextStyle(color: Color(0xFF00E676))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
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
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF181B19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About BookNote',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('Version: 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              RichText(
                text: const TextSpan(
                  text: 'Developer: ',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  children: [
                    TextSpan(
                      text: 'AHM',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2).withOpacity(0.2),
                    foregroundColor: const Color(0xFF4C9EEB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.facebook, size: 20, color: Color(0xFF4C9EEB)),
                  label: const Text(
                    'Follow Facebook Page',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse('https://www.facebook.com/profile.php?id=61581691871822');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              const Text(
                '"People change, time fades, but the memories and thoughts left on the pages of a book stay forever. Designed to be your quiet companion on every reading journey."',
                style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFB0BEC5), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchingBooks
            ? TextField(
                controller: _bookSearchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search book, author, category...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              )
            : const Text('BookNote'),
        actions: [
          IconButton(
            icon: Icon(_isSearchingBooks ? Icons.close : Icons.search),
            tooltip: _isSearchingBooks ? 'Close Search' : 'Search Books',
            onPressed: () {
              setState(() {
                if (_isSearchingBooks) {
                  _isSearchingBooks = false;
                  _bookSearchController.clear();
                } else {
                  _isSearchingBooks = true;
                }
              });
              if (_isSearchingBooks) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _searchFocusNode.requestFocus();
                });
              }
            },
          ),
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.redAccent : const Color(0xFF00E676),
            ),
            tooltip: 'Favorites',
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
                _filterAndSortBooks();
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onSelected: (value) {
              if (value == 'find') _openFindInNotesDialog();
              if (value == 'settings') _openSettingsDialog();
              if (value == 'export') _exportBackupFile();
              if (value == 'import') _importBackupFile();
              if (value == 'guide') _showOnboardingGuideDialog();
              if (value == 'about') _showAboutDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'find',
                child: Row(
                  children: [
                    Icon(Icons.find_in_page_outlined, color: Color(0xFF00E676)),
                    SizedBox(width: 10),
                    Text('Find in Notes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF00E676)),
                    SizedBox(width: 10),
                    Text('Preferences (Font & Sort)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Color(0xFF00E676)),
                    SizedBox(width: 10),
                    Text('Backup (ZIP)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.unarchive_outlined, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Restore (ZIP)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Color(0xFF00E676)),
                    SizedBox(width: 10),
                    Text('How to Use'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 10),
                    Text('About App'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _filteredBooks.isEmpty
          ? Center(
              child: _books.isEmpty
                  ? TypewriterGuide(
                      texts: _homePrompts,
                      icon: Icons.menu_book,
                    )
                  : Text(
                      _isSearchingBooks ? 'No matching books found.' : 'No books found. Tap + to add.',
                      style: const TextStyle(color: Colors.grey),
                    ),
            )
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
                        MaterialPageRoute(
                          builder: (context) => BookNotesScreen(
                            book: item,
                            isFirstEverBook: _books.length == 1,
                            onSaveRequested: _saveBooks,
                          ),
                        ),
                      );
                      _saveBooks();
                      _filterAndSortBooks();
                    },
                    onLongPress: () => _showDeleteBookDialog(item),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        onPressed: () => _showAddOrEditBookDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOOK NOTES SCREEN
// ---------------------------------------------------------------------------

class BookNotesScreen extends StatefulWidget {
  final Book book;
  final bool isFirstEverBook;
  final Future<void> Function() onSaveRequested;

  const BookNotesScreen({
    super.key,
    required this.book,
    required this.isFirstEverBook,
    required this.onSaveRequested,
  });

  @override
  State<BookNotesScreen> createState() => _BookNotesScreenState();
}

class _BookNotesScreenState extends State<BookNotesScreen> {
  final List<String> _firstBookPrompts = [
    '💡 Write your book summary or personal review...',
    '📌 Save your favorite quotes and key lessons...',
    '✍️ Add chapter-wise takeaways & thoughts...',
  ];

  void _openNoteViewer(NoteItem note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NoteDetailScreen(
          book: widget.book,
          note: note,
          onDelete: () {
            setState(() {
              widget.book.notes.removeWhere((n) => n.id == note.id);
            });
            widget.onSaveRequested();
            Navigator.pop(ctx);
          },
          onDirectSave: widget.onSaveRequested,
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
          onInstantPersist: (note) {
            final idx = widget.book.notes.indexWhere((n) => n.id == note.id);
            if (idx != -1) {
              widget.book.notes[idx] = note;
            } else {
              widget.book.notes.insert(0, note);
            }
            widget.onSaveRequested();
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        if (!widget.book.notes.any((n) => n.id == result.id)) {
          widget.book.notes.insert(0, result);
        }
      });
      await widget.onSaveRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: widget.book.notes.isEmpty
          ? Center(
              child: widget.isFirstEverBook
                  ? TypewriterGuide(
                      texts: _firstBookPrompts,
                      icon: Icons.edit_note,
                    )
                  : const Text(
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

// ---------------------------------------------------------------------------
// NOTE DETAIL SCREEN
// ---------------------------------------------------------------------------

class NoteDetailScreen extends StatefulWidget {
  final Book book;
  final NoteItem note;
  final VoidCallback onDelete;
  final Future<void> Function() onDirectSave;

  const NoteDetailScreen({
    super.key,
    required this.book,
    required this.note,
    required this.onDelete,
    required this.onDirectSave,
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
          existingId: widget.note.id,
          onInstantPersist: (note) {
            setState(() {
              widget.note.title = note.title;
              widget.note.content = note.content;
              widget.note.updatedAt = note.updatedAt;
            });
            widget.onDirectSave();
          },
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        widget.note.title = updated.title;
        widget.note.content = updated.content;
        widget.note.updatedAt = updated.updatedAt;
      });
      await widget.onDirectSave();
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
                const SnackBar(
                  content: Text('Note copied to clipboard!'),
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Note',
            onPressed: () {
              Share.share('${widget.note.title}\nBook: ${widget.book.title}\n\n${widget.note.content}');
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

// ---------------------------------------------------------------------------
// NOTE EDITOR (COLORNOTE-STYLE LIFECYCLE AUTO-SAVE + DATE/TIME TRACKING)
// ---------------------------------------------------------------------------

class NoteEditorScreen extends StatefulWidget {
  final String pageTitle;
  final String initialTitle;
  final String initialContent;
  final String? existingId;
  final Function(NoteItem) onInstantPersist;

  const NoteEditorScreen({
    super.key,
    required this.pageTitle,
    required this.initialTitle,
    required this.initialContent,
    this.existingId,
    required this.onInstantPersist,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _noteId;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteId = widget.existingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_isSaved) {
      _executeSave(closeScreen: false);
    }
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _executeSave(closeScreen: false);
    }
  }

  NoteItem? _executeSave({required bool closeScreen}) {
    final title = _titleController.text.trim().isEmpty ? widget.initialTitle : _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (closeScreen) Navigator.pop(context, null);
      return null;
    }

    final item = NoteItem(
      id: _noteId,
      title: title,
      content: content,
      updatedAt: DateTime.now().toIso8601String(),
    );

    widget.onInstantPersist(item);

    if (closeScreen) {
      _isSaved = true;
      Navigator.pop(context, item);
    }
    return item;
  }

  @override
  Widget build(BuildContext context) {
    final currentFontSize = BookNotesApp.of(context).fontSize;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _executeSave(closeScreen: true);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _executeSave(closeScreen: true),
          ),
          title: Text(widget.pageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, size: 28, color: Color(0xFF00E676)),
              tooltip: 'Save & Exit',
              onPressed: () => _executeSave(closeScreen: true),
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
                    hintText: 'Start writing your thoughts, notes or quotes...\nAuto-saves when you leave or switch apps.',
                    hintStyle: TextStyle(color: Colors.white30),
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
