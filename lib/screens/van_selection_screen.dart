import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';

class VanSelectionScreen extends StatefulWidget {
  const VanSelectionScreen({super.key});

  @override
  State<VanSelectionScreen> createState() => _VanSelectionScreenState();
}

class _VanSelectionScreenState extends State<VanSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchVans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          'ลุยเลเขา ไดรเวอร์',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<TripProvider>().fetchVans(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingVans && provider.availableVans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(provider),
              Expanded(
                child: provider.selectedVan == null
                    ? _buildVanPicker(provider)
                    : _buildSchedulePicker(provider),
              ),
              _buildStartButton(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(TripProvider provider) {
    final hasVan = provider.selectedVan != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasVan
                      ? Icons.check_circle_rounded
                      : Icons.airport_shuttle_rounded,
                  color: AppTheme.accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVan ? 'เลือกสเกตจูวล์เดินทาง' : 'เลือกรถของคุณ',
                    style: AppTheme.lightTheme.textTheme.headlineMedium,
                  ),
                  Text(
                    hasVan
                        ? 'โปรดเลือกรอบเดินทางที่วางแผนไว้สำหรับวันนี้'
                        : 'กรุณาเลือกรถตู้ที่คุณกำลังขับในวันนี้',
                    style: AppTheme.lightTheme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
          if (hasVan) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => provider.selectVan(
                provider.selectedVan!,
              ), // Refresh schedules or toggle back
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textMuted.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.airport_shuttle_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      provider.selectedVan!.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => provider
                          .fetchVans(), // Actually we want to reset selection here maybe
                      child: const Text('เปลี่ยนรถ'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVanPicker(TripProvider provider) {
    if (provider.availableVans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bus_alert_rounded,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูลรถในระบบ',
              style: AppTheme.lightTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.availableVans.length,
      itemBuilder: (context, index) {
        final van = provider.availableVans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => provider.selectVan(van),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.airport_shuttle_rounded,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          van.name,
                          style: AppTheme.lightTheme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_rounded,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              van.licensePlate,
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${van.capacity} ที่นั่ง',
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSchedulePicker(TripProvider provider) {
    if (provider.isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.todaySchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text('วันนี้ยังไม่มีรอบเดินทางสำหรับรถคันนี้'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.selectVan(provider.selectedVan!),
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.todaySchedules.length,
      itemBuilder: (context, index) {
        final schedule = provider.todaySchedules[index];
        final isSelected = provider.selectedSchedule?.id == schedule.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => provider.selectSchedule(schedule),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor.withValues(alpha: 0.05)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? AppTheme.activeShadow
                    : AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                schedule.status.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.event_rounded,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule.departureDate,
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          schedule.title,
                          style: AppTheme.lightTheme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule.departurePoint,
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'จองแล้ว ${schedule.bookedSeats}/${schedule.totalSeats}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentColor,
                      size: 32,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartButton(TripProvider provider) {
    final canStart = provider.selectedSchedule != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: canStart
            ? () async {
                final success = await provider.startTrip();
                if (success && mounted) {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.statusMessage),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.textMuted.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_rounded),
            const SizedBox(width: 12),
            Text(
              'เริ่มออกเดินทาง',
              style: GoogleFonts.anuphan(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
