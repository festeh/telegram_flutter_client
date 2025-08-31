import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../data/repositories/tdlib_telegram_client.dart';

// Shared Telegram client instance
final telegramClientProvider = Provider<TelegramClientRepository>((ref) {
  return TdlibTelegramClient();
});