import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../data/notification_parser.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/persona_motifs.dart';
import '../widgets/transaction_editor_sheet.dart';
import 'analytics_screen.dart';
import 'debts_screen.dart';
import 'home_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _tabIndex = 0;
  late final PageController _pageController;
  late PersonaThemePreset _targetPreset;
  late final AnimationController _enterController;
  late final AnimationController _exitController;
  bool _wipeVisible = false;
  bool _isTransitioning = false;
  bool _precached = false;
  bool _quickAddOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _tabIndex);
    _targetPreset = widget.store.themePreset;
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 290),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );

    widget.store.notificationBridge.setLiveListener(
      _handleLiveNotification,
      onQuickAdd: _handleQuickAddRequest,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingQuickAdd();
    });
  }

  Future<void> _checkPendingQuickAdd() async {
    final shouldOpen =
        await widget.store.notificationBridge.consumePendingQuickAdd();
    if (shouldOpen && mounted) {
      _handleQuickAddRequest();
    }
  }

  Future<void> _handleQuickAddRequest() async {
    if (!mounted || _quickAddOpen || widget.store.isLoading) return;
    if (_tabIndex != 0) {
      _selectTab(0);
    }
    _quickAddOpen = true;
    try {
      await TransactionEditorSheet.show(context, store: widget.store);
    } finally {
      _quickAddOpen = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage('assets/images/p3r_emblem.png'), context);
      precacheImage(const AssetImage('assets/images/p5r_emblem.png'), context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromBackground();
    }
  }

  Future<void> _syncFromBackground() async {
    await widget.store.refreshNotificationAccess();
    final added = await widget.store.syncPendingNotifications();
    if (added.isNotEmpty && mounted) {
      _announceAutoCaptured(added);
    }
  }

  Future<void> _handleLiveNotification(RawFinanceNotification raw) async {
    final added = await widget.store.ingestRawNotifications([raw]);
    if (added.isNotEmpty && mounted) {
      _announceAutoCaptured(added);
    }
  }

  void _announceAutoCaptured(List<TransactionItem> added) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final message = added.length == 1
        ? 'Auto-catat: ${added.first.type == TransactionType.income ? '+' : '-'}${formatRupiah(added.first.amount)} via ${widget.store.walletById(added.first.walletId)?.name ?? added.first.walletId}'
        : 'Auto-catat ${added.length} transaksi baru dari notifikasi.';
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.notificationBridge.clearLiveListener();
    _pageController.dispose();
    _enterController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _triggerThemeToggle() async {
    if (_isTransitioning) return;
    final next = widget.store.themePreset == PersonaThemePreset.tatsumi
        ? PersonaThemePreset.shibuya
        : PersonaThemePreset.tatsumi;

    if (MediaQuery.disableAnimationsOf(context)) {
      await widget.store.setThemePreset(next);
      return;
    }

    _isTransitioning = true;
    _enterController.value = 0;
    _exitController.value = 0;
    setState(() {
      _targetPreset = next;
      _wipeVisible = true;
    });

    try {
      // Phase 1: Slide curtain smoothly in while old theme stays untouched.
      await _enterController.forward(from: 0);
      if (!mounted) return;

      // Phase 2: Swap theme completely behind the stationary curtain and let
      // Flutter finish layout + GPU rasterization before exit begins.
      await widget.store.setThemePreset(next);
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;

      // Phase 3: Slide curtain smoothly out from clean frame 0.
      await _exitController.forward(from: 0);
    } finally {
      if (mounted) {
        setState(() => _wipeVisible = false);
      }
      _isTransitioning = false;
    }
  }

  void _openPrimaryAction() {
    HapticFeedback.lightImpact();
    if (_tabIndex == 2) {
      DebtEditorSheet.show(context, store: widget.store);
    } else {
      TransactionEditorSheet.show(context, store: widget.store);
    }
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = index);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final fab = FloatingActionButton.extended(
      onPressed: _openPrimaryAction,
      backgroundColor: tokens.accent,
      foregroundColor: tokens.onAccent,
      elevation: 2,
      shape: isP5
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tokens.ink.withOpacity(0.9), width: 1.5),
            )
          : BeveledRectangleBorder(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
              side: BorderSide(
                color: tokens.accentSecondary.withOpacity(0.75),
                width: 1.2,
              ),
            ),
      icon: isP5
          ? const PersonaStarIcon(
              size: 18,
              color: Colors.white,
              outlineColor: Color(0xFF19191E),
            )
          : const Icon(Icons.add_rounded),
      label: AnimatedSwitcher(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: Text(
          _tabIndex == 2 ? 'Catat Patungan' : 'Catat',
          key: ValueKey(_tabIndex == 2),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.onAccent,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          body: StationeryCanvasBackground(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: widget.store.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : PageView(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          onPageChanged: (index) {
                            if (index != _tabIndex) {
                              HapticFeedback.selectionClick();
                              setState(() => _tabIndex = index);
                            }
                          },
                          children: [
                            HomeScreen(
                              key: const ValueKey('tab_home'),
                              store: widget.store,
                              onToggleTheme: _triggerThemeToggle,
                            ),
                            AnalyticsScreen(
                              key: const ValueKey('tab_analytics'),
                              store: widget.store,
                            ),
                            DebtsScreen(
                              key: const ValueKey('tab_debts'),
                              store: widget.store,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          floatingActionButton: isP5
              ? Transform.rotate(angle: -0.025, child: fab)
              : fab,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(
                top: BorderSide(
                  color: isP5 ? tokens.ink.withOpacity(0.28) : tokens.border,
                  width: 1.2,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: _tabIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: tokens.accentSoft,
                indicatorShape: isP5
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: tokens.accent.withOpacity(0.55),
                          width: 1.1,
                        ),
                      )
                    : const BeveledRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _selectTab,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.book_outlined, color: tokens.inkMuted),
                    selectedIcon:
                        Icon(Icons.book_rounded, color: tokens.accent),
                    label: 'Beranda',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.donut_small_outlined,
                      color: tokens.inkMuted,
                    ),
                    selectedIcon:
                        Icon(Icons.donut_small_rounded, color: tokens.accent),
                    label: 'Ringkasan',
                  ),
                  NavigationDestination(
                    icon:
                        Icon(Icons.handshake_outlined, color: tokens.inkMuted),
                    selectedIcon:
                        Icon(Icons.handshake_rounded, color: tokens.accent),
                    label: 'Patungan',
                  ),
                ],
              ),
            ),
          ),
        ),
        PersonaThemeSlashOverlay(
          visible: _wipeVisible,
          enterAnimation: _enterController,
          exitAnimation: _exitController,
          targetPreset: _targetPreset,
        ),
      ],
    );
  }
}
