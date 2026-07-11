import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/manifest_model.dart';
import '../theme/app_theme.dart';

/// Vehicle seat layout with each booked seat labelled by its occupant's
/// nickname (or first name). Tap a taken seat for the full details.
class SeatMapPanel extends StatelessWidget {
  final SeatMap seatMap;

  const SeatMapPanel({super.key, required this.seatMap});

  @override
  Widget build(BuildContext context) {
    final frontSeat = seatMap.frontSeat == null
        ? null
        : seatMap.seatById(seatMap.frontSeat!);
    final rows = _seatRows(seatMap);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.airline_seat_recline_normal_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'แผนผังที่นั่ง',
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              Text(
                'นั่งแล้ว ${seatMap.occupied}/${seatMap.total}',
                style: GoogleFonts.anuphan(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        frontSeat == null
                            ? const SizedBox(width: 64)
                            : _SeatTile(seat: frontSeat),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            seatMap.frontLabel,
                            style: GoogleFonts.anuphan(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (seatMap.showDriver)
                          const _DriverBlock()
                        else
                          const SizedBox(width: 64),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(width: 300, child: Divider(height: 1)),
                    ),
                    ...rows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SeatRow(row: row, seatMap: seatMap),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverBlock extends StatelessWidget {
  const _DriverBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.textMuted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.airline_seat_recline_extra_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 2),
          Text(
            'คนขับ',
            style: GoogleFonts.anuphan(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final _SeatRowData row;
  final SeatMap seatMap;

  const _SeatRow({required this.row, required this.seatMap});

  @override
  Widget build(BuildContext context) {
    Widget seats(List<String> ids) => Row(
      mainAxisSize: MainAxisSize.min,
      children: ids.map((id) {
        final seat = seatMap.seatById(id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: seat == null
              ? const SizedBox(width: 64, height: 54)
              : _SeatTile(seat: seat),
        );
      }).toList(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seats(row.left),
        if (row.center.isNotEmpty) ...[
          const SizedBox(width: 6),
          seats(row.center),
        ],
        SizedBox(
          width: 36,
          child: Center(
            child: row.hasAisle
                ? Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
        ),
        seats(row.right),
      ],
    );
  }
}

class _SeatTile extends StatelessWidget {
  final Seat seat;

  const _SeatTile({required this.seat});

  @override
  Widget build(BuildContext context) {
    final occupant = seat.occupant;
    final occupied = occupant != null;
    final checkedIn = occupant?.checkedIn ?? false;
    final display = occupant?.shortLabel ?? '';
    final accent = checkedIn ? AppTheme.successColor : AppTheme.primaryColor;

    return GestureDetector(
      onTap: occupied ? () => _showSeatDetail(context, seat.label, occupant) : null,
      child: Container(
        width: 64,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: occupied
              ? accent.withValues(alpha: 0.10)
              : AppTheme.textMuted.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: occupied
                ? accent.withValues(alpha: 0.45)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  seat.label,
                  style: GoogleFonts.anuphan(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: occupied ? accent : AppTheme.textSecondary,
                  ),
                ),
                if (checkedIn) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 10,
                    color: AppTheme.successColor,
                  ),
                ],
              ],
            ),
            if (occupied)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  display.isEmpty ? '—' : display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSeatDetail(BuildContext context, String label, SeatOccupant occupant) {
    final name = occupant.name.trim().isEmpty ? '-' : occupant.name;
    final nickname = occupant.nickname?.trim() ?? '';
    final ref = occupant.bookingRef?.trim() ?? '';
    final checkedIn = occupant.checkedIn;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ที่นั่ง $label',
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      checkedIn
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                      color: checkedIn
                          ? AppTheme.successColor
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkedIn ? 'เช็กอินแล้ว' : 'ยังไม่เช็กอิน',
                      style: GoogleFonts.anuphan(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: checkedIn
                            ? AppTheme.successColor
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              nickname.isEmpty ? name : '$name ($nickname)',
              style: GoogleFonts.anuphan(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            if (ref.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                ref,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Per-row seat arrangement, derived from the layout's columns + aisle markers.
class _SeatRowData {
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _SeatRowData({
    required this.left,
    required this.right,
    required this.center,
    required this.hasAisle,
  });
}

List<_SeatRowData> _seatRows(SeatMap seatMap) {
  final centerSeatIds = seatMap.lastRowCenter.toSet();
  final result = <_SeatRowData>[];

  for (var rowIndex = 1; rowIndex <= seatMap.rows; rowIndex++) {
    final left = <String>[];
    final right = <String>[];
    final center = <String>[];
    var hasAisle = false;
    var inRight = false;

    for (final column in seatMap.columns) {
      if (column.isEmpty) {
        hasAisle = true;
        inRight = true;
        continue;
      }

      final seatId = '$column$rowIndex';
      if (seatId == seatMap.frontSeat) continue;
      if (seatMap.seatById(seatId) == null) continue;

      if (centerSeatIds.contains(seatId)) {
        center.add(seatId);
      } else if (inRight) {
        right.add(seatId);
      } else {
        left.add(seatId);
      }
    }

    if (left.isEmpty && right.isEmpty && center.isEmpty) continue;

    result.add(
      _SeatRowData(
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}
