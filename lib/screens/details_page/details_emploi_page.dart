import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/bottom_sheet_emploi.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DetailsEmploiPage extends StatefulWidget {
  final JobOffer post;

  const DetailsEmploiPage({
    super.key,
    required this.post,
  });

  @override
  State<DetailsEmploiPage> createState() => _DetailsEmploiPageState();
}

class _DetailsEmploiPageState extends State<DetailsEmploiPage> {
  bool _isLoading = true;
  bool _hasApplied = false;
  final ScrollController _scrollController = ScrollController();
  bool _isStickyHeaderVisible = false;
  Company? _company;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
    _checkApplicationStatus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100) {
      if (!_isStickyHeaderVisible) {
        setState(() => _isStickyHeaderVisible = true);
      }
    } else {
      if (_isStickyHeaderVisible) {
        setState(() => _isStickyHeaderVisible = false);
      }
    }
  }

  Future<void> _loadCompanyData() async {
    try {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.post.companyId)
          .get();
      
      if (companyDoc.exists) {
        setState(() {
          _company = Company.fromDocument(companyDoc);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données de l\'entreprise: $e');
      setState(() => _isLoading = false);
    }
  }


  Future<void> _checkApplicationStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _hasApplied = false;
      });
      return;
    }

    try {
      final applicationSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('applicantId', isEqualTo: userId)
          .where('jobOfferId', isEqualTo: widget.post.id)
          .get();

      setState(() {
        _hasApplied = applicationSnapshot.docs.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la candidature: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showApplicationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ApplicationBottomSheet(
          jobOfferId: widget.post.id,
          companyId: widget.post.companyId,
          jobTitle: widget.post.title,
          onApplicationSubmitted: _createApplication,
        );
      },
    );
  }

  Future<void> _createApplication() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('applications').add({
        'applicantId': userId,
        'companyId': widget.post.companyId,
        'jobOfferId': widget.post.id,
        'jobTitle': widget.post.title,
        'status': 'Envoyé',
        'appliedAt': Timestamp.now(),
        'lastUpdate': Timestamp.now(),
        'messages': [],
        'hasUnreadMessages': false,
      });

      setState(() {
        _hasApplied = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi de la candidature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = context.watch<UserModel>().likedPosts.contains(widget.post.id);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar personnalisée
          _buildSliverAppBar(isLiked, theme),
          
          // Contenu principal
          SliverToBoxAdapter(
            child: Column(
              children: [
                // En-tête avec informations principales
                _buildHeader(isMobile),
                
                // Carte entreprise
                if (_company != null) _buildCompanyCard(),
                
                // Informations clés
                _buildKeyInformation(isMobile),
                
                // Description détaillée
                _buildDetailedDescription(isMobile),
                
                // Compétences et mots-clés
                if (widget.post.keywords.isNotEmpty)
                  _buildKeywords(isMobile),
                
                // Avantages
                if (widget.post.benefits.isNotEmpty)
                  _buildBenefits(isMobile),
                
                // Pourquoi nous rejoindre
                if (widget.post.whyJoin.isNotEmpty)
                  _buildWhyJoinUs(isMobile),
                
                // Espace pour le bouton flottant
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      // Bouton Postuler flottant
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar(bool isLiked, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
        backgroundColor: Colors.white,
      elevation: _isStickyHeaderVisible ? 2 : 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: AnimatedOpacity(
          opacity: _isStickyHeaderVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.post.title,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
        _buildActionButton(
          icon: isLiked ? Icons.bookmark : Icons.bookmark_border,
                color: isLiked ? Colors.blue[700] : Colors.grey[800],
            onPressed: () async {
              await Provider.of<UserModel>(context, listen: false)
                  .handleLike(widget.post);
            },
          ),
        _buildActionButton(
          icon: Icons.share_outlined,
          onPressed: () => _showShareOptions(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
        child: Icon(icon, size: 20, color: color ?? Colors.grey[800]),
            ),
      onPressed: onPressed,
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.title,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
          _buildHeaderTags(),
          const SizedBox(height: 16),
          _buildPostMetadata(),
        ],
      ),
    );
  }

  Widget _buildHeaderTags() {
    return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.post.contractType != null)
          _buildTag(
                              Icons.work_outline,
                              widget.post.contractType!,
                              Colors.blue,
                            ),
        if (widget.post.workingHours != null)
          _buildTag(
            Icons.access_time,
            widget.post.workingHours!,
                              Colors.orange,
                            ),
        _buildTag(
          Icons.location_on_outlined,
          widget.post.city,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildPostMetadata() {
    return Row(
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '${widget.post.views} vues',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          'Publié ${_formatDate(widget.post.timestamp)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'hier';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} jours';
    } else {
      return DateFormat('d MMMM yyyy', 'fr_FR').format(date);
    }
  }

  Widget _buildCompanyCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
                            }

                            return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
        color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
                              ),
                              child: CompanyInfoCard(
        name: widget.post.companyName,
        logo: widget.post.companyLogo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailsEntreprise(
                                      entrepriseId: widget.post.companyId,
                                    ),
                                  ),
                                ),
                                isCompact: true,
        showRating: true,
                              ),
                            );
  }

  Widget _buildKeyInformation(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
                      Text(
                        'Informations clés',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                        ),
              ),
            ],
                      ),
          const SizedBox(height: 20),
          _buildInfoGrid(),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                        Icons.work_outline,
                        'Type de contrat',
                        widget.post.contractType ?? 'Non spécifié',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(
                Icons.location_on_outlined,
                'Localisation',
                widget.post.city,
                Colors.green,
              ),
            ),
          ],
        ),
        if (widget.post.workingHours != null || (widget.post.salary != null && widget.post.salary!.isNotEmpty))
          const SizedBox(height: 12),
        if (widget.post.workingHours != null || (widget.post.salary != null && widget.post.salary!.isNotEmpty))
          Row(
            children: [
                      if (widget.post.workingHours != null)
                Expanded(
                  child: _buildInfoItem(
                          Icons.access_time_outlined,
                          'Temps de travail',
                          widget.post.workingHours!,
                    Colors.orange,
                  ),
                ),
              if (widget.post.workingHours != null && widget.post.salary != null && widget.post.salary!.isNotEmpty)
                const SizedBox(width: 12),
              if (widget.post.salary != null && widget.post.salary!.isNotEmpty)
                Expanded(
                  child: _buildInfoItem(
                        Icons.euro_outlined,
                        'Salaire',
                    widget.post.salary!,
                    Colors.purple,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[100]!),
                        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color[700],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                        ),
              ),
            ],
                ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
                ),
    );
  }

  Widget _buildDetailedDescription(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
                  color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildSectionTitle('Description du poste', isMobile),
          const SizedBox(height: 16),
                      Text(
            widget.post.description,
                        style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              height: 1.6,
              color: Colors.grey[800],
                        ),
                      ),
          if (widget.post.numberOfPositions > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Text(
                'Nombre de postes : ${widget.post.numberOfPositions}',
                              style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Localisation et contact
          _buildLocationAndContact(isMobile),
          const SizedBox(height: 24),

          // Dates importantes
          _buildImportantDates(isMobile),
          const SizedBox(height: 24),

          // Profil recherché
          _buildRequirements(isMobile),
          const SizedBox(height: 24),

          // Conditions de travail
          _buildWorkingConditions(isMobile),
          const SizedBox(height: 24),

          // Rémunération
          _buildCompensation(isMobile),
          const SizedBox(height: 24),

          // Avantages
          if (widget.post.benefits.isNotEmpty)
            _buildBenefitsList(isMobile),
        ],
      ),
    );
  }

  Widget _buildLocationAndContact(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Localisation et contact', isMobile),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Adresse
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adresse',
                          style: TextStyle(
                            color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        const SizedBox(height: 4),
                        Text(
                          widget.post.address,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
              
              if (widget.post.additionalInfo.isNotEmpty) ...[
                const SizedBox(height: 16),
                // Informations de contact
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations de contact',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                  ),
                          const SizedBox(height: 4),
                          Text(
                            widget.post.additionalInfo,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
              ],
            ),
          ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportantDates(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Dates importantes', isMobile),
        const SizedBox(height: 12),
        Row(
                    children: [
                      Expanded(
              child: _buildDateInfo(
                'Date de début',
                widget.post.startDate,
                Icons.calendar_today,
                Colors.green,
                        ),
                      ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateInfo(
                'Date limite de candidature',
                widget.post.applicationDeadline,
                Icons.event_busy,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon, MaterialColor color) {
    final formattedDate = DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.parse(date));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color[50],
                              borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[100]!),
                          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 16, color: color[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formattedDate,
                            style: TextStyle(
                    color: Colors.grey[800],
                              fontSize: 14,
                    fontWeight: FontWeight.w600,
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirements(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Profil recherché', isMobile),
        const SizedBox(height: 12),
        if (widget.post.experienceRequired.isNotEmpty)
          _buildRequirementItem(
            'Expérience requise',
            widget.post.experienceRequired,
            Icons.work_history,
            Colors.purple,
          ),
        if (widget.post.educationRequired.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildRequirementItem(
            'Formation requise',
            widget.post.educationRequired,
            Icons.school,
            Colors.orange,
          ),
        ],
        if (widget.post.requiredLicenses.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildRequirementItem(
            'Permis/Licences requis',
            widget.post.requiredLicenses.join(', '),
            Icons.badge,
            Colors.blue,
          ),
        ],
      ],
    );
  }

  Widget _buildRequirementItem(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
        color: color[50],
                            borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[100]!),
                          ),
                          child: Row(
                            children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                              Text(
                  label,
                                style: TextStyle(
                    color: color[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[800],
                                  fontSize: 14,
                    fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
    );
  }

  Widget _buildWorkingConditions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Conditions de travail', isMobile),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildConditionTag(
              'Rythme',
              widget.post.workingRhythm,
              Icons.schedule,
              Colors.blue,
            ),
            _buildConditionTag(
              'Type de travail',
              widget.post.workplaceType,
              Icons.business,
              Colors.purple,
            ),
            if (widget.post.weekendWork)
              _buildConditionTag(
                'Travail le weekend',
                widget.post.weekendWorkDetails,
                Icons.weekend,
                Colors.orange,
            ),
        ],
      ),
      ],
    );
  }

  Widget _buildConditionTag(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color[700]),
          const SizedBox(width: 8),
          Text(
            '$label : $value',
            style: TextStyle(
              color: color[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensation(bool isMobile) {
    if (widget.post.salaryMin.isEmpty && widget.post.salaryMax.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _buildSectionTitle('Rémunération', isMobile),
        const SizedBox(height: 12),
          Container(
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(Icons.euro, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 8),
                Text(
                    'Salaire annuel',
                  style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                  ),
                  ),
                ],
                ),
              const SizedBox(height: 8),
                Text(
                '${widget.post.salaryMin} € - ${widget.post.salaryMax} €',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.post.variableCompensation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.post.variableCompensation,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsList(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Avantages', isMobile),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.post.benefits.map((benefit) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.indigo[100]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.indigo[700]),
                  const SizedBox(width: 8),
                  Text(
                    benefit,
                    style: TextStyle(
                      color: Colors.indigo[700],
                      fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            );
          }).toList(),
          ),
        ],
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 18 : 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildKeywords(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
      color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildSectionTitle('Compétences recherchées', isMobile),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.post.keywords.map((keyword) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Text(
                  keyword,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildSectionTitle('Avantages', isMobile),
          const SizedBox(height: 16),
          Text(
            widget.post.benefits.join(' • '),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyJoinUs(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildSectionTitle('Pourquoi nous rejoindre', isMobile),
          const SizedBox(height: 16),
          Text(
            widget.post.whyJoin,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _hasApplied
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Candidature envoyée',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: _showApplicationBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Postuler maintenant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTag(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    final users = Provider.of<UserModel>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager sur mon profil'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return ShareConfirmationDialog(
                      post: Post(
                        id: widget.post.id,
                        companyId: widget.post.companyId,
                        timestamp: DateTime.now(),
                        type: 'job',
                        companyName: widget.post.companyName,
                        companyLogo: widget.post.companyLogo,
                      ),
                      onConfirm: (String comment) async {
                        try {
                          Navigator.of(dialogContext).pop();

                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.id)
                              .update({
                            'sharesCount': FieldValue.increment(1),
                          });

                          await users.sharePost(
                            widget.post.id,
                            users.userId,
                            comment: comment,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Publication partagée avec succès!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors du partage: $e'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('Envoyer en message'),
              onTap: () {
                Navigator.pop(context);
                _showConversationsList(context, users);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Envoyer à...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where(FieldPath.documentId,
                            whereIn: users.followedUsers)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Une erreur est survenue'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs;

                      if (users.isEmpty) {
                        return const Center(
                          child: Text('Vous ne suivez aucun utilisateur'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData =
                              users[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(userData['image_profile'] ?? ''),
                            ),
                            title: Text(
                                '${userData['firstName']} ${userData['lastName']}'),
                            onTap: () async {
                              try {
                                final post = Post(
                                  companyName: widget.post.companyName,
                                  companyLogo: widget.post.companyLogo,
                                  id: widget.post.id,
                                  companyId: widget.post.companyId,
                                  timestamp: DateTime.now(),
                                  type: 'job',
                                );

                                await Provider.of<ConversationService>(context,
                                        listen: false)
                                    .sharePostInConversation(
                                  senderId: Provider.of<UserModel>(context,
                                          listen: false)
                                      .userId,
                                  receiverId: users[index].id,
                                  post: post,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Message envoyé avec succès!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Erreur lors de l\'envoi: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
