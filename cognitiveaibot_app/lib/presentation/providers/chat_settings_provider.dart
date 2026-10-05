import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/usecases/usecase.dart';
import '../../domain/usecases/delete_conversation.dart';
import 'providers.dart';

/// Chat settings state
class ChatSettings {
  const ChatSettings({
    this.darkMode = true,
    this.fontSize = 16,
    this.enterToSend = true,
    this.showTimestamps = false,
    this.readResponsesAloud = false,
    this.aiVoiceModel = 'Nova (Female, Professional)',
    this.systemPrompt = '',
    this.temperature = 0.7,
    this.pushNotifications = true,
    this.newAiModels = true,
    this.featureUpdates = false,
    this.tokenThresholds = const {80, 100},
    this.invoicesReceipts = true,
    this.paymentIssues = false,
    this.aiTrendsNews = false,
  });

  final bool darkMode;
  final double fontSize;
  final bool enterToSend;
  final bool showTimestamps;
  final bool readResponsesAloud;
  final String aiVoiceModel;
  final String systemPrompt;
  final double temperature;
  final bool? pushNotifications;
  final bool? newAiModels;
  final bool? featureUpdates;
  final Set<int>? tokenThresholds;
  final bool? invoicesReceipts;
  final bool? paymentIssues;
  final bool? aiTrendsNews;

  ChatSettings copyWith({
    bool? darkMode,
    double? fontSize,
    bool? enterToSend,
    bool? showTimestamps,
    bool? readResponsesAloud,
    String? aiVoiceModel,
    String? systemPrompt,
    double? temperature,
    bool? pushNotifications,
    bool? newAiModels,
    bool? featureUpdates,
    Set<int>? tokenThresholds,
    bool? invoicesReceipts,
    bool? paymentIssues,
    bool? aiTrendsNews,
  }) {
    return ChatSettings(
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      enterToSend: enterToSend ?? this.enterToSend,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      readResponsesAloud: readResponsesAloud ?? this.readResponsesAloud,
      aiVoiceModel: aiVoiceModel ?? this.aiVoiceModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      pushNotifications: pushNotifications ?? this.pushNotifications ?? true,
      newAiModels: newAiModels ?? this.newAiModels ?? true,
      featureUpdates: featureUpdates ?? this.featureUpdates ?? false,
      tokenThresholds: tokenThresholds ?? this.tokenThresholds ?? const {80, 100},
      invoicesReceipts: invoicesReceipts ?? this.invoicesReceipts ?? true,
      paymentIssues: paymentIssues ?? this.paymentIssues ?? false,
      aiTrendsNews: aiTrendsNews ?? this.aiTrendsNews ?? false,
    );
  }
}

class ChatSettingsNotifier extends StateNotifier<ChatSettings> {
  ChatSettingsNotifier(this._ref) : super(const ChatSettings());

  final Ref _ref;

  void setDarkMode(bool v) => state = state.copyWith(darkMode: v);
  void setFontSize(double v) => state = state.copyWith(fontSize: v);
  void setEnterToSend(bool v) => state = state.copyWith(enterToSend: v);
  void setShowTimestamps(bool v) => state = state.copyWith(showTimestamps: v);
  void setReadResponsesAloud(bool v) =>
      state = state.copyWith(readResponsesAloud: v);
  void setAiVoiceModel(String v) => state = state.copyWith(aiVoiceModel: v);
  void setSystemPrompt(String v) => state = state.copyWith(systemPrompt: v);
  void setTemperature(double v) => state = state.copyWith(temperature: v);
  void setPushNotifications(bool v) =>
      state = state.copyWith(pushNotifications: v);
  void setNewAiModels(bool v) => state = state.copyWith(newAiModels: v);
  void setFeatureUpdates(bool v) => state = state.copyWith(featureUpdates: v);
  void toggleTokenThreshold(int threshold) {
    final current = Set<int>.from(state.tokenThresholds ?? const {80, 100});
    if (current.contains(threshold)) {
      current.remove(threshold);
    } else {
      current.add(threshold);
    }
    state = state.copyWith(tokenThresholds: current);
  }
  void setInvoicesReceipts(bool v) =>
      state = state.copyWith(invoicesReceipts: v);
  void setPaymentIssues(bool v) => state = state.copyWith(paymentIssues: v);
  void setAiTrendsNews(bool v) => state = state.copyWith(aiTrendsNews: v);

  Future<void> clearAllConversations() async {
    final result =
        await _ref.read(getConversationsProvider).call(const NoParams());
    switch (result) {
      case Success(:final data):
        for (final list in data.values) {
          for (final conv in list) {
            await _ref
                .read(deleteConversationProvider)
                .call(DeleteConversationParams(conversationId: conv.id));
          }
        }
      case FailureResult():
        break;
    }
  }
}

final chatSettingsProvider =
    StateNotifierProvider<ChatSettingsNotifier, ChatSettings>((ref) {
  return ChatSettingsNotifier(ref);
});
