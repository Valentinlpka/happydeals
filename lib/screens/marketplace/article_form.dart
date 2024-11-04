import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/category.dart';
import 'package:happy/screens/marketplace/city_autocomplete.dart';
import 'package:happy/screens/marketplace/custom_widget.dart';
import 'package:happy/screens/marketplace/photo_section.dart';

class ArticleForm extends StatefulWidget {
  final GlobalKey<ArticleFormState> formKey = GlobalKey<ArticleFormState>();
  final Ad? existingAd;

  ArticleForm({super.key, this.existingAd});

  @override
  ArticleFormState createState() => ArticleFormState();

  Map<String, dynamic> getFormData() {
    final state = formKey.currentState;
    if (state != null) {
      return state.getFormData();
    }
    return {};
  }
}

class ArticleFormState extends State<ArticleForm> {
  final GlobalKey<PhotoSectionState> _photoSectionKey =
      GlobalKey<PhotoSectionState>();

  String? selectedCategory;
  String? selectedSubCategory;

  String? selectedState;
  String? selectedMeetingPreference;
  List<Category> categories = []; // Liste des catégories

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _loadCategories() {
    // Votre JSON (à charger depuis un fichier ou une API)
    final categoriesJson = {
      "categories": [
        {
          "nom": "Équipements",
          "sous-catégories": [
            "Équipement auto",
            "Équipement moto",
            "Équipement vélo",
            "Équipements pour bureau",
            "Équipements pour restaurants",
            "Équipements pour hôtels",
            "Équipements médicaux"
          ]
        },
        {
          "nom": "Mode",
          "sous-catégories": [
            "Vêtements",
            "Chaussures",
            "Montres et bijoux",
            "Sacs et accessoires"
          ]
        },
        {
          "nom": "Loisirs",
          "sous-catégories": [
            "Instruments de musique",
            "Collection",
            "Modélisme",
            "Jeux vidéos",
            "Sports et plein air",
            "Jardin et plantes"
          ]
        },
        {
          "nom": "Électronique",
          "sous-catégories": [
            "Téléphones",
            "Objets connectés",
            "Tablettes",
            "Photo",
            "Audio",
            "Vidéo",
            "Consoles",
            "Accessoires informatiques"
          ]
        },
        {
          "nom": "Maison",
          "sous-catégories": [
            "Ameublement",
            "Électroménager",
            "Décoration",
            "Arts de la table",
            "Linge de maison",
            "Bricolage"
          ]
        },
        {
          "nom": "Multimédia",
          "sous-catégories": ["Livres", "Musique", "Films/DVD"]
        },
        {
          "nom": "Services",
          "sous-catégories": ["Emplois", "Services divers"]
        },
        {
          "nom": "Autres",
          "sous-catégories": [
            "Accessoires pour animaux",
            "Loisirs créatifs",
            "Matériel de bureau",
            "Fournitures scolaires"
          ]
        }
      ]
    };

    categories = (categoriesJson['categories'] as List)
        .map((cat) => Category.fromJson(cat))
        .toList();
  }

  void _showCategoryPicker() {
    String? tempCategory;
    String? tempSubCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choisir une catégorie',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            // Liste des catégories principales
                            Expanded(
                              flex: 1,
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final isSelected =
                                      category.name == tempCategory;
                                  return Container(
                                    color: isSelected
                                        ? Colors.blue.withOpacity(0.1)
                                        : null,
                                    child: ListTile(
                                      title: Text(
                                        category.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.black,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          tempCategory = category.name;
                                          tempSubCategory = null;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Séparateur vertical
                            Container(
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            // Liste des sous-catégories
                            Expanded(
                              flex: 1,
                              child: tempCategory == null
                                  ? const Center(
                                      child: Text('Sélectionnez une catégorie'))
                                  : ListView.builder(
                                      itemCount: categories
                                          .firstWhere(
                                              (cat) => cat.name == tempCategory)
                                          .subCategories
                                          .length,
                                      itemBuilder: (context, index) {
                                        final subCategories = categories
                                            .firstWhere((cat) =>
                                                cat.name == tempCategory)
                                            .subCategories;
                                        final subCategory =
                                            subCategories[index];
                                        final isSelected =
                                            subCategory == tempSubCategory;
                                        return ListTile(
                                          title: Text(
                                            subCategory,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.black,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : null,
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              tempSubCategory = subCategory;
                                            });
                                            // Mettre à jour les sélections et fermer
                                            this.setState(() {
                                              selectedCategory = tempCategory;
                                              selectedSubCategory =
                                                  tempSubCategory;
                                            });
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    _titleController.text = ad.title;
    _priceController.text = ad.price.toString();
    _descriptionController.text = ad.description;
    _brandController.text = ad.additionalData['brand'] as String? ?? '';
    _tagsController.text = ad.additionalData['tags'] as String? ?? '';
    _locationController.text = ad.additionalData['location'] as String? ?? '';

    selectedCategory = ad.additionalData['category'] as String?;
    selectedState = ad.additionalData['condition'] as String?;
    selectedMeetingPreference =
        ad.additionalData['meetingPreference'] as String?;

    if (ad.photos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _photoSectionKey.currentState?.setExistingPhotos(ad.photos);
      });
    }

    setState(
        () {}); // Cette ligne est nécessaire pour mettre à jour les dropdowns
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          PhotoSection(key: _photoSectionKey),
          const SizedBox(height: 16),
          buildTextField('Titre', _titleController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: buildTextField('Prix', _priceController)),
              const SizedBox(width: 16),
              Expanded(child: buildCategorySelector()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setDropdownState) {
                    return buildDropdown(
                      'État',
                      selectedState,
                      [
                        'Neuf',
                        'Très bon état',
                        'Bon état',
                        'Satisfaisant',
                        'À rénover'
                      ],
                      (value) => setDropdownState(() => selectedState = value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Marque', _brandController)),
            ],
          ),
          const SizedBox(height: 16),
          buildTextField('Description', _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          buildTextField('Tags de produit', _tagsController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildCityTextField('Lieu', _locationController),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setDropdownState) {
                    return buildDropdown(
                      'Préférence de rencontre',
                      selectedMeetingPreference,
                      ['En personne', 'Livraison', 'Les deux'],
                      (value) => setDropdownState(
                          () => selectedMeetingPreference = value),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> getFormData() {
    return {
      'title': _titleController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'category': selectedCategory ?? '',
      'condition': selectedState ?? '',
      'brand': _brandController.text,
      'description': _descriptionController.text,
      'tags': _tagsController.text,
      'location': _locationController.text,
      'meetingPreference': selectedMeetingPreference ?? '',
      'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
    };
  }

  Widget buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showCategoryPicker,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedSubCategory ?? 'Sélectionner une catégorie',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedSubCategory != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
