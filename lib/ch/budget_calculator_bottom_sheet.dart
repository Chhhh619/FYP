import 'package:flutter/material.dart';

Future<void> showBudgetCalculator({
  required BuildContext context,
  required String categoryName,
  required void Function(double amount) onSave,
}) async {
  String calculatorInput = '0';
  double calculatorResult = 0;
  bool saveAttempted = false;

  double evaluateExpression(String expression) {
    expression = expression.replaceAll(',', '');
    final parts = expression.split(' ');
    double result = double.parse(parts[0]);
    for (int i = 1; i < parts.length; i += 2) {
      final op = parts[i];
      final num = double.parse(parts[i + 1]);
      if (op == '+') result += num;
      else if (op == '-') result -= num;
      else if (op == '*') result *= num;
      else if (op == '/') result /= num;
    }
    return result;
  }

  void calculate(String input, StateSetter setState) {
    setState(() {
      if (input == '.') {
        final parts = calculatorInput.split(RegExp(r'[\+\-\*/]'));
        final lastNumber = parts.isNotEmpty ? parts.last.trim() : '';
        if (!lastNumber.contains('.')) {
          calculatorInput += '.';
        }
      } else if (input == 'delete') {
        if (calculatorInput.length > 1) {
          calculatorInput = calculatorInput.substring(0, calculatorInput.length - 1);
        } else {
          calculatorInput = '0';
        }
      } else if (input == '=') {
        try {
          calculatorResult = evaluateExpression(calculatorInput);
          calculatorInput = calculatorResult.toString();
        } catch (_) {
          calculatorInput = 'Error';
          calculatorResult = double.nan;
        }
      } else if (['+', '-', '*', '/'].contains(input)) {
        calculatorInput += ' $input ';
      } else {
        calculatorInput = calculatorInput == '0' ? input : calculatorInput + input;
      }
    });
  }

  Widget buildCalcButton(String text, void Function(String) onPressed, {IconData? icon}) {
    return ElevatedButton(
      onPressed: () => onPressed(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(40, 42, 41, 1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(12),
      ),
      child: icon != null ? Icon(icon, size: 20) : Text(text, style: const TextStyle(fontSize: 20)),
    );
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (context, setState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(33, 35, 34, 1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Budget for $categoryName',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  calculatorInput,
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                if (saveAttempted)
                  const Text(
                    'Please enter a valid amount.',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  padding: const EdgeInsets.all(8),
                  children: [
                    buildCalcButton('7', (input) => calculate(input, setState)),
                    buildCalcButton('8', (input) => calculate(input, setState)),
                    buildCalcButton('9', (input) => calculate(input, setState)),
                    buildCalcButton('/', (input) => calculate(input, setState)),
                    buildCalcButton('4', (input) => calculate(input, setState)),
                    buildCalcButton('5', (input) => calculate(input, setState)),
                    buildCalcButton('6', (input) => calculate(input, setState)),
                    buildCalcButton('*', (input) => calculate(input, setState)),
                    buildCalcButton('1', (input) => calculate(input, setState)),
                    buildCalcButton('2', (input) => calculate(input, setState)),
                    buildCalcButton('3', (input) => calculate(input, setState)),
                    buildCalcButton('-', (input) => calculate(input, setState)),
                    buildCalcButton('0', (input) => calculate(input, setState)),
                    buildCalcButton('.', (input) => calculate(input, setState)),
                    buildCalcButton('=', (input) => calculate(input, setState)),
                    buildCalcButton('+', (input) => calculate(input, setState)),
                    buildCalcButton('delete', (input) => calculate(input, setState), icon: Icons.backspace),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    try {
                      calculatorResult = evaluateExpression(calculatorInput);
                    } catch (_) {
                      calculatorResult = double.nan;
                    }

                    if (calculatorInput == '0' || calculatorResult.isNaN || calculatorResult == 0) {
                      setState(() {
                        saveAttempted = true;
                      });
                      return;
                    }

                    Navigator.of(context).pop(); // close sheet
                    onSave(calculatorResult); // call back
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Budget',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }),
      );
    },
  );
}
