import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'badge_models.dart';
import 'badge_registry_execution_focus.dart';

export 'badge_registry_execution_focus.dart';

/// Pillars 4-8 Mastery Badges: Habits, Knowledge, Systems, Evolution, Mindfulness.
final List<BadgeDefinition> kHabitsMindfulnessBadges = [
  // ===========================================================================
  // PILLAR 4: HABITS & DISCIPLINE (8 Badges)
  // ===========================================================================
  const BadgeDefinition(
    id: 'habit_spark',
    title: 'Habit Seeder',
    subtitle: 'Plant daily seeds',
    category: BadgeCategory.habits,
    icon: Icons.eco_rounded,
    color: AxisColors.success,
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'First Check-in', targetValue: 3, unit: 'logs', description: 'Log your first 3 habit completions.'),
      BadgeTier(tierNumber: 2, name: 'Sprout', targetValue: 15, unit: 'logs', description: 'Log 15 habit check-ins.'),
      BadgeTier(tierNumber: 3, name: 'Sapling', targetValue: 40, unit: 'logs', description: 'Log 40 habit completions.'),
      BadgeTier(tierNumber: 4, name: 'Bloomed', targetValue: 100, unit: 'logs', description: 'Cross 100 completed habit logs.'),
    ],
  ),
  const BadgeDefinition(
    id: 'iron_discipline',
    title: 'Iron Discipline',
    subtitle: 'Forge unyielding habits',
    category: BadgeCategory.habits,
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF10B981),
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Iron Spark', targetValue: 25, unit: 'logs', description: 'Complete 25 habit check-ins.'),
      BadgeTier(tierNumber: 2, name: 'Iron Forge', targetValue: 75, unit: 'logs', description: 'Forge 75 successful habit executions.'),
      BadgeTier(tierNumber: 3, name: 'Iron Will', targetValue: 200, unit: 'logs', description: 'Record 200 habit check-ins.'),
      BadgeTier(tierNumber: 4, name: 'Iron Legend', targetValue: 500, unit: 'logs', description: '500 habit check-ins. Absolute discipline.'),
    ],
  ),
  const BadgeDefinition(
    id: 'routine_centurion',
    title: 'Routine Centurion',
    subtitle: 'Triple digit habit volume',
    category: BadgeCategory.habits,
    icon: Icons.repeat_on_rounded,
    color: Color(0xFF059669),
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Centurion I', targetValue: 100, unit: 'logs', description: 'Hit 100 habit completions.'),
      BadgeTier(tierNumber: 2, name: 'Centurion II', targetValue: 250, unit: 'logs', description: 'Reach 250 habit check-ins.'),
      BadgeTier(tierNumber: 3, name: 'Centurion III', targetValue: 600, unit: 'logs', description: 'Conquer 600 habit logs.'),
      BadgeTier(tierNumber: 4, name: 'Millennium', targetValue: 1000, unit: 'logs', description: '1,000 habit logs. Habit master.'),
    ],
  ),
  const BadgeDefinition(
    id: 'master_of_routine',
    title: 'Master of Routine',
    subtitle: 'Transform routine into instinct',
    category: BadgeCategory.habits,
    icon: Icons.auto_mode_rounded,
    color: Color(0xFF047857),
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Instinct I', targetValue: 150, unit: 'logs', description: '150 logs: actions become second nature.'),
      BadgeTier(tierNumber: 2, name: 'Instinct II', targetValue: 400, unit: 'logs', description: '400 logs: habits operate on autopilot.'),
      BadgeTier(tierNumber: 3, name: 'Instinct III', targetValue: 800, unit: 'logs', description: '800 logs: disciplined lifestyle.'),
      BadgeTier(tierNumber: 4, name: 'Grandmaster', targetValue: 2000, unit: 'logs', description: '2,000 habit completions. Unrivaled.'),
    ],
  ),
  const BadgeDefinition(
    id: 'habit_architect',
    title: 'Habit Architect',
    subtitle: 'Design custom routines',
    category: BadgeCategory.habits,
    icon: Icons.architecture_rounded,
    color: Color(0xFFEC4899),
    metricType: BadgeMetricType.habitsCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Builder I', targetValue: 2, unit: 'habits', description: 'Design your first 2 custom habits.'),
      BadgeTier(tierNumber: 2, name: 'Builder II', targetValue: 5, unit: 'habits', description: 'Structure 5 active custom habits.'),
      BadgeTier(tierNumber: 3, name: 'Builder III', targetValue: 10, unit: 'habits', description: 'Curate a routine system of 10 habits.'),
      BadgeTier(tierNumber: 4, name: 'Master Architect', targetValue: 20, unit: 'habits', description: '20 custom habits architected.'),
    ],
  ),
  const BadgeDefinition(
    id: 'domain_master',
    title: 'Category Master',
    subtitle: 'Organize habits into domains',
    category: BadgeCategory.habits,
    icon: Icons.category_rounded,
    color: Color(0xFFDB2777),
    metricType: BadgeMetricType.habitCategoriesCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Categorizer', targetValue: 1, unit: 'category', description: 'Create your first custom habit category.'),
      BadgeTier(tierNumber: 2, name: 'Domain Sorter', targetValue: 3, unit: 'categories', description: 'Organize habits into 3 domains.'),
      BadgeTier(tierNumber: 3, name: 'Domain Curator', targetValue: 6, unit: 'categories', description: 'Build 6 custom categories for routines.'),
      BadgeTier(tierNumber: 4, name: 'Domain Master', targetValue: 12, unit: 'categories', description: '12 customized habit domains created.'),
    ],
  ),
  const BadgeDefinition(
    id: 'daily_ritualist',
    title: 'Daily Ritual',
    subtitle: 'Solidify your core ritual',
    category: BadgeCategory.habits,
    icon: Icons.wb_twilight_rounded,
    color: Color(0xFFF43F5E),
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Ritualist I', targetValue: 10, unit: 'logs', description: 'Log 10 ritual check-ins.'),
      BadgeTier(tierNumber: 2, name: 'Ritualist II', targetValue: 50, unit: 'logs', description: '50 daily ritual logs recorded.'),
      BadgeTier(tierNumber: 3, name: 'Ritualist III', targetValue: 150, unit: 'logs', description: '150 ritual completions recorded.'),
      BadgeTier(tierNumber: 4, name: 'High Priest', targetValue: 350, unit: 'logs', description: '350 ritual logs. Absolute commitment.'),
    ],
  ),
  const BadgeDefinition(
    id: 'unshakeable_will',
    title: 'Diamond Will',
    subtitle: 'Resist every distraction',
    category: BadgeCategory.habits,
    icon: Icons.military_tech_outlined,
    color: Color(0xFFE11D48),
    metricType: BadgeMetricType.habitLogs,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Resilient', targetValue: 30, unit: 'logs', description: '30 check-ins showing consistent will.'),
      BadgeTier(tierNumber: 2, name: 'Steadfast', targetValue: 120, unit: 'logs', description: '120 habit check-ins logged.'),
      BadgeTier(tierNumber: 3, name: 'Unwavering', targetValue: 300, unit: 'logs', description: '300 habit completions achieved.'),
      BadgeTier(tierNumber: 4, name: 'Diamond Mind', targetValue: 700, unit: 'logs', description: '700 completions. Diamond mental will.'),
    ],
  ),

  // ===========================================================================
  // PILLAR 5: KNOWLEDGE & WISDOM (5 Badges)
  // ===========================================================================
  const BadgeDefinition(
    id: 'note_scribe',
    title: 'Note Scribe',
    subtitle: 'Capture ideas and reflections',
    category: BadgeCategory.knowledge,
    icon: Icons.auto_stories_rounded,
    color: Color(0xFFA855F7),
    metricType: BadgeMetricType.notesCount,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Notary', targetValue: 3, unit: 'notes', description: 'Write down your first 3 notes.'),
      BadgeTier(tierNumber: 2, name: 'Scribe', targetValue: 10, unit: 'notes', description: 'Capture 10 insights and memos in your vault.'),
      BadgeTier(tierNumber: 3, name: 'Chronicler', targetValue: 25, unit: 'notes', description: 'Build a library of 25 saved notes.'),
      BadgeTier(tierNumber: 4, name: 'Author', targetValue: 60, unit: 'notes', description: 'Document 60 thoughts and study notes.'),
    ],
  ),
  const BadgeDefinition(
    id: 'grand_archivist',
    title: 'Grand Archivist',
    subtitle: 'Compile extensive wisdom',
    category: BadgeCategory.knowledge,
    icon: Icons.inventory_2_rounded,
    color: Color(0xFF9333EA),
    metricType: BadgeMetricType.notesCount,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Archivist I', targetValue: 15, unit: 'notes', description: 'Archive 15 structured notes.'),
      BadgeTier(tierNumber: 2, name: 'Archivist II', targetValue: 50, unit: 'notes', description: 'Preserve 50 insights in your knowledge vault.'),
      BadgeTier(tierNumber: 3, name: 'Archivist III', targetValue: 120, unit: 'notes', description: '120 notes cataloged and indexed.'),
      BadgeTier(tierNumber: 4, name: 'Chief Scholar', targetValue: 250, unit: 'notes', description: '250 notes preserved for the future.'),
    ],
  ),
  const BadgeDefinition(
    id: 'second_brain',
    title: 'Second Brain',
    subtitle: 'Externalize mental bandwidth',
    category: BadgeCategory.knowledge,
    icon: Icons.psychology_alt_rounded,
    color: Color(0xFF7E22CE),
    metricType: BadgeMetricType.notesCount,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Cortex I', targetValue: 20, unit: 'notes', description: 'Build your external memory cortex (20 notes).'),
      BadgeTier(tierNumber: 2, name: 'Cortex II', targetValue: 70, unit: 'notes', description: 'Expand your second brain with 70 notes.'),
      BadgeTier(tierNumber: 3, name: 'Synapse', targetValue: 180, unit: 'notes', description: 'Interconnect 180 thoughts and knowledge items.'),
      BadgeTier(tierNumber: 4, name: 'Supermind', targetValue: 400, unit: 'notes', description: '400 notes documented. Pure second brain.'),
    ],
  ),
  const BadgeDefinition(
    id: 'pinned_vault',
    title: 'Vault Keeper',
    subtitle: 'Highlight essential wisdom',
    category: BadgeCategory.knowledge,
    icon: Icons.push_pin_rounded,
    color: Color(0xFFC084FC),
    metricType: BadgeMetricType.notesPinned,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Pin I', targetValue: 1, unit: 'pinned note', description: 'Pin your first essential note to top.'),
      BadgeTier(tierNumber: 2, name: 'Pin II', targetValue: 3, unit: 'pinned notes', description: 'Keep 3 high-importance notes pinned.'),
      BadgeTier(tierNumber: 3, name: 'Pin III', targetValue: 7, unit: 'pinned notes', description: 'Maintain 7 pinned priority references.'),
      BadgeTier(tierNumber: 4, name: 'Master Vault', targetValue: 15, unit: 'pinned notes', description: 'Curate 15 pinned master documents.'),
    ],
  ),
  const BadgeDefinition(
    id: 'encyclopedist',
    title: 'Encyclopedist',
    subtitle: 'Vast knowledge repository',
    category: BadgeCategory.knowledge,
    icon: Icons.menu_book_rounded,
    color: Color(0xFF6B21A8),
    metricType: BadgeMetricType.notesCount,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Volume I', targetValue: 30, unit: 'notes', description: 'Compile 30 reference notes.'),
      BadgeTier(tierNumber: 2, name: 'Volume II', targetValue: 100, unit: 'notes', description: 'Compile 100 reference notes.'),
      BadgeTier(tierNumber: 3, name: 'Volume III', targetValue: 250, unit: 'notes', description: 'Compile 250 reference notes.'),
      BadgeTier(tierNumber: 4, name: 'Grand Codex', targetValue: 600, unit: 'notes', description: '600 notes. A complete personal encyclopedia.'),
    ],
  ),

  // ===========================================================================
  // PILLAR 6: ORGANIZATION & SYSTEMS (4 Badges)
  // ===========================================================================
  const BadgeDefinition(
    id: 'project_founder',
    title: 'Project Founder',
    subtitle: 'Structure deliverables',
    category: BadgeCategory.systems,
    icon: Icons.folder_special_rounded,
    color: Color(0xFF06B6D4),
    metricType: BadgeMetricType.projectsCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Initiator', targetValue: 1, unit: 'project', description: 'Create your first custom project.'),
      BadgeTier(tierNumber: 2, name: 'Organizer', targetValue: 3, unit: 'projects', description: 'Structure 3 distinct project spaces.'),
      BadgeTier(tierNumber: 3, name: 'Lead', targetValue: 7, unit: 'projects', description: 'Direct 7 active project streams.'),
      BadgeTier(tierNumber: 4, name: 'Portfolio Master', targetValue: 15, unit: 'projects', description: 'Create 15 structured projects.'),
    ],
  ),
  const BadgeDefinition(
    id: 'portfolio_director',
    title: 'Systems Director',
    subtitle: 'Scale multi-project work',
    category: BadgeCategory.systems,
    icon: Icons.account_tree_rounded,
    color: Color(0xFF0891B2),
    metricType: BadgeMetricType.projectsCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Branch I', targetValue: 2, unit: 'projects', description: 'Establish 2 project branches.'),
      BadgeTier(tierNumber: 2, name: 'Branch II', targetValue: 5, unit: 'projects', description: 'Manage 5 project spaces.'),
      BadgeTier(tierNumber: 3, name: 'Enterprise', targetValue: 10, unit: 'projects', description: 'Orchestrate 10 structured project spaces.'),
      BadgeTier(tierNumber: 4, name: 'Visionary', targetValue: 25, unit: 'projects', description: 'Manage 25 organized project domains.'),
    ],
  ),
  const BadgeDefinition(
    id: 'tag_virtuoso',
    title: 'Tag Virtuoso',
    subtitle: 'Clean taxonomy labels',
    category: BadgeCategory.systems,
    icon: Icons.label_rounded,
    color: Color(0xFF38BDF8),
    metricType: BadgeMetricType.tagsCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Labeler', targetValue: 2, unit: 'tags', description: 'Create your first 2 custom task tags.'),
      BadgeTier(tierNumber: 2, name: 'Taxonomist', targetValue: 5, unit: 'tags', description: 'Design 5 custom tags for classification.'),
      BadgeTier(tierNumber: 3, name: 'Indexer', targetValue: 12, unit: 'tags', description: 'Index items with 12 distinct tags.'),
      BadgeTier(tierNumber: 4, name: 'Master Sorter', targetValue: 25, unit: 'tags', description: '25 custom tags created for agile sorting.'),
    ],
  ),
  const BadgeDefinition(
    id: 'taxonomy_architect',
    title: 'Taxonomy Architect',
    subtitle: 'Advanced metadata sorting',
    category: BadgeCategory.systems,
    icon: Icons.style_rounded,
    color: Color(0xFF0284C7),
    metricType: BadgeMetricType.tagsCreated,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Schema I', targetValue: 3, unit: 'tags', description: 'Deploy 3 structured tags.'),
      BadgeTier(tierNumber: 2, name: 'Schema II', targetValue: 8, unit: 'tags', description: 'Build an 8-tag indexing system.'),
      BadgeTier(tierNumber: 3, name: 'Schema III', targetValue: 18, unit: 'tags', description: 'Deploy 18 tags across your workspace.'),
      BadgeTier(tierNumber: 4, name: 'Taxonomy King', targetValue: 40, unit: 'tags', description: '40 custom tags crafted with precision.'),
    ],
  ),

  // ===========================================================================
  // PILLAR 7: KINETIC EVOLUTION & LEVEL (4 Badges)
  // ===========================================================================
  const BadgeDefinition(
    id: 'kinetic_awakened',
    title: 'Kinetic Awakened',
    subtitle: 'Early player progression',
    category: BadgeCategory.evolution,
    icon: Icons.electric_bolt_rounded,
    color: Color(0xFFEAB308),
    metricType: BadgeMetricType.userLevel,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Awakened', targetValue: 2, unit: 'Level', description: 'Ascend to Level 2 in AXIS OS.'),
      BadgeTier(tierNumber: 2, name: 'Attuned', targetValue: 3, unit: 'Level', description: 'Reach Level 3 with earned XP.'),
      BadgeTier(tierNumber: 3, name: 'Charged', targetValue: 4, unit: 'Level', description: 'Reach Level 4 through steady output.'),
      BadgeTier(tierNumber: 4, name: 'Empowered', targetValue: 5, unit: 'Level', description: 'Ascend to Level 5. Full system operative.'),
    ],
  ),
  const BadgeDefinition(
    id: 'system_operative',
    title: 'System Operative',
    subtitle: 'Mid-tier kinetic rank',
    category: BadgeCategory.evolution,
    icon: Icons.terminal_rounded,
    color: Color(0xFFCA8A04),
    metricType: BadgeMetricType.userLevel,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Specialist', targetValue: 6, unit: 'Level', description: 'Ascend to Level 6.'),
      BadgeTier(tierNumber: 2, name: 'Adept', targetValue: 9, unit: 'Level', description: 'Reach Level 9 with proven competence.'),
      BadgeTier(tierNumber: 3, name: 'Commander', targetValue: 12, unit: 'Level', description: 'Reach Level 12 through comprehensive execution.'),
      BadgeTier(tierNumber: 4, name: 'Veteran', targetValue: 15, unit: 'Level', description: 'Reach Level 15 in the kinetic ecosystem.'),
    ],
  ),
  const BadgeDefinition(
    id: 'quantum_ascendant',
    title: 'Quantum Ascendant',
    subtitle: 'High tier prestige',
    category: BadgeCategory.evolution,
    icon: Icons.military_tech_rounded,
    color: Color(0xFFA16207),
    metricType: BadgeMetricType.userLevel,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Ascendant I', targetValue: 18, unit: 'Level', description: 'Ascend to prestige Level 18.'),
      BadgeTier(tierNumber: 2, name: 'Ascendant II', targetValue: 22, unit: 'Level', description: 'Ascend to Level 22.'),
      BadgeTier(tierNumber: 3, name: 'Transcendent', targetValue: 26, unit: 'Level', description: 'Reach Level 26. Legendary operative.'),
      BadgeTier(tierNumber: 4, name: 'Grandmaster', targetValue: 30, unit: 'Level', description: 'Level 30 attained. The peak of mastery.'),
    ],
  ),
  const BadgeDefinition(
    id: 'energy_gatherer',
    title: 'Energy Gatherer',
    subtitle: 'Accumulate lifetime XP',
    category: BadgeCategory.evolution,
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFFACC15),
    metricType: BadgeMetricType.totalXp,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'XP Novice', targetValue: 500, unit: 'XP', description: 'Accumulate 500 lifetime XP.'),
      BadgeTier(tierNumber: 2, name: 'XP Collector', targetValue: 2000, unit: 'XP', description: 'Earn 2,000 lifetime XP.'),
      BadgeTier(tierNumber: 3, name: 'XP Harvester', targetValue: 6000, unit: 'XP', description: 'Surpass 6,000 lifetime XP.'),
      BadgeTier(tierNumber: 4, name: 'XP Sovereign', targetValue: 15000, unit: 'XP', description: '15,000 XP gathered. Pure energy.'),
    ],
  ),

  // ===========================================================================
  // PILLAR 8: MINDFULNESS & CONTINUITY (2 Badges)
  // ===========================================================================
  const BadgeDefinition(
    id: 'pillar_of_dawn',
    title: 'Pillar of Dawn',
    subtitle: 'Mindfulness & spiritual continuity',
    category: BadgeCategory.mindfulness,
    icon: Icons.brightness_5_rounded,
    color: Color(0xFF14B8A6),
    metricType: BadgeMetricType.prayersCompleted,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Devoted I', targetValue: 5, unit: 'prayers', description: 'Complete 5 mindful prayer check-ins.'),
      BadgeTier(tierNumber: 2, name: 'Devoted II', targetValue: 25, unit: 'prayers', description: 'Record 25 completed prayers.'),
      BadgeTier(tierNumber: 3, name: 'Devoted III', targetValue: 100, unit: 'prayers', description: 'Conquer 100 completed prayer moments.'),
      BadgeTier(tierNumber: 4, name: 'Steadfast', targetValue: 300, unit: 'prayers', description: '300 prayers completed on schedule.'),
    ],
  ),
  const BadgeDefinition(
    id: 'black_box_logger',
    title: 'Black Box',
    subtitle: 'Audit trail activity logs',
    category: BadgeCategory.mindfulness,
    icon: Icons.history_edu_rounded,
    color: Color(0xFF0D9488),
    metricType: BadgeMetricType.activityLogsCount,
    tiers: [
      BadgeTier(tierNumber: 1, name: 'Telemetry I', targetValue: 10, unit: 'events', description: 'Record 10 productivity audit events.'),
      BadgeTier(tierNumber: 2, name: 'Telemetry II', targetValue: 50, unit: 'events', description: 'Log 50 kinetic events in the black box.'),
      BadgeTier(tierNumber: 3, name: 'Telemetry III', targetValue: 200, unit: 'events', description: 'Capture 200 activity milestones.'),
      BadgeTier(tierNumber: 4, name: 'Total Recall', targetValue: 600, unit: 'events', description: '600 events documented in history.'),
    ],
  ),
];

/// Complete declarative catalog of 50 Mastery Badges across 8 productivity pillars.
/// Composes Execution & Focus badges with Habits & Mindfulness badges.
final List<BadgeDefinition> kMasteryBadgeRegistry = [
  ...kExecutionFocusBadges,
  ...kHabitsMindfulnessBadges,
];
