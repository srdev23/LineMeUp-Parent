import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/pickup_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'student_selection_screen.dart';

class PickupHomeScreen extends StatefulWidget {
  const PickupHomeScreen({super.key});

  @override
  State<PickupHomeScreen> createState() => _PickupHomeScreenState();
}

class _PickupHomeScreenState extends State<PickupHomeScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final maxContentWidth = isTablet ? 700.0 : double.infinity;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Consumer<PickupProvider>(
              builder: (context, pickupProvider, child) {
                if (pickupProvider.school == null || pickupProvider.selectedStudents.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    _buildAppBar(pickupProvider),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {},
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 40 : 20,
                            8,
                            isTablet ? 40 : 20,
                            20,
                          ),
                          child: Column(
                            children: [
                              _buildStatusCard(pickupProvider),
                              const SizedBox(height: 20),
                              _buildStudentsCard(pickupProvider),
                              const SizedBox(height: 20),
                              _buildInfoCard(pickupProvider),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(PickupProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StudentSelectionScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.grey[700],
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // School Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.school!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: provider.school!.pickupActive 
                            ? Colors.green 
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.school!.pickupActive ? 'Pickup Active' : 'Pickup Inactive',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Logout Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showLogoutDialog(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red[600],
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      try {
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        final pickupProvider =
            Provider.of<PickupProvider>(context, listen: false);

        pickupProvider.cleanup();
        await authProvider.signOut();
      } catch (e) {
        print('Logout error: $e');
      }
    }
  }

  Widget _buildStatusCard(PickupProvider provider) {
    final statusConfig = _getStatusConfig(provider);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusConfig.color.withValues(alpha: 0.15),
            statusConfig.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusConfig.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                // Animated Status Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = provider.pickupState == PickupState.ready
                        ? 1.0 + (_pulseController.value * 0.1)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusConfig.color.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          statusConfig.icon,
                          size: 52,
                          color: statusConfig.color,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Status Text
                Text(
                  statusConfig.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: statusConfig.color,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  statusConfig.subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Queue Position Badge
                if (provider.pickupState == PickupState.queued &&
                    provider.queuePosition > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: statusConfig.color.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Position',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusConfig.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${provider.queuePosition}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action Buttons
          if (provider.canJoinQueue || provider.canMarkPickedUp)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildActionButtons(provider),
            ),
        ],
      ),
    );
  }

  StatusConfig _getStatusConfig(PickupProvider provider) {
    switch (provider.pickupState) {
      case PickupState.pickupNotActive:
        return StatusConfig(
          title: 'Pickup Not Active',
          subtitle: 'The school pickup service is currently unavailable. Please wait for it to start.',
          icon: Icons.pause_circle_outline_rounded,
          color: Colors.grey,
        );
      case PickupState.waitingInsideZoneInactive:
        return StatusConfig(
          title: 'Waiting',
          subtitle: 'You\'re in the pickup zone. The service will start soon.',
          icon: Icons.hourglass_empty_rounded,
          color: Colors.orange,
        );
      case PickupState.waitingActiveNotQueued:
        if (provider.isInsideZone) {
          return StatusConfig(
            title: 'Ready to Join',
            subtitle: 'You are inside the pickup zone. Join the queue when you\'re ready.',
            icon: Icons.location_on_rounded,
            color: const Color(0xFF3B82F6),
          );
        } else {
          return StatusConfig(
            title: 'Approaching',
            subtitle: 'You are near the pickup zone. Get closer to join the queue.',
            icon: Icons.near_me_rounded,
            color: const Color(0xFF3B82F6),
          );
        }
      case PickupState.queued:
        return StatusConfig(
          title: 'In Queue',
          subtitle: 'You\'re in line! Please wait for your turn to pick up.',
          icon: Icons.groups_rounded,
          color: const Color(0xFF3B82F6),
        );
      case PickupState.ready:
        return StatusConfig(
          title: 'Ready Now!',
          subtitle: 'Your child is ready for pickup. Please proceed to the pickup area.',
          icon: Icons.celebration_rounded,
          color: const Color(0xFF10B981),
        );
      case PickupState.pickedUp:
        return StatusConfig(
          title: 'Completed',
          subtitle: 'Pickup completed successfully. Have a great day!',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
        );
    }
  }

  Widget _buildActionButtons(PickupProvider provider) {
    return Column(
      children: [
        if (provider.canJoinQueue)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.joinQueue();
                      if (mounted) {
                        _showResultSnackBar(
                          success: success,
                          successMessage: 'Successfully joined the queue!',
                          errorMessage: provider.errorMessage ?? 'Failed to join queue',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Join Queue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        if (provider.canJoinQueue && provider.canMarkPickedUp)
          const SizedBox(height: 12),
        if (provider.canMarkPickedUp)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () => _showPickupConfirmDialog(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Mark as Picked Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _showPickupConfirmDialog(PickupProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Confirm Pickup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Have you picked up your child(ren)?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not Yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Yes, Confirm',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.markAsPickedUp();
      if (mounted) {
        _showResultSnackBar(
          success: success,
          successMessage: 'Pickup completed successfully!',
          errorMessage: provider.errorMessage ?? 'Failed to mark as picked up',
        );
      }
    }
  }

  void _showResultSnackBar({
    required bool success,
    required String successMessage,
    required String errorMessage,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(success ? successMessage : errorMessage),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildStudentsCard(PickupProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.backpack_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Students',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.selectedStudents.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...provider.selectedStudents.map(
            (student) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Hero(
                    tag: 'student_photo_${student.id}',
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF3B82F6).withValues(alpha: 0.8),
                            const Color(0xFF3B82F6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: student.photo != null && student.photo!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: student.photo!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _buildStudentInitial(student),
                                errorWidget: (context, url, error) => _buildStudentInitial(student),
                              )
                            : _buildStudentInitial(student),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${student.schoolId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInitial(student) {
    return Center(
      child: Text(
        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoCard(PickupProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              icon: Icons.location_on_rounded,
              label: 'Your Location',
              value: provider.isInsideZone ? 'Inside Zone' : 'Outside Zone',
              color: provider.isInsideZone 
                  ? const Color(0xFF10B981) 
                  : Colors.grey,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildInfoItem(
              icon: Icons.schedule_rounded,
              label: 'Service Status',
              value: provider.school!.pickupActive ? 'Active' : 'Inactive',
              color: provider.school!.pickupActive 
                  ? const Color(0xFF10B981) 
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class StatusConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  StatusConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
