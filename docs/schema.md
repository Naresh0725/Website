# Database inventory

Executable schema: `db/migrations/001_schema.sql` plus constraints/triggers in later migrations.

| Table | Direct foreign-key targets |
|---|---|
| `users` | None |
| `user_profiles` | `users` |
| `roles` | None |
| `permissions` | None |
| `role_permissions` | `permissions`, `roles` |
| `user_roles` | `roles`, `users` |
| `media_assets` | None |
| `sources` | `media_assets` |
| `exam_families` | None |
| `exams` | `exam_families` |
| `exam_stages` | `exams` |
| `syllabus_versions` | `exam_stages`, `sources` |
| `subjects` | None |
| `exam_subjects` | `subjects`, `syllabus_versions` |
| `topics` | `exam_subjects`, `topics` |
| `user_exam_preferences` | `exams`, `users` |
| `questions` | `questions`, `users` |
| `question_versions` | `questions` |
| `question_translations` | `question_versions` |
| `question_options` | `question_versions` |
| `question_option_translations` | `question_options` |
| `question_answer_keys` | `question_versions` |
| `question_topic_mappings` | `question_versions`, `topics` |
| `question_groups` | None |
| `question_group_members` | `question_groups`, `question_versions` |
| `question_assets` | `media_assets`, `question_versions` |
| `exam_papers` | `exam_stages`, `sources` |
| `question_paper_occurrences` | `exam_papers`, `question_versions` |
| `question_reviews` | `question_paper_occurrences`, `question_versions`, `users` |
| `question_import_batches` | `sources`, `users` |
| `question_import_items` | `question_import_batches`, `questions` |
| `mock_tests` | `exam_stages`, `users` |
| `test_versions` | `mock_tests`, `syllabus_versions` |
| `test_sections` | `test_versions` |
| `test_questions` | `question_versions`, `test_sections` |
| `test_blueprint_rules` | `test_sections`, `topics` |
| `user_free_allowances` | `users` |
| `subscription_plans` | None |
| `subscription_plan_versions` | `subscription_plans` |
| `plan_exam_access` | `exams`, `subscription_plan_versions` |
| `payment_orders` | `subscription_plan_versions`, `users` |
| `payments` | `payment_orders` |
| `payment_verification_events` | `payments` |
| `payment_webhook_events` | None |
| `user_subscriptions` | `subscription_plan_versions`, `users` |
| `subscription_periods` | `payments`, `user_subscriptions` |
| `user_attempts` | `test_versions`, `users` |
| `attempt_sections` | `test_sections`, `user_attempts` |
| `attempt_questions` | `attempt_sections`, `question_versions`, `user_attempts` |
| `attempt_answers` | `attempt_questions` |
| `attempt_events` | `user_attempts` |
| `free_attempt_events` | `free_attempt_events`, `user_attempts`, `users` |
| `attempt_authorizations` | `free_attempt_events`, `subscription_periods`, `user_attempts` |
| `attempt_results` | `attempt_results`, `user_attempts` |
| `answer_evaluations` | `attempt_questions`, `attempt_results` |
| `result_section_summaries` | `attempt_results`, `attempt_sections` |
| `user_topic_performance` | `topics`, `users` |
| `user_exam_performance` | `exam_stages`, `users` |
| `question_reports` | `question_versions`, `user_attempts`, `users` |
| `refunds` | `payments` |
| `payment_disputes` | `payments` |
| `admin_audit_logs` | `users` |
| `outbox_events` | None |
| `background_jobs` | None |
| `idempotency_requests` | None |

## Conventions

UUID primary keys; explicit composite keys on mappings; UTC-aware timestamps; money in paise with INR currency; exact numeric score storage. No private keys or secrets in question or billing tables. The SQL files are the full column-level schema.

All 65 tables are private to the application schema. Result revisions supersede rather than overwrite old scores. Source records link paper/answer-key evidence; future storage objects are addressed by private storage keys.
