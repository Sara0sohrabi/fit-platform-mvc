# Phase 1 API Contract — Gymmap / Soura

## Authentication

`POST /api/auth/register`
- body: `fullName, mobile, password, role`
- role: `STUDENT | GYM | COACH`

`POST /api/auth/login`
- body: `mobile, password`
- response: access token + user + role(s)

`POST /api/auth/verify-mobile`
- body: `mobile, otp`

## Map / Home

`GET /api/gyms/nearby?latitude={lat}&longitude={lng}&radiusKm={radius}`

Returns approved active gyms with `id, name, latitude, longitude, address, city, activeClassesCount`.

`GET /api/gyms/{gymId}`

Returns gym detail, coach list and active classes.

## Sports

`GET /api/sports?category={category}`

Returns active Sports records for selection. The source table is `dbo.Sports` in `db/sports.sql`.

## Gym management

`POST /api/gyms`
`PUT /api/gyms/{gymId}`
`POST /api/gyms/{gymId}/coaches/{coachUserId}`

## Classes

`POST /api/classes`

Required: `gymId, sportId, title, coachUserId, capacity, startDate, endDate`.

`POST /api/classes/{classId}/schedules`

Schedule supports:
- `dayType=ODD`
- `dayType=EVEN`
- `dayType=WEEKDAY` with `weekdayNo` 0..6 (Saturday..Friday)

`GET /api/classes/{classId}/sessions?from={date}&to={date}`

Returns generated `ClassSessions` used by the calendar.

## Packages / registration

`GET /api/classes/{classId}/packages`

`POST /api/enrollments`

Body: `classId, packageId`.

The package normally has 4, 8 or 12 sessions and a price configured by the gym.

## Payment approval

`POST /api/enrollments/{id}/payments`

Body: `amount, paidAt, trackingCode, receiptUrl`.

New payment starts as `PENDING`.

`POST /api/payments/{paymentId}/approve`

On approval:
- payment becomes `APPROVED`
- enrollment becomes `ACTIVE`
- start/end dates are recorded
- session occurrences are available to the calendar
- notification is created

`POST /api/payments/{paymentId}/reject`

## Attendance

`GET /api/sessions/{sessionId}/attendance`

Coach sees the enrolled students.

`POST /api/sessions/{sessionId}/attendance`

Body: `studentUserId, enrollmentId, status, note`.

Statuses: `PRESENT | ABSENT | LATE | EXCUSED`.

Student sees only their own attendance. Gym/admin sees the complete class attendance.

## Notifications

`GET /api/notifications`
`POST /api/notifications/{id}/read`

Notification examples:
- payment approved/rejected
- class tomorrow
- class today
- registration activated
- schedule changed

## Implementation order

1. Database migrations and seed
2. Authentication + role selection
3. Map/nearby gyms API
4. Gym/student/coach profiles
5. Sports + class + coach management
6. Schedules + odd/even calendar generation
7. Packages + enrollment
8. Card-transfer payment + approval
9. Notifications
10. Attendance
11. Role-specific dashboards
