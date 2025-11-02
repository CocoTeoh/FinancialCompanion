
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // NOTE: If your bottom nav disappears when you navigate here,
  // make sure you push this page on the TAB's nested Navigator, not the root.
  // Example from ProfilePage tile:
  // Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Country + phone code (simple built-in list to avoid extra packages)
  // You can expand this list anytime.
  final List<_Country> _countries = const [
    _Country('Malaysia', 'MY', '+60', '🇲🇾'),
    _Country('Singapore', 'SG', '+65', '🇸🇬'),
    _Country('Indonesia', 'ID', '+62', '🇮🇩'),
    _Country('Thailand', 'TH', '+66', '🇹🇭'),
    _Country('Philippines', 'PH', '+63', '🇵🇭'),
  ];

  late _Country _selectedCountry;
  String _gender = 'Female';

  String? _photoUrl;     // existing or uploaded
  File? _pickedImage;    // local selected file

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countries.first; // default MY
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
      final data = doc.data() ?? {};

      _first.text = (data['firstName'] ?? '').toString();
      _last.text = (data['lastName'] ?? '').toString();
      _email.text = _user.email ?? (data['email'] ?? '');
      _phone.text = (data['phoneNumber'] ?? '').toString();

      _gender = (data['gender'] ?? _gender).toString();

      // country by name or code; default Malaysia
      final savedCountry = (data['country'] ?? 'Malaysia').toString();
      final match = _countries.where((c) => c.name == savedCountry || c.code == savedCountry).toList();
      if (match.isNotEmpty) _selectedCountry = match.first;

      _photoUrl = (data['photoUrl'] ?? _user.photoURL)?.toString();
    } catch (_) {
      // keep defaults; show a non-blocking message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile; using defaults.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadPhotoIfNeeded() async {
    if (_pickedImage == null) return _photoUrl; // no change
    final ref = FirebaseStorage.instance.ref().child('users/${_user.uid}/profile.jpg');
    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final photoUrl = await _uploadPhotoIfNeeded();

      // Update Auth email if changed (newer FlutterFire)
      if (_email.text.trim() != (_user.email ?? '')) {
        await _user.verifyBeforeUpdateEmail(_email.text.trim());
        // Optional: tell user to confirm
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check your inbox to confirm the new email.')),
          );
        }
      }


      // Optionally update displayName/photo in Auth profile
      final displayName = '${_first.text.trim()} ${_last.text.trim()}'.trim();
      await _user.updateDisplayName(displayName.isEmpty ? null : displayName);
      if (photoUrl != null) await _user.updatePhotoURL(photoUrl);

      // Persist to Firestore
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'country': _selectedCountry.name,
        'countryCode': _selectedCountry.dialCode,
        'gender': _gender,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context); // go back to ProfilePage (bottom bar remains if using nested nav)
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'requires-recent-login' => 'Please log in again to change your email.',
        _ => e.message ?? 'Auth error',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This cannot be undone. You might need to re-authenticate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Clean Firestore and Storage (best-effort)
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).delete();
      await FirebaseStorage.instance.ref('users/${_user.uid}/profile.jpg').delete().catchError((_) {});
      await _user.delete(); // may throw requires-recent-login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code == 'requires-recent-login'
              ? 'Please re-login, then try deleting again.'
              : 'Delete failed: ${e.message}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF8EBB87);

    return Scaffold(
      backgroundColor: green,
      appBar: AppBar(
        backgroundColor: green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              // Avatar with edit button
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider<Object>?,
                    child: (_pickedImage == null && _photoUrl == null)
                        ? const Icon(Icons.person, size: 48, color: Colors.black54)
                        : null,
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4, right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black12)],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.edit, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _LabeledField(
                      label: 'First name',
                      controller: _first,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: 'Last name',
                      controller: _last,
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),

                    // Phone with flag + code prefix
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Phone number'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _showCountryPicker(),
                                child: Row(
                                  children: [
                                    Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedCountry.dialCode,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: '6012-345-7890',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Country + Gender row
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownField<_Country>(
                            label: 'Country',
                            value: _selectedCountry,
                            items: _countries
                                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                                .toList(),
                            onChanged: (c) => setState(() => _selectedCountry = c!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DropdownField<String>(
                            label: 'Gender',
                            value: _gender,
                            items: const [
                              DropdownMenuItem(value: 'Female', child: Text('Female', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Male', child: Text('Male', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Other', child: Text('Other', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(
                                value: 'Prefer not to say',
                                child: Text('Prefer not to say', overflow: TextOverflow.ellipsis),
                              ),
                            ],

                            onChanged: (g) => setState(() => _gender = g!),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B8761),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('SUBMIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _deleteAccount,
                      child: const Text('Delete Account', style: TextStyle(color: Colors.black54)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          children: _countries
              .map(
                (c) => ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 20)),
              title: Text(c.name),
              trailing: Text(c.dialCode, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() => _selectedCountry = c);
                Navigator.pop(context);
              },
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

// ---------- UI helpers ----------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '',
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<T>(

            initialValue: value,
            isExpanded: true,                // <-- important
            menuMaxHeight: 320,              // optional but nice
            items: items,
            onChanged: onChanged,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }
}


class _Country {
  final String name;
  final String code;     // ISO alpha-2
  final String dialCode; // +60
  final String flag;     // emoji
  const _Country(this.name, this.code, this.dialCode, this.flag);
}
