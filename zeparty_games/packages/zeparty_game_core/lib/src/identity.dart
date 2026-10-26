/// Identity handed to the games by the ZeParty host application.
///
/// Games never create accounts. The host authenticates the user and passes the
/// resulting token; the games backend verifies it with the shared adapter.
class ZePartyIdentity {
  const ZePartyIdentity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.roles = const [],
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final List<String> roles;

  factory ZePartyIdentity.fromJson(Map<String, dynamic> json) => ZePartyIdentity(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'roles': roles,
      };
}

/// Authenticated session: identity plus the bearer token the backend accepts.
class ZePartySession {
  const ZePartySession({required this.identity, required this.authToken});
  final ZePartyIdentity identity;
  final String authToken;
}
