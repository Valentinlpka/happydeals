import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/menu_item.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:provider/provider.dart';

class MenuCustomizationPage extends StatefulWidget {
  final RestaurantMenu menu;
  final String restaurantId;

  const MenuCustomizationPage({
    super.key,
    required this.menu,
    required this.restaurantId,
  });

  @override
  State<MenuCustomizationPage> createState() => _MenuCustomizationPageState();
}

class MenuCustomization {
  final Map<String, String> mainItemVariants;
  final Map<String, MenuOptionSelection> options;

  MenuCustomization({
    required this.mainItemVariants,
    required this.options,
  });
}

class MenuOptionSelection {
  final String itemId;
  final Map<String, String> variants;

  MenuOptionSelection({
    required this.itemId,
    required this.variants,
  });
}

class _MenuCustomizationPageState extends State<MenuCustomizationPage> {
  // États principaux
  MenuTemplate? menuTemplate;
  Map<String, VariantTemplate> loadedTemplateItems = {};
  MenuCustomization customization = MenuCustomization(
    mainItemVariants: {},
    options: {},
  );
  
  int currentStep = 0;
  double totalPrice = 0.0;
  bool isLoading = true;
  bool isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _startCustomization();
  }

  Future<void> _startCustomization() async {
    print('=== DÉMARRAGE PERSONNALISATION ===');
    print('Menu: ${widget.menu.name}');
    print('Template ID: ${widget.menu.menuTemplateId}');
    
    if (widget.menu.menuTemplateId.isEmpty) {
      print('Pas de template, affichage interface simple');
      setState(() {
        isLoading = false;
      });
      return;
    }

    await _loadMenuTemplate();
    await _initializeCustomization();
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMenuTemplate() async {
    if (widget.menu.menuTemplateId.isEmpty) return;
    
    try {
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      final templatesData = await menuProvider.loadMenuTemplates(widget.menu.menuTemplateId);
      
      if (templatesData != null) {
        menuTemplate = templatesData['menuTemplate'] as MenuTemplate;
        loadedTemplateItems = templatesData['variantTemplates'] as Map<String, VariantTemplate>;
        
        print('Template chargé: ${menuTemplate!.name}');
        print('Variant templates: ${loadedTemplateItems.keys.toList()}');
      }
    } catch (error) {
      print('Erreur lors du chargement du template: $error');
    }
  }

  Future<void> _initializeCustomization() async {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    
    // Initialiser avec le prix de base
    totalPrice = widget.menu.basePrice;
    print('Prix de base: $totalPrice€');

    // Initialiser les variantes de l'article principal
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    final Map<String, String> defaultMainVariants = {};
    
    // Pour l'instant, pas de variantes sur les items principaux
    print('Article principal: ${mainItem?.name}');

    // Initialiser les options par défaut pour chaque template
    final Map<String, MenuOptionSelection> defaultOptions = {};
    
    if (menuTemplate != null) {
      for (final template in menuTemplate!.includedVariantTemplates) {
        final variantTemplate = loadedTemplateItems[template.templateId];
        if (variantTemplate == null) continue;

        print('Traitement template: ${template.label}');

        // Trouver l'option par défaut
        final defaultItem = variantTemplate.referencedItems
            .where((item) => item.isDefault)
            .firstOrNull ?? variantTemplate.referencedItems.first;

        final item = menuProvider.getItemById(defaultItem.itemId);
        if (item != null) {
          print('Item par défaut: ${item.name}');
          
          // Calculer le prix avec override
          final priceOverride = _getPriceOverride(template.templateId, item.id);
          totalPrice += priceOverride;
          print('Prix override: +$priceOverride€');

          // Pour l'instant, pas de variantes sur les items individuels
          final Map<String, String> itemVariants = {};

          defaultOptions[template.templateId] = MenuOptionSelection(
            itemId: defaultItem.itemId,
            variants: itemVariants,
          );
        }
      }
    }

    setState(() {
      customization = MenuCustomization(
        mainItemVariants: defaultMainVariants,
        options: defaultOptions,
      );
      currentStep = 0;
    });

    print('Prix total initialisé: $totalPrice€');
    print('Options par défaut: ${defaultOptions.keys.toList()}');
  }

  double _getPriceOverride(String templateId, String itemId) {
    final templateOverrides = widget.menu.templateOverrides;
    if (templateOverrides != null && templateOverrides.containsKey(templateId)) {
      final override = templateOverrides[templateId];
      if (override != null && override.priceOverrides != null) {
        return override.priceOverrides![itemId] ?? 0.0;
      }
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Personnaliser ${widget.menu.name}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildCustomizationContent()),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: 80.w,
              height: 80.h,
              child: widget.menu.images.isNotEmpty
                  ? Image.network(
                      widget.menu.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.restaurant_menu, size: 32.sp),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.restaurant_menu, size: 32.sp),
                    ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text('MENU', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                SizedBox(height: 8.h),
                Text(widget.menu.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                Text(widget.menu.description, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationContent() {
    if (menuTemplate == null) {
      return _buildSimpleCustomization();
    }

    return _buildStepByStepCustomization();
  }

  Widget _buildStepByStepCustomization() {
    final steps = _buildCustomizationSteps();
    
    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.orange),
            SizedBox(height: 16.h),
            Text('Aucune étape de personnalisation trouvée', style: TextStyle(fontSize: 16.sp)),
          ],
        ),
      );
    }
    
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateur d'étapes
          _buildStepIndicator(steps.length),
          SizedBox(height: 24.h),
          
          // Titre de l'étape
          Text(
            steps[currentStep]['title'] as String,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          
          // Contenu de l'étape actuelle
          Expanded(
            child: SingleChildScrollView(
              child: steps[currentStep]['content'] as Widget,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Boutons de navigation
          _buildNavigationButtons(steps.length),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildCustomizationSteps() {
    final steps = <Map<String, dynamic>>[];
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);

    // Étape 1: Article principal (toujours présent)
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    if (mainItem != null) {
      steps.add({
        'title': 'Article principal',
        'content': _buildMainItemStep(mainItem),
      });
    }

    // Étapes pour les templates de variantes
    if (menuTemplate != null) {
      final sortedTemplates = menuTemplate!.includedVariantTemplates
          .where((t) => loadedTemplateItems.containsKey(t.templateId))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final template in sortedTemplates) {
        final variantTemplate = loadedTemplateItems[template.templateId]!;
        steps.add({
          'title': template.label ?? variantTemplate.name,
          'content': _buildVariantTemplateStep(template, variantTemplate),
        });
      }
    }

    print('Étapes construites: ${steps.map((s) => s['title']).toList()}');
    return steps;
  }

  Widget _buildStepIndicator(int totalSteps) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 2.w),
            height: 4.h,
            decoration: BoxDecoration(
              color: isActive || isCompleted 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMainItemStep(MenuItem mainItem) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8.r, offset: Offset(0, 2.h))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Affichage de l'article principal
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  width: 80.w,
                  height: 80.h,
                  child: mainItem.images.isNotEmpty
                      ? Image.network(mainItem.images.first, fit: BoxFit.cover)
                      : Container(color: Colors.grey[200], child: Icon(Icons.restaurant, size: 32.sp)),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mainItem.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text(mainItem.description, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Cet article est inclus dans votre menu',
                    style: TextStyle(fontSize: 14.sp, color: Colors.green[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantTemplateStep(IncludedVariantTemplate template, VariantTemplate variantTemplate) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final selectedItemId = customization.options[template.templateId]?.itemId;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8.r, offset: Offset(0, 2.h))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indication obligatoire/optionnel
          Row(
            children: [
              if (template.isRequired)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text('* Choix obligatoire', style: TextStyle(fontSize: 12.sp, color: Colors.orange[700])),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text('Choix optionnel', style: TextStyle(fontSize: 12.sp, color: Colors.blue[700])),
                ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Sélection du produit
          ...variantTemplate.referencedItems.map((referencedItem) {
            final item = menuProvider.getItemById(referencedItem.itemId);
            if (item == null) return const SizedBox.shrink();
            
            final isSelected = selectedItemId == item.id;
            final priceOverride = _getPriceOverride(template.templateId, item.id);
            
            return _buildOptionTile(template, item, referencedItem.displayName, isSelected, priceOverride);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    IncludedVariantTemplate template,
    MenuItem item,
    String displayName,
    bool isSelected,
    double priceOverride,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleOptionSelect(template.templateId, item.id),
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: Container(
                    width: 50.w,
                    height: 50.h,
                    child: item.images.isNotEmpty
                        ? Image.network(item.images.first, fit: BoxFit.cover)
                        : Container(color: Colors.grey[200], child: Icon(Icons.fastfood, size: 24.sp)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                      if (item.description.isNotEmpty)
                        Text(item.description, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (priceOverride > 0)
                      Text('+${priceOverride.toStringAsFixed(2)}€', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    SizedBox(height: 4.h),
                    Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      ),
                      child: isSelected ? Icon(Icons.check, size: 16.sp, color: Colors.white) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleOptionSelect(String templateId, String itemId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final newItem = menuProvider.getItemById(itemId);
    if (newItem == null) return;

    print('Sélection option: $templateId -> ${newItem.name}');

    // Calculer la différence de prix
    final currentSelection = customization.options[templateId];
    double priceDifference = 0;

    // Soustraire l'ancien prix override
    if (currentSelection != null) {
      final oldPriceOverride = _getPriceOverride(templateId, currentSelection.itemId);
      priceDifference -= oldPriceOverride;
      print('Ancien prix override: -$oldPriceOverride€');
    }

    // Ajouter le nouveau prix override
    final newPriceOverride = _getPriceOverride(templateId, itemId);
    priceDifference += newPriceOverride;
    print('Nouveau prix override: +$newPriceOverride€');

    setState(() {
      totalPrice += priceDifference;
      customization.options[templateId] = MenuOptionSelection(
        itemId: itemId,
        variants: {},
      );
    });

    print('Nouveau prix total: $totalPrice€');
  }

  Widget _buildNavigationButtons(int totalSteps) {
    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => currentStep--),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: const Text('Précédent'),
            ),
          ),
        if (currentStep > 0) SizedBox(width: 16.w),
        Expanded(
          flex: currentStep == 0 ? 1 : 1,
          child: ElevatedButton(
            onPressed: isAddingToCart ? null : () {
              if (currentStep == totalSteps - 1) {
                _addToCart();
              } else {
                setState(() => currentStep++);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: isAddingToCart
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    currentStep == totalSteps - 1
                        ? 'Ajouter au panier (${totalPrice.toStringAsFixed(2)}€)'
                        : 'Suivant',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleCustomization() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64.sp, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text('Ce menu n\'a pas de template de personnalisation', style: TextStyle(fontSize: 16.sp, color: Colors.grey[600])),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.menu.name} ajouté au panier (${widget.menu.basePrice.toStringAsFixed(2)}€)'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Ajouter au panier (${widget.menu.basePrice.toStringAsFixed(2)}€)'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.r,
            offset: Offset(0, -2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Prix total: ${totalPrice.toStringAsFixed(2)}€', 
               style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          Text('Menu personnalisé', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _addToCart() async {
    setState(() => isAddingToCart = true);

    try {
      // Créer l'objet de commande avec toute la personnalisation
      final customizedMenu = {
        'menuId': widget.menu.id,
        'menuName': widget.menu.name,
        'basePrice': widget.menu.basePrice,
        'totalPrice': totalPrice,
        'customization': {
          'mainItem': {
            'itemId': customization.mainItemVariants,
          },
          'options': customization.options.map((key, value) => MapEntry(key, {
            'itemId': value.itemId,
            'variants': value.variants,
          })),
        },
      };

      print('=== MENU AJOUTÉ AU PANIER ===');
      print('Menu: ${widget.menu.name}');
      print('Prix total: ${totalPrice}€');
      print('Options sélectionnées:');
      customization.options.forEach((templateId, selection) {
        final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
        final selectedItem = menuProvider.getItemById(selection.itemId);
        final priceOverride = _getPriceOverride(templateId, selection.itemId);
        print('  - $templateId: ${selectedItem?.name} (+${priceOverride}€)');
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.menu.name} personnalisé ajouté au panier (${totalPrice.toStringAsFixed(2)}€)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isAddingToCart = false);
    }
  }
} 