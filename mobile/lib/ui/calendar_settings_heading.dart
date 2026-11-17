import 'package:flutter/material.dart';

import 'design_tokens.dart';

class CalendarSettingsHeading extends StatelessWidget {
  const CalendarSettingsHeading(this.title, {this.divided = true, super.key});

  final String title;
  final bool divided;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (divided) const Divider(height: PomaSpace.xl),
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      const SizedBox(height: PomaSpace.xs),
    ],
  );
}
