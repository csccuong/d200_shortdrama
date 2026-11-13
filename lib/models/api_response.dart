/// Generic envelope for every API response from the DXX platform.
///
/// The `code` mirrors the HTTP status, `message` carries server-side info,
/// and `data` holds the typed payload after decryption.
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    this.message = '',
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? 200,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
    );
  }

  bool get isSuccess => code >= 200 && code < 300;
  bool get isPaywall => code == 402;
}
