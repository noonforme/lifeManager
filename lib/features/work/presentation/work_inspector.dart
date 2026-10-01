import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import 'employment_agreement_forms.dart';

enum _SetupStep { introduction, employment, agreement, ready }

final class WorkInspector extends StatefulWidget {
  const WorkInspector({
    required this.onCreateEmployment,
    required this.onCreateAgreement,
    this.onStartShift,
    this.onAddManualShift,
    super.key,
  });

  final SubmitEmployment onCreateEmployment;
  final SubmitAgreement onCreateAgreement;
  final VoidCallback? onStartShift;
  final VoidCallback? onAddManualShift;

  @override
  State<WorkInspector> createState() => _WorkInspectorState();
}

final class _WorkInspectorState extends State<WorkInspector> {
  _SetupStep _step = _SetupStep.introduction;
  Employment? _employment;
  PayAgreement? _agreement;

  Future<MutationOutcome<Employment>> _createEmployment(
    EmploymentDraft draft,
  ) async {
    final outcome = await widget.onCreateEmployment(draft);
    if (mounted) {
      if (outcome case Committed<Employment>(:final value)) {
        setState(() {
          _employment = value;
          _step = _SetupStep.agreement;
        });
      }
    }
    return outcome;
  }

  Future<MutationOutcome<PayAgreement>> _createAgreement(
    AgreementDraft draft,
  ) async {
    final outcome = await widget.onCreateAgreement(draft);
    if (mounted) {
      if (outcome case Committed<PayAgreement>(:final value)) {
        setState(() {
          _agreement = value;
          _step = _SetupStep.ready;
        });
      }
    }
    return outcome;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _SetupStep.introduction => _Introduction(
        onCreate: () => setState(() => _step = _SetupStep.employment),
      ),
      _SetupStep.employment => EmploymentForm(onSubmit: _createEmployment),
      _SetupStep.agreement => AgreementForm(
        employmentId: _employment!.id,
        onSubmit: _createAgreement,
      ),
      _SetupStep.ready => _Ready(
        employment: _employment!,
        agreement: _agreement!,
        onStartShift: widget.onStartShift,
        onAddManualShift: widget.onAddManualShift,
      ),
    };
  }
}

final class _Introduction extends StatelessWidget {
  const _Introduction({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set up Work', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text(
            'Create an employment and an agreement before recording paid work.',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Create employment'),
          ),
        ],
      ),
    );
  }
}

final class _Ready extends StatelessWidget {
  const _Ready({
    required this.employment,
    required this.agreement,
    required this.onStartShift,
    required this.onAddManualShift,
  });

  final Employment employment;
  final PayAgreement agreement;
  final VoidCallback? onStartShift;
  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            employment.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text('Agreement ${agreement.version} is effective.'),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onStartShift,
            child: const Text('Start shift'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAddManualShift,
            child: const Text('Add manual shift'),
          ),
        ],
      ),
    );
  }
}
