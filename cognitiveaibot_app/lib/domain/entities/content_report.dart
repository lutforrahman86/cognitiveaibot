/// Why a reply is reported (`POST /api/reports`).
enum ReportReason {
  harmful('Harmful or dangerous'),
  sexual('Sexual content'),
  hateful('Hateful or harassing'),
  violent('Violent'),
  illegal('Illegal'),
  inaccurate('Inaccurate or misleading'),
  other('Something else');

  const ReportReason(this.label);

  /// Shown in the reason picker. The enum's [name] is what the server takes.
  final String label;
}
