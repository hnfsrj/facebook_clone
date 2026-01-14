import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initAuthListener();
  }

  void _initAuthListener() {
    // Listen to auth state changes to handle OAuth callbacks
    _authSubscription = SupabaseService.authStateChanges.listen((
      AuthState state,
    ) {
      if (state.event == AuthChangeEvent.signedIn && mounted) {
        // Navigate to authenticated area when user signs in
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const FaceBook()),
          (route) => false,
        );
      }
    });
  }

  void _initDeepLinks() {
    // Handle deep links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );

    // Handle deep link when app is opened from terminated state
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'com.example.app' && uri.host == 'login-callback') {
      try {
        // Process the OAuth callback URL with Supabase
        // Supabase will extract tokens from the URL and set the session
        await SupabaseService.client.auth.getSessionFromUrl(uri);

        // Session is set, auth state listener will handle navigation
        // But we can also navigate directly here
        if (mounted && SupabaseService.isLoggedIn) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const FaceBook()),
            (route) => false,
          );
        }
      } catch (error) {
        print('Error handling deep link: $error');
        // Fallback: check if user is logged in anyway
        if (SupabaseService.isLoggedIn && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const FaceBook()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(), // separate widget
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IconButton(
          onPressed: () {
            if (SupabaseService.isLoggedIn) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const FaceBook()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            }
          },
          icon: Icon(Icons.facebook, size: 60),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FaceBook()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await SupabaseService.signInWithGoogle();
      // The navigation will happen when the deep link callback is processed
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Log in',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log in'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.g_mobiledata, size: 24);
                    },
                  ),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountPage(),
                    ),
                  );
                },
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FaceBook()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account creation failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await SupabaseService.signInWithGoogle();
      // The navigation will happen when the deep link callback is processed
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Create account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.g_mobiledata, size: 24);
                    },
                  ),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaceBook extends StatelessWidget {
  const FaceBook({super.key});

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E6EA),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await SupabaseService.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "facebook",
                      style: TextStyle(
                        color: Color(0xFF1877F2),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _circleIcon(Icons.add),
                        const SizedBox(width: 10),
                        _circleIcon(Icons.search),
                        const SizedBox(width: 10),
                        _circleIcon(Icons.messenger_outline),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout, size: 20),
                          color: Colors.black87,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const _TabIcon(icon: Icons.home, selected: true),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendsPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const _TabIcon(icon: Icons.people_outline),
                    ),
                    const _TabIcon(icon: Icons.storefront_outlined),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const _TabIcon(icon: Icons.notifications_none),
                    ),
                    const _TabIcon(icon: Icons.menu),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.6),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE5E6EA),
                      child: Icon(
                        Icons.person,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFFCDD0D5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFFCDD0D5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFFCDD0D5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 26,
                      color: Color(0xFF2DBA4E),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.6),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ActionTile(
                      label: 'Create story',
                      icon: Icons.menu_book_outlined,
                      colorA: Color(0xFF3B82F6),
                      colorB: Color(0xFF2563EB),
                    ),
                    SizedBox(height: 12),
                    _ActionTile(
                      label: 'Create reel',
                      icon: Icons.movie_creation_outlined,
                      colorA: Color(0xFFF97316),
                      colorB: Color(0xFFEA580C),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.6),

              const SizedBox(height: 12),
              const _PostCard(
                name: 'Thumbs Up Studio',
                time: '17h',
                text:
                    'This poor girl uses simple red bricks to craft a peacock...',
              ),
              const SizedBox(height: 12),
              const _PostCard(
                name: 'Creative Corner',
                time: '1d',
                text: 'New handmade wall art using simple materials.',
              ),
              const SizedBox(height: 12),
              const _PostCard(
                name: 'Village Life',
                time: '2d',
                text: 'A quick update from today’s work in the village.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _TabIcon({required this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? const Color(0xFF1877F2) : Colors.black54;
    return SizedBox(
      width: 68,
      height: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 10),
          Container(
            height: 3,
            width: 44,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1877F2) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color colorA;
  final Color colorB;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorA, colorB],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String name;
  final String time;
  final String text;

  const _PostCard({required this.name, required this.time, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE5E6EA),
                child: Icon(Icons.person, color: Colors.black54, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "facebook",
                    style: TextStyle(
                      color: Color(0xFF1877F2),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 20, color: Colors.black87),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.messenger_outline,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FaceBook(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const _TabIcon(icon: Icons.home),
                  ),
                  const _TabIcon(icon: Icons.people_outline, selected: true),
                  const _TabIcon(icon: Icons.storefront_outlined),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const _TabIcon(icon: Icons.notifications_none),
                  ),
                  const _TabIcon(icon: Icons.menu),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.6),

            // Friends Page Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Friends title and search
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Friends',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Icon(Icons.search, size: 24),
                        ],
                      ),
                    ),

                    // Filter Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Friend requests',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Your friends',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // People you may know section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'People you may know',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // People List
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    _PersonCard(name: 'abebe beso'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;

  const _PersonCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE5E6EA),
            child: Icon(Icons.person, color: Colors.black54, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Add friend',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "facebook",
                    style: TextStyle(
                      color: Color(0xFF1877F2),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 20, color: Colors.black87),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E6EA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.messenger_outline,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FaceBook(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const _TabIcon(icon: Icons.home),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendsPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const _TabIcon(icon: Icons.people_outline),
                  ),
                  const _TabIcon(icon: Icons.storefront_outlined),
                  const _TabIcon(
                    icon: Icons.notifications_none,
                    selected: true,
                  ),
                  const _TabIcon(icon: Icons.menu),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.6),

            // Notifications Page Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Notifications title, back arrow, checkmark, and search
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // New label
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        'New',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1877F2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Notifications List
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 25 at 10:58PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    _NotificationCard(
                      name: 'abebe beso',
                      text:
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                      timestamp: 'Dec 23 at 9:29PM',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String name;
  final String text;
  final String timestamp;

  const _NotificationCard({
    required this.name,
    required this.text,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with Facebook icon overlay
          Stack(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFE5E6EA),
                child: Icon(Icons.person, color: Colors.black54, size: 28),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1877F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'f',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black54),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
