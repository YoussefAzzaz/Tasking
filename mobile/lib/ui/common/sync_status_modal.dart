import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/friend_repository.dart';

/// Modal bottom sheet presenting real-time Cloud Synchronization & Network Diagnostics.
class SyncStatusModal extends StatefulWidget {
  const SyncStatusModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SyncStatusModal(),
    );
  }

  @override
  State<SyncStatusModal> createState() => _SyncStatusModalState();
}

class _SyncStatusModalState extends State<SyncStatusModal> {
  bool _isSyncing = false;
  String? _syncMessage;

  Future<void> _triggerManualSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });
    HapticFeedback.lightImpact();

    try {
      final online = await NetworkService().checkSupabaseConnectivity();
      if (!online) {
        if (mounted) {
          setState(() {
            _syncMessage = 'Network unreachable. Please check Wi-Fi or cellular data.';
            _isSyncing = false;
          });
        }
        return;
      }

      await AuthService().ensureAuthenticatedSession();
      await ensurePowerSyncConnected();
      await FriendRepository().syncAllFriendData();

      if (mounted) {
        setState(() {
          _syncMessage = 'Sync successful! All local records and cloud streams updated.';
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncMessage = 'Sync notice: $e';
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final isOnline = NetworkService().isOnline;
    final isDbConnected = db.connected;
    final isGuest = auth.isGuest;
    final email = auth.userEmail ?? (isGuest ? 'Local Offline Guest' : 'Not signed in');

    return Container(
      decoration: const BoxDecoration(
        color: AxisColors.canvasBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AxisColors.borderGlass2, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.textDim.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOnline && isDbConnected ? AxisColors.tertiary : AxisColors.warning).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline && isDbConnected ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                  color: isOnline && isDbConnected ? AxisColors.tertiary : AxisColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLOUD SYNCHRONIZATION',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Column(
              children: [
                _buildDiagnosticRow(
                  label: 'Internet Connectivity',
                  status: isOnline ? 'ONLINE' : 'OFFLINE',
                  isGood: isOnline,
                  icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                ),
                const Divider(height: 18, color: AxisColors.borderSubtle),
                _buildDiagnosticRow(
                  label: 'PowerSync Engine',
                  status: isDbConnected ? 'ACTIVE' : (isOnline ? 'CONNECTING' : 'SUSPENDED'),
                  isGood: isDbConnected,
                  icon: Icons.sync_alt_rounded,
                ),
                const Divider(height: 18, color: AxisColors.borderSubtle),
                _buildDiagnosticRow(
                  label: 'Supabase Authentication',
                  status: auth.isAuthenticated ? 'AUTHENTICATED' : (isGuest ? 'GUEST (OFFLINE)' : 'UNAUTHENTICATED'),
                  isGood: auth.isAuthenticated,
                  icon: Icons.shield_outlined,
                ),
              ],
            ),
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _syncMessage!.contains('successful')
                      ? AxisColors.success.withValues(alpha: 0.5)
                      : AxisColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _syncMessage!,
                style: GoogleFonts.getFont(
                  'Geist',
                  fontSize: 12,
                  color: _syncMessage!.contains('successful') ? AxisColors.success : AxisColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (isGuest) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/auth');
              },
              icon: const Icon(Icons.login_rounded, size: 16),
              label: Text(
                'SIGN IN TO SYNC WITH DESKTOP',
                style: GoogleFonts.spaceGrotesk(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _triggerManualSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              _isSyncing ? 'SYNCING...' : 'SYNC & RECONNECT NOW',
              style: GoogleFonts.spaceGrotesk(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isGuest ? AxisColors.surfaceLowest : AxisColors.primary,
              foregroundColor: isGuest ? AxisColors.primarySoft : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow({
    required String label,
    required String status,
    required bool isGood,
    required IconData icon,
  }) {
    final color = isGood ? AxisColors.tertiary : AxisColors.warning;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

