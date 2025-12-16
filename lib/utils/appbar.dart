import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool showDashboardLayout;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final bool showHelpIcons;
  final String? helpPhoneNumber;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton = true,
    this.showDashboardLayout = false,
    this.onNotificationTap,
    this.onProfileTap,
    this.actions,
    this.showHelpIcons = false,
    this.helpPhoneNumber,
  });

  // Launch phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Launch WhatsApp
  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters except +
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    if (showDashboardLayout) {
      return _buildDashboardAppBar(context);
    }

    return AppBar(
      backgroundColor: AppColors.info,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textWhite,
                size: 26,
              ),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: actions,
    );
  }

  PreferredSizeWidget _buildDashboardAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.info,
      centerTitle: true,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      titleSpacing: 0,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Icon(
          Icons.local_shipping_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
      title: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.9),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              Shadow(
                color: AppColors.info.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Call icon for help
        if (showHelpIcons && helpPhoneNumber != null)
          IconButton(
            onPressed: () => _makePhoneCall(helpPhoneNumber!),
            icon: const Icon(
              Icons.call,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Call for Help',
          ),
        // WhatsApp icon for help
        if (showHelpIcons && helpPhoneNumber != null)
          IconButton(
            onPressed: () => _openWhatsApp(helpPhoneNumber!),
            icon: const Icon(
              Icons.chat,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'WhatsApp for Help',
          ),
        // Notification icon - only show if callback is provided
        if (onNotificationTap != null)
          IconButton(
            onPressed: onNotificationTap,
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
