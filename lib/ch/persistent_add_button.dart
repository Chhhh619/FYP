import 'package:flutter/material.dart';
import 'package:fyp/ch/record_transaction.dart';

class PersistentAddButton extends StatefulWidget {
  const PersistentAddButton({super.key});

  @override
  _PersistentAddButtonState createState() => _PersistentAddButtonState();
}

class _PersistentAddButtonState extends State<PersistentAddButton> {
  bool _isScrollingDown = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: _isScrollingDown ? 56.0 : 120.0,
      height: 56.0,
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordTransactionPage(),
            ),
          );
        },
        backgroundColor: Colors.teal,
        elevation: 4.0,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isScrollingDown
              ? Icon(Icons.add, color: Colors.white, size: 30, key: ValueKey('icon'))
              : FittedBox(
            key: ValueKey('textRow'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 24),
                SizedBox(width: 6),
                Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}