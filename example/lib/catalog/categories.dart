import 'package:flutter/material.dart';

import 'models.dart';

/// Every category, in sidebar order.
abstract final class Categories {
  static const Category gettingStarted = Category(
    id: 'getting-started',
    name: 'Getting started',
    icon: Icons.flag_outlined,
    description: 'Install the package and take a tour of the library.',
  );

  static const Category ai = Category(
    id: 'ai',
    name: 'AI & Agents',
    icon: Icons.auto_awesome_outlined,
    description:
        'Show that an assistant is thinking, working, listening or '
        'streaming an answer.',
  );

  static const Category text = Category(
    id: 'text',
    name: 'Text',
    icon: Icons.text_fields_rounded,
    description: 'Headlines that reveal, decrypt, rotate, type and shine.',
  );

  static const Category borders = Category(
    id: 'borders',
    name: 'Borders & Glow',
    icon: Icons.crop_square_rounded,
    description: 'Light that travels around an edge or blooms on hover.',
  );

  static const Category pointer = Category(
    id: 'pointer',
    name: 'Pointer & Hover',
    icon: Icons.ads_click_rounded,
    description:
        'Effects that follow the mouse, or the finger while it is '
        'down.',
  );

  static const Category backgrounds = Category(
    id: 'backgrounds',
    name: 'Backgrounds & Overlays',
    icon: Icons.layers_outlined,
    description: 'Layers that sit behind or above your content.',
  );

  static const Category cards = Category(
    id: 'cards',
    name: 'Cards & Carousels',
    icon: Icons.view_carousel_outlined,
    description: 'Cards that flip and strips that scroll on their own.',
  );

  static const Category buttons = Category(
    id: 'buttons',
    name: 'Buttons & Inputs',
    icon: Icons.smart_button_outlined,
    description:
        'Press feedback, stateful buttons, confirmations and text '
        'fields.',
  );

  static const Category controls = Category(
    id: 'controls',
    name: 'Controls',
    icon: Icons.toggle_on_outlined,
    description:
        'Switches, segments, sliders, dials and pickers with springy '
        'feedback.',
  );

  static const Category feedback = Category(
    id: 'feedback',
    name: 'Feedback',
    icon: Icons.notifications_none_rounded,
    description: 'Toasts, bursts, badges and counters that answer the user.',
  );

  static const Category lists = Category(
    id: 'lists',
    name: 'Lists & Scroll',
    icon: Icons.view_agenda_outlined,
    description: 'Entrances, swipes, reordering and scroll physics.',
  );

  static const Category loading = Category(
    id: 'loading',
    name: 'Loading & Progress',
    icon: Icons.hourglass_empty_rounded,
    description: 'Skeletons and progress that keep the wait calm.',
  );

  static const Category transitions = Category(
    id: 'transitions',
    name: 'Transitions',
    icon: Icons.swap_horiz_rounded,
    description: 'Page routes, shape morphs and content swaps.',
  );

  /// Component categories in display order (without [gettingStarted]).
  static const List<Category> components = [
    ai,
    text,
    borders,
    pointer,
    backgrounds,
    cards,
    buttons,
    controls,
    feedback,
    lists,
    loading,
    transitions,
  ];

  static const List<Category> all = [gettingStarted, ...components];
}
