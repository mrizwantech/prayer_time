import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppHeader extends StatelessWidget {
  final String? city;
  final String? state;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String? title; // Optional title for sub-pages
  final bool showBackButton;
  final bool showLocation;

  const AppHeader({
    super.key,
    this.city,
    this.state,
    this.onRefresh,
    this.isLoading = false,
    this.title,
    this.showBackButton = false,
    this.showLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the location text only if we have data
    String? locationText;
    if (city != null && state != null) {
      locationText = '$city, $state';
    } else if (city != null) {
      locationText = city;
    } else if (state != null) {
      locationText = state;
    }
    // Don't show "Fetching location..." or "Unknown Location" - just show nothing

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1d2e),
            const Color(0xFF252836),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: showBackButton ? 8.0 : 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 12.0,
      ),
      child: Row(
        children: [
          // Back Button (for sub-pages)
          if (showBackButton)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          
          // Brand Logo and Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.mosque,
                  color: Color(0xFF00D9A5),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Azanify',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (showLocation && locationText != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: isLoading 
                              ? Colors.orange 
                              : const Color(0xFF00D9A5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locationText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          
          const Spacer(),
          
          // Refresh Button (only on home screen with location)
          if (onRefresh != null && showLocation)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00D9A5),
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: Color(0xFF00D9A5),
                        size: 20,
                      ),
                onPressed: isLoading ? null : onRefresh,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
        ],
      ),
    );
  }
}

