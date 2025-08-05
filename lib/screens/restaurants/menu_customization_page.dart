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

// Classes pour gérer la customisation du menu
class MenuCustomization {
  final MainItemSelection mainItem;
  final Map<String, OptionSelection> options;

  MenuCustomization({
    required this.mainItem,
    required this.options,
  });
}

class MainItemSelection {
  final String itemId;
  final Map<String, String> variants;

  MainItemSelection({
    required this.itemId,
    required this.variants,
  });
}

class OptionSelection {
  final String itemId;
  final Map<String, String> variants;

  OptionSelection({
    required this.itemId,
    required this.variants,
  });
}

class CustomizationStep {
  final String title;
  final Widget content;
  final bool isCompleted;

  CustomizationStep({
    required this.title,
    required this.content,
    this.isCompleted = false,
  });
}

class _MenuCustomizationPageState extends State<MenuCustomizationPage> {
  // États principaux
  MenuTemplate? menuTemplate;
  Map<String, VariantTemplate> loadedTemplateItems = {};
  late MenuCustomization customization;
  
  int currentStep = 0;
  double totalPrice = 0.0;
  bool isLoading = true;
  bool isAddingToCart = false;
  List<CustomizationStep> steps = [];

  @override
  void initState() {
    super.initState();
    _startCustomization();
  }

  Future<void> _startCustomization() async {
    debugPrint('=== DÉMARRAGE PERSONNALISATION ===');
    debugPrint('Menu: ${widget.menu.name}');
    debugPrint('Template ID: ${widget.menu.menuTemplateId}');
    
    if (widget.menu.menuTemplateId.isEmpty) {
      debugPrint('Pas de template, affichage interface simple');
      _initializeSimpleCustomization();
      setState(() {
        isLoading = false;
      });
      return;
    }

    await _loadMenuTemplate();
    await _initializeCustomization();
    _buildCustomizationSteps();
    
    setState(() {
      isLoading = false;
    });
  }

  void _initializeSimpleCustomization() {
    totalPrice = widget.menu.basePrice;
    
    customization = MenuCustomization(
      mainItem: MainItemSelection(
        itemId: widget.menu.mainItem.itemId,
        variants: {},
      ),
      options: {},
    );
  }

  Future<void> _loadMenuTemplate() async {
    if (widget.menu.menuTemplateId.isEmpty) return;
    
    try {
      debugPrint('Chargement du template: ${widget.menu.menuTemplateId}');
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      final templatesData = await menuProvider.loadMenuTemplates(widget.menu.menuTemplateId);
      
      if (templatesData != null) {
        menuTemplate = templatesData['menuTemplate'] as MenuTemplate;
        loadedTemplateItems = templatesData['variantTemplates'] as Map<String, VariantTemplate>;
        
        debugPrint('Template chargé avec succès: ${menuTemplate!.name}');
        debugPrint('Variant templates: ${loadedTemplateItems.keys.toList()}');
      } else {
        debugPrint('Template non trouvé ou invalide: ${widget.menu.menuTemplateId}');
        // Ne pas lever d'exception, juste marquer que le template n'est pas disponible
      }
    } catch (error) {
      debugPrint('Erreur lors du chargement du template: $error');
      // Ne pas lever d'exception, permettre de continuer sans template
    }
  }

