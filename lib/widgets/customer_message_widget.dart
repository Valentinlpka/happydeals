import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomerMessageWidget extends StatefulWidget {
  final String? initialMessage;
  final Function(String) onMessageChanged;

  const CustomerMessageWidget({
    super.key,
    this.initialMessage,
    required this.onMessageChanged,
  });

  @override
  State<CustomerMessageWidget> createState() => _CustomerMessageWidgetState();
}

class _CustomerMessageWidgetState extends State<CustomerMessageWidget> {
  late TextEditingController _messageController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialMessage ?? '');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Icon(
                Icons.message_outlined,
                size: 20.sp,
                color: Colors.grey[600],
              ),
              SizedBox(width: 8.w),
              Text(
                'Message pour le restaurant',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                  size: 20.sp,
                ),
              ),
            ],
          ),
          
          if (_isExpanded) ...[
            SizedBox(height: 16.h),
            
            // Suggestions de messages
            Text(
              'Suggestions :',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            
            SizedBox(height: 8.h),
            
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildSuggestionChip('Bien cuit'),
                _buildSuggestionChip('Allergies : gluten'),
                _buildSuggestionChip('Merci !'),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            // Champ de saisie
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 200,

              decoration: InputDecoration(
                
                hintText: 'Ajoutez un message pour le restaurant (optionnel)',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                border: OutlineInputBorder(

                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),                ),
                contentPadding: EdgeInsets.all(12.w),
                counterStyle: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                ),
              ),
              onChanged: (value) {
                widget.onMessageChanged(value);
              },
            ),
          ] else if (_messageController.text.isNotEmpty) ...[
            SizedBox(height: 12.h),
            
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.message,
                    size: 16.sp,
                    color: Colors.blue[600],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _messageController.text,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.blue[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        final currentText = _messageController.text;
        final newText = currentText.isEmpty ? text : '$currentText, $text';
        _messageController.text = newText;
        widget.onMessageChanged(newText);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
} 