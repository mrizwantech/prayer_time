import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/calculation_method_settings.dart';

class CalculationMethodScreen extends StatefulWidget {
  final bool isFirstTime;
  
  const CalculationMethodScreen({
    super.key, 
    this.isFirstTime = false,
  });

  @override
  State<CalculationMethodScreen> createState() => _CalculationMethodScreenState();
}

class _CalculationMethodScreenState extends State<CalculationMethodScreen> {
  CalculationMethodOption? _selectedOption;

  @override
  void initState() {
    super.initState();
    // Pre-select the current method if editing (not first time)
    if (!widget.isFirstTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final settings = Provider.of<CalculationMethodSettings>(context, listen: false);
        setState(() {
          _selectedOption = settings.selectedMethod;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<CalculationMethodSettings>(context);
    
    return PopScope(
      // Prevent back navigation on first time until method is selected
      canPop: !widget.isFirstTime || _selectedOption != null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prayer Calculation Method'),
          automaticallyImplyLeading: !widget.isFirstTime,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Header explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.deepPurple.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isFirstTime 
                      ? 'Welcome! Please select your preferred calculation method'
                      : 'Select your preferred calculation method',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Different Islamic organizations use different angles to calculate Fajr and Isha times. '
                    'Choose the method commonly used in your region.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            // Method list
            Expanded(
              child: ListView.builder(
                itemCount: CalculationMethodOption.values.length,
                itemBuilder: (context, index) {
                  final method = CalculationMethodOption.values[index];
                  final isSelected = _selectedOption == method;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? Colors.deepPurple.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected 
                        ? BorderSide(color: Colors.deepPurple, width: 2)
                        : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Radio<CalculationMethodOption>(
                        value: method,
                        groupValue: _selectedOption,
                        onChanged: (value) {
                          setState(() {
                            _selectedOption = value;
                          });
                        },
                        activeColor: Colors.deepPurple,
                      ),
                      title: Text(
                        method.displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurple : null,
                        ),
                      ),
                      subtitle: Text(
                        method.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedOption = method;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            
            // Recommended section
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For North America, ISNA is commonly recommended.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedOption == null
                    ? null
                    : () async {
                        final currentMethod = settings.selectedMethod;
                        final methodChanged = currentMethod != _selectedOption;
                        
                        await settings.setMethod(_selectedOption!);
                        if (context.mounted) {
                          if (widget.isFirstTime) {
                            // The listener in FirstTimeSetupWrapper will handle navigation
                            // No need to pop - just let the state change trigger rebuild
                          } else {
                            // Show snackbar before popping
                            if (!methodChanged) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Calculation method: ${_selectedOption!.displayName}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            // Return true if method was changed to trigger full reload
                            Navigator.of(context).pop(methodChanged);
                          }
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isFirstTime ? 'Continue' : 'Save',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