  Future<void> _initializeCustomization() async {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    
    // Initialiser avec le prix de base
    totalPrice = widget.menu.basePrice;
    debugPrint('Prix de base: $totalPrice€');

    // Initialiser les variantes de l'article principal
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    final Map<String, String> defaultMainVariants = {};
    
    if (mainItem != null) {
      debugPrint('Article principal trouvé: ${mainItem.name}');
      
      // Gérer les variantes de l'item principal si includeItemVariants est true
      if (menuTemplate?.includeItemVariants == true && mainItem.variants != null) {
        for (final variant in mainItem.variants!) {
          final defaultOption = variant.options.firstWhere(
            (option) => option.isDefault,
            orElse: () => variant.options.first,
          );
          // Utiliser le même format d'ID que dans Next.js
          final optionId = '${variant.id}_${defaultOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
          defaultMainVariants[variant.id] = optionId;
          totalPrice += defaultOption.priceModifier;
        }
      }
    } else {
      debugPrint('Article principal non trouvé: ${widget.menu.mainItem.itemId}');
    }

    // Initialiser les options par défaut pour chaque template
    final Map<String, OptionSelection> defaultOptions = {};
    
    if (menuTemplate != null && menuTemplate!.includedVariantTemplates.isNotEmpty) {
      for (final template in menuTemplate!.includedVariantTemplates) {
        final variantTemplate = loadedTemplateItems[template.templateId];
        if (variantTemplate == null) {
          debugPrint('Template de variante non trouvé: ${template.templateId}');
          continue;
        }

        debugPrint('Traitement template: ${template.label}');

        // Trouver l'option par défaut
        final defaultItem = variantTemplate.referencedItems
            .where((item) => item.isDefault)
            .firstOrNull ?? variantTemplate.referencedItems.first;

        final item = menuProvider.getItemById(defaultItem.itemId);
        if (item != null) {
          debugPrint('Item par défaut trouvé: ${item.name}');
          debugPrint('Item ID: ${item.id}');
          debugPrint('Item variants: ${item.variants?.length ?? 0}');
          
          // Calculer le prix avec override
          final priceOverride = _getPriceOverride(template.templateId, item.id);
          totalPrice += priceOverride;
          debugPrint('Prix override: +$priceOverride€');

          // Initialiser les variantes de l'item sélectionné
          final Map<String, String> itemVariants = {};
          if (item.variants != null && item.variants!.isNotEmpty) {
            debugPrint('Traitement des variantes de l\'item: ${item.name}');
            for (final variant in item.variants!) {
              debugPrint('  Variante: ${variant.name} (${variant.options.length} options)');
              if (variant.options.isNotEmpty) {
                final defaultOption = variant.options.firstWhere(
                  (option) => option.isDefault,
                  orElse: () => variant.options.first,
                );
                // Utiliser le même format d'ID que dans Next.js
                final optionId = '${variant.id}_${defaultOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
                itemVariants[variant.id] = optionId;
                totalPrice += defaultOption.priceModifier;
                debugPrint('  Variante option ajoutée: ${variant.name} -> ${defaultOption.name} (+${defaultOption.priceModifier}€)');
              } else {
                debugPrint('  Aucune option pour la variante: ${variant.name}');
              }
            }
          } else {
            debugPrint('Aucune variante pour l\'item: ${item.name}');
          }

          defaultOptions[template.templateId] = OptionSelection(
            itemId: defaultItem.itemId,
            variants: itemVariants,
          );
        } else {
          debugPrint('Item non trouvé: ${defaultItem.itemId}');
        }
      }
    } else {
      debugPrint('Pas de template ou de templates de variantes disponibles');
    }

    customization = MenuCustomization(
      mainItem: MainItemSelection(
        itemId: widget.menu.mainItem.itemId,
        variants: defaultMainVariants,
      ),
      options: defaultOptions,
    );

    debugPrint('Prix total initialisé: $totalPrice€');
    debugPrint('Options par défaut: ${defaultOptions.keys.toList()}');
  }

  double _getPriceOverride(String templateId, String itemId) {
    final templateOverrides = widget.menu.templateOverrides;
    if (templateOverrides.containsKey(templateId)) {
      final override = templateOverrides[templateId];
      if (override is Map<String, dynamic>) {
        final priceOverrides = override['priceOverrides'] as Map<String, dynamic>?;
        if (priceOverrides != null) {
          final price = priceOverrides[itemId];
          if (price != null) {
            return (price is num) ? price.toDouble() : 0.0;
          }
        }
      }
    }
    return 0.0;
  }

  void _buildCustomizationSteps() {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    steps.clear();

    // Étape 1: Article principal (toujours présent)
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    if (mainItem != null) {
      steps.add(CustomizationStep(
        title: 'Article principal',
        content: _buildMainItemStep(mainItem),
      ));
    }

    // Étapes pour les templates de variantes
    if (menuTemplate != null && menuTemplate!.includedVariantTemplates.isNotEmpty) {
      final sortedTemplates = menuTemplate!.includedVariantTemplates
          .where((t) => loadedTemplateItems.containsKey(t.templateId))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final template in sortedTemplates) {
        final variantTemplate = loadedTemplateItems[template.templateId];
        if (variantTemplate != null) {
          steps.add(CustomizationStep(
            title: template.label ?? variantTemplate.name,
            content: _buildVariantTemplateStep(template, variantTemplate),
          ));
        }
      }
    }

