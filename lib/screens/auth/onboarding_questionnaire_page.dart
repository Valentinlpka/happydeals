import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Added for image upload
import 'package:flutter/material.dart';
import 'package:happy/screens/main_container.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class OnboardingQuestionnairePage extends StatefulWidget {
  const OnboardingQuestionnairePage({super.key});

  @override
  State<OnboardingQuestionnairePage> createState() => _OnboardingQuestionnairePageState();
}

class _OnboardingQuestionnairePageState extends State<OnboardingQuestionnairePage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _isLoading = false;
  
  // Controllers pour les champs obligatoires
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _associationsController = TextEditingController();
  final TextEditingController _otherMotivationController = TextEditingController();
  final TextEditingController _discoverySourceController = TextEditingController();
  
  // Variables pour les coordonnées
  double? _selectedLatitude;
  double? _selectedLongitude;
  
  // Variables pour la photo de profil
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  
  // Variables pour les choix
  String _selectedGender = '';
  DateTime? _selectedBirthDate;
  final List<String> _selectedCategories = [];
  String _onlineShoppingFrequency = '';
  String _monthlyBudget = '';
  String _localShoppingFrequency = '';
  String _associationMember = '';
  String _localEventsParticipation = '';
  final List<String> _communicationPreferences = [];
  String _discoveryPreference = '';
  String _maxDistance = '';
  String _trocInterest = '';
  final List<String> _upMotivations = [];
  String _economicExpectations = '';
  String _discoverySource = '';
  String _professionalSituation = '';
  String _householdComposition = '';
  bool _acceptCGU = false;
  bool _acceptCGV = false;
  bool _acceptPrivacy = false;
  bool _acceptMarketing = false;
  bool _acceptDataSharing = false;
  bool _acceptSurveys = false;
  
  // Variables pour l'autocomplétion d'adresse (maintenant dans AddressSelectionBottomSheet)
  // List<Map<String, dynamic>> _addressSuggestions = [];
  // bool _isSearchingAddress = false;
  // bool _showAddressSuggestions = false;
  // final FocusNode _addressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
    
    _loadUserData();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber?.replaceFirst('+33', '') ?? '';
      
      // Si l'utilisateur vient de Google Sign-In, pré-remplir les champs
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        final nameParts = user.displayName!.split(' ');
        if (nameParts.isNotEmpty) {
          _firstNameController.text = nameParts.first;
          if (nameParts.length > 1) {
            _lastNameController.text = nameParts.sublist(1).join(' ');
          }
        }
      }
    }
  }

  bool _isEmailFieldEnabled() {
    final user = FirebaseAuth.instance.currentUser;
    // Si l'utilisateur s'est inscrit par téléphone (pas d'email), on doit demander l'email
    return user?.email == null || user!.email!.isEmpty;
  }

  bool _isPhoneFieldEnabled() {
    final user = FirebaseAuth.instance.currentUser;
    // Si l'utilisateur s'est inscrit par email (pas de téléphone), on doit demander le téléphone
    return user?.phoneNumber == null || user!.phoneNumber!.isEmpty;
  }

  // Génération d'un code unique de 5 caractères
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      5, (_) => chars.codeUnitAt(random.nextInt(chars.length))
    ));
  }

  // Vérifier si le code existe déjà dans Firestore
  Future<bool> _isCodeUnique(String code) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uniqueCode', isEqualTo: code)
          .limit(1)
          .get();
      
      return query.docs.isEmpty; // Retourne true si aucun document trouvé (code unique)
    } catch (e) {
      print('Erreur lors de la vérification du code: $e');
      return false; // En cas d'erreur, on considère le code comme non unique
    }
  }

  // Générer un code unique garanti
  Future<String> _generateUniqueCode() async {
    String code;
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 50; // Limite pour éviter une boucle infinie
    
    do {
      code = _generateRandomCode();
      isUnique = await _isCodeUnique(code);
      attempts++;
      
      if (attempts >= maxAttempts) {
        // Si on n'arrive pas à générer un code unique, on ajoute un timestamp
        code = _generateRandomCode();
        break;
      }
    } while (!isUnique);
    
    return code;
  }

  // Méthode _searchAddresses supprimée - maintenant dans AddressSelectionBottomSheet
  
  // Méthodes pour la photo de profil
  Future<void> _selectProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection de l\'image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la prise de photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la prise de photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      // Créer une référence unique pour l'image
      final String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);
      
      // Upload du fichier
      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      final TaskSnapshot snapshot = await uploadTask;
      
      // Récupérer l'URL de téléchargement
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _profileImageUrl = downloadUrl;
        _isUploadingImage = false;
      });
      
      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      
      debugPrint('Erreur lors de l\'upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'upload de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Photo de profil'),
          content: const Text('Comment souhaitez-vous ajouter votre photo ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectProfileImage();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 20),
                  SizedBox(width: 8),
                  Text('Galerie'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _takeProfilePhoto();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 20),
                  SizedBox(width: 8),
                  Text('Appareil photo'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _referralCodeController.dispose();
    _associationsController.dispose();
    _otherMotivationController.dispose();
    _discoverySourceController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitQuestionnaire() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Générer un code unique
      final uniqueCode = await _generateUniqueCode();
      
      // Upload de l'image de profil si elle existe
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await _uploadProfileImage();
        if (profileImageUrl == null) {
          throw Exception('Erreur lors de l\'upload de l\'image de profil');
        }
      }

      // Déterminer l'email et le téléphone
      String email = '';
      String phone = '';
      
      if (_isEmailFieldEnabled()) {
        email = _emailController.text;
      } else {
        email = user.email ?? '';
      }
      
      if (_isPhoneFieldEnabled()) {
        phone = _phoneController.text;
      } else {
        phone = user.phoneNumber ?? '';
      }

      final userData = {
        'type': 'particulier', // Type d'utilisateur
        'uniqueCode': uniqueCode, // Code unique de 5 caractères
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'gender': _selectedGender,
        'birthDate': _selectedBirthDate,
        'email': email,
        'phone': phone,
        'address': _addressController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
        'latitude': _selectedLatitude ?? 0.0,
        'longitude': _selectedLongitude ?? 0.0,
        'selectedCategories': _selectedCategories,
        'onlineShoppingFrequency': _onlineShoppingFrequency,
        'monthlyBudget': _monthlyBudget,
        'localShoppingFrequency': _localShoppingFrequency,
        'associationMember': _associationMember,
        'associations': _associationsController.text,
        'localEventsParticipation': _localEventsParticipation,
        'communicationPreferences': _communicationPreferences,
        'discoveryPreference': _discoveryPreference,
        'maxDistance': _maxDistance,
        'trocInterest': _trocInterest,
        'upMotivations': _upMotivations,
        'economicExpectations': _economicExpectations,
        'discoverySource': _discoverySource,
        'otherDiscoverySource': _discoverySourceController.text,
        'professionalSituation': _professionalSituation,
        'householdComposition': _householdComposition,
        'referredBy': _referralCodeController.text,
        'acceptCGU': _acceptCGU,
        'acceptCGV': _acceptCGV,
        'acceptPrivacy': _acceptPrivacy,
        'acceptMarketing': _acceptMarketing,
        'acceptDataSharing': _acceptDataSharing,
        'acceptSurveys': _acceptSurveys,
        'onboardingCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'loyaltyPoints': 0,
        // Informations Google si disponibles
        if (user.displayName != null) 'displayName': user.displayName,
        if (user.photoURL != null && profileImageUrl == null) 'photoURL': user.photoURL,
        // URL de la photo de profil
        if (profileImageUrl != null) 'image_profile': profileImageUrl,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainContainer()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Informations obligatoires
        bool emailValid = _isEmailFieldEnabled() 
            ? _emailController.text.isNotEmpty && _emailController.text.contains('@')
            : true; // Si le champ est désactivé, il est valide
        bool phoneValid = _isPhoneFieldEnabled() 
            ? _phoneController.text.isNotEmpty && _phoneController.text.length >= 10
            : true; // Si le champ est désactivé, il est valide
        bool addressValid = _addressController.text.isNotEmpty && 
                           _selectedLatitude != null && 
                           _selectedLongitude != null;
            
        return _firstNameController.text.isNotEmpty &&
               _lastNameController.text.isNotEmpty &&
               _selectedGender.isNotEmpty &&
               _selectedBirthDate != null &&
               emailValid &&
               phoneValid &&
               addressValid;
      case 4: // Aspects légaux
        return _acceptCGU && _acceptCGV && _acceptPrivacy;
      default:
        return true; // Les autres sections sont facultatives
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Ajouter SafeArea seulement pour le haut
            SafeArea(
              bottom: false,
              child: _buildHeader(),
            ),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildStep1(), // Informations obligatoires
                  _buildStep2(), // Goûts et préférences
                  _buildStep3(), // Communication
                  _buildStep4(), // Motivations
                  _buildStep5(), // Aspects légaux
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'Informations personnelles',
      'Vos goûts et préférences',
      'Communication',
      'Vos motivations',
      'Finalisation',
    ];
    
    final progressPercentage = ((_currentStep + 1) / _totalSteps * 100).round();
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Questionnaire Up - Particuliers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              // Bouton de déconnexion
              IconButton(
                onPressed: () => _showLogoutDialog(),
                icon: Icon(
                  Icons.logout,
                  color: Colors.grey[600],
                  size: 20,
                ),
                tooltip: 'Se déconnecter',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  titles[_currentStep],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$progressPercentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progressPercentage = (_currentStep + 1) / _totalSteps;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Étape ${_currentStep + 1} sur $_totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progressPercentage * 100).round()}% terminé',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue[700] : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Précédent'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _canProceed() 
                    ? (_currentStep == _totalSteps - 1 ? _submitQuestionnaire : _nextStep)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _currentStep == _totalSteps - 1 ? 'Terminer' : 'Suivant',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section 1: Informations obligatoires
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '📋 INFORMATIONS OBLIGATOIRES',
            subtitle: 'Ces informations sont indispensables pour créer votre compte',
            child: Column(
              children: [
                _buildSectionTitle('👤 Informations personnelles'),
                const SizedBox(height: 16),
                _buildProfileImagePicker(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _firstNameController,
                  label: 'Prénom *',
                  hint: 'Votre prénom',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Nom *',
                  hint: 'Votre nom de famille',
                ),
                const SizedBox(height: 16),
                _buildGenderSelector(),
                const SizedBox(height: 16),
                _buildBirthDatePicker(),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      label: 'Adresse e-mail *',
                      hint: _isEmailFieldEnabled() 
                          ? 'votre.email@exemple.com' 
                          : 'Email utilisé lors de l\'inscription',
                      keyboardType: TextInputType.emailAddress,
                      enabled: _isEmailFieldEnabled(),
                    ),
                    if (!_isEmailFieldEnabled())
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Email de votre inscription',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Numéro de téléphone *',
                      hint: _isPhoneFieldEnabled() 
                          ? '06 12 34 56 78' 
                          : 'Numéro utilisé lors de l\'inscription',
                      keyboardType: TextInputType.phone,
                      enabled: _isPhoneFieldEnabled(),
                    ),
                    if (!_isPhoneFieldEnabled())
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Numéro de votre inscription',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('📍 Adresse'),
                const SizedBox(height: 16),
                _buildAddressAutocomplete(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section 2: Goûts et préférences
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '🎯 VOS GOÛTS ET PRÉFÉRENCES',
            subtitle: 'Aidez-nous à personnaliser votre expérience',
            child: Column(
              children: [
                _buildSectionTitle('🛍️ Catégories qui vous intéressent'),
                const SizedBox(height: 12),
                _buildCategoriesSelector(),
                const SizedBox(height: 24),
                _buildSectionTitle('🛒 Habitudes de shopping'),
                const SizedBox(height: 12),
                _buildRadioGroup(
                  title: 'Fréquence d\'achat en ligne',
                  value: _onlineShoppingFrequency,
                  options: const [
                    'Quotidiennement',
                    'Plusieurs fois par semaine',
                    'Une fois par semaine',
                    'Plusieurs fois par mois',
                    'Rarement',
                    'Jamais',
                  ],
                  onChanged: (value) => setState(() => _onlineShoppingFrequency = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Budget mensuel approximatif',
                  value: _monthlyBudget,
                  options: const [
                    'Moins de 100€',
                    '100€ - 300€',
                    '300€ - 500€',
                    '500€ - 1000€',
                    'Plus de 1000€',
                  ],
                  onChanged: (value) => setState(() => _monthlyBudget = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Fréquentation des commerces locaux',
                  value: _localShoppingFrequency,
                  options: const [
                    'Quotidiennement',
                    'Plusieurs fois par semaine',
                    'Une fois par semaine',
                    'Occasionnellement',
                    'Rarement',
                    'Presque jamais',
                  ],
                  onChanged: (value) => setState(() => _localShoppingFrequency = value!),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🤝 Engagement local'),
                const SizedBox(height: 12),
                _buildRadioGroup(
                  title: 'Membre d\'associations',
                  value: _associationMember,
                  options: const [
                    'Oui',
                    'Non, mais ça m\'intéresse',
                    'Non, pas intéressé(e)',
                  ],
                  onChanged: (value) => setState(() => _associationMember = value!),
                ),
                if (_associationMember == 'Oui') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _associationsController,
                    label: 'Lesquelles ?',
                    hint: 'Listez vos associations',
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Participation aux événements locaux',
                  value: _localEventsParticipation,
                  options: const [
                    'Très souvent',
                    'Parfois',
                    'Rarement',
                    'Jamais',
                  ],
                  onChanged: (value) => setState(() => _localEventsParticipation = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section 3: Communication
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '⚙️ PRÉFÉRENCES DE COMMUNICATION',
            subtitle: 'Comment souhaitez-vous être informé(e) ?',
            child: Column(
              children: [
                _buildCheckboxGroup(
                  title: 'Modes de communication préférés',
                  options: const [
                    'Notifications push',
                    'E-mails',
                    'SMS',
                    'Uniquement sur l\'application',
                  ],
                  selectedValues: _communicationPreferences,
                  onChanged: (value, selected) {
                    setState(() {
                      if (selected) {
                        _communicationPreferences.add(value);
                      } else {
                        _communicationPreferences.remove(value);
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
                _buildRadioGroup(
                  title: 'Comment découvrir de nouveaux commerces',
                  value: _discoveryPreference,
                  options: const [
                    'Recommandations personnalisées',
                    'Proximité géographique',
                    'Avis d\'autres utilisateurs',
                    'Promotions/réductions',
                    'Au hasard',
                  ],
                  onChanged: (value) => setState(() => _discoveryPreference = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Distance maximum de déplacement',
                  value: _maxDistance,
                  options: const [
                    'Moins de 1 km',
                    '1 à 5 km',
                    '5 à 10 km',
                    '10 à 20 km',
                    'Plus de 20 km',
                  ],
                  onChanged: (value) => setState(() => _maxDistance = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Intérêt pour le troc/échange',
                  value: _trocInterest,
                  options: const [
                    'Très intéressé(e)',
                    'Peut-être occasionnellement',
                    'Pas intéressé(e)',
                  ],
                  onChanged: (value) => setState(() => _trocInterest = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section 4: Motivations
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '💡 POURQUOI VOUS ÊTES LÀ',
            subtitle: 'Dites-nous ce qui vous motive !',
            child: Column(
              children: [
                _buildCheckboxGroup(
                  title: 'Ce qui vous attire dans Up',
                  options: const [
                    'Soutenir les commerces locaux',
                    'Économiser grâce au cashback',
                    'Découvrir de nouveaux commerces',
                    'Éviter les grandes plateformes',
                    'Trouver des promotions exclusives',
                    'Utiliser le click & collect',
                    'Participer à la vie locale',
                    'Consommer de façon responsable',
                    'Utiliser le troc et échange',
                    'Conseil personnalisé des commerçants',
                    'Rester informé sur l\'activité locale',
                    'Soutenir des associations',
                  ],
                  selectedValues: _upMotivations,
                  onChanged: (value, selected) {
                    setState(() {
                      if (selected) {
                        _upMotivations.add(value);
                      } else {
                        _upMotivations.remove(value);
                      }
                    });
                  },
                ),
                if (_upMotivations.contains('Autre')) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _otherMotivationController,
                    label: 'Autre motivation',
                    hint: 'Précisez...',
                  ),
                ],
                const SizedBox(height: 24),
                _buildRadioGroup(
                  title: 'Type d\'économies recherchées',
                  value: _economicExpectations,
                  options: const [
                    'Cashback sur tous les achats',
                    'Promotions flash (deals express)',
                    'Cartes de fidélité numériques',
                    'Offres de parrainage',
                    'Toutes ces options',
                  ],
                  onChanged: (value) => setState(() => _economicExpectations = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Comment nous avez-vous découverts',
                  value: _discoverySource,
                  options: const [
                    'Recommandation d\'un proche',
                    'Publicité en ligne',
                    'Article de presse/blog',
                    'Événement local',
                    'Commerçant partenaire',
                    'Recherche sur internet',
                    'Autre',
                  ],
                  onChanged: (value) => setState(() => _discoverySource = value!),
                ),
                if (_discoverySource == 'Autre') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _discoverySourceController,
                    label: 'Précisez',
                    hint: 'Comment nous avez-vous connus ?',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section 5: Aspects légaux
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '✅ FINALISATION',
            subtitle: 'Dernières informations et consentements',
            child: Column(
              children: [
                _buildSectionTitle('👤 Informations personnelles'),
                const SizedBox(height: 12),
                _buildRadioGroup(
                  title: 'Situation professionnelle',
                  value: _professionalSituation,
                  options: const [
                    'Salarié(e)',
                    'Indépendant(e)/Chef d\'entreprise',
                    'Étudiant(e)',
                    'Retraité(e)',
                    'En recherche d\'emploi',
                    'Autre',
                  ],
                  onChanged: (value) => setState(() => _professionalSituation = value!),
                ),
                const SizedBox(height: 16),
                _buildRadioGroup(
                  title: 'Composition du foyer',
                  value: _householdComposition,
                  options: const [
                    'Seul(e)',
                    'En couple sans enfant',
                    'En couple avec enfant(s)',
                    'Famille monoparentale',
                    'Colocation',
                    'Autre',
                  ],
                  onChanged: (value) => setState(() => _householdComposition = value!),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _referralCodeController,
                  label: 'Code de parrainage (optionnel)',
                  hint: 'Si vous avez été parrainé(e)',
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('📜 Consentements obligatoires'),
                const SizedBox(height: 12),
                _buildCheckboxTile(
                  title: 'J\'accepte les Conditions Générales d\'Utilisation *',
                  subtitle: 'Les règles du jeu pour utiliser Up sereinement',
                  value: _acceptCGU,
                  onChanged: (value) => setState(() => _acceptCGU = value!),
                  required: true,
                ),
                _buildCheckboxTile(
                  title: 'J\'accepte les Conditions Générales de Vente *',
                  subtitle: 'Pour que vos achats se passent sans accroc',
                  value: _acceptCGV,
                  onChanged: (value) => setState(() => _acceptCGV = value!),
                  required: true,
                ),
                _buildCheckboxTile(
                  title: 'J\'accepte la Politique de Confidentialité *',
                  subtitle: 'On vous explique tout sur l\'utilisation de vos données',
                  value: _acceptPrivacy,
                  onChanged: (value) => setState(() => _acceptPrivacy = value!),
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('📧 Communications optionnelles'),
                const SizedBox(height: 12),
                _buildCheckboxTile(
                  title: 'Communications marketing',
                  subtitle: 'Newsletters, nouveautés, conseils...',
                  value: _acceptMarketing,
                  onChanged: (value) => setState(() => _acceptMarketing = value!),
                ),
                _buildCheckboxTile(
                  title: 'Partage de données avec les commerçants',
                  subtitle: 'Pour des offres personnalisées',
                  value: _acceptDataSharing,
                  onChanged: (value) => setState(() => _acceptDataSharing = value!),
                ),
                _buildCheckboxTile(
                  title: 'Enquêtes de satisfaction',
                  subtitle: 'Pour nous aider à améliorer Up',
                  value: _acceptSurveys,
                  onChanged: (value) => setState(() => _acceptSurveys = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widgets helpers
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImagePicker() {
    return Column(
      children: [
        const Text(
          'Photo de profil (optionnel)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _showImagePickerDialog,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: _profileImage != null || _profileImageUrl != null 
                        ? Colors.blue[700]! 
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _profileImage != null
                      ? Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : _profileImageUrl != null
                          ? Image.network(
                              _profileImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                ),
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    _profileImage != null || _profileImageUrl != null 
                        ? Icons.edit 
                        : Icons.add_a_photo,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tapez pour ajouter une photo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sexe *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('Homme', Icons.man),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Femme', Icons.woman),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Autre', Icons.person),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue[700] : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              gender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date de naissance *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 ans
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _selectedBirthDate = date);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedBirthDate != null
                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                      : 'Sélectionnez votre date de naissance',
                  style: TextStyle(
                    color: _selectedBirthDate != null ? Colors.black : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSelector() {
    final categories = [
      '🍽️ Restaurants & Alimentation',
      '👗 Mode & Vêtements',
      '💄 Beauté & Bien-être',
      '🏠 Maison & Décoration',
      '⚽ Sport & Loisirs',
      '📚 Culture & Éducation',
      '🔧 Services & Artisanat',
      '🚗 Automobile & Transport',
      '👶 Enfants & Famille',
      '🎁 Cadeaux & Occasions spéciales',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((category) {
        final isSelected = _selectedCategories.contains(category);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCategories.remove(category);
              } else {
                _selectedCategories.add(category);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRadioGroup({
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((option) => RadioListTile<String>(
          title: Text(
            option,
            style: const TextStyle(fontSize: 14),
          ),
          value: option,
          groupValue: value,
          onChanged: onChanged,
          dense: true,
          contentPadding: EdgeInsets.zero,
        )),
      ],
    );
  }

  Widget _buildCheckboxGroup({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required Function(String, bool) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((option) => CheckboxListTile(
          title: Text(
            option,
            style: const TextStyle(fontSize: 14),
          ),
          value: selectedValues.contains(option),
          onChanged: (selected) => onChanged(option, selected ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        )),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool required = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: required && !value ? Colors.red[300]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget d'adresse qui ouvre un bottom sheet pour la saisie
  Widget _buildAddressAutocomplete() {
    final bool isAddressValid = _addressController.text.isNotEmpty && 
                               _selectedLatitude != null && 
                               _selectedLongitude != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label avec indicateur de validation
        Row(
          children: [
            const Text(
              'Adresse complète *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(width: 8),
            if (isAddressValid)
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 16,
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Champ cliquable qui ouvre le bottom sheet
        GestureDetector(
          onTap: _openAddressBottomSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAddressValid ? Colors.green[300]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: isAddressValid ? Colors.green[600] : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _addressController.text.isEmpty 
                        ? '123 rue de la Paix, 75001 Paris'
                        : _addressController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: _addressController.text.isEmpty 
                          ? Colors.grey[500]
                          : const Color(0xFF1F2937),
                      fontWeight: _addressController.text.isEmpty 
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isAddressValid 
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: isAddressValid 
                      ? Colors.green[600]
                      : Colors.grey[400],
                  size: isAddressValid ? 20 : 16,
                ),
              ],
            ),
          ),
        ),
        
        // Informations sur l'adresse sélectionnée
        if (isAddressValid && _cityController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.location_city, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 4),
                Text(
                  '${_cityController.text}${_postalCodeController.text.isNotEmpty ? ' - ${_postalCodeController.text}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  // Méthode appelée quand une adresse est sélectionnée
  void _onAddressSelected(Map<String, dynamic> addressData) {
    setState(() {
      _addressController.text = addressData['address'] ?? '';
      _cityController.text = addressData['city'] ?? '';
      _postalCodeController.text = addressData['postalCode'] ?? '';
      _selectedLatitude = addressData['latitude']?.toDouble();
      _selectedLongitude = addressData['longitude']?.toDouble();
    });
    
    debugPrint('Adresse sélectionnée: ${addressData['address']}');
    debugPrint('Coordonnées: $_selectedLatitude, $_selectedLongitude');
  }

  // Méthode _onAddressChanged supprimée - plus nécessaire avec le bottom sheet

  void _openAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return AddressSelectionBottomSheet(
              currentAddress: _addressController.text,
              onAddressSelected: (addressData) {
                _onAddressSelected(addressData);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange[700], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Se déconnecter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?\n\nVotre progression dans le questionnaire sera perdue.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Fermer le dialogue
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Se déconnecter',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
} 

// Widget séparé pour la sélection d'adresse en bottom sheet
class AddressSelectionBottomSheet extends StatefulWidget {
  final String currentAddress;
  final Function(Map<String, dynamic>) onAddressSelected;

  const AddressSelectionBottomSheet({
    super.key,
    required this.currentAddress,
    required this.onAddressSelected,
  });

  @override
  State<AddressSelectionBottomSheet> createState() => _AddressSelectionBottomSheetState();
}

class _AddressSelectionBottomSheetState extends State<AddressSelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  
  // Token Mapbox pour l'autocomplétion
  static const String mapboxAccessToken = 'pk.eyJ1IjoiaGFwcHlkZWFscyIsImEiOiJjbHo3ZHA5NDYwN2hyMnFzNTdiMWd2Zm92In0.1nmT5Fumjq16InZ3dmG9zQ';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.currentAddress;
    // Auto-focus pour afficher le clavier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchAddresses(String query) async {
    if (query.length < 3) return [];
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=$mapboxAccessToken'
          '&country=FR'
          '&types=address,poi'
          '&limit=8';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        return features.map<Map<String, dynamic>>((feature) {
          final geometry = feature['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final context = feature['context'] as List? ?? [];
          
          // Extraire les informations d'adresse
          String address = feature['place_name'] ?? '';
          String city = '';
          String postalCode = '';
          
          // Chercher la ville et le code postal dans le context
          for (var contextItem in context) {
            final id = contextItem['id'] ?? '';
            if (id.startsWith('place.')) {
              city = contextItem['text'] ?? '';
            } else if (id.startsWith('postcode.')) {
              postalCode = contextItem['text'] ?? '';
            }
          }
          
          return {
            'address': address,
            'city': city,
            'postalCode': postalCode,
            'latitude': coordinates[1], // longitude, latitude dans Mapbox
            'longitude': coordinates[0],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Erreur lors de la recherche d\'adresse: $e');
    }
    
    return [];
  }

  void _onSearchChanged(String query) {
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final suggestions = await _searchAddresses(query);
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle du bottom sheet
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header avec titre et bouton fermer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📍 Sélectionner une adresse',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Tapez votre adresse...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[700]!),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _suggestions = [];
                                _isLoading = false;
                              });
                            },
                          )
                        : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Liste des suggestions
          Expanded(
            child: _suggestions.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_searching,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.length < 3
                              ? 'Tapez au moins 3 caractères pour rechercher'
                              : 'Aucune adresse trouvée',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          suggestion['address'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: suggestion['city'] != null && suggestion['postalCode'] != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${suggestion['city']} - ${suggestion['postalCode']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        onTap: () {
                          widget.onAddressSelected(suggestion);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 