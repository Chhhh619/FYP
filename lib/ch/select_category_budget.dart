import 'package:flutter/material.dart';

class SelectCategoryBudgetPage extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final DateTime? selectedDate;

  const SelectCategoryBudgetPage({
    super.key,
    required this.categories,
    this.selectedDate,
  });

  @override
  _SelectCategoryBudgetPageState createState() => _SelectCategoryBudgetPageState();
}

class _SelectCategoryBudgetPageState extends State<SelectCategoryBudgetPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Category')),
      body: ListView.builder(
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          return ListTile(
            leading: CircleAvatar(child: Text(category['icon'])),
            title: Text(category['name']),
            onTap: () {
              Navigator.pop(context, {
                'ref': category['ref'],
                'name': category['name'],
              });
            },
          );
        },
      ),
    );
  }
}