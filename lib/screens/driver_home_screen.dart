import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import 'manifest_screen.dart';
import 'map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchDriverContext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final user = provider.driverUser ?? const <String, dynamic>{};
        final selected = provider.selectedSchedule;

        return Scaffold(
          backgroundColor: AppTheme.bgLight,
          appBar: AppBar(
            title: const Text('งานขับรถวันนี้'),
            actions: [
              IconButton(
                tooltip: 'รีเฟรช',
                onPressed: provider.fetchDriverContext,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'ออกจากระบบ',
                onPressed: provider.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: provider.fetchDriverContext,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                _DriverHeader(user: user),
                const SizedBox(height: 18),
                if (provider.isLoadingSchedules)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.todaySchedules.isEmpty)
                  const _EmptyTrips()
                else ...[
                  Text(
                    'เลือกรอบเดินทาง',
                    style: GoogleFonts.anuphan(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final trip in provider.todaySchedules) ...[
                    _ScheduleCard(
                      trip: trip,
                      selected: selected?.id == trip.id,
                      onTap: () => provider.selectSchedule(trip),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
          bottomNavigationBar: selected == null
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 20,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await provider.startTrip();
                              if (!mounted) return;
                              if (success) {
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => const MapScreen(),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(provider.statusMessage),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('เริ่มติดตาม'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ManifestScreen(schedule: selected),
                                ),
                              );
                            },
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('รายชื่อผู้โดยสาร'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final Map<String, dynamic> user;

  const _DriverHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'คนขับ';
    final phone = user['phone']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isEmpty ? 'พร้อมรับงานขับรถ' : phone,
                  style: GoogleFonts.anuphan(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Trip trip;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = trip.confirmedBookingsCount;
    final checked = trip.checkedInBookingsCount;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.accentColor : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? AppTheme.activeShadow : AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentColor,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.directions_bus_rounded,
                text: [
                  if ((trip.vehicleName ?? '').isNotEmpty) trip.vehicleName!,
                  if ((trip.licensePlate ?? '').isNotEmpty) trip.licensePlate!,
                ].join(' · '),
              ),
              const SizedBox(height: 6),
              _InfoLine(
                icon: Icons.location_on_rounded,
                text: trip.departurePoint.isEmpty
                    ? 'จุดนัดพบตามรายละเอียดทริป'
                    : trip.departurePoint,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total <= 0 ? 0 : checked / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: const Color(0xFFE5E7EB),
                color: AppTheme.successColor,
              ),
              const SizedBox(height: 8),
              Text(
                'เช็กอินแล้ว $checked/$total รายการ',
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 56,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'ยังไม่มีทริปที่ผูกกับบัญชีนี้',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ให้แอดมิน assign คนขับในรอบเดินทาง หรือใส่เบอร์คนขับให้ตรงกับเบอร์บัญชีนี้',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
