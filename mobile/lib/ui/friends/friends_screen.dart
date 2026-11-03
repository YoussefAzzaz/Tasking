import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Parses 32-bit hex color string (e.g. '#6366F1' or '0xFF6366F1') safely without throwing.
Color _parseHexColor(String? hexString, {Color fallback = const Color(0xFF6366F1)}) {
  if (hexString == null || hexString.isEmpty) return fallback;
  try {
    String hex = hexString.replaceAll('#', '').trim();
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) return Color(val & 0xFFFFFFFF);
    }
  } catch (_) {}
  return fallback;
}

/// Companions & Mutual Accountability Screen.
/// Pro UI/UX with Obsidian Cyberpunk theme, live candidate preview before invite,
/// instant accept/refuse with notifications, today's prayer comparison, and gamified standings.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _friendRepo = FriendRepository();
  final _profileRepo = UserProfileRepository();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Tab 0 = Circle, Tab 1 = Today's Prayers, Tab 2 = Standings & Habits
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initial sync
    _friendRepo.syncAllFriendData();

    // Periodic sync every 12s while screen is active
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        _friendRepo.syncAllFriendData();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // ADD COMPANION RESPONSIVE BOTTOM SHEET WITH LIVE CANDIDATE PREVIEW
  // ===========================================================================
  void _showAddCompanionSheet(BuildContext context, String myFriendCode) {
    final searchCtrl = TextEditingController();
    FriendUser? foundCandidate;
    bool isSearching = false;
    bool isSubmitting = false;
    String lastQuery = '';
    Timer? debounce;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context);
          final viewInsets = MediaQuery.of(sheetCtx).viewInsets;

          void performSearch(String query) {
            debounce?.cancel();
            final clean = query.trim();
            if (clean.isEmpty) {
              setSheetState(() {
                foundCandidate = null;
                isSearching = false;
                lastQuery = '';
              });
              return;
            }

            setSheetState(() {
              isSearching = true;
              lastQuery = clean;
            });

            debounce = Timer(const Duration(milliseconds: 350), () async {
              try {
                final candidate = await _friendRepo.searchCandidateCompanion(clean);
                if (sheetCtx.mounted) {
                  setSheetState(() {
                    foundCandidate = candidate;
                    isSearching = false;
                  });
                }
              } catch (_) {
                if (sheetCtx.mounted) {
                  setSheetState(() {
                    foundCandidate = null;
                    isSearching = false;
                  });
                }
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: AxisColors.borderGlass2, width: 1.5),
                  left: BorderSide(color: AxisColors.borderGlass2, width: 0.5),
                  right: BorderSide(color: AxisColors.borderGlass2, width: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 36,
                    spreadRadius: 8,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Drag Indicator Pill
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AxisColors.textDim.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title Header with Close Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AxisColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                            color: AxisColors.primarySoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.addCompanion,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.addCompanionDesc,
                                style: GoogleFonts.getFont(
                                  'Geist',
                                  fontSize: 11,
                                  color: AxisColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                          onPressed: () {
                            debounce?.cancel();
                            Navigator.of(sheetCtx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Your Friend Code Showcase Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AxisColors.surfaceLowest,
                            AxisColors.surfaceLow,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AxisColors.primary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_rounded, size: 18, color: AxisColors.primarySoft),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.yourFriendCode.toUpperCase(),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                    color: AxisColors.textDim,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  myFriendCode.isNotEmpty ? myFriendCode : 'AX-7842',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AxisColors.primarySoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: myFriendCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.copyCodeSuccess),
                                  backgroundColor: AxisColors.surfaceLow,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 13),
                            label: Text(
                              l10n.copy,
                              style: GoogleFonts.getFont('Geist', fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AxisColors.primary.withValues(alpha: 0.22),
                              foregroundColor: AxisColors.primarySoft,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.45)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Input Field with Live Search Trigger
                    TextField(
                      controller: searchCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.spaceGrotesk(
                        color: AxisColors.textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.friendCode,
                        labelStyle: GoogleFonts.getFont('Geist', color: AxisColors.textDim, fontSize: 13),
                        hintText: l10n.searchCompanionHint,
                        hintStyle: GoogleFonts.getFont('Geist', color: AxisColors.textDim.withValues(alpha: 0.6), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AxisColors.primarySoft),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                                ),
                              )
                            : searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: AxisColors.textDim),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      performSearch('');
                                    },
                                  )
                                : null,
                        filled: true,
                        fillColor: AxisColors.surfaceLowest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AxisColors.primary, width: 1.8),
                        ),
                      ),
                      onChanged: performSearch,
                    ),
                    const SizedBox(height: 16),

                    // LIVE CANDIDATE PREVIEW CARD
                    if (foundCandidate != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: foundCandidate!.status == 'accepted'
                                ? AxisColors.success.withValues(alpha: 0.6)
                                : AxisColors.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Pill
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (foundCandidate!.status == 'accepted'
                                            ? AxisColors.success
                                            : AxisColors.primary)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        foundCandidate!.status == 'accepted'
                                            ? Icons.check_circle_rounded
                                            : Icons.verified_user_rounded,
                                        size: 13,
                                        color: foundCandidate!.status == 'accepted'
                                            ? AxisColors.success
                                            : AxisColors.primarySoft,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        foundCandidate!.status == 'accepted'
                                            ? l10n.alreadyFriends
                                            : (foundCandidate!.status == 'pending'
                                                ? l10n.requestAlreadyPending
                                                : l10n.candidateFound),
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: foundCandidate!.status == 'accepted'
                                              ? AxisColors.success
                                              : AxisColors.primarySoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  foundCandidate!.friendCode ?? '',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AxisColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Profile row: Avatar + Name + Level
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _parseHexColor(foundCandidate!.avatarColor),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      foundCandidate!.name.isNotEmpty
                                          ? foundCandidate!.name[0].toUpperCase()
                                          : 'C',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        foundCandidate!.name,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AxisColors.surfaceHigh,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Lv. ${foundCandidate!.level}',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AxisColors.warning,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            foundCandidate!.title,
                                            style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${foundCandidate!.totalXp} XP',
                                            style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else if (!isSearching && lastQuery.length >= 3) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AxisColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 20, color: AxisColors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.noCompanionFound,
                                style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Send Request Button
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: (foundCandidate != null && foundCandidate!.status == 'none')
                            ? const LinearGradient(
                                colors: [AxisColors.primary, Color(0xFF818CF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: (foundCandidate == null || foundCandidate!.status != 'none')
                            ? AxisColors.surfaceHigh.withValues(alpha: 0.4)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: (foundCandidate != null && foundCandidate!.status == 'none')
                            ? [
                                BoxShadow(
                                  color: AxisColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: isSubmitting || foundCandidate == null || foundCandidate!.status != 'none'
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  final success = await _friendRepo.sendFriendRequestToCandidate(foundCandidate!);
                                  if (context.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? (l10n.isArabic
                                                  ? 'تم إرسال طلب الرفقة بنجاح إلى ${foundCandidate!.name}!'
                                                  : 'Friend request sent successfully to ${foundCandidate!.name}!')
                                              : (l10n.isArabic
                                                  ? 'تعذر إرسال الطلب. حاول مرة أخرى.'
                                                  : 'Could not send request. Please try again.'),
                                        ),
                                        backgroundColor: success ? AxisColors.success : AxisColors.warning,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: AxisColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AxisColors.textDim,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    foundCandidate != null
                                        ? l10n.sendRequestTo(foundCandidate!.name)
                                        : l10n.sendConnectionRequest,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MAIN SCAFFOLD & CUSTOM CAPSULE TAB BAR
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.canvasBase,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AxisColors.textHigh),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.companions,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AxisColors.textHigh,
          ),
        ),
        actions: [
          ValueListenableBuilder<UserProfile>(
            valueListenable: _profileRepo.profileNotifier,
            builder: (context, profile, _) {
              final code = profile.friendCode ?? 'AX-7842';
              return Padding(
                padding: const EdgeInsets.only(right: 14.0, left: 14.0),
                child: Center(
                  child: InkWell(
                    onTap: () => _showAddCompanionSheet(context, code),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AxisColors.primary.withValues(alpha: 0.25),
                            AxisColors.primary.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AxisColors.primary.withValues(alpha: 0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: AxisColors.primary.withValues(alpha: 0.18),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, size: 15, color: AxisColors.primarySoft),
                          const SizedBox(width: 6),
                          Text(
                            l10n.addCompanion,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.primarySoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: StreamBuilder<List<FriendUser>>(
                stream: _friendRepo.watchPendingRequests(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;
                  return TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AxisColors.primary.withValues(alpha: 0.35),
                          AxisColors.primary.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.7)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AxisColors.textHigh,
                    unselectedLabelColor: AxisColors.textDim,
                    labelStyle: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w500),
                    tabs: [
                      // TAB 0: CIRCLE (REQUESTS, NOTIFICATIONS, COMPANIONS)
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.group_rounded, size: 15),
                            const SizedBox(width: 5),
                            Flexible(child: Text(l10n.circle, overflow: TextOverflow.ellipsis)),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AxisColors.primary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // TAB 1: TODAY'S PRAYERS
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.checklist_rtl_rounded, size: 15),
                            const SizedBox(width: 5),
                            Flexible(child: Text(l10n.todaysBoard, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      // TAB 2: WEEKLY STANDINGS & HABITS
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 15),
                            const SizedBox(width: 5),
                            Flexible(child: Text(l10n.weeklyStandings, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCircleTab(),
          _buildTodaysPrayerBoard(todayStr),
          _buildWeeklyStandings(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 0: CIRCLE & NOTIFICATIONS (REQUESTS, NOTIFICATIONS, COMPANIONS, CODE)
  // ===========================================================================
  Widget _buildCircleTab() {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _friendRepo.syncAllFriendData();
      },
      color: AxisColors.primary,
      backgroundColor: AxisColors.surfaceLow,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 1. Your Friend Code Showcase Card
          ValueListenableBuilder<UserProfile>(
            valueListenable: _profileRepo.profileNotifier,
            builder: (context, profile, _) {
              final myCode = profile.friendCode ?? 'AX-7842';
              return Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AxisColors.surfaceLowest,
                      AxisColors.surfaceLow,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: AxisColors.primarySoft, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.yourFriendCode.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: AxisColors.textDim),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            myCode,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AxisColors.primarySoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: myCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.copyCodeSuccess),
                            backgroundColor: AxisColors.surfaceLow,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        l10n.copy,
                        style: GoogleFonts.getFont('Geist', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary.withValues(alpha: 0.22),
                        foregroundColor: AxisColors.primarySoft,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.45)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. INCOMING FRIEND REQUESTS SECTION (WITH REAL CANDIDATE DETAILS + ACCEPT/REFUSE)
          StreamBuilder<List<FriendUser>>(
            stream: _friendRepo.watchPendingRequests(),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.mark_email_unread_rounded, size: 15, color: AxisColors.primarySoft),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.pendingRequests.toUpperCase()} (${requests.length})',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.primarySoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...requests.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AxisColors.primary.withValues(alpha: 0.45), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.08),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Requester Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _parseHexColor(r.avatarColor),
                                shape: BoxShape.circle,
                                border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  r.name.isNotEmpty ? r.name[0].toUpperCase() : 'C',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AxisColors.textHigh,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lv. ${r.level}  ·  ${r.friendCode ?? "AX-7842"}',
                                    style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                  ),
                                ],
                              ),
                            ),
                            // Accept Button
                            ElevatedButton.icon(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await _friendRepo.acceptFriendRequest(r.friendshipId, r.userId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.requestAccepted),
                                      backgroundColor: AxisColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_rounded, size: 15),
                              label: Text(
                                l10n.accept,
                                style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AxisColors.success.withValues(alpha: 0.22),
                                foregroundColor: AxisColors.success,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: AxisColors.success.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Refuse Button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AxisColors.error, size: 20),
                              tooltip: l10n.refuse,
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await _friendRepo.declineFriendRequest(r.friendshipId, r.userId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.requestDeclined),
                                      backgroundColor: AxisColors.surfaceLow,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // 3. COMPANION REMINDERS & NOTIFICATIONS SECTION
          StreamBuilder<List<FriendActivityLog>>(
            stream: _friendRepo.watchFriendActivityLogs(),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, size: 15, color: AxisColors.tertiaryBright),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.friendNotifications.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.tertiaryBright,
                        ),
                      ),
                      const Spacer(),
                      if (logs.isNotEmpty)
                        TextButton(
                          onPressed: () => _friendRepo.clearFriendNotifications(),
                          child: Text(
                            l10n.clearNotifications,
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 16, color: AxisColors.textDim),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.noNotificationsYet,
                              style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...logs.take(5).map((log) {
                      IconData iconData = Icons.notifications_rounded;
                      Color iconColor = AxisColors.tertiary;

                      if (log.isFriendRequest) {
                        iconData = Icons.person_add_rounded;
                        iconColor = AxisColors.primarySoft;
                      } else if (log.isRequestAccepted) {
                        iconData = Icons.celebration_rounded;
                        iconColor = AxisColors.success;
                      } else if (log.isRequestDeclined) {
                        iconData = Icons.cancel_outlined;
                        iconColor = AxisColors.error;
                      } else if (log.isPrayerReminder) {
                        iconData = Icons.mosque_rounded;
                        iconColor = AxisColors.tertiaryBright;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, size: 15, color: iconColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log.title,
                                style: GoogleFonts.getFont(
                                  'Geist',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),

          // 4. CONNECTED COMPANIONS LIST
          StreamBuilder<List<FriendUser>>(
            stream: _friendRepo.watchAcceptedFriends(),
            builder: (context, snapshot) {
              final friends = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 16, color: AxisColors.textDim),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.connectedCompanions.toUpperCase()} (${friends.length})',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (friends.isEmpty)
                    _buildEmptyStateCard(
                      icon: Icons.group_add_outlined,
                      title: l10n.noCompanionsYet,
                      subtitle: l10n.noCompanionsDesc,
                      actionLabel: l10n.addCompanion,
                      onAction: () {
                        final code = _profileRepo.profileNotifier.value.friendCode ?? 'AX-7842';
                        _showAddCompanionSheet(context, code);
                      },
                    )
                  else
                    ...friends.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _parseHexColor(f.avatarColor),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    f.name.isNotEmpty ? f.name[0].toUpperCase() : 'C',
                                    style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.name,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AxisColors.textHigh,
                                      ),
                                    ),
                                    Text(
                                      '${l10n.friendCode}: ${f.friendCode ?? "AX-7842"}  ·  Lv. ${f.level}',
                                      style: GoogleFonts.getFont('Geist', fontSize: 10.5, color: AxisColors.textDim),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AxisColors.textDim),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AxisColors.surfaceLow,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Text(
                                        l10n.removeCompanion,
                                        style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh, fontWeight: FontWeight.w700),
                                      ),
                                      content: Text(
                                        l10n.removeCompanionConfirm,
                                        style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: Text(l10n.cancel, style: const TextStyle(color: AxisColors.textDim)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: Text(l10n.remove, style: const TextStyle(color: AxisColors.error)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _friendRepo.removeFriendship(f.friendshipId);
                                  }
                                },
                              ),
                            ],
                          ),
                        )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TODAY'S PRAYER & HABIT CHECKLIST BOARD
  // ===========================================================================
  Widget _buildTodaysPrayerBoard(String todayStr) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _friendRepo.syncAllFriendData();
      },
      color: AxisColors.primary,
      backgroundColor: AxisColors.surfaceLow,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Elegant Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AxisColors.primary.withValues(alpha: 0.16),
                  AxisColors.tertiary.withValues(alpha: 0.08),
                  AxisColors.surfaceLowest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AxisColors.primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AxisColors.tertiary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.mosque_rounded, color: AxisColors.tertiaryBright, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mutualPrayerAccountability.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.tertiaryBright,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.todayPrayerSub,
                        style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Stream of Checklist Cards (Current User FIRST + Companions)
          StreamBuilder<List<DailyPrayerStatus>>(
            stream: _friendRepo.watchTodayChecklist(),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return _buildEmptyStateCard(
                  icon: Icons.people_outline_rounded,
                  title: l10n.noCompanionsYet,
                  subtitle: l10n.noCompanionsDesc,
                  actionLabel: l10n.addCompanion,
                  onAction: () {
                    final code = _profileRepo.profileNotifier.value.friendCode ?? 'AX-7842';
                    _showAddCompanionSheet(context, code);
                  },
                );
              }

              return Column(
                children: list.map((status) => _buildCompanionChecklistCard(status)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionChecklistCard(DailyPrayerStatus status) {
    final l10n = AppLocalizations.of(context);
    final prayers = [
      {'code': 'fajr', 'name': l10n.prayerName('fajr'), 'done': status.fajr},
      {'code': 'dhuhr', 'name': l10n.prayerName('dhuhr'), 'done': status.dhuhr},
      {'code': 'asr', 'name': l10n.prayerName('asr'), 'done': status.asr},
      {'code': 'maghrib', 'name': l10n.prayerName('maghrib'), 'done': status.maghrib},
      {'code': 'isha', 'name': l10n.prayerName('isha'), 'done': status.isha},
    ];

    final isMe = status.userId == _friendRepo.currentUserId ||
        status.userName == 'You' ||
        status.userName == l10n.youLabel;

    final cardBg = isMe ? AxisColors.surfaceLow : AxisColors.surfaceLowest;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe ? AxisColors.primary.withValues(alpha: 0.5) : AxisColors.borderSubtle,
          width: isMe ? 1.4 : 1.0,
        ),
        boxShadow: [
          if (isMe)
            BoxShadow(
              color: AxisColors.primary.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + You Badge + Streak
          Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _parseHexColor(status.userAvatarColor),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMe ? AxisColors.primarySoft : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    status.userName.isNotEmpty ? status.userName[0].toUpperCase() : 'C',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMe ? l10n.youLabel : status.userName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.youLabel,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AxisColors.primarySoft,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${status.completedCount}/5 ${l10n.prayersDoneCount}',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ],
                ),
              ),
              // Streak Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AxisColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: AxisColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      '${status.streakDays} ${l10n.day}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AxisColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 5 Prayers Responsive Capsules Row
          Row(
            children: prayers.map((p) {
              final isDone = p['done'] as bool;
              final name = p['name'] as String;

              return Expanded(
                child: InkWell(
                  onTap: (!isDone && !isMe)
                      ? () {
                          HapticFeedback.lightImpact();
                          _friendRepo.sendPrayerReminder(status.userId, name);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.isArabic
                                    ? 'تم إرسال تذكير لصلاة $name إلى ${status.userName} 🕌'
                                    : 'Sent reminder for $name prayer to ${status.userName} 🕌',
                              ),
                              backgroundColor: AxisColors.surfaceLow,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AxisColors.tertiary.withValues(alpha: 0.16)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDone
                            ? AxisColors.tertiary.withValues(alpha: 0.8)
                            : AxisColors.borderSubtle.withValues(alpha: 0.6),
                        width: isDone ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : (!isMe
                                  ? Icons.notifications_none_rounded
                                  : Icons.radio_button_unchecked_rounded),
                          size: 15,
                          color: isDone
                              ? AxisColors.tertiary
                              : (!isMe ? AxisColors.primarySoft : AxisColors.textDim),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                            color: isDone ? AxisColors.textHigh : AxisColors.textDim,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Daily Habits consistency bar
          if (status.habitsTotal > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 13, color: AxisColors.textDim),
                  const SizedBox(width: 6),
                  Text(
                    '${l10n.dailyHabitsCount}: ${status.habitsDone}/${status.habitsTotal}',
                    style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                  ),
                  const Spacer(),
                  if (status.habitsDone == status.habitsTotal)
                    Text(
                      l10n.allCompletedBadge,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.tertiary,
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

  // ===========================================================================
  // TAB 2: WEEKLY STANDINGS (PODIUM + LEADERBOARD INCLUDING CURRENT USER)
  // ===========================================================================
  Widget _buildWeeklyStandings() {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<FriendUser>>(
      stream: _friendRepo.watchAllStandings(),
      builder: (context, snapshot) {
        final standings = snapshot.data ?? [];

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Motivational Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AxisColors.warning.withValues(alpha: 0.16),
                    AxisColors.surfaceLowest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AxisColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AxisColors.warning.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: AxisColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Icon(Icons.military_tech_rounded, color: AxisColors.warningBright, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.weeklyStandings.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AxisColors.warningBright,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.circleStandingsSub,
                          style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (standings.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.emoji_events_outlined,
                title: l10n.noCompanionsYet,
                subtitle: l10n.noCompanionsDesc,
                actionLabel: l10n.addCompanion,
                onAction: () {
                  final code = _profileRepo.profileNotifier.value.friendCode ?? 'AX-7842';
                  _showAddCompanionSheet(context, code);
                },
              )
            else ...[
              // TOP 3 PODIUM SHOWCASE
              _buildPodiumSection(standings),
              const SizedBox(height: 20),

              // RANKS 4+ LIST
              if (standings.length > 3)
                ...List.generate(standings.length - 3, (index) {
                  final rank = index + 4;
                  final f = standings[rank - 1];
                  return _buildLeaderboardRow(f, rank);
                }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPodiumSection(List<FriendUser> standings) {
    final top1 = standings.isNotEmpty ? standings[0] : null;
    final top2 = standings.length > 1 ? standings[1] : null;
    final top3 = standings.length > 2 ? standings[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2 (Silver)
        if (top2 != null)
          Expanded(child: _buildPodiumColumn(user: top2, rank: 2, height: 120, color: const Color(0xFF94A3B8)))
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 10),

        // Rank 1 (Gold - Center)
        if (top1 != null)
          Expanded(child: _buildPodiumColumn(user: top1, rank: 1, height: 145, color: AxisColors.warning))
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 10),

        // Rank 3 (Bronze)
        if (top3 != null)
          Expanded(child: _buildPodiumColumn(user: top3, rank: 3, height: 105, color: const Color(0xFFD97706)))
        else
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required FriendUser user,
    required int rank,
    required double height,
    required Color color,
  }) {
    final isMe = user.userId == _friendRepo.currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / Badge for #1
        if (rank == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.workspace_premium_rounded, size: 24, color: AxisColors.warning),
          ),
        // Avatar with podium border
        Container(
          width: rank == 1 ? 48 : 42,
          height: rank == 1 ? 48 : 42,
          decoration: BoxDecoration(
            color: _parseHexColor(user.avatarColor),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'C',
              style: GoogleFonts.spaceGrotesk(
                fontSize: rank == 1 ? 18 : 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AxisColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('YOU', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        Text(
          '${user.totalXp} XP',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 8),

        // Podium Pillar
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.08),
                AxisColors.surfaceLowest,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(FriendUser f, int rank) {
    final isMe = f.userId == _friendRepo.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AxisColors.surfaceLow : AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AxisColors.primary.withValues(alpha: 0.5) : AxisColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AxisColors.textDim,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _parseHexColor(f.avatarColor),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                f.name.isNotEmpty ? f.name[0].toUpperCase() : 'C',
                style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        f.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('YOU', style: TextStyle(fontSize: 8.5, color: AxisColors.primarySoft, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Lv. ${f.level}  ·  ${f.title}',
                  style: GoogleFonts.getFont('Geist', fontSize: 10.5, color: AxisColors.textDim),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AxisColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${f.totalXp} XP',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AxisColors.primarySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AxisColors.textDim),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.person_add_rounded, size: 15),
            label: Text(actionLabel, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
