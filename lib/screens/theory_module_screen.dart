import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../models/traffic_rule_topic.dart';
import '../providers/content_provider.dart';
import '../providers/progress_provider.dart';
import 'traffic_rule_content_screen.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_result_parts.dart';

class TheoryModuleScreen extends StatefulWidget {
  final TheoryModule module;

  const TheoryModuleScreen({
    Key? key,
    required this.module,
  }) : super(key: key);

  @override
  _TheoryModuleScreenState createState() => _TheoryModuleScreenState();
}

class _TheoryModuleScreenState extends State<TheoryModuleScreen> {
  List<TrafficRuleTopic> _moduleTopics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
    });

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    print('TheoryModuleScreen: Loading topics for module ${widget.module.id}');
    print('Module topics: ${widget.module.topics}');
    print('Module state: ${widget.module.state}, language: ${widget.module.language}');
    
    // ENHANCEMENT: Pre-warm topics for this module to improve performance
    try {
      await contentProvider.preWarmTopicsForModule(widget.module);
    } catch (e) {
      print('Warning: Pre-warming failed, continuing with normal loading: $e');
    }
    
    // Using the topics from the provider
    final allTopics = contentProvider.topics;
    
    // Get module topics list using the helper method to handle both string and list
    final topicsList = widget.module.getTopicsList();
    
    // Filter topics based on the topics listed in the module
    final filteredTopics = <TrafficRuleTopic>[];
    
    // 🔧 FIX: If module topics array is empty, match by ID pattern
    if (topicsList.isEmpty && allTopics.isNotEmpty) {
      print('Module topics array is empty, attempting to match by ID pattern...');
      
      // Extract number from module ID: traffic_rules_en_IL_01 → 01 → 1
      final moduleIdParts = widget.module.id.split('_');
      if (moduleIdParts.length >= 4) {
        final moduleNumber = moduleIdParts.last;
        final topicNumber = moduleNumber.replaceAll(RegExp(r'^0+'), ''); // Remove leading zeros: 01 → 1
        
        print('Extracted module number: $moduleNumber → topic number: $topicNumber');
        print('Looking for topic with ID: $topicNumber, state: ${widget.module.state}, language: ${widget.module.language}');
        
        // Find THE matching topic with same ID, state, and language
        try {
          final matchingTopic = allTopics.firstWhere(
            (t) => t.id == topicNumber && 
                   (t.state == widget.module.state || t.state == 'ALL') && 
                   t.language == widget.module.language,
          );
          
          print('✅ Successfully matched topic: ${matchingTopic.id} - ${matchingTopic.title}');
          filteredTopics.add(matchingTopic);
        } catch (e) {
          print('❌ Could not find matching topic for module ${widget.module.id}');
          print('Available topic IDs: ${allTopics.map((t) => "${t.id}(${t.state},${t.language})").take(5).join(", ")}...');
        }
      }
    } else {
      // Original logic: First try to match topics from the ones already loaded in memory
      for (var topicId in topicsList) {
        print('Looking for topic ID: $topicId');
        
        // Try multiple ways to match the topic ID
        TrafficRuleTopic? topic;
        try {
          topic = allTopics.firstWhere(
            (t) => t.id == topicId || 
                   t.id == topicId.replaceAll('topic_', '') || 
                   'topic_${t.id}' == topicId,
          );
          print('Found topic in memory: ${topic.id} - ${topic.title}');
          filteredTopics.add(topic);
        } catch (e) {
          print('Topic not found in memory, fetching from database: $topicId');
          // If topic not found in memory, try to fetch it directly
          final fetchedTopic = await contentProvider.getTopicById(topicId);
          if (fetchedTopic != null) {
            print('Successfully fetched topic: ${fetchedTopic.id} - ${fetchedTopic.title}');
            filteredTopics.add(fetchedTopic);
          } else {
            print('Failed to fetch topic: $topicId');
          }
        }
      }
    }
    
    // If we still don't have any topics and the content provider has topics,
    // try to match by state and language
    if (filteredTopics.isEmpty && allTopics.isNotEmpty) {
      print('No direct topic matches found. Trying to filter by state and language...');
      filteredTopics.addAll(allTopics.where((topic) => 
        (topic.state == widget.module.state || topic.state == 'ALL') && 
        topic.language == widget.module.language &&
        topic.licenseId == widget.module.licenseId
      ).toList());
      
      print('Found ${filteredTopics.length} topics by filtering');
    }
    
    // Sort by order
    filteredTopics.sort((a, b) => a.order.compareTo(b.order));
    
    setState(() {
      _moduleTopics = filteredTopics;
      _isLoading = false;
    });
    
    print('Loaded ${_moduleTopics.length} topics for module ${widget.module.id}');
    
    // 🚀 AUTO-NAVIGATE: If there's only 1 topic, go directly to content
    // (This should now be rare since TheoryScreen handles it directly)
    if (_moduleTopics.length == 1 && mounted) {
      print('📍 Auto-navigating to single topic: ${_moduleTopics[0].title}');
      // Use immediate navigation without post-frame callback to reduce flash
      Future.microtask(() {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrafficRuleContentScreen(topic: _moduleTopics[0], moduleId: widget.module.id),
            ),
          );
        }
      });
    }
  }

  /// Opens a topic. Moved unchanged from the row's inline `onTap`.
  void _openTopic(TrafficRuleTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrafficRuleContentScreen(topic: topic, moduleId: widget.module.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A pushed screen: the round back button with the module's name beside
    // it, one line, shrinking rather than wrapping.
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: widget.module.title,
        onBack: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildTopicsList(),
    );
  }

  Widget _buildTopicsList() {
    if (_moduleTopics.isEmpty) {
      // As on the topic list: a soft blue disc, the message, then the action
      // as a blue pill.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.signal50,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIcons.listLinear,
                  size: 40,
                  color: AppColors.signal,
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              Text(
                'No topics available for this module',
                textAlign: TextAlign.center,
                style: AppTypography.heading.copyWith(
                  fontSize: 20,
                  height: 26 / 20,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              FilledButton(
                onPressed: _loadTopics,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
                  shape: const StadiumBorder(),
                ),
                child: Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x6 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: _moduleTopics.length,
      itemBuilder: (context, index) {
        final topic = _moduleTopics[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
          // One-shot entrance, capped so the whole list lands inside
          // AppMotion.base.
          child: StaggerIn(
            index: index,
            count: _moduleTopics.length,
            curve: BentoTokens.curve,
            child: _TopicRow(
              number: index + 1,
              title: topic.title,
              onTap: () => _openTopic(topic),
              trailing: Consumer<ProgressProvider>(
                builder: (context, progressProvider, _) {
                  // Show progress indicator for this topic
                  final progress = progressProvider.progress.topicProgress[topic.id] ?? 0.0;
                  return _buildProgress(progress);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// The topic's progress: nothing before it is started, a blue ring while
  /// under way (blue = current), a green disc with a tick once done
  /// (green = done).
  Widget _buildProgress(double progress) {
    if (progress <= 0) return const SizedBox.shrink();
    if (progress >= 1.0) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.guide,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          SolarIcons.checkLinear,
          color: AppColors.onSignal,
          size: 18,
        ),
      );
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.signal),
      ),
    );
  }
}

/// One topic of the module as a Bento card: a neutral number key, the title,
/// and the progress at the end. The whole card is the button — no chevron.
/// Presses lift the card rather than shrinking it, as on Тесты.
class _TopicRow extends StatefulWidget {
  const _TopicRow({
    required this.number,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final int number;
  final String title;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  State<_TopicRow> createState() => _TopicRowState();
}

class _TopicRowState extends State<_TopicRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.04 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.field,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.number}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.inkSecondary,
                      fontVariations: const [FontVariation('wght', 600)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.body.copyWith(
                      fontSize: 17,
                      height: 22 / 17,
                      letterSpacing: -0.2,
                      color: AppColors.ink,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
