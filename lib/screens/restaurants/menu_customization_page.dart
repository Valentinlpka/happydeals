import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/menu_item.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/widgets/cart_snackbar.dart';
import 'package:provider/provider.dart';

class MenuCustomizationPage extends StatefulWidget {
  final RestaurantMenu menu;
  final String restaurantId;
  final CartItem? existingItem; // Pour le mode édition
  final String? restaurantName; // Nécessaire pour l'édition
  final String? restaurantLogo; // Nécessaire pour l'édition

  const MenuCustomizationPage({
    super.key,
    required this.menu,
    required this.restaurantId,
    this.existingItem,
    this.restaurantName,
    this.restaurantLogo,
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

class _MenuCustomizationPageState extends State<MenuCustomizationPage> {
  // États principaux
  MenuTemplate? menuTemplate;
  Map<String, VariantTemplate> loadedTemplateItems = {};
  late MenuCustomization customization;
  
  int currentStep = 0;
  double totalPrice = 0.0;
  bool isLoading = true;
  bool isAddingToCart = false;
  
  List<CustomizationStepData> steps = [];

  @override
  void initState() {
    super.initState();
    _initializeCustomization();
  }

  Future<void> _initializeCustomization() async {
    debugPrint('=== DÉMARRAGE PERSONNALISATION ===');
    debugPrint('Menu: ${widget.menu.name}');
    debugPrint('Template ID: ${widget.menu.menuTemplateId}');
    
    if (widget.menu.menuTemplateId.isEmpty) {
      debugPrint('Pas de template, affichage interface simple');
      _initializeSimpleCustomization();
      setState(() => isLoading = false);
      return;
    }

    await _loadMenuTemplate();
    await _setupCustomizationData();
    _buildSteps();
    
    setState(() => isLoading = false);
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
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      final templatesData = await menuProvider.loadMenuTemplates(widget.menu.menuTemplateId);
      
      if (templatesData != null) {
        menuTemplate = templatesData['menuTemplate'] as MenuTemplate;
        loadedTemplateItems = templatesData['variantTemplates'] as Map<String, VariantTemplate>;
        debugPrint('Template chargé avec succès: ${menuTemplate!.name}');
      }
    } catch (error) {
      debugPrint('Erreur lors du chargement du template: $error');
    }
  }

  Future<void> _setupCustomizationData() async {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    
    // Mode édition : pré-remplir avec les données existantes
    if (widget.existingItem != null) {
      await _setupEditMode();
      return;
    }
    
    // Mode création : initialiser avec les valeurs par défaut
    totalPrice = widget.menu.basePrice;

    // Initialiser les variantes de l'article principal
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    final Map<String, String> defaultMainVariants = {};
    
    if (mainItem != null && menuTemplate?.includeItemVariants == true && mainItem.variants != null) {
      for (final variant in mainItem.variants!) {
        final defaultOption = variant.options.firstWhere(
          (option) => option.isDefault,
          orElse: () => variant.options.first,
        );
        defaultMainVariants[variant.id] = defaultOption.id;
        totalPrice += defaultOption.priceModifier;
      }
    }

    // Initialiser les options par défaut pour chaque template
    final Map<String, OptionSelection> defaultOptions = {};
    
    if (menuTemplate != null && menuTemplate!.includedVariantTemplates.isNotEmpty) {
      for (final template in menuTemplate!.includedVariantTemplates) {
        final variantTemplate = loadedTemplateItems[template.templateId];
        if (variantTemplate == null) continue;

        // Gérer les exclusions
        final overrides = widget.menu.templateOverrides[template.templateId];
        final List<String> excludedItems = (overrides is Map<String, dynamic> && overrides['excludeItems'] is List)
            ? List<String>.from(overrides['excludeItems'] as List)
            : <String>[];

        final availableItems = variantTemplate.referencedItems
            .where((ref) => !excludedItems.contains(ref.itemId))
            .toList();

        if (availableItems.isEmpty) continue;

        final defaultItem = availableItems
            .where((item) => item.isDefault)
            .firstOrNull ?? availableItems.first;

        final item = menuProvider.getItemById(defaultItem.itemId);
        if (item != null) {
          final priceOverride = _getPriceOverride(template.templateId, item.id);
          totalPrice += priceOverride;

          final Map<String, String> itemVariants = {};
          if (item.variants != null && item.variants!.isNotEmpty) {
            for (final variant in item.variants!) {
              if (variant.options.isNotEmpty) {
                final defaultOption = variant.options.firstWhere(
                  (option) => option.isDefault,
                  orElse: () => variant.options.first,
                );
                final optionId = '${variant.id}_${defaultOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
                itemVariants[variant.id] = optionId;
                totalPrice += defaultOption.priceModifier;
              }
            }
          }

          defaultOptions[template.templateId] = OptionSelection(
            itemId: defaultItem.itemId,
            variants: itemVariants,
          );
        }
      }
    }

    customization = MenuCustomization(
      mainItem: MainItemSelection(
        itemId: widget.menu.mainItem.itemId,
        variants: defaultMainVariants,
      ),
      options: defaultOptions,
    );
  }

  Future<void> _setupEditMode() async {
    final existingItem = widget.existingItem!;
    totalPrice = existingItem.unitPrice; // Prix unitaire de l'article existant
    
    debugPrint('=== MODE ÉDITION ===');
    debugPrint('Article existant: ${existingItem.name}');
    debugPrint('Prix existant: ${existingItem.unitPrice}€');
    
    // Récupérer les variantes de l'article principal existant
    final Map<String, String> mainVariants = {};
    if (existingItem.mainItem?.variants != null) {
      for (final variant in existingItem.mainItem!.variants!) {
        // Retrouver l'ID de l'option à partir du nom
        final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
        final mainItem = menuProvider.getItemById(existingItem.mainItem!.itemId);
        
        if (mainItem?.variants != null) {
          for (final itemVariant in mainItem!.variants!) {
            if (itemVariant.id == variant.variantId) {
              final option = itemVariant.options.firstWhere(
                (opt) => opt.name == variant.selectedOption.name,
                orElse: () => itemVariant.options.first,
              );
              mainVariants[variant.variantId] = option.id;
              break;
            }
          }
        }
      }
    }
    
    // Récupérer les options existantes
    final Map<String, OptionSelection> existingOptions = {};
    if (existingItem.options != null) {
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      
      for (final option in existingItem.options!) {
        final Map<String, String> optionVariants = {};
        
        // Récupérer les variantes de l'option
        if (option.item.variants != null) {
          final optionItem = menuProvider.getItemById(option.item.itemId);
          
          if (optionItem?.variants != null) {
            for (final variant in option.item.variants!) {
              for (final itemVariant in optionItem!.variants!) {
                if (itemVariant.id == variant.variantId) {
                  final variantOption = itemVariant.options.firstWhere(
                    (opt) => opt.name == variant.selectedOption.name,
                    orElse: () => itemVariant.options.first,
                  );
                  optionVariants[variant.variantId] = '${variant.variantId}_${variantOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
                  break;
                }
              }
            }
          }
        }
        
        existingOptions[option.templateId] = OptionSelection(
          itemId: option.item.itemId,
          variants: optionVariants,
        );
      }
    }
    
    customization = MenuCustomization(
      mainItem: MainItemSelection(
        itemId: existingItem.mainItem?.itemId ?? widget.menu.mainItem.itemId,
        variants: mainVariants,
      ),
      options: existingOptions,
    );
    
    debugPrint('Personnalisation restaurée depuis l\'article existant');
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

  void _buildSteps() {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    steps.clear();

    // Étape 1: Article principal
    final mainItem = menuProvider.getItemById(widget.menu.mainItem.itemId);
    if (mainItem != null) {
      steps.add(CustomizationStepData(
        title: 'Article principal',
        subtitle: mainItem.name,
        isMainItem: true,
        mainItem: mainItem,
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
          steps.add(CustomizationStepData(
            title: template.label ?? variantTemplate.name,
            subtitle: template.isRequired ? 'Choix obligatoire' : 'Choix optionnel',
            isMainItem: false,
            template: template,
            variantTemplate: variantTemplate,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: isLoading ? _buildLoadingState() : _buildContent(),
      bottomNavigationBar: isLoading ? null : _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isEditMode = widget.existingItem != null;
    
    return AppBar(
      title: Text(
        isEditMode ? 'Modifier le menu' : 'Personnaliser',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(
          height: 1.h,
          color: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3.w,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          SizedBox(height: 16.h),
          Text(
            'Chargement de la personnalisation...',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.menu.menuTemplateId.isEmpty || menuTemplate == null || steps.isEmpty) {
      return _buildSimpleContent();
    }

    return Column(
      children: [
        _buildMenuHeader(),
        _buildStepIndicator(),
        Expanded(child: _buildCurrentStep()),
      ],
    );
  }

  Widget _buildMenuHeader() {
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
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: widget.menu.images.isNotEmpty
                  ? Image.network(
                      widget.menu.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant_menu,
                        size: 32.sp,
                        color: Colors.grey[400],
                      ),
                    )
                  : Icon(
                      Icons.restaurant_menu,
                      size: 32.sp,
                      color: Colors.grey[400],
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
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.menu.name,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (widget.menu.description.isNotEmpty)
                  Text(
                    widget.menu.description,
                    style: TextStyle(
                      fontSize: 14.sp,
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

  Widget _buildStepIndicator() {
    if (steps.length <= 1) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.w),
      child: Row(
        children: List.generate(steps.length, (index) {
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
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (currentStep >= steps.length) return const SizedBox.shrink();
    
    final step = steps[currentStep];
    
    return Container(
      color: Colors.white,
      margin: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildStepHeader(step),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: step.isMainItem 
                  ? _buildMainItemContent(step.mainItem!)
                  : _buildTemplateContent(step.template!, step.variantTemplate!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(CustomizationStepData step) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${currentStep + 1}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 14.sp,
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

  Widget _buildMainItemContent(MenuItem mainItem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildItemCard(
          item: mainItem,
          isSelected: true,
          onTap: null,
        ),
        
        SizedBox(height: 20.h),
        
        if (menuTemplate?.includeItemVariants == true && 
            mainItem.variants != null && 
            mainItem.variants!.isNotEmpty) ...[
          Text(
            'Personnalisez votre ${mainItem.name}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16.h),
          ...mainItem.variants!.map((variant) => _buildMainVariantSection(variant)),
        ] else ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Cet article est inclus dans votre menu',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemplateContent(IncludedVariantTemplate template, VariantTemplate variantTemplate) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final selectedOption = customization.options[template.templateId];
    
    // Filtrer les items exclus
    final overrides = widget.menu.templateOverrides[template.templateId];
    final List<String> excludedItems = (overrides is Map<String, dynamic> && overrides['excludeItems'] is List)
        ? List<String>.from(overrides['excludeItems'] as List)
        : <String>[];

    final availableItems = variantTemplate.referencedItems
        .where((ref) => !excludedItems.contains(ref.itemId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...availableItems.map((referencedItem) {
          final item = menuProvider.getItemById(referencedItem.itemId);
          if (item == null) return const SizedBox.shrink();
          
          final isSelected = selectedOption?.itemId == item.id;
          final priceOverride = _getPriceOverride(template.templateId, item.id);
          
          return Column(
            children: [
              _buildItemCard(
                item: item,
                displayName: referencedItem.displayName,
                isSelected: isSelected,
                priceOverride: priceOverride,
                onTap: () => _handleOptionSelect(template.templateId, item.id),
              ),
              
              if (isSelected && item.variants != null && item.variants!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personnalisez votre ${referencedItem.displayName}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ...item.variants!.map((variant) => 
                        _buildOptionVariantSection(template.templateId, variant)),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 16.h),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildItemCard({
    required MenuItem item,
    String? displayName,
    required bool isSelected,
    double? priceOverride,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ] : [],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                width: 60.w,
                height: 60.h,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: item.images.isNotEmpty
                    ? Image.network(
                        item.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.fastfood,
                          size: 24.sp,
                          color: Colors.grey[400],
                        ),
                      )
                    : Icon(
                        Icons.fastfood,
                        size: 24.sp,
                        color: Colors.grey[400],
                      ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? item.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (priceOverride != null && priceOverride > 0) ...[
                  Text(
                    '+${priceOverride.toStringAsFixed(2)}€',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
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
                  child: isSelected 
                      ? Icon(Icons.check, size: 16.sp, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainVariantSection(MenuItemVariant variant) {
    final selectedOptionId = customization.mainItem.variants[variant.id];

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                variant.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
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
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          ...variant.options.map((option) {
            final isSelected = selectedOptionId == option.id;
            
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              child: GestureDetector(
                onTap: () => _handleMainVariantSelect(variant.id, option.id),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
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
                        child: isSelected 
                            ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                            : null,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: Colors.black87,
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionVariantSection(String templateId, MenuItemVariant variant) {
    final selectedOptionId = customization.options[templateId]?.variants[variant.id];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                variant.name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
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
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedOptionId,
                hint: Text(
                  'Choisissez une option',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                isExpanded: true,
                items: variant.options.map((option) {
                  final optionId = '${variant.id}_${option.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
                  return DropdownMenuItem<String>(
                    value: optionId,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black87,
                          ),
                        ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleContent() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24.h),
            Text(
              widget.menu.menuTemplateId.isEmpty 
                  ? 'Ce menu n\'a pas de template de personnalisation'
                  : 'Personnalisation non disponible',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addToCartSimple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  widget.existingItem != null 
                      ? 'Modifier le menu (${widget.menu.basePrice.toStringAsFixed(2)}€)'
                      : 'Ajouter au panier (${widget.menu.basePrice.toStringAsFixed(2)}€)',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10.r,
              offset: Offset(0, -2.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${totalPrice.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                if (currentStep > 0) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goToPreviousStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Précédent',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isAddingToCart ? null : _handleNextOrAddToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: isAddingToCart
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isLastStep 
                                ? (widget.existingItem != null ? 'Modifier le menu' : 'Ajouter au panier')
                                : 'Suivant',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isLastStep => currentStep >= steps.length - 1;

  void _goToPreviousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  void _handleNextOrAddToCart() {
    if (_isLastStep) {
      _addToCart();
    } else {
      setState(() => currentStep++);
    }
  }

  void _handleMainVariantSelect(String variantId, String optionId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final mainItem = menuProvider.getItemById(customization.mainItem.itemId);
    if (mainItem?.variants == null || mainItem!.variants!.isEmpty) return;

    final variant = mainItem.variants!.firstWhere((v) => v.id == variantId);
    if (variant.options.isEmpty) return;
    
    final currentOptionId = customization.mainItem.variants[variantId];
    final newOption = variant.options.firstWhere((o) => o.id == optionId);
    
    // Calculer la différence de prix
    double priceDifference = 0;
    if (currentOptionId != null) {
      final currentOption = variant.options.firstWhere((o) => o.id == currentOptionId);
      priceDifference -= currentOption.priceModifier;
    }
    priceDifference += newOption.priceModifier;

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

    // Calculer la différence de prix
    final currentSelection = customization.options[templateId];
    double priceDifference = 0;

    // Soustraire l'ancien prix (override + variantes)
    if (currentSelection != null) {
      final oldPriceOverride = _getPriceOverride(templateId, currentSelection.itemId);
      priceDifference -= oldPriceOverride;
      
      // Soustraire les prix des anciennes variantes
      final oldItem = menuProvider.getItemById(currentSelection.itemId);
      if (oldItem?.variants != null && oldItem!.variants!.isNotEmpty) {
        for (final entry in currentSelection.variants.entries) {
          final variant = oldItem.variants!.firstWhere((v) => v.id == entry.key);
          if (variant.options.isNotEmpty) {
            final selectedOptionId = entry.value;
            final option = variant.options.firstWhere((o) =>
                '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == selectedOptionId);
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
          final optionId = '${variant.id}_${defaultOption.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
          defaultVariants[variant.id] = optionId;
          priceDifference += defaultOption.priceModifier;
        }
      }
    }

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
  }

  void _handleOptionVariantSelect(String templateId, String variantId, String optionId) {
    final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
    final currentSelection = customization.options[templateId];
    if (currentSelection == null) return;

    final item = menuProvider.getItemById(currentSelection.itemId);
    if (item?.variants == null || item!.variants!.isEmpty) return;

    final variant = item.variants!.firstWhere((v) => v.id == variantId);
    if (variant.options.isEmpty) return;
    
    final newOption = variant.options.firstWhere((o) =>
        '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == optionId);
    
    final currentOptionId = currentSelection.variants[variantId];
    double priceDifference = 0;
    
    if (currentOptionId != null) {
      final currentOption = variant.options.firstWhere((o) =>
          '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == currentOptionId);
      priceDifference -= currentOption.priceModifier;
    }
    priceDifference += newOption.priceModifier;

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

  Future<void> _addToCart() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CartSnackBar.showError(
        context: context,
        message: 'Vous devez être connecté pour ajouter des articles au panier',
      );
      return;
    }

    setState(() => isAddingToCart = true);

    try {
      final cartService = Provider.of<CartRestaurantService>(context, listen: false);
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      
      // Créer l'article principal avec ses variantes
      final mainItem = menuProvider.getItemById(customization.mainItem.itemId);
      if (mainItem == null) {
        throw Exception('Article principal non trouvé');
      }

      final List<CartItemVariant> mainItemVariants = [];
      if (customization.mainItem.variants.isNotEmpty) {
        for (final entry in customization.mainItem.variants.entries) {
          final variantId = entry.key;
          final optionId = entry.value;
          
          final variant = mainItem.variants?.firstWhere((v) => v.id == variantId);
          if (variant != null) {
            final option = variant.options.firstWhere((o) => o.id == optionId);
            mainItemVariants.add(CartItemVariant(
              variantId: variant.id,
              name: variant.name,
              selectedOption: CartSelectedOption(
                name: option.name,
                priceModifier: option.priceModifier,
              ),
            ));
          }
        }
      }

      // Créer les options du menu
      final List<CartOption> menuOptions = [];
      for (final entry in customization.options.entries) {
        final templateId = entry.key;
        final optionSelection = entry.value;
        
        final template = menuTemplate?.includedVariantTemplates
            .firstWhere((t) => t.templateId == templateId);
        
        final optionItem = menuProvider.getItemById(optionSelection.itemId);
        if (template != null && optionItem != null) {
          final List<CartItemVariant> optionVariants = [];
          
          for (final variantEntry in optionSelection.variants.entries) {
            final variantId = variantEntry.key;
            final selectedOptionId = variantEntry.value;
            
            final variant = optionItem.variants?.firstWhere((v) => v.id == variantId);
            if (variant != null) {
              final option = variant.options.firstWhere((o) => 
                  '${variant.id}_${o.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}' == selectedOptionId);
              
              optionVariants.add(CartItemVariant(
                variantId: variant.id,
                name: variant.name,
                selectedOption: CartSelectedOption(
                  name: option.name,
                  priceModifier: option.priceModifier,
                ),
              ));
            }
          }

          menuOptions.add(CartOption(
            templateId: templateId,
            templateName: template.label ?? 'Option',
            item: CartOptionItem(
              itemId: optionItem.id,
              name: optionItem.name,
              variants: optionVariants,
            ),
          ));
        }
      }

      // Créer l'item de menu pour le panier
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'menu',
        itemId: widget.menu.id,
        name: widget.menu.name,
        description: widget.menu.description,
        images: widget.menu.images,
        quantity: 1,
        unitPrice: totalPrice,
        totalPrice: totalPrice,
        addedAt: DateTime.now(),
        mainItem: CartMainItem(
          itemId: mainItem.id,
          name: mainItem.name,
          variants: mainItemVariants,
        ),
        options: menuOptions,
      );

      // Mode édition ou ajout
      if (widget.existingItem != null) {
        // Mode édition : mettre à jour l'article existant
        await cartService.updateMenuItem(
          restaurantId: widget.restaurantId,
          itemId: widget.existingItem!.id,
          updatedItem: cartItem.copyWith(
            quantity: widget.existingItem!.quantity, // Conserver la quantité existante
            totalPrice: totalPrice * widget.existingItem!.quantity,
          ),
        );
      } else {
        // Mode ajout : ajouter un nouvel article
        await cartService.addItemToCart(
          userId: currentUser.uid,
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName ?? '', 
          restaurantLogo: widget.restaurantLogo ?? '',
          item: cartItem,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        CartSnackBar.showSuccess(
          context: context,
          itemName: widget.existingItem != null 
              ? '${widget.menu.name} modifié'
              : '${widget.menu.name} personnalisé',
          price: totalPrice,
          onViewCart: () {
            // Navigation vers le panier sera gérée par le parent
          },
        );
      }
    } catch (e) {
      if (mounted) {
        CartSnackBar.showError(
          context: context,
          message: 'Erreur lors de l\'ajout au panier: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isAddingToCart = false);
      }
    }
  }

  Future<void> _addToCartSimple() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CartSnackBar.showError(
        context: context,
        message: 'Vous devez être connecté pour ajouter des articles au panier',
      );
      return;
    }

    try {
      final cartService = Provider.of<CartRestaurantService>(context, listen: false);
      
      // Créer un menu simple sans personnalisation
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'menu',
        itemId: widget.menu.id,
        name: widget.menu.name,
        description: widget.menu.description,
        images: widget.menu.images,
        quantity: 1,
        unitPrice: widget.menu.basePrice,
        totalPrice: widget.menu.basePrice,
        addedAt: DateTime.now(),
      );

      // Mode édition ou ajout
      if (widget.existingItem != null) {
        // Mode édition : mettre à jour l'article existant
        await cartService.updateMenuItem(
          restaurantId: widget.restaurantId,
          itemId: widget.existingItem!.id,
          updatedItem: cartItem.copyWith(
            quantity: widget.existingItem!.quantity, // Conserver la quantité existante
            totalPrice: widget.menu.basePrice * widget.existingItem!.quantity,
          ),
        );
      } else {
        // Mode ajout : ajouter un nouvel article
        await cartService.addItemToCart(
          userId: currentUser.uid,
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName ?? '',
          restaurantLogo: widget.restaurantLogo ?? '',
          item: cartItem,
        );
      }

      Navigator.pop(context);
      CartSnackBar.showSuccess(
        context: context,
        itemName: widget.existingItem != null 
            ? '${widget.menu.name} modifié'
            : widget.menu.name,
        price: widget.menu.basePrice,
        onViewCart: () {
          // Navigation vers le panier sera gérée par le parent
        },
      );
    } catch (e) {
      CartSnackBar.showError(
        context: context,
        message: 'Erreur lors de l\'ajout au panier: $e',
      );
    }
  }
}

class CustomizationStepData {
  final String title;
  final String subtitle;
  final bool isMainItem;
  final MenuItem? mainItem;
  final IncludedVariantTemplate? template;
  final VariantTemplate? variantTemplate;

  CustomizationStepData({
    required this.title,
    required this.subtitle,
    required this.isMainItem,
    this.mainItem,
    this.template,
    this.variantTemplate,
  });
}