# TODO: Fix ExamSubmission fromMap() Method

## Goal
Add a `fromMap()` factory method to the ExamSubmission model and update the offline queue service to use it.

## Information Gathered
- ExamSubmission model currently has `toMap()` method but no `fromMap()` factory method
- Offline queue service manually constructs ExamSubmission objects from map data in `_processUploadExam()` and `_processUpdateExam()` methods
- QueueItem already has a proper `fromMap()` factory method that works correctly

## Plan
1. Add `fromMap()` factory method to ExamSubmission model
   - Mirror the existing `toMap()` method structure
   - Handle timestamp conversion properly (Map contains Timestamp objects)
   - Include all fields that are in the model

2. Update offline queue service to use `ExamSubmission.fromMap()`
   - Replace manual construction in `_processUploadExam()`
   - Replace manual construction in `_processUpdateExam()`
   - Ensure data format matches what `toMap()` produces

## Dependent Files to be edited
- `lib/models/exam_submission.dart` - Add fromMap() factory method
- `lib/services/offline_queue_service.dart` - Update to use fromMap() method

## Followup steps
- Test the changes by running the app
- Verify offline queue service works correctly with the new fromMap() method
- Ensure data consistency between toMap() and fromMap()

## Status
- [x] Add fromMap() factory method to ExamSubmission model
- [x] Update offline queue service _processUploadExam() method
- [x] Update offline queue service _processUpdateExam() method
- [ ] Test the changes