    debugPrint('Étapes construites: ${steps.map((s) => s.title).toList()}');
    debugPrint('Nombre d\'étapes: ${steps.length}');
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
            child: SizedBox(
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
    // Si on est en cours de chargement, afficher un indicateur
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Si pas de template ou template vide, afficher l'interface simple
    if (widget.menu.menuTemplateId.isEmpty) {
      return _buildSimpleCustomization();
    }

    // Si le template n'est pas encore chargé mais qu'on a un templateId, 
    // afficher une interface de chargement avec possibilité de continuer
    if (menuTemplate == null) {
      return _buildTemplateLoadingState();
    }

    // Si on a un template mais pas d'étapes, essayer de les construire
    if (steps.isEmpty) {
      _buildCustomizationSteps();
      if (steps.isEmpty) {
        return _buildSimpleCustomization();
      }
    }

    return _buildStepByStepCustomization();
  }

  Widget _buildTemplateLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text('Chargement de la personnalisation...', style: TextStyle(fontSize: 16.sp)),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              // Réessayer de charger le template
              _startCustomization();
            },
            child: const Text('Réessayer'),
          ),
          SizedBox(height: 16.h),
          TextButton(
            onPressed: () {
              // Permettre d'ajouter au panier sans personnalisation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.menu.name} ajouté au panier (${widget.menu.basePrice.toStringAsFixed(2)}€)'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Ajouter sans personnalisation (${widget.menu.basePrice.toStringAsFixed(2)}€)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepByStepCustomization() {
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
            steps[currentStep].title,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          
          // Contenu de l'étape actuelle
          Flexible(
            child: SingleChildScrollView(
              child: steps[currentStep].content,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Boutons de navigation
          _buildNavigationButtons(steps.length),
        ],
      ),
    );
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
                child: SizedBox(
                  width: 80.w,
                  height: 80.h,
                  child: mainItem.images.isNotEmpty
                      ? Image.network(
                          mainItem.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.restaurant, size: 32.sp),
                          ),
                        )
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
                    if (mainItem.description.isNotEmpty)
                      Text(mainItem.description, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Variantes de l'article principal si includeItemVariants est true
          if (menuTemplate?.includeItemVariants == true && mainItem.variants != null && mainItem.variants!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Personnalisez votre ${mainItem.name}',
                style: TextStyle(fontSize: 14.sp, color: Colors.blue[700], fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(height: 16.h),
            ...mainItem.variants!.map((variant) => _buildVariantSection(variant, true)),
          ] else ...[
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
        ],
      ),
    );
  }

  Widget _buildVariantSection(MenuItemVariant variant, bool isMainItem) {
    final selectedOptionId = isMainItem 
        ? customization.mainItem.variants[variant.id]
        : null; // Pour les items d'options, cela sera géré différemment

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              variant.name,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            if (variant.isRequired) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Obligatoire',
                  style: TextStyle(fontSize: 10.sp, color: Colors.orange[700]),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12.h),
        Column(
          children: variant.options.map((option) {
            // Utiliser le même format d'ID que dans Next.js
            final optionId = '${variant.id}_${option.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
            final isSelected = selectedOptionId == optionId;
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleMainVariantSelect(variant.id, optionId),
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
                        Container(
                          width: 20.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
                              width: 2,
                            ),
                            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                          ),
                          child: isSelected ? Icon(Icons.check, size: 12.sp, color: Colors.white) : null,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            option.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (option.priceModifier > 0)
                          Text(
                            '+${option.priceModifier.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildVariantTemplateStep(IncludedVariantTemplate template, VariantTemplate variantTemplate) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final selectedOption = customization.options[template.templateId];
    
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: template.isRequired ? Colors.orange[100] : Colors.blue[100],
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              template.isRequired ? '* Choix obligatoire' : 'Choix optionnel',
              style: TextStyle(
                fontSize: 12.sp,
                color: template.isRequired ? Colors.orange[700] : Colors.blue[700],
              ),
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Sélection du produit
          Column(
            children: variantTemplate.referencedItems.map((referencedItem) {
              final item = menuProvider.getItemById(referencedItem.itemId);
              if (item == null) return const SizedBox.shrink();
              
              final isSelected = selectedOption?.itemId == item.id;
              final priceOverride = _getPriceOverride(template.templateId, item.id);
              
              debugPrint('Item: ${item.name}, Selected: $isSelected, ItemId: ${item.id}, SelectedItemId: ${selectedOption?.itemId}');
              debugPrint('Item variants: ${item.variants?.length ?? 0}');
              
              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                child: Column(
                  children: [
                    // Item selection tile
                    Material(
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
                                child: SizedBox(
                                  width: 50.w,
                                  height: 50.h,
                                  child: item.images.isNotEmpty
                                      ? Image.network(
                                          item.images.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey[200],
                                            child: Icon(Icons.fastfood, size: 24.sp),
                                          ),
                                        )
                                      : Container(color: Colors.grey[200], child: Icon(Icons.fastfood, size: 24.sp)),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      referencedItem.displayName,
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                                    ),
                                    if (item.description.isNotEmpty)
                                      Text(
                                        item.description,
                                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (priceOverride > 0)
                                    Text(
                                      '+${priceOverride.toStringAsFixed(2)}€',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
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
                    
                    // Variantes de l'item sélectionné
                    if (isSelected && item.variants != null && item.variants!.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personnalisez votre ${referencedItem.displayName}',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                            ),
                            SizedBox(height: 12.h),
                            ...item.variants!.map((variant) => _buildOptionVariantSection(template.templateId, variant)),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Log pour debug
                      Builder(
                        builder: (context) {
                          debugPrint('Variantes non affichées pour ${item.name}: isSelected=$isSelected, variants=${item.variants?.length ?? 0}');
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionVariantSection(String templateId, MenuItemVariant variant) {
    final selectedOptionId = customization.options[templateId]?.variants[variant.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              variant.name,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            if (variant.isRequired) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Obligatoire',
                  style: TextStyle(fontSize: 10.sp, color: Colors.orange[700]),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            value: selectedOptionId,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
            hint: const Text('Choisissez une option'),
            items: variant.options.map((option) {
              // Utiliser le même format d'ID que dans Next.js
              final optionId = '${variant.id}_${option.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
              return DropdownMenuItem<String>(
                value: optionId,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(option.name)),
                    if (option.priceModifier > 0)
                      Text(
                        '+${option.priceModifier.toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _handleOptionVariantSelect(templateId, variant.id, value);
              }
            },
          ),
        ),
        SizedBox(height: 12.h),
      ],
    );
  }

  void _handleMainVariantSelect(String variantId, String optionId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final mainItem = menuProvider.getItemById(customization.mainItem.itemId);
    if (mainItem?.variants == null || mainItem!.variants!.isEmpty) return;

    final variant = mainItem.variants!.firstWhere((v) => v.id == variantId);
    if (variant.options.isEmpty) return;
    
    final currentOptionId = customization.mainItem.variants[variantId];
    final newOption = variant.options.firstWhere((o) => 
        '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == optionId
    );
    
    // Calculer la différence de prix
    double priceDifference = 0;
    if (currentOptionId != null) {
      final currentOption = variant.options.firstWhere((o) => 
          '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == currentOptionId
      );
      priceDifference -= currentOption.priceModifier;
    }
    priceDifference += newOption.priceModifier;

    debugPrint('Sélection variante principale: $variantId -> ${newOption.name} (${priceDifference > 0 ? '+' : ''}$priceDifference€)');

    setState(() {
      totalPrice += priceDifference;
      customization = MenuCustomization(
        mainItem: MainItemSelection(
          itemId: customization.mainItem.itemId,
          variants: {
            ...customization.mainItem.variants,
            variantId: optionId,
          },
        ),
        options: customization.options,
      );
    });
  }

  void _handleOptionSelect(String templateId, String itemId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final newItem = menuProvider.getItemById(itemId);
    if (newItem == null) return;

    debugPrint('Sélection option: $templateId -> ${newItem.name}');

    // Calculer la différence de prix
    final currentSelection = customization.options[templateId];
    double priceDifference = 0;

    // Soustraire l'ancien prix (override + variantes)
    if (currentSelection != null) {
      final oldItem = menuProvider.getItemById(currentSelection.itemId);
      final oldPriceOverride = _getPriceOverride(templateId, currentSelection.itemId);
      priceDifference -= oldPriceOverride;
      
      // Soustraire les prix des anciennes variantes
      if (oldItem?.variants != null && oldItem!.variants!.isNotEmpty) {
        for (final entry in currentSelection.variants.entries) {
          final variant = oldItem.variants!.firstWhere((v) => v.id == entry.key);
          if (variant.options.isNotEmpty) {
            final option = variant.options.firstWhere((o) => o.id == entry.value);
            priceDifference -= option.priceModifier;
          }
        }
      }
    }

    // Ajouter le nouveau prix (override + variantes par défaut)
    final newPriceOverride = _getPriceOverride(templateId, itemId);
    priceDifference += newPriceOverride;

    // Initialiser les variantes par défaut et ajouter leurs prix
    final Map<String, String> defaultVariants = {};
    if (newItem.variants != null && newItem.variants!.isNotEmpty) {
      for (final variant in newItem.variants!) {
        if (variant.options.isNotEmpty) {
          final defaultOption = variant.options.firstWhere(
            (option) => option.isDefault,
            orElse: () => variant.options.first,
          );
          // Utiliser le même format d'ID que dans Next.js
          final optionId = '${variant.id}_${defaultOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
          defaultVariants[variant.id] = optionId;
          priceDifference += defaultOption.priceModifier;
        }
      }
    }

    debugPrint('Différence de prix: ${priceDifference > 0 ? '+' : ''}$priceDifference€');

    setState(() {
      totalPrice += priceDifference;
      final newOptions = Map<String, OptionSelection>.from(customization.options);
      newOptions[templateId] = OptionSelection(
        itemId: itemId,
        variants: defaultVariants,
      );
      
      customization = MenuCustomization(
        mainItem: customization.mainItem,
        options: newOptions,
      );
    });

    debugPrint('Nouveau prix total: $totalPrice€');
    debugPrint('Nouvelle sélection pour $templateId: $itemId');
    debugPrint('Options après mise à jour: ${customization.options.keys.toList()}');
  }

  void _handleOptionVariantSelect(String templateId, String variantId, String optionId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final currentSelection = customization.options[templateId];
    if (currentSelection == null) return;

    final item = menuProvider.getItemById(currentSelection.itemId);
    if (item?.variants == null || item!.variants!.isEmpty) return;

    final variant = item.variants!.firstWhere((v) => v.id == variantId);
    if (variant.options.isEmpty) return;
    
    // Extraire le nom de l'option depuis l'ID (format: variantId_optionName)
    final optionName = optionId.split('_').skip(1).join('_');
    final newOption = variant.options.firstWhere((o) => 
        '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == optionId
    );
    
    final currentOptionId = currentSelection.variants[variantId];
    double priceDifference = 0;
    
    if (currentOptionId != null) {
      // Extraire le nom de l'option actuelle
      final currentOptionName = currentOptionId.split('_').skip(1).join('_');
      final currentOption = variant.options.firstWhere((o) => 
          '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == currentOptionId
      );
      priceDifference -= currentOption.priceModifier;
    }
    priceDifference += newOption.priceModifier;

    debugPrint('Sélection variante option: $templateId/$variantId -> ${newOption.name} (${priceDifference > 0 ? '+' : ''}$priceDifference€)');

    setState(() {
      totalPrice += priceDifference;
      final newOptions = Map<String, OptionSelection>.from(customization.options);
      newOptions[templateId] = OptionSelection(
        itemId: currentSelection.itemId,
        variants: {
          ...currentSelection.variants,
          variantId: optionId,
        },
      );
      
      customization = MenuCustomization(
        mainItem: customization.mainItem,
        options: newOptions,
      );
    });
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
          Text(
            widget.menu.menuTemplateId.isEmpty 
                ? 'Ce menu n\'a pas de template de personnalisation'
                : 'Personnalisation non disponible',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (widget.menu.menuTemplateId.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              'Template ID: ${widget.menu.menuTemplateId}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
            ),
          ],
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
          if (widget.menu.menuTemplateId.isNotEmpty) ...[
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () {
                // Réessayer de charger le template
                setState(() {
                  isLoading = true;
                  menuTemplate = null;
                  loadedTemplateItems.clear();
                  steps.clear();
                });
                _startCustomization();
              },
              child: const Text('Réessayer la personnalisation'),
            ),
          ],
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
      // Logging de la personnalisation pour debug

      debugPrint('=== MENU AJOUTÉ AU PANIER ===');
      debugPrint('Menu: ${widget.menu.name}');
      debugPrint('Prix total: $totalPrice€');
      debugPrint('Article principal: ${customization.mainItem.itemId}');
      debugPrint('Options sélectionnées:');
      customization.options.forEach((templateId, selection) {
        final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
        final selectedItem = menuProvider.getItemById(selection.itemId);
        final priceOverride = _getPriceOverride(templateId, selection.itemId);
        debugPrint('  - $templateId: ${selectedItem?.name} (+$priceOverride€)');
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
