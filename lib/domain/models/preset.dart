class Preset {
  final String name;
  final String subtitle;
  final String details;
  final int hz;
  final int pwm;
  final int durationSeconds;
  final int iconCodePoint;
  final int waveform; // 0: Square, 1: Triangular, 2: Trapezoidal, 3: Burst

  const Preset({
    required this.name,
    required this.subtitle,
    required this.details,
    required this.hz,
    required this.pwm,
    required this.durationSeconds,
    required this.iconCodePoint,
    required this.waveform,
  });
}
