import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/risk_levels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/drive_session_model.dart';
import '../../driving/screens/driving_detection_screen.dart';

/// หน้า Home
/// หน้า 4 = ยังไม่เริ่มขับ
/// หน้า 5 = กำลังขับ
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // =========================
  // Firebase User Name
  // =========================

  String _userName = 'กำลังโหลด...';

  // =========================
  // Driving Session
  // =========================

  DriveSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  // =========================
  // Load Name From Firestore
  // =========================

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _userName = 'ผู้ใช้';
      });

      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();

        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';

        final fullName = '$firstName $lastName'.trim();

        setState(() {
          _userName = fullName.isEmpty ? 'ผู้ใช้' : fullName;
        });
      } else {
        // ถ้าไม่มีข้อมูลใน Firestore
        setState(() {
          _userName = user.displayName ?? 'ผู้ใช้';
        });
      }
    } catch (e) {
      if (!mounted) return;

      // ถ้าอ่าน Firestore ไม่สำเร็จ
      // ใช้ชื่อจาก Firebase Authentication แทน
      setState(() {
        _userName = user.displayName ?? 'ผู้ใช้';
      });
    }
  }

  // =========================
  // Start Driving
  // =========================

  Future<void> _startDriving() async {
    final result = await Navigator.push<DriveSession>(
      context,
      MaterialPageRoute(
        builder: (_) => const DrivingDetectionScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _activeSession = result;
      });
    }
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    final session = _activeSession;

    final isActive = session != null;

    final alertnessScore = session?.alertnessScore ?? 0;

    final riskScore = session?.currentRiskScore ?? 15;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // User Name
            // =========================

            Text(
              'สวัสดี $_userName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),

            const Text(
              'การเดินทางของคุณ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.notifications_none,
            ),
          ),
        ],
      ),

      // =========================
      // Body
      // =========================

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // Main Status
          // =========================

          _MainStatusCard(
            isActive: isActive,
            alertnessScore: alertnessScore,
            riskScore: riskScore,
            onTap: isActive ? null : _startDriving,
          ),

          const SizedBox(height: 16),

          // =========================
          // Driving Metrics
          // =========================

          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.speed,
                  value: isActive ? session.speedKmh.toStringAsFixed(0) : '--',
                  unit: 'กม./ชม.',
                  label: 'ความเร็วเฉลี่ย',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.route,
                  value:
                      isActive ? session.distanceKm.toStringAsFixed(1) : '--',
                  unit: 'กม.',
                  label: 'ระยะทาง',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.access_time,
                  value: isActive ? '${session.elapsed.inMinutes}' : '--',
                  unit: 'นาที',
                  label: 'เวลาขับขี่',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // =========================
          // Risk Level
          // =========================

          const Text(
            'ระดับความเสี่ยง (Drowsiness Risk)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              for (final info in RiskLevels.all)
                Expanded(
                  child: _RiskLevelChip(
                    info: info,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // =========================
          // Rest Message
          // =========================

          if (!isActive)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.creamButton,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.self_improvement,
                    color: AppColors.creamButtonText,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'พักสติเมื่อรู้สึกล้า',
                      style: TextStyle(
                        color: AppColors.creamButtonText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Main Status Card
// ============================================================

class _MainStatusCard extends StatelessWidget {
  final bool isActive;
  final double alertnessScore;
  final double riskScore;
  final VoidCallback? onTap;

  const _MainStatusCard({
    required this.isActive,
    required this.alertnessScore,
    required this.riskScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // =========================
            // Status Pills
            // =========================

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatusPill(
                  icon: Icons.camera_alt_outlined,
                  label: 'AI ตรวจจับ',
                ),
                _StatusPill(
                  icon: Icons.bluetooth,
                  label: 'BT เชื่อมต่อแล้ว',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =========================
            // Alertness Circle
            // =========================

            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value:
                          isActive ? (alertnessScore / 100).clamp(0, 1) : 0.15,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.ringActive,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Text(
                          alertnessScore.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const Text(
                          'เริ่มต้น',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const Text(
                        'ความตื่นตัว',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // Drowsiness Risk
            // =========================

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Drowsiness Risk',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${riskScore.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (riskScore / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.ringActive,
                ),
              ),
            ),

            const SizedBox(height: 6),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '● ปกติ • ขับได้อย่างปลอดภัย',
                style: TextStyle(
                  color: AppColors.ringActive,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Status Pill
// ============================================================

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Metric Card
// ============================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          Text(
            '$value $unit',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Risk Level Chip
// ============================================================

class _RiskLevelChip extends StatelessWidget {
  final RiskLevelInfo info;

  const _RiskLevelChip({
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: info.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 4,
              backgroundColor: info.color,
            ),
            const SizedBox(height: 4),
            Text(
              info.rangeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: info.color,
              ),
            ),
            Text(
              info.nameLabel,
              style: const TextStyle(
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
