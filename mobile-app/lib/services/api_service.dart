import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.nextconnect.com';

  final http.Client client = http.Client();

  // TODO: login, pair/register, pair/confirm, pair/poll endpoints
}