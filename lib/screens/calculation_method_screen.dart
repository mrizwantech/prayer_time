import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/calculation_method_settings.dart';
import '../presentation/widgets/app_header.dart';
import '../core/prayer_time_service.dart';
import '../main.dart';

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
        body: SafeArea(
          child: Column(
            children: [
              // Match home header
              Consumer<PrayerTimeService>(
                builder: (context, prayerService, _) => AppHeader(
                  city: prayerService.city,
                  state: prayerService.state,
                  isLoading: prayerService.isLoading,
                  onRefresh: () => prayerService.refresh(),
                  showLocation: true,
                  showBackButton: false,
                  // Use default app title for consistency
                ),
              ),

              // Header explanation (theme-aligned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calculate, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isFirstTime
                                ? 'Choose your regional calculation method'
                                : 'Select your preferred calculation method',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Methods differ by the angles used for Fajr and Isha. Pick what your local community or masjid follows.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
                          ),
                        ],
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
                      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
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
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          method.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          method.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
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
                              } else {
                                if (!methodChanged) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Calculation method: ${_selectedOption!.displayName}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                Navigator.of(context).pop(methodChanged);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 6, // keep Settings highlighted
          onTap: (idx) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: idx)),
            );
          },
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Quran'),
            BottomNavigationBarItem(icon: Icon(Icons.radio_button_checked), label: 'Tasbeeh'),
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Qibla'),
            BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Rakat'),
            BottomNavigationBarItem(icon: Icon(Icons.brush), label: 'Posts'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
