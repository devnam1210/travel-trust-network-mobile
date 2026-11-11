class SessionTokens {
  const SessionTokens({required this.accessToken, this.refreshToken});

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String ||
        access.trim().isEmpty ||
        (refresh != null && (refresh is! String || refresh.trim().isEmpty))) {
      throw const FormatException('Invalid session credentials');
    }
    return SessionTokens(accessToken: access, refreshToken: refresh as String?);
  }

  final String accessToken;
  final String? refreshToken;
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
  };
}
