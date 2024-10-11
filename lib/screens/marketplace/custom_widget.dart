import 'package:flutter/material.dart';

Widget buildDropdown(
  String label,
  String? value,
  List<String> items,
  void Function(String?) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            focusColor: Colors.transparent,
            isExpanded: true,
            value: value,
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            icon: const Icon(Icons.arrow_drop_down),
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            dropdownColor: Colors.white,
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((String item) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    ],
  );
}

Widget buildTextField(String label, TextEditingController controller,
    {int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    ],
  );
}
