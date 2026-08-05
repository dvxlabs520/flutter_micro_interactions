import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for ButtonStates, ShakeButton, ShimmerButton, InputFocus and
/// FloatingLabel.
class ButtonsInputsPage extends StatefulWidget {
  const ButtonsInputsPage({super.key});

  @override
  State<ButtonsInputsPage> createState() => _ButtonsInputsPageState();
}

class _ButtonsInputsPageState extends State<ButtonsInputsPage> {
  final ButtonStateController _saveController = ButtonStateController();
  final ButtonStateController _uploadController = ButtonStateController();
  bool _termsAccepted = false;

  @override
  void dispose() {
    _saveController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _saveController.setLoading();
    await Future<void>.delayed(const Duration(seconds: 2));
    _saveController.setSuccess();
  }

  Future<void> _upload() async {
    _uploadController.setLoading();
    await Future<void>.delayed(const Duration(seconds: 2));
    _uploadController.setError();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Buttons & Inputs',
      description:
          'Stateful buttons and text fields with focus and label animations.',
      children: [
        DemoSection(
          title: 'ButtonStates: success flow',
          description:
              'A ButtonStateController drives idle, loading and success '
              'content. autoResetDuration returns the button to idle.',
          child: ButtonStates(
            controller: _saveController,
            autoResetDuration: const Duration(seconds: 1),
            loadingBuilder: (context) => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            successBuilder: (context) =>
                const Icon(Icons.check_circle, color: Colors.green),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ),
        ),
        DemoSection(
          title: 'ButtonStates: error flow',
          description: 'The same widget showing the error state.',
          child: ButtonStates(
            controller: _uploadController,
            autoResetDuration: const Duration(seconds: 2),
            errorBuilder: (context) =>
                Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            child: OutlinedButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload file'),
            ),
          ),
        ),
        DemoSection(
          title: 'ShakeButton',
          description:
              'Shakes when pressed while invalid. Accept the terms to make '
              'the press succeed.',
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('I accept the terms'),
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
              ),
              ShakeButton(
                isValid: _termsAccepted,
                onPressed: () => showMessage(context, 'Account created'),
                onInvalidPress: () =>
                    showMessage(context, 'Please accept the terms first'),
                builder: (context, handlePressed) => FilledButton.icon(
                  onPressed: handlePressed,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'ShimmerButton',
          description:
              'A periodic shimmer sweep marks the primary call to action. '
              'Pressing scales the button down slightly; onPressed fires '
              'immediately on tap-up.',
          child: Column(
            children: [
              ShimmerButton(
                onPressed: () =>
                    showMessage(context, 'Proceeding to checkout'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checkout securely',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Custom colors and corner radius, with haptics on press.
              ShimmerButton(
                onPressed: () =>
                    showMessage(context, 'Upgraded to Pro'),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                borderRadius: BorderRadius.circular(24),
                enableHaptics: true,
                child: Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'InputFocus',
          description:
              'Gently scales and lifts a text field while it is focused.',
          child: InputFocus.animate(
            borderRadius: BorderRadius.circular(4),
            child: const TextField(
              decoration: InputDecoration(
                labelText: 'Full name',
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        DemoSection(
          title: 'FloatingLabel',
          description:
              'A text field whose label slides from the hint position to a '
              'floated position. Validators run like any TextFormField.',
          child: Column(
            children: [
              FloatingLabel(
                label: 'Email',
                hint: 'name@example.com',
                prefixIcon: const Icon(Icons.email),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FloatingLabel(
                label: 'Password',
                hint: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: const Icon(Icons.visibility),
                obscureText: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
