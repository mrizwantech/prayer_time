import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../salah_pose_setup/salah_pose_setup_screen.dart';

enum _RakatTrackingMode { manual, automatic }

class RakahCounterScreen extends StatefulWidget {
  const RakahCounterScreen({super.key});

  @override
  State<RakahCounterScreen> createState() => _RakahCounterScreenState();
}

class _RakahCounterScreenState extends State<RakahCounterScreen>
    with SingleTickerProviderStateMixin {
  int _targetRakats = 2;
  int _currentRakah = 0;
  bool _isTracking = false;
  bool _isCompleted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Prayer presets
  final List<Map<String, dynamic>> _prayerPresets = [
    {'name': 'Fajr', 'rakats': 2, 'icon': Icons.wb_twilight},
    {'name': 'Dhuhr', 'rakats': 4, 'icon': Icons.wb_sunny},
    {'name': 'Asr', 'rakats': 4, 'icon': Icons.sunny_snowing},
    {'name': 'Maghrib', 'rakats': 3, 'icon': Icons.nights_stay},
    {'name': 'Isha', 'rakats': 4, 'icon': Icons.bedtime},
    {'name': 'Witr', 'rakats': 3, 'icon': Icons.star},
    {'name': 'Taraweeh', 'rakats': 20, 'icon': Icons.mosque},
    {'name': 'Sunnah / Nafl', 'rakats': 0, 'icon': Icons.volunteer_activism},
    {'name': 'Custom', 'rakats': 0, 'icon': Icons.edit},
  ];

  String? _selectedPrayerName;
  _RakatTrackingMode _trackingMode = _RakatTrackingMode.manual;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectPrayer(String name, int rakats) {
    if (name == 'Custom' || name == 'Sunnah / Nafl') {
      _showCustomRakatDialog(prayerLabel: name);
    } else if (_trackingMode == _RakatTrackingMode.automatic) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SalahPoseSetupScreen(initialPrayer: name, initialRakats: rakats),
        ),
      );
    } else {
      setState(() {
        _selectedPrayerName = name;
        _targetRakats = rakats;
        _currentRakah = 0;
        _isTracking = false;
        _isCompleted = false;
      });
    }
  }

  void _showCustomRakatDialog({String prayerLabel = 'Custom'}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          prayerLabel == 'Custom' ? 'Custom Rakats' : '$prayerLabel Rakats',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Number of Rakats',
            hintText: 'Enter number (1-100)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              final maxRakats = _trackingMode == _RakatTrackingMode.automatic
                  ? 20
                  : 100;
              if (value != null && value >= 1 && value <= maxRakats) {
                Navigator.pop(context);
                if (_trackingMode == _RakatTrackingMode.automatic) {
                  Navigator.of(this.context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SalahPoseSetupScreen(
                        initialPrayer: prayerLabel,
                        initialRakats: value,
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedPrayerName = prayerLabel == 'Custom'
                      ? 'Custom ($value)'
                      : '$prayerLabel ($value)';
                  _targetRakats = value;
                  _currentRakah = 0;
                  _isTracking = false;
                  _isCompleted = false;
                });
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _currentRakah = 0;
      _isCompleted = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _manualIncrement() {
    if (_currentRakah < _targetRakats) {
      _pulseController.forward().then((_) => _pulseController.reverse());
      HapticFeedback.lightImpact();

      setState(() {
        _currentRakah++;
        if (_currentRakah >= _targetRakats) {
          _isCompleted = true;
          _isTracking = false;
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _decrementRakah() {
    if (_currentRakah > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentRakah--;
        _isCompleted = false;
        if (!_isTracking && _currentRakah < _targetRakats) {
          _isTracking = true;
        }
      });
    }
  }

  void _resetCounter() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentRakah = 0;
      _isTracking = false;
      _isCompleted = false;
    });
  }

  void _backToSelection() {
    setState(() {
      _selectedPrayerName = null;
      _currentRakah = 0;
      _isTracking = false;
      _isCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subtitleColor =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
        (isDark ? Colors.white70 : Colors.black54);
    final primaryColor = theme.colorScheme.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Rakat Counter'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedPrayerName != null && !_isCompleted) {
              _backToSelection();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: _selectedPrayerName == null
            ? _buildPrayerSelection(
                cardColor,
                textColor,
                subtitleColor,
                primaryColor,
                bottomPadding,
              )
            : _buildCounterView(
                cardColor,
                textColor,
                subtitleColor,
                primaryColor,
                isDark,
                bottomPadding,
              ),
      ),
    );
  }

  Widget _buildPrayerSelection(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color primaryColor,
    double bottomPadding,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Select Prayer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a prayer or set custom rakats to track',
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Tracking mode',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_RakatTrackingMode>(
              segments: const [
                ButtonSegment(
                  value: _RakatTrackingMode.manual,
                  icon: Icon(Icons.touch_app_outlined),
                  label: Text('Manual'),
                ),
                ButtonSegment(
                  value: _RakatTrackingMode.automatic,
                  icon: Icon(Icons.camera_alt_outlined),
                  label: Text('Auto detect'),
                ),
              ],
              selected: {_trackingMode},
              onSelectionChanged: (selection) {
                setState(() => _trackingMode = selection.first);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Prayer Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: _prayerPresets.length,
            itemBuilder: (context, index) {
              final preset = _prayerPresets[index];
              final isCustom = preset['rakats'] == 0;

              return Material(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: InkWell(
                  onTap: () => _selectPrayer(preset['name'], preset['rakats']),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(preset['icon'], size: 28, color: primaryColor),
                        const SizedBox(height: 6),
                        Text(
                          preset['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (!isCustom) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${preset['rakats']} Rakats',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _trackingMode == _RakatTrackingMode.manual
                          ? Icons.touch_app
                          : Icons.center_focus_strong,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _trackingMode == _RakatTrackingMode.manual
                            ? 'Manual counting'
                            : 'Camera pose tracking',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _trackingMode == _RakatTrackingMode.manual
                      ? 'Choose a prayer to count rakats with the on-screen controls.'
                      : 'Choose a prayer or enter a Sunnah/Nafl rakat count to start camera-based movement tracking.',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can still undo and reset if you make a mistake.',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterView(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color primaryColor,
    bool isDark,
    double bottomPadding,
  ) {
    final progress = _targetRakats > 0 ? _currentRakah / _targetRakats : 0.0;
    final progressColor = _isCompleted ? Colors.green : primaryColor;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: Column(
        children: [
          // Prayer Info Card
          Card(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mosque, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _selectedPrayerName!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(progressColor),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_currentRakah of $_targetRakats Rakats',
                    style: TextStyle(
                      fontSize: 16,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Main Counter Button
          if (!_isTracking && !_isCompleted) ...[
            // Start Button
            SizedBox(
              width: 200,
              height: 200,
              child: ElevatedButton(
                onPressed: _startTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 8,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 40),
                    SizedBox(height: 4),
                    Text(
                      'START',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Manual counting', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ] else if (_isCompleted) ...[
            // Completed View
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 56, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ما شاء الله',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Counter Display (tracking mode)
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _manualIncrement, // Allow manual tap as backup
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_currentRakah',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'RAKATS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tap to add',
                          style: TextStyle(fontSize: 9, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Control Buttons
          if (_isTracking || _isCompleted) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Manual Add Button
                if (_isTracking && _currentRakah < _targetRakats)
                  ElevatedButton.icon(
                    onPressed: _manualIncrement,
                    icon: const Icon(Icons.add),
                    label: const Text('Manual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                if (_isTracking && _currentRakah < _targetRakats)
                  const SizedBox(width: 8),
                // Minus Button
                if (_currentRakah > 0 && !_isCompleted)
                  ElevatedButton.icon(
                    onPressed: _decrementRakah,
                    icon: const Icon(Icons.remove),
                    label: const Text('Undo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Reset Button
                ElevatedButton.icon(
                  onPressed: _resetCounter,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Back to Selection
          TextButton.icon(
            onPressed: _backToSelection,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Choose Different Prayer'),
            style: TextButton.styleFrom(foregroundColor: subtitleColor),
          ),

          const SizedBox(height: 32),

          // Remaining Rakats Info
          if (_isTracking) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    'Completed',
                    '$_currentRakah',
                    Colors.green,
                    textColor,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: subtitleColor.withOpacity(0.3),
                  ),
                  _buildInfoItem(
                    'Remaining',
                    '${_targetRakats - _currentRakah}',
                    Colors.orange,
                    textColor,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: subtitleColor.withOpacity(0.3),
                  ),
                  _buildInfoItem(
                    'Total',
                    '$_targetRakats',
                    primaryColor,
                    textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instruction Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap the counter or Manual button to add a rakat. Use Undo or Reset to correct the count.',
                      style: TextStyle(color: textColor, fontSize: 12),
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

  Widget _buildInfoItem(
    String label,
    String value,
    Color color,
    Color textColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
        ),
      ],
    );
  }
}
