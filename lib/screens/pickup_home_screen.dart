import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pickup_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class PickupHomeScreen extends StatefulWidget {
  const PickupHomeScreen({super.key});

  @override
  State<PickupHomeScreen> createState() => _PickupHomeScreenState();
}

class _PickupHomeScreenState extends State<PickupHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pickup Status',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              if (!mounted) return;
              
              // Navigate away FIRST to prevent widget access errors
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
              
              // Then cleanup and sign out (after navigation to avoid context errors)
              try {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final pickupProvider =
                    Provider.of<PickupProvider>(context, listen: false);
                
                // Cleanup provider (stops streams and location tracking)
                pickupProvider.cleanup();
                
                // Sign out
                await authProvider.signOut();
              } catch (e) {
                print('Logout error: $e');
                // Try to sign out anyway
                try {
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.signOut();
                } catch (_) {
                  // Ignore errors
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<PickupProvider>(
        builder: (context, pickupProvider, child) {
          // Check if provider needs initialization
          if (pickupProvider.school == null || pickupProvider.selectedStudents.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh logic if needed
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  
                  // School Info Card
                  _buildSchoolCard(pickupProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Students Card
                  _buildStudentsCard(pickupProvider),
                  
                  const SizedBox(height: 24),
                  
                  // Main Status Card - Large and Prominent
                  _buildStatusCard(pickupProvider, context),
                  
                  const SizedBox(height: 20),
                  
                  // Additional Info Card
                  _buildInfoCard(pickupProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSchoolCard(PickupProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.school!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsCard(PickupProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Students',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...provider.selectedStudents.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(PickupProvider provider, BuildContext context) {
    String statusText;
    String statusSubtext;
    Color statusColor;
    Color backgroundColor;
    IconData statusIcon;
    double iconSize;

    switch (provider.pickupState) {
      case PickupState.pickupNotActive:
        statusText = 'Pickup Not Active';
        statusSubtext = 'Pickup service is currently unavailable';
        statusColor = Colors.grey;
        backgroundColor = Colors.grey[100]!;
        statusIcon = Icons.pause_circle_outline;
        iconSize = 80;
        break;
      case PickupState.waitingInsideZoneInactive:
        statusText = 'Waiting';
        statusSubtext = 'Pickup service will start soon';
        statusColor = Colors.orange;
        backgroundColor = Colors.orange[50]!;
        statusIcon = Icons.access_time;
        iconSize = 80;
        break;
      case PickupState.waitingActiveNotQueued:
        if (provider.isInsideZone) {
          statusText = 'Ready to Join';
          statusSubtext = 'You are in the pickup zone';
        } else {
          statusText = 'Approaching';
          statusSubtext = 'You are near the pickup zone';
        }
        statusColor = Colors.blue;
        backgroundColor = Colors.blue[50]!;
        statusIcon = Icons.location_on;
        iconSize = 80;
        break;
      case PickupState.queued:
        statusText = 'In Queue';
        statusSubtext = provider.queuePosition > 0
            ? 'Your position: #${provider.queuePosition}'
            : 'Waiting for your turn';
        statusColor = Colors.blue;
        backgroundColor = Colors.blue[50]!;
        statusIcon = Icons.queue;
        iconSize = 80;
        break;
      case PickupState.ready:
        statusText = 'Ready for Pickup';
        statusSubtext = 'Your child is ready! Please proceed to pickup';
        statusColor = Colors.green;
        backgroundColor = Colors.green[50]!;
        statusIcon = Icons.check_circle;
        iconSize = 100;
        break;
      case PickupState.pickedUp:
        statusText = 'Picked Up';
        statusSubtext = 'Pickup completed successfully';
        statusColor = Colors.green;
        backgroundColor = Colors.green[50]!;
        statusIcon = Icons.done_all;
        iconSize = 80;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              statusIcon,
              size: iconSize,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: statusColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            statusSubtext,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          if (provider.pickupState == PickupState.queued &&
              provider.queuePosition > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#${provider.queuePosition}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
          
          // Action Buttons
          const SizedBox(height: 32),
          _buildActionButtons(provider, context),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PickupProvider provider, BuildContext context) {
    return Column(
      children: [
        // Join Queue Button
        if (provider.canJoinQueue)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.joinQueue();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Successfully joined the queue!'
                                  : provider.errorMessage ??
                                      'Failed to join queue',
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.queue, size: 24),
              label: Text(
                provider.isLoading ? 'Joining...' : 'Join Queue',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

        // Mark as Picked Up Button
        if (provider.canMarkPickedUp && !provider.isLoading) ...[
          if (provider.canJoinQueue) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Pickup'),
                          content: const Text(
                              'Have you picked up your child(ren)?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && mounted) {
                        final success = await provider.markAsPickedUp();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Marked as picked up successfully!'
                                    : provider.errorMessage ??
                                        'Failed to mark as picked up',
                              ),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle, size: 24),
              label: Text(
                provider.isLoading ? 'Updating...' : 'Mark as Picked Up',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(PickupProvider provider) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: provider.isInsideZone ? 'Inside Zone' : 'Outside Zone',
                  color: provider.isInsideZone ? Colors.green : Colors.grey,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildInfoItem(
                  icon: Icons.schedule,
                  label: 'Status',
                  value: provider.school!.pickupActive ? 'Active' : 'Inactive',
                  color: provider.school!.pickupActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
