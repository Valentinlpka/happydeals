import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/review.dart';

class ReviewsList extends StatefulWidget {
  final String companyId;
  final int limit;

  const ReviewsList({
    super.key,
    required this.companyId,
    this.limit = 10,
  });

  @override
  State<ReviewsList> createState() => _ReviewsListState();
}

class _ReviewsListState extends State<ReviewsList> {
  final ScrollController _scrollController = ScrollController();
  List<Review> _reviews = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreReviews();
      }
    }
  }

  Future<void> _loadReviews() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('🌟 ReviewsList - Chargement des avis pour companyId: ${widget.companyId}');
      
      final query = FirebaseFirestore.instance
          .collection('reviews')
          .where('companyId', isEqualTo: widget.companyId)
          .orderBy('createdAt', descending: true)
          .limit(widget.limit);

      final querySnapshot = await query.get();
      
      debugPrint('🌟 ReviewsList - ${querySnapshot.docs.length} avis trouvés');

      final reviews = querySnapshot.docs.map((doc) {
        try {
          return Review.fromFirestore(doc);
        } catch (e) {
          debugPrint('🌟 ReviewsList - Erreur parsing avis ${doc.id}: $e');
          return null;
        }
      }).whereType<Review>().toList();

      setState(() {
        _reviews = reviews;
        _hasMore = querySnapshot.docs.length == widget.limit;
        _lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🌟 ReviewsList - Erreur chargement avis: $e');
      setState(() {
        _error = 'Erreur lors du chargement des avis: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('reviews')
          .where('companyId', isEqualTo: widget.companyId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(widget.limit);

      final querySnapshot = await query.get();

      final newReviews = querySnapshot.docs.map((doc) {
        try {
          return Review.fromFirestore(doc);
        } catch (e) {
          debugPrint('🌟 ReviewsList - Erreur parsing avis ${doc.id}: $e');
          return null;
        }
      }).whereType<Review>().toList();

      setState(() {
        _reviews.addAll(newReviews);
        _hasMore = querySnapshot.docs.length == widget.limit;
        _lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🌟 ReviewsList - Erreur chargement plus d\'avis: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadReviews,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'Aucun avis',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Soyez le premier à laisser un avis sur ce restaurant',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _reviews.clear();
          _lastDocument = null;
          _hasMore = true;
        });
        await _loadReviews();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16.w),
        itemCount: _reviews.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _reviews.length) {
            // Indicateur de chargement en bas
            return Container(
              padding: EdgeInsets.all(16.w),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final review = _reviews[index];
          return _buildReviewCard(review);
        },
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec utilisateur et note
          Row(
            children: [
              // Photo de profil
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: ClipOval(
                  child: review.userPhotoUrl.isNotEmpty
                      ? Image.network(
                          review.userPhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultAvatar(review.userName),
                        )
                      : _buildDefaultAvatar(review.userName),
                ),
              ),
              
              SizedBox(width: 12.w),
              
              // Nom et date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      review.formattedDate,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Note avec étoiles
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < review.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16.sp,
                      );
                    }),
                  ),
                  Text(
                    '${review.rating}/5',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Commentaire
          if (review.comment.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String userName) {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
