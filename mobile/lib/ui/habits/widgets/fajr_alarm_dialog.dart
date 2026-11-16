import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Non-dismissible cognitive alarm dialog that requires solving
/// a mental arithmetic challenge before the alarm can be turned off.
class FajrAlarmDialog extends StatefulWidget {
  const FajrAlarmDialog({
    super.key,
    required this.onAlarmDismissed,
  });

  final VoidCallback onAlarmDismissed;

  @override
  State<FajrAlarmDialog> createState() => _FajrAlarmDialogState();
}

class _FajrAlarmDialogState extends State<FajrAlarmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late int _num1;
  late int _num2;
  late int _expectedAnswer;
  String _userAnswer = '';
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _generateChallenge();
  }

  void _generateChallenge() {
    final rand = Random();
    // Generates two 2-digit numbers that sum to < 100
    _num1 = 15 + rand.nextInt(35);
    _num2 = 12 + rand.nextInt(40);
    _expectedAnswer = _num1 + _num2;
    _userAnswer = '';
    _errorMessage = null;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isSuccess) return;
    if (_userAnswer.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _userAnswer += digit;
      _errorMessage = null;
    });
  }

  void _onClearPressed() {
    if (_isSuccess) return;
    HapticFeedback.selectionClick();
    setState(() {
      _userAnswer = '';
      _errorMessage = null;
    });
  }

  void _onSubmit() {
    if (_isSuccess) return;
    final parsed = int.tryParse(_userAnswer);

    if (parsed == _expectedAnswer) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSuccess = true;
        _errorMessage = null;
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          widget.onAlarmDismissed();
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = context.isArabic
            ? 'إجابة غير صحيحة. احسب مجدداً للاستيقاظ!'
            : 'Incorrect answer. Calculate again to wake up!';
        _userAnswer = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF508111D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSuccess
                ? AxisColors.success
                : const Color(0xFFEF4444).withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isSuccess ? AxisColors.success : const Color(0xFFEF4444))
                  .withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alarm Status Pulse Indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_isSuccess
                                ? AxisColors.success
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isSuccess
                              ? AxisColors.success
                              : const Color(0xFFEF4444),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.alarm_on_rounded,
                        size: 28,
                        color: _isSuccess
                            ? AxisColors.success
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Alarm Title
              Text(
                _isSuccess
                    ? (context.isArabic ? 'مستيقظ ومستعد' : 'AWAKE AND READY')
                    : (context.isArabic ? 'مهمة الاستيقاظ لصلاة الفجر' : 'FAJR WAKE-UP MISSION'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isSuccess ? AxisColors.success : Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.isArabic ? 'الصلاة خير من النوم' : 'As-Salatu Khayrun Minan-Nawm',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AxisColors.secondary,
                ),
              ),
              Text(
                context.isArabic ? 'الصلاة خير من النوم' : 'Prayer is better than sleep',
                style: const TextStyle(
                  fontSize: 10,
                  color: AxisColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              // Instruction Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        size: 15, color: AxisColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isSuccess
                            ? (context.isArabic
                                ? 'تم التحقق بنجاح! تم إيقاف المنبه.'
                                : 'Verification passed! Alarm stopping.')
                            : (context.isArabic
                                ? 'قم بحل المسألة الحسابية لإيقاف المنبه:'
                                : 'Solve arithmetic problem to dismiss alarm:'),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Mental Arithmetic Question Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1726),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isSuccess
                        ? AxisColors.success
                        : AxisColors.borderPrimary,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_num1  +  $_num2  =  ?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 32,
                      width: 130,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _errorMessage != null
                              ? const Color(0xFFEF4444)
                              : AxisColors.secondary.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        _userAnswer.isEmpty
                            ? (context.isArabic ? 'اكتب الإجابة' : 'Tap answer')
                            : _userAnswer,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _userAnswer.isEmpty
                              ? AxisColors.textDim
                              : AxisColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Number Pad Grid (1 through 9, Clear, 0, Submit)
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    _buildNumpadRow(['1', '2', '3']),
                    const SizedBox(height: 6),
                    _buildNumpadRow(['4', '5', '6']),
                    const SizedBox(height: 6),
                    _buildNumpadRow(['7', '8', '9']),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumpadButton(
                            label: 'C',
                            color: const Color(0xFFEF4444),
                            onTap: _onClearPressed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildNumpadButton(
                            label: '0',
                            onTap: () => _onDigitPressed('0'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildNumpadButton(
                            label: context.isArabic ? 'موافق' : 'OK',
                            color: AxisColors.success,
                            onTap: _onSubmit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Emergency direct Stop Alarm button to guarantee user control
              TextButton.icon(
                key: const ValueKey('stop_fajr_alarm_button'),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onAlarmDismissed();
                  Navigator.of(context, rootNavigator: true).pop();
                },
                icon: const Icon(Icons.alarm_off_rounded, size: 15, color: Color(0xFFEF4444)),
                label: Text(
                  context.isArabic ? 'إيقاف المنبه' : 'Stop Alarm',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      children: digits.map((d) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumpadButton(
              label: d,
              onTap: () => _onDigitPressed(d),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isCustomColor = color != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('numpad_$label'),
        onTap: _isSuccess ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCustomColor
                ? color.withValues(alpha: 0.2)
                : AxisColors.surfaceHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCustomColor ? color : AxisColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isCustomColor ? color : AxisColors.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}
