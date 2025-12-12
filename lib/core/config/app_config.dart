/// Centralized configuration constants for the application.
///
/// All magic numbers, timing constants, and tunable parameters
/// should be defined here for easy adjustment and clarity.
abstract class AppConfig {
  // ===== Timing - TDLib polling and delays =====

  /// How often to poll TDLib for updates
  static const updatePollingInterval = Duration(seconds: 1);

  /// Delay after requesting chats to allow updates to arrive
  static const chatLoadDelay = Duration(milliseconds: 500);

  /// Delay when fetching a single chat
  static const singleChatFetchDelay = Duration(milliseconds: 200);

  /// Delay after requesting messages to allow them to arrive
  static const messageLoadDelay = Duration(milliseconds: 800);

  /// Delay between retry attempts
  static const retryDelay = Duration(milliseconds: 100);

  // ===== Pagination =====

  /// Number of chats to load per page
  static const chatPageSize = 50;

  /// Number of messages to load per request
  static const messagePageSize = 50;

  /// Maximum retry attempts for loading messages
  static const messageLoadRetries = 5;

  // ===== Cache limits =====

  /// Minimum messages to keep cached per chat
  static const minCachedMessages = 30;

  /// Maximum messages to keep cached per chat
  static const maxMessagesPerChat = 100;
}
